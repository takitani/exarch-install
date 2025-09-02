#!/bin/bash

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Function to print colored output
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

# Function to install Brazilian keyboard packages
install_brazilian_keyboard() {
    print_status "Installing Brazilian keyboard layout packages..."
    
    # Install xkeyboard-config if not already installed
    if ! pacman -Q xkeyboard-config >/dev/null 2>&1; then
        print_status "Installing xkeyboard-config..."
        sudo pacman -S --noconfirm xkeyboard-config
    fi
    
    print_success "Brazilian keyboard packages ready"
}

# Function to configure fcitx5 for Brazilian layout
configure_fcitx5_brazilian() {
    local profile_file="$HOME/.config/fcitx5/profile"
    local config_dir="$HOME/.config/fcitx5/conf"
    
    print_status "Configuring fcitx5 for Brazilian ABNT2 layout..."
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Backup existing profile
    if [[ -f "$profile_file" ]]; then
        cp "$profile_file" "${profile_file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up existing fcitx5 profile"
    fi
    
    # Create new profile with Brazilian layout
    cat > "$profile_file" << 'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=br
# Default Input Method
DefaultIM=keyboard-br

[Groups/0/Items/0]
# Name
Name=keyboard-br
# Layout
Layout=

[GroupOrder]
0=Default
EOF
    
    # Create xcb configuration
    cat > "$config_dir/xcb.conf" << 'EOF'
Allow Overriding System XKB Settings=True
EOF
    
    print_success "Configured fcitx5 with Brazilian ABNT2 layout"
}

# Function to update Hyprland input configuration
update_hyprland_input() {
    local input_conf="$HOME/.config/hypr/input.conf"
    
    print_status "Updating Hyprland input configuration for Brazilian layout..."
    
    # Backup existing input.conf
    if [[ -f "$input_conf" ]]; then
        cp "$input_conf" "${input_conf}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up existing input.conf"
    fi
    
    # Create new input configuration with Brazilian layout
    cat > "$input_conf" << 'EOF'
# Control your input devices
# See https://wiki.hypr.land/Configuring/Variables/#input
input {
  # Use Brazilian ABNT2 keyboard layout
  kb_layout = br
  kb_variant = abnt2
  kb_options = compose:ralt

  # Change speed of keyboard repeat
  repeat_rate = 40
  repeat_delay = 600

  # Increase sensitity for mouse/trackpack (default: 0)
  # sensitivity = 0.35

  touchpad {
    # Use natural (inverse) scrolling
    # natural_scroll = true

    # Use two-finger clicks for right-click instead of lower-right corner
    # clickfinger_behavior = true

    # Control the speed of your scrolling
    scroll_factor = 0.4
  }
}

# Scroll faster in the terminal
windowrule = scrolltouchpad 1.5, class:Alacritty

# Set Brazilian keyboard layout
exec-once = setxkbmap -layout br -variant abnt2 -option compose:ralt
EOF
    
    print_success "Updated Hyprland input configuration for Brazilian ABNT2"
}

# Function to create environment.d configuration
create_environment_config() {
    local env_dir="$HOME/.config/environment.d"
    local env_file="$env_dir/fcitx5.conf"
    
    print_status "Creating environment.d configuration..."
    
    # Create directory if it doesn't exist
    mkdir -p "$env_dir"
    
    # Create fcitx5 environment configuration
    cat > "$env_file" << 'EOF'
# fcitx5 environment variables for input method support
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
EOF
    
    print_success "Created $env_file"
}

# Function to update Hyprland environment configuration
update_hyprland_environment() {
    local hypr_conf="$HOME/.config/hypr/hyprland.conf"
    local env_conf="$HOME/.config/hypr/environment.conf"
    
    print_status "Updating Hyprland environment configuration..."
    
    # Create environment configuration file
    cat > "$env_conf" << 'EOF'
# Environment variables for fcitx5 input method
env = GTK_IM_MODULE,fcitx
env = QT_IM_MODULE,fcitx
env = XMODIFIERS,@im=fcitx
env = SDL_IM_MODULE,fcitx
env = GLFW_IM_MODULE,ibus
EOF
    
    # Check if environment.conf is already sourced in hyprland.conf
    if ! grep -q "source.*environment.conf" "$hypr_conf" 2>/dev/null; then
        echo "" >> "$hypr_conf"
        echo "# Source environment variables for input methods" >> "$hypr_conf"
        echo "source = ~/.config/hypr/environment.conf" >> "$hypr_conf"
        print_success "Added environment.conf source to hyprland.conf"
    else
        print_status "environment.conf already sourced in hyprland.conf"
    fi
    
    print_success "Created $env_conf"
}

# Function to update user profile
update_user_profile() {
    local profile_file="$HOME/.profile"
    
    print_status "Updating user profile with fcitx5 environment variables..."
    
    # Check if fcitx5 variables are already in profile
    if ! grep -q "GTK_IM_MODULE=fcitx" "$profile_file" 2>/dev/null; then
        cat >> "$profile_file" << 'EOF'

# fcitx5 input method environment variables
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
export SDL_IM_MODULE=fcitx
export GLFW_IM_MODULE=ibus
EOF
        print_success "Added fcitx5 environment variables to $profile_file"
    else
        print_status "fcitx5 environment variables already in $profile_file"
    fi
}

# Function to create desktop file override for Cursor
create_cursor_desktop_override() {
    local desktop_dir="$HOME/.local/share/applications"
    local cursor_desktop="$desktop_dir/cursor.desktop"
    
    print_status "Creating desktop file override for Cursor..."
    
    # Create directory if it doesn't exist
    mkdir -p "$desktop_dir"
    
    # Create desktop file override
    cat > "$cursor_desktop" << 'EOF'
[Desktop Entry]
Name=Cursor
Comment=AI-first code editor
Exec=env GTK_IM_MODULE=fcitx QT_IM_MODULE=fcitx XMODIFIERS=@im=fcitx /usr/bin/cursor %F
Icon=cursor
Type=Application
StartupNotify=true
StartupWMClass=Cursor
Categories=Development;IDE;
MimeType=text/plain;inode/directory;application/x-code-workspace;
EOF
    
    print_success "Created desktop file override at $cursor_desktop"
    print_status "Cursor will now use fcitx5 with Brazilian layout when launched from menu"
}

# Function to restart fcitx5
restart_fcitx5() {
    print_status "Restarting fcitx5..."
    
    # Kill fcitx5 if running
    pkill -f fcitx5 || true
    
    # Wait a moment
    sleep 2
    
    # Start fcitx5
    fcitx5 -d &
    
    # Wait a moment for it to start
    sleep 3
    
    if pgrep -x "fcitx5" > /dev/null; then
        print_success "fcitx5 restarted successfully"
    else
        print_error "Failed to restart fcitx5"
        return 1
    fi
}

# Function to test Brazilian keyboard layout
test_brazilian_layout() {
    print_status "Testing Brazilian keyboard layout..."
    
    # Set Brazilian layout temporarily
    setxkbmap -layout br -variant abnt2 -option compose:ralt
    
    # Check current layout
    print_status "Current keyboard layout:"
    setxkbmap -query | grep -E "(layout|variant|options)"
    
    # Check fcitx5 status
    if fcitx5-remote -c 2>/dev/null; then
        print_success "fcitx5 remote connection successful"
    else
        print_warning "fcitx5 remote connection failed"
    fi
    
    print_status "Brazilian ABNT2 keyboard layout configured!"
    print_status "Now you can use:"
    print_status "  • c + ' = ç"
    print_status "  • a + ~ = ã"
    print_status "  • o + ~ = õ"
    print_status "  • n + ~ = ñ"
    print_status "  • a + ' = á"
    print_status "  • e + ' = é"
    print_status "  • i + ' = í"
    print_status "  • o + ' = ó"
    print_status "  • u + ' = ú"
}

# Main function
main() {
    echo "===== Brazilian Keyboard Layout Fix ====="
    echo ""
    
    # Check if fcitx5 is installed
    if ! command -v fcitx5 &> /dev/null; then
        print_error "fcitx5 is not installed. Please install it first:"
        print_error "sudo pacman -S fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt"
        exit 1
    fi
    
    # Install Brazilian keyboard packages
    install_brazilian_keyboard
    
    # Create configurations
    configure_fcitx5_brazilian
    update_hyprland_input
    create_environment_config
    update_hyprland_environment
    update_user_profile
    create_cursor_desktop_override
    
    # Restart fcitx5
    restart_fcitx5
    
    # Test configuration
    test_brazilian_layout
    
    echo ""
    print_success "Brazilian keyboard layout fix completed!"
    print_warning "Please log out and log back in for all changes to take effect"
    print_status "Or restart Hyprland with: hyprctl dispatch exit"
    print_status "Then open Cursor from menu - Brazilian layout should work!"
    print_status "Test: c + ' = ç, a + ~ = ã, etc."
}

# Run main function
main "$@"










