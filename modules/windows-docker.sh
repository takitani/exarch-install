#!/usr/bin/env bash
# modules/windows-docker.sh - Windows 11 via Docker installation and configuration

# Check if Docker is installed and running
check_docker_installed() {
  info "Checking Docker installation..."
  
  if command -v docker &> /dev/null; then
    success "Docker already installed ✓"
    
    # Check if Docker is running
    if ! systemctl is-active --quiet docker; then
      warn "Docker not running, starting service..."
      sudo systemctl start docker || {
        err "Failed to start Docker service"
        return 1
      }
    fi
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
      warn "Adding user to docker group..."
      sudo usermod -aG docker $USER
      info "Please logout and login again for group changes to take effect"
      info "Or run: newgrp docker"
    fi
    
    # Check if docker-compose is available
    if ! command -v docker-compose &> /dev/null; then
      warn "docker-compose not found, installing..."
      pac docker-compose
    fi
    
    return 0
  else
    warn "Docker not installed"
    return 1
  fi
}

# Check system requirements for Windows Docker
check_windows_docker_requirements() {
  info "Checking system requirements for Windows 11 Docker..."
  
  local warnings=()
  
  # Check available RAM (should be at least 12GB for 8GB Windows + 4GB host)
  local total_ram_kb
  total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  local total_ram_gb=$((total_ram_kb / 1024 / 1024))
  
  if [[ $total_ram_gb -lt 12 ]]; then
    warnings+=("⚠️  RAM: ${total_ram_gb}GB (recommended: 12GB+ for smooth operation)")
  else
    success "RAM: ${total_ram_gb}GB ✓"
  fi
  
  # Check available disk space (should be at least 100GB free)
  local available_space_gb
  available_space_gb=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')
  
  if [[ $available_space_gb -lt 100 ]]; then
    warnings+=("⚠️  Disk space: ${available_space_gb}GB free (recommended: 100GB+ free)")
  else
    success "Disk space: ${available_space_gb}GB free ✓"
  fi
  
  # Check KVM support
  if [[ -e /dev/kvm ]]; then
    success "KVM acceleration available ✓"
  else
    warnings+=("⚠️  KVM not available - Windows will run slower without hardware acceleration")
  fi
  
  # Show warnings if any
  if [[ ${#warnings[@]} -gt 0 ]]; then
    echo
    warn "System requirements warnings:"
    for warning in "${warnings[@]}"; do
      echo "  $warning"
    done
    echo
    echo -n "Continue anyway? [y/N]: "
    read -r continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
      info "Installation cancelled"
      return 1
    fi
  fi
  
  return 0
}

# Install Docker if needed
install_docker_if_needed() {
  if ! check_docker_installed; then
    info "Installing Docker and Docker Compose..."
    
    if is_debug_mode; then
      info "[DEBUG] Would install: docker docker-compose"
      return 0
    fi
    
    # Install Docker
    pac docker docker-compose
    
    # Enable Docker service
    sudo systemctl enable --now docker || {
      err "Failed to enable Docker service"
      return 1
    }
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    success "Docker installed and configured"
    info "Note: You may need to logout and login again for group changes"
    
    return 0
  fi
  
  return 0
}

# Create Windows Docker configuration
create_windows_docker_config() {
  local config_dir="$HOME/.config/exarch-scripts"
  local compose_file="$config_dir/docker-compose-windows.yml"
  
  info "Creating Windows Docker configuration..."
  
  # Create config directory
  mkdir -p "$config_dir"
  
  # Create docker-compose.yml for Windows
  cat > "$compose_file" << 'EOF'
version: '3.8'

services:
  windows11:
    image: dockurr/windows
    container_name: windows11-exarch
    environment:
      VERSION: "11"
      DISK_SIZE: "64G"
      RAM: "8G"
      CPU_CORES: "4"
      LANGUAGE: "en-US"        # English International
      KEYBOARD: "en-US"        # US International keyboard
      USERNAME: "User"
      PASSWORD: "ExarchWin11"  # Default password
      MANUAL: "N"             # Automatic installation
    devices:
      - /dev/kvm:/dev/kvm     # Hardware acceleration (if available)
      - /dev/net/tun:/dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - "8006:8006"  # Web viewer
      - "3389:3389"  # RDP
    volumes:
      - windows_data:/storage
      - /home/${USER}:/shared  # Share Linux home directory
    restart: unless-stopped
    networks:
      - windows_network

volumes:
  windows_data:
    driver: local

networks:
  windows_network:
    driver: bridge
EOF

  success "Docker Compose configuration created at: $compose_file"
  return 0
}

# Start Windows Docker container
start_windows_container() {
  local config_dir="$HOME/.config/exarch-scripts"
  local compose_file="$config_dir/docker-compose-windows.yml"
  
  info "Starting Windows 11 container..."
  
  if is_debug_mode; then
    info "[DEBUG] Would run: docker-compose -f $compose_file up -d"
    success "[DEBUG] Windows container started"
    return 0
  fi
  
  # Change to config directory and start container
  cd "$config_dir" || {
    err "Failed to change to config directory"
    return 1
  }
  
  # Pull the Windows image first (this might take a while)
  info "Downloading Windows Docker image (this may take several minutes)..."
  docker-compose -f docker-compose-windows.yml pull || {
    err "Failed to download Windows Docker image"
    return 1
  }
  
  # Start the container
  docker-compose -f docker-compose-windows.yml up -d || {
    err "Failed to start Windows container"
    return 1
  }
  
  success "Windows 11 container started successfully!"
  
  return 0
}

# Install WinApps for seamless Windows app integration
install_winapps() {
  info "Installing WinApps for seamless Windows application integration..."
  
  if is_debug_mode; then
    info "[DEBUG] Would install WinApps and configure FreeRDP"
    return 0
  fi
  
  # Install FreeRDP for RDP connections
  if ! pacman -Q freerdp &>/dev/null; then
    pac freerdp
  fi
  
  # Clone WinApps repository
  local winapps_dir="$HOME/.local/share/winapps"
  
  if [[ ! -d "$winapps_dir" ]]; then
    info "Cloning WinApps repository..."
    git clone https://github.com/winapps-org/winapps.git "$winapps_dir" || {
      warn "Failed to clone WinApps repository"
      return 1
    }
  else
    info "WinApps already installed, updating..."
    cd "$winapps_dir" && git pull || warn "Failed to update WinApps"
  fi
  
  # Create WinApps configuration
  local winapps_config_dir="$HOME/.config/winapps"
  mkdir -p "$winapps_config_dir"
  
  cat > "$winapps_config_dir/winapps.conf" << 'EOF'
RDP_USER="User"
RDP_PASS="ExarchWin11"
RDP_IP="localhost"
RDP_PORT="3389"
MULTIMON="false"
DEBUG="false"
FREERDP_COMMAND="xfreerdp"
EOF
  
  success "WinApps installed and configured"
  
  return 0
}

# Install WinApps Launcher for taskbar integration
install_winapps_launcher() {
  info "Installing WinApps Launcher for taskbar integration..."
  
  if is_debug_mode; then
    info "[DEBUG] Would install yad and WinApps Launcher"
    return 0
  fi
  
  # Install yad dependency
  if ! pacman -Q yad &>/dev/null; then
    pac yad
  fi
  
  # Install WinApps first if not already done
  local winapps_dir="$HOME/.local/share/winapps"
  
  if [[ ! -d "$winapps_dir" ]]; then
    warn "WinApps not found, installing it first..."
    if ! install_winapps; then
      err "Failed to install WinApps (required for WinApps Launcher)"
      return 1
    fi
  fi
  
  # Clone WinApps-Launcher repository  
  local launcher_dir="$HOME/.local/bin/winapps-src/WinApps-Launcher"
  mkdir -p "$(dirname "$launcher_dir")"
  
  if [[ ! -d "$launcher_dir" ]]; then
    info "Cloning WinApps-Launcher repository..."
    git clone https://github.com/winapps-org/WinApps-Launcher.git "$launcher_dir" || {
      warn "Failed to clone WinApps-Launcher repository"
      return 1
    }
  else
    info "WinApps-Launcher already installed, updating..."
    cd "$launcher_dir" && git pull || warn "Failed to update WinApps-Launcher"
  fi
  
  # Make script executable
  chmod +x "$launcher_dir/WinApps-Launcher.sh"
  
  # Create desktop shortcut
  local desktop_dir="$HOME/.local/share/applications"
  mkdir -p "$desktop_dir"
  
  cat > "$desktop_dir/winapps-launcher.desktop" << EOF
[Desktop Entry]
Name=WinApps Launcher
Comment=Taskbar Launcher for Windows Applications
Exec=$launcher_dir/WinApps-Launcher.sh
Icon=$launcher_dir/icon.png
Terminal=false
Type=Application
Categories=Utility;
StartupNotify=true
EOF
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$desktop_dir" &>/dev/null || true
  fi
  
  success "WinApps Launcher installed and configured"
  info "You can now launch Windows apps from the WinApps Launcher in your applications menu"
  
  return 0
}

# Generate Windows Docker RDP connection for Remmina
generate_windows_docker_remmina_connection() {
  info "Generating Windows Docker RDP connection for Remmina..."
  
  # Check if Remmina is available
  if ! command -v remmina &>/dev/null && ! pacman -Q remmina &>/dev/null; then
    warn "Remmina not installed, skipping RDP connection generation"
    return 0
  fi
  
  local remmina_dir="$HOME/.local/share/remmina"
  local config_file="$remmina_dir/group_local_win-11-docker_localhost-3389.remmina"
  
  # Ensure remmina directory exists
  mkdir -p "$remmina_dir"
  
  # Generate Remmina configuration for Windows Docker
  cat > "$config_file" << 'EOF'
[remmina]
password=RXhhcmNoV2luMTE=
gateway_username=
notes_text=Generated for Windows 11 Docker container - Use web viewer at http://localhost:8006
vc=
window_height=1080
preferipv6=0
ssh_tunnel_loopback=0
serialname=
tls-seclevel=
sound=off
printer_overrides=
name=Win 11 Docker
console=0
colordepth=32
security=
precommand=
disable_fastpath=0
postcommand=
left-handed=0
multitransport=0
group=local
server=localhost:3389
ssh_tunnel_certfile=
glyph-cache=0
ssh_tunnel_enabled=0
disableclipboard=0
labels=
audio-output=
parallelpath=
monitorids=
cert_ignore=1
gateway_server=
serialpermissive=0
protocol=RDP
old-license=0
ssh_tunnel_password=
resolution_mode=2
pth=
disableautoreconnect=0
loadbalanceinfo=
clientbuild=
clientname=
resolution_width=1920
drive=/home/opik/Public
relax-order-checks=0
base-cred-for-gw=0
gateway_domain=
network=none
rdp2tcp=
gateway_password=
serialdriver=
rdp_reconnect_attempts=
profile-lock=0
domain=
smartcardname=
serialpath=
exec=
multimon=0
username=User
enable-autostart=0
usb=
shareprinter=0
viewmode=1
restricted-admin=0
shareparallel=0
quality=0
span=0
ssh_tunnel_passphrase=
parallelname=
disablepasswordstoring=0
execpath=
shareserial=0
sharefolder=
sharesmartcard=0
keymap=
ssh_tunnel_username=
resolution_height=1080
timeout=
useproxyenv=0
no-suppress=0
dvc=
microphone=
freerdp_log_filters=
gwtransp=http
window_maximize=1
ssh_tunnel_server=
ignore-tls-errors=1
gateway_usage=0
ssh_tunnel_auth=2
ssh_tunnel_privatekey=
window_width=1920
websockets=0
freerdp_log_level=INFO
disable-smooth-scrolling=0
EOF
  
  success "Created Windows Docker RDP connection: Win 11 Docker"
  info "Connection details:"
  info "  • Name: Win 11 Docker"
  info "  • Server: localhost:3389"
  info "  • Username: User"
  info "  • Password: ExarchWin11"
  info "  • Group: local"
  info "  • File: $config_file"
  
  return 0
}

# Create Windows Docker launcher script and desktop entry
create_windows_docker_launcher() {
  info "Creating Windows Docker launcher and menu integration..."
  
  local launcher_script="$HOME/.local/bin/windows-docker-launcher.sh"
  local desktop_file="$HOME/.local/share/applications/windows-docker.desktop"
  local config_dir="$HOME/.config/exarch-scripts"
  
  # Ensure directories exist
  mkdir -p "$(dirname "$launcher_script")"
  mkdir -p "$(dirname "$desktop_file")"
  
  # Create launcher script
  cat > "$launcher_script" << 'EOF'
#!/bin/bash
# Windows Docker Launcher - Start container and connect via RDP
# Generated by Exarch Scripts

set -euo pipefail

# Configuration
CONFIG_DIR="$HOME/.config/exarch-scripts"
COMPOSE_FILE="$CONFIG_DIR/docker-compose-windows.yml"
CONTAINER_NAME="windows11-exarch"
RDP_HOST="localhost"
RDP_PORT="3389"
WEB_VIEWER="http://localhost:8006"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if Docker is running
check_docker() {
    if ! systemctl is-active --quiet docker; then
        error "Docker service is not running"
        log "Starting Docker service..."
        pkexec systemctl start docker || {
            error "Failed to start Docker service"
            return 1
        }
        sleep 2
    fi
    return 0
}

# Check container status
check_container_status() {
    if docker ps --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        return 0  # Running
    elif docker ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        return 1  # Stopped
    else
        return 2  # Not created
    fi
}

# Start Windows container
start_container() {
    log "Starting Windows 11 Docker container..."
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        error "Docker Compose configuration not found: $COMPOSE_FILE"
        error "Please run the Exarch Scripts installation first"
        return 1
    fi
    
    cd "$CONFIG_DIR" || return 1
    
    # Start container
    if docker-compose -f docker-compose-windows.yml up -d; then
        success "Container started successfully"
        return 0
    else
        error "Failed to start container"
        return 1
    fi
}

# Wait for RDP to be ready
wait_for_rdp() {
    log "Waiting for Windows RDP service to be ready..."
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if timeout 2 bash -c "</dev/tcp/$RDP_HOST/$RDP_PORT" 2>/dev/null; then
            success "RDP service is ready"
            return 0
        fi
        
        ((attempt++))
        log "Attempt $attempt/$max_attempts - RDP not ready yet, waiting..."
        sleep 5
    done
    
    warn "RDP service not ready after $((max_attempts * 5)) seconds"
    return 1
}

# Connect via RDP
connect_rdp() {
    log "Connecting to Windows via RDP..."
    
    # Try different RDP clients in order of preference
    if command -v remmina >/dev/null 2>&1; then
        # Use Remmina if available and connection exists
        local remmina_file="$HOME/.local/share/remmina/group_local_win-11-docker_localhost-3389.remmina"
        if [[ -f "$remmina_file" ]]; then
            log "Using Remmina connection: Win 11 Docker"
            remmina -c "$remmina_file" &
            return 0
        fi
    fi
    
    if command -v xfreerdp >/dev/null 2>&1; then
        log "Using xfreerdp for RDP connection"
        xfreerdp /v:${RDP_HOST}:${RDP_PORT} /u:User /p:ExarchWin11 \
                 /w:1920 /h:1080 /drive:shared,${HOME} \
                 /cert:ignore /compression /auto-reconnect &
        return 0
    fi
    
    if command -v rdesktop >/dev/null 2>&1; then
        log "Using rdesktop for RDP connection"
        rdesktop -g 1920x1080 -u User -p ExarchWin11 -r disk:shared=${HOME} \
                 ${RDP_HOST}:${RDP_PORT} &
        return 0
    fi
    
    warn "No RDP client found. Opening web viewer instead..."
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "$WEB_VIEWER" &
    else
        log "Web viewer available at: $WEB_VIEWER"
    fi
}

# Show startup notification
show_notification() {
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "Windows Docker" "$1" -t 5000 -i computer
    fi
}

# Main execution
main() {
    log "🚀 Windows Docker Launcher starting..."
    
    # Check Docker service
    if ! check_docker; then
        show_notification "Failed to start Docker service"
        exit 1
    fi
    
    # Check container status
    case $(check_container_status; echo $?) in
        0)
            success "Container already running"
            ;;
        1)
            log "Container exists but stopped, starting..."
            if ! start_container; then
                show_notification "Failed to start Windows container"
                exit 1
            fi
            ;;
        2)
            log "Container not found, creating and starting..."
            if ! start_container; then
                show_notification "Failed to create Windows container"
                exit 1
            fi
            ;;
    esac
    
    # Wait for RDP service
    if wait_for_rdp; then
        show_notification "Windows 11 Docker ready - Connecting via RDP..."
        sleep 2
        connect_rdp
        success "🎉 Connected to Windows 11 Docker!"
    else
        show_notification "Windows container started but RDP not ready"
        warn "You can access Windows via web viewer: $WEB_VIEWER"
        if command -v xdg-open >/dev/null 2>&1; then
            log "Opening web viewer..."
            xdg-open "$WEB_VIEWER" &
        fi
    fi
}

# Handle script arguments
case "${1:-}" in
    --status)
        check_container_status
        case $? in
            0) echo "Container is running" ;;
            1) echo "Container is stopped" ;;
            2) echo "Container not found" ;;
        esac
        ;;
    --stop)
        log "Stopping Windows container..."
        cd "$CONFIG_DIR" && docker-compose -f docker-compose-windows.yml down
        ;;
    --web)
        log "Opening web viewer..."
        xdg-open "$WEB_VIEWER" &
        ;;
    *)
        main
        ;;
esac
EOF

  # Make script executable
  chmod +x "$launcher_script"
  
  # Create desktop entry
  cat > "$desktop_file" << EOF
[Desktop Entry]
Name=Windows 11 Docker
Comment=Start Windows 11 container and connect via RDP
Exec=$launcher_script
Icon=windows
Terminal=false
Type=Application
Categories=System;Utility;
Keywords=windows;docker;rdp;vm;
StartupNotify=true
Actions=WebViewer;Stop;Status;

[Desktop Action WebViewer]
Name=Open Web Viewer
Exec=$launcher_script --web

[Desktop Action Stop]
Name=Stop Container
Exec=$launcher_script --stop

[Desktop Action Status]
Name=Check Status
Exec=bash -c '$launcher_script --status | notify-send "Windows Docker Status" "\$(cat)"'
EOF

  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$HOME/.local/share/applications" &>/dev/null || true
  fi
  
  success "Windows Docker launcher created successfully!"
  info "Menu entry details:"
  info "  • Name: Windows 11 Docker"
  info "  • Category: System > Utility"
  info "  • Actions: Web Viewer, Stop Container, Check Status"
  info "  • Script: $launcher_script"
  info "  • Desktop file: $desktop_file"
  
  return 0
}

# Complete WinApps Launcher setup
setup_winapps_launcher_complete() {
  if [[ "${INSTALL_WINAPPS_LAUNCHER:-false}" != "true" ]]; then
    return 0
  fi
  
  echo
  echo -e "${EXATO_CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${EXATO_CYAN}║  ${BOLD}Setting up WinApps Launcher${NC}              ${EXATO_CYAN}║${NC}"
  echo -e "${EXATO_CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo
  
  info "Installing WinApps Launcher for seamless Windows app integration..."
  
  if ! install_winapps_launcher; then
    err "Failed to install WinApps Launcher"
    return 1
  fi
  
  # Check if both Windows Docker and Remmina are installed, then create RDP connection
  if [[ "${INSTALL_WINDOWS_DOCKER:-false}" == "true" ]] && [[ "${GENERATE_REMMINA_CONNECTIONS:-false}" == "true" || "${INSTALL_REMMINA:-false}" == "true" ]]; then
    generate_windows_docker_remmina_connection
  fi
  
  success "WinApps Launcher setup completed successfully!"
  echo
  echo -e "${BOLD}What's been installed:${NC}"
  echo "• yad (GUI toolkit dependency)"
  echo "• WinApps (for Windows app detection and integration)"
  echo "• WinApps-Launcher (taskbar launcher for Windows apps)"
  echo "• Desktop shortcut in applications menu"
  if [[ "${INSTALL_WINDOWS_DOCKER:-false}" == "true" ]] && [[ "${GENERATE_REMMINA_CONNECTIONS:-false}" == "true" || "${INSTALL_REMMINA:-false}" == "true" ]]; then
    echo "• Remmina RDP connection for Windows Docker"
  fi
  if [[ "${INSTALL_WINDOWS_DOCKER:-false}" == "true" ]]; then
    echo "• 'Windows 11 Docker' launcher in system menu"
  fi
  echo
  echo -e "${BOLD}Next steps:${NC}"
  if [[ "${INSTALL_WINDOWS_DOCKER:-false}" == "true" ]]; then
    echo "1. Click 'Windows 11 Docker' in applications menu to start and connect"
    echo "2. Or use the web viewer at http://localhost:8006"
  else
    echo "1. Start your Windows Docker container"
  fi
  echo "2. Install Windows applications in the container"  
  echo "3. Launch 'WinApps Launcher' from applications menu"
  echo "4. Windows apps will appear as native Linux applications"
  if [[ "${INSTALL_WINDOWS_DOCKER:-false}" == "true" ]] && [[ "${GENERATE_REMMINA_CONNECTIONS:-false}" == "true" || "${INSTALL_REMMINA:-false}" == "true" ]]; then
    echo "5. Use Remmina 'Win 11 Docker' connection for direct RDP access"
  fi
  
  return 0
}

# Show Windows Docker status and access information
show_windows_docker_info() {
  echo
  echo -e "${EXATO_CYAN}╔═════════════════════════════════════════╗${NC}"
  echo -e "${EXATO_CYAN}║  ${BOLD}Windows 11 Docker - Access Information${NC} ${EXATO_CYAN}║${NC}"
  echo -e "${EXATO_CYAN}╚═════════════════════════════════════════╝${NC}"
  echo
  
  # Check if container is running
  local container_status
  if command -v docker &>/dev/null && docker ps --format "table {{.Names}}\t{{.Status}}" | grep -q "windows11-exarch"; then
    container_status="🟢 Running"
    
    echo -e "${BOLD}Container Status:${NC} $container_status"
    echo
    echo -e "${BOLD}Access Methods:${NC}"
    echo -e "  🌐 ${CYAN}Web Viewer:${NC} http://localhost:8006"
    echo -e "  🖥️  ${CYAN}RDP Client:${NC} localhost:3389"
    echo
    echo -e "${BOLD}Default Credentials:${NC}"
    echo -e "  👤 ${CYAN}Username:${NC} User"
    echo -e "  🔑 ${CYAN}Password:${NC} ExarchWin11"
    echo
    echo -e "${BOLD}Shared Folder:${NC}"
    echo -e "  📁 Linux home directory available at: ${CYAN}\\\\shared${NC}"
    echo
    echo -e "${YELLOW}💡 Installation Progress:${NC}"
    echo -e "  • Windows installation takes ~30 minutes"
    echo -e "  • Monitor progress at: http://localhost:8006"
    echo -e "  • Container will be ready when web viewer shows Windows desktop"
    
  elif command -v docker &>/dev/null; then
    if docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -q "windows11-exarch"; then
      container_status="🟡 Stopped"
      echo -e "${BOLD}Container Status:${NC} $container_status"
      echo
      echo -e "${YELLOW}To start Windows:${NC} cd ~/.config/exarch-scripts && docker-compose -f docker-compose-windows.yml up -d"
    else
      container_status="🔴 Not Created"
      echo -e "${BOLD}Container Status:${NC} $container_status"
      echo -e "${YELLOW}Run the installation first to create the Windows container.${NC}"
    fi
  else
    echo -e "${RED}Docker not installed${NC}"
  fi
  
  echo
}

# Complete Windows Docker setup
setup_windows_docker_complete() {
  echo
  echo -e "${EXATO_CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${EXATO_CYAN}║  ${BOLD}Setting up Windows 11 via Docker${NC}            ${EXATO_CYAN}║${NC}"
  echo -e "${EXATO_CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo
  
  # Show configuration summary
  echo -e "${BOLD}Configuration:${NC}"
  echo -e "  • OS: Windows 11 (English International)"
  echo -e "  • RAM: 8GB | CPU: 4 cores | Disk: 64GB"
  echo -e "  • Web Access: http://localhost:8006"
  echo -e "  • RDP Access: localhost:3389"
  echo -e "  • Credentials: User / ExarchWin11"
  echo
  
  # Check system requirements
  if ! check_windows_docker_requirements; then
    return 1
  fi
  
  # Install Docker if needed
  if ! install_docker_if_needed; then
    err "Failed to install Docker"
    return 1
  fi
  
  # Create Docker configuration
  if ! create_windows_docker_config; then
    err "Failed to create Docker configuration"
    return 1
  fi
  
  # Install WinApps for seamless integration
  install_winapps
  
  # Generate Remmina connection if both Windows Docker and Remmina are being set up
  if [[ "${GENERATE_REMMINA_CONNECTIONS:-false}" == "true" || "${INSTALL_REMMINA:-false}" == "true" ]]; then
    generate_windows_docker_remmina_connection
  fi
  
  # Create Windows Docker launcher for system menu
  create_windows_docker_launcher
  
  # Start Windows container
  if ! start_windows_container; then
    err "Failed to start Windows container"
    return 1
  fi
  
  # Show access information
  show_windows_docker_info
  
  success "Windows 11 Docker setup completed successfully!"
  echo
  echo -e "${BOLD}Menu Integration:${NC}"
  echo "• 'Windows 11 Docker' launcher created in System menu"
  echo "• Right-click actions: Web Viewer, Stop Container, Check Status"
  echo "• One-click startup and RDP connection"
  
  return 0
}

# Test mode for Windows Docker (--windocker flag)
test_windows_docker_mode() {
  echo
  echo -e "${CYAN}╔══════════════════════════════════════════════╗${NC}"
  echo -e "${CYAN}║  ${BOLD}Windows 11 Docker - Test Mode${NC}              ${CYAN}║${NC}"
  echo -e "${CYAN}╚══════════════════════════════════════════════╝${NC}"
  echo
  
  echo "Windows 11 Docker Test Mode"
  echo "============================"
  echo
  echo "This mode will:"
  echo "• Install Docker and Docker Compose (if needed)"
  echo "• Create Windows 11 container configuration"
  echo "• Download Windows 11 Docker image (~2GB)"
  echo "• Start Windows 11 container with English interface"
  echo "• Install WinApps for seamless app integration" 
  echo "• Configure RDP and web access"
  echo
  
  if ! is_debug_mode; then
    echo -e "${YELLOW}⚠️  This will download and install Windows 11 (may take 30+ minutes)${NC}"
    echo -n "Continue? [y/N]: "
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      info "Windows Docker installation cancelled"
      return 1
    fi
  fi
  
  # Enable Windows Docker module
  INSTALL_WINDOWS_DOCKER=true
  
  echo
  info "Starting Windows 11 Docker setup..."
  setup_windows_docker_complete
}

# Management functions for existing Windows containers
manage_windows_container() {
  local action="$1"
  local config_dir="$HOME/.config/exarch-scripts"
  local compose_file="$config_dir/docker-compose-windows.yml"
  
  if [[ ! -f "$compose_file" ]]; then
    err "Windows Docker configuration not found. Run installation first."
    return 1
  fi
  
  cd "$config_dir" || return 1
  
  case "$action" in
    "start")
      info "Starting Windows container..."
      docker-compose -f docker-compose-windows.yml up -d
      ;;
    "stop")
      info "Stopping Windows container..."
      docker-compose -f docker-compose-windows.yml down
      ;;
    "restart")
      info "Restarting Windows container..."
      docker-compose -f docker-compose-windows.yml restart
      ;;
    "status")
      show_windows_docker_info
      ;;
    "logs")
      docker-compose -f docker-compose-windows.yml logs -f windows11
      ;;
    *)
      err "Unknown action: $action"
      echo "Available actions: start, stop, restart, status, logs"
      return 1
      ;;
  esac
}