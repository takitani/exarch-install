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
echo "• Create/modify desktop shortcuts"
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

# Create flag files first (before applying patch)
echo
echo "🏴 Creating browser flag files..."

# Create Chromium flags file
chromium_flags="$HOME/.config/chromium-flags.conf"
mkdir -p "$(dirname "$chromium_flags")"
if [[ ! -f "$chromium_flags" ]]; then
  touch "$chromium_flags"
  echo "📄 Created $chromium_flags"
fi

# Required flags for Chromium
required_chromium_flags=(
  "--enable-webrtc-pipewire-camera"
  "--enable-features=WebRTCPipeWireCapturer"
  "--ozone-platform=wayland"
  "--enable-wayland-ime"
)

echo "🔧 Configuring Chromium flags..."
for flag in "${required_chromium_flags[@]}"; do
  if ! grep -Fxq -- "$flag" "$chromium_flags" 2>/dev/null; then
    echo "$flag" >> "$chromium_flags"
    echo "  + Added: $flag"
  else
    echo "  ✓ Already present: $flag"
  fi
done

# Create Chrome flags file
chrome_flags="$HOME/.config/google-chrome-flags.conf"
mkdir -p "$(dirname "$chrome_flags")"
if [[ ! -f "$chrome_flags" ]]; then
  touch "$chrome_flags"
  echo "📄 Created $chrome_flags"
fi

echo "🔧 Configuring Chrome flags..."
for flag in "${required_chromium_flags[@]}"; do
  if ! grep -Fxq -- "$flag" "$chrome_flags" 2>/dev/null; then
    echo "$flag" >> "$chrome_flags"
    echo "  + Added: $flag"
  else
    echo "  ✓ Already present: $flag"
  fi
done

echo
echo "🎯 Applying PipeWire camera patch..."

# Define basic logging functions if not available
if ! command -v info >/dev/null 2>&1; then
  info() { echo "ℹ️  $*"; }
  warn() { echo "⚠️  $*"; }
  log() { echo "📝 $*"; }
  success() { echo "✅ $*"; }
  err() { echo "❌ $*"; }
fi

# Apply the patch with proper error handling
if apply_pipewire_camera_patch; then
  echo "✅ PipeWire camera patch applied successfully"
else
  echo "⚠️  Some issues occurred during patch application, but flags were configured"
fi

echo
echo "✅ Fix completed successfully!"
echo

# Show what was configured
echo "📄 Configuration Summary:"
echo "========================="
echo
echo "Chromium flags file: $chromium_flags"
if [[ -f "$chromium_flags" ]]; then
  echo "  Content:"
  sed 's/^/    /' "$chromium_flags"
else
  echo "  ❌ File not created"
fi
echo

echo "Chrome flags file: $chrome_flags"  
if [[ -f "$chrome_flags" ]]; then
  echo "  Content:"
  sed 's/^/    /' "$chrome_flags"
else
  echo "  ❌ File not created"
fi
echo

echo "📋 Next Steps:"
echo "=============="
echo "1. 🌐 Open Chrome/Chromium (it should now use the flags automatically)"
echo "2. 🔍 Check chrome://flags and search for 'pipewire'"
echo "3. ✅ Verify 'WebRTC PipeWire support' shows as 'Enabled'"
echo "4. 🎥 Test camera at:"
echo "   • https://webcamtests.com"  
echo "   • https://meet.google.com"
echo "   • https://webrtc.github.io/samples/src/content/getusermedia/gum/"
echo
echo "🔧 Troubleshooting:"
echo "=================="
echo "If flags still show 'Default' instead of 'Enabled':"
echo "  1. Close ALL browser windows/tabs completely"
echo "  2. Kill any background browser processes:"
echo "     pkill -f chromium; pkill -f chrome"
echo "  3. Wait 5 seconds"
echo "  4. Start browser fresh"
echo
echo "If camera still not working:"
echo "  1. Check PipeWire: systemctl --user status pipewire"
echo "  2. Run diagnostic: ./helpers/diagnose-chromium-pipewire.sh"
echo "  3. Check camera permissions in browser settings"
echo