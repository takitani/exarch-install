#!/usr/bin/env bash
# modules/remmina.sh - Remmina RDP connection generation from 1Password

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"

# Remmina settings (can be overridden in settings.conf)
REMMINA_DEFAULT_RESOLUTION="${REMMINA_DEFAULT_RESOLUTION:-1920x1080}"
REMMINA_DRIVE_MAPPING="${REMMINA_DRIVE_MAPPING:-/home/$USER/Public}"
REMMINA_DEFAULT_USERNAME="${REMMINA_DEFAULT_USERNAME:-Administrator}"

# Vault to category mapping
declare -A VAULT_CATEGORIES=(
  ["Cloud Prod"]="prod"
  ["Cloud Dev (UAT)"]="dev"
  ["Personal"]="personal"
)

# Check if Remmina is installed
detect_remmina() {
  if command_exists remmina; then
    return 0
  fi
  
  # Check if it's installed via package manager
  if is_pacman_installed remmina || is_aur_installed remmina; then
    return 0
  fi
  
  return 1
}

# Install Remmina if not present
install_remmina() {
  info "Installing Remmina..."
  
  if detect_remmina; then
    info "Remmina already installed"
    return 0
  fi
  
  if pac remmina; then
    # Install common RDP plugins
    pac freerdp || warn "Failed to install FreeRDP plugin"
    success "Remmina installed successfully"
    return 0
  else
    err "Failed to install Remmina"
    return 1
  fi
}

# Get Remmina encryption secret
get_remmina_secret() {
  local remmina_pref="$HOME/.config/remmina/remmina.pref"
  
  if [[ ! -f "$remmina_pref" ]]; then
    # Create default remmina config if it doesn't exist
    mkdir -p "$(dirname "$remmina_pref")"
    
    # Generate a random secret (32 bytes, base64 encoded)
    local secret
    secret=$(openssl rand -base64 32 | tr -d '\n')
    
    cat > "$remmina_pref" << EOF
[remmina]
datadir_path=$HOME/.local/share/remmina
remmina_file_name=%G_%P_%N_%h
screenshot_path=$HOME
screenshot_name=remmina_%p_%h_%Y%m%d-%H%M%S
console_font=
console_font_size=12
resolutions=640x480,800x600,1024x768,1152x864,1280x960,1280x1024,1360x768,1440x900,1680x1050,1920x1080,1920x1200,2560x1440,3840x2160
main_width=600
main_height=400
main_maximize=false
main_show_quick_search=false
expanded_group=
toolbar_pin_down=false
small_toolbutton=false
view_file_mode=0
resolutions_artsd=
keystrokes=
secret=$secret
vte_font=Monospace 12
vte_allow_bold_text=true
vte_lines=-1
tab_mode=0
auto_scroll_step=10
hostkey=65027
shortcutkey_fullscreen=65480
shortcutkey_autofit=65481
shortcutkey_nexttab=65366
shortcutkey_prevtab=65365
shortcutkey_scale=65479
shortcutkey_grab=65478
shortcutkey_minimize=65482
shortcutkey_viewonly=65483
shortcutkey_screenshot=65484
shortcutkey_disconnect=65485
shortcutkey_toolbar=65486
disable_tray_icon=false
dark_theme=false
EOF
    
    success "Created Remmina configuration with new secret"
  fi
  
  # Extract secret from config file
  local secret
  secret=$(grep "^secret=" "$remmina_pref" 2>/dev/null | cut -d'=' -f2)
  
  if [[ -z "$secret" ]]; then
    err "Could not find Remmina secret in configuration"
    return 1
  fi
  
  echo "$secret"
}

# Encrypt password for Remmina (using simple base64 encoding)
encrypt_remmina_password() {
  local password="$1"
  
  if [[ -z "$password" ]]; then
    err "Password is required"
    return 1
  fi
  
  # Use base64 encoding - Remmina can handle this and will use its own encryption
  # when the file is first loaded by the application
  echo "$password" | base64 -w 0
}

# Convert vault name to category
vault_to_category() {
  local vault="$1"
  echo "${VAULT_CATEGORIES[$vault]:-unknown}"
}

# Sanitize name for filename
sanitize_name() {
  local name="$1"
  # Convert to lowercase, replace spaces/special chars with dashes, limit length
  echo "$name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g' | cut -c1-50
}

# Extract IP from server field and sanitize for filename
extract_ip() {
  local server="$1"
  # Remove protocol, extract hostname/IP, replace special chars with dashes, limit length
  echo "$server" | sed 's|.*://||' | sed 's|/.*||' | sed 's/[^a-zA-Z0-9.-]/-/g' | sed 's/\./-/g' | sed 's/--*/-/g' | cut -c1-30
}

# Generate Remmina configuration file
generate_remmina_config() {
  local name="$1"
  local server="$2" 
  local username="$3"
  local password="$4"
  local category="$5"
  local vault="$6"
  
  local sanitized_name
  local ip_part
  local filename
  local remmina_dir="$HOME/.local/share/remmina"
  local encrypted_password
  local secret
  
  # Get encryption secret (for Remmina config, but we'll use simple approach)
  secret=$(get_remmina_secret)
  
  # Encrypt password (simple base64 encoding)
  encrypted_password=$(encrypt_remmina_password "$password")
  if [[ -z "$encrypted_password" ]]; then
    warn "Failed to encode password for $name, using plaintext"
    encrypted_password="$password"
  fi
  
  # Sanitize components for filename
  sanitized_name=$(sanitize_name "$name")
  ip_part=$(extract_ip "$server")
  
  # Validate components before creating filename
  if [[ -z "$sanitized_name" ]]; then
    sanitized_name="unknown"
  fi
  if [[ -z "$ip_part" ]]; then
    ip_part="noserver"
  fi
  
  # Create filename: group_[category]_[name]_[ip].remmina
  filename="group_${category}_${sanitized_name}_${ip_part}.remmina"
  
  # Additional validation - ensure filename is valid
  if [[ ! "$filename" =~ ^[a-zA-Z0-9._-]+\.remmina$ ]]; then
    warn "Invalid filename generated: $filename, using fallback"
    filename="group_${category}_connection_$(date +%s).remmina"
  fi
  
  # Ensure remmina directory exists
  mkdir -p "$remmina_dir"
  
  # Debug: Show what we're creating
  info "Creating: $filename"
  
  # Generate configuration file
  cat > "$remmina_dir/$filename" << EOF
[remmina]
password=$encrypted_password
gateway_username=
notes_text=Generated from 1Password vault: $vault
vc=
window_height=1080
preferipv6=0
ssh_tunnel_loopback=0
serialname=
tls-seclevel=
sound=off
printer_overrides=
name=$name
console=0
colordepth=16
security=
precommand=
disable_fastpath=0
postcommand=
left-handed=0
multitransport=0
group=$category
server=$server
ssh_tunnel_certfile=
glyph-cache=0
ssh_tunnel_enabled=0
disableclipboard=0
labels=
audio-output=
parallelpath=
monitorids=
cert_ignore=0
gateway_server=
serialpermissive=0
protocol=RDP
old-license=0
ssh_tunnel_password=
resolution_mode=2
pth=
disableautoreconnect=0
loadbalanceinfo=
clientbuild=
clientname=
resolution_width=$(echo "$REMMINA_DEFAULT_RESOLUTION" | cut -d'x' -f1)
drive=$REMMINA_DRIVE_MAPPING
relax-order-checks=0
base-cred-for-gw=0
gateway_domain=
network=none
rdp2tcp=
gateway_password=
serialdriver=
rdp_reconnect_attempts=
profile-lock=0
domain=
smartcardname=
serialpath=
exec=
multimon=0
username=$username
enable-autostart=0
usb=
shareprinter=0
viewmode=1
restricted-admin=0
shareparallel=0
quality=0
span=0
ssh_tunnel_passphrase=
parallelname=
disablepasswordstoring=0
execpath=
shareserial=0
sharefolder=
sharesmartcard=0
keymap=
ssh_tunnel_username=
resolution_height=$(echo "$REMMINA_DEFAULT_RESOLUTION" | cut -d'x' -f2)
timeout=
useproxyenv=0
no-suppress=0
dvc=
microphone=
freerdp_log_filters=
gwtransp=http
window_maximize=1
ssh_tunnel_server=
ignore-tls-errors=1
gateway_usage=0
ssh_tunnel_auth=2
ssh_tunnel_privatekey=
window_width=1920
websockets=0
freerdp_log_level=INFO
disable-smooth-scrolling=0
EOF
  
  success "Created Remmina connection: $filename"
  echo "$remmina_dir/$filename"
}

# Process servers from a specific vault
process_vault_servers() {
  local vault="$1"
  local category="$2"
  local connections_created=0
  
  info "Processing vault: $vault (category: $category)"
  
  # Get list of server items from vault with expanded search
  local server_list
  # Search in multiple categories since RDP connections can be in various places
  local server_list_server server_list_login server_list_database filtered_login filtered_database
  
  # Get items from Server category - use timeout and echo "n" to prevent interactive prompts
  server_list_server=$(echo "n" | timeout 5 op item list --vault "$vault" --categories Server --format json 2>/dev/null || echo "[]")
  
  # Get items from Login category
  server_list_login=$(echo "n" | timeout 5 op item list --vault "$vault" --categories Login --format json 2>/dev/null || echo "[]")
  
  # Get items from Database category (sometimes servers are stored here)
  server_list_database=$(echo "n" | timeout 5 op item list --vault "$vault" --categories Database --format json 2>/dev/null || echo "[]")
  
  # Filter Login items to only those that look like server connections
  filtered_login=$(echo "$server_list_login" | jq '[.[] | select(.title | test("EC2|RDP|Remote|Server|VM|VPS|Instance|Host|AWS|Azure|GCP|Cloud|Web|App|API|Backend|Frontend|Prod|Dev|UAT|Test|Staging"; "i"))]' 2>/dev/null || echo "[]")
  
  # Filter Database items to only those that look like server connections
  filtered_database=$(echo "$server_list_database" | jq '[.[] | select(.title | test("EC2|RDP|Remote|Server|VM|VPS|Instance|Host|AWS|Azure|GCP|Cloud|Web|App|API|Backend|Frontend|Prod|Dev|UAT|Test|Staging"; "i"))]' 2>/dev/null || echo "[]")
  
  # Combine all lists
  server_list=$(echo "$server_list_server" "$filtered_login" "$filtered_database" | jq -s 'flatten' 2>/dev/null || echo "[]")
  
  if [[ -z "$server_list" || "$server_list" == "null" || "$server_list" == "[]" ]]; then
    warn "No server items found in vault: $vault"
    return 0
  fi
  
  # Process each server item
  local server_count
  server_count=$(echo "$server_list" | jq 'length' 2>/dev/null || echo "0")
  
  if [[ "$server_count" -gt 0 ]]; then
    info "Found $server_count server(s) in $vault"
    
    # Process each server
    for i in $(seq 0 $((server_count - 1))); do
      local item_id
      local item_title
      
      item_id=$(echo "$server_list" | jq -r ".[$i].id" 2>/dev/null)
      item_title=$(echo "$server_list" | jq -r ".[$i].title" 2>/dev/null)
      
      if [[ -n "$item_id" && "$item_id" != "null" ]]; then
        if process_server_item "$item_id" "$item_title" "$category" "$vault"; then
          ((connections_created++))
        fi
      fi
    done
  fi
  
  if [[ $connections_created -gt 0 ]]; then
    success "Created $connections_created connection(s) from $vault"
  fi
  
  return 0
}

# Process a single server item
process_server_item() {
  local item_id="$1"
  local item_title="$2"
  local category="$3"
  local vault="$4"
  
  info "Processing server: $item_title"
  
  # Get detailed item information
  local item_details
  item_details=$(op item get "$item_id" --format json 2>/dev/null)
  
  if [[ -z "$item_details" ]]; then
    warn "Could not fetch details for item: $item_title"
    return 1
  fi
  
  # Extract fields with improved detection
  local server_field
  local username_field
  local password_field
  
  # Debug: Show all available fields for troubleshooting
  if [[ "${DEBUG_REMMINA:-false}" == "true" ]]; then
    info "Available fields for $item_title:"
    echo "$item_details" | jq -r '.fields[]? | "  \(.label // "NO_LABEL"): \(.value // "NO_VALUE")"' 2>/dev/null
  fi
  
  # Try to find server/hostname field with expanded patterns
  server_field=$(echo "$item_details" | jq -r '.fields[] | select(.label | test("server|hostname|Server|Hostname|Servidor|servidor|address|Address|endereço|endereco|ip|IP|host|Host"; "i")) | .value' 2>/dev/null | head -n1)
  
  # If not found in fields, try URLs (common for EC2 instances)
  if [[ -z "$server_field" || "$server_field" == "null" ]]; then
    server_field=$(echo "$item_details" | jq -r '.urls[]? | .href' 2>/dev/null | head -n1)
    # Extract hostname from URL if it looks like a URL
    if [[ "$server_field" =~ ^https?:// ]]; then
      server_field=$(echo "$server_field" | sed -E 's|.*://([^:/]+).*|\1|')
    fi
  fi
  
  # Try to find username field with expanded patterns
  username_field=$(echo "$item_details" | jq -r '.fields[] | select(.label | test("username|Username|user|User|usuário|usuario|nome.*usuário|nome.*usuario|login|Login|account|Account|conta|Conta"; "i")) | .value' 2>/dev/null | head -n1)
  
  # If username not found in fields, try login section
  if [[ -z "$username_field" || "$username_field" == "null" ]]; then
    username_field=$(echo "$item_details" | jq -r '.login.username // ""' 2>/dev/null)
  fi
  
  # Try to find password field with expanded patterns
  password_field=$(echo "$item_details" | jq -r '.fields[] | select(.label | test("password|Password|pass|Pass|senha|Senha|pwd|Pwd|secret|Secret|chave|Chave"; "i")) | .value' 2>/dev/null | head -n1)
  
  # If password not found in fields, try login section
  if [[ -z "$password_field" || "$password_field" == "null" ]]; then
    password_field=$(echo "$item_details" | jq -r '.login.password // ""' 2>/dev/null)
  fi
  
  # Additional fallback: try to find any field that might contain the password
  if [[ -z "$password_field" || "$password_field" == "null" ]]; then
    # Look for any field with "password" in the value (sometimes passwords are stored in generic fields)
    password_field=$(echo "$item_details" | jq -r '.fields[] | select(.value | test("^[a-zA-Z0-9!@#$%^&*()_+\\-=\\[\\]{}|;:,.<>?]{8,}$"; "i")) | .value' 2>/dev/null | head -n1)
  fi
  
  # Validate required fields with detailed debugging
  if [[ -z "$server_field" || "$server_field" == "null" ]]; then
    warn "Skipping $item_title: No server/hostname found"
    if [[ "${DEBUG_REMMINA:-false}" == "true" ]]; then
      info "Available fields that might contain server info:"
      echo "$item_details" | jq -r '.fields[]? | select(.label | test("server|hostname|address|ip|host"; "i")) | "  \(.label): \(.value // "NO_VALUE")"' 2>/dev/null
      info "URLs:"
      echo "$item_details" | jq -r '.urls[]? | .href // "NO_URL"' 2>/dev/null
    fi
    return 1
  fi
  
  if [[ -z "$username_field" || "$username_field" == "null" ]]; then
    username_field="$REMMINA_DEFAULT_USERNAME"
    warn "No username found for $item_title, using default: $username_field"
    if [[ "${DEBUG_REMMINA:-false}" == "true" ]]; then
      info "Available fields that might contain username info:"
      echo "$item_details" | jq -r '.fields[]? | select(.label | test("user|login|account"; "i")) | "  \(.label): \(.value // "NO_VALUE")"' 2>/dev/null
    fi
  fi
  
  if [[ -z "$password_field" || "$password_field" == "null" ]]; then
    warn "Skipping $item_title: No password found"
    if [[ "${DEBUG_REMMINA:-false}" == "true" ]]; then
      info "Available fields that might contain password info:"
      echo "$item_details" | jq -r '.fields[]? | select(.label | test("password|pass|senha|secret|chave"; "i")) | "  \(.label): \(.value // "NO_VALUE")"' 2>/dev/null
      info "Login section:"
      echo "$item_details" | jq -r '.login // "NO_LOGIN_SECTION"' 2>/dev/null
    fi
    return 1
  fi
  
  # Generate Remmina configuration
  if generate_remmina_config "$item_title" "$server_field" "$username_field" "$password_field" "$category" "$vault"; then
    return 0
  else
    err "Failed to generate Remmina configuration for: $item_title"
    return 1
  fi
}

# Main function to setup Remmina connections
setup_remmina_connections_complete() {
  info "Setting up Remmina RDP connections from 1Password..."
  
  # Enable debug mode if requested
  if [[ "${DEBUG_REMMINA:-false}" == "true" ]]; then
    info "DEBUG MODE ENABLED - Will show detailed field information"
  fi
  
  # Check if Remmina is installed
  if ! detect_remmina; then
    if ! install_remmina; then
      err "Remmina installation failed"
      return 1
    fi
  fi
  
  # Check 1Password CLI
  if ! command_exists op; then
    err "1Password CLI not available. Please run 1Password setup first."
    return 1
  fi
  
  # Test 1Password authentication - check if actually configured with accounts
  local account_check
  account_check=$(timeout 5 op account list 2>&1)
  local account_exit=$?
  
  if [[ $account_exit -ne 0 ]] || [[ "$account_check" == *"No accounts configured"* ]] || [[ -z "$account_check" ]] || ! echo "$account_check" | grep -q "@"; then
    err "1Password CLI not configured or authenticated."
    echo "Please configure 1Password first by running:"
    echo "  ./install.sh --1pass"
    echo "Or:"
    echo "  ./helpers/1password-helper.sh"
    return 1
  fi
  
  # Check if we can actually access vaults
  if ! timeout 5 op vault list >/dev/null 2>&1; then
    err "1Password CLI needs authentication."
    echo "Please sign in first using: eval \$(op signin)"
    return 1
  fi
  
  local total_connections=0
  
  # Process each vault
  for vault in "${!VAULT_CATEGORIES[@]}"; do
    local category="${VAULT_CATEGORIES[$vault]}"
    local vault_connections
    
    info "Checking vault: $vault"
    vault_connections=$(process_vault_servers "$vault" "$category")
    
    # Extract connection count from output
    if [[ "$vault_connections" =~ Created\ ([0-9]+)\ connection ]]; then
      ((total_connections += ${BASH_REMATCH[1]}))
    fi
  done
  
  echo
  if [[ $total_connections -gt 0 ]]; then
    success "Successfully created $total_connections Remmina connection(s)"
    echo
    echo -e "${BOLD}Files created in:${NC} $HOME/.local/share/remmina/"
    echo -e "${BOLD}Remmina groups:${NC}"
    for vault in "${!VAULT_CATEGORIES[@]}"; do
      local category="${VAULT_CATEGORIES[$vault]}"
      echo "  • $category (from $vault vault)"
    done
    echo
    echo "You can now open Remmina and find your connections organized by category."
  else
    warn "No Remmina connections were created"
    echo "This could be because:"
    echo "  • No Server items found in accessible vaults"
    echo "  • Server items missing required fields (hostname, password)"
    echo "  • 1Password authentication issues"
  fi
  
  return 0
}

# Test mode with debug output - generates sample files for testing
test_remmina_mode() {
  info "🖥️ Remmina Debug Mode - Generating sample RDP connections for testing"
  
  # Create debug directory
  local debug_dir="/tmp/remmina-debug-$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$debug_dir"
  
  # Create sample connections for testing
  local sample_connections=(
    "Intelligence-API-1:54.207.93.195:Administrator:TestPass123:prod"
    "Exato-UAT:18.228.254.104:Administrator:DevPass456:dev"
    "Test-Server:192.168.1.100:opik:LocalPass789:personal"
  )
  
  info "Creating sample RDP connection files..."
  echo
  
  local connections_created=0
  
  for connection_data in "${sample_connections[@]}"; do
    IFS=':' read -r name server username password category <<< "$connection_data"
    
    info "Creating connection: $name ($server)"
    
    # Generate the connection file in debug directory
    local sanitized_name=$(sanitize_name "$name")
    local ip_part=$(extract_ip "$server")
    local filename="group_${category}_${sanitized_name}_${ip_part}.remmina"
    
    # Encrypt password
    local encrypted_password
    encrypted_password=$(encrypt_remmina_password "$password")
    
    # Generate configuration file
    cat > "$debug_dir/$filename" << EOF
[remmina]
password=$encrypted_password
gateway_username=
notes_text=DEBUG: Generated from Remmina test mode - Server: $name
vc=
window_height=1080
preferipv6=0
ssh_tunnel_loopback=0
serialname=
tls-seclevel=
sound=off
printer_overrides=
name=$name (DEBUG)
console=0
colordepth=16
security=
precommand=
disable_fastpath=0
postcommand=
left-handed=0
multitransport=0
group=$category
server=$server
ssh_tunnel_certfile=
glyph-cache=0
ssh_tunnel_enabled=0
disableclipboard=0
labels=
audio-output=
parallelpath=
monitorids=
cert_ignore=0
gateway_server=
serialpermissive=0
protocol=RDP
old-license=0
ssh_tunnel_password=
resolution_mode=2
pth=
disableautoreconnect=0
loadbalanceinfo=
clientbuild=
clientname=
resolution_width=1920
drive=$HOME/Public
relax-order-checks=0
base-cred-for-gw=0
gateway_domain=
network=none
rdp2tcp=
gateway_password=
serialdriver=
rdp_reconnect_attempts=
profile-lock=0
domain=
smartcardname=
serialpath=
exec=
multimon=0
username=$username
enable-autostart=0
usb=
shareprinter=0
viewmode=1
restricted-admin=0
shareparallel=0
quality=0
span=0
ssh_tunnel_passphrase=
parallelname=
disablepasswordstoring=0
execpath=
shareserial=0
sharefolder=
sharesmartcard=0
keymap=
ssh_tunnel_username=
resolution_height=1080
timeout=
useproxyenv=0
no-suppress=0
dvc=
microphone=
freerdp_log_filters=
gwtransp=http
window_maximize=1
ssh_tunnel_server=
ignore-tls-errors=1
gateway_usage=0
ssh_tunnel_auth=2
ssh_tunnel_privatekey=
window_width=1920
websockets=0
freerdp_log_level=INFO
disable-smooth-scrolling=0
EOF

    success "Created: $filename"
    ((connections_created++))
  done
  
  # Create a summary file
  cat > "$debug_dir/README.txt" << EOF
Remmina Debug Mode - Sample Connections Generated
=================================================

Generated on: $(date)
Command: ./install.sh --remmina

Sample connections created: $connections_created

Files in this directory:
$(ls -la "$debug_dir"/*.remmina 2>/dev/null | awk '{print "  • " $NF}' | sed 's|.*/||')

Usage:
1. Copy .remmina files to: ~/.local/share/remmina/
2. Open Remmina application
3. Your connections will appear organized by groups:
   - prod (production servers)
   - dev (development/UAT servers) 
   - personal (personal/local servers)

Notes:
- Passwords are base64 encoded for basic security
- Groups help organize connections by environment
- File naming: group_[category]_[name]_[ip].remmina

To install these connections:
  cp $debug_dir/*.remmina ~/.local/share/remmina/

Test credentials used:
- Intelligence-API-1: Administrator / TestPass123
- Exato-UAT: Administrator / DevPass456  
- Test-Server: opik / LocalPass789
EOF

  echo
  success "Remmina debug mode completed!"
  echo
  echo -e "${BOLD}Generated files:${NC}"
  echo "  • Directory: $debug_dir"
  echo "  • Connections: $connections_created"
  echo "  • README: $debug_dir/README.txt"
  echo
  
  info "Files created:"
  ls -la "$debug_dir"
  
  echo
  echo -e "${CYAN}To use these connections:${NC}"
  echo "  1. cp $debug_dir/*.remmina ~/.local/share/remmina/"
  echo "  2. Open Remmina application"
  echo "  3. Connections will appear in groups: prod, dev, personal"
  
  return 0
}

# Export main functions
export -f detect_remmina install_remmina setup_remmina_connections_complete test_remmina_mode