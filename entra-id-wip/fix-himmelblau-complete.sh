#!/bin/bash

# Complete fix for himmelblau authentication issues

set -euo pipefail

echo "=== Complete Himmelblau Fix Script ==="
echo ""

# Check if running with sudo
if [[ $EUID -ne 0 ]]; then 
    echo "This script must be run with sudo"
    echo "Usage: sudo ./fix-himmelblau-complete.sh"
    exit 1
fi

echo "Step 1: Stopping himmelblaud service..."
systemctl stop himmelblaud 2>/dev/null || true
systemctl stop himmelblau 2>/dev/null || true
sleep 2

echo "Step 2: Fixing configuration file..."
# Fix the 'domain' vs 'domains' issue
if grep -q "^domain = " /etc/himmelblau/himmelblau.conf; then
    echo "  - Fixing 'domain' parameter to 'domains'"
    sed -i 's/^domain = /domains = /' /etc/himmelblau/himmelblau.conf
fi

echo "Step 3: Fixing cache directory permissions..."
# Create directories if they don't exist
mkdir -p /var/cache/himmelblaud
mkdir -p /var/cache/himmelblau
mkdir -p /var/cache/nss-himmelblau
mkdir -p /var/lib/himmelblau
mkdir -p /var/log/himmelblau
mkdir -p /var/run/himmelblaud

# Fix permissions (remove 'everyone' bits for security)
chmod 750 /var/cache/himmelblaud
chmod 750 /var/cache/himmelblau
chmod 750 /var/cache/nss-himmelblau
chmod 750 /var/lib/himmelblau
chmod 750 /var/log/himmelblau

# Set ownership
chown himmelblaud:himmelblaud /var/cache/himmelblaud 2>/dev/null || true
chown himmelblaud:himmelblaud /var/cache/himmelblau 2>/dev/null || true
chown himmelblaud:himmelblaud /var/lib/himmelblau 2>/dev/null || true
chown himmelblaud:himmelblaud /var/log/himmelblau 2>/dev/null || true

echo "Step 4: Clearing all caches..."
rm -rf /var/cache/himmelblaud/*
rm -rf /var/cache/himmelblau/*
rm -rf /var/cache/nss-himmelblau/*
rm -rf /var/lib/himmelblau/*

echo "Step 5: Updating himmelblau configuration..."
cat > /etc/himmelblau/himmelblau.conf << 'EOF'
[global]
tenant_id = c902ee7d-d8f4-44e7-a09e-bf42b25fa285
domains = exato.digital
client_id = 9669afee-37e6-47b1-9b15-da3a7c8f560d
cache_timeout = 3600
offline_timeout = 86400
require_mfa = false
log_level = info
log_file = /var/log/himmelblau/himmelblau.log
# Optional: Add pam_allow_groups to restrict access
# pam_allow_groups = linux-users@exato.digital
EOF

echo "Step 6: Starting himmelblaud service..."
systemctl daemon-reload
systemctl start himmelblaud
sleep 3

echo "Step 7: Verifying service status..."
if ! systemctl is-active himmelblaud >/dev/null 2>&1; then
    echo "ERROR: himmelblaud failed to start!"
    echo "Checking logs..."
    journalctl -xe -u himmelblaud -n 20 --no-pager
    exit 1
fi

echo "Step 8: Testing connectivity..."
if ! himmelblau status 2>/dev/null | grep -q "working"; then
    echo "WARNING: himmelblau status check failed"
    echo "Continuing anyway..."
fi

echo "Step 9: Enumerating users from Entra ID..."
# This might fail if not authenticated yet, that's OK
himmelblau enumerate 2>/dev/null || echo "  - Enumeration requires authentication (this is normal)"

echo ""
echo "=== Fix Complete ==="
echo ""
echo "The himmelblau service has been restarted with fixed configuration."
echo ""
echo "Next steps:"
echo "1. Test authentication with: himmelblau auth-test --name 'andre@exato.digital'"
echo "2. If prompted for a PIN, set up your Windows Hello PIN"
echo "3. Log out and try logging in with your Microsoft account"
echo ""
echo "If authentication still fails:"
echo "- You may need to set up Windows Hello PIN on your Microsoft account"
echo "- Try: himmelblau user set-posix-attrs --name 'andre@exato.digital'"
echo ""