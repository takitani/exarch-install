#!/usr/bin/env bash
# Exarch Scripts - Post-installation setup for Omarchy Linux
# Modular architecture with clean separation of concerns

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source core libraries
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/config-manager.sh"
source "$SCRIPT_DIR/lib/package-manager.sh"
source "$SCRIPT_DIR/lib/hardware-detection.sh"

# Source configuration files
source "$SCRIPT_DIR/config/settings.conf"
source "$SCRIPT_DIR/config/packages.conf"
source "$SCRIPT_DIR/config/profiles.conf"

# Source modules
source "$SCRIPT_DIR/modules/1password.sh"
source "$SCRIPT_DIR/modules/development.sh"
source "$SCRIPT_DIR/modules/dell-xps.sh"
source "$SCRIPT_DIR/modules/remmina.sh"

# ======================================
# MENU SYSTEM
# ======================================

# Menu state
SELECTED_INDEX=0

# Show interactive menu
show_menu() {
  clear
  
  # Header
  echo -e "${EXATO_CYAN}╔════════════════════════════════════════╗${NC}"
  echo -e "${EXATO_CYAN}║${NC}  ${BOLD}Exarch Scripts - Setup Menu${NC}           ${EXATO_CYAN}║${NC}"
  echo -e "${EXATO_CYAN}╚════════════════════════════════════════╝${NC}"
  echo
  
  # System info
  show_system_info_compact
  
  echo
  echo -e "${BOLD}Select packages to install:${NC}"
  echo
  
  # Package categories
  show_menu_category "Web Browsers" \
    "INSTALL_GOOGLE_CHROME:Google Chrome" \
    "INSTALL_FIREFOX:Firefox"
    
  show_menu_category "Productivity Tools" \
    "INSTALL_COPYQ:CopyQ clipboard manager" \
    "INSTALL_DROPBOX:Dropbox" \
    "INSTALL_AWS_VPN:AWS VPN Client" \
    "INSTALL_ESPANSO:Espanso text expander"
    
  show_menu_category "Development Tools" \
    "INSTALL_POSTMAN:Postman API client" \
    "INSTALL_REMMINA:Remmina remote desktop" \
    "INSTALL_MISE_RUNTIMES:Node.js + .NET via mise"
    
  show_menu_category "Text Editors" \
    "INSTALL_NANO:nano" \
    "INSTALL_MICRO:micro" \
    "INSTALL_KATE:Kate"
    
  show_menu_category "Code Editors & IDEs" \
    "INSTALL_VSCODE:Visual Studio Code" \
    "INSTALL_CURSOR:Cursor AI editor" \
    "INSTALL_WINDSURF:WindSurf editor" \
    "INSTALL_JB_TOOLBOX:JetBrains Toolbox" \
    "INSTALL_JB_RIDER:JetBrains Rider" \
    "INSTALL_JB_DATAGRIP:DataGrip database IDE"
    
  show_menu_category "Communication" \
    "INSTALL_SLACK:Slack" \
    "INSTALL_TEAMS:Microsoft Teams"
    
  show_menu_category "AI & CLI Tools" \
    "INSTALL_CLAUDE_CODE:Claude Code CLI" \
    "INSTALL_CODEX_CLI:Codex CLI" \
    "INSTALL_GEMINI_CLI:Gemini CLI"
    
  show_menu_category "System Configuration" \
    "SYNC_HYPR_CONFIGS:Sync Hypr configs" \
    "SETUP_DELL_XPS_9320:Dell XPS 13 Plus setup" \
    "SETUP_DUAL_KEYBOARD:Dual keyboard (BR+US)" \
    "INSTALL_CHEZMOI:chezmoi dotfiles manager" \
    "INSTALL_AGE:Age encryption" \
    "SETUP_DOTFILES_MANAGEMENT:Dotfiles management" \
    "SETUP_DEV_PGPASS:Dev .pgpass via 1Password" \
    "SETUP_REMMINA_CONNECTIONS:Generate Remmina RDP connections from 1Password"
  
  echo
  show_menu_controls
}

# Show a menu category with options
show_menu_category() {
  local category_name="$1"
  shift
  local options=("$@")
  
  echo -e "${CYAN}$category_name:${NC}"
  
  for option in "${options[@]}"; do
    local var_name="${option%%:*}"
    local display_name="${option#*:}"
    local value="${!var_name}"
    local status="✗"
    
    [[ "$value" == "true" ]] && status="✓"
    
    echo "  $status $display_name"
  done
  
  echo
}

# Show compact system information
show_system_info_compact() {
  local hardware
  hardware=$(detect_hardware)
  
  echo -e "${BOLD}System:${NC} $(uname -s) $(uname -r) ($(uname -m))"
  if [[ -n "$hardware" ]]; then
    echo -e "${BOLD}Hardware:${NC} $hardware"
    if is_dell_xps_9320; then
      echo -e "${YELLOW}  → Dell XPS optimizations available${NC}"
    fi
  fi
}

# Show menu controls
show_menu_controls() {
  echo -e "${BOLD}Controls:${NC}"
  echo "  ${CYAN}↑/↓${NC} Navigate   ${CYAN}Space${NC} Toggle   ${CYAN}Enter${NC} Install"
  echo "  ${CYAN}a${NC} All   ${CYAN}r${NC} Recommended   ${CYAN}d${NC} Development   ${CYAN}m${NC} Minimal"
  echo "  ${CYAN}h${NC} Hardware report   ${CYAN}q${NC} Quit"
  
  if is_debug_mode; then
    echo -e "  ${YELLOW}DEBUG MODE ACTIVE${NC}"
  fi
  
  if is_1pass_test_mode; then
    echo -e "  ${CYAN}1PASSWORD TEST MODE${NC}"
  fi
  
  if is_remmina_test_mode; then
    echo -e "  ${CYAN}REMMINA DEBUG MODE${NC}"
  fi
}

# Interactive menu loop
interactive_menu() {
  while true; do
    show_menu
    
    echo
    echo -n "Choice: "
    read -r choice
    
    case "$choice" in
      ""|"enter")
        start_installation
        break
        ;;
      "a")
        apply_profile "all"
        ;;
      "r")
        apply_profile "recommended" 
        ;;
      "d")
        apply_profile "development"
        ;;
      "m")
        apply_profile "minimal"
        ;;
      "x")
        apply_profile "dell-xps"
        ;;
      "h")
        show_hardware_report
        echo
        echo "Press Enter to continue..."
        read -r
        ;;
      "q")
        echo "Goodbye!"
        exit 0
        ;;
      *)
        if toggle_option "$choice"; then
          continue
        else
          echo "Invalid option: $choice"
          sleep 1
        fi
        ;;
    esac
  done
}

# Toggle configuration option
toggle_option() {
  local choice="$1"
  
  case "$choice" in
    # Add individual toggle cases as needed
    *)
      return 1
      ;;
  esac
}

# ======================================
# INSTALLATION ORCHESTRATION
# ======================================

# Main installation function
start_installation() {
  echo
  info "Starting installation with current configuration..."
  
  # Initialize logging
  init_logging
  
  # Pre-installation checks
  perform_pre_installation_checks
  
  # Setup environment
  setup_installation_environment
  
  # Execute modules
  execute_installation_modules
  
  # Post-installation tasks
  perform_post_installation_tasks
  
  # Show final report
  show_final_report
}

# Pre-installation system checks
perform_pre_installation_checks() {
  info "Performing pre-installation checks..."
  
  # Check if not running as root
  check_not_root
  
  # Check internet connection
  if ! check_internet; then
    err "Internet connection required for installation"
    exit 1
  fi
  
  # Check required dependencies
  if ! check_dependencies yay git; then
    err "Required dependencies missing"
    exit 1
  fi
  
  # Check disk space
  local available_space
  available_space=$(df / | awk 'NR==2 {print int($4/1024/1024)}')
  if [[ $available_space -lt ${MIN_DISK_SPACE_GB:-10} ]]; then
    err "Insufficient disk space: ${available_space}GB available, ${MIN_DISK_SPACE_GB:-10}GB required"
    exit 1
  fi
  
  success "Pre-installation checks passed"
}

# Setup installation environment
setup_installation_environment() {
  info "Setting up installation environment..."
  
  # Setup temporary DNS if configured
  if [[ "${#DNS_SERVERS[@]}" -gt 0 ]] && [[ ! -f "/tmp/resolv.conf.backup" ]]; then
    info "Configuring temporary DNS..."
    sudo cp /etc/resolv.conf /tmp/resolv.conf.backup
    
    {
      echo "# Temporary DNS for installation"
      for dns in "${DNS_SERVERS[@]}"; do
        echo "nameserver $dns"
      done
    } | sudo tee /etc/resolv.conf > /dev/null
  fi
  
  # Update package databases if configured
  if [[ "${RUN_SYSTEM_UPDATE:-true}" == "true" ]]; then
    update_databases
  fi
  
  success "Installation environment ready"
}

# Execute installation modules
execute_installation_modules() {
  info "Executing installation modules..."
  
  # Desktop applications
  install_desktop_applications
  
  # Development environment
  if module_enabled "development"; then
    setup_development_environment
  fi
  
  # 1Password integration
  if module_enabled "1password"; then
    setup_1password_complete
  fi
  
  # Remmina connections (standalone)
  if module_enabled "remmina"; then
    setup_remmina_connections_complete
  fi
  
  # Dell XPS optimizations
  if module_enabled "dell-xps"; then
    setup_dell_xps_9320_complete
  fi
  
  # Dotfiles management
  if module_enabled "dotfiles"; then
    setup_dotfiles_management_complete
  fi
  
  # Wait for all background jobs to complete
  wait_for_background_jobs
  
  success "All modules executed"
}

# Install desktop applications
install_desktop_applications() {
  info "Installing desktop applications..."
  
  local apps_to_install=()
  
  # Browsers
  [[ "${INSTALL_GOOGLE_CHROME:-true}" == "true" ]] && apps_to_install+=("google-chrome")
  [[ "${INSTALL_FIREFOX:-true}" == "true" ]] && apps_to_install+=("firefox")
  
  # Productivity
  [[ "${INSTALL_COPYQ:-true}" == "true" ]] && apps_to_install+=("copyq")
  [[ "${INSTALL_DROPBOX:-true}" == "true" ]] && apps_to_install+=("dropbox")
  
  # Install in background for heavy packages
  for app in "${apps_to_install[@]}"; do
    if [[ " ${HEAVY_PACKAGES_AUR[*]} " =~ " $app " ]]; then
      start_background_job "$app" "$app" "aur"
    else
      # Install immediately for light packages
      if [[ " ${DESKTOP_APPS_PACMAN[*]} " =~ " $app " ]]; then
        pac "$app"
      else
        aur "$app"
      fi
    fi
  done
  
  success "Desktop applications installation initiated"
}

# Check if module is enabled
module_enabled() {
  local module="$1"
  
  case "$module" in
    "development")
      [[ "${ENABLE_DEVELOPMENT_MODULE:-true}" == "true" ]]
      ;;
    "1password")
      [[ "${ENABLE_1PASSWORD_MODULE:-true}" == "true" ]] && [[ "${SETUP_DEV_PGPASS:-false}" == "true" ]]
      ;;
    "remmina")
      [[ "${ENABLE_REMMINA_MODULE:-true}" == "true" ]] && [[ "${SETUP_REMMINA_CONNECTIONS:-false}" == "true" ]]
      ;;
    "dell-xps") 
      [[ "${ENABLE_DELL_XPS_MODULE:-true}" == "true" ]] && [[ "${SETUP_DELL_XPS_9320:-false}" == "true" ]]
      ;;
    "dotfiles")
      [[ "${ENABLE_DOTFILES_MODULE:-true}" == "true" ]] && [[ "${SETUP_DOTFILES_MANAGEMENT:-false}" == "true" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

# Setup dotfiles management (placeholder)
setup_dotfiles_management_complete() {
  if [[ "${SETUP_DOTFILES_MANAGEMENT:-false}" != "true" ]]; then
    return 0
  fi
  
  info "Setting up dotfiles management..."
  
  # Install chezmoi if selected
  if [[ "${INSTALL_CHEZMOI:-true}" == "true" ]]; then
    pac chezmoi
  fi
  
  # Install age if selected
  if [[ "${INSTALL_AGE:-true}" == "true" ]]; then
    aur age-bin || aur age
  fi
  
  success "Dotfiles management setup completed"
}

# Post-installation tasks
perform_post_installation_tasks() {
  info "Performing post-installation tasks..."
  
  # Clean package cache if configured
  if [[ "${CLEAN_PACKAGE_CACHE:-true}" == "true" ]] && ! is_debug_mode; then
    info "Cleaning package cache..."
    yay -Sc --noconfirm >/dev/null 2>&1 || true
  fi
  
  # Restore DNS configuration
  if [[ -f "/tmp/resolv.conf.backup" ]]; then
    info "Restoring DNS configuration..."
    sudo mv /tmp/resolv.conf.backup /etc/resolv.conf
  fi
  
  success "Post-installation tasks completed"
}

# Show final installation report
show_final_report() {
  echo
  echo -e "${BOLD}╔════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║${NC}           Installation Complete!          ${BOLD}║${NC}"
  echo -e "${BOLD}╚════════════════════════════════════════╝${NC}"
  echo
  
  # Installation summary
  echo -e "${BOLD}Installation Summary:${NC}"
  echo "═══════════════════════"
  
  if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "\n${GREEN}✓ Installed packages (${#INSTALLED_PACKAGES[@]}):${NC}"
    for package in "${INSTALLED_PACKAGES[@]}"; do
      echo "  • $package"
    done
  fi
  
  if [[ ${#CONFIGURED_RUNTIMES[@]} -gt 0 ]]; then
    echo -e "\n${CYAN}⚙ Configured runtimes (${#CONFIGURED_RUNTIMES[@]}):${NC}"
    for runtime in "${CONFIGURED_RUNTIMES[@]}"; do
      echo "  • $runtime"
    done
  fi
  
  if [[ ${#SKIPPED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "\n${YELLOW}⏩ Skipped packages (${#SKIPPED_PACKAGES[@]}):${NC}"
    for package in "${SKIPPED_PACKAGES[@]}"; do
      echo "  • $package"
    done
  fi
  
  if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "\n${RED}❌ Failed packages (${#FAILED_PACKAGES[@]}):${NC}"
    for package in "${FAILED_PACKAGES[@]}"; do
      echo "  • $package"
    done
  fi
  
  # Next steps
  echo
  echo -e "${BOLD}Next Steps:${NC}"
  
  if [[ "${SETUP_DELL_XPS_9320:-false}" == "true" ]] && is_dell_xps_9320; then
    echo "• Reboot to activate Dell XPS drivers"
  fi
  
  if [[ "${SETUP_DEV_PGPASS:-false}" == "true" ]]; then
    echo "• Your .pgpass file has been configured for database access"
  fi
  
  if [[ "${SETUP_REMMINA_CONNECTIONS:-false}" == "true" ]]; then
    echo "• Remmina RDP connections have been generated from 1Password"
  fi
  
  echo "• Log files saved to: $LOG_DIR"
  
  if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo "• Review failed packages and install manually if needed"
  fi
  
  echo
  success "Setup completed successfully! 🎉"
}

# ======================================
# MAIN FUNCTION
# ======================================

main() {
  # Load configuration from all sources
  if ! load_configuration "$@"; then
    err "Failed to load configuration"
    exit 1
  fi
  
  # Handle special modes
  if is_1pass_test_mode; then
    test_1password_mode
    exit $?
  fi
  
  if is_remmina_test_mode; then
    test_remmina_mode
    exit $?
  fi
  
  # Show interactive menu or start direct installation
  if [[ $# -eq 0 ]]; then
    interactive_menu
  else
    # Direct installation with arguments
    start_installation
  fi
}

# Run main function
main "$@"