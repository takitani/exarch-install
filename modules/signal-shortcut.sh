#!/bin/bash
# Remove Signal shortcut from Hyprland configuration

remove_signal_shortcut() {
  info "Removing Signal shortcut from Hyprland configuration..."
  
  local hypr_bindings_file="$HOME/.config/hypr/bindings.conf"
  
  # Check if file exists
  if [[ ! -f "$hypr_bindings_file" ]]; then
    warn "Hyprland bindings file not found at $hypr_bindings_file"
    return 1
  fi
  
  # Check if Signal binding exists
  if ! grep -q "bindd = SUPER, G, Signal" "$hypr_bindings_file"; then
    info "Signal shortcut not found in configuration - nothing to remove"
    return 0
  fi
  
  # Create backup
  local backup_file="${hypr_bindings_file}.backup.$(date +%Y%m%d_%H%M%S)"
  cp "$hypr_bindings_file" "$backup_file"
  info "Created backup at $backup_file"
  
  # Remove the Signal shortcut line
  if sed -i '/bindd = SUPER, G, Signal, exec, uwsm app -- signal-desktop/d' "$hypr_bindings_file"; then
    success "Signal shortcut (Super+G) removed successfully"
    
    # Check if removal was successful
    if grep -q "bindd = SUPER, G, Signal" "$hypr_bindings_file"; then
      err "Failed to remove Signal shortcut from configuration"
      # Restore backup
      mv "$backup_file" "$hypr_bindings_file"
      return 1
    fi
    
    info "You may need to reload Hyprland configuration for changes to take effect"
    info "Use: hyprctl reload"
    return 0
  else
    err "Failed to modify Hyprland configuration"
    # Restore backup
    mv "$backup_file" "$hypr_bindings_file"
    return 1
  fi
}

# Export the function
export -f remove_signal_shortcut