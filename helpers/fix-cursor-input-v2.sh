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

# Function to check if fcitx5 is running
check_fcitx5() {
    if pgrep -x "fcitx5" > /dev/null; then
        print_success "fcitx5 is running"
        return 0
    else
        print_warning "fcitx5 is not running"
        return 1
    fi
}

# Function to install fcitx5 packages
install_fcitx5_packages() {
    print_status "Installing fcitx5 packages..."
    
    # Check if packages are installed
    if ! pacman -Q fcitx5 >/dev/null 2>&1; then
        print_status "Installing fcitx5..."
        sudo pacman -S --noconfirm fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt
    else
        print_success "fcitx5 packages already installed"
    fi
}

# Function to create proper fcitx5 configuration
create_fcitx5_config() {
    local profile_file="$HOME/.config/fcitx5/profile"
    local config_dir="$HOME/.config/fcitx5/conf"
    
    print_status "Creating proper fcitx5 configuration..."
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Backup existing profile
    if [[ -f "$profile_file" ]]; then
        cp "$profile_file" "${profile_file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up existing fcitx5 profile"
    fi
    
    # Create new profile with proper US International layout
    cat > "$profile_file" << 'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=us
# Default Input Method
DefaultIM=keyboard-us

[Groups/0/Items/0]
# Name
Name=keyboard-us
# Layout
Layout=intl

[GroupOrder]
0=Default
EOF
    
    # Create xcb configuration
    cat > "$config_dir/xcb.conf" << 'EOF'
Allow Overriding System XKB Settings=True
EOF
    
    # Create notifications configuration
    cat > "$config_dir/notifications.conf" << 'EOF'
# Enable notifications
UseDBus=true
EOF
    
    print_success "Created fcitx5 configuration with US International layout"
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

# Function to update Hyprland configuration
update_hyprland_config() {
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
    
    if check_fcitx5; then
        print_success "fcitx5 restarted successfully"
    else
        print_error "Failed to restart fcitx5"
        return 1
    fi
}

# Function to test input method
test_input_method() {
    print_status "Testing input method configuration..."
    
    # Check environment variables
    print_status "Current environment variables:"
    echo "GTK_IM_MODULE: ${GTK_IM_MODULE:-not set}"
    echo "QT_IM_MODULE: ${QT_IM_MODULE:-not set}"
    echo "XMODIFIERS: ${XMODIFIERS:-not set}"
    
    # Check fcitx5 status
    if fcitx5-remote -c 2>/dev/null; then
        print_success "fcitx5 remote connection successful"
    else
        print_warning "fcitx5 remote connection failed"
    fi
    
    # Check keyboard layout
    print_status "Current keyboard layout:"
    setxkbmap -query | grep -E "(layout|variant|options)"
    
    print_status "To test in Cursor:"
    print_status "1. Close Cursor completely"
    print_status "2. Log out and log back in (or restart Hyprland)"
    print_status "3. Open Cursor normally from menu"
    print_status "4. Try typing 'ção' - Right Alt + c should give 'ç'"
    print_status "5. Try Right Alt + a for 'ã', Right Alt + o for 'õ'"
}

# Function to create desktop file override
create_desktop_override() {
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
    print_status "Cursor will now use fcitx5 when launched from menu"
}

# Main function
main() {
    echo "===== Cursor Input Method Fix Script v2 ====="
    echo ""
    
    # Check if fcitx5 is installed
    if ! command -v fcitx5 &> /dev/null; then
        print_error "fcitx5 is not installed. Installing now..."
        install_fcitx5_packages
    fi
    
    # Check fcitx5 status
    check_fcitx5
    
    # Create configurations
    create_fcitx5_config
    create_environment_config
    update_hyprland_config
    update_user_profile
    create_desktop_override
    
    # Restart fcitx5
    restart_fcitx5
    
    # Test configuration
    test_input_method
    
    echo ""
    print_success "Cursor input method fix completed!"
    print_warning "Please log out and log back in for all changes to take effect"
    print_status "Or restart Hyprland with: hyprctl dispatch exit"
    print_status "Then open Cursor from menu - it should work with Portuguese characters!"
}

# Run main function
main "$@"











