#!/usr/bin/env bash
# modules/espanso.sh - Espanso installation and configuration for Wayland

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"

# Install and compile Espanso for Wayland
install_espanso_wayland() {
  info "Installing Espanso with Wayland support..."
  
  # Check if already installed
  if command_exists espanso; then
    local version=$(espanso --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    info "Espanso $version already installed"
    
    # Check if compiled with Wayland support
    if espanso --help 2>&1 | grep -q "wayland"; then
      success "Espanso already has Wayland support"
      return 0
    else
      warn "Espanso installed but without Wayland support, recompiling..."
    fi
  fi
  
  # Install build dependencies
  info "Installing build dependencies..."
  local build_deps=(
    "rust"
    "cargo"
    "make"
    "gcc"
    "pkg-config"
    "libx11"
    "libxtst"
    "libxkbcommon"
    "libdbus"
    "wxgtk3"
    "webkit2gtk"
  )
  
  for dep in "${build_deps[@]}"; do
    if ! pac "$dep"; then
      warn "Failed to install $dep"
    fi
  done
  
  # Install Wayland-specific dependencies
  info "Installing Wayland dependencies..."
  pac wayland
  pac wayland-protocols
  pac libxkbcommon
  
  # Create temporary build directory
  local build_dir="/tmp/espanso-build-$$"
  mkdir -p "$build_dir"
  cd "$build_dir"
  
  # Clone Espanso repository
  info "Cloning Espanso repository..."
  if ! git clone --depth 1 https://github.com/espanso/espanso.git; then
    err "Failed to clone Espanso repository"
    return 1
  fi
  
  cd espanso
  
  # Apply Wayland patches if needed
  info "Configuring for Wayland build..."
  
  # Build with Wayland feature
  info "Building Espanso with Wayland support (this may take a while)..."
  if cargo build --release --features wayland; then
    success "Espanso built successfully"
  else
    warn "Build failed with Wayland feature, trying alternative method..."
    
    # Try building with modulo feature for Wayland
    if cargo build --release --features modulo; then
      success "Espanso built with modulo feature"
    else
      err "Failed to build Espanso"
      cd /
      rm -rf "$build_dir"
      return 1
    fi
  fi
  
  # Install the compiled binary
  info "Installing Espanso..."
  sudo cp target/release/espanso /usr/local/bin/
  sudo chmod +x /usr/local/bin/espanso
  
  # Create systemd service
  info "Creating systemd service..."
  espanso service register
  
  # Enable and start service
  systemctl --user enable espanso
  systemctl --user start espanso
  
  # Install default configuration
  info "Installing default configuration..."
  mkdir -p ~/.config/espanso
  
  # Create a basic config for Wayland
  cat > ~/.config/espanso/config/default.yml << 'EOF'
# Espanso configuration for Wayland

# Backend configuration for Wayland
backend: Clipboard

# Enable clipboard backend for Wayland compatibility
clipboard_backend: CopyQ

# Disable X11 features on Wayland
enable_x11_fast_inject: false

# Toggle key (Alt+Space by default)
toggle_key: ALT+SPACE

# Search shortcut
search_shortcut: ALT+SHIFT+SPACE

# Show notifications
show_notifications: true

# Preserve clipboard
preserve_clipboard: true
EOF
  
  # Create matches directory
  mkdir -p ~/.config/espanso/match
  
  # Create a sample match file
  cat > ~/.config/espanso/match/base.yml << 'EOF'
# Sample Espanso matches
matches:
  # Email signature
  - trigger: ":sig"
    replace: |
      Best regards,
      $|$
      
  # Current date
  - trigger: ":date"
    replace: "{{mydate}}"
    vars:
      - name: mydate
        type: date
        params:
          format: "%Y-%m-%d"
          
  # Current time
  - trigger: ":time"
    replace: "{{mytime}}"
    vars:
      - name: mytime
        type: date
        params:
          format: "%H:%M"
EOF
  
  # Clean up build directory
  cd /
  rm -rf "$build_dir"
  
  success "Espanso installed and configured for Wayland!"
  info "Use Alt+Space to toggle Espanso"
  info "Edit ~/.config/espanso/match/base.yml to add custom text expansions"
  
  return 0
}

# Alternative: Install Espanso from AUR with Wayland patches
install_espanso_aur_wayland() {
  info "Installing Espanso from AUR with Wayland support..."
  
  # Try espanso-wayland package first
  if aur espanso-wayland; then
    success "Espanso Wayland installed from AUR"
    configure_espanso_wayland
    return 0
  fi
  
  # Fallback to regular espanso
  if aur espanso; then
    warn "Regular Espanso installed, may have limited Wayland support"
    configure_espanso_wayland
    return 0
  fi
  
  # If both fail, compile from source
  warn "AUR installation failed, compiling from source..."
  install_espanso_wayland
}

# Configure Espanso for Wayland
configure_espanso_wayland() {
  info "Configuring Espanso for Wayland..."
  
  # Ensure config directory exists
  mkdir -p ~/.config/espanso/config
  
  # Check if config exists
  if [[ -f ~/.config/espanso/config/default.yml ]]; then
    # Backup existing config
    cp ~/.config/espanso/config/default.yml ~/.config/espanso/config/default.yml.backup
  fi
  
  # Update or create Wayland-compatible config
  cat > ~/.config/espanso/config/default.yml << 'EOF'
# Espanso configuration optimized for Wayland

# Use clipboard backend for Wayland
backend: Clipboard

# Clipboard settings
clipboard_backend: Auto
restore_clipboard_delay: 300

# Disable X11-specific features
enable_x11_fast_inject: false
x11_use_xclip_backend: false

# Key bindings
toggle_key: ALT+SPACE
search_shortcut: ALT+SHIFT+SPACE

# UI settings
show_notifications: true
show_icon: false

# Performance
inject_delay: 10
key_delay: 10

# Workarounds for Wayland
evdev_modifier_delay: 10
wayland_paste_key: CTRL+V
EOF
  
  # Restart Espanso service
  systemctl --user restart espanso
  
  success "Espanso configured for Wayland"
}

# Main installation function
setup_espanso() {
  if [[ "${INSTALL_ESPANSO:-true}" != "true" ]]; then
    return 0
  fi
  
  info "Setting up Espanso text expander for Wayland..."
  
  # Detect session type
  if [[ "$XDG_SESSION_TYPE" == "wayland" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
    info "Wayland session detected, installing Wayland-compatible version..."
    
    # Try AUR first (faster if available)
    if ! install_espanso_aur_wayland; then
      # Compile from source if AUR fails
      install_espanso_wayland
    fi
  else
    # X11 session - install regular version
    info "X11 session detected, installing standard version..."
    pac espanso || aur espanso
  fi
  
  return 0
}

# Export functions
export -f install_espanso_wayland install_espanso_aur_wayland configure_espanso_wayland setup_espanso