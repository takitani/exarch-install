#!/usr/bin/env bash
# lib/package-manager.sh - Package management with pac/aur functions and background jobs

# Source core functions
[[ -f "$(dirname "${BASH_SOURCE[0]}")/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/core.sh"

# Background job tracking
declare -A JOB_STATUS

# Package installation function for pacman
pac() {
  local pkg="$1"
  
  if is_debug_mode; then
    info "[DEBUG] Simulated installation: pacman -S $*"
    INSTALLED_PACKAGES+=("$pkg (pacman) [DEBUG]")
    write_summary "🔄 DEBUG: $pkg (pacman)"
    return 0
  fi
  
  # Check if already installed
  if is_pacman_installed "$pkg"; then
    SKIPPED_PACKAGES+=("$pkg (pacman)")
    write_summary "⏩ Already installed: $pkg (pacman)"
    return 0
  fi
  
  write_log "Attempting to install $pkg via pacman..."
  if sudo pacman -S --noconfirm --needed "$@" 2>>"$LOG_FILE" 1>&2; then
    INSTALLED_PACKAGES+=("$pkg (pacman)")
    write_summary "✅ Installed: $pkg (pacman)"
    return 0
  else
    FAILED_PACKAGES+=("$pkg (pacman)")
    write_summary "❌ Failed: $pkg (pacman)"
    return 1
  fi
}

# Package installation function for AUR
aur() {
  local pkg="$1"
  
  if is_debug_mode; then
    info "[DEBUG] Simulated installation: yay -S $*"
    INSTALLED_PACKAGES+=("$pkg (AUR) [DEBUG]")
    write_summary "🔄 DEBUG: $pkg (AUR)"
    return 0
  fi
  
  # Check if already installed
  if is_aur_installed "$pkg"; then
    SKIPPED_PACKAGES+=("$pkg (AUR)")
    write_summary "⏩ Already installed: $pkg (AUR)"
    return 0
  fi
  
  write_log "Attempting to install $pkg via yay (AUR)..."
  if yay -S --noconfirm --needed --sudoloop "$@" 2>&1 | tee -a "$LOG_FILE" | grep -v "cannot use yay as root"; then
    INSTALLED_PACKAGES+=("$pkg (AUR)")
    write_summary "✅ Installed: $pkg (AUR)"
    return 0
  else
    FAILED_PACKAGES+=("$pkg (AUR)")
    write_summary "❌ Failed: $pkg (AUR)"
    return 1
  fi
}

# Start a background job for package installation
start_background_job() {
  local job_name="$1"
  local pkg_name="$2"
  local install_type="$3"  # "pac" or "aur"
  
  ((JOB_COUNTER++))
  local job_id="job_${JOB_COUNTER}"
  local job_log="$LOG_DIR/${job_id}_${pkg_name}.log"
  
  info "🔄 Starting background installation: $job_name"
  write_log "Starting background job: $job_name ($install_type $pkg_name)"
  
  # Debug mode: simulate installation
  if is_debug_mode; then
    (
      echo "=== INSTALLATION LOG (DEBUG): $job_name ===" > "$job_log"
      echo "Command: [DEBUG] Simulating installation of $pkg_name" >> "$job_log"
      echo "Start: $(date)" >> "$job_log"
      echo "" >> "$job_log"
      
      # Simulate installation time (5 seconds in debug)
      sleep 5
      
      echo "SUCCESS:$job_name:$pkg_name:$install_type" > "$LOG_DIR/${job_id}.result"
      
      echo "" >> "$job_log"
      echo "End: $(date)" >> "$job_log"
    ) &
  elif [[ "$install_type" == "aur" ]]; then
    (
      echo "=== INSTALLATION LOG: $job_name ===" > "$job_log"
      echo "Command: yay -S --noconfirm --needed --sudoloop $pkg_name" >> "$job_log"
      echo "Start: $(date)" >> "$job_log"
      echo "" >> "$job_log"
      
      if yay -S --noconfirm --needed --sudoloop "$pkg_name" >> "$job_log" 2>&1; then
        echo "SUCCESS:$job_name:$pkg_name:$install_type" > "$LOG_DIR/${job_id}.result"
      else
        echo "FAIL:$job_name:$pkg_name:$install_type" > "$LOG_DIR/${job_id}.result"
      fi
      
      echo "" >> "$job_log"
      echo "End: $(date)" >> "$job_log"
    ) &
  else  # pacman
    (
      echo "=== INSTALLATION LOG: $job_name ===" > "$job_log"
      echo "Command: sudo pacman -S --noconfirm --needed $pkg_name" >> "$job_log"
      echo "Start: $(date)" >> "$job_log"
      echo "" >> "$job_log"
      
      if sudo pacman -S --noconfirm --needed "$pkg_name" >> "$job_log" 2>&1; then
        echo "SUCCESS:$job_name:$pkg_name:$install_type" > "$LOG_DIR/${job_id}.result"
      else
        echo "FAIL:$job_name:$pkg_name:$install_type" > "$LOG_DIR/${job_id}.result"
      fi
      
      echo "" >> "$job_log"
      echo "End: $(date)" >> "$job_log"
    ) &
  fi
  
  local pid=$!
  BACKGROUND_JOBS["$job_id"]=$pid
  JOB_NAMES["$job_id"]="$job_name"
  JOB_STATUS["$job_id"]="🔄 Instalando..."
  
  info "Background job started: $job_name (PID: $pid, ID: $job_id)"
}

# Wait for all background jobs to complete
wait_for_background_jobs() {
  local total=${#BACKGROUND_JOBS[@]}
  [[ $total -eq 0 ]] && return 0
  
  info "Aguardando conclusão de $total instalações em background..."
  local completed=0
  local last_update=0
  local update_interval=3  # Update display every 3 seconds
  
  while [[ ${#BACKGROUND_JOBS[@]} -gt 0 ]]; do
    local current_time=$(date +%s)
    
    # Update display periodically
    if [[ $((current_time - last_update)) -ge $update_interval ]]; then
      clear_line
      printf "${BLUE}[ .. ]${NC} Background installation progress:\n"
      
      # Show status of each job
      for job_id in "${!BACKGROUND_JOBS[@]}"; do
        local job_name=${JOB_NAMES[$job_id]}
        local status=${JOB_STATUS[$job_id]}
        printf "  %-25s %s\n" "$job_name:" "$status"
      done
      
      # Progress bar
      local progress_percent=$((completed * 100 / total))
      local bar_length=30
      local filled_length=$((progress_percent * bar_length / 100))
      local bar=""
      
      for ((i=0; i<bar_length; i++)); do
        if [[ $i -lt filled_length ]]; then
          bar+="█"
        else
          bar+="░"
        fi
      done
      
      printf "  [%s] %d%% (%d/%d completed)\n" "$bar" "$progress_percent" "$completed" "$total"
      last_update=$current_time
    fi
    
    for job_id in "${!BACKGROUND_JOBS[@]}"; do
      local pid=${BACKGROUND_JOBS[$job_id]}
      local job_name=${JOB_NAMES[$job_id]}
      
      # Check if job finished
      if ! kill -0 "$pid" 2>/dev/null; then
        ((completed++))
        unset BACKGROUND_JOBS["$job_id"]
        
        # Check result
        local result_file="$LOG_DIR/${job_id}.result"
        if [[ -f "$result_file" ]]; then
          local result
          result=$(cat "$result_file")
          IFS=':' read -r status name pkg type <<< "$result"
          
          if [[ "$status" == "SUCCESS" ]]; then
            JOB_STATUS["$job_id"]="✅ Completed"
            log "✅ $name completed successfully"
            INSTALLED_PACKAGES+=("$pkg ($type) [background]")
            write_summary "✅ Installed (background): $pkg ($type)"
          else
            JOB_STATUS["$job_id"]="❌ Failed"
            warn "❌ $name failed"
            FAILED_PACKAGES+=("$pkg ($type) [background]")
            write_summary "❌ Failed (background): $pkg ($type)"
          fi
          
          # Append job log to main log
          local job_log="$LOG_DIR/${job_id}_${pkg}.log"
          if [[ -f "$job_log" ]]; then
            echo "" >> "$LOG_FILE"
            echo "=== JOB LOG: $name ===" >> "$LOG_FILE"
            cat "$job_log" >> "$LOG_FILE"
            echo "=== END JOB LOG ===" >> "$LOG_FILE"
            rm -f "$job_log"
          fi
          
          rm -f "$result_file"
        fi
      fi
    done
    
    # Small pause to not consume too much CPU
    [[ $completed -lt $total ]] && sleep 1
  done
  
  # Show final result
  clear_line
  printf "${GREEN}[ OK ]${NC} All background installations completed!\n"
  log "🎉 All background installations completed!"
}

# Clear current line
clear_line() {
  printf "\r\033[K"
}

# Install package with retry logic
install_with_retry() {
  local pkg="$1"
  local type="$2"  # "pac" or "aur"
  local max_retries="${3:-3}"
  local retry_count=0
  
  while [[ $retry_count -lt $max_retries ]]; do
    if [[ "$type" == "pac" ]]; then
      if pac "$pkg"; then
        return 0
      fi
    elif [[ "$type" == "aur" ]]; then
      if aur "$pkg"; then
        return 0
      fi
    fi
    
    ((retry_count++))
    if [[ $retry_count -lt $max_retries ]]; then
      warn "Installation failed, retrying ($retry_count/$max_retries)..."
      sleep 2
    fi
  done
  
  err "Failed to install $pkg after $max_retries attempts"
  return 1
}

# Batch install packages
batch_install() {
  local type="$1"
  shift
  local packages=("$@")
  
  info "Starting batch installation of ${#packages[@]} packages via $type"
  
  for pkg in "${packages[@]}"; do
    if [[ "$type" == "pac" ]]; then
      pac "$pkg"
    elif [[ "$type" == "aur" ]]; then
      aur "$pkg"
    fi
  done
}

# Install packages in background (batch)
batch_install_background() {
  local type="$1"
  shift
  local packages=("$@")
  
  for pkg in "${packages[@]}"; do
    start_background_job "$pkg" "$pkg" "$type"
  done
}

# Check if yay is available
check_yay() {
  if ! command_exists yay; then
    err "yay (AUR helper) is not installed"
    err "Please install yay first or use a different AUR helper"
    return 1
  fi
  return 0
}

# Update package databases
update_databases() {
  info "Updating package databases..."
  
  if is_debug_mode; then
    info "[DEBUG] Would update package databases"
    return 0
  fi
  
  # Update pacman database
  if sudo pacman -Sy; then
    success "Pacman database updated"
  else
    warn "Failed to update pacman database"
  fi
  
  # Update yay/AUR database if yay is available
  if command_exists yay; then
    if yay -Sy; then
      success "AUR database updated"
    else
      warn "Failed to update AUR database"
    fi
  fi
}

# Export package management functions
export -f pac aur start_background_job wait_for_background_jobs clear_line
export -f install_with_retry batch_install batch_install_background
export -f check_yay update_databases