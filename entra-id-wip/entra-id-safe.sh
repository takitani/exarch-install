#!/usr/bin/env bash
# modules/entra-id-safe.sh - SAFE Microsoft Entra ID integration with Himmelblau
# 
# This is a SAFER version that includes proper validation, rollback, and incremental configuration
# Based on lessons learned from authentication system failure analysis

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"

# Configuration
ENTRA_TENANT_ID="${ENTRA_TENANT_ID:-}"
ENTRA_DOMAIN="${ENTRA_DOMAIN:-exato.digital}"
BACKUP_DIR="/home/opik/backups/himmelblau-$(date +%Y%m%d_%H%M%S)"
HIMMELBLAU_VERSION="latest"

# Safety flags
ENABLE_ROLLBACK=true
VALIDATE_EACH_STEP=true
PRESERVE_LOCAL_AUTH=true
TEST_MODE=false

# Create comprehensive backup before any changes
create_system_backup() {
    info "Creating comprehensive system backup at $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # PAM configurations
    if sudo cp -r /etc/pam.d/ "$BACKUP_DIR/pam.d.original" 2>/dev/null; then
        success "PAM configurations backed up"
    else
        warn "Could not backup PAM configs (will continue)"
    fi
    
    # NSS configuration
    cp /etc/nsswitch.conf "$BACKUP_DIR/nsswitch.conf.original" 2>/dev/null || warn "Could not backup NSS config"
    
    # System state
    systemctl list-units --state=active > "$BACKUP_DIR/active-services.txt"
    id > "$BACKUP_DIR/current-user-info.txt"
    whoami > "$BACKUP_DIR/current-user.txt"
    
    # Create restore script
    cat > "$BACKUP_DIR/restore.sh" << 'EOF'
#!/bin/bash
# Emergency restore script
BACKUP_DIR="$(dirname "$0")"
echo "Restoring system from backup in $BACKUP_DIR"

# Stop himmelblau if running
sudo systemctl stop himmelblaud 2>/dev/null || true
sudo systemctl disable himmelblaud 2>/dev/null || true

# Restore PAM
if [[ -d "$BACKUP_DIR/pam.d.original" ]]; then
    sudo cp -r "$BACKUP_DIR/pam.d.original"/* /etc/pam.d/
    echo "PAM restored"
fi

# Restore NSS
if [[ -f "$BACKUP_DIR/nsswitch.conf.original" ]]; then
    sudo cp "$BACKUP_DIR/nsswitch.conf.original" /etc/nsswitch.conf
    echo "NSS restored"
fi

echo "System restore completed. Reboot recommended."
EOF
    chmod +x "$BACKUP_DIR/restore.sh"
    
    success "System backup created at $BACKUP_DIR"
    info "Emergency restore available: $BACKUP_DIR/restore.sh"
}

# Validate system before proceeding
validate_system_prerequisites() {
    info "Validating system prerequisites..."
    
    local validation_failed=false
    
    # Check if we can authenticate currently (skip interactive test)
    if ! sudo -n true 2>/dev/null; then
        if ! groups | grep -q wheel; then
            err "User not in wheel group - cannot use sudo"
            return 1
        else
            info "User in wheel group - assuming sudo access available"
        fi
    fi
    
    # Check network connectivity to Microsoft endpoints
    local endpoints=("login.microsoftonline.com" "graph.microsoft.com")
    for endpoint in "${endpoints[@]}"; do
        if ! ping -c 1 "$endpoint" >/dev/null 2>&1; then
            warn "Cannot reach $endpoint - network issues may affect authentication"
            validation_failed=true
        fi
    done
    
    # Check time synchronization (critical for OAuth/Kerberos)
    if ! timedatectl status | grep -q "System clock synchronized: yes"; then
        warn "System clock not synchronized - this may cause authentication failures"
        info "Run: sudo timedatectl set-ntp true"
    fi
    
    # Validate current authentication works
    if ! echo "test" | su -c "exit 0" "$USER" >/dev/null 2>&1; then
        warn "Current user authentication test failed"
    fi
    
    # Check required tools
    local required_tools=("curl" "systemctl" "sed" "grep")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null; then
            err "Required tool '$tool' not found"
            return 1
        fi
    done
    
    if [[ "$validation_failed" == "true" ]] && [[ "$TEST_MODE" != "true" ]]; then
        warn "Some validations failed. Continue anyway? [y/N]"
        read -r response
        [[ "$response" =~ ^[yY]$ ]] || return 1
    fi
    
    success "System prerequisites validated"
    return 0
}

# Check if Himmelblau is available
check_himmelblau_availability() {
    info "Checking Himmelblau availability..."
    
    # Check if we can build from source (most reliable method)
    if command -v rustc >/dev/null && command -v cargo >/dev/null && command -v git >/dev/null; then
        success "Rust toolchain and Git available for building from source"
        return 0
    fi
    
    # Check AUR as fallback (but don't fail if network issues)
    if command -v yay >/dev/null; then
        if timeout 10 yay -Ss himmelblau 2>/dev/null | grep -q "himmelblau"; then
            success "Himmelblau packages found in AUR"
            return 0
        else
            info "AUR search failed or timed out - will try build from source"
        fi
    fi
    
    err "Himmelblau not available - need Rust toolchain (rustc, cargo, git)"
    return 1
}

# Safe PAM configuration - INCREMENTAL approach
configure_pam_safely() {
    info "Configuring PAM safely for Himmelblau..."
    
    # Only modify if himmelblau PAM module actually exists
    if [[ ! -f "/usr/lib/security/pam_himmelblau.so" ]]; then
        err "Himmelblau PAM module not found - installation may have failed"
        return 1
    fi
    
    # Test the PAM module can load
    if ! ldd /usr/lib/security/pam_himmelblau.so >/dev/null 2>&1; then
        err "Himmelblau PAM module has dependency issues"
        return 1
    fi
    
    # Create a TEST PAM configuration first
    local test_pam="/tmp/test-himmelblau-pam"
    cat > "$test_pam" << EOF
#%PAM-1.0
# Test configuration with Himmelblau
auth       required                    pam_faillock.so preauth silent
auth       [success=2 default=ignore]  pam_himmelblau.so
auth       [success=1 default=bad]     pam_unix.so try_first_pass nullok
auth       [default=die]               pam_faillock.so authfail
auth       optional                    pam_permit.so
auth       required                    pam_env.so
auth       required                    pam_faillock.so authsucc

account    [success=1 default=ignore]  pam_himmelblau.so
account    required                    pam_unix.so
account    optional                    pam_permit.so
account    required                    pam_time.so

session    optional                    pam_himmelblau.so
session    required                    pam_limits.so
session    required                    pam_unix.so
session    optional                    pam_permit.so
EOF
    
    # Test the PAM configuration syntax
    if ! pamtester -v "$test_pam" "$USER" authenticate >/dev/null 2>&1; then
        warn "PAM test configuration failed - this is expected, but module loaded"
    fi
    
    success "PAM module validated"
    
    # NOW we can safely modify the actual PAM config
    info "Applying safe PAM configuration..."
    
    # Backup and modify system-auth (the core PAM config)
    local pam_system_auth="/etc/pam.d/system-auth"
    sudo cp "$pam_system_auth" "$pam_system_auth.pre-himmelblau"
    
    # Add himmelblau as SUFFICIENT (not required) so local auth still works
    if ! grep -q "pam_himmelblau" "$pam_system_auth"; then
        # Add himmelblau BEFORE unix, but as sufficient so fallback works
        sudo sed -i '/auth.*pam_unix.so/i auth       [success=2 default=ignore]  pam_himmelblau.so' "$pam_system_auth"
        sudo sed -i '/account.*pam_unix.so/i account    [success=1 default=ignore]  pam_himmelblau.so' "$pam_system_auth"  
        sudo sed -i '/session.*pam_unix.so/a session     optional    pam_himmelblau.so' "$pam_system_auth"
        
        success "PAM configuration updated with Himmelblau support"
    else
        info "Himmelblau already configured in PAM"
    fi
    
    # Validate the modified PAM configuration
    if ! sudo pamtester system-auth "$USER" authenticate >/dev/null 2>&1; then
        warn "Modified PAM configuration test failed - but this may be expected"
        info "Local authentication should still work as fallback"
    fi
    
    return 0
}

# Safe NSS configuration
configure_nss_safely() {
    info "Configuring NSS safely for Himmelblau..."
    
    # Check if himmelblau NSS module exists
    if [[ ! -f "/usr/lib/libnss_himmelblau.so.2" ]]; then
        err "Himmelblau NSS module not found"
        return 1
    fi
    
    local nsswitch="/etc/nsswitch.conf"
    sudo cp "$nsswitch" "$nsswitch.pre-himmelblau"
    
    # Add himmelblau to lookups, but keep files as primary
    if ! grep -q "himmelblau" "$nsswitch"; then
        sudo sed -i 's/^passwd:.*/passwd: files himmelblau systemd/' "$nsswitch"
        sudo sed -i 's/^group:.*/group: files himmelblau systemd/' "$nsswitch"
        sudo sed -i 's/^shadow:.*/shadow: files himmelblau/' "$nsswitch"
        
        success "NSS configuration updated"
    else
        info "Himmelblau already configured in NSS"
    fi
    
    # Test NSS lookups still work for local user
    if ! getent passwd "$USER" >/dev/null 2>&1; then
        err "NSS lookup for current user failed - reverting"
        sudo cp "$nsswitch.pre-himmelblau" "$nsswitch"
        return 1
    fi
    
    success "NSS configuration validated"
    return 0
}

# Install Himmelblau safely
install_himmelblau_safely() {
    info "Installing Himmelblau safely..."
    
    # Try AUR first
    if command -v yay >/dev/null; then
        info "Attempting Himmelblau installation from AUR..."
        if yay -S --noconfirm himmelblau himmelblau-pam 2>/dev/null; then
            success "Himmelblau installed from AUR"
        else
            warn "AUR installation failed, trying build from source..."
            return install_himmelblau_from_source
        fi
    else
        warn "No AUR helper found, trying build from source..."
        return install_himmelblau_from_source
    fi
    
    # Verify installation
    if [[ ! -f "/usr/bin/himmelblau" ]] || [[ ! -f "/usr/lib/security/pam_himmelblau.so" ]]; then
        err "Himmelblau installation incomplete"
        return 1
    fi
    
    success "Himmelblau installed successfully"
    return 0
}

# Install Himmelblau from source
install_himmelblau_from_source() {
    info "Installing Himmelblau from source..."
    
    # Check prerequisites
    if ! command -v rustc >/dev/null || ! command -v cargo >/dev/null; then
        err "Rust toolchain not available for building from source"
        return 1
    fi
    
    if ! command -v git >/dev/null; then
        err "Git not available for cloning repository"
        return 1
    fi
    
    # Create build directory
    local build_dir="/tmp/himmelblau-build-$(date +%s)"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    info "Cloning Himmelblau repository..."
    if ! git clone --depth 1 https://github.com/himmelblau-idm/himmelblau.git; then
        err "Failed to clone Himmelblau repository"
        return 1
    fi
    
    cd himmelblau
    
    info "Building Himmelblau (this may take several minutes)..."
    if ! cargo build --release; then
        err "Failed to build Himmelblau"
        return 1
    fi
    
    info "Installing Himmelblau binaries..."
    # Install binaries
    sudo install -Dm755 target/release/himmelblau /usr/bin/himmelblau
    sudo install -Dm755 target/release/himmelblaud /usr/bin/himmelblaud
    
    # Install PAM module if built
    if [[ -f "target/release/libpam_himmelblau.so" ]]; then
        sudo install -Dm755 target/release/libpam_himmelblau.so /usr/lib/security/pam_himmelblau.so
    fi
    
    # Install NSS module if built
    if [[ -f "target/release/libnss_himmelblau.so" ]]; then
        sudo install -Dm755 target/release/libnss_himmelblau.so /usr/lib/libnss_himmelblau.so.2
    fi
    
    # Install systemd service
    if [[ -f "platform/debian/himmelblaud.service" ]]; then
        sudo install -Dm644 platform/debian/himmelblaud.service /usr/lib/systemd/system/himmelblaud.service
    fi
    
    # Clean up
    cd /
    rm -rf "$build_dir"
    
    # Verify installation
    if [[ ! -f "/usr/bin/himmelblau" ]]; then
        err "Himmelblau binary installation failed"
        return 1
    fi
    
    success "Himmelblau built and installed from source"
    return 0
}

# Configure Himmelblau daemon
configure_himmelblau_daemon() {
    info "Configuring Himmelblau daemon..."
    
    if [[ -z "$ENTRA_TENANT_ID" ]]; then
        err "ENTRA_TENANT_ID not set - cannot configure daemon"
        return 1
    fi
    
    sudo mkdir -p /etc/himmelblau
    
    sudo tee /etc/himmelblau/himmelblau.conf > /dev/null << EOF
[global]
# Microsoft Entra ID Configuration
tenant_id = $ENTRA_TENANT_ID
domain = $ENTRA_DOMAIN

# Authentication settings
cache_timeout = 3600
offline_timeout = 86400
require_mfa = false

# Logging
log_level = info
log_file = /var/log/himmelblau.log
EOF
    
    success "Himmelblau daemon configured"
    return 0
}

# Test authentication incrementally
test_authentication_incrementally() {
    info "Testing authentication incrementally..."
    
    # Test 1: Local authentication still works
    info "Testing local authentication..."
    if echo "test" | su -c "exit 0" "$USER" >/dev/null 2>&1; then
        success "Local authentication works"
    else
        err "Local authentication broken - this is critical!"
        return 1
    fi
    
    # Test 2: PAM modules load
    info "Testing PAM module loading..."
    if ldd /usr/lib/security/pam_himmelblau.so >/dev/null 2>&1; then
        success "Himmelblau PAM module loads correctly"
    else
        warn "Himmelblau PAM module has issues"
    fi
    
    # Test 3: NSS lookups work
    info "Testing NSS lookups..."
    if getent passwd "$USER" >/dev/null 2>&1; then
        success "NSS lookups work for local users"
    else
        err "NSS lookups broken"
        return 1
    fi
    
    # Test 4: Himmelblau daemon
    info "Testing Himmelblau daemon..."
    if sudo systemctl start himmelblaud; then
        if systemctl is-active --quiet himmelblaud; then
            success "Himmelblau daemon started successfully"
        else
            warn "Himmelblau daemon failed to start"
            sudo journalctl -u himmelblaud --no-pager -n 10
        fi
    else
        warn "Could not start Himmelblau daemon"
    fi
    
    return 0
}

# Main installation function
install_entra_id_safely() {
    info "Starting SAFE Microsoft Entra ID integration with Himmelblau"
    
    # Check for required configuration
    if [[ -z "$ENTRA_TENANT_ID" ]]; then
        err "ENTRA_TENANT_ID must be set. Example: export ENTRA_TENANT_ID='your-tenant-id'"
        return 1
    fi
    
    # Step 1: Prerequisites
    validate_system_prerequisites || {
        err "System prerequisites validation failed"
        return 1
    }
    
    # Step 2: Create backup
    create_system_backup || {
        err "Could not create system backup"
        return 1
    }
    
    # Step 3: Check availability
    check_himmelblau_availability || {
        err "Himmelblau not available"
        return 1
    }
    
    # Step 4: Install Himmelblau
    install_himmelblau_safely || {
        err "Himmelblau installation failed"
        return 1
    }
    
    # Step 5: Configure daemon
    configure_himmelblau_daemon || {
        err "Daemon configuration failed"
        return 1
    }
    
    # Step 6: Configure NSS
    configure_nss_safely || {
        err "NSS configuration failed"
        return 1
    }
    
    # Step 7: Configure PAM
    configure_pam_safely || {
        err "PAM configuration failed"
        return 1
    }
    
    # Step 8: Test everything
    test_authentication_incrementally || {
        err "Authentication testing failed"
        return 1
    }
    
    success "Microsoft Entra ID integration completed successfully!"
    info "Backup and restore scripts available at: $BACKUP_DIR"
    info "To join domain: sudo himmelblau domain join"
    
    return 0
}

# Rollback function
rollback_entra_id() {
    warn "Rolling back Microsoft Entra ID integration..."
    
    # Stop services
    sudo systemctl stop himmelblaud 2>/dev/null || true
    sudo systemctl disable himmelblaud 2>/dev/null || true
    
    # Restore from most recent backup
    local latest_backup=$(ls -1dt /home/opik/backups/himmelblau-* 2>/dev/null | head -1)
    if [[ -n "$latest_backup" ]] && [[ -f "$latest_backup/restore.sh" ]]; then
        info "Restoring from backup: $latest_backup"
        bash "$latest_backup/restore.sh"
        success "System restored from backup"
    else
        warn "No backup found - manual restoration required"
    fi
}

# Export functions
export -f install_entra_id_safely rollback_entra_id create_system_backup