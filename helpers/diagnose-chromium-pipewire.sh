#!/bin/bash

# diagnose-chromium-pipewire.sh - Diagnose PipeWire camera configuration

echo "🔍 Chrome/Chromium PipeWire Camera Diagnostics"
echo "=============================================="
echo

# Check if pipewire is running
echo "📊 PipeWire Status:"
if systemctl --user is-active pipewire >/dev/null 2>&1; then
    echo "✅ PipeWire is active"
    pipewire --version 2>/dev/null | head -1 || echo "   Version: unknown"
else
    echo "❌ PipeWire is not running"
    echo "   Run: systemctl --user start pipewire"
fi
echo

# Check pipewire-libcamera
echo "📦 Package Status:"
if pacman -Q pipewire-libcamera >/dev/null 2>&1; then
    echo "✅ pipewire-libcamera is installed: $(pacman -Q pipewire-libcamera)"
else
    echo "❌ pipewire-libcamera is not installed"
    echo "   Install with: sudo pacman -S pipewire-libcamera"
fi
echo

# Check Chrome/Chromium installation
echo "🌐 Browser Status:"
if command -v chromium >/dev/null 2>&1; then
    echo "✅ Chromium found: $(chromium --version 2>/dev/null | head -1)"
else
    echo "❌ Chromium not found"
fi

if command -v google-chrome-stable >/dev/null 2>&1; then
    echo "✅ Chrome found: $(google-chrome-stable --version 2>/dev/null | head -1)"
elif command -v google-chrome >/dev/null 2>&1; then
    echo "✅ Chrome found: $(google-chrome --version 2>/dev/null | head -1)"
else
    echo "❌ Chrome not found"
fi
echo

# Check flag files
echo "🏴 Flag Files Status:"
echo

# Chromium flags
chromium_flags="$HOME/.config/chromium-flags.conf"
echo "Chromium flags file: $chromium_flags"
if [[ -f "$chromium_flags" ]]; then
    echo "✅ File exists"
    echo "   Content:"
    sed 's/^/     /' "$chromium_flags"
    echo
    if grep -q "enable-webrtc-pipewire-camera" "$chromium_flags"; then
        echo "✅ Contains pipewire camera flag"
    else
        echo "❌ Missing pipewire camera flag"
    fi
    if grep -q "WebRTCPipeWireCapturer" "$chromium_flags"; then
        echo "✅ Contains WebRTCPipeWireCapturer flag"
    else
        echo "❌ Missing WebRTCPipeWireCapturer flag"
    fi
else
    echo "❌ File does not exist"
fi
echo

# Chrome flags
chrome_flags="$HOME/.config/google-chrome-flags.conf"
echo "Chrome flags file: $chrome_flags"
if [[ -f "$chrome_flags" ]]; then
    echo "✅ File exists"
    echo "   Content:"
    sed 's/^/     /' "$chrome_flags"
    echo
    if grep -q "enable-webrtc-pipewire-camera" "$chrome_flags"; then
        echo "✅ Contains pipewire camera flag"
    else
        echo "❌ Missing pipewire camera flag"
    fi
    if grep -q "WebRTCPipeWireCapturer" "$chrome_flags"; then
        echo "✅ Contains WebRTCPipeWireCapturer flag"
    else
        echo "❌ Missing WebRTCPipeWireCapturer flag"
    fi
else
    echo "❌ File does not exist"
fi
echo

# Check preferences files
echo "⚙️  Browser Preferences:"
echo

# Chromium preferences
for profile_dir in "$HOME/.config/chromium/"*/; do
    if [[ -d "$profile_dir" ]]; then
        profile_name=$(basename "$profile_dir")
        prefs_file="${profile_dir}Preferences"
        echo "Chromium $profile_name: $prefs_file"
        
        if [[ -f "$prefs_file" ]]; then
            echo "✅ File exists"
            if grep -q "enabled_labs_experiments" "$prefs_file"; then
                echo "✅ Has labs experiments section"
                if grep -q "enable-webrtc-pipewire" "$prefs_file"; then
                    echo "✅ Contains pipewire flags"
                else
                    echo "❌ Missing pipewire flags"
                fi
            else
                echo "❌ No labs experiments section"
            fi
        else
            echo "❌ File does not exist"
        fi
        echo
    fi
done

# Chrome preferences  
for profile_dir in "$HOME/.config/google-chrome/"*/; do
    if [[ -d "$profile_dir" ]]; then
        profile_name=$(basename "$profile_dir")
        prefs_file="${profile_dir}Preferences"
        echo "Chrome $profile_name: $prefs_file"
        
        if [[ -f "$prefs_file" ]]; then
            echo "✅ File exists"
            if grep -q "enabled_labs_experiments" "$prefs_file"; then
                echo "✅ Has labs experiments section"
                if grep -q "enable-webrtc-pipewire" "$prefs_file"; then
                    echo "✅ Contains pipewire flags"
                else
                    echo "❌ Missing pipewire flags"
                fi
            else
                echo "❌ No labs experiments section"
            fi
        else
            echo "❌ File does not exist"
        fi
        echo
    fi
done

# Check running processes
echo "🏃 Running Processes:"
if pgrep -f "chrom(e|ium)" >/dev/null; then
    echo "⚠️  Browser processes are running:"
    pgrep -fa "chrom(e|ium)" | sed 's/^/     /'
    echo "   Note: Close all browser windows and try again"
else
    echo "✅ No browser processes running"
fi
echo

# Test camera access
echo "📹 Camera Test:"
if command -v v4l2-ctl >/dev/null 2>&1; then
    echo "📱 Video devices:"
    v4l2-ctl --list-devices 2>/dev/null | head -10 || echo "   No devices found or permission denied"
else
    echo "⚠️  v4l2-ctl not available (install v4l-utils for detailed camera info)"
    echo "📱 Basic camera check:"
    ls -la /dev/video* 2>/dev/null || echo "   No video devices found"
fi
echo

# Final recommendations
echo "💡 Recommendations:"
echo "==================="

if ! systemctl --user is-active pipewire >/dev/null 2>&1; then
    echo "1. Start PipeWire: systemctl --user start pipewire"
fi

if ! pacman -Q pipewire-libcamera >/dev/null 2>&1; then
    echo "2. Install: sudo pacman -S pipewire-libcamera"
fi

if [[ ! -f "$chromium_flags" ]] && command -v chromium >/dev/null 2>&1; then
    echo "3. Create Chromium flags file with required flags"
fi

if [[ ! -f "$chrome_flags" ]] && (command -v google-chrome >/dev/null 2>&1 || command -v google-chrome-stable >/dev/null 2>&1); then
    echo "4. Create Chrome flags file with required flags"
fi

if pgrep -f "chrom(e|ium)" >/dev/null; then
    echo "5. Close ALL browser windows completely"
    echo "6. Wait 5 seconds, then reopen browser"
fi

echo "7. Test at: https://webcamtests.com or https://meet.google.com"
echo