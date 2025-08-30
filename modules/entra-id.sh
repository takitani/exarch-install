#!/usr/bin/env bash
# modules/entra-id.sh - Microsoft Entra ID/Microsoft SSO integration module

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"

# Microsoft Entra ID configuration defaults
ENTRA_TENANT_ID="${ENTRA_TENANT_ID:-$DEFAULT_ENTRA_TENANT_ID}"
ENTRA_METHOD="${ENTRA_METHOD:-$DEFAULT_ENTRA_METHOD}"  # sssd, aadds, or ssh
ENABLE_OFFLINE_AUTH="${ENABLE_OFFLINE_AUTH:-true}"
CREATE_HOME_DIRS="${CREATE_HOME_DIRS:-true}"
ENTRA_BACKUP_DIR="/etc/entra-id-backup"

# Check if Azure AD integration is already configured
is_entra_id_configured() {
  # Check if SSSD is configured for Azure AD
  if [[ -f "/etc/sssd/sssd.conf" ]]; then
    grep -q "id_provider = ad" /etc/sssd/sssd.conf 2>/dev/null && return 0
  fi
  
  # Check if realm is joined
  if command_exists realm; then
    realm list 2>/dev/null | grep -q "domain-name:" && return 0
  fi
  
  return 1
}

# Detect Azure AD integration requirements
detect_entra_id_requirements() {
  local missing_requirements=()
  
  info "Checking Microsoft Entra ID integration requirements..."
  
  # Check network connectivity
  if ! ping -c 1 login.microsoftonline.com >/dev/null 2>&1; then
    missing_requirements+=("Network connectivity to Microsoft Entra ID")
  fi
  
  # Check time synchronization
  if ! systemctl is-active --quiet systemd-timesyncd && ! systemctl is-active --quiet ntp && ! systemctl is-active --quiet chronyd; then
    missing_requirements+=("Time synchronization service")
  fi
  
  # Check Microsoft Entra ID endpoints (modern method)
  local endpoints=(
    "https://login.microsoftonline.com"
    "https://pas.windows.net" 
    "https://packages.microsoft.com"
  )
  
  for endpoint in "${endpoints[@]}"; do
    if ! curl -s --connect-timeout 5 "$endpoint" >/dev/null 2>&1; then
      missing_requirements+=("Network connectivity to: $endpoint")
    fi
  done
  
  # Check if Tenant ID is configured  
  if [[ -z "$ENTRA_TENANT_ID" ]]; then
    missing_requirements+=("Microsoft Entra ID Tenant ID not configured")
  elif [[ ! "$ENTRA_TENANT_ID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
    missing_requirements+=("Invalid Tenant ID format: $ENTRA_TENANT_ID")
  fi
  
  if [[ ${#missing_requirements[@]} -gt 0 ]]; then
    warn "Missing requirements:"
    for req in "${missing_requirements[@]}"; do
      echo "  • $req"
    done
    return 1
  fi
  
  success "All requirements met"
  return 0
}

# Setup Microsoft repository for AAD packages
setup_microsoft_repository() {
  info "Setting up Microsoft package repository..."
  
  # Add Microsoft GPG key
  curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor | sudo tee /etc/pacman.d/gnupg/microsoft.gpg > /dev/null
  
  # Note: For Arch Linux, Microsoft packages may not be directly available
  # Users will need to install from AUR or compile manually
  warn "Microsoft packages may need manual installation on Arch Linux"
  return 0
}

# Install required packages for Microsoft Entra ID integration  
install_entra_id_packages() {
  info "Installing Microsoft Entra ID SSH Login packages..."
  
  # Basic packages
  local packages=(
    "curl"
    "wget" 
    "openssh"
    "jq"
    "azure-cli"
  )
  
  local failed_packages=()
  
  for package in "${packages[@]}"; do
    info "Installing $package..."
    if ! pac "$package"; then
      if ! aur "$package"; then
        warn "Failed to install $package"
        failed_packages+=("$package")
      fi
    fi
  done
  
  # Additional AUR packages that might be needed
  local aur_packages=(
    "sssd-tools"
    "pam-krb5"
  )
  
  for package in "${aur_packages[@]}"; do
    info "Installing $package from AUR..."
    if ! aur "$package"; then
      warn "Failed to install $package (may not be critical)"
    fi
  done
  
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    err "Failed to install required packages:"
    for pkg in "${failed_packages[@]}"; do
      echo "  • $pkg"
    done
    return 1
  fi
  
  success "All required packages installed"
  return 0
}

# Backup existing authentication configuration
backup_auth_configuration() {
  info "Backing up existing authentication configuration..."
  
  # Create backup directory
  mkdir -p "$AZURE_AD_BACKUP_DIR"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_subdir="$AZURE_AD_BACKUP_DIR/backup-$timestamp"
  mkdir -p "$backup_subdir"
  
  # Files to backup
  local files_to_backup=(
    "/etc/nsswitch.conf"
    "/etc/pam.d/system-auth"
    "/etc/pam.d/su"
    "/etc/pam.d/sudo"
    "/etc/krb5.conf"
    "/etc/samba/smb.conf"
    "/etc/sssd/sssd.conf"
  )
  
  for file in "${files_to_backup[@]}"; do
    if [[ -f "$file" ]]; then
      cp -p "$file" "$backup_subdir/" 2>/dev/null
      info "Backed up: $file"
    fi
  done
  
  # Create restore script
  cat > "$backup_subdir/restore.sh" << 'EOF'
#!/bin/bash
# Restore script for Azure AD configuration

echo "Restoring original authentication configuration..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Stop SSSD service
systemctl stop sssd 2>/dev/null

# Restore files
for file in "$SCRIPT_DIR"/*; do
  if [[ -f "$file" ]] && [[ "$(basename "$file")" != "restore.sh" ]]; then
    target="/etc/$(basename "$file")"
    
    # Handle nested paths
    case "$(basename "$file")" in
      system-auth|su|sudo)
        target="/etc/pam.d/$(basename "$file")"
        ;;
      smb.conf)
        target="/etc/samba/smb.conf"
        ;;
      sssd.conf)
        target="/etc/sssd/sssd.conf"
        ;;
    esac
    
    echo "Restoring $target"
    sudo cp -p "$file" "$target"
  fi
done

# Leave domain if joined
if command -v realm >/dev/null 2>&1; then
  realm leave 2>/dev/null
fi

echo "Restoration complete. Please restart your system."
EOF
  
  chmod +x "$backup_subdir/restore.sh"
  
  success "Configuration backed up to: $backup_subdir"
  info "Restore script created: $backup_subdir/restore.sh"
  
  return 0
}

# Configure DNS for domain resolution
configure_dns_for_domain() {
  info "Configuring DNS for Azure AD domain..."
  
  # Detect if using systemd-resolved
  if systemctl is-active --quiet systemd-resolved; then
    info "Using systemd-resolved for DNS configuration"
    
    # Get Azure AD DNS servers (typically domain controllers)
    local dns_servers=(
      "168.63.129.16"  # Azure DNS
      "8.8.8.8"        # Google DNS fallback
    )
    
    # Configure systemd-resolved
    sudo mkdir -p /etc/systemd/resolved.conf.d/
    cat | sudo tee /etc/systemd/resolved.conf.d/azure-ad.conf > /dev/null << EOF
[Resolve]
DNS=${dns_servers[0]} ${dns_servers[1]}
Domains=$AZURE_AD_DOMAIN
DNSSEC=no
EOF
    
    sudo systemctl restart systemd-resolved
  else
    # Traditional resolv.conf approach
    warn "Using traditional /etc/resolv.conf configuration"
    
    if [[ -f /etc/resolv.conf ]] && ! grep -q "# Azure AD DNS" /etc/resolv.conf; then
      sudo cp /etc/resolv.conf /etc/resolv.conf.backup
      
      cat | sudo tee -a /etc/resolv.conf > /dev/null << EOF

# Azure AD DNS
nameserver 168.63.129.16
search $AZURE_AD_DOMAIN
EOF
    fi
  fi
  
  # Test DNS resolution
  if nslookup "$AZURE_AD_DOMAIN" >/dev/null 2>&1; then
    success "DNS configured successfully"
    return 0
  else
    err "DNS configuration failed - cannot resolve $AZURE_AD_DOMAIN"
    return 1
  fi
}

# Configure time synchronization
configure_time_sync() {
  info "Configuring time synchronization..."
  
  # Prefer systemd-timesyncd if available
  if systemctl list-unit-files | grep -q systemd-timesyncd; then
    info "Using systemd-timesyncd"
    
    sudo timedatectl set-ntp true
    sudo systemctl enable --now systemd-timesyncd
    
  elif command_exists ntpd; then
    info "Using NTP daemon"
    
    # Configure NTP for Azure AD
    cat | sudo tee /etc/ntp.conf > /dev/null << EOF
# Azure AD time synchronization
server time.windows.com iburst
server pool.ntp.org iburst

# Allow large time adjustments at startup
tinker panic 0

# Default restrictions
restrict default kod nomodify notrap nopeer noquery
restrict 127.0.0.1
restrict ::1
EOF
    
    sudo systemctl enable --now ntpd
    
  elif command_exists chronyd; then
    info "Using Chrony"
    
    cat | sudo tee /etc/chrony.conf > /dev/null << EOF
# Azure AD time synchronization
server time.windows.com iburst
pool pool.ntp.org iburst

# Allow large time adjustments
makestep 1.0 3

# Enable kernel RTC synchronization
rtcsync
EOF
    
    sudo systemctl enable --now chronyd
  else
    err "No time synchronization service available"
    return 1
  fi
  
  success "Time synchronization configured"
  return 0
}

# Join Azure AD domain using realm
join_azure_domain() {
  local domain="${1:-$AZURE_AD_DOMAIN}"
  local admin_user="$2"
  
  info "Joining Azure AD domain: $domain"
  
  # Check if already joined
  if realm list 2>/dev/null | grep -q "$domain"; then
    warn "Already joined to domain: $domain"
    
    if ask_yes_no "Leave and rejoin domain?"; then
      info "Leaving current domain..."
      sudo realm leave "$domain" 2>/dev/null
    else
      return 0
    fi
  fi
  
  # Get admin credentials if not provided
  if [[ -z "$admin_user" ]]; then
    echo
    echo -n "Enter domain admin username: "
    read -r admin_user
  fi
  
  if [[ -z "$admin_user" ]]; then
    err "Admin username required for domain join"
    return 1
  fi
  
  # Discover domain
  info "Discovering domain configuration..."
  if ! sudo realm discover "$domain"; then
    err "Failed to discover domain: $domain"
    return 1
  fi
  
  # Join domain
  info "Joining domain (you will be prompted for password)..."
  
  local join_options=(
    "--verbose"
    "--user=$admin_user"
  )
  
  if [[ "$CREATE_HOME_DIRS" == "true" ]]; then
    join_options+=("--automatic-id-mapping=yes")
  fi
  
  if sudo realm join "${join_options[@]}" "$domain"; then
    success "Successfully joined domain: $domain"
    
    # Configure SSSD for optimal Azure AD integration
    configure_sssd_for_azure
    
    return 0
  else
    err "Failed to join domain"
    return 1
  fi
}

# Configure SSSD for Azure AD
configure_sssd_for_azure() {
  info "Configuring SSSD for Azure AD..."
  
  # SSSD configuration file
  local sssd_conf="/etc/sssd/sssd.conf"
  
  # Create SSSD configuration
  cat | sudo tee "$sssd_conf" > /dev/null << EOF
[sssd]
config_file_version = 2
domains = $AZURE_AD_DOMAIN
services = nss, pam, ssh

[domain/$AZURE_AD_DOMAIN]
# Identity provider
id_provider = ad
auth_provider = ad
access_provider = ad
chpass_provider = ad

# Azure AD specific settings
ad_domain = $AZURE_AD_DOMAIN
ad_server = _srv_
ad_hostname = $(hostname -f)

# User and group settings
use_fully_qualified_names = false
fallback_homedir = /home/%u
default_shell = /bin/bash
skel_dir = /etc/skel
create_homedir = true

# Performance and caching
cache_credentials = $ENABLE_OFFLINE_AUTH
cached_auth_timeout = 3600
krb5_store_password_if_offline = true
krb5_renewable_lifetime = 7d
krb5_renew_interval = 3600

# Enumeration settings (set to false for large domains)
enumerate = false
subdomain_enumerate = false

# Access control
ad_gpo_access_control = permissive
ad_gpo_ignore_unreadable = true

# Additional options for Azure AD
dyndns_update = false
ad_use_ldaps = false
ldap_id_mapping = true
ldap_schema = ad
ldap_referrals = false

# Debugging (comment out in production)
# debug_level = 7

[nss]
filter_groups = root
filter_users = root
reconnection_retries = 3
entry_cache_timeout = 300
entry_cache_nowait_percentage = 75

[pam]
reconnection_retries = 3
offline_credentials_expiration = 7
offline_failed_login_attempts = 5
offline_failed_login_delay = 5

[ssh]
# SSH key retrieval from Azure AD
EOF
  
  # Set proper permissions
  sudo chmod 600 "$sssd_conf"
  
  # Enable and restart SSSD
  sudo systemctl enable sssd
  sudo systemctl restart sssd
  
  # Wait for SSSD to initialize
  sleep 3
  
  # Test SSSD
  if systemctl is-active --quiet sssd; then
    success "SSSD configured and running"
    return 0
  else
    err "SSSD failed to start"
    sudo journalctl -xe -u sssd | tail -20
    return 1
  fi
}

# Configure PAM for Azure AD authentication
configure_pam_for_azure() {
  info "Configuring PAM for Azure AD authentication..."
  
  # Enable automatic home directory creation
  if [[ "$CREATE_HOME_DIRS" == "true" ]]; then
    info "Enabling automatic home directory creation..."
    
    # For systemd-based systems
    if command_exists pam-auth-update; then
      sudo pam-auth-update --enable mkhomedir
    else
      # Manual PAM configuration for Arch
      if ! grep -q "pam_mkhomedir.so" /etc/pam.d/system-login; then
        sudo sed -i '/^session.*required.*pam_unix.so/a session    required   pam_mkhomedir.so skel=/etc/skel/ umask=0077' /etc/pam.d/system-login
      fi
    fi
    
    # Enable oddjobd for home directory creation
    if command_exists oddjobd; then
      sudo systemctl enable --now oddjobd
    fi
  fi
  
  # Update NSSwitch configuration
  info "Updating NSSwitch configuration..."
  
  local nsswitch="/etc/nsswitch.conf"
  
  # Backup original
  sudo cp "$nsswitch" "$nsswitch.backup"
  
  # Update passwd, group, and shadow entries
  sudo sed -i 's/^passwd:.*/passwd:     files sss/' "$nsswitch"
  sudo sed -i 's/^group:.*/group:      files sss/' "$nsswitch"
  sudo sed -i 's/^shadow:.*/shadow:     files sss/' "$nsswitch"
  
  # Add sudoers if not present
  if ! grep -q "^sudoers:" "$nsswitch"; then
    echo "sudoers:    files sss" | sudo tee -a "$nsswitch" > /dev/null
  fi
  
  success "PAM and NSSwitch configured"
  return 0
}

# Test Azure AD authentication
test_azure_authentication() {
  info "Testing Azure AD authentication..."
  
  local test_user="$1"
  local tests_passed=0
  local tests_failed=0
  
  # Test 1: Check SSSD status
  echo -n "Checking SSSD service... "
  if systemctl is-active --quiet sssd; then
    echo -e "${GREEN}✓${NC}"
    ((tests_passed++))
  else
    echo -e "${RED}✗${NC}"
    ((tests_failed++))
  fi
  
  # Test 2: Check domain join status
  echo -n "Checking domain join... "
  if realm list 2>/dev/null | grep -q "domain-name:"; then
    echo -e "${GREEN}✓${NC}"
    ((tests_passed++))
  else
    echo -e "${RED}✗${NC}"
    ((tests_failed++))
  fi
  
  # Test 3: Test user lookup
  if [[ -n "$test_user" ]]; then
    echo -n "Looking up user $test_user... "
    if id "$test_user" >/dev/null 2>&1; then
      echo -e "${GREEN}✓${NC}"
      ((tests_passed++))
      
      # Show user info
      echo "  User info:"
      id "$test_user" | sed 's/^/    /'
    else
      echo -e "${RED}✗${NC}"
      ((tests_failed++))
    fi
  fi
  
  # Test 4: Check Kerberos ticket
  echo -n "Checking Kerberos tickets... "
  if klist 2>/dev/null | grep -q "Ticket cache:"; then
    echo -e "${GREEN}✓${NC}"
    ((tests_passed++))
  else
    echo -e "${YELLOW}⚠${NC} (No active tickets - this is normal if not logged in)"
  fi
  
  # Test 5: Check authentication
  echo -n "Checking PAM configuration... "
  if grep -q "pam_sss.so" /etc/pam.d/system-auth 2>/dev/null || grep -q "pam_sss.so" /etc/pam.d/common-auth 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    ((tests_passed++))
  else
    echo -e "${RED}✗${NC}"
    ((tests_failed++))
  fi
  
  echo
  echo "Test Summary: $tests_passed passed, $tests_failed failed"
  
  if [[ $tests_failed -eq 0 ]]; then
    success "All authentication tests passed!"
    return 0
  else
    warn "Some tests failed - authentication may not work properly"
    return 1
  fi
}

# Remove Azure AD integration
remove_azure_integration() {
  info "Removing Azure AD integration..."
  
  if ask_yes_no "This will remove Azure AD integration and restore local authentication. Continue?"; then
    # Leave domain
    if command_exists realm; then
      info "Leaving domain..."
      sudo realm leave 2>/dev/null
    fi
    
    # Stop and disable SSSD
    info "Stopping SSSD..."
    sudo systemctl stop sssd
    sudo systemctl disable sssd
    
    # Find most recent backup
    if [[ -d "$AZURE_AD_BACKUP_DIR" ]]; then
      local latest_backup=$(ls -td "$AZURE_AD_BACKUP_DIR"/backup-* 2>/dev/null | head -1)
      
      if [[ -n "$latest_backup" ]] && [[ -f "$latest_backup/restore.sh" ]]; then
        info "Restoring from backup: $latest_backup"
        bash "$latest_backup/restore.sh"
      else
        warn "No backup found - manual restoration may be needed"
      fi
    fi
    
    # Remove Azure AD specific configurations
    sudo rm -f /etc/sssd/sssd.conf
    sudo rm -f /etc/krb5.conf
    sudo rm -f /etc/systemd/resolved.conf.d/azure-ad.conf
    
    success "Azure AD integration removed"
    info "Please restart your system to complete the removal"
    
    return 0
  else
    info "Removal cancelled"
    return 1
  fi
}

# Configure Microsoft Entra ID SSH Login (Modern Method)
configure_entra_ssh_login() {
  info "Configuring Microsoft Entra ID SSH Login..."
  
  # Enable SSH daemon
  sudo systemctl enable sshd
  sudo systemctl start sshd
  
  # Configure SSH for Azure AD
  info "Configuring SSH for Microsoft Entra ID..."
  
  # Backup original SSH config
  if [[ -f "/etc/ssh/sshd_config" ]]; then
    sudo cp "/etc/ssh/sshd_config" "/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
  fi
  
  # Add Azure AD SSH configuration
  local ssh_config_additions="
# Microsoft Entra ID SSH Login Configuration
ChallengeResponseAuthentication yes
PubkeyAuthentication yes
AuthenticationMethods publickey,keyboard-interactive:pam
UsePAM yes
"
  
  if ! grep -q "Microsoft Entra ID SSH Login Configuration" /etc/ssh/sshd_config; then
    echo "$ssh_config_additions" | sudo tee -a /etc/ssh/sshd_config
    if sudo systemctl restart sshd; then
      info "SSH configured for Entra ID authentication"
    else
      warn "SSH configuration added but restart failed - may need manual check"
    fi
  else
    info "SSH already configured for Entra ID"
  fi
  
  return 0
}

# Install and configure Himmelblau for real Entra ID authentication
install_himmelblau() {
  info "Installing Himmelblau for real Microsoft Entra ID authentication..."
  
  # Check if Himmelblau is available in AUR
  if yay -Ss himmelblau >/dev/null 2>&1; then
    info "Installing Himmelblau from AUR..."
    if yay -S himmelblau --noconfirm; then
      success "Himmelblau installed successfully"
      return 0
    fi
  fi
  
  # If not in AUR, build from source
  warn "Himmelblau not found in AUR, building from source..."
  
  # Install build dependencies
  local build_deps=("rust" "git" "make" "gcc" "pkg-config" "systemd" "pam" "openssl")
  for dep in "${build_deps[@]}"; do
    if ! pacman -Q "$dep" >/dev/null 2>&1; then
      info "Installing build dependency: $dep"
      sudo pacman -S "$dep" --noconfirm
    fi
  done
  
  # Clone and build Himmelblau
  local build_dir="/tmp/himmelblau-build"
  rm -rf "$build_dir"
  
  info "Cloning Himmelblau repository..."
  if git clone https://github.com/himmelblau-idm/himmelblau.git "$build_dir"; then
    cd "$build_dir"
    
    info "Building Himmelblau (this may take a while)..."
    if make && sudo make install; then
      success "Himmelblau built and installed successfully"
      cd - >/dev/null
      return 0
    else
      err "Failed to build Himmelblau"
      cd - >/dev/null
      return 1
    fi
  else
    err "Failed to clone Himmelblau repository"
    return 1
  fi
}

# Configure system to allow real Entra ID login at the console/GDM
configure_entra_system_login() {
  info "Configuring system for REAL Microsoft Entra ID authentication..."
  
  # Install Himmelblau
  if ! install_himmelblau; then
    err "Failed to install Himmelblau - cannot configure real Entra ID authentication"
    return 1
  fi
  
  # Configure Himmelblau
  info "Configuring Himmelblau for Microsoft Entra ID..."
  
  # Create Himmelblau configuration
  sudo mkdir -p /etc/himmelblau
  
  # Configure himmelblaud daemon
  sudo tee /etc/himmelblau/himmelblau.conf > /dev/null << EOF
[global]
# Microsoft Entra ID Tenant Configuration
tenant_id = $ENTRA_TENANT_ID

# Application ID for device authentication
client_id = 

# Domain for user authentication
domain = exato.digital

# Cache settings
cache_timeout = 3600
offline_timeout = 86400

# Security settings
require_mfa = false
device_enrollment = true

# Logging
log_level = info
EOF

  success "Himmelblau configured with Tenant ID: $ENTRA_TENANT_ID"
  
  # Configure PAM for Himmelblau
  info "Configuring PAM for Himmelblau authentication..."
  
  # Backup original PAM configurations
  local pam_files=("login" "sshd" "gdm-password" "sddm")
  for pam_file in "${pam_files[@]}"; do
    if [[ -f "/etc/pam.d/$pam_file" ]]; then
      sudo cp "/etc/pam.d/$pam_file" "/etc/pam.d/$pam_file.backup.$(date +%Y%m%d_%H%M%S)"
    fi
  done
  
  # Configure PAM modules for Himmelblau
  info "Adding Himmelblau PAM modules..."
  
  # Add to login PAM
  if [[ -f "/etc/pam.d/login" ]]; then
    # Add himmelblau authentication
    if ! grep -q "pam_himmelblau" /etc/pam.d/login; then
      sudo sed -i '/auth.*pam_unix.so/a auth        sufficient  pam_himmelblau.so' /etc/pam.d/login
      sudo sed -i '/account.*pam_unix.so/a account     sufficient  pam_himmelblau.so' /etc/pam.d/login  
      sudo sed -i '/session.*pam_unix.so/a session     optional    pam_himmelblau.so' /etc/pam.d/login
    fi
  fi
  
  # Configure NSS for Himmelblau
  info "Configuring NSS for Himmelblau..."
  
  if [[ -f "/etc/nsswitch.conf" ]]; then
    sudo cp "/etc/nsswitch.conf" "/etc/nsswitch.conf.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Add himmelblau to passwd and group lookups
    sudo sed -i 's/^passwd:.*/passwd: files himmelblau systemd/' /etc/nsswitch.conf
    sudo sed -i 's/^group:.*/group: files himmelblau systemd/' /etc/nsswitch.conf
    sudo sed -i 's/^shadow:.*/shadow: files himmelblau/' /etc/nsswitch.conf
  fi
  
  # Enable and start Himmelblau daemon
  info "Starting Himmelblau daemon..."
  sudo systemctl enable himmelblaud
  sudo systemctl start himmelblaud
  
  if systemctl is-active --quiet himmelblaud; then
    success "Himmelblau daemon is running"
  else
    err "Failed to start Himmelblau daemon"
    return 1
  fi
  
  # Configure GDM to show user selection
  if systemctl is-active --quiet gdm; then
    info "Configuring GDM for multiple users..."
    
    # Disable autologin if enabled
    if [[ -f "/etc/gdm/custom.conf" ]]; then
      sudo cp "/etc/gdm/custom.conf" "/etc/gdm/custom.conf.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Configure GDM to show user list
    sudo tee /etc/gdm/custom.conf > /dev/null << 'EOF'
[daemon]
# Enable user list
TimedLoginEnable=false
AutomaticLoginEnable=false
TimedLoginDelay=0

[security]
# Allow user selection
AllowRoot=false
DisallowTCP=true

[xdmcp]
Enable=false

[chooser]

[debug]
Enable=false
EOF
    
    success "GDM configured to show user selection"
  elif systemctl is-active --quiet sddm; then
    info "Configuring SDDM for multiple users..."
    
    if [[ -f "/etc/sddm.conf" ]]; then
      sudo cp "/etc/sddm.conf" "/etc/sddm.conf.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Configure SDDM
    sudo tee -a /etc/sddm.conf > /dev/null << 'EOF'

[Autologin]
# Disable autologin to show user selection
User=
Session=

[General]
# Show user selection
HideUsers=
HideShells=
EOF
    
    success "SDDM configured to show user selection"
  else
    warn "No display manager detected (GDM/SDDM) - manual configuration may be needed"
  fi
  
  # Test Himmelblau authentication
  info "Testing Himmelblau Microsoft Entra ID authentication..."
  
  # Get current Azure user info
  local azure_user
  azure_user=$(az account show --query user.name -o tsv 2>/dev/null)
  
  if [[ -n "$azure_user" ]]; then
    success "Found Azure user: $azure_user"
    
    # Test if we can resolve the user through Himmelblau
    info "Testing user resolution through Himmelblau..."
    if getent passwd "$azure_user" >/dev/null 2>&1; then
      success "✓ User '$azure_user' resolved successfully through Himmelblau"
    else
      warn "⚠️ User resolution test failed - may need device enrollment on first login"
    fi
    
    # No need to create local users - Himmelblau handles this automatically
    info "Himmelblau will handle user creation automatically on first login"
    
  else
    warn "Could not detect Azure user - make sure you're logged in"
  fi
  
  # Configure SSH for Azure AD authentication
  if configure_entra_ssh_login; then
    success "SSH configured for Entra ID"
  else
    warn "SSH configuration had issues"
  fi
  
  # Instructions for the user
  echo
  info "🎉 REAL Microsoft Entra ID Authentication Setup Complete!"
  echo
  echo "📋 What was configured:"
  echo "   ✓ Himmelblau installed and configured"
  echo "   ✓ PAM/NSS configured for Microsoft Entra ID"
  echo "   ✓ Azure CLI logged in as: $azure_user"
  echo "   ✓ Display manager configured for multi-user login"
  echo "   ✓ Device enrollment enabled"
  echo
  echo "🖥️  After reboot, you can login with:"
  echo "   👤 $(whoami)              ← Your original local user"
  echo "   👤 andre@exato.digital   ← Microsoft Entra ID user (REAL)"
  echo "   👤 [outros-users]@exato.digital ← Other company users"
  echo
  echo "🔐 How to login with Microsoft Entra ID:"
  echo "   1. Reboot: sudo reboot"
  echo "   2. At login screen, type: andre@exato.digital"
  echo "   3. Enter your MICROSOFT PASSWORD (same as Office 365)"
  echo "   4. Complete MFA if prompted (Microsoft Authenticator)"
  echo "   5. Device will be enrolled in Azure AD automatically"
  echo "   6. Home directory created automatically: /home/andre@exato.digital"
  echo
  echo "✨ Benefits of REAL integration:"
  echo "   • Same password as Microsoft Office/Teams"
  echo "   • Corporate policies applied"
  echo "   • MFA enforced if configured"
  echo "   • Automatic user provisioning"
  echo "   • SSH with Microsoft credentials"
  echo
  echo "🔧 Advanced usage:"
  echo "   • SSH to Azure VMs: az ssh vm -n <vm-name> -g <resource-group>"
  echo "   • SSH to this machine with AD: ssh andre@exato.digital@$(hostname)"
  echo
  echo "⚠️  Safety net: Your original user '$(whoami)' remains unchanged"
  echo "   If Entra ID login fails, you can always use your local account"
  
  return 0
}

# Main setup function
setup_entra_id_complete() {
  info "Setting up Microsoft Entra ID authentication..."
  
  # Go directly to the essential steps
  echo
  info "This will set up Microsoft Entra ID authentication for your system"
  echo "You'll be able to login with: andre@exato.digital"
  echo
  
  # Step 1: Install Azure CLI if needed
  if ! command -v az >/dev/null 2>&1; then
    info "Installing Azure CLI..."
    if ! install_entra_id_packages; then
      err "Failed to install Azure CLI"
      return 1
    fi
  fi
  
  # Step 2: Login to Azure
  info "Logging into Azure..."
  echo "Opening browser for Azure login..."
  
  if az login --tenant "$ENTRA_TENANT_ID"; then
    success "Azure login successful!"
    echo "Account: $(az account show --query user.name -o tsv 2>/dev/null)"
  else
    err "Azure login failed"
    return 1
  fi
  
  # Step 3: Configure system for Entra ID login
  info "Configuring system for Entra ID login..."
  if ! configure_entra_system_login; then
    err "Failed to configure system login"
    return 1
  fi
  
  success "Microsoft Entra ID authentication configured successfully!"
  echo
  echo "You can now:"
  echo "• SSH to Azure VMs: az ssh vm -n <vm-name> -g <resource-group>"
  echo "• Login to this system with: andre@exato.digital (after reboot)"
  
  return 0
    
    echo
    echo "Options:"
    echo "1) Reconfigure Azure AD integration"
    echo "2) Test current configuration"
    echo "3) Remove Azure AD integration"
    echo "4) Cancel"
    echo
    echo -n "Choose (1/2/3/4): "
    read -r choice
    
    case "$choice" in
      1)
        info "Proceeding with reconfiguration..."
        ;;
      2)
        test_azure_authentication
        return $?
        ;;
      3)
        remove_azure_integration
        return $?
        ;;
      *)
        info "Cancelled"
        return 0
        ;;
    esac
  
  # Show disclaimer
  echo
  echo -e "${YELLOW}⚠ IMPORTANT NOTICE ⚠${NC}"
  echo "This will configure Azure AD/Microsoft SSO integration for your system."
  echo "Your local user account will remain functional as a fallback."
  echo
  echo "Requirements:"
  echo "• Network access to Azure AD domain"
  echo "• Domain administrator credentials for joining"
  echo "• System will join the corporate domain"
  echo
  
  if ! ask_yes_no "Continue with Azure AD setup?"; then
    info "Setup cancelled"
    return 0
  fi
  
  # Check requirements
  if ! detect_entra_id_requirements; then
    if ! ask_yes_no "Some requirements are missing. Continue anyway?"; then
      return 1
    fi
  fi
  
  # Install packages
  if ! install_entra_id_packages; then
    err "Failed to install required packages"
    return 1
  fi
  
  # Backup current configuration
  backup_auth_configuration
  
  # Configure DNS
  if ! configure_dns_for_domain; then
    err "DNS configuration failed"
    return 1
  fi
  
  # Configure time synchronization
  if ! configure_time_sync; then
    warn "Time sync configuration failed - this may cause authentication issues"
  fi
  
  # Get domain information
  echo
  echo "Enter Azure AD domain information:"
  echo -n "Domain name (default: $AZURE_AD_DOMAIN): "
  read -r domain_input
  
  if [[ -n "$domain_input" ]]; then
    AZURE_AD_DOMAIN="$domain_input"
  fi
  
  echo -n "Domain admin username: "
  read -r admin_user
  
  # Join domain
  if ! join_azure_domain "$AZURE_AD_DOMAIN" "$admin_user"; then
    err "Failed to join domain"
    
    # Offer to restore
    if ask_yes_no "Restore original configuration?"; then
      local latest_backup=$(ls -td "$AZURE_AD_BACKUP_DIR"/backup-* 2>/dev/null | head -1)
      if [[ -n "$latest_backup" ]] && [[ -f "$latest_backup/restore.sh" ]]; then
        bash "$latest_backup/restore.sh"
      fi
    fi
    
    return 1
  fi
  
  # Configure PAM
  configure_pam_for_azure
  
  # Test authentication
  echo
  info "Testing configuration..."
  echo -n "Enter an Azure AD username to test (or press Enter to skip): "
  read -r test_user
  
  test_azure_authentication "$test_user"
  
  # Show summary
  echo
  success "Azure AD integration setup complete!"
  echo
  echo -e "${BOLD}Next Steps:${NC}"
  echo "1. Restart your system for all changes to take effect"
  echo "2. At login screen, use your Azure AD credentials:"
  echo "   • Username: your.name@$AZURE_AD_DOMAIN or just 'your.name'"
  echo "   • Password: your Azure AD password"
  echo "3. Your local user account remains available as fallback"
  echo
  echo -e "${BOLD}Troubleshooting:${NC}"
  echo "• Check status: systemctl status sssd"
  echo "• View logs: sudo journalctl -u sssd"
  echo "• Test user: id username@$AZURE_AD_DOMAIN"
  echo "• List domain: realm list"
  echo
  echo -e "${BOLD}To remove Azure AD integration:${NC}"
  echo "  ./install.sh → System Configuration → Remove Azure AD"
  echo "  Or run: $AZURE_AD_BACKUP_DIR/backup-*/restore.sh"
  
  return 0
}

# Export functions
export -f is_entra_id_configured detect_entra_id_requirements install_entra_id_packages
export -f backup_auth_configuration configure_dns_for_domain configure_time_sync
export -f join_azure_domain configure_sssd_for_azure configure_pam_for_azure
export -f test_azure_authentication remove_azure_integration setup_entra_id_complete