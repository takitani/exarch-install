#!/usr/bin/env bash
# lib/hardware-detection.sh - Hardware detection and system information

# Source core functions
[[ -f "$(dirname "${BASH_SOURCE[0]}")/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Detect hardware model
detect_hardware() {
  local product_name=""
  if [[ -f /sys/devices/virtual/dmi/id/product_name ]]; then
    product_name=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "")
  fi
  echo "$product_name"
}

# Check if system is Dell XPS 13 Plus (9320)
is_dell_xps_9320() {
  local hardware
  hardware=$(detect_hardware)
  
  if [[ "$hardware" == *"XPS 13 9320"* ]] || is_xps_mode; then
    return 0
  fi
  return 1
}

# Get detailed hardware information
get_hardware_info() {
  local info=()
  
  # System information
  if [[ -f /sys/devices/virtual/dmi/id/sys_vendor ]]; then
    local vendor=$(cat /sys/devices/virtual/dmi/id/sys_vendor 2>/dev/null)
    [[ -n "$vendor" ]] && info+=("Vendor: $vendor")
  fi
  
  if [[ -f /sys/devices/virtual/dmi/id/product_name ]]; then
    local model=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null)
    [[ -n "$model" ]] && info+=("Model: $model")
  fi
  
  if [[ -f /sys/devices/virtual/dmi/id/product_version ]]; then
    local version=$(cat /sys/devices/virtual/dmi/id/product_version 2>/dev/null)
    [[ -n "$version" ]] && info+=("Version: $version")
  fi
  
  # CPU information
  if [[ -f /proc/cpuinfo ]]; then
    local cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^ *//')
    [[ -n "$cpu_model" ]] && info+=("CPU: $cpu_model")
    
    local cpu_cores=$(nproc)
    [[ -n "$cpu_cores" ]] && info+=("CPU Cores: $cpu_cores")
  fi
  
  # Memory information
  if [[ -f /proc/meminfo ]]; then
    local memory_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
    if [[ -n "$memory_kb" ]]; then
      local memory_gb=$(( memory_kb / 1024 / 1024 ))
      info+=("Memory: ${memory_gb}GB")
    fi
  fi
  
  # Graphics information
  if command_exists lspci; then
    local gpu=$(lspci | grep -i vga | head -1 | cut -d':' -f3 | sed 's/^ *//')
    [[ -n "$gpu" ]] && info+=("GPU: $gpu")
  fi
  
  # Storage information
  if command_exists lsblk; then
    local storage=$(lsblk -d -o NAME,SIZE | grep -v "NAME" | head -3 | while read name size; do echo "$name ($size)"; done | tr '\n' ' ')
    [[ -n "$storage" ]] && info+=("Storage: $storage")
  fi
  
  # Print information
  for item in "${info[@]}"; do
    echo "$item"
  done
}

# Check for specific hardware features
has_touchscreen() {
  if command_exists xinput; then
    xinput list | grep -qi "touchscreen\|touch screen" && return 0
  fi
  
  # Check for touch devices in /proc/bus/input/devices
  if [[ -f /proc/bus/input/devices ]]; then
    grep -qi "touchscreen\|touch screen" /proc/bus/input/devices && return 0
  fi
  
  return 1
}

# Check for webcam
has_webcam() {
  # Check for video devices
  if ls /dev/video* >/dev/null 2>&1; then
    return 0
  fi
  
  # Check via lsusb for USB webcams
  if command_exists lsusb; then
    lsusb | grep -qi "camera\|webcam\|video" && return 0
  fi
  
  return 1
}

# Check for specific webcam issues (Dell XPS IPU6)
has_ipu6_webcam() {
  if command_exists lspci; then
    # Look for Intel IPU6 (Imaging Processing Unit 6)
    lspci | grep -qi "ipu6\|imaging.*processing" && return 0
  fi
  
  # Check dmesg for IPU6 references
  if dmesg 2>/dev/null | grep -qi "ipu6"; then
    return 0
  fi
  
  return 1
}

# Check for Intel graphics
has_intel_graphics() {
  if command_exists lspci; then
    lspci | grep -qi "intel.*graphics\|intel.*vga" && return 0
  fi
  return 1
}

# Check for NVIDIA graphics
has_nvidia_graphics() {
  if command_exists lspci; then
    lspci | grep -qi "nvidia" && return 0
  fi
  return 1
}

# Check for AMD graphics
has_amd_graphics() {
  if command_exists lspci; then
    lspci | grep -qi "amd\|radeon" && return 0
  fi
  return 1
}

# Check if system supports hardware acceleration
supports_hardware_acceleration() {
  # Check for VA-API support
  if command_exists vainfo; then
    vainfo >/dev/null 2>&1 && return 0
  fi
  
  # Check for VDPAU support
  if command_exists vdpauinfo; then
    vdpauinfo >/dev/null 2>&1 && return 0
  fi
  
  return 1
}

# Get battery information
get_battery_info() {
  local batteries=()
  
  # Check /sys/class/power_supply for batteries
  if [[ -d /sys/class/power_supply ]]; then
    for battery in /sys/class/power_supply/BAT*; do
      if [[ -d "$battery" ]]; then
        local name=$(basename "$battery")
        local capacity=""
        local status=""
        
        if [[ -f "$battery/capacity" ]]; then
          capacity=$(cat "$battery/capacity" 2>/dev/null)
        fi
        
        if [[ -f "$battery/status" ]]; then
          status=$(cat "$battery/status" 2>/dev/null)
        fi
        
        batteries+=("$name: ${capacity}% ($status)")
      fi
    done
  fi
  
  if [[ ${#batteries[@]} -gt 0 ]]; then
    printf '%s\n' "${batteries[@]}"
  else
    echo "No battery detected"
  fi
}

# Check for specific power management features
supports_tlp() {
  # TLP works best on laptops
  if [[ -d /sys/class/power_supply/BAT0 ]] || [[ -d /sys/class/power_supply/BAT1 ]]; then
    return 0
  fi
  return 1
}

# Check wireless capabilities
get_wireless_info() {
  local wireless=()
  
  # WiFi interfaces
  if command_exists iw; then
    local wifi_interfaces=$(iw dev | grep "Interface" | awk '{print $2}')
    for interface in $wifi_interfaces; do
      wireless+=("WiFi: $interface")
    done
  fi
  
  # Bluetooth
  if command_exists bluetoothctl; then
    if systemctl is-active bluetooth >/dev/null 2>&1; then
      wireless+=("Bluetooth: enabled")
    else
      wireless+=("Bluetooth: available but disabled")
    fi
  fi
  
  if [[ ${#wireless[@]} -gt 0 ]]; then
    printf '%s\n' "${wireless[@]}"
  else
    echo "No wireless capabilities detected"
  fi
}

# Comprehensive hardware report
show_hardware_report() {
  echo
  echo -e "${BOLD}Hardware Information${NC}"
  echo "===================="
  
  echo
  echo -e "${CYAN}System:${NC}"
  get_hardware_info
  
  echo
  echo -e "${CYAN}Special Features:${NC}"
  has_touchscreen && echo "✓ Touchscreen detected" || echo "✗ No touchscreen"
  has_webcam && echo "✓ Webcam detected" || echo "✗ No webcam"
  has_ipu6_webcam && echo "⚠ IPU6 webcam detected (may need special drivers)"
  
  echo
  echo -e "${CYAN}Graphics:${NC}"
  has_intel_graphics && echo "✓ Intel graphics"
  has_nvidia_graphics && echo "✓ NVIDIA graphics"
  has_amd_graphics && echo "✓ AMD graphics"
  supports_hardware_acceleration && echo "✓ Hardware acceleration supported"
  
  echo
  echo -e "${CYAN}Power:${NC}"
  get_battery_info
  supports_tlp && echo "✓ TLP power management recommended"
  
  echo
  echo -e "${CYAN}Wireless:${NC}"
  get_wireless_info
  
  echo
  echo -e "${CYAN}Dell XPS Detection:${NC}"
  if is_dell_xps_9320; then
    echo "✓ Dell XPS 13 Plus (9320) detected"
    echo "  → Special optimizations available"
    echo "  → IPU6 webcam support available"
    echo "  → TLP power management recommended"
  else
    echo "✗ Not a Dell XPS 13 Plus (9320)"
  fi
  
  echo
}

# Export hardware detection functions
export -f detect_hardware is_dell_xps_9320 get_hardware_info
export -f has_touchscreen has_webcam has_ipu6_webcam
export -f has_intel_graphics has_nvidia_graphics has_amd_graphics
export -f supports_hardware_acceleration get_battery_info
export -f supports_tlp get_wireless_info show_hardware_report