#!/bin/bash
# Script para restaurar configuração PT-BR com teclado US Internacional

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Stop fcitx5 if running
stop_fcitx5() {
    print_status "Stopping fcitx5 input method..."
    pkill -f fcitx5 || true
    sleep 2
    print_success "fcitx5 stopped"
}

# Configure locale for PT-BR with US keyboard
configure_locale() {
    print_status "Configuring locale for PT-BR..."
    
    # Set LC_CTYPE to pt_BR for character support (acentos, cedilha)
    # Keep LANG as en_US for English system messages
    sudo localectl set-locale LC_CTYPE=pt_BR.UTF-8
    
    print_success "Locale configured: LC_CTYPE=pt_BR.UTF-8"
}

# Configure keyboard layout
configure_keyboard() {
    print_status "Configuring US International keyboard layout..."
    
    # Set US International layout for X11 and console
    sudo localectl set-x11-keymap us pc105 intl terminate:ctrl_alt_bksp
    sudo localectl set-keymap us
    
    print_success "Keyboard layout configured: US International"
}

# Clean up fcitx5 environment variables if present
cleanup_fcitx_env() {
    print_status "Cleaning up fcitx5 environment variables..."
    
    # Remove from user profile if present
    if [[ -f ~/.profile ]] && grep -q "GTK_IM_MODULE=fcitx" ~/.profile 2>/dev/null; then
        sed -i '/# fcitx5 input method environment variables/,/export GLFW_IM_MODULE=ibus/d' ~/.profile
        print_status "Removed fcitx5 variables from ~/.profile"
    fi
    
    # Remove environment.d config if present
    if [[ -f ~/.config/environment.d/fcitx5.conf ]]; then
        rm ~/.config/environment.d/fcitx5.conf
        print_status "Removed ~/.config/environment.d/fcitx5.conf"
    fi
    
    # Clean current session environment
    unset GTK_IM_MODULE QT_IM_MODULE XMODIFIERS SDL_IM_MODULE GLFW_IM_MODULE 2>/dev/null || true
    
    print_success "fcitx5 environment cleanup completed"
}

# Update Hyprland configuration to remove fcitx5
cleanup_hyprland_fcitx() {
    local hypr_conf="$HOME/.config/hypr/hyprland.conf"
    local env_conf="$HOME/.config/hypr/environment.conf"
    
    print_status "Cleaning up Hyprland fcitx5 configuration..."
    
    # Remove environment.conf if it exists
    if [[ -f "$env_conf" ]]; then
        rm "$env_conf"
        print_status "Removed $env_conf"
    fi
    
    # Remove source line from hyprland.conf if present
    if [[ -f "$hypr_conf" ]] && grep -q "source.*environment.conf" "$hypr_conf"; then
        sed -i '/# Source environment variables for input methods/d' "$hypr_conf"
        sed -i '/source.*environment.conf/d' "$hypr_conf"
        print_status "Removed environment.conf source from hyprland.conf"
    fi
    
    print_success "Hyprland fcitx5 configuration cleaned up"
}

# Create a simple Hyprland keyboard configuration
create_hyprland_keyboard_config() {
    local hypr_conf="$HOME/.config/hypr/hyprland.conf"
    
    print_status "Adding US International keyboard to Hyprland config..."
    
    # Check if keyboard config already exists
    if ! grep -q "kb_layout.*us" "$hypr_conf" 2>/dev/null; then
        cat >> "$hypr_conf" << 'EOF'

# Keyboard configuration - US International for PT-BR support
input {
    kb_layout = us
    kb_variant = intl
    kb_model = pc105
    kb_options = terminate:ctrl_alt_bksp
    
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
    sensitivity = 0
}
EOF
        print_success "Added US International keyboard config to Hyprland"
    else
        print_status "Hyprland keyboard config already present"
    fi
}

# Test the configuration
test_configuration() {
    print_status "Testing configuration..."
    
    # Show current locale
    echo -e "\n${BLUE}Current locale settings:${NC}"
    locale | grep -E "(LANG|LC_CTYPE)"
    
    # Show keyboard layout
    echo -e "\n${BLUE}Current keyboard layout:${NC}"
    localectl status | grep -E "(X11 Layout|X11 Variant|VC Keymap)"
    
    echo -e "\n${GREEN}Configuration test completed!${NC}"
    
    print_status "How to test acentos/cedilha (US International dead keys):"
    echo "  • ' + c = ç (apostrophe + c)"
    echo "  • ' + a = á (apostrophe + a)"
    echo "  • ' + e = é (apostrophe + e)"
    echo "  • ' + i = í (apostrophe + i)"
    echo "  • ' + o = ó (apostrophe + o)"
    echo "  • ' + u = ú (apostrophe + u)"
    echo "  • ^ + a = â (caret + a)"
    echo "  • ~ + a = ã (tilde + a)"
    echo "  • ~ + o = õ (tilde + o)"
    echo "  • \" + a = ä (quote + a)"
}

# Main function
main() {
    echo "===== Restore PT-BR Locale with US International Keyboard ====="
    echo ""
    
    print_status "This will restore your original PT-BR locale configuration"
    print_status "without fcitx5, using US International keyboard layout"
    echo ""
    
    read -p "Continue? [y/N]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled"
        exit 0
    fi
    
    # Stop fcitx5
    stop_fcitx5
    
    # Configure locale
    configure_locale
    
    # Configure keyboard  
    configure_keyboard
    
    # Clean up fcitx5 environment
    cleanup_fcitx_env
    
    # Clean up Hyprland fcitx5 config
    cleanup_hyprland_fcitx
    
    # Create proper Hyprland keyboard config
    create_hyprland_keyboard_config
    
    # Test configuration
    test_configuration
    
    echo ""
    print_success "PT-BR locale restoration completed!"
    print_warning "Please log out and log back in (or restart) for all changes to take effect"
    print_status "Your acentos and cedilha should work normally with US International layout"
}

# Run main function
main "$@"