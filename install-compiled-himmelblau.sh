#!/usr/bin/env bash
# install-compiled-himmelblau.sh - Install pre-compiled Himmelblau binaries
#
# This script installs the Himmelblau binaries that were successfully compiled
# from source but failed to install due to sudo interactive requirements.

set -e

# Find the most recent build directory
BUILD_DIR=$(ls -1dt /tmp/himmelblau-build-* 2>/dev/null | head -1)

if [[ -z "$BUILD_DIR" ]]; then
    echo "❌ No Himmelblau build directory found!"
    echo "The compilation may have failed or been cleaned up."
    exit 1
fi

if [[ ! -d "$BUILD_DIR/himmelblau/target/release" ]]; then
    echo "❌ Build directory found but no compiled binaries!"
    echo "Build directory: $BUILD_DIR"
    exit 1
fi

echo "🔍 Found Himmelblau build in: $BUILD_DIR"
cd "$BUILD_DIR/himmelblau"

# Check what was compiled
echo "📦 Checking compiled binaries..."
ls -la target/release/ | grep -E '^-.*himmelblau|pam_|nss_|broker|aad-tool'

echo ""
echo "🚀 Installing Himmelblau components..."

# Install main binaries
echo "Installing main binaries..."
if [[ -f "target/release/aad-tool" ]]; then
    sudo install -Dm755 target/release/aad-tool /usr/bin/himmelblau
    echo "✅ himmelblau (aad-tool) installed to /usr/bin/himmelblau"
fi

if [[ -f "target/release/himmelblaud" ]]; then
    sudo install -Dm755 target/release/himmelblaud /usr/bin/himmelblaud
    echo "✅ himmelblaud installed to /usr/bin/himmelblaud"
fi

if [[ -f "target/release/broker" ]]; then
    sudo install -Dm755 target/release/broker /usr/bin/himmelblau-broker
    echo "✅ himmelblau-broker installed to /usr/bin/himmelblau-broker"
fi

# Install PAM module
echo "Installing PAM module..."
if [[ -f "target/release/libpam_himmelblau.so" ]]; then
    sudo install -Dm755 target/release/libpam_himmelblau.so /usr/lib/security/pam_himmelblau.so
    echo "✅ PAM module installed to /usr/lib/security/pam_himmelblau.so"
else
    echo "⚠️  PAM module not found - checking alternative paths..."
    find target/release -name "*pam*" -type f
fi

# Install NSS module  
echo "Installing NSS module..."
if [[ -f "target/release/libnss_himmelblau.so" ]]; then
    sudo install -Dm755 target/release/libnss_himmelblau.so /usr/lib/libnss_himmelblau.so.2
    echo "✅ NSS module installed to /usr/lib/libnss_himmelblau.so.2"
else
    echo "⚠️  NSS module not found - checking alternative paths..."
    find target/release -name "*nss*" -type f
fi

# Install systemd service
echo "Installing systemd service..."
if [[ -f "platform/debian/himmelblaud.service" ]]; then
    sudo install -Dm644 platform/debian/himmelblaud.service /usr/lib/systemd/system/himmelblaud.service
    echo "✅ Systemd service installed"
elif [[ -f "src/daemon/himmelblaud.service" ]]; then
    sudo install -Dm644 src/daemon/himmelblaud.service /usr/lib/systemd/system/himmelblaud.service
    echo "✅ Systemd service installed"
else
    echo "⚠️  Systemd service file not found - will create basic one..."
    cat > /tmp/himmelblaud.service << 'EOF'
[Unit]
Description=Himmelblau Authentication Daemon
Documentation=https://github.com/himmelblau-idm/himmelblau
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/himmelblaud
Restart=on-failure
RestartSec=5
User=root
Group=root

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/himmelblau /var/cache/himmelblau /var/log
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF
    sudo install -Dm644 /tmp/himmelblaud.service /usr/lib/systemd/system/himmelblaud.service
    rm /tmp/himmelblaud.service
    echo "✅ Basic systemd service created and installed"
fi

# Create necessary directories
echo "Creating necessary directories..."
sudo mkdir -p /etc/himmelblau
sudo mkdir -p /var/lib/himmelblau
sudo mkdir -p /var/cache/himmelblau
sudo mkdir -p /var/log/himmelblau

# Set permissions
sudo chown root:root /etc/himmelblau
sudo chmod 755 /etc/himmelblau
sudo chown root:root /var/lib/himmelblau
sudo chmod 700 /var/lib/himmelblau

echo ""
echo "🎉 Himmelblau installation completed!"
echo ""
echo "📋 Installed components:"
echo "  • himmelblau CLI: $(which himmelblau 2>/dev/null || echo 'Not found')"
echo "  • himmelblaud daemon: $(which himmelblaud 2>/dev/null || echo 'Not found')"  
echo "  • PAM module: $([[ -f /usr/lib/security/pam_himmelblau.so ]] && echo '✅ Installed' || echo '❌ Missing')"
echo "  • NSS module: $([[ -f /usr/lib/libnss_himmelblau.so.2 ]] && echo '✅ Installed' || echo '❌ Missing')"
echo "  • Systemd service: $([[ -f /usr/lib/systemd/system/himmelblaud.service ]] && echo '✅ Installed' || echo '❌ Missing')"

echo ""
echo "🔧 Next steps:"
echo "  1. Configure Himmelblau: /etc/himmelblau/himmelblau.conf"
echo "  2. Enable service: sudo systemctl enable himmelblaud"
echo "  3. Start service: sudo systemctl start himmelblau"
echo "  4. Join domain: sudo himmelblau domain join"

echo ""
echo "📁 Build directory preserved: $BUILD_DIR"
echo "   (You can delete it after confirming everything works)"

# Reload systemd
echo "🔄 Reloading systemd..."
sudo systemctl daemon-reload

echo ""
echo "✅ Installation script completed successfully!"