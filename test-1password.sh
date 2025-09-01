#!/bin/bash
# Quick 1Password integration test

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== 1Password Integration Test ===${NC}"
echo

# Check if 1Password desktop is running
echo "1. Checking 1Password desktop..."
if pgrep -x "1password" > /dev/null || pgrep -f "1Password" > /dev/null; then
    echo -e "${GREEN}✓ 1Password desktop is running${NC}"
else
    echo -e "${YELLOW}⚠ 1Password desktop not detected running${NC}"
    echo "  Please open 1Password desktop app"
fi

# Check if op CLI is installed
echo
echo "2. Checking op CLI..."
if command -v op >/dev/null 2>&1; then
    echo -e "${GREEN}✓ op CLI is installed${NC}"
    echo "  Version: $(op --version)"
else
    echo -e "${YELLOW}⚠ op CLI not found${NC}"
    echo "  Install with: yay -S 1password-cli"
    exit 1
fi

# Test integration
echo
echo "3. Testing CLI integration..."
echo "Running: op account list"
echo

if op account list 2>&1; then
    echo
    echo -e "${GREEN}✓ Integration is working!${NC}"
else
    echo
    echo -e "${YELLOW}Integration not working yet.${NC}"
    echo
    echo "To enable integration:"
    echo "1. Open 1Password desktop"
    echo "2. Go to Settings → Developer"
    echo "3. Enable 'Integrate with 1Password CLI'"
    echo "4. Try running: op account list"
fi
