#!/usr/bin/env bash
# Exarch Scripts - Post-installation setup for Omarchy Linux
# Modular architecture with clean separation of concerns

# Bootstrap function for remote execution
bootstrap_remote() {
  # Colors for output
  local RED='\033[0;31m'
  local GREEN='\033[0;32m'
  local BLUE='\033[0;34m'
  local BOLD='\033[1m'
  local NC='\033[0m'
  
  echo -e "${BOLD}🚀 Exarch Scripts - Remote Bootstrap${NC}"
  echo "Detected remote execution, downloading full repository..."
  echo
  
  # Repository details
  local REPO_URL="https://github.com/takitani/exarch-install"
  local TEMP_DIR="/tmp/exarch-scripts-$$"
  
  # Check for required tools
  if ! command -v git &> /dev/null; then
    echo -e "${RED}[ERROR]${NC} git is required but not installed. Please install git first: sudo pacman -S git"
    exit 1
  fi
  
  # Create temporary directory
  mkdir -p "$TEMP_DIR"
  
  # Clone the repository
  echo -e "${BLUE}[INFO]${NC} Cloning repository..."
  if ! git clone "$REPO_URL" "$TEMP_DIR/exarch-install" >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} Failed to clone repository"
    exit 1
  fi
  
  # Change to the repository directory and execute
  cd "$TEMP_DIR/exarch-install"
  chmod +x install.sh
  
  echo -e "${GREEN}[SUCCESS]${NC} Repository downloaded, executing script..."
  echo
  
  # Execute with all original arguments
  exec ./install.sh "$@"
}

# Detect if running remotely (via curl/wget)
# Check if script directory doesn't contain expected files
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# If we're in /dev/fd or missing core files, we're running remotely
if [[ "$SCRIPT_DIR" == "/dev/fd" ]] || [[ ! -f "$SCRIPT_DIR/lib/core.sh" ]]; then
  bootstrap_remote "$@"
  exit $?
fi

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
source "$SCRIPT_DIR/modules/pipewire-camera.sh"
source "$SCRIPT_DIR/modules/espanso.sh"
source "$SCRIPT_DIR/modules/gnome-keyring.sh"
source "$SCRIPT_DIR/modules/keyboard-layout.sh"
source "$SCRIPT_DIR/modules/windows-docker.sh"

# ======================================
# MENU SYSTEM
# ======================================

# Menu state
SELECTED_INDEX=0

# Show interactive menu
show_menu() {
  clear
  
  # Reset menu counter
  MENU_ITEM_COUNTER=0
  
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
  show_menu_category "Web Browsers" "10" \
    "INSTALL_GOOGLE_CHROME:Google Chrome" \
    "INSTALL_FIREFOX:Firefox"
    
  show_menu_category "Productivity Tools" "20" \
    "INSTALL_COPYQ:CopyQ clipboard manager" \
    "INSTALL_DROPBOX:Dropbox" \
    "INSTALL_AWS_VPN:AWS VPN Client" \
    "INSTALL_ESPANSO:Espanso text expander"
    
  show_menu_category "Development Tools" "30" \
    "INSTALL_POSTMAN:Postman API client" \
    "INSTALL_REMMINA:Remmina remote desktop" \
    "INSTALL_MISE_RUNTIMES:Node.js + .NET via mise"
    
  show_menu_category "Text Editors" "40" \
    "INSTALL_NANO:nano" \
    "INSTALL_MICRO:micro" \
    "INSTALL_KATE:Kate"
    
  show_menu_category "Code Editors & IDEs" "50" \
    "INSTALL_VSCODE:Visual Studio Code" \
    "INSTALL_CURSOR:Cursor AI editor" \
    "INSTALL_WINDSURF:WindSurf editor" \
    "INSTALL_JB_TOOLBOX:JetBrains Toolbox" \
    "INSTALL_JB_RIDER:JetBrains Rider" \
    "INSTALL_JB_DATAGRIP:DataGrip database IDE"
    
  show_menu_category "Communication" "60" \
    "INSTALL_SLACK:Slack" \
    "INSTALL_TEAMS:Microsoft Teams"
    
  show_menu_category "AI & CLI Tools" "70" \
    "INSTALL_CLAUDE_CODE:Claude Code CLI" \
    "INSTALL_CODEX_CLI:Codex CLI" \
    "INSTALL_GEMINI_CLI:Gemini CLI"
    
  show_menu_category "Virtual Environments" "80" \
    "INSTALL_WINDOWS_DOCKER:Windows 11 via Docker" \
    "INSTALL_WINAPPS_LAUNCHER:WinApps Launcher (Windows app integration)"
    
  show_menu_category "System Configuration" "90" \
    "SYNC_HYPR_CONFIGS:Sync Hypr configs" \
    "SETUP_SHELL_IMPROVEMENTS:Shell improvements (shared history)" \
    "INSTALL_CHEZMOI:chezmoi dotfiles manager" \
    "INSTALL_AGE:Age encryption" \
    "SETUP_DOTFILES_MANAGEMENT:Dotfiles management" \
    "SETUP_DEV_PGPASS:Dev .pgpass via 1Password" \
    "SETUP_SSH_KEYS:SSH keys sync via 1Password" \
    "GENERATE_REMMINA_CONNECTIONS:Generate Remmina RDP connections from 1Password" \
    "FIX_CURSOR_INPUT_METHOD:Fix Cursor input method (BR keyboard support)" \
    "SETUP_GNOME_KEYRING:Setup Gnome Keyring (no Chrome password prompts)" \
    "SETUP_PTBR_KEYBOARD_LAYOUT:Configure US keyboard with PT-BR layout"
    
  # Only show Dell XPS category if detected or forced
  local hw_info
  hw_info=$(detect_hardware 2>/dev/null || echo "Unknown")
  
  # Show XPS menu if: hardware contains XPS, or FORCE_XPS is set, or is_xps_mode returns true
  if [[ "$hw_info" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]] || is_xps_mode; then
    show_menu_category "Dell XPS 13 Plus" "95" \
      "SETUP_DELL_XPS_9320:XPS 13 Plus optimizations (webcam, power)" \
      "SETUP_DUAL_KEYBOARD:Dual keyboard support (BR+US)"
  fi
  
  echo
  show_menu_controls
}

# Global counter for menu items
MENU_ITEM_COUNTER=0

# Show a menu category with options and group toggle
show_menu_category() {
  local category_name="$1"
  local group_number="$2"
  shift 2
  local options=("$@")
  
  # Show category title with toggle number
  echo -e "${CYAN}${BOLD}${group_number} - ${category_name}${NC}"
  
  # Calculate starting number for this group
  local start_num=$((group_number + 1))
  
  for option in "${options[@]}"; do
    local var_name="${option%%:*}"
    local display_name="${option#*:}"
    local value="${!var_name}"
    local status="✗"
    
    [[ "$value" == "true" ]] && status="✓"
    
    printf "  ${BOLD}%2d${NC}. %s %s\n" "$start_num" "$status" "$display_name"
    ((start_num++))
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
  echo -e "  ${CYAN}10,20,30...${NC} Toggle group   ${CYAN}11,12,21,22...${NC} Toggle item   ${CYAN}Enter${NC} Install"
  echo -e "  ${CYAN}a${NC} All   ${CYAN}n${NC} None   ${CYAN}r${NC} Recommended   ${CYAN}d${NC} Development   ${CYAN}m${NC} Minimal   ${CYAN}x${NC} Dell XPS"
  echo -e "  ${CYAN}h${NC} Hardware report   ${CYAN}dns${NC} DNS Safe Mode   ${CYAN}q${NC} Quit"
  
  if is_debug_mode; then
    echo -e "  ${YELLOW}DEBUG MODE ACTIVE${NC}"
  fi
  
  if is_1pass_test_mode; then
    echo -e "  ${CYAN}1PASSWORD TEST MODE${NC}"
  fi
  
  if is_remmina_test_mode; then
    echo -e "  ${CYAN}REMMINA DEBUG MODE${NC}"
  fi
  
  if is_windows_docker_mode; then
    echo -e "  ${CYAN}WINDOWS DOCKER MODE${NC}"
  fi
  
}

# Interactive menu loop
interactive_menu() {
  # Auto-detect Dell XPS on first run
  local hw_info
  hw_info=$(detect_hardware 2>/dev/null || echo "Unknown")
  
  if [[ "$hw_info" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
    echo -e "${YELLOW}🔍 Dell XPS detected - auto-enabling hardware optimizations...${NC}"
    SETUP_DELL_XPS_9320=true
    SETUP_DUAL_KEYBOARD=true
    echo -e "${GREEN}✓ XPS optimizations enabled${NC}"
    sleep 2
  fi
  
  while true; do
    show_menu
    
    echo
    echo -n "Choice: "
    read -r choice
    
    case "$choice" in
      ""|"enter")
        if start_installation; then
          break
        else
          local install_result=$?
          if [[ $install_result -eq 2 ]]; then
            # Return to menu - clear collected configuration
            unset GIT_USERNAME GIT_EMAIL SSH_KEY_NAME HYPR_DOTFILES_PATH ONEPASSWORD_ACCOUNT ONEPASSWORD_EMAIL
            # Continue to next iteration of the while loop
            continue
          else
            # Installation failed or cancelled
            break
          fi
        fi
        ;;
      "a")
        apply_profile "all"
        ;;
      "n")
        apply_profile "none"
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
      "dns")
        if [[ "${DNS_SAFE_MODE:-true}" == "true" ]]; then
          DNS_SAFE_MODE=false
          echo -e "${YELLOW}⚠️  DNS Safe Mode DISABLED - may modify DNS if needed${NC}"
        else
          DNS_SAFE_MODE=true
          echo -e "${GREEN}✓ DNS Safe Mode ENABLED - will not modify DNS${NC}"
        fi
        echo -e "Current status: ${DNS_SAFE_MODE:-true}"
        sleep 2
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

# Apply configuration profile
apply_profile() {
  local profile="$1"
  
  case "$profile" in
    "all")
      # Select all options
      INSTALL_GOOGLE_CHROME=true
      INSTALL_FIREFOX=true
      INSTALL_COPYQ=true
      INSTALL_DROPBOX=true
      INSTALL_AWS_VPN=true
      INSTALL_POSTMAN=true
      INSTALL_REMMINA=true
      INSTALL_ESPANSO=true
      INSTALL_NANO=true
      INSTALL_MICRO=true
      INSTALL_KATE=true
      INSTALL_SLACK=true
      INSTALL_TEAMS=true
      INSTALL_JB_TOOLBOX=true
      INSTALL_JB_RIDER=true
      INSTALL_JB_DATAGRIP=true
      INSTALL_CURSOR=true
      INSTALL_VSCODE=true
      INSTALL_WINDSURF=true
      INSTALL_MISE_RUNTIMES=true
      INSTALL_CLAUDE_CODE=true
      INSTALL_CODEX_CLI=true
      INSTALL_GEMINI_CLI=true
      INSTALL_WINDOWS_DOCKER=true
      INSTALL_WINAPPS_LAUNCHER=true
      SYNC_HYPR_CONFIGS=true
      INSTALL_CHEZMOI=true
      INSTALL_AGE=true
      SETUP_DOTFILES_MANAGEMENT=true
      SETUP_DEV_PGPASS=true
      SETUP_DELL_XPS_9320=true
      SETUP_DUAL_KEYBOARD=true
      GENERATE_REMMINA_CONNECTIONS=true
      FIX_CURSOR_INPUT_METHOD=true
      SETUP_GNOME_KEYRING=false
      ;;
    "none")
      # Disable all options
      INSTALL_GOOGLE_CHROME=false
      INSTALL_FIREFOX=false
      INSTALL_COPYQ=false
      INSTALL_DROPBOX=false
      INSTALL_AWS_VPN=false
      INSTALL_POSTMAN=false
      INSTALL_REMMINA=false
      INSTALL_ESPANSO=false
      INSTALL_NANO=false
      INSTALL_MICRO=false
      INSTALL_KATE=false
      INSTALL_SLACK=false
      INSTALL_TEAMS=false
      INSTALL_JB_TOOLBOX=false
      INSTALL_JB_RIDER=false
      INSTALL_JB_DATAGRIP=false
      INSTALL_CURSOR=false
      INSTALL_VSCODE=false
      INSTALL_WINDSURF=false
      INSTALL_MISE_RUNTIMES=false
      INSTALL_CLAUDE_CODE=false
      INSTALL_CODEX_CLI=false
      INSTALL_GEMINI_CLI=false
      INSTALL_WINDOWS_DOCKER=false
      INSTALL_WINAPPS_LAUNCHER=false
      SYNC_HYPR_CONFIGS=false
      SETUP_SHELL_IMPROVEMENTS=false
      INSTALL_CHEZMOI=false
      INSTALL_AGE=false
      SETUP_DOTFILES_MANAGEMENT=false
      SETUP_DEV_PGPASS=false
      SETUP_SSH_KEYS=false
      SETUP_PTBR_KEYBOARD_LAYOUT=false
      SETUP_DELL_XPS_9320=false
      SETUP_DUAL_KEYBOARD=false
      GENERATE_REMMINA_CONNECTIONS=false
      FIX_CURSOR_INPUT_METHOD=false
      SETUP_GNOME_KEYRING=false
      echo -e "${RED}✗ All options disabled - select items individually${NC}"
      ;;
    "recommended")
      # Reset all first
      INSTALL_GOOGLE_CHROME=true
      INSTALL_FIREFOX=false
      INSTALL_COPYQ=true
      INSTALL_DROPBOX=true
      INSTALL_AWS_VPN=false
      INSTALL_POSTMAN=false
      INSTALL_REMMINA=false
      INSTALL_ESPANSO=false
      INSTALL_NANO=true
      INSTALL_MICRO=false
      INSTALL_KATE=false
      INSTALL_SLACK=false
      INSTALL_TEAMS=false
      INSTALL_JB_TOOLBOX=false
      INSTALL_JB_RIDER=false
      INSTALL_JB_DATAGRIP=false
      INSTALL_CURSOR=false
      INSTALL_VSCODE=true
      INSTALL_WINDSURF=false
      INSTALL_MISE_RUNTIMES=true
      INSTALL_CLAUDE_CODE=true
      INSTALL_CODEX_CLI=false
      INSTALL_GEMINI_CLI=false
      INSTALL_WINDOWS_DOCKER=false
      INSTALL_WINAPPS_LAUNCHER=false
      SYNC_HYPR_CONFIGS=true
      INSTALL_CHEZMOI=false
      INSTALL_AGE=false
      SETUP_DOTFILES_MANAGEMENT=false
      SETUP_DEV_PGPASS=false
      SETUP_DELL_XPS_9320=false
      SETUP_DUAL_KEYBOARD=false
      GENERATE_REMMINA_CONNECTIONS=false
      FIX_CURSOR_INPUT_METHOD=false
      SETUP_PTBR_KEYBOARD_LAYOUT=true
      ;;
    "development")
      INSTALL_GOOGLE_CHROME=true
      INSTALL_FIREFOX=true
      INSTALL_COPYQ=true
      INSTALL_DROPBOX=true
      INSTALL_AWS_VPN=true
      INSTALL_POSTMAN=true
      INSTALL_REMMINA=true
      INSTALL_ESPANSO=false
      INSTALL_NANO=true
      INSTALL_MICRO=true
      INSTALL_KATE=false
      INSTALL_SLACK=false
      INSTALL_TEAMS=false
      INSTALL_JB_TOOLBOX=true
      INSTALL_JB_RIDER=true
      INSTALL_JB_DATAGRIP=true
      INSTALL_CURSOR=true
      INSTALL_VSCODE=true
      INSTALL_WINDSURF=true
      INSTALL_MISE_RUNTIMES=true
      INSTALL_CLAUDE_CODE=true
      INSTALL_CODEX_CLI=true
      INSTALL_GEMINI_CLI=true
      SYNC_HYPR_CONFIGS=true
      INSTALL_CHEZMOI=true
      INSTALL_AGE=true
      SETUP_DOTFILES_MANAGEMENT=true
      SETUP_DEV_PGPASS=true
      SETUP_DELL_XPS_9320=false
      SETUP_DUAL_KEYBOARD=false
      GENERATE_REMMINA_CONNECTIONS=true
      FIX_CURSOR_INPUT_METHOD=true
      SETUP_PTBR_KEYBOARD_LAYOUT=true
      ;;
    "minimal")
      # Deselect all options
      INSTALL_GOOGLE_CHROME=false
      INSTALL_FIREFOX=false
      INSTALL_COPYQ=false
      INSTALL_DROPBOX=false
      INSTALL_AWS_VPN=false
      INSTALL_POSTMAN=false
      INSTALL_REMMINA=false
      INSTALL_ESPANSO=false
      INSTALL_NANO=false
      INSTALL_MICRO=false
      INSTALL_KATE=false
      INSTALL_SLACK=false
      INSTALL_TEAMS=false
      INSTALL_JB_TOOLBOX=false
      INSTALL_JB_RIDER=false
      INSTALL_JB_DATAGRIP=false
      INSTALL_CURSOR=false
      INSTALL_VSCODE=false
      INSTALL_WINDSURF=false
      INSTALL_MISE_RUNTIMES=false
      INSTALL_CLAUDE_CODE=false
      INSTALL_CODEX_CLI=false
      INSTALL_GEMINI_CLI=false
      INSTALL_WINDOWS_DOCKER=false
      INSTALL_WINAPPS_LAUNCHER=false
      SYNC_HYPR_CONFIGS=false
      INSTALL_CHEZMOI=false
      INSTALL_AGE=false
      SETUP_DOTFILES_MANAGEMENT=false
      SETUP_DEV_PGPASS=false
      SETUP_DELL_XPS_9320=false
      SETUP_DUAL_KEYBOARD=false
      GENERATE_REMMINA_CONNECTIONS=false
      ;;
    "dell-xps")
      # Enable Dell XPS specific configurations
      SETUP_DELL_XPS_9320=true
      SETUP_DUAL_KEYBOARD=true
      # Also apply recommended profile
      INSTALL_GOOGLE_CHROME=true
      INSTALL_FIREFOX=false
      INSTALL_COPYQ=true
      INSTALL_DROPBOX=true
      INSTALL_AWS_VPN=false
      INSTALL_POSTMAN=false
      INSTALL_REMMINA=false
      INSTALL_ESPANSO=false
      INSTALL_NANO=true
      INSTALL_MICRO=false
      INSTALL_KATE=false
      INSTALL_SLACK=false
      INSTALL_TEAMS=false
      INSTALL_JB_TOOLBOX=false
      INSTALL_JB_RIDER=false
      INSTALL_JB_DATAGRIP=false
      INSTALL_CURSOR=false
      INSTALL_VSCODE=true
      INSTALL_WINDSURF=false
      INSTALL_MISE_RUNTIMES=true
      INSTALL_CLAUDE_CODE=true
      INSTALL_CODEX_CLI=false
      INSTALL_GEMINI_CLI=false
      INSTALL_WINDOWS_DOCKER=false
      INSTALL_WINAPPS_LAUNCHER=false
      SYNC_HYPR_CONFIGS=true
      INSTALL_CHEZMOI=false
      INSTALL_AGE=false
      SETUP_DOTFILES_MANAGEMENT=false
      SETUP_DEV_PGPASS=false
      GENERATE_REMMINA_CONNECTIONS=false
      echo -e "${GREEN}✓ Dell XPS profile applied - hardware optimizations enabled${NC}"
      ;;
    *)
      echo "Unknown profile: $profile"
      return 1
      ;;
  esac
  
  echo -e "${GREEN}✓ Profile '$profile' applied${NC}"
  sleep 1
  return 0
}

# ======================================
# GROUP TOGGLE FUNCTIONS
# ======================================

# Toggle Web Browsers group
toggle_web_browsers_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_GOOGLE_CHROME" "INSTALL_FIREFOX")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_GOOGLE_CHROME=false
    INSTALL_FIREFOX=false
    echo -e "${YELLOW}✗ Web Browsers group disabled${NC}"
  else
    INSTALL_GOOGLE_CHROME=true
    INSTALL_FIREFOX=true
    echo -e "${GREEN}✓ Web Browsers group enabled${NC}"
  fi
}

# Toggle Productivity Tools group
toggle_productivity_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_COPYQ" "INSTALL_DROPBOX" "INSTALL_AWS_VPN" "INSTALL_ESPANSO")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_COPYQ=false
    INSTALL_DROPBOX=false
    INSTALL_AWS_VPN=false
    INSTALL_ESPANSO=false
    echo -e "${YELLOW}✗ Productivity Tools group disabled${NC}"
  else
    INSTALL_COPYQ=true
    INSTALL_DROPBOX=true
    INSTALL_AWS_VPN=true
    INSTALL_ESPANSO=true
    echo -e "${GREEN}✓ Productivity Tools group enabled${NC}"
  fi
}

# Toggle Development Tools group
toggle_development_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_POSTMAN" "INSTALL_REMMINA" "INSTALL_MISE_RUNTIMES")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_POSTMAN=false
    INSTALL_REMMINA=false
    INSTALL_MISE_RUNTIMES=false
    echo -e "${YELLOW}✗ Development Tools group disabled${NC}"
  else
    INSTALL_POSTMAN=true
    INSTALL_REMMINA=true
    INSTALL_MISE_RUNTIMES=true
    echo -e "${GREEN}✓ Development Tools group enabled${NC}"
  fi
}

# Toggle Text Editors group
toggle_text_editors_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_NANO" "INSTALL_KATE")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_NANO=false
    INSTALL_KATE=false
    echo -e "${YELLOW}✗ Text Editors group disabled${NC}"
  else
    INSTALL_NANO=true
    INSTALL_KATE=true
    echo -e "${GREEN}✓ Text Editors group enabled${NC}"
  fi
}

# Toggle Code Editors & IDEs group
toggle_code_editors_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_VSCODE" "INSTALL_CURSOR" "INSTALL_WINDSURF" "INSTALL_JB_TOOLBOX" "INSTALL_JB_RIDER" "INSTALL_JB_DATAGRIP")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_VSCODE=false
    INSTALL_CURSOR=false
    INSTALL_WINDSURF=false
    INSTALL_JB_TOOLBOX=false
    INSTALL_JB_RIDER=false
    INSTALL_JB_DATAGRIP=false
    echo -e "${YELLOW}✗ Code Editors & IDEs group disabled${NC}"
  else
    INSTALL_VSCODE=true
    INSTALL_CURSOR=true
    INSTALL_WINDSURF=true
    INSTALL_JB_TOOLBOX=true
    INSTALL_JB_RIDER=true
    INSTALL_JB_DATAGRIP=true
    echo -e "${GREEN}✓ Code Editors & IDEs group enabled${NC}"
  fi
}

# Toggle Communication group
toggle_communication_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_SLACK" "INSTALL_TEAMS")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_SLACK=false
    INSTALL_TEAMS=false
    echo -e "${YELLOW}✗ Communication group disabled${NC}"
  else
    INSTALL_SLACK=true
    INSTALL_TEAMS=true
    echo -e "${GREEN}✓ Communication group enabled${NC}"
  fi
}

# Toggle AI & CLI Tools group
toggle_ai_cli_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_CLAUDE_CODE" "INSTALL_CODEX_CLI" "INSTALL_GEMINI_CLI")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_CLAUDE_CODE=false
    INSTALL_CODEX_CLI=false
    INSTALL_GEMINI_CLI=false
    echo -e "${YELLOW}✗ AI & CLI Tools group disabled${NC}"
  else
    INSTALL_CLAUDE_CODE=true
    INSTALL_CODEX_CLI=true
    INSTALL_GEMINI_CLI=true
    echo -e "${GREEN}✓ AI & CLI Tools group enabled${NC}"
  fi
}

# Toggle Virtual Environments group
toggle_virtual_env_group() {
  local current_state
  current_state=$(check_group_state "INSTALL_WINDOWS_DOCKER" "INSTALL_WINAPPS_LAUNCHER")
  
  if [[ "$current_state" == "all_true" ]]; then
    INSTALL_WINDOWS_DOCKER=false
    INSTALL_WINAPPS_LAUNCHER=false
    echo -e "${YELLOW}✗ Virtual Environments group disabled${NC}"
  else
    INSTALL_WINDOWS_DOCKER=true
    INSTALL_WINAPPS_LAUNCHER=true
    echo -e "${GREEN}✓ Virtual Environments group enabled${NC}"
  fi
}

# Toggle System Configuration group
toggle_system_config_group() {
  local current_state
  current_state=$(check_group_state "SYNC_HYPR_CONFIGS" "SETUP_SHELL_IMPROVEMENTS" "INSTALL_CHEZMOI" "INSTALL_AGE" "SETUP_DOTFILES_MANAGEMENT" "SETUP_DEV_PGPASS" "SETUP_SSH_KEYS" "GENERATE_REMMINA_CONNECTIONS" "FIX_CURSOR_INPUT_METHOD" "SETUP_GNOME_KEYRING" "SETUP_PTBR_KEYBOARD_LAYOUT")
  
  if [[ "$current_state" == "all_true" ]]; then
    SYNC_HYPR_CONFIGS=false
    SETUP_SHELL_IMPROVEMENTS=false
    INSTALL_CHEZMOI=false
    INSTALL_AGE=false
    SETUP_DOTFILES_MANAGEMENT=false
    SETUP_DEV_PGPASS=false
    SETUP_SSH_KEYS=false
    GENERATE_REMMINA_CONNECTIONS=false
    FIX_CURSOR_INPUT_METHOD=false
    SETUP_GNOME_KEYRING=false
    SETUP_PTBR_KEYBOARD_LAYOUT=false
    echo -e "${YELLOW}✗ System Configuration group disabled${NC}"
  else
    SYNC_HYPR_CONFIGS=true
    SETUP_SHELL_IMPROVEMENTS=true
    INSTALL_CHEZMOI=true
    INSTALL_AGE=true
    SETUP_DOTFILES_MANAGEMENT=true
    SETUP_DEV_PGPASS=true
    SETUP_SSH_KEYS=true
    GENERATE_REMMINA_CONNECTIONS=true
    FIX_CURSOR_INPUT_METHOD=true
    SETUP_GNOME_KEYRING=true
    SETUP_PTBR_KEYBOARD_LAYOUT=true
    echo -e "${GREEN}✓ System Configuration group enabled${NC}"
  fi
}

# Toggle Dell XPS group
toggle_dell_xps_group() {
  local current_state
  current_state=$(check_group_state "SETUP_DELL_XPS_9320" "SETUP_DUAL_KEYBOARD")
  
  if [[ "$current_state" == "all_true" ]]; then
    SETUP_DELL_XPS_9320=false
    SETUP_DUAL_KEYBOARD=false
    echo -e "${YELLOW}✗ Dell XPS group disabled${NC}"
  else
    SETUP_DELL_XPS_9320=true
    SETUP_DUAL_KEYBOARD=true
    echo -e "${GREEN}✓ Dell XPS group enabled${NC}"
  fi
}

# Helper function to check group state
check_group_state() {
  local all_true=true
  local all_false=true
  
  for var in "$@"; do
    if [[ "${!var}" == "true" ]]; then
      all_false=false
    else
      all_true=false
    fi
  done
  
  if [[ "$all_true" == "true" ]]; then
    echo "all_true"
  elif [[ "$all_false" == "true" ]]; then
    echo "all_false"
  else
    echo "mixed"
  fi
}

# Toggle configuration option
toggle_option() {
  local choice="$1"
  
  case "$choice" in
    # Group toggles
    10) toggle_web_browsers_group ;;
    20) toggle_productivity_group ;;
    30) toggle_development_group ;;
    40) toggle_text_editors_group ;;
    50) toggle_code_editors_group ;;
    60) toggle_communication_group ;;
    70) toggle_ai_cli_group ;;
    80) toggle_virtual_env_group ;;
    90) toggle_system_config_group ;;
    95) toggle_dell_xps_group ;;
    
    # Individual toggles
    0) INSTALL_GOOGLE_CHROME=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true) ;;
    1) INSTALL_FIREFOX=$([ "$INSTALL_FIREFOX" == true ] && echo false || echo true) ;;
    2) INSTALL_COPYQ=$([ "$INSTALL_COPYQ" == true ] && echo false || echo true) ;;
    3) INSTALL_DROPBOX=$([ "$INSTALL_DROPBOX" == true ] && echo false || echo true) ;;
    4) INSTALL_AWS_VPN=$([ "$INSTALL_AWS_VPN" == true ] && echo false || echo true) ;;
    5) INSTALL_POSTMAN=$([ "$INSTALL_POSTMAN" == true ] && echo false || echo true) ;;
    6) INSTALL_REMMINA=$([ "$INSTALL_REMMINA" == true ] && echo false || echo true) ;;
    7) INSTALL_ESPANSO=$([ "$INSTALL_ESPANSO" == true ] && echo false || echo true) ;;
    8) INSTALL_NANO=$([ "$INSTALL_NANO" == true ] && echo false || echo true) ;;
    9) INSTALL_KATE=$([ "$INSTALL_KATE" == true ] && echo false || echo true) ;;
    11) INSTALL_SLACK=$([ "$INSTALL_SLACK" == true ] && echo false || echo true) ;;
    12) INSTALL_TEAMS=$([ "$INSTALL_TEAMS" == true ] && echo false || echo true) ;;
    13) INSTALL_JB_TOOLBOX=$([ "$INSTALL_JB_TOOLBOX" == true ] && echo false || echo true) ;;
    14) INSTALL_JB_RIDER=$([ "$INSTALL_JB_TOOLBOX" == true ] && echo false || echo true) ;;
    15) INSTALL_JB_DATAGRIP=$([ "$INSTALL_JB_DATAGRIP" == true ] && echo false || echo true) ;;
    16) INSTALL_CURSOR=$([ "$INSTALL_CURSOR" == true ] && echo false || echo true) ;;
    17) INSTALL_VSCODE=$([ "$INSTALL_VSCODE" == true ] && echo false || echo true) ;;
    18) INSTALL_WINDSURF=$([ "$INSTALL_WINDSURF" == true ] && echo false || echo true) ;;
    19) INSTALL_MISE_RUNTIMES=$([ "$INSTALL_MISE_RUNTIMES" == true ] && echo false || echo true) ;;
    21) INSTALL_CLAUDE_CODE=$([ "$INSTALL_CLAUDE_CODE" == true ] && echo false || echo true) ;;
    22) INSTALL_CODEX_CLI=$([ "$INSTALL_CODEX_CLI" == true ] && echo false || echo true) ;;
    23) INSTALL_GEMINI_CLI=$([ "$INSTALL_GEMINI_CLI" == true ] && echo false || echo true) ;;
    24) INSTALL_WINDOWS_DOCKER=$([ "$INSTALL_WINDOWS_DOCKER" == true ] && echo false || echo true) ;;
    25) INSTALL_WINAPPS_LAUNCHER=$([ "$INSTALL_WINAPPS_LAUNCHER" == true ] && echo false || echo true) ;;
    26) SYNC_HYPR_CONFIGS=$([ "$SYNC_HYPR_CONFIGS" == true ] && echo false || echo true) ;;
    27) SETUP_SHELL_IMPROVEMENTS=$([ "$SETUP_SHELL_IMPROVEMENTS" == true ] && echo false || echo true) ;;
    28) INSTALL_CHEZMOI=$([ "$INSTALL_CHEZMOI" == true ] && echo false || echo true) ;;
    29) INSTALL_AGE=$([ "$INSTALL_AGE" == true ] && echo false || echo true) ;;
    31) SETUP_DOTFILES_MANAGEMENT=$([ "$SETUP_DOTFILES_MANAGEMENT" == true ] && echo false || echo true) ;;
    32) SETUP_DEV_PGPASS=$([ "$SETUP_DEV_PGPASS" == true ] && echo false || echo true) ;;
    33) SETUP_SSH_KEYS=$([ "$SETUP_SSH_KEYS" == true ] && echo false || echo true) ;;
    34) GENERATE_REMMINA_CONNECTIONS=$([ "$GENERATE_REMMINA_CONNECTIONS" == true ] && echo false || echo true) ;;
    35) FIX_CURSOR_INPUT_METHOD=$([ "$FIX_CURSOR_INPUT_METHOD" == true ] && echo false || echo true) ;;
    36) SETUP_GNOME_KEYRING=$([ "$SETUP_GNOME_KEYRING" == true ] && echo false || echo true) ;;
    37) SETUP_PTBR_KEYBOARD_LAYOUT=$([ "$SETUP_PTBR_KEYBOARD_LAYOUT" == true ] && echo false || echo true) ;;
    38) SETUP_DELL_XPS_9320=$([ "$SETUP_DELL_XPS_9320" == true ] && echo false || echo true) ;;
    39) SETUP_DUAL_KEYBOARD=$([ "$SETUP_DUAL_KEYBOARD" == true ] && echo false || echo true) ;;
    *)
      return 1
      ;;
  esac
  
  return 0
}

# ======================================
# INSTALLATION ORCHESTRATION
# ======================================

# Main installation function
start_installation() {
  echo
  info "Starting installation with current configuration..."
  
  # Collect and confirm all user data before installation
  collect_and_confirm_user_data
  local confirmation_result=$?
  info "Confirmation result: $confirmation_result"
  
  if [[ $confirmation_result -eq 2 ]]; then
    # User wants to return to menu
    info "User wants to return to menu"
    return 2
  elif [[ $confirmation_result -ne 0 ]]; then
    info "Installation cancelled by user"
    return 1
  fi
  
  # Initialize logging
  init_logging
  
  # Pre-installation checks
  perform_pre_installation_checks
  
  # Setup environment
  setup_installation_environment
  
  # Execute modules
  execute_installation_modules
  
  # Execute any pending sudo commands
  force_sudo_batch
  
  # Post-installation tasks
  perform_post_installation_tasks
  
  # Show final report
  show_final_report
}

# Collect and confirm all user data before installation
collect_and_confirm_user_data() {
  echo
  echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  ${BOLD}Configuration Confirmation${NC}${CYAN} ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════╝${NC}"
  echo
  echo "Please review and confirm the following configuration:"
  echo
  
  # Collect Git configuration
  collect_git_config
  
  # Collect SSH key information if SSH sync is enabled
  if [[ "${SETUP_SSH_KEYS:-false}" == "true" ]]; then
    collect_ssh_config
  fi
  
  # Collect Hyprland dotfiles path if sync is enabled
  if [[ "${SYNC_HYPR_CONFIGS:-false}" == "true" ]]; then
    collect_hypr_config
  fi
  
  # Collect 1Password configuration if needed
  if module_enabled "1password"; then
    collect_1password_config
  fi
  
  # Show all collected data for confirmation
  show_configuration_summary
  
  # Ask for confirmation
  echo
  echo -e "${YELLOW}Do you want to proceed with this configuration?${NC}"
  echo -n "Type 'yes', 'y', or press ENTER to continue, 'no' to modify: "
  read -r confirmation
  
  # Normalize confirmation input
  local normalized_confirmation
  normalized_confirmation=$(echo "$confirmation" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
  
  if [[ "$normalized_confirmation" == "yes" ]] || [[ "$normalized_confirmation" == "y" ]] || [[ -z "$normalized_confirmation" ]]; then
    success "Configuration confirmed. Starting installation..."
    return 0
  else
    info "Returning to menu to modify settings..."
    return 2  # Special return code to indicate return to menu
  fi
}

# Collect Git configuration
collect_git_config() {
  echo -e "${BOLD}Git Configuration:${NC}"
  
  # Try to read existing Git config
  local existing_username
  local existing_email
  
  if command_exists git; then
    existing_username=$(git config --global user.name 2>/dev/null || echo "")
    existing_email=$(git config --global user.email 2>/dev/null || echo "")
  fi
  
  # Git username
  if [[ -z "${GIT_USERNAME:-}" ]]; then
    if [[ -n "$existing_username" ]]; then
      echo -e "Git username: ${CYAN}${existing_username}${NC} (from existing .gitconfig)"
      echo -n "Press Enter to keep or type new username: "
      read -r new_username
      if [[ -n "$new_username" ]]; then
        GIT_USERNAME="$new_username"
        # Persist to disk
        git config --global user.name "$new_username"
        info "Git username updated to: $new_username"
      else
        GIT_USERNAME="$existing_username"
      fi
    else
      echo -n "Git username: "
      read -r GIT_USERNAME
      # Persist to disk
      git config --global user.name "$GIT_USERNAME"
      info "Git username set to: $GIT_USERNAME"
    fi
  else
    echo -e "Git username: ${CYAN}${GIT_USERNAME}${NC} (from environment)"
    echo -n "Press Enter to keep or type new username: "
    read -r new_username
    if [[ -n "$new_username" ]]; then
      GIT_USERNAME="$new_username"
      # Persist to disk
      git config --global user.name "$new_username"
      info "Git username updated to: $new_username"
    fi
  fi
  
  # Git email
  if [[ -z "${GIT_EMAIL:-}" ]]; then
    if [[ -n "$existing_email" ]]; then
      echo -e "Git email: ${CYAN}${existing_email}${NC} (from existing .gitconfig)"
      echo -n "Press Enter to keep or type new email: "
      read -r new_email
      if [[ -n "$new_email" ]]; then
        GIT_EMAIL="$new_email"
        # Persist to disk
        git config --global user.email "$new_email"
        info "Git email updated to: $new_email"
      else
        GIT_EMAIL="$existing_email"
      fi
    else
      echo -n "Git email: "
      read -r GIT_EMAIL
      # Persist to disk
      git config --global user.email "$GIT_EMAIL"
      info "Git email set to: $GIT_EMAIL"
    fi
  else
    echo -e "Git email: ${CYAN}${GIT_EMAIL}${NC} (from environment)"
    echo -n "Press Enter to keep or type new email: "
    read -r new_email
    if [[ -n "$new_email" ]]; then
      GIT_EMAIL="$new_email"
      # Persist to disk
      git config --global user.email "$new_email"
      info "Git email updated to: $new_email"
    fi
  fi
  
  echo
}

# Collect SSH configuration
collect_ssh_config() {
  echo -e "${BOLD}SSH Configuration:${NC}"
  
  # SSH key name in 1Password
  if [[ -z "${SSH_KEY_NAME:-}" ]]; then
    echo -n "SSH key name in 1Password: "
    read -r SSH_KEY_NAME
  else
    echo -e "SSH key name in 1Password: ${CYAN}${SSH_KEY_NAME}${NC} (from environment)"
  fi
  
  echo
}

# Collect Hyprland configuration
collect_hypr_config() {
  echo -e "${BOLD}Hyprland Configuration:${NC}"
  
  # Hyprland dotfiles path
  if [[ -z "${HYPR_DOTFILES_PATH:-}" ]]; then
    echo -n "Hyprland dotfiles path (default: ~/.config/hypr): "
    read -r HYPR_DOTFILES_PATH
    HYPR_DOTFILES_PATH="${HYPR_DOTFILES_PATH:-~/.config/hypr}"
  else
    echo -e "Hyprland dotfiles path: ${CYAN}${HYPR_DOTFILES_PATH}${NC} (from environment)"
  fi
  
  echo
}

# Collect 1Password configuration
collect_1password_config() {
  echo -e "${BOLD}1Password Configuration:${NC}"
  
  # Check if 1Password CLI is already authenticated (hybrid mode)
  if op account list >/dev/null 2>&1; then
    echo -e "1Password: ${CYAN}Already authenticated via desktop app${NC}"
    echo -e "Using hybrid integration mode (no additional config needed)"
    echo
    return 0
  fi
  
  # Only ask for credentials if not authenticated
  # 1Password account - use ONEPASSWORD_URL if available, clean format
  local onepass_url="${ONEPASSWORD_URL:-${ONEPASSWORD_ACCOUNT:-}}"
  if [[ -n "$onepass_url" ]]; then
    # Clean URL format
    onepass_url="${onepass_url#https://}"
    onepass_url="${onepass_url#http://}"
    onepass_url="${onepass_url%/}"
    echo -e "1Password account: ${CYAN}${onepass_url}${NC} (from configuration)"
    echo -n "Press ENTER to use this account, or type a different one: "
    read -r user_input
    if [[ -n "$user_input" ]]; then
      ONEPASSWORD_ACCOUNT="$user_input"
    else
      ONEPASSWORD_ACCOUNT="$onepass_url"
    fi
  else
    echo -n "1Password account (e.g., myteam.1password.com): "
    read -r ONEPASSWORD_ACCOUNT
  fi
  
  # 1Password email
  local onepass_email="${ONEPASSWORD_EMAIL:-}"
  if [[ -n "$onepass_email" ]]; then
    echo -e "1Password email: ${CYAN}${onepass_email}${NC} (from configuration)"
    echo -n "Press ENTER to use this email, or type a different one: "
    read -r user_email
    if [[ -n "$user_email" ]]; then
      ONEPASSWORD_EMAIL="$user_email"
    else
      ONEPASSWORD_EMAIL="$onepass_email"
    fi
  else
    echo -n "1Password email: "
    read -r ONEPASSWORD_EMAIL
  fi
  
  echo
}

# Show configuration summary
show_configuration_summary() {
  echo -e "${BOLD}Configuration Summary:${NC}"
  echo "================================"
  
  # Git config
  if [[ -n "${GIT_USERNAME:-}" ]] || [[ -n "${GIT_EMAIL:-}" ]]; then
    echo -e "Git username: ${CYAN}${GIT_USERNAME:-Not set}${NC}"
    echo -e "Git email: ${CYAN}${GIT_EMAIL:-Not set}${NC}"
  fi
  
  # SSH config
  if [[ "${SETUP_SSH_KEYS:-false}" == "true" ]]; then
    echo -e "SSH key name: ${CYAN}${SSH_KEY_NAME:-Not set}${NC}"
  fi
  
  # Hyprland config
  if [[ "${SYNC_HYPR_CONFIGS:-false}" == "true" ]]; then
    echo -e "Hyprland dotfiles: ${CYAN}${HYPR_DOTFILES_PATH:-Not set}${NC}"
  fi
  
  # 1Password config
  if module_enabled "1password"; then
    echo -e "1Password account: ${CYAN}${ONEPASSWORD_ACCOUNT:-Not set}${NC}"
    echo -e "1Password email: ${CYAN}${ONEPASSWORD_EMAIL:-Not set}${NC}"
  fi
  
  echo
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
  
  # DNS Safe Mode - don't modify DNS if enabled
  if [[ "${DNS_SAFE_MODE:-true}" == "true" ]]; then
    info "DNS Safe Mode enabled - will not modify DNS configuration"
    info "Using existing network configuration from the system"
    
    # Test if current DNS is working
    if command_exists nslookup; then
      if timeout 5 nslookup google.com >/dev/null 2>&1; then
        success "Current DNS configuration is working properly"
      else
        warn "Current DNS configuration may have issues, but DNS Safe Mode prevents modifications"
        warn "You can disable DNS Safe Mode if you need DNS fixes during installation"
      fi
    elif command_exists dig; then
      if timeout 5 dig google.com +short >/dev/null 2>&1; then
        success "Current DNS configuration is working properly"
      else
        warn "Current DNS configuration may have issues, but DNS Safe Mode prevents modifications"
        warn "You can disable DNS Safe Mode if you need DNS fixes during installation"
      fi
    else
      info "DNS testing tools not available, proceeding with current configuration"
    fi
  else
    info "DNS Safe Mode disabled - may modify DNS if needed"
    
    # Check if systemd-resolved is working properly before modifying DNS
    local dns_working=false
    
    # Test if systemd-resolved is managing DNS properly
    if command_exists resolvectl && resolvectl status >/dev/null 2>&1; then
      # Check if systemd-resolved is in managed mode and working
      if resolvectl status 2>/dev/null | grep -q "resolv.conf mode: managed" && \
         resolvectl status 2>/dev/null | grep -q "Current DNS Server:"; then
        dns_working=true
        info "systemd-resolved is working properly, skipping DNS modifications"
      fi
    fi
    
    # Setup temporary DNS only if systemd-resolved is not working and DNS_SERVERS is configured
    if [[ "$dns_working" == "false" ]] && [[ "${#DNS_SERVERS[@]}" -gt 0 ]] && [[ ! -f "/tmp/resolv.conf.backup" ]]; then
      info "Configuring temporary DNS..."
      add_sudo_command "cp /etc/resolv.conf /tmp/resolv.conf.backup"
      
      # Create DNS configuration
      local dns_config="/tmp/dns_config_$$"
      {
        echo "# Temporary DNS for installation"
        for dns in "${DNS_SERVERS[@]}"; do
          echo "nameserver $dns"
        done
      } > "$dns_config"
      
      add_sudo_command "cp $dns_config /etc/resolv.conf"
      add_sudo_command "rm -f $dns_config"
    fi
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
    if command -v setup_1password_complete >/dev/null 2>&1; then
      if ! setup_1password_complete; then
        warn "1Password configuration failed or was skipped"
        echo
        if ask_yes_no "Do you want to continue without 1Password integration?"; then
          info "Continuing without 1Password..."
        else
          err "Installation aborted due to 1Password configuration failure"
          exit 1
        fi
      fi
    else
      err "1Password module not loaded properly. Please run from the main directory."
      echo "Try: git clone https://github.com/takitani/exarch-install && cd exarch-install && ./install.sh"
      exit 1
    fi
  fi
  
  # SSH keys from 1Password
  if [[ "${SETUP_SSH_KEYS:-false}" == "true" ]]; then
    if command -v setup_ssh_keys_from_1password >/dev/null 2>&1; then
      setup_ssh_keys_from_1password || warn "SSH key setup failed or was skipped"
    else
      warn "SSH key function not available. Skipping SSH key configuration."
    fi
  fi
  
  # Remmina connections (standalone) - only if 1Password is available
  if module_enabled "remmina"; then
    # Check if 1Password CLI is available and configured
    if command_exists op; then
      # Test if 1Password is actually authenticated
      if timeout 5 op account list >/dev/null 2>&1 && timeout 5 op vault list >/dev/null 2>&1; then
        if command -v setup_remmina_connections_complete >/dev/null 2>&1; then
          if ! setup_remmina_connections_complete; then
            warn "Remmina configuration failed"
            echo "You can configure Remmina connections later using: ./helpers/1password-helper.sh"
          fi
        else
          warn "Remmina module not loaded. Skipping Remmina configuration."
        fi
      else
        info "1Password CLI not authenticated, skipping Remmina configuration"
        echo "Configure 1Password first, then run: ./helpers/1password-helper.sh"
      fi
    else
      info "1Password CLI not available, skipping Remmina configuration"
      echo "Install and configure 1Password first, then run: ./helpers/1password-helper.sh"
    fi
  fi
  
  
  # Dell XPS optimizations
  if module_enabled "dell-xps"; then
    setup_dell_xps_9320_complete
  fi
  
  # PipeWire camera support
  if [[ "${ENABLE_PIPEWIRE_CAMERA_MODULE:-true}" == "true" ]] && command -v setup_pipewire_camera >/dev/null 2>&1; then
    setup_pipewire_camera
  fi
  
  # Dotfiles management
  if module_enabled "dotfiles"; then
    setup_dotfiles_management_complete
  fi
  
  # Shell improvements
  if [[ "${SETUP_SHELL_IMPROVEMENTS:-false}" == "true" ]]; then
    setup_shell_improvements
  fi
  
  # Gnome Keyring setup
  if [[ "${SETUP_GNOME_KEYRING:-false}" == "true" ]]; then
    setup_gnome_keyring
  fi
  
  # PT-BR Keyboard Layout setup
  if [[ "${SETUP_PTBR_KEYBOARD_LAYOUT:-false}" == "true" ]]; then
    setup_ptbr_keyboard_layout
  fi
  
  # Windows Docker setup
  if [[ "${INSTALL_WINDOWS_DOCKER:-false}" == "true" ]]; then
    setup_windows_docker_complete
  fi
  
  # WinApps Launcher setup
  if [[ "${INSTALL_WINAPPS_LAUNCHER:-false}" == "true" ]]; then
    setup_winapps_launcher_complete
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
  
  # Restore DNS configuration only if we modified it (and DNS Safe Mode is disabled)
  if [[ -f "/tmp/resolv.conf.backup" ]] && [[ "${DNS_SAFE_MODE:-true}" != "true" ]]; then
    info "Restoring DNS configuration..."
    
    # Check if systemd-resolved is working properly now
    local dns_working=false
    if command_exists resolvectl && resolvectl status >/dev/null 2>&1; then
      if resolvectl status 2>/dev/null | grep -q "resolv.conf mode: managed" && \
         resolvectl status 2>/dev/null | grep -q "Current DNS Server:"; then
        dns_working=true
      fi
    fi
    
    if [[ "$dns_working" == "true" ]]; then
      info "systemd-resolved is working, removing backup and letting it manage DNS"
      sudo rm -f "/tmp/resolv.conf.backup"
    else
      info "Restoring original DNS configuration..."
      sudo mv /tmp/resolv.conf.backup /etc/resolv.conf
    fi
  elif [[ -f "/tmp/resolv.conf.backup" ]] && [[ "${DNS_SAFE_MODE:-true}" == "true" ]]; then
    info "DNS Safe Mode enabled - removing DNS backup file (no modifications were made)"
    sudo rm -f "/tmp/resolv.conf.backup"
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
  
  if [[ "${SETUP_GNOME_KEYRING:-false}" == "true" ]]; then
    echo "• Gnome Keyring configured - Chrome will no longer ask for password"
  fi
  
  if [[ "${SETUP_PTBR_KEYBOARD_LAYOUT:-false}" == "true" ]]; then
    echo "• PT-BR keyboard layout configured for US keyboards"
  fi
  
  echo "• Log files saved to: $LOG_DIR"
  
  if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo "• Review failed packages and install manually if needed"
  fi
  
  echo
  success "Setup completed successfully! 🎉"
}

# ======================================
# SHELL IMPROVEMENTS
# ======================================

# Configure shell improvements (shared history, etc)
setup_shell_improvements() {
  info "Configuring shell improvements..."
  
  local bashrc_file="$HOME/.bashrc"
  local backup_file="$bashrc_file.backup.$(date +%Y%m%d_%H%M%S)"
  
  # Check if improvements are already configured
  if grep -q "PROMPT_COMMAND.*history -a.*history -c.*history -r" "$bashrc_file" 2>/dev/null; then
    info "Shell improvements already configured"
    return 0
  fi
  
  # Backup .bashrc
  if [[ -f "$bashrc_file" ]]; then
    if backup_file "$bashrc_file" "$backup_file"; then
      info "Backup created: $backup_file"
    fi
  fi
  
  # Add shell improvements to .bashrc
  info "Adding shared history configuration to .bashrc..."
  
  cat >> "$bashrc_file" << 'EOF'

# ======================================
# SHELL IMPROVEMENTS (Added by Exarch Scripts)
# ======================================

# Configuração para histórico compartilhado em tempo real entre terminais
export HISTCONTROL=ignoredups:erasedups
export HISTSIZE=10000
export HISTFILESIZE=10000
shopt -s histappend

# Salva e recarrega o histórico após cada comando
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"
EOF
  
  if [[ $? -eq 0 ]]; then
    success "Shell improvements configured successfully"
    echo
    echo "Improvements added:"
    echo "• Shared command history between terminals"
    echo "• Increased history size (10,000 commands)"
    echo "• Automatic history synchronization"
    echo "• Duplicate command removal"
    echo
    echo "Note: Open a new terminal or run 'source ~/.bashrc' to apply changes"
  else
    err "Failed to configure shell improvements"
    return 1
  fi
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
  

  
  if is_ssh_test_mode; then
    test_ssh_mode
    exit $?
  fi
  
  if is_remmina_test_mode; then
    test_remmina_mode
    exit $?
  fi
  
  if is_windows_docker_mode; then
    test_windows_docker_mode
    exit $?
  fi
  
  # Always show interactive menu (even in debug mode)
  # unless specific test modes are active
  interactive_menu
}

# Test SSH key synchronization mode
test_ssh_mode() {
  echo
  echo -e "${CYAN}╔═══════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  ${BOLD}SSH Key Sync Test Mode${NC}${CYAN} ║${NC}"
  echo -e "${CYAN}╚═══════════════════════════════════════╗${NC}"
  echo
  
  # Enable SSH keys module for testing
  SETUP_SSH_KEYS=true
  
  echo "SSH Key Sync Test Mode"
  echo "======================"
  echo
  echo "This mode will:"
  echo "• Ask for the name of your SSH key in 1Password"
  echo "• Download and configure the SSH key"
  echo "• Set it as the main system key"
  echo "• Configure SSH agent"
  echo "• Create backups of existing keys"
  echo
  echo "Example key names: opiklocal, github-key, server-key, etc."
  echo
  
  if setup_ssh_keys_from_1password; then
    success "SSH key sync test completed successfully!"
    echo
    echo -e "${BOLD}Generated files:${NC}"
    echo "  • ~/.ssh/ (SSH directory with keys)"
    echo "  • Symlinks for standard key names (id_rsa, id_ed25519, etc.)"
    echo "  • SSH agent configuration in shell profile"
    echo
    echo "You can now use SSH with your synced key!"
    return 0
  else
    err "SSH key sync test failed"
    return 1
  fi
}

# Run main function
main "$@"