#!/usr/bin/env bash
# modules/development.sh - Development tools and runtime management

# Source required libraries
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/core.sh"
[[ -f "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh" ]] && source "$(dirname "${BASH_SOURCE[0]}")/../lib/package-manager.sh"

# Install development editors
install_development_editors() {
  info "Installing development editors..."
  
  local editors_to_install=()
  
  # Visual Studio Code
  if [[ "${INSTALL_VSCODE:-true}" == "true" ]]; then
    editors_to_install+=("visual-studio-code-bin")
  fi
  
  # Cursor
  if [[ "${INSTALL_CURSOR:-true}" == "true" ]]; then
    editors_to_install+=("cursor-bin")
  fi
  
  # WindSurf
  if [[ "${INSTALL_WINDSURF:-true}" == "true" ]]; then
    editors_to_install+=("windsurf-bin")
  fi
  
  # Text editors
  if [[ "${INSTALL_NANO:-true}" == "true" ]]; then
    pac nano
  fi
  
  if [[ "${INSTALL_MICRO:-true}" == "true" ]]; then
    pac micro
  fi
  
  if [[ "${INSTALL_KATE:-true}" == "true" ]]; then
    pac kate
  fi
  
  # Install AUR editors in background
  for editor in "${editors_to_install[@]}"; do
    start_background_job "$editor" "$editor" "aur"
  done
  
  success "Development editors installation initiated"
}

# Install JetBrains IDEs
install_jetbrains_ides() {
  info "Installing JetBrains IDEs..."
  
  if [[ "${INSTALL_JB_TOOLBOX:-false}" == "true" ]]; then
    # Install JetBrains Toolbox (manages all IDEs)
    start_background_job "JetBrains Toolbox" "jetbrains-toolbox" "aur"
  else
    # Install individual IDEs
    if [[ "${INSTALL_JB_RIDER:-true}" == "true" ]]; then
      start_background_job "JetBrains Rider" "rider" "aur"
    fi
    
    if [[ "${INSTALL_JB_DATAGRIP:-true}" == "true" ]]; then
      start_background_job "DataGrip" "datagrip" "aur"
    fi
  fi
  
  success "JetBrains IDEs installation initiated"
}

# Install Claude Code CLI
install_claude_code() {
  if [[ "${INSTALL_CLAUDE_CODE:-true}" != "true" ]]; then
    return 0
  fi
  
  info "Installing Claude Code CLI..."
  
  # Check if already installed
  if command_exists claude-code; then
    success "Claude Code already installed"
    return 0
  fi
  
  # Install via npm (Claude Code is distributed via npm)
  if command_exists npm; then
    if npm install -g claude-code 2>/dev/null; then
      success "Claude Code installed via npm"
      CONFIGURED_RUNTIMES+=("Claude Code CLI")
      return 0
    fi
  fi
  
  # Fallback: try AUR
  if aur claude-code-bin || aur claude-code; then
    success "Claude Code installed via AUR"
    CONFIGURED_RUNTIMES+=("Claude Code CLI")
  else
    warn "Failed to install Claude Code"
    echo "Install manually: npm install -g claude-code"
  fi
}

# Install AI CLI tools
install_ai_cli_tools() {
  info "Installing AI CLI tools..."
  
  # Install Claude Code
  install_claude_code
  
  # Install other AI tools
  if [[ "${INSTALL_CODEX_CLI:-true}" == "true" ]]; then
    start_background_job "Codex CLI" "codex-cli" "aur"
  fi
  
  if [[ "${INSTALL_GEMINI_CLI:-true}" == "true" ]]; then
    start_background_job "Gemini CLI" "gemini-cli" "aur"
  fi
  
  success "AI CLI tools installation initiated"
}

# Configure mise for runtime management
configure_mise_runtimes() {
  if [[ "${INSTALL_MISE_RUNTIMES:-true}" != "true" ]]; then
    info "Skipping mise runtime configuration (not selected)"
    return 0
  fi
  
  info "Configuring mise runtimes..."
  
  # Check if mise is installed
  if ! command_exists mise; then
    warn "mise not found - installing..."
    if ! pac mise; then
      err "Failed to install mise"
      return 1
    fi
  fi
  
  # Configure Node.js
  configure_nodejs_runtime
  
  # Configure .NET
  configure_dotnet_runtime
  
  success "Mise runtimes configured"
}

# Configure Node.js via mise
configure_nodejs_runtime() {
  local node_version="${DEFAULT_NODE:-lts}"
  
  info "Configuring Node.js via mise (version: $node_version)..."
  
  # Install Node.js version
  if mise install node@"$node_version" 2>/dev/null; then
    info "Node.js $node_version installed via mise"
  else
    warn "Failed to install Node.js $node_version via mise"
    return 1
  fi
  
  # Set as global default
  if mise use -g node@"$node_version" 2>/dev/null; then
    success "Node.js $node_version set as global default"
    CONFIGURED_RUNTIMES+=("Node.js $node_version (mise)")
  else
    warn "Failed to set Node.js $node_version as global default"
  fi
  
  # Install global npm packages
  install_global_npm_packages
}

# Configure .NET via mise
configure_dotnet_runtime() {
  local dotnet_default="${DEFAULT_DOTNET_DEFAULT:-9}"
  
  info "Configuring .NET via mise (default: $dotnet_default)..."
  
  # Install default version
  if mise install dotnet@"$dotnet_default" 2>/dev/null; then
    info ".NET $dotnet_default installed via mise"
  else
    warn "Failed to install .NET $dotnet_default via mise"
    return 1
  fi
  
  # Set as global default
  if mise use -g dotnet@"$dotnet_default" 2>/dev/null; then
    success ".NET $dotnet_default set as global default"
    CONFIGURED_RUNTIMES+=(".NET $dotnet_default (mise)")
  else
    warn "Failed to set .NET $dotnet_default as global default"
  fi
  
  # Install additional versions
  if [[ -n "${EXTRA_DOTNET:-}" ]]; then
    for version in "${EXTRA_DOTNET[@]}"; do
      if mise install dotnet@"$version" 2>/dev/null; then
        info ".NET $version installed as additional version"
        CONFIGURED_RUNTIMES+=(".NET $version (mise)")
      else
        warn "Failed to install additional .NET version: $version"
      fi
    done
  fi
}

# Install global npm packages
install_global_npm_packages() {
  info "Installing global npm packages..."
  
  # Check if npm is available
  if ! command_exists npm; then
    warn "npm not available, skipping global packages"
    return 1
  fi
  
  # Essential development packages
  local npm_packages=(
    "typescript"
    "ts-node"     
    "@vue/cli"
    "create-react-app"
    "vite"
    "eslint"
    "prettier"
    "nodemon"
    "pm2"
    "yarn"
    "pnpm"
  )
  
  for package in "${npm_packages[@]}"; do
    if npm list -g "$package" >/dev/null 2>&1; then
      info "$package already installed globally"
    else
      info "Installing global npm package: $package"
      if npm install -g "$package" >/dev/null 2>&1; then
        success "$package installed globally"
      else
        warn "Failed to install $package globally"
      fi
    fi
  done
  
  CONFIGURED_RUNTIMES+=("Global npm packages")
  success "Global npm packages configured"
}

# Install development tools
install_development_tools() {
  info "Installing development tools..."
  
  # Version control and tools
  pac git
  
  # API testing
  if [[ "${INSTALL_POSTMAN:-true}" == "true" ]]; then
    start_background_job "Postman" "postman-bin" "aur"
  fi
  
  # Remote desktop
  if [[ "${INSTALL_REMMINA:-true}" == "true" ]]; then
    pac remmina
  fi
  
  # Text expansion
  if [[ "${INSTALL_ESPANSO:-true}" == "true" ]]; then
    pac espanso
  fi
  
  success "Development tools installation initiated"
}

# Install containerization tools
install_container_tools() {
  info "Installing containerization tools..."
  
  # Docker
  if ask_yes_no "Install Docker?"; then
    pac docker
    pac docker-compose
    
    # Add user to docker group
    if ! groups "$USER" | grep -q docker; then
      info "Adding user to docker group..."
      sudo usermod -aG docker "$USER"
      warn "You need to log out and back in for Docker group changes to take effect"
    fi
    
    # Enable Docker service
    if ! systemctl is-enabled docker >/dev/null 2>&1; then
      sudo systemctl enable docker
    fi
    
    if ! systemctl is-active docker >/dev/null 2>&1; then
      sudo systemctl start docker
    fi
    
    CONFIGURED_RUNTIMES+=("Docker with docker-compose")
  fi
  
  # Podman (alternative to Docker)
  if ask_yes_no "Install Podman as Docker alternative?"; then
    pac podman
    pac podman-compose
    CONFIGURED_RUNTIMES+=("Podman with podman-compose")
  fi
}

# Configure development environment
setup_development_environment() {
  info "Setting up development environment..."
  
  # Install editors
  install_development_editors
  
  # Install JetBrains IDEs
  install_jetbrains_ides
  
  # Install development tools
  install_development_tools
  
  # Install AI CLI tools
  install_ai_cli_tools
  
  # Configure runtimes
  configure_mise_runtimes
  
  # Wait for background installations
  wait_for_background_jobs
  
  # Install container tools (interactive)
  # install_container_tools
  
  success "Development environment setup completed"
}

# Configure git (optional interactive setup)
configure_git() {
  if ! command_exists git; then
    warn "Git not installed, skipping configuration"
    return 1
  fi
  
  info "Configuring Git..."
  
  # Check if already configured
  local git_name git_email
  git_name=$(git config --global user.name 2>/dev/null || echo "")
  git_email=$(git config --global user.email 2>/dev/null || echo "")
  
  if [[ -n "$git_name" ]] && [[ -n "$git_email" ]]; then
    info "Git already configured:"
    info "  Name: $git_name"
    info "  Email: $git_email"
    return 0
  fi
  
  # Interactive configuration
  if ask_yes_no "Configure Git user information?"; then
    echo -n "Enter your full name: "
    read -r name
    echo -n "Enter your email: "
    read -r email
    
    git config --global user.name "$name"
    git config --global user.email "$email"
    
    # Set some useful defaults
    git config --global init.defaultBranch main
    git config --global pull.rebase false
    git config --global push.default simple
    
    success "Git configured successfully"
    CONFIGURED_RUNTIMES+=("Git (user: $name <$email>)")
  fi
}

# Show development tools summary
show_development_summary() {
  echo
  echo -e "${BOLD}Development Environment Summary${NC}"
  echo "================================"
  
  # Editors
  echo -e "\n${CYAN}Editors:${NC}"
  command_exists code && echo "✓ Visual Studio Code"
  command_exists cursor && echo "✓ Cursor"
  command_exists windsurf && echo "✓ WindSurf" 
  command_exists nano && echo "✓ Nano"
  command_exists micro && echo "✓ Micro"
  command_exists kate && echo "✓ Kate"
  
  # IDEs
  echo -e "\n${CYAN}IDEs:${NC}"
  command_exists jetbrains-toolbox && echo "✓ JetBrains Toolbox"
  command_exists rider && echo "✓ JetBrains Rider"
  command_exists datagrip && echo "✓ DataGrip"
  
  # Runtimes
  echo -e "\n${CYAN}Runtimes:${NC}"
  if command_exists mise; then
    echo "✓ mise (runtime manager)"
    if command_exists node; then
      echo "  └─ Node.js $(node --version 2>/dev/null || echo 'unknown')"
    fi
    if command_exists dotnet; then
      echo "  └─ .NET $(dotnet --version 2>/dev/null || echo 'unknown')"
    fi
  fi
  
  # Tools
  echo -e "\n${CYAN}Development Tools:${NC}"
  command_exists git && echo "✓ Git $(git --version 2>/dev/null | cut -d' ' -f3 || echo 'unknown')"
  command_exists docker && echo "✓ Docker $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo 'unknown')"
  command_exists podman && echo "✓ Podman"
  command_exists postman && echo "✓ Postman"
  command_exists remmina && echo "✓ Remmina"
  command_exists espanso && echo "✓ Espanso"
  
  # AI Tools
  echo -e "\n${CYAN}AI Tools:${NC}"
  command_exists claude-code && echo "✓ Claude Code"
  command_exists codex && echo "✓ Codex CLI"
  command_exists gemini && echo "✓ Gemini CLI"
  
  echo
}

# Export functions
export -f install_development_editors install_jetbrains_ides install_claude_code
export -f install_ai_cli_tools configure_mise_runtimes configure_nodejs_runtime
export -f configure_dotnet_runtime install_global_npm_packages install_development_tools
export -f install_container_tools setup_development_environment configure_git
export -f show_development_summary