#!/bin/bash

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "===== Hyprland Restart for Input Method Fix ====="
echo ""

print_status "This will restart Hyprland to apply input method fixes"
print_status "All applications will be closed - save your work first!"
echo ""

echo -n "Do you want to continue? (y/N): "
read -r confirmation

if [[ "$confirmation" =~ ^[Yy]$ ]]; then
    print_status "Restarting Hyprland..."
    hyprctl dispatch exit
    print_success "Hyprland restarted. The input method fixes should now be active."
    print_status "Try opening Cursor normally and test typing 'ção'"
else
    print_warning "Restart cancelled. You can test with 'cursor-fcitx' command instead."
fi












