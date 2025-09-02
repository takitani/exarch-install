#!/usr/bin/env bash
# modules/1password.sh - Complete 1Password integration module

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/config-manager.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/remmina.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/remmina.sh"

# Environment variables to control 1Password behavior (set per function when needed)
# Note: These are NOT exported globally to avoid breaking desktop integration
# OP_BIOMETRIC_UNLOCK_ENABLED=false  # Prevent biometric prompts (CLI-only mode)
# OP_DEVICE=false  # Prevent device authentication (CLI-only mode)
export ONEPASSWORD_CLI_ONLY="${ONEPASSWORD_CLI_ONLY:-false}"  # CLI-only mode flag

# 1Password CLI Installation and Setup
install_1password_cli() {
  info "Installing 1Password CLI..."
  
  if command_exists op; then
    info "1Password CLI already installed"
    return 0
  fi
  
  if aur 1password-cli; then
    success "1Password CLI installed successfully"
    return 0
  else
    err "Failed to install 1Password CLI automatically"
    echo "   Install manually:"
    echo "   - Via AUR: yay -S 1password-cli"
    echo "   - Or download from: https://1password.com/downloads/command-line/"
    return 1
  fi
}

# Check if 1Password desktop app is installed
detect_1password_desktop() {
  local desktop_paths=(
    "/usr/bin/1password"
    "/usr/local/bin/1password"
    "/opt/1Password/1password"
    "$HOME/.local/bin/1password"
  )
  
  for path in "${desktop_paths[@]}"; do
    if [[ -f "$path" ]] || [[ -d "$path" ]]; then
      return 0
    fi
  done
  
  # Check via package managers
  if is_pacman_installed 1password || is_aur_installed 1password; then
    return 0
  fi
  
  # Check flatpak
  if command_exists flatpak && flatpak list 2>/dev/null | grep -q "com.onepassword.OnePassword"; then
    return 0
  fi
  
  return 1
}

# Install 1Password desktop app
install_1password_desktop() {
  info "Installing 1Password desktop app..."
  
  if detect_1password_desktop; then
    info "1Password desktop already installed"
    return 0
  fi
  
  if aur 1password; then
    success "1Password desktop installed via AUR"
    return 0
  else
    warn "Failed to install 1Password desktop automatically"
    echo "Alternative installation methods:"
    echo -e "• Via Flatpak: ${CYAN}flatpak install com.onepassword.OnePassword${NC}"
    echo -e "• Via AUR manually: ${CYAN}yay -S 1password${NC}"
    return 1
  fi
}

# Open 1Password desktop app
open_1password_desktop() {
  info "Opening 1Password desktop app..."
  
  if command_exists 1password; then
    nohup 1password >/dev/null 2>&1 & disown
    return 0
  fi
  
  # Try via flatpak
  if command_exists flatpak && flatpak list 2>/dev/null | grep -q "com.onepassword.OnePassword"; then
    nohup flatpak run com.onepassword.OnePassword >/dev/null 2>&1 & disown
    return 0
  fi
  
  # Try via xdg-open
  if xdg-open "1password://" 2>/dev/null; then
    return 0
  fi
  
  warn "Could not open 1Password desktop automatically"
  return 1
}

# Check 1Password CLI account status
check_1password_status() {
  # First check if CLI can actually list accounts with real data (desktop integration)
  local account_output
  account_output=$(timeout 5 op account list 2>&1)
  local account_exit=$?
  
  if [[ $account_exit -eq 0 ]] && [[ -n "$account_output" ]] && echo "$account_output" | grep -q "@"; then
    # Has real account data, now check vault access
    local vault_test
    vault_test=$(timeout 10 op vault list 2>&1)
    local vault_exit=$?
    
    # Debug output for troubleshooting
    if [[ ${DEBUG_1PASS:-false} == true ]]; then
      echo "DEBUG: account_output='$account_output'" >&2
      echo "DEBUG: vault_exit=$vault_exit" >&2
      echo "DEBUG: vault_test='$vault_test'" >&2
    fi
    
    if [[ $vault_exit -eq 0 ]]; then
      echo "authenticated"
    else
      echo "configured_not_logged_in"
    fi
  elif [[ $account_exit -eq 0 ]]; then
    # CLI responds but no real account data - this means not configured
    if [[ ${DEBUG_1PASS:-false} == true ]]; then
      echo "DEBUG: CLI responds but no account data: '$account_output'" >&2
    fi
    echo "not_configured"
  else
    # Check for traditional config file (manual configuration)
    local config_file="$HOME/.config/op/config"
    if [[ -f "$config_file" ]] && [[ -s "$config_file" ]] && grep -q '"accounts":' "$config_file" && ! grep -q '"accounts": null' "$config_file"; then
      if timeout 10 op vault list >/dev/null 2>&1; then
        echo "authenticated"
      else
        echo "configured_not_logged_in"
      fi
    else
      echo "not_configured"
    fi
  fi
}

# 1Password CLI signin
signin_1password_cli() {
  info "Signing in to 1Password..."
  
  local account_id=""
  if timeout 3 op account list --format=json >/dev/null 2>&1; then
    account_id=$(timeout 3 op account list --format=json 2>/dev/null | jq -r '.[0].shorthand' 2>/dev/null || echo "")
  fi
  
  if [[ -n "$account_id" ]]; then
    if eval "$(op signin --account "$account_id")"; then
      success "Successfully signed in to 1Password"
      return 0
    fi
  else
    if eval "$(op signin)"; then
      success "Successfully signed in to 1Password"
      return 0
    fi
  fi
  
  err "Failed to sign in to 1Password"
  return 1
}

# Mobile + Desktop hybrid flow configuration
configure_1password_mobile_desktop() {
  info "1Password Mobile + Desktop Flow Configuration..."
  echo
  
  # Step 1: Ensure desktop app is installed
  echo -e "${BOLD}Step 1: Configure 1Password Desktop${NC}"
  echo
  
  if ! detect_1password_desktop; then
    warn "1Password desktop is not installed."
    echo
    echo "To use the mobile flow, you need to install it first:"
    echo -e "• Via AUR: ${CYAN}yay -S 1password${NC}"
    echo -e "• Via Flatpak: ${CYAN}flatpak install com.onepassword.OnePassword${NC}"
    echo
    
    if ask_yes_no "Install automatically via AUR?"; then
      if install_1password_desktop; then
        success "1Password desktop installed"
      else
        err "Automatic installation failed. Please install manually and try again."
        return 1
      fi
    else
      err "Please install manually and try again"
      return 1
    fi
  else
    success "1Password desktop detected"
  fi
  
  # Step 2: Mobile setup instructions
  echo
  echo -e "${BOLD}Step 2: Configure on Mobile${NC}"
  echo
  echo "On your mobile phone (1Password app):"
  echo "1. Open 1Password on your phone"
  echo "2. Tap on the account icon (top right corner)"
  echo -e "3. Tap on ${BOLD}'Set up another device'${NC}"
  echo -e "4. Choose ${BOLD}'Scan QR Code'${NC}"
  echo
  echo "Press ENTER when ready to continue..."
  read -r
  
  # Step 3: Open desktop app
  echo
  echo -e "${BOLD}Step 3: Open 1Password Desktop${NC}"
  echo
  
  if open_1password_desktop; then
    success "1Password desktop is opening..."
    sleep 2
  else
    info "Please open 1Password desktop manually"
  fi
  
  echo
  echo "In the 1Password desktop app that opened:"
  echo -e "1. Click on ${BOLD}'Sign in with QR Code'${NC}"
  echo "2. A QR code will appear on screen"
  echo "3. On your phone, point the camera at the QR code"
  echo "4. Confirm on your phone when prompted"
  echo
  echo "Press ENTER when you're done configuring..."
  read -r
  
  # Step 4: Enable CLI integration
  echo
  echo -e "${BOLD}Step 4: Enable CLI Integration${NC}"
  echo
  echo "Now in 1Password desktop:"
  echo -e "1. Go to ${BOLD}Settings/Preferences${NC} (gear icon)"
  echo -e "2. Click on the ${BOLD}Developer${NC} tab"
  echo -e "3. Enable ${BOLD}'Integrate with 1Password CLI'${NC}"
  echo -e "4. ${YELLOW}IMPORTANT:${NC} If no prompt appears, try running a command to trigger it:"
  echo -e "   Open a terminal and run: ${CYAN}op account list${NC}"
  echo -e "5. You should see an authorization prompt in 1Password desktop"
  echo -e "6. Click ${BOLD}'Allow'${NC} or ${BOLD}'Authorize'${NC} when prompted"
  echo
  echo "Press ENTER when finished..."
  read -r
  
  # Test integration
  echo
  info "Testing integration..."
  if timeout 5 op account list >/dev/null 2>&1; then
    success "Integration working!"
    
    # Test login
    if timeout 10 op vault list >/dev/null 2>&1; then
      success "Automatic login working!"
    else
      warn "Desktop integration enabled but vault access failed"
      echo "This usually means the desktop app needs to be unlocked"
      echo "Please unlock 1Password desktop app and try again"
      return 1
    fi
    
    return 0
  else
    err "Integration not detected"
    echo "Please verify you followed all steps"
    return 1
  fi
}

# CLI direct configuration
configure_1password_cli_direct() {
  info "Direct CLI Configuration (CLI-only mode)..."
  echo
  
  # Enable CLI-only mode to prevent desktop app from opening
  export ONEPASSWORD_CLI_ONLY=true
  export OP_BIOMETRIC_UNLOCK_ENABLED=false
  export OP_DEVICE=false
  
  echo "You need one of the following:"
  echo -e "• ${BOLD}Emergency Kit${NC} with Setup Code (starts with A3-)"
  echo -e "• ${BOLD}Account data${NC}: URL, email and Secret Key"
  echo
  echo "What do you have?"
  echo "1) Setup Code from Emergency Kit"
  echo "2) Complete data (URL, email, Secret Key)"
  echo "3) I don't have any of these"
  echo "4) Cancel configuration"
  echo
  echo -n "Choose (1/2/3/4): "
  read -r config_type
  
  case "$config_type" in
    1)
      echo
      info "Emergency Kit Setup Code"
      echo
      echo -e "${BOLD}How to find in mobile app:${NC}"
      echo "1. Open 1Password on your phone"
      echo "2. Tap on account (top)"
      echo -e "3. Tap on ${BOLD}'Get Setup Code'${NC} or ${BOLD}'Emergency Kit'${NC}"
      echo "4. Copy the code that starts with A3-"
      echo
      echo "Format: ${CYAN}A3-XXXXXX-XXXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX${NC}"
      echo
      info "Enter or paste the Setup Code:"
      
      # Use pre-configured URL if available
      if [[ -n "${ONEPASSWORD_URL:-}" ]]; then
        # Clean URL format - remove https:// and trailing slashes
        local clean_url="${ONEPASSWORD_URL}"
        clean_url="${clean_url#https://}"
        clean_url="${clean_url#http://}"
        clean_url="${clean_url%/}"
        
        echo "Using pre-configured URL: ${clean_url}"
        echo -n "Enter the email address for your account on ${clean_url}: "
        read -r email
        
        # Let user paste the Setup Code and op will extract the Secret Key
        if op account add --address "${clean_url}" --email "${email}"; then
          success "Account added via Setup Code!"
          return 0
        else
          err "Failed to add account. Check your Setup Code and network connection."
          echo "The URL might be incorrect or your network might be blocking the connection."
          return 1
        fi
      else
        echo "Enter your 1Password account URL when prompted (e.g. company.1password.com)"
        if op account add; then
          success "Account added via Setup Code!"
          return 0
        else
          err "Failed to add account"
          return 1
        fi
      fi
      ;;
      
    2)
      echo
      info "Enter account data:"
      echo
      
      # Use URL from .env if available
      local url="${ONEPASSWORD_URL:-}"
      if [[ -n "$url" ]]; then
        # Clean URL format - remove https:// and trailing slashes
        url="${url#https://}"
        url="${url#http://}"
        url="${url%/}"
        info "URL detected from configuration: $url"
        if ! ask_yes_no "Use this URL?"; then
          echo -n "Enter URL (e.g. company.1password.com): "
          read -r url
        fi
      else
        echo -n "Account URL (e.g. company.1password.com): "
        read -r url
      fi
      
      # Clean the URL again in case user entered with protocol
      url="${url#https://}"
      url="${url#http://}"
      url="${url%/}"
      
      # Use email from .env if available
      local email="${ONEPASSWORD_EMAIL:-}"
      if [[ -n "$email" ]]; then
        info "Email detected: $email"
        if ! ask_yes_no "Use this email?"; then
          echo -n "Enter email: "
          read -r email
        fi
      else
        echo -n "Email: "
        read -r email
      fi
      
      echo -n "Secret Key: "
      read -r secret_key
      
      echo
      info "Adding account..."
      
      if op account add --address "$url" --email "$email" --secret-key "$secret_key"; then
        success "Account added via manual data!"
        return 0
      else
        err "Failed to add account - check your data"
        return 1
      fi
      ;;
      
    3)
      echo
      warn "You need the Emergency Kit or account data"
      echo
      echo "The Emergency Kit contains:"
      echo "• Setup Code (QR code)"
      echo "• Secret Key"
      echo "• Account URL"
      echo
      echo "You can find it in:"
      echo "• Welcome email from 1Password"
      echo "• PDF downloaded during signup"
      echo "• Account settings at 1password.com"
      echo
      echo "Configure first by running: ./helpers/1password-helper.sh"
      return 1
      ;;
      
    4)
      echo
      info "Cancelling 1Password configuration"
      return 1
      ;;
  esac
}

# Main 1Password setup function
setup_1password_complete() {
  if [[ "${SETUP_DEV_PGPASS:-false}" != "true" ]]; then
    info "Skipping 1Password .pgpass configuration (not selected)"
    return 0
  fi

  info "Configuring dev environment (.pgpass via 1Password)..."
  
  # Install dependencies
  if ! command_exists jq; then
    info "Installing jq (required for JSON processing)..."
    if ! pac jq; then
      err "Failed to install jq"
      return 1
    fi
  fi
  
  # Install 1Password CLI
  if ! install_1password_cli; then
    err "1Password CLI required for .pgpass generation"
    return 1
  fi
  
  # Check current status
  local status
  status=$(check_1password_status)
  
  # Check if user wants to reconfigure even if already set up
  local force_reconfig=false
  if [[ "${ONEPASSWORD_FORCE_RECONFIG:-false}" == "true" ]]; then
    force_reconfig=true
  fi
  
  case "$status" in
    "authenticated")
      if [[ "$force_reconfig" == "true" ]]; then
        info "1Password CLI is already configured, but reconfiguration requested."
        status="not_configured"  # Force showing menu
      else
        info "1Password CLI already configured and authenticated"
        # Offer option to reconfigure
        echo
        if ask_yes_no "1Password is already configured. Do you want to reconfigure?"; then
          status="not_configured"  # Force showing menu
        else
          return 0  # Skip reconfiguration
        fi
      fi
      ;;
    "configured_not_logged_in")
      info "1Password CLI configured but not logged in."
      echo
      echo "Options:"
      echo "1) Sign in with existing configuration"
      echo "2) Reconfigure 1Password"
      echo "3) Skip"
      echo
      echo -n "Choose (1/2/3): "
      read -r signin_choice
      
      case "$signin_choice" in
        1)
          if ! signin_1password_cli; then
            err "Failed to authenticate with 1Password"
            return 1
          fi
          return 0
          ;;
        2)
          status="not_configured"  # Force showing menu
          ;;
        3)
          info "Skipping 1Password configuration"
          return 0
          ;;
        *)
          err "Invalid choice"
          return 1
          ;;
      esac
      ;;
  esac
  
  # Show configuration menu for not_configured status
  if [[ "$status" == "not_configured" ]]; then
    info "1Password CLI configuration needed."
    
    # Loop until valid configuration is chosen
    while true; do
        echo
        echo "Choose configuration method:"
        echo -e "1) ${BOLD}Mobile + Desktop Flow${NC} (easiest with phone)"
        echo "   • Use mobile app to configure desktop"
        echo "   • Then integrate CLI with desktop"
        echo -e "2) ${BOLD}Direct CLI${NC} (for Setup Code or manual data entry)"
        echo "   • Setup Code from Emergency Kit OR complete data entry"
        echo -e "3) ${BOLD}Interactive helper${NC} (runs dedicated setup script)"
        echo "   • Full-featured guided configuration"
        echo "   • All options with better user experience"
        echo -e "4) ${BOLD}Basic manual configuration${NC} (simple op account add)"
        echo "   • Uses op command directly"
        echo "   • Uses default URL from configuration if available"
        echo -e "5) ${BOLD}Skip 1Password configuration${NC}"
        echo
        echo -n "Choose (1/2/3/4/5): "
        read -r config_method
        
        case "$config_method" in
          1)
            if configure_1password_mobile_desktop; then
              success "Mobile + Desktop configuration completed successfully!"
              break
            else
              err "Mobile + Desktop configuration failed"
              if ! ask_yes_no "Try a different configuration method?"; then
                return 1
              fi
            fi
            ;;
          2)
            if configure_1password_cli_direct; then
              # Sign in after configuration
              if signin_1password_cli; then
                success "Direct CLI configuration completed successfully!"
                break
              else
                err "Failed to sign in after configuration"
                if ! ask_yes_no "Try a different configuration method?"; then
                  return 1
                fi
              fi
            else
              err "Direct CLI configuration failed"
              if ! ask_yes_no "Try a different configuration method?"; then
                return 1
              fi
            fi
            ;;
          3)
            # Try different possible locations for the helper
            local helper_paths=(
              "./helpers/1password-helper.sh"
              "$SCRIPT_DIR/helpers/1password-helper.sh"
              "$(dirname "${BASH_SOURCE[0]}")/../helpers/1password-helper.sh"
            )
            
            local helper_found=false
            for helper_path in "${helper_paths[@]}"; do
              if [[ -x "$helper_path" ]]; then
                info "Running interactive helper: $helper_path"
                if "$helper_path"; then
                  success "Interactive helper completed successfully!"
                  break 2  # Break out of both loops
                else
                  err "Interactive helper failed to configure 1Password"
                  if ! ask_yes_no "Try a different configuration method?"; then
                    return 1
                  fi
                  break  # Try different method
                fi
                helper_found=true
                break
              fi
            done
            
            if [[ "$helper_found" == "false" ]]; then
              warn "Interactive helper not found at expected locations"
              echo "Falling back to basic configuration with defaults from .env"
              echo
              
              # Use URL from .env if available
              local address="${ONEPASSWORD_URL:-}"
              if [[ -n "$address" ]]; then
                # Clean URL format
                address="${address#https://}"
                address="${address#http://}"
                address="${address%/}"
                echo "Using configured address: $address"
                echo -n "Enter email: "
                read -r email
                if op account add --address "$address" --email "$email"; then
                  if signin_1password_cli; then
                    success "Basic configuration completed successfully!"
                    break
                  else
                    err "Failed to sign in after basic configuration"
                    if ! ask_yes_no "Try a different configuration method?"; then
                      return 1
                    fi
                  fi
                else
                  err "Failed to add account with configured address"
                  if ! ask_yes_no "Try a different configuration method?"; then
                    return 1
                  fi
                fi
              else
                echo "No default URL configured. Using standard op account add..."
                if op account add; then
                  if signin_1password_cli; then
                    success "Basic configuration completed successfully!"
                    break
                  else
                    err "Failed to sign in after basic configuration"
                    if ! ask_yes_no "Try a different configuration method?"; then
                      return 1
                    fi
                  fi
                else
                  err "Basic configuration failed"
                  if ! ask_yes_no "Try a different configuration method?"; then
                    return 1
                  fi
                fi
              fi
            fi
            ;;
          4)
            info "Basic manual configuration..."
            
            # Use URL from .env if available
            local address="${ONEPASSWORD_URL:-}"
            if [[ -n "$address" ]]; then
              # Clean URL format
              address="${address#https://}"
              address="${address#http://}"
              address="${address%/}"
              
              info "Using configured URL: $address"
              
              # Use email from .env if available
              local email="${ONEPASSWORD_EMAIL:-}"
              if [[ -n "$email" ]]; then
                info "Using configured email: $email"
              else
                echo -n "Enter email for $address: "
                read -r email
              fi
              
              if [[ -n "$email" ]]; then
                echo "Debug: About to run: op account add --address '$address' --email '$email'"
                echo "Debug: Testing connectivity to $address..."
                
                # Test HTTPS connectivity 
                if curl -I -s --connect-timeout 10 "https://$address" >/dev/null 2>&1; then
                  info "✅ Connectivity to $address OK"
                else
                  warn "⚠️ Connectivity test to $address failed - but will try anyway"
                fi
                
                # Additional debugging - test what op can see
                echo "Debug: Testing op CLI connectivity..."
                echo "Debug: op version: $(op --version 2>/dev/null || echo 'version check failed')"
                echo "Debug: DNS resolution test:"
                nslookup "$address" 2>/dev/null | grep -A2 "Name:" | head -3 || echo "nslookup failed"
                
                # Test with verbose op command
                echo "Debug: Running op with detailed error output..."
                
                # Try with environment variables that might help
                echo "Debug: Trying with SSL/network environment variables..."
                export CURL_CA_BUNDLE=""
                export SSL_CERT_DIR=""
                export SSL_CERT_FILE=""
                export OP_LOG_LEVEL="debug"
                
                if op account add --address "$address" --email "$email"; then
                  if signin_1password_cli; then
                    success "Basic manual configuration completed successfully!"
                    break
                  else
                    err "Failed to sign in after manual configuration"
                    if ! ask_yes_no "Try a different configuration method?"; then
                      return 1
                    fi
                  fi
                else
                  err "Failed to add account with configured settings"
                  echo "Command executed: op account add --address '$address' --email '$email'"
                  echo
                  echo "Possible issues:"
                  echo "  • Check if URL is correct: $address"
                  echo "  • Check network connectivity from this machine"
                  echo "  • Try manually: curl -I https://$address"
                  echo
                  echo "Advanced debugging:"
                  echo "  • Test telnet: telnet $address 443"
                  echo "  • Test openssl: openssl s_client -connect $address:443 -servername $address < /dev/null"
                  echo "  • Check if corporate firewall blocks 1Password CLI specifically"
                  echo
                  
                  # Test if it's a certificate issue
                  echo "Testing SSL certificate..."
                  if openssl s_client -connect "$address:443" -servername "$address" < /dev/null 2>/dev/null | grep -q "Verify return code: 0"; then
                    info "✅ SSL certificate is valid"
                  else
                    warn "⚠️ SSL certificate issue detected"
                  fi
                  
                  echo "Since basic manual configuration failed, let's try the interactive helper instead."
                  if ask_yes_no "Run the interactive 1Password helper (recommended)?"; then
                    # Try to find and run the helper
                    local helper_paths=(
                      "./helpers/1password-helper.sh"
                      "$SCRIPT_DIR/helpers/1password-helper.sh"
                      "$(dirname "${BASH_SOURCE[0]}")/../helpers/1password-helper.sh"
                    )
                    
                    local helper_found=false
                    for helper_path in "${helper_paths[@]}"; do
                      if [[ -x "$helper_path" ]]; then
                        info "Running interactive helper: $helper_path"
                        if "$helper_path"; then
                          success "Interactive helper completed successfully!"
                          return 0
                        else
                          err "Interactive helper also failed"
                          return 1
                        fi
                        helper_found=true
                        break
                      fi
                    done
                    
                    if [[ "$helper_found" == "false" ]]; then
                      err "Interactive helper not found at expected locations"
                      return 1
                    fi
                  else
                    if ! ask_yes_no "Try a different configuration method?"; then
                      return 1
                    fi
                  fi
                fi
              else
                err "Email is required"
                if ! ask_yes_no "Try a different configuration method?"; then
                  return 1
                fi
              fi
            else
              info "No default URL configured, using standard op account add..."
              if op account add; then
                if signin_1password_cli; then
                  success "Basic manual configuration completed successfully!"
                  break
                else
                  err "Failed to sign in after manual configuration"
                  if ! ask_yes_no "Try a different configuration method?"; then
                    return 1
                  fi
                fi
              else
                err "Manual configuration failed"
                if ! ask_yes_no "Try a different configuration method?"; then
                  return 1
                fi
              fi
            fi
            ;;
          5)
            info "Skipping 1Password configuration"
            return 0
            ;;
          *)
            err "Invalid choice: $config_method"
            if ! ask_yes_no "Try again?"; then
              info "Exiting 1Password configuration"
              return 1
            fi
            ;;
        esac
      done
      
      success "1Password configured and authenticated successfully!"
  fi
  
  # Generate .pgpass file
  generate_pgpass_file
  return $?
}

# Process a database item from 1Password
process_database_item() {
  local item_id="$1"
  local -n entries_ref="$2"
  
  info "Processing database item: $item_id"
  
  # Get item details
  local item_json
  if ! item_json=$(op item get "$item_id" --format=json 2>/dev/null); then
    warn "Failed to get item details for $item_id"
    return 1
  fi
  
  # Extract basic info
  local title hostname port database username password
  title=$(echo "$item_json" | jq -r '.title // "Unknown"')
  
  info "Processing: $title"
  
  # Try different field combinations for database credentials
  local fields
  fields=$(echo "$item_json" | jq -r '.fields[]? | select(.label) | "\(.label):\(.value // .reference // "")"')
  
  # Initialize variables
  hostname=""
  port=""
  database=""
  username=""
  password=""
  
  # Parse fields with flexible field name matching (Portuguese + English)
  while IFS=':' read -r label value; do
    case "${label,,}" in
      *host*|*server*|*address*|*servidor*)
        [[ -z "$hostname" ]] && hostname="$value"
        ;;
      *port*|*porta*)
        [[ -z "$port" ]] && port="$value"
        ;;
      *database*|*db*|*schema*|*banco*)
        [[ -z "$database" ]] && database="$value"
        ;;
      *user*|*login*|*usuário*|*usuario*)
        [[ -z "$username" ]] && username="$value"
        ;;
      *pass*|*pwd*|*senha*)
        [[ -z "$password" ]] && password="$value"
        ;;
    esac
  done <<< "$fields"
  
  # Try URLs field for connection strings
  if [[ -z "$hostname" ]]; then
    local urls
    urls=$(echo "$item_json" | jq -r '.urls[]? | .href // ""' 2>/dev/null)
    if [[ -n "$urls" ]]; then
      # Extract hostname from URL (basic parsing)
      hostname=$(echo "$urls" | head -1 | sed -E 's|.*://([^:/]+).*|\1|')
    fi
  fi
  
  # Try username from login info if not found in fields
  if [[ -z "$username" ]]; then
    username=$(echo "$item_json" | jq -r '.login.username // ""' 2>/dev/null)
  fi
  
  # Try password from login info if not found in fields
  if [[ -z "$password" ]]; then
    password=$(echo "$item_json" | jq -r '.login.password // ""' 2>/dev/null)
  fi
  
  # Set defaults
  [[ -z "$port" ]] && port="5432"
  [[ -z "$database" ]] && database="postgres"
  
  # Validate required fields
  if [[ -z "$hostname" ]] || [[ -z "$username" ]] || [[ -z "$password" ]]; then
    warn "Missing required fields for $title:"
    warn "  Hostname: ${hostname:-'MISSING'}"
    warn "  Username: ${username:-'MISSING'}"  
    warn "  Password: ${password:+'SET'}${password:-'MISSING'}"
    warn "  Port: $port (default)"
    warn "  Database: $database (default)"
    return 1
  fi
  
  # Create .pgpass entry
  local pgpass_entry="$hostname:$port:$database:$username:$password"
  entries_ref+=("$pgpass_entry")
  
  success "Processed: $hostname:$port:$database:$username"
  return 0
}

# Generate .pgpass file from 1Password
generate_pgpass_file() {
  local pgpass_file="$HOME/.pgpass"
  local backup_file=""
  
  # Check if systemd-resolved is working properly before modifying DNS
  local dns_working=false
  
  # Test if systemd-resolved is managing DNS properly
  if command_exists resolvectl && resolvectl status >/dev/null 2>&1; then
    # Check if systemd-resolved is in managed mode and working
    if resolvectl status 2>/dev/null | grep -q "resolv.conf mode: managed" && \
       resolvectl status 2>/dev/null | grep -q "Current DNS Server:"; then
      dns_working=true
      info "systemd-resolved is working properly, skipping DNS modifications"
    fi
  fi
  
  # Only apply DNS workaround if systemd-resolved is not working
  if [[ "$dns_working" == "false" ]]; then
    warn "DNS resolution issue detected, applying workaround..."
    
    # Temporarily add public DNS to resolv.conf if needed
    if [[ -f /etc/resolv.conf ]] && ! grep -q "8.8.8.8\|1.1.1.1" /etc/resolv.conf; then
      info "Adding temporary DNS servers..."
      echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null
      echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf >/dev/null
    fi
  fi
  
  # Verify 1Password CLI is authenticated before proceeding
  if ! op account list >/dev/null 2>&1; then
    err "1Password CLI not authenticated. Cannot generate .pgpass file."
    info "Please complete 1Password configuration first."
    return 1
  fi
  
  # Backup existing file
  if [[ -f "$pgpass_file" ]]; then
    backup_file="$pgpass_file.backup.$(date +%Y%m%d_%H%M%S)"
    if cp "$pgpass_file" "$backup_file"; then
      info "Backup created: $backup_file"
    fi
  fi
  
  # Search for database credentials
  info "Searching for database credentials in 1Password..."
  
  # Debug: Show available categories
  info "Available item categories:"
  op item list --format=json 2>/dev/null | jq -r '[.[].category] | unique | join(", ")' || true
  
  local db_items
  info "Attempting to list Database category items..."
  if ! db_items=$(op item list --categories Database --format=json 2>&1); then
    err "Failed to list database credentials from 1Password"
    err "Error output: $db_items"
    
    # Try alternative search
    info "Trying alternative search for database items..."
    db_items=$(op item list --format=json 2>/dev/null | jq '[.[] | select(.category == "DATABASE" or .category == "Database" or .category == "database")]' 2>/dev/null)
    
    if [[ -z "$db_items" ]] || [[ "$db_items" == "[]" ]]; then
      err "Alternative search also failed"
      return 1
    fi
  fi
  
  if [[ "$db_items" == "[]" ]] || [[ -z "$db_items" ]]; then
    warn "No database credentials found in 1Password"
    info "Make sure you have credentials with category 'Database' in 1Password"
    return 1
  fi
  
  # Process found credentials
  local db_count
  db_count=$(echo "$db_items" | jq length 2>/dev/null || echo "0")
  
  if [[ "$db_count" -eq 0 ]]; then
    warn "No database credentials found"
    return 1
  fi
  
  info "Found $db_count database credential(s)"
  echo
  echo "Select credentials to include in .pgpass:"
  echo
  
  # Selection menu
  local selected_items=()
  local i=1
  
  while IFS= read -r item; do
    local title
    title=$(echo "$item" | jq -r '.title')
    local id
    id=$(echo "$item" | jq -r '.id')
    echo "$i) $title"
    selected_items+=("$id:$title")
    ((i++))
  done < <(echo "$db_items" | jq -c '.[]')
  
  echo
  echo "Enter numbers of credentials (space-separated) or 'a' for all:"
  read -r selection
  
  local pgpass_entries=()
  
  if [[ "$selection" == "a" || "$selection" == "A" ]]; then
    # Select all
    for item in "${selected_items[@]}"; do
      local item_id="${item%%:*}"
      if ! process_database_item "$item_id" pgpass_entries; then
        warn "Failed to process item: ${item##*:}"
      fi
    done
  else
    # Select specific ones
    for num in $selection; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#selected_items[@]}" ]]; then
        local item="${selected_items[$((num-1))]}"
        local item_id="${item%%:*}"
        if ! process_database_item "$item_id" pgpass_entries; then
          warn "Failed to process item: ${item##*:}"
        fi
      fi
    done
  fi
  
  # Generate .pgpass file
  if [[ ${#pgpass_entries[@]} -gt 0 ]]; then
    {
      echo "# .pgpass generated automatically via 1Password"
      echo "# Format: hostname:port:database:username:password"
      echo "# Generated on: $(date)"
      echo
      for entry in "${pgpass_entries[@]}"; do
        echo "$entry"
      done
    } > "$pgpass_file"
    
    chmod 600 "$pgpass_file"
    
    success "Created .pgpass file with ${#pgpass_entries[@]} entry(s)"
    info "Location: $pgpass_file"
    if [[ -n "$backup_file" ]]; then
      info "Previous backup: $backup_file"
    fi
    
    # Ask if user wants to generate Remmina connections too (unless skipped)
    if [[ "${SKIP_REMMINA_PROMPT:-false}" != "true" ]]; then
      echo
      if ask_yes_no "Generate Remmina RDP connections from 1Password as well?"; then
        if command -v setup_remmina_connections_complete >/dev/null 2>&1; then
          info "Setting up Remmina connections..."
          setup_remmina_connections_complete
        else
          warn "Remmina module not loaded, skipping RDP connections setup"
        fi
      fi
    fi
    
    return 0
  else
    err "No valid entries processed"
    return 1
  fi
}


# Test mode with debug output
test_1password_mode() {
  # Ensure test mode enables the 1Password module
  SETUP_DEV_PGPASS=true
  
  while true; do
    echo
    echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  ${BOLD}1Password Integration Test Mode${NC}${CYAN} ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════╗${NC}"
    echo
    
    echo "Test mode options:"
    echo "1) Generate .pgpass file only"
    echo "2) Generate Remmina connections only"
    echo "3) Generate both .pgpass and Remmina connections"
    echo "4) Reset 1Password (remove accounts and test from scratch)"
    echo "5) Exit"
    echo
    echo -n "Choose (1/2/3/4/5): "
    
    # Use timeout to prevent infinite loops
    if ! read -r -t 30 test_option; then
      echo
      warn "Input timeout or no response, exiting test mode"
      return 0
    fi
    
    case "$test_option" in
    1)
      echo "Generating .pgpass file only..."
      echo
      # Create a temporary flag to skip Remmina prompt
      local SKIP_REMMINA_PROMPT=true
      if setup_1password_complete; then
        # Create debug file
        local debug_file="$HOME/.pgpass_debug"
        if [[ -f "$HOME/.pgpass" ]]; then
          {
            echo "# .pgpass_debug generated automatically via 1Password (TEST MODE)"
            echo "# Original file: $HOME/.pgpass"
            echo "# Generated on: $(date)"
            echo "# Command: ./install.sh --1pass"
            echo "#"
            echo "# Format: hostname:port:database:username:password"
            echo
            cat "$HOME/.pgpass"
          } > "$debug_file"
          
          success "Debug file created!"
          info "Original: $HOME/.pgpass"
          info "Debug: $debug_file"
          
          echo
          info "Contents of $debug_file:"
          cat "$debug_file"
        fi
        
        echo
        success "Test mode completed successfully!"
        echo
        echo -e "${BOLD}Generated files:${NC}"
        [[ -f "$HOME/.pgpass" ]] && echo "  • $HOME/.pgpass (main file)"
        [[ -f "$HOME/.pgpass_debug" ]] && echo "  • $HOME/.pgpass_debug (test version)"
        
        return 0
      else
        err "Test configuration failed"
        return 1
      fi
      ;;
    2)
      echo "Generating Remmina connections only..."
      echo
      if command -v setup_remmina_connections_complete >/dev/null 2>&1; then
        if setup_remmina_connections_complete; then
          success "Remmina connections test completed successfully!"
          return 0
        else
          err "Remmina connections test failed"
          return 1
        fi
      else
        err "Remmina module not loaded"
        return 1
      fi
      ;;
    3)
      echo "Generating both .pgpass and Remmina connections..."
      echo
      if setup_1password_complete; then
        success "Both .pgpass and Remmina test completed successfully!"
        return 0
      else
        err "Combined test failed"
        return 1
      fi
      ;;
    4)
      echo "Resetting 1Password for clean test..."
      
      # Sign out CLI and remove accounts (with timeout to avoid hanging)
      info "Signing out from CLI..."
      timeout 5 op signout --all >/dev/null 2>&1 || true
      
      # Remove CLI config files
      if [[ -d "$HOME/.config/op" ]]; then
        info "Removing 1Password CLI configuration..."
        rm -rf "$HOME/.config/op" 2>/dev/null || true
      fi
      
      # Clear desktop app integration
      info "Clearing desktop app integration..."
      
      # Try to quit desktop app gracefully
      if command_exists 1password; then
        pkill -f "1password" 2>/dev/null || true
      fi
      
      # Remove desktop app data that might interfere with CLI
      local desktop_data_dirs=(
        "$HOME/.config/1Password"
        "$HOME/.local/share/1Password"
        "$HOME/.cache/1Password"
      )
      
      for dir in "${desktop_data_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
          info "Removing desktop app data: $(basename "$dir")"
          rm -rf "$dir" 2>/dev/null || true
        fi
      done
      
      # Clear any temporary authentication tokens
      unset OP_SESSION_* 2>/dev/null || true
      
      success "Reset completed! Both CLI and desktop app cleared."
      info "Note: You may need to sign in again to the desktop app if you use it"
      echo
      
      # After successful reset, continue to show menu again
      continue
      ;;
    5)
      info "Exiting test mode"
      return 0
      ;;
    "")
      # Empty input - continue loop
      warn "Please enter a valid option (1, 2, 3, 4, or 5)"
      continue
      ;;
    *)
      warn "Invalid option: '$test_option'. Please choose 1, 2, 3, 4, or 5"
      continue
      ;;
    esac
  done
}

# Export functions for use by main script
export -f install_1password_cli detect_1password_desktop install_1password_desktop
export -f open_1password_desktop check_1password_status signin_1password_cli
export -f configure_1password_mobile_desktop configure_1password_cli_direct
export -f setup_1password_complete process_database_item generate_pgpass_file
export -f test_1password_mode setup_ssh_keys_from_1password

# SSH Key Management from 1Password
setup_ssh_keys_from_1password() {
  if [[ "${SETUP_SSH_KEYS:-false}" != "true" ]]; then
    info "Skipping SSH keys configuration (not selected)"
    return 0
  fi

  info "Configuring SSH keys from 1Password..."
  
  # Verify 1Password CLI is authenticated
  local account_check
  account_check=$(op account list 2>&1)
  local account_exit=$?
  
  if [[ $account_exit -ne 0 ]] || [[ "$account_check" == *"No accounts configured"* ]] || [[ -z "$account_check" ]]; then
    err "1Password CLI not configured or authenticated."
    echo
    echo "The SSH key sync requires 1Password to be configured first."
    echo "Please run: ./install.sh --1pass"
    echo "Or use the helper: ./helpers/1password-helper.sh"
    echo
    return 1
  fi
  
  # Also check if we can actually access vaults (authenticated)
  if ! op vault list >/dev/null 2>&1; then
    info "1Password needs authentication. Attempting to sign in..."
    if ! signin_1password_cli; then
      err "Failed to authenticate with 1Password"
      return 1
    fi
  fi
  
  # Get SSH key name from configuration (collected in confirmation step)
  local ssh_key_name="${SSH_KEY_NAME:-}"
  
  if [[ -z "$ssh_key_name" ]]; then
    err "SSH key name is required. Please set SSH_KEY_NAME in configuration."
    return 1
  fi
  
  info "Using SSH key name from configuration: $ssh_key_name"
  
  # Search for the specific SSH key in 1Password with retry option
  while true; do
    info "Searching for SSH key: $ssh_key_name"
    
    local ssh_item
    if ssh_item=$(op item get "$ssh_key_name" --format=json 2>/dev/null); then
      break  # Found the key, exit the loop
    else
      err "SSH key '$ssh_key_name' not found in 1Password"
      echo
      echo "Options:"
      echo "1. Try again with a different name"
      echo "2. Exit"
      echo
      echo -n "Choose option (1 or 2): "
      read -r retry_option
      
      case "$retry_option" in
        1)
          echo
          echo "Enter the name of your SSH key in 1Password:"
          echo "Example: opiklocal, github-key, server-key, etc."
          echo
          echo -n "SSH Key name: "
          read -r ssh_key_name
          
          if [[ -z "$ssh_key_name" ]]; then
            err "SSH key name is required"
            return 1
          fi
          ;;
        2)
          info "Exiting SSH key configuration"
          return 1
          ;;
        *)
          warn "Invalid option. Please choose 1 or 2."
          ;;
      esac
    fi
  done
  
  # Process the SSH key
  local processed_keys=()
  if process_ssh_key_item_by_name "$ssh_key_name" processed_keys; then
    success "SSH key '$ssh_key_name' processed successfully"
    
    # Set as main key if processed
    if [[ ${#processed_keys[@]} -gt 0 ]]; then
      local main_key="${processed_keys[0]}"
      setup_main_ssh_key "$main_key"
    fi
    
    # Setup SSH agent
    setup_ssh_agent
    
    # Try to sync known_hosts if available
    sync_known_hosts_from_1password "$ssh_key_name"
    
    # Try to sync SSH config if available
    sync_ssh_config_from_1password "$ssh_key_name"
    
    success "SSH key configuration completed!"
    return 0
  else
    err "Failed to process SSH key '$ssh_key_name'"
    return 1
  fi
}

# Process an SSH key item by name from 1Password
process_ssh_key_item_by_name() {
  local item_name="$1"
  local -n keys_ref="$2"
  
  info "Processing SSH key: $item_name"
  
  # Get item details
  local item_json
  if ! item_json=$(op item get "$item_name" --format=json 2>/dev/null); then
    err "Failed to get item details for $item_name"
    return 1
  fi
  
  # Extract basic info
  local title key_type private_key public_key
  title=$(echo "$item_json" | jq -r '.title // "Unknown"')
  
  info "Processing SSH key: $title"
  
  # Try to extract private key using op read (more reliable for protected keys)
  private_key=""
  public_key=""
  
  # Get vault name from item
  local vault_name
  vault_name=$(echo "$item_json" | jq -r '.vault.name // "Private"')
  
  # Try to read private key using op read with SSH format
  info "Attempting to read private key using op read..."
  local private_key_read
  if private_key_read=$(op read "op://$vault_name/$item_name/private key?ssh-format=openssh" 2>/dev/null); then
    if [[ -n "$private_key_read" ]] && echo "$private_key_read" | grep -q "BEGIN.*PRIVATE KEY"; then
      private_key="$private_key_read"
      success "Successfully read private key using op read"
    fi
  fi
  
  # Fallback: Check for private key in fields
  if [[ -z "$private_key" ]]; then
    local private_key_field
    private_key_field=$(echo "$item_json" | jq -r '.fields[]? | select(.label | test("private|key|ssh", "i")) | .value // .reference // ""' | head -1)
    
    if [[ -n "$private_key_field" ]]; then
      private_key="$private_key_field"
    fi
  fi
  
  # Fallback: Check for private key in notes
  if [[ -z "$private_key" ]]; then
    local notes
    notes=$(echo "$item_json" | jq -r '.notes // ""')
    if [[ -n "$notes" ]] && echo "$notes" | grep -q "BEGIN.*PRIVATE KEY"; then
      private_key="$notes"
    fi
  fi
  
  # Try to read public key using op read
  info "Attempting to read public key using op read..."
  local public_key_read
  if public_key_read=$(op read "op://$vault_name/$item_name/public key" 2>/dev/null); then
    if [[ -n "$public_key_read" ]] && echo "$public_key_read" | grep -q "ssh-"; then
      public_key="$public_key_read"
      success "Successfully read public key using op read"
    fi
  fi
  
  # Fallback: Check for public key in fields
  if [[ -z "$public_key" ]]; then
    local public_key_field
    public_key_field=$(echo "$item_json" | jq -r '.fields[]? | select(.label | test("public|pub", "i")) | .value // .reference // ""' | head -1)
    
    if [[ -n "$public_key_field" ]]; then
      public_key="$public_key_field"
    fi
  fi
  
  # If no public key found, try to generate from private key
  if [[ -n "$private_key" ]] && [[ -z "$public_key" ]]; then
    info "Generating public key from private key..."
    public_key=$(echo "$private_key" | ssh-keygen -y -f /dev/stdin 2>/dev/null)
  fi
  
  # Validate private key
  if [[ -z "$private_key" ]] || ! echo "$private_key" | grep -q "BEGIN.*PRIVATE KEY"; then
    err "Invalid or missing private key for $title"
    return 1
  fi
  
  # Determine key type and filename
  local key_filename
  if echo "$private_key" | grep -q "BEGIN OPENSSH PRIVATE KEY"; then
    key_type="ed25519"
    key_filename="id_ed25519"
  elif echo "$private_key" | grep -q "BEGIN RSA PRIVATE KEY"; then
    key_type="rsa"
    key_filename="id_rsa"
  elif echo "$private_key" | grep -q "BEGIN DSA PRIVATE KEY"; then
    key_type="dsa"
    key_filename="id_dsa"
  elif echo "$private_key" | grep -q "BEGIN EC PRIVATE KEY"; then
    key_type="ecdsa"
    key_filename="id_ecdsa"
  else
    key_type="unknown"
    key_filename="id_${item_name//[^a-zA-Z0-9]/_}"
  fi
  
  # Create SSH directory if it doesn't exist
  local ssh_dir="$HOME/.ssh"
  if [[ ! -d "$ssh_dir" ]]; then
    info "Creating SSH directory: $ssh_dir"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
  fi
  
  # Create key files
  local private_key_file="$HOME/.ssh/$key_filename"
  local public_key_file="$HOME/.ssh/$key_filename.pub"
  
  # Create backup directory for better organization
  local backup_dir="$HOME/.ssh/backups/$(date +%Y%m%d_%H%M%S)"
  
  # Backup existing files with better organization
  if [[ -f "$private_key_file" ]]; then
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/$(basename "$private_key_file")"
    if cp "$private_key_file" "$backup_file"; then
      info "Backup created: $backup_file"
    fi
  fi
  
  if [[ -f "$public_key_file" ]]; then
    mkdir -p "$backup_dir"
    local backup_file="$backup_dir/$(basename "$public_key_file")"
    if cp "$public_key_file" "$backup_file"; then
      info "Backup created: $backup_file"
    fi
  fi
  
  # Write private key
  echo "$private_key" > "$private_key_file"
  chmod 600 "$private_key_file"
  
  # Write public key
  if [[ -n "$public_key" ]]; then
    echo "$public_key" > "$public_key_file"
    chmod 644 "$public_key_file"
  fi
  
  keys_ref+=("$key_filename")
  
  success "Processed SSH key: $key_filename ($key_type)"
  info "Private key: $private_key_file"
  info "Public key: $public_key_file"
  if [[ -d "$backup_dir" ]]; then
    info "Backups saved to: $backup_dir"
  fi
  return 0
}

# Sync known_hosts from 1Password
sync_known_hosts_from_1password() {
  local item_name="$1"
  
  info "Checking for known_hosts in SSH key item..."
  
  # Get vault name
  local vault_name
  vault_name=$(op item get "$item_name" --format=json 2>/dev/null | jq -r '.vault.name // "Private"')
  
  # Try to read known_hosts using op read
  local known_hosts_content
  if known_hosts_content=$(op read "op://$vault_name/$item_name/known_hosts" 2>/dev/null); then
    if [[ -n "$known_hosts_content" ]]; then
      info "Found known_hosts content, syncing..."
      
      local known_hosts_file="$HOME/.ssh/known_hosts"
      local backup_dir="$HOME/.ssh/backups/$(date +%Y%m%d_%H%M%S)"
      
      # Backup existing known_hosts
      if [[ -f "$known_hosts_file" ]]; then
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/known_hosts"
        if cp "$known_hosts_file" "$backup_file"; then
          info "Backup created: $backup_file"
        fi
      fi
      
      # Append or create known_hosts
      if [[ -f "$known_hosts_file" ]]; then
        echo "" >> "$known_hosts_file"
        echo "# Added from 1Password SSH key: $item_name" >> "$known_hosts_file"
        echo "$known_hosts_content" >> "$known_hosts_file"
        info "Appended to existing known_hosts"
      else
        echo "$known_hosts_content" > "$known_hosts_file"
        chmod 644 "$known_hosts_file"
        info "Created new known_hosts file"
      fi
      
      success "Known_hosts synced successfully"
      return 0
    fi
  fi
  
  info "No known_hosts found in SSH key item"
  return 0
}

# Sync SSH config from 1Password
sync_ssh_config_from_1password() {
  local item_name="$1"
  
  info "Checking for SSH config in SSH key item..."
  
  # Get vault name
  local vault_name
  vault_name=$(op item get "$item_name" --format=json 2>/dev/null | jq -r '.vault.name // "Private"')
  
  # Try to read config using op read
  local config_content
  if config_content=$(op read "op://$vault_name/$item_name/config" 2>/dev/null); then
    if [[ -n "$config_content" ]]; then
      info "Found SSH config content, syncing..."
      
      local config_file="$HOME/.ssh/config"
      local backup_dir="$HOME/.ssh/backups/$(date +%Y%m%d_%H%M%S)"
      
      # Backup existing config
      if [[ -f "$config_file" ]]; then
        mkdir -p "$backup_dir"
        local backup_file="$backup_dir/config"
        if cp "$config_file" "$backup_file"; then
          info "Backup created: $backup_file"
        fi
      fi
      
      # Create or replace config
      echo "$config_content" > "$config_file"
      chmod 600 "$config_file"
      info "SSH config synced successfully"
      
      success "SSH config synced successfully"
      return 0
    fi
  fi
  
  info "No SSH config found in SSH key item"
  return 0
}

# Setup main SSH key for the system
setup_main_ssh_key() {
  local key_filename="$1"
  local private_key_file="$HOME/.ssh/$key_filename"
  local public_key_file="$HOME/.ssh/$key_filename.pub"
  
  info "Setting up main SSH key: $key_filename"
  
  # Only create symlinks for the most common names, not all possible types
  # This avoids cluttering the .ssh directory with unnecessary symlinks
  local standard_names=()
  
  # Determine which symlinks to create based on the actual key type
  case "$key_filename" in
    "id_ed25519")
      standard_names=("id_rsa")  # Most common fallback name
      ;;
    "id_rsa")
      standard_names=("id_ed25519")  # Modern alternative
      ;;
    *)
      # For other key types, create symlink to id_rsa (most commonly expected)
      standard_names=("id_rsa")
      ;;
  esac
  
  for standard_name in "${standard_names[@]}"; do
    local standard_private="$HOME/.ssh/$standard_name"
    local standard_public="$HOME/.ssh/$standard_name.pub"
    
    # Remove existing symlinks or files
    if [[ -L "$standard_private" ]]; then
      rm "$standard_private"
    fi
    if [[ -L "$standard_public" ]]; then
      rm "$standard_public"
    fi
    
    # Create symlinks
    if [[ -f "$private_key_file" ]]; then
      ln -sf "$private_key_file" "$standard_private"
      info "Created symlink: $standard_private -> $private_key_file"
    fi
    
    if [[ -f "$public_key_file" ]]; then
      ln -sf "$public_key_file" "$standard_public"
      info "Created symlink: $standard_public -> $public_key_file"
    fi
  done
  
  # Add to SSH agent
  if command_exists ssh-add; then
    ssh-add "$private_key_file" 2>/dev/null || warn "Failed to add key to SSH agent"
  fi
  
  success "Main SSH key configured: $key_filename"
}

# Setup SSH agent
setup_ssh_agent() {
  info "Setting up SSH agent..."
  
  # Check if ssh-agent is running
  if ! pgrep ssh-agent >/dev/null; then
    info "Starting SSH agent..."
    eval "$(ssh-agent -s)" >/dev/null 2>&1
  fi
  
  # Add SSH_AUTH_SOCK to shell profile if not present
  local shell_profile=""
  if [[ -f "$HOME/.bashrc" ]]; then
    shell_profile="$HOME/.bashrc"
  elif [[ -f "$HOME/.zshrc" ]]; then
    shell_profile="$HOME/.zshrc"
  fi
  
  if [[ -n "$shell_profile" ]]; then
    if ! grep -q "SSH_AUTH_SOCK" "$shell_profile"; then
      echo "" >> "$shell_profile"
      echo "# SSH Agent Configuration" >> "$shell_profile"
      echo "if [[ -z \"\$SSH_AUTH_SOCK\" ]]; then" >> "$shell_profile"
      echo "  eval \"\$(ssh-agent -s)\" >/dev/null 2>&1" >> "$shell_profile"
      echo "fi" >> "$shell_profile"
      info "Added SSH agent configuration to $shell_profile"
    fi
  fi
  
  success "SSH agent configured"
}