#!/usr/bin/env bash
# modules/dell-xps.sh - Dell XPS 13 Plus (9320) specific optimizations

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/hardware-detection.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/hardware-detection.sh"

# Function to check if package is available in official repos
check_package_available() {
  local pkg="$1"
  pacman -Ss "^$pkg$" >/dev/null 2>&1
}

# Function to check if package is available in AUR
check_aur_available() {
  local pkg="$1"
  if command -v yay >/dev/null 2>&1; then
    yay -Ss "^$pkg$" >/dev/null 2>&1
  else
    return 1
  fi
}

# Manual TLP installation from source
install_tlp_manual() {
  info "Installing TLP from source..."
  
  local tmpdir_tlp
  tmpdir_tlp=$(mktemp -d)
  
  pushd "$tmpdir_tlp" > /dev/null || return 1
  
  # Clone TLP repository
  if ! git clone https://github.com/linrunner/TLP.git .; then
    err "Failed to clone TLP repository"
    popd > /dev/null
    rm -rf "$tmpdir_tlp"
    return 1
  fi
    
  # Check dependencies
  local deps=("make" "gcc" "pkg-config" "libpciaccess" "libnl" "libudev-zero")
  local missing_deps=()
  
  for dep in "${deps[@]}"; do
    if ! pacman -Q "$dep" >/dev/null 2>&1; then
      missing_deps+=("$dep")
    fi
  done
  
  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    info "Installing missing dependencies: ${missing_deps[*]}"
    for dep in "${missing_deps[@]}"; do
      pac "$dep" || warn "Failed to install dependency: $dep"
    done
  fi
  
  # Build and install
  if make && sudo make install; then
    success "TLP installed from source"
    popd > /dev/null
    rm -rf "$tmpdir_tlp"
    return 0
  else
    err "Failed to build/install TLP from source"
    popd > /dev/null
    rm -rf "$tmpdir_tlp"
    return 1
  fi
}

# Manual TLP RDW installation from source
install_tlp_rdw_manual() {
  info "Installing TLP RDW from source..."
  
  local tmpdir_rdw
  tmpdir_rdw=$(mktemp -d)
  
  pushd "$tmpdir_rdw" > /dev/null || return 1
  
  # Clone TLP repository
  if ! git clone https://github.com/linrunner/TLP.git .; then
    err "Failed to clone TLP repository for RDW"
    popd > /dev/null
    rm -rf "$tmpdir_rdw"
    return 1
  fi
  
  # Check if rdw directory exists
  if [[ ! -d "rdw" ]]; then
    err "TLP RDW source not found in repository"
    popd > /dev/null
    rm -rf "$tmpdir_rdw"
    return 1
  fi
  
  # Install RDW
  pushd "rdw" > /dev/null || return 1
  
  if make && sudo make install; then
    success "TLP RDW installed from source"
    popd > /dev/null
    popd > /dev/null
    rm -rf "$tmpdir_rdw"
    return 0
  else
    err "Failed to build/install TLP RDW from source"
    popd > /dev/null
    popd > /dev/null
    rm -rf "$tmpdir_rdw"
    return 1
  fi
}

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
  
  # Function to install TLP with fallbacks
  install_tlp_with_fallbacks() {
    local tlp_installed=false
    local tlp_rdw_installed=false
    
    info "Installing TLP (Linux Advanced Power Management)..."
    
    # Method 1: Try official repository first
    if check_package_available "tlp"; then
      info "TLP available in official repository, installing..."
      if pac tlp; then
        tlp_installed=true
        success "TLP installed from official repository"
      else
        warn "Failed to install TLP from official repository"
      fi
    fi
    
    # Method 2: Try AUR if official repo failed
    if [[ "$tlp_installed" == false ]] && check_aur_available "tlp"; then
      info "TLP available in AUR, installing via yay..."
      if aur tlp; then
        tlp_installed=true
        success "TLP installed from AUR"
      else
        warn "Failed to install TLP from AUR"
      fi
    fi
    
    # Method 3: Try alternative package names
    if [[ "$tlp_installed" == false ]]; then
      info "Trying alternative TLP package names..."
      
      # Try tlp-git from AUR
      if check_aur_available "tlp-git"; then
        info "Installing tlp-git from AUR..."
        if aur tlp-git; then
          tlp_installed=true
          success "TLP installed as tlp-git from AUR"
        fi
      fi
      
      # Try tlp-rdw-git if still not installed
      if [[ "$tlp_installed" == false ]] && check_aur_available "tlp-rdw-git"; then
        info "Installing tlp-rdw-git from AUR (includes TLP)..."
        if aur tlp-rdw-git; then
          tlp_installed=true
          success "TLP installed via tlp-rdw-git"
        fi
      fi
    fi
    
    # Method 4: Manual compilation if all else fails
    if [[ "$tlp_installed" == false ]]; then
      warn "All package manager methods failed, attempting manual compilation..."
      if install_tlp_manual; then
        tlp_installed=true
        success "TLP installed via manual compilation"
      else
        err "Failed to install TLP via all methods"
        return 1
      fi
    fi
    
    # Install TLP RDW (Radio Device Wizard)
    info "Installing TLP RDW (Radio Device Wizard)..."
    
    # Method 1: Official repository
    if check_package_available "tlp-rdw"; then
      info "TLP RDW available in official repository, installing..."
      if pac tlp-rdw; then
        tlp_rdw_installed=true
        success "TLP RDW installed from official repository"
      else
        warn "Failed to install TLP RDW from official repository"
      fi
    fi
    
    # Method 2: AUR
    if [[ "$tlp_rdw_installed" == false ]] && check_aur_available "tlp-rdw"; then
      info "TLP RDW available in AUR, installing via yay..."
      if aur tlp-rdw; then
        tlp_rdw_installed=true
        success "TLP RDW installed from AUR"
      else
        warn "Failed to install TLP RDW from AUR"
      fi
    fi
    
    # Method 3: Alternative names
    if [[ "$tlp_rdw_installed" == false ]]; then
      info "Trying alternative TLP RDW package names..."
      
      # Try tlp-rdw-git
      if check_aur_available "tlp-rdw-git"; then
        info "Installing tlp-rdw-git from AUR..."
        if aur tlp-rdw-git; then
          tlp_rdw_installed=true
          success "TLP RDW installed as tlp-rdw-git"
        fi
      fi
    fi
    
    # Method 4: Manual compilation if needed
    if [[ "$tlp_rdw_installed" == false ]]; then
      warn "All package manager methods failed for TLP RDW, attempting manual compilation..."
      if install_tlp_rdw_manual; then
        tlp_rdw_installed=true
        success "TLP RDW installed via manual compilation"
      else
        warn "Failed to install TLP RDW, but continuing with TLP only"
      fi
    fi
    
    return 0
  }
  
  # Install TLP with all fallbacks
  if ! install_tlp_with_fallbacks; then
    err "Failed to install TLP power management tools"
    return 1
  fi
  
  # Install thermald for thermal management
  info "Installing thermald (thermal management daemon)..."
  if check_package_available "thermald"; then
    if pac thermald; then
      success "thermald installed from official repository"
    else
      warn "Failed to install thermald from official repository"
    fi
  elif check_aur_available "thermald"; then
    if aur thermald; then
      success "thermald installed from AUR"
    else
      warn "Failed to install thermald from AUR"
    fi
  else
    warn "thermald not available in official repos or AUR"
  fi
  
  # Enable services
  if ! is_debug_mode; then
    # Check if TLP service exists, create if not
    if [[ ! -f /usr/lib/systemd/system/tlp.service ]] && [[ ! -f /etc/systemd/system/tlp.service ]]; then
      warn "TLP service file not found, creating manual service..."
      create_tlp_service
    fi
    
    # Check if thermald service exists, create if not
    if [[ ! -f /usr/lib/systemd/system/thermald.service ]] && [[ ! -f /etc/systemd/system/thermald.service ]]; then
      warn "thermald service file not found, creating manual service..."
      create_thermald_service
    fi
    
    # Enable services
    if systemctl list-unit-files | grep -q "tlp.service"; then
      sudo systemctl enable tlp.service
      
      # Start service if not running
      if ! systemctl is-active tlp >/dev/null 2>&1; then
        sudo systemctl start tlp.service
      fi
    else
      warn "TLP service not found in systemd, manual start required"
    fi
    
    if systemctl list-unit-files | grep -q "thermald.service"; then
      sudo systemctl enable thermald.service
      
      # Start service if not running
      if ! systemctl is-active thermald >/dev/null 2>&1; then
        sudo systemctl start thermald.service
      fi
    else
      warn "thermald service not found in systemd, manual start required"
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
    warn "TLP configuration file not found, creating default configuration..."
    create_tlp_config
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
  
  # Create X11 config directory if it doesn't exist
  local config_dir="/etc/X11/xorg.conf.d"
  if [[ ! -d "$config_dir" ]]; then
    info "Creating X11 configuration directory: $config_dir"
    sudo mkdir -p "$config_dir"
  fi
  
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
    # Check if fwupd service exists, create if not
    if [[ ! -f /usr/lib/systemd/system/fwupd.service ]] && [[ ! -f /etc/systemd/system/fwupd.service ]]; then
      warn "fwupd service file not found, creating manual service..."
      create_fwupd_service
    fi
    
    # Enable fwupd service
    if systemctl list-unit-files | grep -q "fwupd.service"; then
      sudo systemctl enable fwupd.service
      
      if ! systemctl is-active fwupd >/dev/null 2>&1; then
        sudo systemctl start fwupd.service
      fi
    else
      warn "fwupd service not found in systemd, manual start required"
    fi
  fi
  
  success "Firmware update utilities configured"
  CONFIGURED_RUNTIMES+=("fwupd firmware updater")
}

# Create shutdown hook to prevent hanging
create_dell_xps_shutdown_hook() {
  info "Creating Dell XPS shutdown hook to prevent freezes..."
  
  local hook_file="/etc/systemd/system-shutdown/dell-xps-cleanup.shutdown"
  
  if is_debug_mode; then
    info "[DEBUG] Would create shutdown hook at $hook_file"
    return 0
  fi
  
  # Create shutdown directory if it doesn't exist
  sudo mkdir -p "/etc/systemd/system-shutdown"
  
  # Create shutdown hook script
  sudo tee "$hook_file" > /dev/null << 'EOF'
#!/bin/bash
# Dell XPS shutdown cleanup hook
# Prevents shutdown hangs by properly stopping services and unloading modules

# Only run on shutdown/reboot
if [[ "$1" != "halt" ]] && [[ "$1" != "poweroff" ]] && [[ "$1" != "reboot" ]]; then
    exit 0
fi

echo "Dell XPS shutdown cleanup starting..."

# Stop TLP services gracefully
systemctl --no-block stop tlp.service 2>/dev/null || true
systemctl --no-block stop thermald.service 2>/dev/null || true
systemctl --no-block stop fwupd.service 2>/dev/null || true

# Kill any hanging processes
pkill -f "tlp" 2>/dev/null || true
pkill -f "thermald" 2>/dev/null || true
pkill -f "fwupd" 2>/dev/null || true

# Unload problematic kernel modules
modprobe -r ipu6_drivers 2>/dev/null || true
modprobe -r intel_ipu6_isys 2>/dev/null || true
modprobe -r intel_ipu6_psys 2>/dev/null || true

# Disable USB devices that might hang
for usb_device in /sys/bus/usb/devices/*/power/control; do
    [[ -w "$usb_device" ]] && echo "on" > "$usb_device" 2>/dev/null || true
done

# Disable runtime PM for all PCI devices to prevent hangs
for pci_device in /sys/bus/pci/devices/*/power/control; do
    [[ -w "$pci_device" ]] && echo "on" > "$pci_device" 2>/dev/null || true
done

# Force sync filesystems
sync

echo "Dell XPS shutdown cleanup completed"
exit 0
EOF

  # Make executable
  sudo chmod +x "$hook_file"
  
  success "Dell XPS shutdown hook created: $hook_file"
  info "This hook will run during shutdown to prevent hanging"
  
  return 0
}

# Create systemd service to handle shutdown more gracefully
create_dell_xps_shutdown_service() {
  info "Creating Dell XPS graceful shutdown service..."
  
  local service_file="/etc/systemd/system/dell-xps-shutdown.service"
  
  if is_debug_mode; then
    info "[DEBUG] Would create shutdown service at $service_file"
    return 0
  fi
  
  # Create shutdown service
  sudo tee "$service_file" > /dev/null << 'EOF'
[Unit]
Description=Dell XPS Graceful Shutdown Handler
DefaultDependencies=false
Before=shutdown.target reboot.target halt.target
Requires=-.mount

[Service]
Type=oneshot
RemainAfterExit=true
ExecStop=/bin/bash -c '
echo "Dell XPS graceful shutdown starting...";

# Stop services with timeout
timeout 5 systemctl stop tlp.service 2>/dev/null || true;
timeout 5 systemctl stop thermald.service 2>/dev/null || true;
timeout 5 systemctl stop fwupd.service 2>/dev/null || true;

# Kill any remaining processes
pkill -TERM -f "tlp|thermald|fwupd" 2>/dev/null || true;
sleep 2;
pkill -KILL -f "tlp|thermald|fwupd" 2>/dev/null || true;

# Unload modules
modprobe -r ipu6_drivers 2>/dev/null || true;
modprobe -r intel_ipu6_isys 2>/dev/null || true;
modprobe -r intel_ipu6_psys 2>/dev/null || true;

# Add specific Dell XPS 13 Plus shutdown workarounds
echo "Dell XPS graceful shutdown completed";
'
TimeoutStopSec=10
KillMode=none

[Install]
WantedBy=multi-user.target
EOF

  # Enable the service
  sudo systemctl daemon-reload
  sudo systemctl enable dell-xps-shutdown.service
  
  success "Dell XPS graceful shutdown service created and enabled"
  
  return 0
}

# Add kernel parameters to prevent XPS shutdown hangs
configure_dell_xps_kernel_params() {
  info "Configuring kernel parameters to prevent Dell XPS shutdown hangs..."
  
  local grub_config="/etc/default/grub"
  local backup_file="${grub_config}.backup.$(date +%Y%m%d_%H%M%S)"
  
  if [[ ! -f "$grub_config" ]]; then
    warn "GRUB configuration not found: $grub_config"
    return 1
  fi
  
  if is_debug_mode; then
    info "[DEBUG] Would add kernel parameters to prevent shutdown hangs"
    return 0
  fi
  
  # Backup GRUB config
  sudo cp "$grub_config" "$backup_file"
  info "GRUB config backed up to: $backup_file"
  
  # Kernel parameters to add
  local kernel_params="reboot=acpi,force acpi_sleep=s3_bios,s3_mode button.lid_init_state=open"
  
  # Check if parameters already exist
  if grep -q "reboot=acpi,force" "$grub_config"; then
    info "Dell XPS kernel parameters already configured"
    return 0
  fi
  
  # Add parameters to GRUB_CMDLINE_LINUX_DEFAULT
  if grep -q "^GRUB_CMDLINE_LINUX_DEFAULT=" "$grub_config"; then
    # Replace existing line
    sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $kernel_params\"/" "$grub_config"
  else
    # Add new line
    echo "GRUB_CMDLINE_LINUX_DEFAULT=\"$kernel_params\"" | sudo tee -a "$grub_config" > /dev/null
  fi
  
  # Update GRUB
  info "Updating GRUB configuration..."
  if command -v grub-mkconfig >/dev/null 2>&1; then
    sudo grub-mkconfig -o /boot/grub/grub.cfg
    success "GRUB configuration updated"
  else
    warn "grub-mkconfig not found, please update GRUB manually"
  fi
  
  success "Dell XPS kernel parameters configured"
  info "Added parameters: $kernel_params"
  
  return 0
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
  
  # Create shutdown hooks to prevent hanging (IMPORTANT FIX)
  create_dell_xps_shutdown_hook
  create_dell_xps_shutdown_service
  configure_dell_xps_kernel_params
  
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
  
  echo -e "\n${CYAN}Shutdown Fix:${NC}"
  echo "• Shutdown hooks installed to prevent freezing"
  echo "• Kernel parameters added for reliable reboot"
  echo "• Services will stop gracefully during shutdown"
  
  echo -e "\n${CYAN}Next Steps:${NC}"
  echo "• Reboot to activate all drivers and kernel parameters"
  echo "• Check webcam: cheese"
  echo "• Check TLP status: sudo tlp-stat"
  echo "• Update firmware: sudo fwupdmgr refresh && sudo fwupdmgr update"
  
  echo
}

# Functions will be exported at the end of the file after all definitions

# Create TLP systemd service manually
create_tlp_service() {
  info "Creating TLP systemd service manually..."
  
  local service_file="/etc/systemd/system/tlp.service"
  
  # Create service file
  sudo tee "$service_file" > /dev/null << 'EOF'
[Unit]
Description=TLP - Linux Advanced Power Management
Documentation=https://linrunner.de/tlp/
After=network.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/bin/tlp start
ExecStop=/usr/bin/tlp stop
TimeoutSec=0

[Install]
WantedBy=multi-user.target
EOF

  # Reload systemd
  sudo systemctl daemon-reload
  
  if [[ -f "$service_file" ]]; then
    success "TLP service created: $service_file"
    return 0
  else
    err "Failed to create TLP service file"
    return 1
  fi
}

# Create thermald systemd service manually
create_thermald_service() {
  info "Creating thermald systemd service manually..."
  
  local service_file="/etc/systemd/system/thermald.service"
  
  # Create service file
  sudo tee "$service_file" > /dev/null << 'EOF'
[Unit]
Description=Thermal Daemon Service
Documentation=https://github.com/intel/thermal_daemon
After=syslog.target

[Service]
Type=simple
ExecStart=/usr/bin/thermald --no-daemon --log-level=info
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

  # Reload systemd
  sudo systemctl daemon-reload
  
  if [[ -f "$service_file" ]]; then
    success "thermald service created: $service_file"
    return 0
  else
    err "Failed to create thermald service file"
    return 1
  fi
}

# Create fwupd systemd service manually
create_fwupd_service() {
  info "Creating fwupd systemd service manually..."
  
  local service_file="/etc/systemd/system/fwupd.service"
  
  # Create service file
  sudo tee "$service_file" > /dev/null << 'EOF'
[Unit]
Description=Firmware update daemon
Documentation=man:fwupd(8)
After=syslog.target

[Service]
Type=simple
ExecStart=/usr/bin/fwupd --daemon
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

  # Reload systemd
  sudo systemctl daemon-reload
  
  if [[ -f "$service_file" ]]; then
    success "fwupd service created: $service_file"
    return 0
  else
    err "Failed to create fwupd service file"
    return 1
  fi
}

# Create TLP configuration file
create_tlp_config() {
  info "Creating TLP configuration file..."
  
  local tlp_config="/etc/tlp.conf"
  
  # Create config file with Dell XPS optimizations
  sudo tee "$tlp_config" > /dev/null << 'EOF'
# TLP Configuration for Dell XPS 13 Plus (9320)
# Generated by Exarch Scripts

# Default TLP settings
TLP_ENABLE=1
TLP_DEFAULT_MODE=AC
DISK_IDLE_SECS_ON_AC=0
DISK_IDLE_SECS_ON_BAT=2
MAX_LOST_WORK_SECS_ON_AC=15
MAX_LOST_WORK_SECS_ON_BAT=60

# CPU scaling governor
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

# Battery optimization
START_CHARGE_THRESH_BAT0=40
STOP_CHARGE_THRESH_BAT0=80

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

# Audio power saving
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y

# Runtime power management
RUNTIME_PM_ON_AC=on
RUNTIME_PM_ON_BAT=auto
EOF

  if [[ -f "$tlp_config" ]]; then
    success "TLP configuration created: $tlp_config"
    return 0
  else
    err "Failed to create TLP configuration file"
    return 1
  fi
}

# Cleanup function to ensure clean shutdown
cleanup_dell_xps_services() {
  info "Cleaning up Dell XPS services for clean shutdown..."
  
  # Stop TLP services
  if systemctl is-active tlp >/dev/null 2>&1; then
    info "Stopping TLP service..."
    sudo systemctl stop tlp
  fi
  
  if systemctl is-active thermald >/dev/null 2>&1; then
    info "Stopping thermald service..."
    sudo systemctl stop thermald
  fi
  
  if systemctl is-active fwupd >/dev/null 2>&1; then
    info "Stopping fwupd service..."
    sudo systemctl stop fwupd
  fi
  
  # Unload IPU6 modules if loaded
  local modules=("ipu6_drivers" "intel_ipu6_isys" "intel_ipu6_psys")
  for module in "${modules[@]}"; do
    if lsmod | grep -q "^$module "; then
      info "Unloading module: $module"
      sudo modprobe -r "$module" 2>/dev/null || warn "Failed to unload $module"
    fi
  done
  
  # Kill any remaining processes
  local processes=("tlp" "thermald" "fwupd" "ipu6")
  for proc in "${processes[@]}"; do
    local pids
    pids=$(pgrep "$proc" 2>/dev/null)
    if [[ -n "$pids" ]]; then
      info "Terminating $proc processes: $pids"
      echo "$pids" | xargs -r sudo kill -TERM 2>/dev/null
      sleep 1
      echo "$pids" | xargs -r sudo kill -KILL 2>/dev/null
    fi
  done
  
  # Sync filesystems
  info "Syncing filesystems..."
  sudo sync
  
  success "Cleanup completed - safe to reboot"
}

# Export all functions at the end after they are defined
export -f setup_dell_xps_9320_webcam install_ivsc_firmware install_ivsc_firmware_manual
export -f install_ipu6_drivers configure_dell_xps_kernel_modules
export -f install_dell_xps_power_management configure_tlp_dell_xps
export -f check_package_available check_aur_available install_tlp_manual install_tlp_rdw_manual
export -f setup_dual_keyboard_dell_xps install_dell_utilities
export -f setup_dell_xps_9320_complete show_dell_xps_post_install_info
export -f create_tlp_service create_thermald_service create_fwupd_service create_tlp_config cleanup_dell_xps_services
export -f create_dell_xps_shutdown_hook create_dell_xps_shutdown_service configure_dell_xps_kernel_params