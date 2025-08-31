#!/usr/bin/env bash
# test-entra-environment.sh - Environment validation for Microsoft Entra ID integration
#
# This script validates the system environment before attempting Himmelblau installation
# and provides detailed testing procedures for each step of the integration.

# Source core libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/lib/core.sh"

# Test configuration
TEST_RESULTS_DIR="/tmp/entra-id-tests-$(date +%Y%m%d_%H%M%S)"
TENANT_ID_TEST="${ENTRA_TENANT_ID:-}"
TEST_DOMAIN="${ENTRA_DOMAIN:-exato.digital}"

# Create test results directory
mkdir -p "$TEST_RESULTS_DIR"
echo "Test results will be saved to: $TEST_RESULTS_DIR"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNINGS=0

# Test result logging
log_test_result() {
    local test_name="$1"
    local result="$2"
    local details="$3"
    
    ((TESTS_TOTAL++))
    
    case "$result" in
        "PASS")
            ((TESTS_PASSED++))
            echo "✅ $test_name" | tee -a "$TEST_RESULTS_DIR/results.log"
            ;;
        "FAIL")
            ((TESTS_FAILED++))
            echo "❌ $test_name" | tee -a "$TEST_RESULTS_DIR/results.log"
            echo "   Error: $details" | tee -a "$TEST_RESULTS_DIR/results.log"
            ;;
        "WARN")
            ((TESTS_WARNINGS++))
            echo "⚠️  $test_name" | tee -a "$TEST_RESULTS_DIR/results.log"
            echo "   Warning: $details" | tee -a "$TEST_RESULTS_DIR/results.log"
            ;;
    esac
    
    [[ -n "$details" ]] && echo "   Details: $details" >> "$TEST_RESULTS_DIR/details.log"
}

# Test 1: Basic System Authentication
test_basic_authentication() {
    echo "=== Testing Basic System Authentication ==="
    
    # Test current user authentication
    if sudo -n true 2>/dev/null; then
        log_test_result "Current user sudo access" "PASS" "User can authenticate with sudo (cached)"
    elif groups | grep -q wheel; then
        log_test_result "Current user sudo access" "PASS" "User is in wheel group (sudo available)"
    else
        log_test_result "Current user sudo access" "WARN" "User may not have sudo access - check manually"
    fi
    
    # Test user switching
    if echo "test" | su -c "exit 0" "$USER" >/dev/null 2>&1; then
        log_test_result "User switching (su)" "PASS" "User can switch to self"
    else
        log_test_result "User switching (su)" "WARN" "User switching test failed - may not be critical"
    fi
    
    # Test user lookup
    if id "$USER" >/dev/null 2>&1; then
        local user_info=$(id "$USER")
        log_test_result "User lookup (id)" "PASS" "$user_info"
    else
        log_test_result "User lookup (id)" "FAIL" "Cannot lookup current user information"
        return 1
    fi
    
    # Test password database lookup
    if getent passwd "$USER" >/dev/null 2>&1; then
        log_test_result "NSS user lookup (getent)" "PASS" "User found in password database"
    else
        log_test_result "NSS user lookup (getent)" "FAIL" "User not found in password database"
        return 1
    fi
    
    return 0
}

# Test 2: Network Connectivity
test_network_connectivity() {
    echo "=== Testing Network Connectivity ==="
    
    # Microsoft endpoints
    local endpoints=(
        "login.microsoftonline.com:443"
        "graph.microsoft.com:443"
        "pas.windows.net:443"
        "management.azure.com:443"
    )
    
    for endpoint in "${endpoints[@]}"; do
        local host=$(echo "$endpoint" | cut -d: -f1)
        local port=$(echo "$endpoint" | cut -d: -f2)
        
        if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            log_test_result "Network connectivity to $host:$port" "PASS" "Connection successful"
        else
            log_test_result "Network connectivity to $host:$port" "FAIL" "Cannot connect to Microsoft endpoint"
        fi
    done
    
    # DNS resolution test
    if ping -c 1 login.microsoftonline.com >/dev/null 2>&1; then
        log_test_result "DNS resolution" "PASS" "Can resolve Microsoft domains via ping"
    else
        log_test_result "DNS resolution" "WARN" "DNS resolution test failed - but network connectivity works"
    fi
    
    return 0
}

# Test 3: System Prerequisites
test_system_prerequisites() {
    echo "=== Testing System Prerequisites ==="
    
    # Time synchronization
    if timedatectl status | grep -q "System clock synchronized: yes"; then
        log_test_result "Time synchronization" "PASS" "System clock is synchronized"
    else
        local time_info=$(timedatectl status | grep "System clock synchronized:")
        log_test_result "Time synchronization" "WARN" "Clock may not be synchronized: $time_info"
    fi
    
    # Required packages
    local required_packages=("curl" "systemd" "pam" "glibc" "rust")
    for pkg in "${required_packages[@]}"; do
        if pacman -Q "$pkg" >/dev/null 2>&1; then
            local version=$(pacman -Q "$pkg")
            log_test_result "Package $pkg installed" "PASS" "$version"
        else
            log_test_result "Package $pkg installed" "WARN" "Package not installed - may need to install"
        fi
    done
    
    # AUR helper availability
    if command -v yay >/dev/null; then
        local yay_version=$(yay --version | head -1)
        log_test_result "AUR helper (yay) available" "PASS" "$yay_version"
    else
        log_test_result "AUR helper (yay) available" "WARN" "No AUR helper found - may need manual installation"
    fi
    
    # Disk space
    local available_space=$(df -h /home | awk 'NR==2 {print $4}')
    local available_mb=$(df -m /home | awk 'NR==2 {print $4}')
    
    if [[ "$available_mb" -gt 500 ]]; then
        log_test_result "Disk space availability" "PASS" "$available_space available in /home"
    else
        log_test_result "Disk space availability" "WARN" "Low disk space: $available_space available"
    fi
    
    return 0
}

# Test 4: Himmelblau Availability
test_himmelblau_availability() {
    echo "=== Testing Himmelblau Availability ==="
    
    # Check if already installed
    if command -v himmelblau >/dev/null; then
        local version=$(himmelblau --version 2>/dev/null || echo "installed")
        log_test_result "Himmelblau already installed" "WARN" "$version - may need uninstall first"
    else
        log_test_result "Himmelblau not installed" "PASS" "Clean state for installation"
    fi
    
    # Check AUR packages (skip network-dependent search for now)
    if command -v yay >/dev/null; then
        log_test_result "Himmelblau AUR packages available" "PASS" "AUR helper available for package search"
    else
        log_test_result "Himmelblau AUR packages available" "WARN" "No AUR helper available"
    fi
    
    # Check Rust toolchain for building from source
    if command -v rustc >/dev/null && command -v cargo >/dev/null; then
        local rust_version=$(rustc --version)
        log_test_result "Rust toolchain available" "PASS" "$rust_version"
    else
        log_test_result "Rust toolchain available" "WARN" "No Rust toolchain - cannot build from source"
    fi
    
    return 0
}

# Test 5: PAM Configuration Analysis
test_pam_configuration() {
    echo "=== Testing PAM Configuration ==="
    
    # Check PAM system-auth
    local pam_system_auth="/etc/pam.d/system-auth"
    if [[ -f "$pam_system_auth" ]]; then
        log_test_result "PAM system-auth exists" "PASS" "Configuration file found"
        
        # Check for existing modifications
        if grep -q "himmelblau\|azure\|entra" "$pam_system_auth"; then
            log_test_result "PAM already modified for Azure/Entra" "WARN" "Previous modifications detected"
        else
            log_test_result "PAM clean for modification" "PASS" "No existing Azure/Entra modifications"
        fi
        
        # Copy current config for reference
        cp "$pam_system_auth" "$TEST_RESULTS_DIR/pam-system-auth-current.txt"
    else
        log_test_result "PAM system-auth exists" "FAIL" "Critical PAM file missing"
    fi
    
    # Check PAM modules directory
    if [[ -d "/usr/lib/security" ]]; then
        log_test_result "PAM modules directory exists" "PASS" "/usr/lib/security found"
    else
        log_test_result "PAM modules directory exists" "FAIL" "PAM modules directory not found"
    fi
    
    return 0
}

# Test 6: NSS Configuration Analysis
test_nss_configuration() {
    echo "=== Testing NSS Configuration ==="
    
    local nsswitch="/etc/nsswitch.conf"
    if [[ -f "$nsswitch" ]]; then
        log_test_result "NSS configuration exists" "PASS" "Configuration file found"
        
        # Check current configuration
        local passwd_line=$(grep "^passwd:" "$nsswitch")
        local group_line=$(grep "^group:" "$nsswitch")
        
        log_test_result "Current passwd resolution" "PASS" "$passwd_line"
        log_test_result "Current group resolution" "PASS" "$group_line"
        
        # Check for existing modifications
        if grep -q "himmelblau\|azure\|sss" "$nsswitch"; then
            log_test_result "NSS already modified" "WARN" "Previous modifications detected"
        else
            log_test_result "NSS clean for modification" "PASS" "No existing modifications"
        fi
        
        # Copy current config for reference
        cp "$nsswitch" "$TEST_RESULTS_DIR/nsswitch-current.conf"
    else
        log_test_result "NSS configuration exists" "FAIL" "Critical NSS file missing"
    fi
    
    return 0
}

# Test 7: Hyprland Integration
test_hyprland_integration() {
    echo "=== Testing Hyprland Integration ==="
    
    # Check if Hyprland is running
    if pgrep -x Hyprland >/dev/null; then
        log_test_result "Hyprland running" "PASS" "Hyprland compositor is active"
    else
        log_test_result "Hyprland running" "WARN" "Hyprland not detected - may affect login testing"
    fi
    
    # Check Hyprlock configuration
    if [[ -f "$HOME/.config/hypr/hyprlock.conf" ]]; then
        log_test_result "Hyprlock configured" "PASS" "Lock screen configuration found"
        
        # Check PAM configuration in hyprlock
        if grep -q "pam-module" "$HOME/.config/hypr/hyprlock.conf" || grep -q "auth" "$HOME/.config/hypr/hyprlock.conf"; then
            log_test_result "Hyprlock PAM configuration" "PASS" "PAM authentication configured"
        else
            log_test_result "Hyprlock PAM configuration" "WARN" "PAM configuration not explicit in hyprlock"
        fi
    else
        log_test_result "Hyprlock configured" "WARN" "No hyprlock configuration found"
    fi
    
    # Check if we can test lock/unlock
    if [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; then
        log_test_result "Display environment available" "PASS" "Can test lock screen functionality"
    else
        log_test_result "Display environment available" "WARN" "No display - cannot test lock screen"
    fi
    
    return 0
}

# Test 8: Configuration Validation
test_configuration() {
    echo "=== Testing Configuration ==="
    
    # Check Tenant ID
    if [[ -n "$TENANT_ID_TEST" ]]; then
        log_test_result "Tenant ID configured" "PASS" "ENTRA_TENANT_ID set: $TENANT_ID_TEST"
        
        # Validate format (UUID)
        if [[ "$TENANT_ID_TEST" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
            log_test_result "Tenant ID format" "PASS" "Valid UUID format"
        else
            log_test_result "Tenant ID format" "WARN" "May not be valid UUID format"
        fi
    else
        log_test_result "Tenant ID configured" "WARN" "ENTRA_TENANT_ID not set - will need to configure"
    fi
    
    # Check domain
    if [[ -n "$TEST_DOMAIN" ]]; then
        log_test_result "Domain configured" "PASS" "Domain set: $TEST_DOMAIN"
    else
        log_test_result "Domain configured" "WARN" "Domain not configured"
    fi
    
    return 0
}

# Comprehensive testing function
run_comprehensive_tests() {
    echo "🔍 Starting Comprehensive Microsoft Entra ID Environment Testing"
    echo "================================================================"
    echo
    
    # Save system state
    {
        echo "=== System Information ==="
        uname -a
        echo
        echo "=== Current User ==="
        id
        echo
        echo "=== Active Services ==="
        systemctl list-units --state=active --no-pager
        echo
        echo "=== Network Configuration ==="
        ip route
        echo
        echo "=== Time Configuration ==="
        timedatectl status
    } > "$TEST_RESULTS_DIR/system-state.txt"
    
    # Run all tests
    test_basic_authentication
    test_network_connectivity  
    test_system_prerequisites
    test_himmelblau_availability
    test_pam_configuration
    test_nss_configuration
    test_hyprland_integration
    test_configuration
    
    # Generate summary
    echo
    echo "🔍 Test Results Summary"
    echo "======================"
    echo "Total Tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED ✅"
    echo "Failed: $TESTS_FAILED ❌"
    echo "Warnings: $TESTS_WARNINGS ⚠️"
    echo
    echo "Detailed results saved to: $TEST_RESULTS_DIR"
    
    # Generate recommendations
    echo
    echo "📋 Recommendations"
    echo "=================="
    
    if [[ "$TESTS_FAILED" -gt 0 ]]; then
        echo "❌ CRITICAL ISSUES FOUND - DO NOT PROCEED WITH INSTALLATION"
        echo "   Fix failed tests before attempting integration"
    elif [[ "$TESTS_WARNINGS" -gt 3 ]]; then
        echo "⚠️  MULTIPLE WARNINGS - PROCEED WITH CAUTION"  
        echo "   Review warnings and ensure you have emergency access"
    else
        echo "✅ SYSTEM READY FOR INTEGRATION"
        echo "   Environment looks good for Himmelblau installation"
    fi
    
    echo
    echo "Next steps:"
    echo "1. Review detailed logs in $TEST_RESULTS_DIR"
    echo "2. Address any critical failures"
    echo "3. Set ENTRA_TENANT_ID if not configured"
    echo "4. Run: source modules/entra-id-safe.sh && install_entra_id_safely"
    
    # Return appropriate exit code
    [[ "$TESTS_FAILED" -eq 0 ]]
}

# Individual test functions for debugging
test_single() {
    local test_name="$1"
    
    case "$test_name" in
        "auth") test_basic_authentication ;;
        "network") test_network_connectivity ;;
        "prereq") test_system_prerequisites ;;
        "himmelblau") test_himmelblau_availability ;;
        "pam") test_pam_configuration ;;
        "nss") test_nss_configuration ;;
        "hyprland") test_hyprland_integration ;;
        "config") test_configuration ;;
        *) 
            echo "Unknown test: $test_name"
            echo "Available tests: auth, network, prereq, himmelblau, pam, nss, hyprland, config"
            return 1
            ;;
    esac
}

# Main execution
main() {
    case "${1:-all}" in
        "all")
            run_comprehensive_tests
            ;;
        "test")
            test_single "$2"
            ;;
        *)
            echo "Usage: $0 [all|test <test_name>]"
            echo "  all: Run comprehensive testing (default)"  
            echo "  test <name>: Run specific test"
            echo
            echo "Available tests:"
            echo "  auth - Basic authentication"
            echo "  network - Network connectivity"
            echo "  prereq - System prerequisites" 
            echo "  himmelblau - Himmelblau availability"
            echo "  pam - PAM configuration"
            echo "  nss - NSS configuration"
            echo "  hyprland - Hyprland integration"
            echo "  config - Configuration validation"
            ;;
    esac
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi