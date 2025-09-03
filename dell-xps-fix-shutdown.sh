#!/usr/bin/env bash
# dell-xps-fix-shutdown.sh - Emergency script to fix Dell XPS shutdown hangs
# Run this if your system hangs during shutdown/reboot after installing IPU6 drivers

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Dell XPS 13 Plus - Emergency Shutdown Fix${NC}"
echo "============================================"
echo ""
echo "This script will unload problematic IPU6 camera modules that may"
echo "cause shutdown/reboot hangs on Dell XPS 13 Plus (9320)."
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}This script should NOT be run as root directly${NC}"
   echo "Please run: ./dell-xps-fix-shutdown.sh"
   exit 1
fi

# Function to unload a module safely
unload_module() {
    local module=$1
    if lsmod | grep -q "^${module//-/_} "; then
        echo -e "${YELLOW}Unloading module: $module${NC}"
        if timeout 3 sudo modprobe -r "$module" 2>/dev/null; then
            echo -e "${GREEN}  ✓ Successfully unloaded $module${NC}"
        else
            echo -e "${RED}  ✗ Failed to unload $module (may be in use)${NC}"
        fi
    else
        echo "  Module $module not loaded"
    fi
}

echo -e "${YELLOW}Step 1: Stopping related services...${NC}"
# Stop services that might be using the camera
sudo systemctl stop v4l2-relayd 2>/dev/null || true
sudo systemctl stop pipewire 2>/dev/null || true
sudo systemctl stop wireplumber 2>/dev/null || true

echo ""
echo -e "${YELLOW}Step 2: Killing processes using camera...${NC}"
# Kill any processes that might be using the camera
sudo pkill -f cheese 2>/dev/null || true
sudo pkill -f firefox 2>/dev/null || true
sudo pkill -f chromium 2>/dev/null || true
sudo pkill -f chrome 2>/dev/null || true
sudo pkill -f teams 2>/dev/null || true
sudo pkill -f zoom 2>/dev/null || true
sudo pkill -f skype 2>/dev/null || true

echo ""
echo -e "${YELLOW}Step 3: Unloading IPU6 camera modules...${NC}"
# Unload modules in reverse dependency order
modules=(
    "intel_ipu6_psys"
    "intel_ipu6_isys"
    "intel_ipu6"
    "intel-ipu6"
    "ipu6_psys"
    "ipu6_isys"
    "ipu6-psys"
    "ipu6-isys"
    "ipu6"
    "v4l2loopback"
)

for module in "${modules[@]}"; do
    unload_module "$module"
done

echo ""
echo -e "${YELLOW}Step 4: Disabling module auto-loading temporarily...${NC}"
# Temporarily disable module loading on boot
if [[ -f /etc/modules-load.d/dell-xps-camera.conf ]]; then
    sudo mv /etc/modules-load.d/dell-xps-camera.conf /etc/modules-load.d/dell-xps-camera.conf.disabled
    echo -e "${GREEN}  ✓ Disabled camera module auto-loading${NC}"
    echo "  To re-enable: sudo mv /etc/modules-load.d/dell-xps-camera.conf.disabled /etc/modules-load.d/dell-xps-camera.conf"
else
    echo "  Module configuration not found"
fi

echo ""
echo -e "${YELLOW}Step 5: Syncing filesystems...${NC}"
sync
echo -e "${GREEN}  ✓ Filesystems synced${NC}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Emergency fix completed!${NC}"
echo ""
echo "You should now be able to shutdown/reboot normally."
echo ""
echo "To permanently fix this issue:"
echo "1. The install script has been updated to not load modules immediately"
echo "2. Modules will only load on boot (not during installation)"
echo "3. To use the camera after reboot:"
echo "   - Reboot once more after the modules are loaded"
echo "   - Or manually load with: sudo modprobe intel_ipu6_isys"
echo ""
echo -e "${YELLOW}Ready to shutdown/reboot safely now.${NC}"