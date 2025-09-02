#!/usr/bin/env bash
# lib/config-manager.sh - Configuration management and .env handling

# Source core functions
[[ -f "$(dirname "${BASH_SOURCE[0]}")/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Default installation flags (can be overridden by config files or menu)
DEFAULT_INSTALL_GOOGLE_CHROME=true
DEFAULT_INSTALL_FIREFOX=true
DEFAULT_INSTALL_COPYQ=true
DEFAULT_INSTALL_DROPBOX=true
DEFAULT_INSTALL_AWS_VPN=true
DEFAULT_INSTALL_POSTMAN=true
DEFAULT_INSTALL_REMMINA=true
DEFAULT_INSTALL_ESPANSO=true
DEFAULT_INSTALL_NANO=true
DEFAULT_INSTALL_MICRO=true
DEFAULT_INSTALL_KATE=true
DEFAULT_INSTALL_SLACK=true
DEFAULT_INSTALL_TEAMS=true
DEFAULT_INSTALL_JB_TOOLBOX=false  # By default, install IDEs separately
DEFAULT_INSTALL_JB_RIDER=true
DEFAULT_INSTALL_JB_DATAGRIP=true
DEFAULT_INSTALL_CURSOR=true
DEFAULT_INSTALL_VSCODE=true
DEFAULT_INSTALL_WINDSURF=true
DEFAULT_INSTALL_MISE_RUNTIMES=true
DEFAULT_INSTALL_CLAUDE_CODE=true
DEFAULT_INSTALL_CODEX_CLI=true
DEFAULT_INSTALL_GEMINI_CLI=true
DEFAULT_SYNC_HYPR_CONFIGS=true
DEFAULT_SETUP_DELL_XPS_9320=false
DEFAULT_SETUP_DUAL_KEYBOARD=false
DEFAULT_SETUP_SHELL_IMPROVEMENTS=true
DEFAULT_INSTALL_CHEZMOI=true
DEFAULT_INSTALL_AGE=true
DEFAULT_SETUP_DOTFILES_MANAGEMENT=true
DEFAULT_SETUP_DEV_PGPASS=true
DEFAULT_SETUP_SSH_KEYS=true
DEFAULT_SETUP_REMMINA_CONNECTIONS=true
DEFAULT_ENABLE_REMMINA_MODULE=true
DEFAULT_GENERATE_REMMINA_CONNECTIONS=true
DEFAULT_FIX_CURSOR_INPUT_METHOD=false
DEFAULT_SETUP_GNOME_KEYRING=false

# Runtime defaults
DEFAULT_NODE="lts"
DEFAULT_DOTNET_DEFAULT="9"
EXTRA_DOTNET=("8")

# Directory defaults
DEFAULT_HYPR_SRC_DIR="$(pwd)/dotfiles/hypr"
DEFAULT_HYPRL_SRC_DIR="$(pwd)/dotfiles/hyprl"
DEFAULT_HYPR_DST_DIR="$HOME/.config/hypr"
DEFAULT_HYPRL_DST_DIR="$HOME/.config/hyprl"

# Load environment file if it exists
load_env_file() {
  local env_file="${1:-$(dirname "$0")/.env}"
  
  if [[ -f "$env_file" ]]; then
    info "Loading configuration from $env_file"
    # Source with error handling
    if source "$env_file"; then
      write_log "Successfully loaded .env file: $env_file"
      return 0
    else
      warn "Failed to load .env file: $env_file"
      return 1
    fi
  else
    info "No .env file found at $env_file (optional)"
    return 0
  fi
}

# Initialize all configuration variables with defaults
init_config_variables() {
  # Installation flags
  INSTALL_GOOGLE_CHROME=${INSTALL_GOOGLE_CHROME:-$DEFAULT_INSTALL_GOOGLE_CHROME}
  INSTALL_FIREFOX=${INSTALL_FIREFOX:-$DEFAULT_INSTALL_FIREFOX}
  INSTALL_COPYQ=${INSTALL_COPYQ:-$DEFAULT_INSTALL_COPYQ}
  INSTALL_DROPBOX=${INSTALL_DROPBOX:-$DEFAULT_INSTALL_DROPBOX}
  INSTALL_AWS_VPN=${INSTALL_AWS_VPN:-$DEFAULT_INSTALL_AWS_VPN}
  INSTALL_POSTMAN=${INSTALL_POSTMAN:-$DEFAULT_INSTALL_POSTMAN}
  INSTALL_REMMINA=${INSTALL_REMMINA:-$DEFAULT_INSTALL_REMMINA}
  INSTALL_ESPANSO=${INSTALL_ESPANSO:-$DEFAULT_INSTALL_ESPANSO}
  INSTALL_NANO=${INSTALL_NANO:-$DEFAULT_INSTALL_NANO}
  INSTALL_MICRO=${INSTALL_MICRO:-$DEFAULT_INSTALL_MICRO}
  INSTALL_KATE=${INSTALL_KATE:-$DEFAULT_INSTALL_KATE}
  INSTALL_SLACK=${INSTALL_SLACK:-$DEFAULT_INSTALL_SLACK}
  INSTALL_TEAMS=${INSTALL_TEAMS:-$DEFAULT_INSTALL_TEAMS}
  INSTALL_JB_TOOLBOX=${INSTALL_JB_TOOLBOX:-$DEFAULT_INSTALL_JB_TOOLBOX}
  INSTALL_JB_RIDER=${INSTALL_JB_RIDER:-$DEFAULT_INSTALL_JB_RIDER}
  INSTALL_JB_DATAGRIP=${INSTALL_JB_DATAGRIP:-$DEFAULT_INSTALL_JB_DATAGRIP}
  INSTALL_CURSOR=${INSTALL_CURSOR:-$DEFAULT_INSTALL_CURSOR}
  INSTALL_VSCODE=${INSTALL_VSCODE:-$DEFAULT_INSTALL_VSCODE}
  INSTALL_WINDSURF=${INSTALL_WINDSURF:-$DEFAULT_INSTALL_WINDSURF}
  INSTALL_MISE_RUNTIMES=${INSTALL_MISE_RUNTIMES:-$DEFAULT_INSTALL_MISE_RUNTIMES}
  INSTALL_CLAUDE_CODE=${INSTALL_CLAUDE_CODE:-$DEFAULT_INSTALL_CLAUDE_CODE}
  INSTALL_CODEX_CLI=${INSTALL_CODEX_CLI:-$DEFAULT_INSTALL_CODEX_CLI}
  INSTALL_GEMINI_CLI=${INSTALL_GEMINI_CLI:-$DEFAULT_INSTALL_GEMINI_CLI}
  SYNC_HYPR_CONFIGS=${SYNC_HYPR_CONFIGS:-$DEFAULT_SYNC_HYPR_CONFIGS}
  SETUP_SSH_KEYS=${SETUP_SSH_KEYS:-$DEFAULT_SETUP_SSH_KEYS}
  
  # Auto-enable XPS options if XPS hardware is detected
  local hw_info
  hw_info=$(detect_hardware 2>/dev/null || echo "Unknown")
  
  if [[ "$hw_info" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
    SETUP_DELL_XPS_9320=${SETUP_DELL_XPS_9320:-true}
    SETUP_DUAL_KEYBOARD=${SETUP_DUAL_KEYBOARD:-true}
  else
    SETUP_DELL_XPS_9320=${SETUP_DELL_XPS_9320:-$DEFAULT_SETUP_DELL_XPS_9320}
    SETUP_DUAL_KEYBOARD=${SETUP_DUAL_KEYBOARD:-$DEFAULT_SETUP_DUAL_KEYBOARD}
  fi
  SETUP_SHELL_IMPROVEMENTS=${SETUP_SHELL_IMPROVEMENTS:-$DEFAULT_SETUP_SHELL_IMPROVEMENTS}
  INSTALL_CHEZMOI=${INSTALL_CHEZMOI:-$DEFAULT_INSTALL_CHEZMOI}
  INSTALL_AGE=${INSTALL_AGE:-$DEFAULT_INSTALL_AGE}
  SETUP_DOTFILES_MANAGEMENT=${SETUP_DOTFILES_MANAGEMENT:-$DEFAULT_SETUP_DOTFILES_MANAGEMENT}
  SETUP_DEV_PGPASS=${SETUP_DEV_PGPASS:-$DEFAULT_SETUP_DEV_PGPASS}
  SETUP_REMMINA_CONNECTIONS=${SETUP_REMMINA_CONNECTIONS:-$DEFAULT_SETUP_REMMINA_CONNECTIONS}
  ENABLE_REMMINA_MODULE=${ENABLE_REMMINA_MODULE:-$DEFAULT_ENABLE_REMMINA_MODULE}
  GENERATE_REMMINA_CONNECTIONS=${GENERATE_REMMINA_CONNECTIONS:-$DEFAULT_GENERATE_REMMINA_CONNECTIONS}
  FIX_CURSOR_INPUT_METHOD=${FIX_CURSOR_INPUT_METHOD:-$DEFAULT_FIX_CURSOR_INPUT_METHOD}
  SETUP_GNOME_KEYRING=${SETUP_GNOME_KEYRING:-$DEFAULT_SETUP_GNOME_KEYRING}
  
  # Runtime versions
  DEFAULT_NODE=${DEFAULT_NODE:-$DEFAULT_NODE}
  DEFAULT_DOTNET_DEFAULT=${DEFAULT_DOTNET_DEFAULT:-$DEFAULT_DOTNET_DEFAULT}
  
  # Directories
  HYPR_SRC_DIR=${HYPR_SRC_DIR:-$DEFAULT_HYPR_SRC_DIR}
  HYPRL_SRC_DIR=${HYPRL_SRC_DIR:-$DEFAULT_HYPRL_SRC_DIR}
  HYPR_DST_DIR=${HYPR_DST_DIR:-$DEFAULT_HYPR_DST_DIR}
  HYPRL_DST_DIR=${HYPRL_DST_DIR:-$DEFAULT_HYPRL_DST_DIR}
  
  write_log "Configuration variables initialized"
}

# Validate configuration
validate_config() {
  local errors=()
  
  # Check runtime versions
  if [[ ! "$DEFAULT_NODE" =~ ^(lts|[0-9]+)$ ]]; then
    errors+=("Invalid Node.js version: $DEFAULT_NODE")
  fi
  
  if [[ ! "$DEFAULT_DOTNET_DEFAULT" =~ ^[0-9]+$ ]]; then
    errors+=("Invalid .NET version: $DEFAULT_DOTNET_DEFAULT")
  fi
  
  # Check directory paths exist for source directories (if sync is enabled)
  # Skip this check in test modes
  if [[ "$SYNC_HYPR_CONFIGS" == true ]] && [[ "${TEST_1PASS_MODE:-false}" == false ]] && [[ "${TEST_REMMINA_MODE:-false}" == false ]]; then
    if [[ ! -d "$HYPR_SRC_DIR" ]]; then
      warn "Hypr source directory not found: $HYPR_SRC_DIR (will skip sync)"
      # Don't disable automatically, just warn
    fi
    if [[ ! -d "$HYPRL_SRC_DIR" ]]; then
      warn "Hyprl source directory not found: $HYPRL_SRC_DIR (will skip sync)"
      # Don't disable automatically, just warn
    fi
  fi
  
  # Report validation errors
  if [[ ${#errors[@]} -gt 0 ]]; then
    for error in "${errors[@]}"; do
      err "Config validation error: $error"
    done
    return 1
  fi
  
  info "Configuration validation passed"
  return 0
}

# Parse command line arguments and set flags
parse_command_line() {
  DEBUG_MODE=false
  FORCE_XPS=false
  TEST_1PASS_MODE=false
  TEST_REMMINA_MODE=false
  
  for arg in "$@"; do
    case "$arg" in
      --debug)
        DEBUG_MODE=true
        info "🐛 DEBUG MODE ENABLED - Simulation only, nothing will be installed"
        ;;
      --xps)
        FORCE_XPS=true
        info "💻 XPS MODE ENABLED - Simulating Dell XPS 13 Plus"
        ;;
      --1pass)
        TEST_1PASS_MODE=true
        info "🔐 1PASSWORD TEST MODE - Testing .pgpass configuration only"
        ;;
      --sync-ssh)
        TEST_SSH_MODE=true
        info "🔑 SSH SYNC MODE - Testing SSH key synchronization from 1Password"
        ;;
      --remmina)
        TEST_REMMINA_MODE=true
        info "🖥️ REMMINA DEBUG MODE - Testing RDP connection generation"
        ;;
      --windocker)
        TEST_WINDOCKER_MODE=true
        info "🪟 WINDOWS DOCKER MODE - Installing Windows 11 via Docker only"
        ;;
      --help|-h)
        show_help
        exit 0
        ;;
      *)
        warn "Unknown argument: $arg"
        ;;
    esac
  done
  
  if [[ "$DEBUG_MODE" == true ]] || [[ "$FORCE_XPS" == true ]]; then
    sleep 2
  fi
}

# Show help message
show_help() {
  echo
  echo "Exarch Scripts - Post-installation setup for Omarchy Linux"
  echo
  echo "Usage: $0 [options]"
  echo
  echo "Options:"
  echo "  --debug     Enable debug mode (simulation only)"
  echo "  --xps       Force Dell XPS 13 Plus mode"
  echo "  --1pass     Test 1Password .pgpass configuration only"
  echo "  --sync-ssh  Test SSH key synchronization from 1Password"
  echo "  --remmina   Test Remmina RDP connection generation (creates sample files)"
  echo "  --windocker Install Windows 11 via Docker only"
  echo "  --help, -h  Show this help message"
  echo
  echo "Configuration:"
  echo "  Create a .env file to customize default settings"
  echo "  Use ./configure.sh for interactive configuration"
  echo
}

# Save current configuration to file
save_config() {
  local config_file="${1:-$(dirname "$0")/.env.generated}"
  
  info "Saving current configuration to $config_file"
  
  cat > "$config_file" << EOF
# Generated configuration file
# Generated on: $(date)

# 1Password Configuration
ONEPASSWORD_URL="${ONEPASSWORD_URL:-}"
ONEPASSWORD_EMAIL="${ONEPASSWORD_EMAIL:-}"

# Installation flags
INSTALL_GOOGLE_CHROME=$INSTALL_GOOGLE_CHROME
INSTALL_FIREFOX=$INSTALL_FIREFOX
INSTALL_COPYQ=$INSTALL_COPYQ
INSTALL_DROPBOX=$INSTALL_DROPBOX
INSTALL_AWS_VPN=$INSTALL_AWS_VPN
INSTALL_POSTMAN=$INSTALL_POSTMAN
INSTALL_REMMINA=$INSTALL_REMMINA
INSTALL_ESPANSO=$INSTALL_ESPANSO
INSTALL_NANO=$INSTALL_NANO
INSTALL_MICRO=$INSTALL_MICRO
INSTALL_KATE=$INSTALL_KATE
INSTALL_SLACK=$INSTALL_SLACK
INSTALL_TEAMS=$INSTALL_TEAMS
INSTALL_JB_TOOLBOX=$INSTALL_JB_TOOLBOX
INSTALL_JB_RIDER=$INSTALL_JB_RIDER
INSTALL_JB_DATAGRIP=$INSTALL_JB_DATAGRIP
INSTALL_CURSOR=$INSTALL_CURSOR
INSTALL_VSCODE=$INSTALL_VSCODE
INSTALL_WINDSURF=$INSTALL_WINDSURF
INSTALL_MISE_RUNTIMES=$INSTALL_MISE_RUNTIMES
INSTALL_CLAUDE_CODE=$INSTALL_CLAUDE_CODE
INSTALL_CODEX_CLI=$INSTALL_CODEX_CLI
INSTALL_GEMINI_CLI=$INSTALL_GEMINI_CLI
SYNC_HYPR_CONFIGS=$SYNC_HYPR_CONFIGS
SETUP_DELL_XPS_9320=$SETUP_DELL_XPS_9320
SETUP_DUAL_KEYBOARD=$SETUP_DUAL_KEYBOARD
SETUP_SHELL_IMPROVEMENTS=$SETUP_SHELL_IMPROVEMENTS
INSTALL_CHEZMOI=$INSTALL_CHEZMOI
INSTALL_AGE=$INSTALL_AGE
SETUP_DOTFILES_MANAGEMENT=$SETUP_DOTFILES_MANAGEMENT
SETUP_DEV_PGPASS=$SETUP_DEV_PGPASS
SETUP_REMMINA_CONNECTIONS=$SETUP_REMMINA_CONNECTIONS
ENABLE_REMMINA_MODULE=$ENABLE_REMMINA_MODULE
GENERATE_REMMINA_CONNECTIONS=$GENERATE_REMMINA_CONNECTIONS

# Runtime versions
DEFAULT_NODE="$DEFAULT_NODE"
DEFAULT_DOTNET_DEFAULT="$DEFAULT_DOTNET_DEFAULT"

# Directory paths
HYPR_SRC_DIR="$HYPR_SRC_DIR"
HYPRL_SRC_DIR="$HYPRL_SRC_DIR"
HYPR_DST_DIR="$HYPR_DST_DIR"
HYPRL_DST_DIR="$HYPRL_DST_DIR"
EOF

  success "Configuration saved to $config_file"
}

# Load configuration from all sources
load_configuration() {
  info "Loading configuration..."
  
  # 1. Load .env file if it exists
  load_env_file "$(dirname "$0")/.env"
  
  # 2. Initialize variables with defaults
  init_config_variables
  
  # 3. Parse command line arguments (can override config)
  parse_command_line "$@"
  
  # 4. Validate configuration
  if ! validate_config; then
    err "Configuration validation failed"
    return 1
  fi
  
  success "Configuration loaded successfully"
  return 0
}

# Check if SSH test mode is enabled
is_ssh_test_mode() {
  [[ "${TEST_SSH_MODE:-false}" == "true" ]]
}

# Export configuration functions
export -f load_env_file init_config_variables validate_config
export -f parse_command_line show_help save_config load_configuration
export -f is_ssh_test_mode