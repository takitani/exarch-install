#!/bin/bash

# modules/pipewire-camera.sh - PipeWire Camera support for Chrome/Chromium
# Integrates the PipeWire camera patch functionality

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"

# Source the actual patch implementation
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../helpers/pipewire-camera-patch.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../helpers/pipewire-camera-patch.sh"

# Setup PipeWire camera support
setup_pipewire_camera() {
  info "Setting up PipeWire camera support for Chrome/Chromium..."
  
  # Check if we're in debug mode
  if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
    info "[DEBUG] Configurando suporte à webcam PipeWire (simulado)"
    CONFIGURED_RUNTIMES+=("PipeWire Camera support (simulado)")
    return 0
  fi
  
  # Use the isolated script if available
  local fix_script="$(dirname "${BASH_SOURCE[0]}")/../helpers/fix-chromium-desktop.sh"
  
  if [[ -f "$fix_script" ]] && [[ -x "$fix_script" ]]; then
    info "Using isolated fix-chromium-desktop.sh script..."
    
    # Run the script in non-interactive mode
    if bash "$fix_script" --non-interactive 2>/dev/null; then
      success "PipeWire camera support configured successfully"
      CONFIGURED_RUNTIMES+=("PipeWire Camera support - Chrome/Chromium configurados")
      return 0
    else
      warn "Isolated script failed, falling back to direct patch"
    fi
  fi
  
  # Fallback: Install required packages
  pac pipewire-libcamera || warn "Failed to install pipewire-libcamera"
  
  # Apply the camera patch
  if command -v apply_pipewire_camera_patch >/dev/null 2>&1; then
    apply_pipewire_camera_patch
    CONFIGURED_RUNTIMES+=("PipeWire Camera support - Chrome/Chromium configurados")
  else
    warn "PipeWire camera patch function not available"
    return 1
  fi
}

# Check if PipeWire camera is configured
check_pipewire_camera() {
  # Check for common indicators that the patch was applied
  local chromium_flags="$HOME/.config/chromium-flags.conf"
  local chrome_flags="$HOME/.config/google-chrome-flags.conf"
  
  if [[ -f "$chromium_flags" ]] && grep -q "enable-webrtc-pipewire-camera" "$chromium_flags"; then
    return 0
  fi
  
  if [[ -f "$chrome_flags" ]] && grep -q "enable-webrtc-pipewire-camera" "$chrome_flags"; then
    return 0
  fi
  
  return 1
}

# Export functions
export -f setup_pipewire_camera check_pipewire_camera