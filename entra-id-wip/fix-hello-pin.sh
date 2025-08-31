#!/bin/bash

# Script to fix Windows Hello PIN authentication for himmelblau

set -euo pipefail

echo "=== Fixing Windows Hello PIN Authentication ==="

# Check if running as regular user
if [[ $EUID -eq 0 ]]; then
    echo "Error: This script should NOT be run as root"
    echo "Run it as your regular user account"
    exit 1
fi

# Function to run commands with sudo
run_sudo() {
    echo "Running: sudo $*"
    sudo "$@"
}

echo "Step 1: Stopping himmelblau daemon..."
run_sudo systemctl stop himmelblaud

echo "Step 2: Clearing himmelblau cache..."
run_sudo himmelblau cache-clear

echo "Step 3: Removing existing cache/lib data..."
run_sudo rm -rf /var/cache/himmelblau/*
run_sudo rm -rf /var/lib/himmelblau/*
run_sudo rm -rf /var/cache/nss-himmelblau/*

echo "Step 4: Starting himmelblau daemon..."
run_sudo systemctl start himmelblau

# Wait for service to be ready
sleep 3

echo "Step 5: Checking daemon status..."
if ! himmelblau status | grep -q "working!"; then
    echo "Error: himmelblau daemon not working properly"
    exit 1
fi

echo "Step 6: Testing authentication (this will prompt for initial PIN setup)..."
echo "You will be prompted to set up your Windows Hello PIN."
echo "Follow the prompts to configure your PIN."
echo ""

# Try to authenticate - this should trigger PIN setup
if ! himmelblau auth-test --name "andre@exato.digital"; then
    echo ""
    echo "Authentication test failed. This is expected on first run."
    echo "The system should have prompted you to set up your PIN."
    echo ""
    echo "If you didn't see a PIN setup prompt, you may need to:"
    echo "1. Ensure your Microsoft account has Windows Hello configured"
    echo "2. Try logging in through the login screen to complete PIN setup"
    echo ""
    echo "Try logging out and logging in again with your Microsoft account."
fi

echo ""
echo "=== Fix Complete ==="
echo "Try logging out and back in with your Microsoft account."
echo "The PIN should now work properly."