#!/bin/bash

# fix-chromium-desktop.sh - Quick fix for PipeWire Camera in Chrome/Chromium
# This script can be run standalone to apply the PipeWire camera patch

set -e

# Get script directory and find the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Check if we can find the patch file
PATCH_FILE=""
if [[ -f "$SCRIPT_DIR/pipewire-camera-patch.sh" ]]; then
  # Running from helpers/ directory
  PATCH_FILE="$SCRIPT_DIR/pipewire-camera-patch.sh"
elif [[ -f "$PROJECT_ROOT/helpers/pipewire-camera-patch.sh" ]]; then
  # Running from project root
  PATCH_FILE="$PROJECT_ROOT/helpers/pipewire-camera-patch.sh"
else
  echo "❌ Error: Cannot find pipewire-camera-patch.sh"
  echo "   Looked in:"
  echo "   - $SCRIPT_DIR/pipewire-camera-patch.sh"
  echo "   - $PROJECT_ROOT/helpers/pipewire-camera-patch.sh"
  exit 1
fi

# Source the patch implementation
source "$PATCH_FILE"

echo "🎥 Chrome/Chromium PipeWire Camera Fix"
echo "======================================"
echo
echo "This script will configure PipeWire camera support for Chrome/Chromium:"
echo "• Install pipewire-libcamera package"
echo "• Configure Chrome/Chromium flags files" 
echo "• Force flags as 'Enabled' in browser preferences"
echo "• Modify desktop shortcuts to include camera flags"
echo
echo "⚠️  This will close all running Chrome/Chromium instances!"
echo

# Check if browsers are running
if pgrep -f "chrom(e|ium)" >/dev/null; then
  echo "🔴 Warning: Chrome/Chromium is currently running"
  read -p "Continue? This will close all browser windows. (y/N): " response
  
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    exit 0
  fi
fi

echo
echo "🔧 Installing pipewire-libcamera..."
if command -v yay >/dev/null 2>&1; then
  yay -S --noconfirm pipewire-libcamera || echo "⚠️  Package installation failed (may already be installed)"
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -S --noconfirm pipewire-libcamera || echo "⚠️  Package installation failed (may already be installed)"
else
  echo "❌ No package manager found (yay/pacman)"
  exit 1
fi

echo
echo "🎯 Applying PipeWire camera patch..."
apply_pipewire_camera_patch

echo
echo "✅ Fix completed successfully!"
echo
echo "📋 Next steps:"
echo "1. Open Chrome/Chromium"
echo "2. Go to chrome://flags"
echo "3. Search for 'pipewire'"
echo "4. Verify flags show as 'Enabled' (not 'Default')"
echo "5. Test camera at https://meet.google.com or https://webcamtests.com"
echo
echo "🔧 If flags still show as 'Default', try:"
echo "   • Close ALL browser windows completely"
echo "   • Wait 5 seconds"
echo "   • Reopen browser"
echo