#!/usr/bin/env bash
# test-ssh-keys.sh - Test SSH keys functionality with 1Password

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source core libraries
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/config-manager.sh"
source "$SCRIPT_DIR/lib/package-manager.sh"

# Source 1Password module
source "$SCRIPT_DIR/modules/1password.sh"

# Test SSH keys functionality
test_ssh_keys_functionality() {
  echo
  echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  ${BOLD}SSH Keys 1Password Test Mode${NC}${CYAN} ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════╗${NC}"
  echo
  
  # Enable SSH keys module for testing
  SETUP_SSH_KEYS=true
  
  echo "SSH Keys Test Mode"
  echo "=================="
  echo
  echo "This will test SSH key synchronization from 1Password."
  echo "You'll be asked to provide the name of your SSH key in 1Password."
  echo
  echo "Example key names: opiklocal, github-key, server-key, etc."
  echo
  
  if setup_ssh_keys_from_1password; then
    success "SSH keys test completed successfully!"
    echo
    echo -e "${BOLD}What was done:${NC}"
    echo "  • SSH key downloaded from 1Password"
    echo "  • Key files created in ~/.ssh/"
    echo "  • Symlinks created for standard names"
    echo "  • SSH agent configured"
    echo "  • Backups of existing keys created"
    echo
    echo "You can now use SSH with your synced key!"
    return 0
  else
    err "SSH keys test failed"
    return 1
  fi
}

# Main execution
main() {
  # Check if 1Password CLI is available
  if ! command_exists op; then
    err "1Password CLI not found. Please install it first:"
    echo "  yay -S 1password-cli-bin"
    return 1
  fi
  
  # Check if jq is available
  if ! command_exists jq; then
    err "jq not found. Please install it first:"
    echo "  sudo pacman -S jq"
    return 1
  fi
  
  # Check if OpenSSH is available
  if ! command_exists ssh-keygen; then
    err "OpenSSH not found. Please install it first:"
    echo "  sudo pacman -S openssh"
    return 1
  fi
  
  # Run test
  test_ssh_keys_functionality
}

# Run main function
main "$@"
