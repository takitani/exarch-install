#!/usr/bin/env bash
# lib/core.sh - Core utilities, colors, logging, and basic functions

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BG_BLUE='\033[44m'

# Exato Digital brand colors
EXATO_CYAN='\033[96m'  # Turquoise/Cyan (primary color)
EXATO_YELLOW='\033[93m' # Yellow (secondary color)
EXATO_DARK='\033[90m'  # Dark gray

BOLD='\033[1m'
NC='\033[0m' # No Color

# Global arrays for tracking installations
INSTALLED_PACKAGES=()
FAILED_PACKAGES=()
SKIPPED_PACKAGES=()
CONFIGURED_RUNTIMES=()

# Logging configuration - use /tmp for easy cleanup
LOG_DIR="/tmp/exarch-install-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_DIR" 2>/dev/null || true
LOG_FILE="$LOG_DIR/install.log"
LOG_SUMMARY="$LOG_DIR/summary.txt"

# Background job system
declare -A BACKGROUND_JOBS
declare -A JOB_NAMES
JOB_COUNTER=0

# Initialize log files
init_logging() {
  echo "==========================================================" > "$LOG_FILE"
  echo "EXARCH INSTALL LOG - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
  echo "==========================================================" >> "$LOG_FILE"
  echo "" >> "$LOG_FILE"

  echo "==========================================================" > "$LOG_SUMMARY"
  echo "EXARCH INSTALL SUMMARY - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_SUMMARY"
  echo "==========================================================" >> "$LOG_SUMMARY"
  echo "" >> "$LOG_SUMMARY"
}

# Function to write to log file
write_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Function to write to summary
write_summary() {
  echo "$*" >> "$LOG_SUMMARY"
}

# Logging functions
log() { 
  printf "${GREEN}[ OK ]${NC} %s\n" "$*"
  write_log "[OK] $*"
}

info() { 
  printf "${BLUE}[ .. ]${NC} %s\n" "$*"
  write_log "[INFO] $*"
}

warn() { 
  printf "${YELLOW}[ !! ]${NC} %s\n" "$*" >&2
  write_log "[WARN] $*"
  write_summary "⚠️  AVISO: $*"
}

err() { 
  printf "${RED}[ERR ]${NC} %s\n" "$*" >&2
  write_log "[ERROR] $*"
  write_summary "❌ ERRO: $*"
}

success() {
  printf "${GREEN}✓${NC} %s\n" "$*"
  write_log "[SUCCESS] $*"
}

# Utility functions
is_debug_mode() {
  [[ "${DEBUG_MODE:-false}" == "true" ]]
}

is_xps_mode() {
  [[ "${FORCE_XPS:-false}" == "true" ]]
}

is_1pass_test_mode() {
  [[ "${TEST_1PASS_MODE:-false}" == "true" ]]
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if package is installed via pacman
is_pacman_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

# Check if package is installed via yay (AUR)
is_aur_installed() {
  yay -Q "$1" >/dev/null 2>&1
}

# Function to show a loading animation
show_loading() {
  local duration=${1:-3}
  local text=${2:-"Processing"}
  local i=0
  local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  
  while [[ $i -lt $duration ]]; do
    for (( j=0; j<${#chars}; j++ )); do
      printf "\r${BLUE}${chars:$j:1}${NC} %s" "$text"
      sleep 0.1
    done
    ((i++))
  done
  printf "\r\033[K" # Clear the line
}

# Function to get system info
get_system_info() {
  echo "OS: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
  echo "Kernel: $(uname -r)"
  echo "Architecture: $(uname -m)"
  echo "Shell: ${SHELL##*/}"
  if command_exists yay; then
    echo "AUR Helper: yay $(yay --version | head -1 | awk '{print $2}')"
  fi
}

# Function to create a backup of a file
backup_file() {
  local file="$1"
  local backup_suffix="${2:-.backup.$(date +%Y%m%d_%H%M%S)}"
  
  if [[ -f "$file" ]]; then
    local backup_file="${file}${backup_suffix}"
    cp "$file" "$backup_file"
    info "Backup created: $backup_file"
    return 0
  else
    warn "File not found for backup: $file"
    return 1
  fi
}

# Function to safely create directory
safe_mkdir() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    info "Created directory: $dir"
  fi
}

# Function to check if running as root
check_not_root() {
  if [[ $EUID -eq 0 ]]; then
    err "This script should not be run as root"
    err "Please run as a regular user with sudo privileges"
    exit 1
  fi
}

# Function to check required commands
check_dependencies() {
  local deps=("$@")
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command_exists "$dep"; then
      missing+=("$dep")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    err "Missing required dependencies: ${missing[*]}"
    return 1
  fi
  
  return 0
}

# Function to prompt yes/no question
ask_yes_no() {
  local question="$1"
  local default="${2:-n}"
  local response
  
  if [[ "$default" == "y" ]]; then
    printf "%s [Y/n]: " "$question"
  else
    printf "%s [y/N]: " "$question"
  fi
  
  read -r response
  
  if [[ -z "$response" ]]; then
    response="$default"
  fi
  
  case "$response" in
    [yY]|[yY][eE][sS])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Function to show progress bar
show_progress() {
  local current="$1"
  local total="$2"
  local width=50
  local percentage=$((current * 100 / total))
  local filled=$((current * width / total))
  local empty=$((width - filled))
  
  printf "\r${BLUE}["
  printf "%${filled}s" | tr ' ' '█'
  printf "%${empty}s" | tr ' ' '░'
  printf "]${NC} %d%% (%d/%d)" "$percentage" "$current" "$total"
}

# Cleanup function for graceful exit
cleanup_and_exit() {
  local exit_code="${1:-0}"
  
  info "Cleaning up..."
  
  # Kill any remaining background jobs
  for job_id in "${!BACKGROUND_JOBS[@]}"; do
    local pid="${BACKGROUND_JOBS[$job_id]}"
    if kill -0 "$pid" 2>/dev/null; then
      warn "Killing background job: ${JOB_NAMES[$job_id]} (PID: $pid)"
      kill "$pid" 2>/dev/null || true
    fi
  done
  
  # Restore DNS if modified
  if [[ -f "/tmp/resolv.conf.backup" ]]; then
    info "Restoring original DNS configuration..."
    sudo mv /tmp/resolv.conf.backup /etc/resolv.conf 2>/dev/null || true
  fi
  
  # Show log location
  if [[ -f "$LOG_FILE" ]]; then
    info "Installation log saved to: $LOG_FILE"
  fi
  
  exit "$exit_code"
}

# Trap for cleanup on exit
trap 'cleanup_and_exit $?' EXIT INT TERM

# Function to check internet connection
check_internet() {
  if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    return 0
  else
    err "No internet connection detected"
    return 1
  fi
}

# Export all functions for use in other modules
export -f log info warn err success
export -f show_loading get_system_info backup_file safe_mkdir
export -f check_not_root check_dependencies ask_yes_no show_progress
export -f command_exists is_pacman_installed is_aur_installed
export -f is_debug_mode is_xps_mode is_1pass_test_mode
export -f write_log write_summary init_logging
export -f cleanup_and_exit check_internet