#!/usr/bin/env bash
# test-tlp-installation.sh - Test script for TLP installation with fallbacks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Test functions
test_package_availability() {
    log_info "Testing package availability functions..."
    
    # Source the module to get access to functions
    source modules/dell-xps.sh
    
    # Test check_package_available function
    if check_package_available "tlp"; then
        log_success "TLP is available in official repository"
    else
        log_warn "TLP is NOT available in official repository"
    fi
    
    if check_package_available "tlp-rdw"; then
        log_success "TLP RDW is available in official repository"
    else
        log_warn "TLP RDW is NOT available in official repository"
    fi
    
    # Test check_aur_available function
    if check_aur_available "tlp"; then
        log_success "TLP is available in AUR"
    else
        log_warn "TLP is NOT available in AUR"
    fi
    
    if check_aur_available "tlp-rdw"; then
        log_success "TLP RDW is available in AUR"
    else
        log_warn "TLP RDW is NOT available in AUR"
    fi
    
    # Test alternative package names
    if check_aur_available "tlp-git"; then
        log_success "tlp-git is available in AUR"
    else
        log_warn "tlp-git is NOT available in AUR"
    fi
    
    if check_aur_available "tlp-rdw-git"; then
        log_success "tlp-rdw-git is available in AUR"
    else
        log_warn "tlp-rdw-git is NOT available in AUR"
    fi
}

test_yay_availability() {
    log_info "Testing yay availability..."
    
    if command -v yay >/dev/null 2>&1; then
        local yay_version
        yay_version=$(yay --version 2>/dev/null | head -n1 || echo "unknown")
        log_success "yay is available: $yay_version"
        
        # Test yay search functionality
        if yay -Ss "^tlp$" >/dev/null 2>&1; then
            log_success "yay search for TLP works"
        else
            log_warn "yay search for TLP failed"
        fi
    else
        log_error "yay is NOT available - AUR fallbacks won't work"
        log_info "Consider installing yay: sudo pacman -S yay"
    fi
}

test_current_tlp_status() {
    log_info "Testing current TLP installation status..."
    
    # Check if TLP is already installed
    if pacman -Q tlp >/dev/null 2>&1; then
        log_success "TLP is already installed via pacman"
        pacman -Q tlp
    else
        log_warn "TLP is NOT installed via pacman"
    fi
    
    if pacman -Q tlp-rdw >/dev/null 2>&1; then
        log_success "TLP RDW is already installed via pacman"
        pacman -Q tlp-rdw
    else
        log_warn "TLP RDW is NOT installed via pacman"
    fi
    
    # Check if TLP is running
    if systemctl is-active tlp >/dev/null 2>&1; then
        log_success "TLP service is running"
    else
        log_warn "TLP service is NOT running"
    fi
    
    # Check TLP configuration
    if [[ -f /etc/tlp.conf ]]; then
        log_success "TLP configuration file exists: /etc/tlp.conf"
        log_info "TLP config size: $(wc -l < /etc/tlp.conf) lines"
    else
        log_warn "TLP configuration file does NOT exist"
    fi
}

test_installation_methods() {
    log_info "Testing different installation methods..."
    
    log_info "Method 1: Official repository"
    if pacman -Ss "^tlp$" >/dev/null 2>&1; then
        log_success "TLP available in official repo"
        log_info "Would install with: sudo pacman -S tlp"
    else
        log_warn "TLP NOT available in official repo"
    fi
    
    log_info "Method 2: AUR via yay"
    if command -v yay >/dev/null 2>&1 && yay -Ss "^tlp$" >/dev/null 2>&1; then
        log_success "TLP available in AUR"
        log_info "Would install with: yay -S tlp"
    else
        log_warn "TLP NOT available in AUR or yay not available"
    fi
    
    log_info "Method 3: Alternative package names"
    local alternatives=("tlp-git" "tlp-rdw-git")
    for alt in "${alternatives[@]}"; do
        if command -v yay >/dev/null 2>&1 && yay -Ss "^$alt$" >/dev/null 2>&1; then
            log_success "$alt is available in AUR"
        else
            log_warn "$alt is NOT available in AUR"
        fi
    done
    
    log_info "Method 4: Manual compilation"
    if command -v git >/dev/null 2>&1 && command -v make >/dev/null 2>&1; then
        log_success "Git and make available for manual compilation"
        log_info "Would clone from: https://github.com/linrunner/TLP.git"
    else
        log_warn "Git or make not available for manual compilation"
    fi
}

show_recommendations() {
    echo
    log_info "Installation Recommendations:"
    echo "================================"
    
    if pacman -Ss "^tlp$" >/dev/null 2>&1; then
        log_success "✅ Use official repository: sudo pacman -S tlp tlp-rdw"
    elif command -v yay >/dev/null 2>&1 && yay -Ss "^tlp$" >/dev/null 2>&1; then
        log_success "✅ Use AUR: yay -S tlp tlp-rdw"
    elif command -v yay >/dev/null 2>&1 && yay -Ss "^tlp-git$" >/dev/null 2>&1; then
        log_success "✅ Use AUR git version: yay -S tlp-git tlp-rdw-git"
    else
        log_warn "⚠️  Manual compilation required"
        log_info "   Clone: git clone https://github.com/linrunner/TLP.git"
        log_info "   Build: cd TLP && make && sudo make install"
    fi
    
    echo
    log_info "Post-installation steps:"
    echo "1. Enable TLP service: sudo systemctl enable tlp"
    echo "2. Start TLP service: sudo systemctl start tlp"
    echo "3. Check status: sudo tlp-stat"
    echo "4. Configure: sudo nano /etc/tlp.conf"
}

main() {
    echo -e "${BLUE}TLP Installation Test Script${NC}"
    echo "================================"
    echo
    
    # Run tests
    test_yay_availability
    echo
    test_package_availability
    echo
    test_current_tlp_status
    echo
    test_installation_methods
    echo
    show_recommendations
    
    echo
    log_success "Test completed successfully!"
}

# Run main function
main "$@"
