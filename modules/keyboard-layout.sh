#!/usr/bin/env bash
# modules/keyboard-layout.sh - Keyboard Layout Configuration Module

# Setup PT-BR keyboard layout for US keyboards
setup_ptbr_keyboard_layout() {
  info "Setting up US keyboard with PT-BR layout configuration..."
  
  local helper_script="$SCRIPT_DIR/helpers/restore-ptbr-locale.sh"
  
  # Check if the helper script exists
  if [[ ! -f "$helper_script" ]]; then
    err "Helper script not found: $helper_script"
    return 1
  fi
  
  # Make sure the script is executable
  chmod +x "$helper_script"
  
  info "Running PT-BR locale restoration script..."
  
  # Execute the helper script
  if "$helper_script"; then
    success "PT-BR keyboard layout configured successfully"
    
    # Show summary
    echo
    echo -e "${BOLD}PT-BR Keyboard Layout Setup Complete!${NC}"
    echo "======================================"
    echo "• System locale configured for PT-BR"
    echo "• Keyboard layout set to US with PT-BR mapping" 
    echo "• Input method configuration updated"
    echo "• fcitx5 configured for proper Brazilian Portuguese support"
    echo
    echo "The system has been configured for US keyboards with Brazilian Portuguese layout."
    echo "This is ideal for desktop setups with US keyboards requiring PT-BR input."
    echo
    
    return 0
  else
    err "Failed to configure PT-BR keyboard layout"
    return 1
  fi
}

# Revert PT-BR keyboard layout configuration (if needed)
revert_ptbr_keyboard_layout() {
  info "Reverting PT-BR keyboard layout configuration..."
  warn "Automatic reversion not implemented yet"
  warn "To revert, manually reconfigure your system locale and keyboard settings"
  return 0
}

# Export functions
export -f setup_ptbr_keyboard_layout revert_ptbr_keyboard_layout