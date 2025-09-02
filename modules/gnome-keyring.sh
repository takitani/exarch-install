#!/usr/bin/env bash
# modules/gnome-keyring.sh - Gnome Keyring setup module

# Setup gnome-keyring to avoid password prompts on Chrome/Chromium
setup_gnome_keyring() {
  info "Setting up Gnome Keyring for passwordless Chrome/Chromium..."
  
  # Check if gnome-keyring is installed
  if ! command -v gnome-keyring-daemon &>/dev/null; then
    info "Installing gnome-keyring..."
    pac gnome-keyring
  else
    info "gnome-keyring is already installed"
  fi
  
  # Configure PAM for automatic unlock
  info "Configuring PAM for automatic keyring unlock..."
  
  # Backup PAM configuration
  if [[ ! -f "/etc/pam.d/login.bak" ]]; then
    add_sudo_command "cp /etc/pam.d/login /etc/pam.d/login.bak.$(date +%Y%m%d)"
  fi
  
  # Check if already configured
  if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/login 2>/dev/null; then
    # Create temporary PAM configuration
    local pam_config="/tmp/pam-login-gnome-keyring-$$"
    cat > "$pam_config" << 'EOF'
#%PAM-1.0

auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so
account    include      system-local-login
session    include      system-local-login
session    optional     pam_gnome_keyring.so auto_start
password   include      system-local-login
EOF
    
    add_sudo_command "mv $pam_config /etc/pam.d/login"
    success "PAM configured for gnome-keyring"
  else
    info "PAM already configured for gnome-keyring"
  fi
  
  # Configure Hyprland autostart
  local hypr_autostart="$HOME/.config/hypr/autostart.conf"
  
  if [[ -f "$hypr_autostart" ]]; then
    if ! grep -q "gnome-keyring-daemon" "$hypr_autostart" 2>/dev/null; then
      info "Adding gnome-keyring to Hyprland autostart..."
      cat >> "$hypr_autostart" << 'EOF'

# Gnome Keyring - desbloqueia automaticamente no login
exec-once = gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
EOF
      success "Hyprland autostart configured"
    else
      info "gnome-keyring already in Hyprland autostart"
    fi
  else
    warn "Hyprland autostart.conf not found, creating it..."
    mkdir -p "$(dirname "$hypr_autostart")"
    cat > "$hypr_autostart" << 'EOF'
# Hyprland autostart configuration

# Gnome Keyring - desbloqueia automaticamente no login
exec-once = gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
EOF
    success "Created Hyprland autostart with gnome-keyring"
  fi
  
  # Create blank keyring (no password)
  info "Creating blank keyring for passwordless operation..."
  
  local keyring_dir="$HOME/.local/share/keyrings"
  mkdir -p "$keyring_dir"
  
  # Stop current daemon if running
  killall gnome-keyring-daemon 2>/dev/null
  sleep 1
  
  # Create login keyring without password
  cat > "$keyring_dir/login.keyring" << 'EOF'
[keyring]
display-name=Login
ctime=0
mtime=0
lock-on-idle=false
lock-after=false
EOF
  
  # Set login keyring as default
  echo "login" > "$keyring_dir/default"
  
  # Set proper permissions
  chmod 600 "$keyring_dir/login.keyring"
  chmod 644 "$keyring_dir/default"
  
  success "Blank keyring created and set as default"
  
  # Show summary
  echo
  echo -e "${BOLD}Gnome Keyring Setup Complete!${NC}"
  echo "================================"
  echo "• PAM configured for automatic unlock"
  echo "• Hyprland autostart configured"
  echo "• Blank keyring created (no password)"
  echo
  echo "After reboot, Chrome/Chromium will no longer ask for keyring password."
  echo
  echo "If you still get prompted, you can alternatively run Chrome with:"
  echo "  google-chrome-stable --password-store=basic"
  echo
  
  return 0
}

# Revert gnome-keyring configuration
revert_gnome_keyring() {
  info "Reverting gnome-keyring configuration..."
  
  # Restore PAM backup if exists
  local backup_file
  backup_file=$(ls -t /etc/pam.d/login.bak.* 2>/dev/null | head -1)
  
  if [[ -f "$backup_file" ]]; then
    info "Restoring PAM backup: $backup_file"
    add_sudo_command "cp $backup_file /etc/pam.d/login"
    success "PAM configuration restored"
  else
    warn "No PAM backup found, removing gnome-keyring lines manually..."
    add_sudo_command "grep -v 'pam_gnome_keyring.so' /etc/pam.d/login > /tmp/pam-login-clean && mv /tmp/pam-login-clean /etc/pam.d/login"
  fi
  
  # Remove from Hyprland autostart
  local hypr_autostart="$HOME/.config/hypr/autostart.conf"
  if [[ -f "$hypr_autostart" ]]; then
    info "Removing gnome-keyring from Hyprland autostart..."
    cp "$hypr_autostart" "$hypr_autostart.bak.$(date +%Y%m%d_%H%M%S)"
    sed -i '/# Gnome Keyring/d' "$hypr_autostart"
    sed -i '/gnome-keyring-daemon/d' "$hypr_autostart"
    success "Hyprland autostart cleaned"
  fi
  
  # Stop gnome-keyring daemon
  if pgrep gnome-keyring > /dev/null; then
    info "Stopping gnome-keyring daemon..."
    killall gnome-keyring-daemon 2>/dev/null
  fi
  
  success "Gnome keyring configuration reverted"
  echo "Please reboot to complete the reversion."
}

# Export functions
export -f setup_gnome_keyring revert_gnome_keyring