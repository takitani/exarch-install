#!/bin/bash

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

# Function to create desktop file override for Cursor
create_cursor_desktop_override() {
    local desktop_dir="$HOME/.local/share/applications"
    local cursor_desktop="$desktop_dir/cursor.desktop"
    
    print_status "Creating desktop file override for Cursor..."
    
    # Create directory if it doesn't exist
    mkdir -p "$desktop_dir"
    
    # Create desktop file override with proper environment variables
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

# Function to configure fcitx5 for US International
configure_fcitx5_us_international() {
    local profile_file="$HOME/.config/fcitx5/profile"
    local config_dir="$HOME/.config/fcitx5/conf"
    
    print_status "Configuring fcitx5 for US International layout..."
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Backup existing profile
    if [[ -f "$profile_file" ]]; then
        cp "$profile_file" "${profile_file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up existing fcitx5 profile"
    fi
    
    # Create new profile with US International layout
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
    
    print_success "Configured fcitx5 with US International layout"
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

# Function to test US International layout
test_us_international() {
    print_status "Testing US International layout..."
    
    # Set US International layout temporarily
    setxkbmap -layout us -variant intl -option compose:ralt
    
    # Check current layout
    print_status "Current keyboard layout:"
    setxkbmap -query | grep -E "(layout|variant|options)"
    
    # Check fcitx5 status
    if fcitx5-remote -c 2>/dev/null; then
        print_success "fcitx5 remote connection successful"
    else
        print_warning "fcitx5 remote connection failed"
    fi
    
    print_status "US International keyboard layout configured!"
    print_status "Now you can use:"
    print_status "  • Right Alt + c = ç"
    print_status "  • Right Alt + a = ã"
    print_status "  • Right Alt + o = õ"
    print_status "  • Right Alt + n = ñ"
    print_status "  • Right Alt + e = é"
    print_status "  • Right Alt + i = í"
    print_status "  • Right Alt + u = ú"
    print_status "  • Right Alt + y = ý"
    print_status "  • Right Alt + ' = á"
    print_status "  • Right Alt + ~ = ã"
}

# Main function
main() {
    echo "===== Simple Cursor Input Fix (US International) ====="
    echo ""
    
    # Check if fcitx5 is installed
    if ! command -v fcitx5 &> /dev/null; then
        print_error "fcitx5 is not installed. Please install it first:"
        print_error "sudo pacman -S fcitx5 fcitx5-configtool fcitx5-gtk fcitx5-qt"
        exit 1
    fi
    
    # Create configurations
    configure_fcitx5_us_international
    create_cursor_desktop_override
    
    # Restart fcitx5
    restart_fcitx5
    
    # Test configuration
    test_us_international
    
    echo ""
    print_success "Simple Cursor input fix completed!"
    print_status "Now open Cursor from the menu and test:"
    print_status "  • Right Alt + c = ç"
    print_status "  • Right Alt + a = ã"
    print_status "  • Right Alt + o = õ"
    print_status "  • etc."
    print_status ""
    print_status "If it still doesn't work, try:"
    print_status "  • Close Cursor completely"
    print_status "  • Open Cursor from menu (not terminal)"
    print_status "  • Test the characters above"
}

# Run main function
main "$@"













