#!/bin/bash

# Script to test manual login with Entra ID support before TTY1

echo "=== Omarchy Login Transition Test ==="
echo "This script will prepare the system for manual login with Entra ID support"
echo

# Check current status
echo "1. Current status:"
echo "   - getty@tty1: $(systemctl is-enabled getty@tty1 2>/dev/null || echo 'not found')"
echo "   - omarchy-seamless-login: $(systemctl is-enabled omarchy-seamless-login 2>/dev/null || echo 'not found')"
echo

# Create wrapper script for Hyprland launch
echo "2. Creating Hyprland launcher wrapper..."
sudo tee /usr/local/bin/hyprland-login << 'EOFINNER'
#!/bin/bash
# Hyprland launcher with proper environment setup

# Set XDG runtime directory
export XDG_RUNTIME_DIR="/run/user/$(id -u)"

# Launch Hyprland using uwsm
exec uwsm start -- hyprland.desktop
EOFINNER

sudo chmod +x /usr/local/bin/hyprland-login

# Create profile script for Entra ID users
echo "3. Setting up auto-launch for Hyprland after login..."
sudo tee /etc/profile.d/hyprland-autostart.sh << 'EOFINNER'
#!/bin/bash
# Auto-start Hyprland on TTY1 login

if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
    # Only start if we're on TTY1 and no display is running
    exec /usr/local/bin/hyprland-login
fi
EOFINNER

sudo chmod +x /etc/profile.d/hyprland-autostart.sh

# Create home directory for Entra ID user
echo "4. Creating home directory for andre@exato.digital..."
sudo mkdir -p "/home/andre@exato.digital"
sudo chown 91084901:91084901 "/home/andre@exato.digital"
sudo chmod 755 "/home/andre@exato.digital"

# Copy essential configs
echo "5. Copying essential configs for Entra ID user..."
if [ -d "/home/opik/.config/hypr" ]; then
    sudo cp -r "/home/opik/.config/hypr" "/home/andre@exato.digital/.config/"
    sudo chown -R 91084901:91084901 "/home/andre@exato.digital/.config"
fi

# Check himmelblau client_id
echo "6. Checking himmelblau configuration..."
if ! grep -q "^client_id = ." /etc/himmelblau/himmelblau.conf; then
    echo "   WARNING: client_id is empty in himmelblau.conf"
    echo "   You need to set a valid client_id for Entra ID authentication"
    echo "   Edit /etc/himmelblau/himmelblau.conf and add your application's client_id"
fi

echo
echo "=== Configuration Complete ==="
echo
echo "To test:"
echo "1. Reboot the system"
echo "2. At TTY1, you should see a text login prompt"
echo "3. Login with either:"
echo "   - Local user: opik"
echo "   - Entra ID: andre@exato.digital (use PIN)"
echo "4. Hyprland should start automatically after successful login"
echo
echo "To revert to auto-login:"
echo "  sudo systemctl disable getty@tty1"
echo "  sudo systemctl enable omarchy-seamless-login"
echo

read -p "Press Enter to continue..."
