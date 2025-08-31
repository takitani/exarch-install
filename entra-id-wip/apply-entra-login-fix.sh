#!/bin/bash

# Script to apply Entra ID login fix with greetd

set -e

echo "========================================"
echo "Applying Entra ID Login Fix"
echo "========================================"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Install greetd and tuigreet
echo -e "${GREEN}[1/5]${NC} Installing greetd and tuigreet..."
sudo pacman -S greetd greetd-tuigreet --noconfirm || {
    echo -e "${RED}Failed to install packages${NC}"
    exit 1
}

# Step 2: Configure greetd
echo -e "${GREEN}[2/5]${NC} Configuring greetd..."
sudo mkdir -p /etc/greetd
sudo tee /etc/greetd/config.toml > /dev/null << 'EOF'
[terminal]
# The VT to run the greeter on
vt = 1

[default_session]
# The greeter to run with Hyprland launch command
command = "tuigreet --remember --remember-user-session --time --issue --asterisks --cmd 'uwsm start -- hyprland.desktop'"
user = "greeter"
EOF

# Create greeter user if doesn't exist
if ! id greeter &>/dev/null; then
    echo "Creating greeter user..."
    sudo useradd -M -G video greeter
fi

# Step 3: Configure client_id if provided
echo -e "${GREEN}[3/5]${NC} Configuring himmelblau client_id..."
echo
echo "You need a client_id for Entra ID authentication to work properly."
echo "If you have one, enter it now. Otherwise press Enter to skip."
read -p "Client ID (or Enter to skip): " CLIENT_ID

if [[ -n "$CLIENT_ID" ]]; then
    # Update himmelblau.conf with client_id
    sudo sed -i "s/^client_id = .*/client_id = $CLIENT_ID/" /etc/himmelblau/himmelblau.conf
    echo -e "${GREEN}✓${NC} Client ID configured: $CLIENT_ID"
else
    echo -e "${YELLOW}⚠${NC} Client ID not configured. You'll need to add it later to /etc/himmelblau/himmelblau.conf"
fi

# Step 4: Disable conflicting services
echo -e "${GREEN}[4/5]${NC} Configuring services..."

if systemctl is-enabled getty@tty1 &>/dev/null; then
    echo "Disabling getty@tty1..."
    sudo systemctl disable getty@tty1
fi

if systemctl is-enabled omarchy-seamless-login &>/dev/null; then
    echo "Disabling omarchy-seamless-login..."
    sudo systemctl disable omarchy-seamless-login
fi

# Step 5: Enable greetd
echo -e "${GREEN}[5/5]${NC} Enabling greetd service..."
sudo systemctl enable greetd

# Restart himmelblau to apply config changes
echo "Restarting himmelblau daemon..."
sudo systemctl restart himmelblaud

echo
echo "========================================"
echo -e "${GREEN}✓ Configuration Complete!${NC}"
echo "========================================"
echo
echo "NEXT STEPS:"
echo "1. Reboot your system: sudo reboot"
echo "2. At the login screen (tuigreet), you can login with:"
echo "   - Local user: opik"
echo "   - Entra ID: andre@exato.digital (use your PIN)"
echo
echo "TO REVERT TO AUTO-LOGIN:"
echo "  sudo systemctl disable greetd"
echo "  sudo systemctl enable omarchy-seamless-login"
echo "  sudo reboot"
echo
echo -e "${YELLOW}Ready to reboot now? (y/N):${NC} "
read -r REBOOT_NOW

if [[ "$REBOOT_NOW" =~ ^[Yy]$ ]]; then
    echo "Rebooting in 5 seconds... Press Ctrl+C to cancel"
    sleep 5
    sudo reboot
fi