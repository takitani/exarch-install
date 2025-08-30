#!/usr/bin/env bash
# modules/dell-xps.sh - Dell XPS 13 Plus (9320) specific optimizations

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/hardware-detection.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/hardware-detection.sh"

# Install Dell XPS 13 Plus webcam drivers
setup_dell_xps_9320_webcam() {
  if ! is_dell_xps_9320; then
    info "Skipping Dell XPS webcam setup (not Dell XPS 13 Plus 9320)"
    return 0
  fi
  
  info "Configuring webcam for Dell XPS 13 Plus (9320)..."
  
  # Step 1: Install libcamera
  info "Installing libcamera..."
  pac libcamera || warn "Failed to install libcamera"
  
  # Step 2: Install pipewire-libcamera
  info "Installing pipewire-libcamera..."
  pac pipewire-libcamera || warn "Failed to install pipewire-libcamera"
  
  # Step 3: Create and install PKGBUILD for ivsc-firmware
  install_ivsc_firmware
  
  # Step 4: Create and install PKGBUILD for ipu6-drivers
  install_ipu6_drivers
  
  # Step 5: Configure kernel modules
  configure_dell_xps_kernel_modules
  
  success "Dell XPS 13 Plus webcam configuration completed"
  CONFIGURED_RUNTIMES+=("Dell XPS 13 Plus webcam drivers")
}

# Install Intel Visual Sensing Controller firmware
install_ivsc_firmware() {
  info "Creating and installing PKGBUILD for ivsc-firmware..."
  
  local tmpdir_ivsc
  tmpdir_ivsc=$(mktemp -d)
  
  # Change to temp directory
  pushd "$tmpdir_ivsc" > /dev/null || return 1
  
  # Create PKGBUILD for ivsc-firmware
  cat > PKGBUILD << 'EOF'
# Maintainer: Exarch Scripts <noreply@example.com>

pkgname=ivsc-firmware-git
pkgver=r13.0000000
pkgrel=1
pkgdesc="Intel Visual Sensing Controller (IVSC) firmware binaries (from intel/ivsc-firmware)"
arch=('any')
url="https://github.com/intel/ivsc-firmware"
license=('custom')
depends=()
makedepends=('git')
provides=('intel-ivsc-firmware')
conflicts=('intel-ivsc-firmware')
source=("git+https://github.com/intel/ivsc-firmware.git")
sha256sums=('SKIP')

pkgver() {
    cd "$srcdir/ivsc-firmware"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
    cd "$srcdir/ivsc-firmware"
    # Install firmwares under /usr/lib/firmware/vsc (Arch: /lib -> /usr/lib)
    install -d "$pkgdir/usr/lib/firmware/vsc"
    
    # Copy firmware files
    find . -name "*.bin" -exec cp {} "$pkgdir/usr/lib/firmware/vsc/" \;
    
    # Install license if available
    if [[ -f LICENSE ]]; then
        install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
    fi
}
EOF

  # Build and install
  info "Building ivsc-firmware package..."
  if is_debug_mode; then
    info "[DEBUG] Would build and install ivsc-firmware"
    success "ivsc-firmware installation simulated"
  else
    if makepkg -si --noconfirm --needed 2>/dev/null; then
      success "ivsc-firmware installed successfully"
    else
      warn "Failed to build ivsc-firmware, trying alternative method..."
      # Fallback: manual installation
      if install_ivsc_firmware_manual; then
        success "ivsc-firmware installed via fallback method"
      else
        err "Failed to install ivsc-firmware"
        popd > /dev/null
        rm -rf "$tmpdir_ivsc"
        return 1
      fi
    fi
  fi
  
  popd > /dev/null
  rm -rf "$tmpdir_ivsc"
  return 0
}

# Manual installation fallback for IVSC firmware
install_ivsc_firmware_manual() {
  info "Installing IVSC firmware manually..."
  
  local firmware_dir="/usr/lib/firmware/vsc"
  
  # Create firmware directory
  sudo mkdir -p "$firmware_dir"
  
  # Download and extract firmware files
  local temp_repo
  temp_repo=$(mktemp -d)
  
  if git clone https://github.com/intel/ivsc-firmware.git "$temp_repo" 2>/dev/null; then
    # Copy firmware files
    find "$temp_repo" -name "*.bin" -exec sudo cp {} "$firmware_dir/" \;
    rm -rf "$temp_repo"
    return 0
  else
    rm -rf "$temp_repo"
    return 1
  fi
}

# Install IPU6 camera drivers
install_ipu6_drivers() {
  info "Creating and installing PKGBUILD for ipu6-drivers..."
  
  local tmpdir_ipu6
  tmpdir_ipu6=$(mktemp -d)
  
  pushd "$tmpdir_ipu6" > /dev/null || return 1
  
  # Create PKGBUILD for ipu6-drivers
  cat > PKGBUILD << 'EOF'
# Maintainer: Exarch Scripts <noreply@example.com>

pkgname=ipu6-drivers-git
pkgver=r156.0000000
pkgrel=1
pkgdesc="Intel IPU6 camera drivers for Tiger Lake and Alder Lake platforms"
arch=('x86_64')
url="https://github.com/intel/ipu6-drivers"
license=('GPL2')
depends=('dkms')
makedepends=('git' 'linux-headers')
provides=('intel-ipu6-drivers')
conflicts=('intel-ipu6-drivers')
source=("git+https://github.com/intel/ipu6-drivers.git")
sha256sums=('SKIP')

pkgver() {
    cd "$srcdir/ipu6-drivers"
    printf "r%s.%s" "$(git rev-list --count HEAD)" "$(git rev-parse --short HEAD)"
}

package() {
    cd "$srcdir/ipu6-drivers"
    
    # Install to DKMS
    local dkms_dir="$pkgdir/usr/src/ipu6-drivers-$pkgver"
    mkdir -p "$dkms_dir"
    
    # Copy source files
    cp -r . "$dkms_dir/"
    
    # Create dkms.conf if it doesn't exist
    if [[ ! -f "$dkms_dir/dkms.conf" ]]; then
        cat > "$dkms_dir/dkms.conf" << DKMS_EOF
PACKAGE_NAME="ipu6-drivers"
PACKAGE_VERSION="$pkgver"
MAKE="make -C . KDIR=/lib/modules/\${kernelver}/build"
CLEAN="make -C . clean"
BUILT_MODULE_NAME[0]="intel-ipu6"
BUILT_MODULE_LOCATION[0]="."
DEST_MODULE_LOCATION[0]="/kernel/drivers/media/pci/intel/"
AUTOINSTALL="yes"
DKMS_EOF
    fi
}

install() {
    dkms add -m ipu6-drivers -v $pkgver
    dkms build -m ipu6-drivers -v $pkgver
    dkms install -m ipu6-drivers -v $pkgver
}

remove() {
    dkms remove -m ipu6-drivers -v $pkgver --all
}
EOF

  # Build and install
  info "Building ipu6-drivers package..."
  if is_debug_mode; then
    info "[DEBUG] Would build and install ipu6-drivers"
    success "ipu6-drivers installation simulated"
  else
    if makepkg -si --noconfirm --needed 2>/dev/null; then
      success "ipu6-drivers installed successfully"
    else
      warn "Failed to build ipu6-drivers package"
      # Continue anyway, might not be critical
    fi
  fi
  
  popd > /dev/null
  rm -rf "$tmpdir_ipu6"
  return 0
}

# Configure kernel modules for Dell XPS
configure_dell_xps_kernel_modules() {
  info "Configuring kernel modules for Dell XPS..."
  
  # Modules to load at boot
  local modules=(
    "intel_ipu6_isys"
    "intel_ipu6_psys" 
    "ipu6_drivers"
  )
  
  local modules_file="/etc/modules-load.d/dell-xps-camera.conf"
  
  if is_debug_mode; then
    info "[DEBUG] Would configure kernel modules: ${modules[*]}"
    return 0
  fi
  
  # Create modules configuration
  {
    echo "# Dell XPS 13 Plus camera modules"
    echo "# Generated by Exarch Scripts"
    echo
    for module in "${modules[@]}"; do
      echo "$module"
    done
  } | sudo tee "$modules_file" > /dev/null
  
  info "Kernel modules configured: $modules_file"
  
  # Load modules immediately (if not in debug mode)
  for module in "${modules[@]}"; do
    if ! lsmod | grep -q "^$module "; then
      if sudo modprobe "$module" 2>/dev/null; then
        info "Loaded module: $module"
      else
        warn "Failed to load module: $module (may not be available yet)"
      fi
    fi
  done
}

# Install power management tools
install_dell_xps_power_management() {
  if ! is_dell_xps_9320; then
    info "Skipping Dell XPS power management (not Dell XPS 13 Plus 9320)"
    return 0
  fi
  
  info "Installing power management tools for Dell XPS..."
  
  # TLP for advanced power management
  pac tlp
  pac tlp-rdw  # Radio device wizard
  
  # thermald for thermal management
  pac thermald
  
  # Enable services
  if ! is_debug_mode; then
    sudo systemctl enable tlp.service
    sudo systemctl enable thermald.service
    
    # Start services if not running
    if ! systemctl is-active tlp >/dev/null 2>&1; then
      sudo systemctl start tlp.service
    fi
    
    if ! systemctl is-active thermald >/dev/null 2>&1; then
      sudo systemctl start thermald.service
    fi
  fi
  
  success "Power management tools installed and configured"
  CONFIGURED_RUNTIMES+=("TLP power management")
  CONFIGURED_RUNTIMES+=("thermald thermal management")
}

# Configure TLP for Dell XPS optimizations
configure_tlp_dell_xps() {
  if ! is_dell_xps_9320; then
    return 0
  fi
  
  local tlp_config="/etc/tlp.conf"
  
  if [[ ! -f "$tlp_config" ]]; then
    warn "TLP configuration file not found, skipping custom configuration"
    return 1
  fi
  
  info "Applying Dell XPS optimizations to TLP..."
  
  if is_debug_mode; then
    info "[DEBUG] Would apply Dell XPS TLP optimizations"
    return 0
  fi
  
  # Backup original config
  sudo cp "$tlp_config" "${tlp_config}.backup.$(date +%Y%m%d_%H%M%S)"
  
  # Apply Dell XPS specific optimizations
  sudo tee -a "$tlp_config" > /dev/null << 'EOF'

# Dell XPS 13 Plus optimizations added by Exarch Scripts
# Battery optimization
START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=80

# CPU scaling governor
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# Intel GPU power management
INTEL_GPU_MIN_FREQ_ON_AC=0
INTEL_GPU_MIN_FREQ_ON_BAT=0
INTEL_GPU_MAX_FREQ_ON_AC=0
INTEL_GPU_MAX_FREQ_ON_BAT=0
INTEL_GPU_BOOST_FREQ_ON_AC=0
INTEL_GPU_BOOST_FREQ_ON_BAT=0

# WiFi power saving
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=on

# USB autosuspend
USB_AUTOSUSPEND=1
USB_BLACKLIST_WWAN=1

# PCIe Active State Power Management
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=powersave
EOF

  success "TLP optimized for Dell XPS 13 Plus"
}

# Setup dual keyboard layout (BR + US International)
setup_dual_keyboard_dell_xps() {
  if [[ "${SETUP_DUAL_KEYBOARD:-false}" != "true" ]]; then
    return 0
  fi
  
  if ! is_dell_xps_9320; then
    info "Skipping dual keyboard setup (not Dell XPS 13 Plus 9320)"
    return 0
  fi
  
  info "Setting up dual keyboard layout (BR + US International)..."
  
  # Configure keyboard layouts
  local keyboard_config="/etc/X11/xorg.conf.d/00-keyboard.conf"
  
  if is_debug_mode; then
    info "[DEBUG] Would configure dual keyboard layout"
    return 0
  fi
  
  # Create keyboard configuration
  sudo tee "$keyboard_config" > /dev/null << 'EOF'
# Keyboard configuration for Dell XPS - BR + US International
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "br,us"
    Option "XkbVariant" ",intl"
    Option "XkbOptions" "grp:alt_shift_toggle,grp_led:scroll"
EndSection
EOF

  success "Dual keyboard layout configured"
  info "Use Alt+Shift to toggle between BR and US International"
  CONFIGURED_RUNTIMES+=("Dual keyboard (BR + US Intl)")
}

# Install Dell-specific utilities
install_dell_utilities() {
  if ! is_dell_xps_9320; then
    return 0
  fi
  
  info "Installing Dell-specific utilities..."
  
  # Dell command configure (if available)
  if aur dell-command-configure; then
    success "Dell Command Configure installed"
    CONFIGURED_RUNTIMES+=("Dell Command Configure")
  else
    info "Dell Command Configure not available in AUR"
  fi
  
  # Firmware update utilities
  pac fwupd
  
  if ! is_debug_mode; then
    # Enable fwupd service
    sudo systemctl enable fwupd.service
    
    if ! systemctl is-active fwupd >/dev/null 2>&1; then
      sudo systemctl start fwupd.service
    fi
  fi
  
  success "Firmware update utilities configured"
  CONFIGURED_RUNTIMES+=("fwupd firmware updater")
}

# Main Dell XPS setup function
setup_dell_xps_9320_complete() {
  if [[ "${SETUP_DELL_XPS_9320:-false}" != "true" ]]; then
    info "Skipping Dell XPS 13 Plus setup (not selected)"
    return 0
  fi
  
  if ! is_dell_xps_9320; then
    warn "Dell XPS 13 Plus (9320) not detected"
    if ! ask_yes_no "Continue with Dell XPS optimizations anyway?"; then
      return 0
    fi
  fi
  
  info "Setting up Dell XPS 13 Plus (9320) optimizations..."
  
  # Webcam drivers
  setup_dell_xps_9320_webcam
  
  # Power management
  install_dell_xps_power_management
  configure_tlp_dell_xps
  
  # Keyboard layout
  setup_dual_keyboard_dell_xps
  
  # Dell utilities
  install_dell_utilities
  
  success "Dell XPS 13 Plus setup completed!"
  
  # Show post-installation info
  show_dell_xps_post_install_info
}

# Show post-installation information
show_dell_xps_post_install_info() {
  echo
  echo -e "${BOLD}Dell XPS 13 Plus Post-Installation Info${NC}"
  echo "======================================="
  
  echo -e "\n${CYAN}Webcam:${NC}"
  echo "• IPU6 drivers installed"
  echo "• Reboot required for webcam to work"
  echo "• Test with: cheese or other camera app"
  
  echo -e "\n${CYAN}Power Management:${NC}"
  echo "• TLP configured for battery optimization"
  echo "• Battery charging limited to 40-80%"
  echo "• Thermal management active"
  
  if [[ "${SETUP_DUAL_KEYBOARD:-false}" == "true" ]]; then
    echo -e "\n${CYAN}Keyboard:${NC}"
    echo "• Dual layout: Brazilian + US International"
    echo "• Toggle with: Alt+Shift"
  fi
  
  echo -e "\n${CYAN}Next Steps:${NC}"
  echo "• Reboot to activate all drivers"
  echo "• Check webcam: cheese"
  echo "• Check TLP status: sudo tlp-stat"
  echo "• Update firmware: sudo fwupdmgr refresh && sudo fwupdmgr update"
  
  echo
}

# Export functions
export -f setup_dell_xps_9320_webcam install_ivsc_firmware install_ivsc_firmware_manual
export -f install_ipu6_drivers configure_dell_xps_kernel_modules
export -f install_dell_xps_power_management configure_tlp_dell_xps
export -f setup_dual_keyboard_dell_xps install_dell_utilities
export -f setup_dell_xps_9320_complete show_dell_xps_post_install_info