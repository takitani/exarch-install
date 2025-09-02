#!/usr/bin/env bash
# fix-dell-xps-shutdown.sh - Emergency fix for Dell XPS shutdown issues

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

# Emergency cleanup function
emergency_cleanup() {
    log_info "Starting emergency cleanup for Dell XPS shutdown issues..."
    
    # Stop problematic services
    log_info "Stopping TLP services..."
    sudo systemctl stop tlp 2>/dev/null || log_warn "TLP service not running"
    sudo systemctl stop thermald 2>/dev/null || log_warn "thermald service not running"
    sudo systemctl stop fwupd 2>/dev/null || log_warn "fwupd service not running"
    
    # Disable services temporarily
    log_info "Disabling services temporarily..."
    sudo systemctl disable tlp 2>/dev/null || log_warn "Could not disable TLP"
    sudo systemctl disable thermald 2>/dev/null || log_warn "Could not disable thermald"
    sudo systemctl disable fwupd 2>/dev/null || log_warn "Could not disable fwupd"
    
    # Unload IPU6 modules
    log_info "Unloading IPU6 modules..."
    local modules=("ipu6_drivers" "intel_ipu6_isys" "intel_ipu6_psys")
    for module in "${modules[@]}"; do
        if lsmod | grep -q "^$module "; then
            log_info "Unloading module: $module"
            sudo modprobe -r "$module" 2>/dev/null || log_warn "Failed to unload $module"
        fi
    done
    
    # Kill any remaining processes
    log_info "Terminating remaining processes..."
    local processes=("tlp" "thermald" "fwupd" "ipu6")
    for proc in "${processes[@]}"; do
        local pids
        pids=$(pgrep "$proc" 2>/dev/null)
        if [[ -n "$pids" ]]; then
            log_info "Terminating $proc processes: $pids"
            echo "$pids" | xargs -r sudo kill -TERM 2>/dev/null
            sleep 1
            echo "$pids" | xargs -r sudo kill -KILL 2>/dev/null
        fi
    done
    
    # Remove problematic service files
    log_info "Removing problematic service files..."
    sudo rm -f /etc/systemd/system/tlp.service
    sudo rm -f /etc/systemd/system/thermald.service
    sudo rm -f /etc/systemd/system/fwupd.service
    
    # Reload systemd
    log_info "Reloading systemd..."
    sudo systemctl daemon-reload
    
    # Sync filesystems
    log_info "Syncing filesystems..."
    sudo sync
    
    log_success "Emergency cleanup completed!"
}

# Check system status
check_system_status() {
    log_info "Checking system status..."
    
    echo
    log_info "=== Service Status ==="
    systemctl list-units --failed --no-pager || log_info "No failed services"
    
    echo
    log_info "=== Loaded Modules ==="
    lsmod | grep -E "(ipu6|intel)" || log_info "No IPU6 modules loaded"
    
    echo
    log_info "=== Active Processes ==="
    ps aux | grep -E "(tlp|thermald|fwupd|ipu6)" | grep -v grep || log_info "No problematic processes running"
    
    echo
    log_info "=== Recent Errors ==="
    journalctl -b -p err --no-pager | tail -20 || log_info "No recent errors found"
}

# Safe reboot function
safe_reboot() {
    log_warn "Attempting safe reboot..."
    
    # Final cleanup
    emergency_cleanup
    
    # Wait a moment
    sleep 3
    
    log_info "Initiating safe reboot..."
    sudo reboot
}

# Main menu
show_menu() {
    echo
    echo -e "${BLUE}Dell XPS Shutdown Fix Tool${NC}"
    echo "================================"
    echo
    echo "1. Check system status"
    echo "2. Emergency cleanup"
    echo "3. Safe reboot"
    echo "4. Exit"
    echo
}

# Main function
main() {
    if [[ $EUID -eq 0 ]]; then
        log_error "This script should not be run as root"
        exit 1
    fi
    
    log_info "Dell XPS Shutdown Fix Tool started"
    
    while true; do
        show_menu
        read -p "Select option (1-4): " choice
        
        case $choice in
            1)
                check_system_status
                ;;
            2)
                emergency_cleanup
                ;;
            3)
                read -p "Are you sure you want to reboot? (y/N): " confirm
                if [[ "$confirm" =~ ^[Yy]$ ]]; then
                    safe_reboot
                else
                    log_info "Reboot cancelled"
                fi
                ;;
            4)
                log_info "Exiting..."
                exit 0
                ;;
            *)
                log_error "Invalid option. Please select 1-4."
                ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
    done
}

# Run main function
main "$@"
