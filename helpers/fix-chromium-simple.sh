#!/bin/bash

# fix-chromium-simple.sh - Simplified PipeWire Camera fix for Chrome/Chromium

set -e

echo "🎥 Chrome/Chromium PipeWire Camera Fix (Simplified)"
echo "=================================================="
echo

# Check if browsers are running and close them
if pgrep -f "chrom(e|ium)" >/dev/null; then
  echo "🔴 Closing Chrome/Chromium browsers..."
  pkill -f "chromium" 2>/dev/null || true
  pkill -f "chrome" 2>/dev/null || true
  sleep 3
fi

# Check pipewire-libcamera
echo "🔧 Checking pipewire-libcamera..."
if pacman -Q pipewire-libcamera >/dev/null 2>&1; then
  echo "✅ pipewire-libcamera is installed"
else
  echo "📦 Installing pipewire-libcamera..."
  if command -v yay >/dev/null 2>&1; then
    yay -S --noconfirm pipewire-libcamera || echo "⚠️  Package installation failed"
  elif command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --noconfirm pipewire-libcamera || echo "⚠️  Package installation failed"
  else
    echo "❌ No package manager found"
  fi
fi

echo "🏴 Configuring browser flags..."

# Required flags
required_flags=(
  "--enable-webrtc-pipewire-camera"
  "--enable-features=WebRTCPipeWireCapturer"  
  "--ozone-platform=wayland"
  "--enable-wayland-ime"
)

# Configure Chromium flags
chromium_flags="$HOME/.config/chromium-flags.conf"
mkdir -p "$(dirname "$chromium_flags")"
echo "# Flags para Chromium no Wayland com suporte à webcam" > "$chromium_flags"
for flag in "${required_flags[@]}"; do
  echo "$flag" >> "$chromium_flags"
done
echo "✅ Chromium flags configured: $chromium_flags"

# Configure Chrome flags  
chrome_flags="$HOME/.config/google-chrome-flags.conf"
mkdir -p "$(dirname "$chrome_flags")"
echo "# Flags para Google Chrome no Wayland com suporte à webcam" > "$chrome_flags"
for flag in "${required_flags[@]}"; do
  echo "$flag" >> "$chrome_flags"
done
echo "✅ Chrome flags configured: $chrome_flags"

echo "🎯 Applying Preferences patch..."

# Function to patch preferences file
patch_preferences() {
  local prefs_file="$1"
  local browser_name="$2"
  
  if [[ ! -f "$prefs_file" ]]; then
    echo "⚠️  $browser_name Preferences not found: $prefs_file"
    return 1
  fi
  
  # Backup
  cp "$prefs_file" "${prefs_file}.backup" 2>/dev/null || true
  
  # Use jq to add labs experiments
  if command -v jq >/dev/null 2>&1; then
    if jq '.browser.enabled_labs_experiments = ["enable-webrtc-pipewire-capturer@1", "enable-webrtc-pipewire-camera@1"]' \
        "$prefs_file" > "${prefs_file}.tmp" 2>/dev/null; then
      mv "${prefs_file}.tmp" "$prefs_file"
      echo "✅ $browser_name Preferences patched successfully"
      return 0
    else
      rm -f "${prefs_file}.tmp"
      echo "❌ Failed to patch $browser_name Preferences with jq"
      return 1
    fi
  else
    echo "❌ jq not available for patching $browser_name Preferences"
    return 1
  fi
}

# Patch Chromium profiles
chromium_patched=false
for profile_dir in "$HOME/.config/chromium/"*/; do
  if [[ -d "$profile_dir" ]]; then
    profile_name=$(basename "$profile_dir")
    prefs_file="${profile_dir}Preferences"
    
    if [[ -f "$prefs_file" ]]; then
      echo "📝 Patching Chromium profile: $profile_name"
      if patch_preferences "$prefs_file" "Chromium ($profile_name)"; then
        chromium_patched=true
      fi
    fi
  fi
done

# Patch Chrome profiles  
chrome_patched=false
for profile_dir in "$HOME/.config/google-chrome/"*/; do
  if [[ -d "$profile_dir" ]]; then
    profile_name=$(basename "$profile_dir")
    prefs_file="${profile_dir}Preferences"
    
    if [[ -f "$prefs_file" ]]; then
      echo "📝 Patching Chrome profile: $profile_name"  
      if patch_preferences "$prefs_file" "Chrome ($profile_name)"; then
        chrome_patched=true
      fi
    fi
  fi
done

echo
echo "📄 Configuration Summary:"
echo "========================"
echo

if [[ -f "$chromium_flags" ]]; then
  echo "Chromium flags: $chromium_flags"
  echo "  Content:"
  sed 's/^/    /' "$chromium_flags"
  echo
fi

if [[ -f "$chrome_flags" ]]; then
  echo "Chrome flags: $chrome_flags"
  echo "  Content:"
  sed 's/^/    /' "$chrome_flags"
  echo
fi

if [[ "$chromium_patched" == true ]]; then
  echo "✅ Chromium Preferences patched"
else
  echo "⚠️  Chromium Preferences not patched (no profiles found or jq failed)"
fi

if [[ "$chrome_patched" == true ]]; then
  echo "✅ Chrome Preferences patched" 
else
  echo "⚠️  Chrome Preferences not patched (no profiles found or jq failed)"
fi

echo
echo "🚀 Next Steps:"
echo "=============="
echo "1. 🌐 Open Chrome/Chromium"
echo "2. 🔍 Go to chrome://flags and search for 'pipewire'"
echo "3. ✅ Verify 'WebRTC PipeWire support' shows as 'Enabled'"
echo "4. 🎥 Test camera at https://webcamtests.com"
echo
echo "🔧 If flags still show 'Default':"
echo "   • Close ALL browser windows"
echo "   • Wait 5 seconds" 
echo "   • Reopen browser"
echo

echo "✅ PipeWire camera fix completed!"