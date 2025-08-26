#!/usr/bin/env bash
set -euo pipefail

# ======================================
# Post-Omarchy setup (Arch + Hyprland)
# - Menu interativo para seleção de componentes
# - Suporte específico para Dell XPS 13 Plus (9320)
# - Usa exclusivamente yay (já presente no Omarchy)
# - Configura mise (já instalado): Node LTS + .NET 8/9
# ======================================

# Modo debug (simulação sem instalação real)
DEBUG_MODE=false
FORCE_XPS=false

for arg in "$@"; do
  case "$arg" in
    --debug)
      DEBUG_MODE=true
      echo "🐛 MODO DEBUG ATIVADO - Simulação apenas, nada será instalado"
      ;;
    --xps)
      FORCE_XPS=true
      echo "💻 MODO XPS ATIVADO - Simulando Dell XPS 13 Plus"
      ;;
  esac
done

if [[ "$DEBUG_MODE" == true ]] || [[ "$FORCE_XPS" == true ]]; then
  sleep 2
fi

# Arrays para tracking de instalações
INSTALLED_PACKAGES=()
FAILED_PACKAGES=()
SKIPPED_PACKAGES=()
CONFIGURED_RUNTIMES=()

# Configurações de instalação (modificadas pelo menu)
INSTALL_GOOGLE_CHROME=false
INSTALL_COPYQ=false
INSTALL_DROPBOX=false
INSTALL_AWS_VPN=false
INSTALL_POSTMAN=false
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
SYNC_HYPR_CONFIGS=false
SETUP_DELL_XPS_9320=false

DEFAULT_NODE="lts"         # Ex.: lts | 22 | 20
DEFAULT_DOTNET_DEFAULT="9" # Default global
EXTRA_DOTNET=("8")          # Versões adicionais

# Diretórios de origem/destino dos configs do Hypr/Hyprl para sincronizar
HYPR_SRC_DIR="${HYPR_SRC_DIR:-$(pwd)/dotfiles/hypr}"
HYPRL_SRC_DIR="${HYPRL_SRC_DIR:-$(pwd)/dotfiles/hyprl}"
HYPR_DST_DIR="${HYPR_DST_DIR:-$HOME/.config/hypr}"
HYPRL_DST_DIR="${HYPRL_DST_DIR:-$HOME/.config/hyprl}"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BG_BLUE='\033[44m'
# Cores da Exato Digital
EXATO_CYAN='\033[96m'  # Turquesa/Ciano (cor principal)
EXATO_YELLOW='\033[93m' # Amarelo (cor secundária)
EXATO_DARK='\033[90m'  # Cinza escuro
BOLD='\033[1m'
NC='\033[0m' # No Color

# Índice selecionado no menu
SELECTED_INDEX=0

log() { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
info() { printf "${BLUE}[ .. ]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[ !! ]${NC} %s\n" "$*"; }
err() { printf "${RED}[ERR ]${NC} %s\n" "$*" >&2; }

# Detecção de hardware
detect_hardware() {
  local product_name=""
  if [[ -f /sys/devices/virtual/dmi/id/product_name ]]; then
    product_name=$(cat /sys/devices/virtual/dmi/id/product_name 2>/dev/null || echo "")
  fi
  echo "$product_name"
}

# Menu de seleção com checkboxes
show_menu() {
  clear
  echo
  echo -e "        ${EXATO_YELLOW}███████╗██╗  ██╗ █████╗ ██████╗  ██████╗██╗  ██╗${NC}"
  echo -e "        ${EXATO_YELLOW}██╔════╝╚██╗██╔╝██╔══██╗██╔══██╗██╔════╝██║  ██║${NC}"
  echo -e "        ${EXATO_YELLOW}█████╗   ╚███╔╝ ███████║██████╔╝██║     ███████║${NC}"
  echo -e "        ${EXATO_YELLOW}██╔══╝   ██╔██╗ ██╔══██║██╔══██╗██║     ██╔══██║${NC}"
  echo -e "        ${EXATO_YELLOW}███████╗██╔╝ ██╗██║  ██║██║  ██║╚██████╗██║  ██║${NC}"
  echo -e "        ${EXATO_YELLOW}╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝${NC}"
  echo
  echo -e "               ${EXATO_CYAN}██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗${NC}"
  echo -e "               ${EXATO_CYAN}██║     ██║████╗  ██║██║   ██║╚██╗██╔╝${NC}"
  echo -e "               ${EXATO_CYAN}██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝${NC}"
  echo -e "               ${EXATO_CYAN}██║     ██║██║╚██╗██║██║   ██║ ██╔██╗${NC}"
  echo -e "               ${EXATO_CYAN}███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗${NC}"
  echo -e "               ${EXATO_CYAN}╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝${NC}"
  echo
  echo -e "${EXATO_CYAN}═══════════════════════════════════════════════════════════════════${NC}"
  local title="Omarchy Post-Install Setup"
  local prefix=""
  
  if [[ "$DEBUG_MODE" == true ]]; then
    prefix="${BOLD}${RED}🐛 DEBUG MODE${NC}"
  fi
  
  if [[ "$FORCE_XPS" == true ]] || [[ "$hw_model" == *"XPS"* ]]; then
    if [[ -n "$prefix" ]]; then
      prefix="$prefix ${BOLD}${YELLOW}💻 XPS 9320${NC}"
    else
      prefix="${BOLD}${YELLOW}💻 XPS 9320${NC}"
    fi
  fi
  
  if [[ -n "$prefix" ]]; then
    echo -e "$prefix ${BOLD}- $title${NC}"
  else
    echo -e "${BOLD}              $title${NC}"
  fi
  echo -e "${EXATO_CYAN}═══════════════════════════════════════════════════════════════════${NC}"
  echo
  
  # Detectar hardware
  local hw_model
  hw_model=$(detect_hardware)
  if [[ "$hw_model" == *"XPS 13 9320"* ]] || [[ "$hw_model" == *"XPS 13 Plus"* ]] || [[ "$FORCE_XPS" == true ]]; then
    echo -e "${YELLOW}🔍 Hardware detectado: Dell XPS 13 Plus (9320)${NC}"
    echo -e "${YELLOW}   Configuração específica disponível!${NC}"
    echo
  fi
  
  echo -e "${BOLD}Selecione os componentes para instalar:${NC}"
  echo -e "${EXATO_DARK}(Números separados por espaço: '1 3 5', Seções: 10=apps, 20=jetbrains, 30=dev, 40=config)${NC}"
  echo -e "${EXATO_DARK}(Atalhos: a=todos, r=recomendados, d=desenvolvimento, x=continuar, q=sair)${NC}"
  echo
  
  local num=1
  
  echo
  echo -e "${GREEN}📦 Aplicações ${EXATO_YELLOW}[10]${NC}:${NC}"
  echo -e "  ${num}) [$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo '✓' || echo ' ')] Google Chrome - Navegador web"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_COPYQ" == true ] && echo '✓' || echo ' ')] CopyQ - Gerenciador de clipboard"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_DROPBOX" == true ] && echo '✓' || echo ' ')] Dropbox - Sincronização de arquivos"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_AWS_VPN" == true ] && echo '✓' || echo ' ')] AWS VPN Client"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_POSTMAN" == true ] && echo '✓' || echo ' ')] Postman - Teste de APIs"; ((num++))
  
  echo
  echo -e "${GREEN}🛠️ JetBrains IDEs ${EXATO_YELLOW}[20]${NC}:${NC}"
  echo -e "  ${num}) [$([ "$INSTALL_JB_TOOLBOX" == true ] && echo '✓' || echo ' ')] JetBrains Toolbox"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_JB_RIDER" == true ] && echo '✓' || echo ' ')] Rider - IDE para .NET"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_JB_DATAGRIP" == true ] && echo '✓' || echo ' ')] DataGrip - IDE para bancos de dados"; ((num++))
  
  echo
  echo -e "${GREEN}🚀 Desenvolvimento ${EXATO_YELLOW}[30]${NC}:${NC}"
  echo -e "  ${num}) [$([ "$INSTALL_CURSOR" == true ] && echo '✓' || echo ' ')] Cursor - IDE com IA integrada"; ((num++))
  echo -e " ${num}) [$([ "$INSTALL_VSCODE" == true ] && echo '✓' || echo ' ')] Visual Studio Code"; ((num++))
  echo -e " ${num}) [$([ "$INSTALL_WINDSURF" == true ] && echo '✓' || echo ' ')] Windsurf IDE"; ((num++))
  echo -e " ${num}) [$([ "$INSTALL_MISE_RUNTIMES" == true ] && echo '✓' || echo ' ')] Mise Runtimes (Node.js LTS + .NET 8/9)"; ((num++))
  echo -e " ${num}) [$([ "$INSTALL_CLAUDE_CODE" == true ] && echo '✓' || echo ' ')] Claude Code CLI"; ((num++))
  echo -e " ${num}) [$([ "$INSTALL_CODEX_CLI" == true ] && echo '✓' || echo ' ')] Codex CLI - OpenAI"; ((num++))
  echo -e " ${num}) [$([ "$INSTALL_GEMINI_CLI" == true ] && echo '✓' || echo ' ')] Gemini CLI - Google"; ((num++))
  
  echo
  echo -e "${GREEN}⚙️ Configurações ${EXATO_YELLOW}[40]${NC}:${NC}"
  echo -e " ${num}) [$([ "$SYNC_HYPR_CONFIGS" == true ] && echo '✓' || echo ' ')] Sincronizar configurações Hypr/Hyprl"; ((num++))
  
  if [[ "$hw_model" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
    echo
    echo -e "${GREEN}💻 Hardware Específico ${EXATO_YELLOW}[50]${NC}:${NC}"
    echo -e " ${num}) [$([ "$SETUP_DELL_XPS_9320" == true ] && echo '✓' || echo ' ')] Configurar Dell XPS 13 Plus (webcam + otimizações)"
  fi
  
  echo
  echo -e "${EXATO_CYAN}════════════════════════════════════════${NC}"
  echo -e "Atalhos: ${EXATO_YELLOW}a${NC} marcar todos | ${EXATO_YELLOW}r${NC} recomendados | ${EXATO_YELLOW}d${NC} desenvolvimento completo"
  echo
}

# Atualizar estados das variáveis baseado no índice
update_states_from_array() {
  local states=("$@")
  INSTALL_GOOGLE_CHROME="${states[0]}"
  INSTALL_COPYQ="${states[1]}"
  INSTALL_DROPBOX="${states[2]}"
  INSTALL_AWS_VPN="${states[3]}"
  INSTALL_POSTMAN="${states[4]}"
  INSTALL_JB_TOOLBOX="${states[5]}"
  INSTALL_JB_RIDER="${states[6]}"
  INSTALL_JB_DATAGRIP="${states[7]}"
  INSTALL_CURSOR="${states[8]}"
  INSTALL_VSCODE="${states[9]}"
  INSTALL_WINDSURF="${states[10]}"
  INSTALL_MISE_RUNTIMES="${states[11]}"
  INSTALL_CLAUDE_CODE="${states[12]}"
  INSTALL_CODEX_CLI="${states[13]}"
  INSTALL_GEMINI_CLI="${states[14]}"
  SYNC_HYPR_CONFIGS="${states[15]}"
  if [[ ${#states[@]} -gt 16 ]]; then
    SETUP_DELL_XPS_9320="${states[16]}"
  fi
}

toggle_option() {
  case "$1" in
    0) INSTALL_GOOGLE_CHROME=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true) ;;
    1) INSTALL_COPYQ=$([ "$INSTALL_COPYQ" == true ] && echo false || echo true) ;;
    2) INSTALL_DROPBOX=$([ "$INSTALL_DROPBOX" == true ] && echo false || echo true) ;;
    3) INSTALL_AWS_VPN=$([ "$INSTALL_AWS_VPN" == true ] && echo false || echo true) ;;
    4) INSTALL_POSTMAN=$([ "$INSTALL_POSTMAN" == true ] && echo false || echo true) ;;
    5) INSTALL_JB_TOOLBOX=$([ "$INSTALL_JB_TOOLBOX" == true ] && echo false || echo true) ;;
    6) INSTALL_JB_RIDER=$([ "$INSTALL_JB_RIDER" == true ] && echo false || echo true) ;;
    7) INSTALL_JB_DATAGRIP=$([ "$INSTALL_JB_DATAGRIP" == true ] && echo false || echo true) ;;
    8) INSTALL_CURSOR=$([ "$INSTALL_CURSOR" == true ] && echo false || echo true) ;;
    9) INSTALL_VSCODE=$([ "$INSTALL_VSCODE" == true ] && echo false || echo true) ;;
    10) INSTALL_WINDSURF=$([ "$INSTALL_WINDSURF" == true ] && echo false || echo true) ;;
    11) INSTALL_MISE_RUNTIMES=$([ "$INSTALL_MISE_RUNTIMES" == true ] && echo false || echo true) ;;
    12) INSTALL_CLAUDE_CODE=$([ "$INSTALL_CLAUDE_CODE" == true ] && echo false || echo true) ;;
    13) INSTALL_CODEX_CLI=$([ "$INSTALL_CODEX_CLI" == true ] && echo false || echo true) ;;
    14) INSTALL_GEMINI_CLI=$([ "$INSTALL_GEMINI_CLI" == true ] && echo false || echo true) ;;
    15) SYNC_HYPR_CONFIGS=$([ "$SYNC_HYPR_CONFIGS" == true ] && echo false || echo true) ;;
    16) SETUP_DELL_XPS_9320=$([ "$SETUP_DELL_XPS_9320" == true ] && echo false || echo true) ;;
    a|A) 
      local state=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true)
      INSTALL_GOOGLE_CHROME=$state
      INSTALL_COPYQ=$state
      INSTALL_DROPBOX=$state
      INSTALL_AWS_VPN=$state
      INSTALL_POSTMAN=$state
      INSTALL_JB_TOOLBOX=$state
      INSTALL_JB_RIDER=$state
      INSTALL_JB_DATAGRIP=$state
      INSTALL_CURSOR=$state
      INSTALL_VSCODE=$state
      INSTALL_WINDSURF=$state
      INSTALL_MISE_RUNTIMES=$state
      INSTALL_CLAUDE_CODE=$state
      INSTALL_CODEX_CLI=$state
      INSTALL_GEMINI_CLI=$state
      SYNC_HYPR_CONFIGS=$state
      if [[ "$(detect_hardware)" == *"XPS"* ]]; then
        SETUP_DELL_XPS_9320=$state
      fi
      ;;
    r|R)
      INSTALL_GOOGLE_CHROME=true
      INSTALL_COPYQ=true
      INSTALL_DROPBOX=true
      INSTALL_AWS_VPN=false
      INSTALL_POSTMAN=false
      INSTALL_JB_TOOLBOX=false
      INSTALL_JB_RIDER=false
      INSTALL_JB_DATAGRIP=false
      INSTALL_CURSOR=false
      INSTALL_VSCODE=false
      INSTALL_WINDSURF=false
      INSTALL_MISE_RUNTIMES=true
      INSTALL_CLAUDE_CODE=true
      INSTALL_CODEX_CLI=false
      INSTALL_GEMINI_CLI=false
      SYNC_HYPR_CONFIGS=true
      SETUP_DELL_XPS_9320=false
      ;;
    d|D)
      INSTALL_GOOGLE_CHROME=true
      INSTALL_COPYQ=true
      INSTALL_DROPBOX=true
      INSTALL_AWS_VPN=true
      INSTALL_POSTMAN=true
      INSTALL_JB_TOOLBOX=false
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
      if [[ "$(detect_hardware)" == *"XPS"* ]]; then
        SETUP_DELL_XPS_9320=true
      fi
      ;;
  esac
}

interactive_menu() {
  local hw_model
  hw_model=$(detect_hardware)
  
  # Auto-configurar para Dell XPS 13 Plus
  if [[ "$hw_model" == *"XPS 13 9320"* ]] || [[ "$hw_model" == *"XPS 13 Plus"* ]] || [[ "$FORCE_XPS" == true ]]; then
    echo -e "${YELLOW}🔍 Dell XPS 13 Plus detectado - Marcando configurações de hardware específicas...${NC}"
    SETUP_DELL_XPS_9320=true  # Auto-marcar apenas configuração XPS
    sleep 1
  fi
  
  while true; do
    show_menu
    
    echo
    echo -n "Digite uma opção: "
    read -r choice
    
    case "$choice" in
      10) # Seção Aplicações (1-5)
        echo "Alternando seção Aplicações..."
        local state=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true)
        INSTALL_GOOGLE_CHROME=$state
        INSTALL_COPYQ=$state
        INSTALL_DROPBOX=$state
        INSTALL_AWS_VPN=$state
        INSTALL_POSTMAN=$state
        ;;
      20) # Seção JetBrains (6-8)
        echo "Alternando seção JetBrains..."
        local state=$([ "$INSTALL_JB_TOOLBOX" == true ] && echo false || echo true)
        INSTALL_JB_TOOLBOX=$state
        INSTALL_JB_RIDER=$state
        INSTALL_JB_DATAGRIP=$state
        ;;
      30) # Seção Desenvolvimento (9-15)
        echo "Alternando seção Desenvolvimento..."
        local state=$([ "$INSTALL_CURSOR" == true ] && echo false || echo true)
        INSTALL_CURSOR=$state
        INSTALL_VSCODE=$state
        INSTALL_WINDSURF=$state
        INSTALL_MISE_RUNTIMES=$state
        INSTALL_CLAUDE_CODE=$state
        INSTALL_CODEX_CLI=$state
        INSTALL_GEMINI_CLI=$state
        ;;
      40) # Seção Configurações (12)
        echo "Alternando seção Configurações..."
        SYNC_HYPR_CONFIGS=$([ "$SYNC_HYPR_CONFIGS" == true ] && echo false || echo true)
        ;;
      50) # Seção Hardware (13) - se aplicável
        if [[ "$hw_model" == *"XPS"* ]]; then
          echo "Alternando seção Hardware..."
          SETUP_DELL_XPS_9320=$([ "$SETUP_DELL_XPS_9320" == true ] && echo false || echo true)
        fi
        ;;
      *[0-9]*) # Números individuais ou múltiplos
        # Dividir entrada por espaços e processar cada número
        for num in $choice; do
          if [[ "$num" =~ ^[1-9]$|^1[0-5]$ ]]; then
            local index=$((num - 1))
            toggle_option "$index"
          fi
        done
        ;;
      a|A) # Marcar/desmarcar todos
        local state=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true)
        INSTALL_GOOGLE_CHROME=$state
        INSTALL_COPYQ=$state
        INSTALL_DROPBOX=$state
        INSTALL_AWS_VPN=$state
        INSTALL_POSTMAN=$state
        INSTALL_JB_TOOLBOX=$state
        INSTALL_JB_RIDER=$state
        INSTALL_JB_DATAGRIP=$state
        INSTALL_CURSOR=$state
        INSTALL_VSCODE=$state
        INSTALL_WINDSURF=$state
        INSTALL_MISE_RUNTIMES=$state
        INSTALL_CLAUDE_CODE=$state
        SYNC_HYPR_CONFIGS=$state
        if [[ "$hw_model" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
          SETUP_DELL_XPS_9320=$state
        fi
        ;;
      r|R) # Recomendados
        INSTALL_GOOGLE_CHROME=true
        INSTALL_COPYQ=true
        INSTALL_DROPBOX=true
        INSTALL_AWS_VPN=false
        INSTALL_POSTMAN=false
        INSTALL_JB_TOOLBOX=false
        INSTALL_JB_RIDER=false
        INSTALL_JB_DATAGRIP=false
        INSTALL_CURSOR=false
        INSTALL_VSCODE=false
        INSTALL_WINDSURF=false
        INSTALL_MISE_RUNTIMES=true
        INSTALL_CLAUDE_CODE=true
        SYNC_HYPR_CONFIGS=true
        SETUP_DELL_XPS_9320=false
        ;;
      d|D) # Desenvolvimento completo
        INSTALL_GOOGLE_CHROME=true
        INSTALL_COPYQ=true
        INSTALL_DROPBOX=true
        INSTALL_AWS_VPN=true
        INSTALL_POSTMAN=true
        INSTALL_JB_TOOLBOX=false
        INSTALL_JB_RIDER=true
        INSTALL_JB_DATAGRIP=true
        INSTALL_CURSOR=true
        INSTALL_VSCODE=true
        INSTALL_WINDSURF=false
        INSTALL_MISE_RUNTIMES=true
        INSTALL_CLAUDE_CODE=true
        SYNC_HYPR_CONFIGS=true
        if [[ "$hw_model" == *"XPS"* ]]; then
          SETUP_DELL_XPS_9320=true
        fi
        ;;
      x|X) # Prosseguir
        break
        ;;
      q|Q) # Sair
        echo "Saindo..."
        exit 0
        ;;
      *) 
        echo "Opção inválida!"
        sleep 1
        ;;
    esac
  done
}

# Configurar DNS temporário para a sessão
setup_temporary_dns() {
  info "Configurando DNS temporário (8.8.8.8, 1.1.1.1) para esta sessão..."
  
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] DNS temporário simulado"
    return 0
  fi
  
  # Salvar resolv.conf original
  if [[ -f /etc/resolv.conf ]]; then
    sudo cp /etc/resolv.conf /tmp/resolv.conf.backup.$$
    log "Backup do resolv.conf salvo em /tmp/resolv.conf.backup.$$"
  fi
  
  # Configurar DNS temporário
  echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" | sudo tee /tmp/resolv.conf.temp > /dev/null
  sudo mount --bind /tmp/resolv.conf.temp /etc/resolv.conf
  
  log "DNS temporário configurado (8.8.8.8, 1.1.1.1)"
  
  # Registrar cleanup function
  trap restore_dns EXIT
}

# Restaurar DNS original
restore_dns() {
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] Restauração de DNS simulada"
    return 0
  fi
  
  if [[ -f /tmp/resolv.conf.backup.$$ ]]; then
    info "Restaurando DNS original..."
    sudo umount /etc/resolv.conf 2>/dev/null || true
    sudo mv /tmp/resolv.conf.backup.$$ /etc/resolv.conf
    log "DNS original restaurado"
  fi
  
  # Limpar arquivo temporário
  sudo rm -f /tmp/resolv.conf.temp
}

require_sudo() {
  if [[ ${EUID:-0} -eq 0 ]]; then
    warn "Execute este script como usuário normal (não root)."
  fi
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] Sudo check simulado"
    return 0
  fi
  if ! sudo -v; then
    err "sudo requerido."
    exit 1
  fi
}

ensure_tools() {
  info "Atualizando índices do pacman e garantindo dependências base"
  
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] Instalação de ferramentas base simulada"
    log "[DEBUG] Pacotes base OK (simulado)"
  else
    sudo pacman -Sy --noconfirm --needed base-devel git curl jq ca-certificates unzip rsync
    log "Pacotes base OK"
  fi

  if ! command -v yay >/dev/null 2>&1; then
    err "yay não encontrado. O Omarchy deveria trazer o yay. Aborte ou instale o yay manualmente."
    exit 1
  fi
  log "AUR helper: yay"
}

pac() {
  local pkg="$1"
  
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] Instalação simulada: pacman -S $@"
    INSTALLED_PACKAGES+=("$pkg (pacman) [DEBUG]")
    return 0
  fi
  
  if sudo pacman -S --noconfirm --needed "$@"; then
    INSTALLED_PACKAGES+=("$pkg (pacman)")
  else
    FAILED_PACKAGES+=("$pkg (pacman)")
    return 1
  fi
}

aur() {
  local pkg="$1"
  
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] Instalação simulada: yay -S $@"
    INSTALLED_PACKAGES+=("$pkg (AUR) [DEBUG]")
    return 0
  fi
  
  if yay -S --noconfirm --needed --sudoloop "$@" 2>&1 | grep -v "cannot use yay as root"; then
    INSTALLED_PACKAGES+=("$pkg (AUR)")
  else
    FAILED_PACKAGES+=("$pkg (AUR)")
    return 1
  fi
}

setup_dell_xps_9320_webcam() {
  info "Configurando webcam para Dell XPS 13 Plus (9320)"
  
  # Instalar dependências essenciais primeiro
  info "Instalando libcamera e pipewire-libcamera (obrigatórios para webcam)..."
  pac libcamera || warn "Falha ao instalar libcamera"
  pac pipewire-libcamera || warn "Falha ao instalar pipewire-libcamera"
  
  # Instalar ivsc-driver do AUR
  info "Instalando driver IVSC para webcam..."
  if aur ivsc-driver; then
    log "Driver IVSC instalado"
  else
    warn "Falha ao instalar ivsc-driver. Tentando método alternativo..."
    
    # Método alternativo: compilar do fonte
    local tmpdir=$(mktemp -d)
    cd "$tmpdir" || return 1
    
    info "Clonando repositório ivsc-driver..."
    if git clone https://github.com/intel/ivsc-driver.git; then
      cd ivsc-driver || return 1
      info "Compilando driver..."
      if make && sudo make install; then
        log "Driver IVSC compilado e instalado"
        sudo modprobe intel_vsc
        sudo modprobe mei_csi
        sudo modprobe mei_ace
      else
        warn "Falha ao compilar driver IVSC"
      fi
    else
      warn "Falha ao clonar repositório do driver"
    fi
    
    cd - >/dev/null || true
    rm -rf "$tmpdir"
  fi
  
  # Instalar ipu6-camera-bins e ipu6-camera-hal do AUR
  info "Instalando binários e HAL da câmera IPU6..."
  aur ipu6-camera-bins || warn "Falha ao instalar ipu6-camera-bins"
  aur ipu6-camera-hal || warn "Falha ao instalar ipu6-camera-hal"
  
  # Configurar firmware se necessário
  info "Verificando firmware da câmera..."
  if [[ ! -f /lib/firmware/intel/ipu6_fw.bin ]]; then
    warn "Firmware IPU6 não encontrado. Pode ser necessário instalar manualmente."
  else
    log "Firmware IPU6 presente"
  fi
  
  # Criar regras udev se necessário
  info "Configurando regras udev para câmera..."
  local udev_rule="/etc/udev/rules.d/99-ipu6-camera.rules"
  if [[ ! -f "$udev_rule" ]]; then
    echo 'SUBSYSTEM=="video4linux", ATTR{name}=="Intel IPU6 Camera", MODE="0666"' | sudo tee "$udev_rule" > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    log "Regras udev configuradas"
  else
    log "Regras udev já existentes"
  fi
  
  # Adicionar módulos ao carregamento automático
  info "Configurando módulos para carregamento automático..."
  local modules=("intel_vsc" "mei_csi" "mei_ace")
  for mod in "${modules[@]}"; do
    if ! grep -q "^$mod$" /etc/modules-load.d/ipu6.conf 2>/dev/null; then
      echo "$mod" | sudo tee -a /etc/modules-load.d/ipu6.conf > /dev/null
    fi
  done
  log "Módulos configurados para carregamento automático"
  
  # Testar se a câmera está funcionando
  info "Verificando se a câmera foi detectada..."
  if ls /dev/video* 2>/dev/null | grep -q video; then
    log "Dispositivos de vídeo detectados: $(ls /dev/video* 2>/dev/null | tr '\n' ' ')"
  else
    warn "Nenhum dispositivo de vídeo detectado. Pode ser necessário reiniciar."
  fi
  
  CONFIGURED_RUNTIMES+=("Webcam Dell XPS 9320")
}

setup_dell_xps_9320_optimizations() {
  info "Aplicando otimizações para Dell XPS 13 Plus (9320)"
  
  # Instalar ferramentas de gerenciamento de energia
  pac thermald || warn "Falha ao instalar thermald"
  pac powertop || warn "Falha ao instalar powertop"
  
  # Habilitar thermald
  sudo systemctl enable --now thermald.service || warn "Falha ao habilitar thermald"
  
  # Configurar TLP se disponível
  if pac tlp tlp-rdw; then
    sudo systemctl enable --now tlp.service
    log "TLP configurado para gerenciamento de energia"
  else
    warn "Falha ao instalar TLP"
  fi
  
  # Configuração de áudio (se necessário)
  info "Verificando configuração de áudio..."
  if ! lspci | grep -q "Audio device.*Tiger Lake"; then
    warn "Hardware de áudio não detectado como Tiger Lake"
  else
    log "Hardware de áudio Tiger Lake detectado"
  fi
  
  CONFIGURED_RUNTIMES+=("Otimizações Dell XPS 9320")
}

install_core_apps() {
  info "Instalando aplicações selecionadas..."
  
  if [[ "$INSTALL_GOOGLE_CHROME" == true ]]; then
    info "Instalando Google Chrome..."
    aur google-chrome || warn "Falha no Google Chrome (AUR)"
  fi
  
  if [[ "$INSTALL_COPYQ" == true ]]; then
    info "Instalando CopyQ..."
    pac copyq || warn "Falha instalando copyq"
  fi
  
  if [[ "$INSTALL_DROPBOX" == true ]]; then
    info "Instalando Dropbox..."
    if aur dropbox; then
      # Dropbox AUR package não inclui serviço systemd
      # Usuário deve iniciar manualmente ou configurar autostart
      info "Dropbox instalado. Para iniciar: dropbox start -i"
      CONFIGURED_RUNTIMES+=("Dropbox (instalar manualmente: dropbox start -i)")
    else
      warn "Falha no dropbox (AUR)"
    fi
  fi
  
  if [[ "$INSTALL_AWS_VPN" == true ]]; then
    info "Instalando AWS VPN Client..."
    if aur awsvpnclient; then
      # Configurar systemd-resolved se necessário
      info "Configurando serviços para AWS VPN Client..."
      
      # Verificar se systemd-resolved está habilitado
      if ! systemctl is-enabled systemd-resolved.service >/dev/null 2>&1; then
        info "Habilitando systemd-resolved para suporte DNS do VPN..."
        sudo systemctl enable --now systemd-resolved.service || warn "Falha ao habilitar systemd-resolved"
      fi
      
      # Habilitar e iniciar o serviço awsvpnclient
      info "Habilitando serviço AWS VPN Client..."
      sudo systemctl enable --now awsvpnclient || warn "Falha ao habilitar awsvpnclient.service"
      
      CONFIGURED_RUNTIMES+=("AWS VPN Client (serviços configurados)")
    else
      warn "Falha no AWS VPN Client (AUR)"
    fi
  fi
  
  if [[ "$INSTALL_POSTMAN" == true ]]; then
    info "Instalando Postman..."
    aur postman-bin || aur postman || warn "Falha no Postman (AUR)"
  fi
  
  if [[ "$INSTALL_JB_TOOLBOX" == true ]]; then
    info "Instalando JetBrains Toolbox..."
    aur jetbrains-toolbox || warn "Falha no JetBrains Toolbox (AUR)"
  fi
  
  if [[ "$INSTALL_JB_RIDER" == true ]]; then
    info "Instalando JetBrains Rider..."
    aur rider || warn "Falha no Rider (AUR)"
  fi
  
  if [[ "$INSTALL_JB_DATAGRIP" == true ]]; then
    info "Instalando JetBrains DataGrip..."
    aur datagrip || warn "Falha no DataGrip (AUR)"
  fi
  
  if [[ "$INSTALL_CURSOR" == true ]]; then
    info "Instalando Cursor IDE..."
    aur cursor-bin || warn "Falha no Cursor (AUR)"
  fi
  
  if [[ "$INSTALL_VSCODE" == true ]]; then
    info "Instalando Visual Studio Code..."
    aur visual-studio-code-bin || warn "Falha no VSCode (AUR)"
  fi
  
  if [[ "$INSTALL_WINDSURF" == true ]]; then
    info "Instalando Windsurf IDE..."
    aur windsurf-bin || warn "Falha no Windsurf (AUR)"
  fi
}

activate_mise_in_shell() {
  if command -v mise >/dev/null 2>&1; then
    # shellcheck disable=SC1090
    eval "$(mise activate bash)" || true
  else
    warn "mise não encontrado no PATH. Ajuste seu shell init."
  fi
}

configure_mise_runtimes() {
  if [[ "$INSTALL_MISE_RUNTIMES" != true ]]; then
    info "Pulando configuração do mise (não selecionado)"
    return 0
  fi
  
  if ! command -v mise >/dev/null 2>&1; then
    warn "Pulando configuração do mise: comando não encontrado."
    return 0
  fi

  # Verificar se Node já está instalado
  if mise list node 2>/dev/null | grep -q "node.*${DEFAULT_NODE}"; then
    info "Node ${DEFAULT_NODE} já instalado via mise"
    # Verificar se há atualizações disponíveis
    info "Verificando atualizações para Node ${DEFAULT_NODE}..."
    mise install "node@${DEFAULT_NODE}" 2>/dev/null || true
    mise use -g "node@${DEFAULT_NODE}" 2>/dev/null || warn "Falha em definir node@${DEFAULT_NODE} como global"
    SKIPPED_PACKAGES+=("node@${DEFAULT_NODE}")
  else
    info "Instalando Node via mise: ${DEFAULT_NODE}"
    if mise install "node@${DEFAULT_NODE}"; then
      CONFIGURED_RUNTIMES+=("node@${DEFAULT_NODE}")
      mise use -g "node@${DEFAULT_NODE}" || warn "Falha em definir node@${DEFAULT_NODE} como global"
    else
      warn "Falha em instalar node@${DEFAULT_NODE}"
      FAILED_PACKAGES+=("node@${DEFAULT_NODE}")
    fi
  fi

  info ".NET via mise: default ${DEFAULT_DOTNET_DEFAULT} + extras ${EXTRA_DOTNET[*]}"
  local dotnet_pkgs=("dotnet@${DEFAULT_DOTNET_DEFAULT}")
  for v in "${EXTRA_DOTNET[@]}"; do
    dotnet_pkgs+=("dotnet@${v}")
  done
  
  for pkg in "${dotnet_pkgs[@]}"; do
    local version="${pkg#dotnet@}"
    if mise list dotnet 2>/dev/null | grep -q "dotnet.*${version}"; then
      info "${pkg} já instalado via mise"
      SKIPPED_PACKAGES+=("$pkg")
    else
      if mise install "$pkg"; then
        CONFIGURED_RUNTIMES+=("$pkg")
      else
        warn "Falha instalando $pkg"
        FAILED_PACKAGES+=("$pkg")
      fi
    fi
  done
  
  mise use -g "dotnet@${DEFAULT_DOTNET_DEFAULT}" || warn "Falha definindo .NET global"
  mise reshim || true
  log "mise: Node e .NET configurados"
}

install_clis() {
  # Verificar se algum CLI foi selecionado
  if [[ "$INSTALL_CLAUDE_CODE" != true && "$INSTALL_CODEX_CLI" != true && "$INSTALL_GEMINI_CLI" != true ]]; then
    info "Pulando instalação de CLIs (nenhum selecionado)"
    return 0
  fi
  
  activate_mise_in_shell

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm não disponível após mise. Pulando instalação de CLIs npm."
    return 0
  fi

  # Claude Code CLI
  if [[ "$INSTALL_CLAUDE_CODE" == true ]]; then
    info "Instalando Claude Code CLI..."
    if npm install -g @anthropic-ai/claude-code; then
      INSTALLED_PACKAGES+=("@anthropic-ai/claude-code (npm)")
    else
      warn "Falha ao instalar @anthropic-ai/claude-code"
      FAILED_PACKAGES+=("@anthropic-ai/claude-code (npm)")
    fi
  fi

  # Codex CLI
  if [[ "$INSTALL_CODEX_CLI" == true ]]; then
    info "Instalando Codex CLI..."
    if npm install -g @openai/codex; then
      INSTALLED_PACKAGES+=("@openai/codex (npm)")
    else
      warn "Falha ao instalar @openai/codex"
      FAILED_PACKAGES+=("@openai/codex (npm)")
    fi
  fi

  # Gemini CLI
  if [[ "$INSTALL_GEMINI_CLI" == true ]]; then
    info "Instalando Gemini CLI..."
    if npm install -g @google/gemini-cli; then
      INSTALLED_PACKAGES+=("@google/gemini-cli (npm)")
    else
      warn "Falha ao instalar @google/gemini-cli"
      FAILED_PACKAGES+=("@google/gemini-cli (npm)")
    fi
  fi
}

sync_dir() {
  local src="$1" dst="$2"
  [[ -d "$src" ]] || { warn "Fonte não encontrada: $src"; return 0; }
  info "Sincronizando $src -> $dst"
  mkdir -p "$dst"
  local backup_dir
  backup_dir="${dst}.bak.$(date +%Y%m%d-%H%M%S)"
  # Backup rápido do destino inteiro antes do sync
  if [[ -n "$(ls -A "$dst" 2>/dev/null || true)" ]]; then
    cp -a "$dst" "$backup_dir" || warn "Backup falhou para $dst"
  fi
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src"/ "$dst"/
  else
    # Fallback simples: copiar recursivamente (sem delete de órfãos)
    cp -a "$src"/. "$dst"/
  fi
  log "Sync concluído: $dst (backup: ${backup_dir##*/})"
}

sync_hypr_configs() {
  if [[ "$SYNC_HYPR_CONFIGS" != true ]]; then
    info "Pulando sincronização de configurações Hypr (não selecionado)"
    return 0
  fi
  
  # hypr (padrão)
  if [[ -d "$HYPR_SRC_DIR" ]]; then
    sync_dir "$HYPR_SRC_DIR" "$HYPR_DST_DIR"
  else
    info "Diretório de origem Hypr não encontrado: $HYPR_SRC_DIR (ok)"
  fi
  # hyprl (variante custom)
  if [[ -d "$HYPRL_SRC_DIR" ]]; then
    sync_dir "$HYPRL_SRC_DIR" "$HYPRL_DST_DIR"
  else
    info "Diretório de origem Hyprl não encontrado: $HYPRL_SRC_DIR (ok)"
  fi
}

print_summary() {
  echo
  echo "======================================"
  echo "         SUMÁRIO DA INSTALAÇÃO"
  echo "======================================"
  echo
  
  if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
    log "Pacotes instalados com sucesso:"
    for pkg in "${INSTALLED_PACKAGES[@]}"; do
      echo "  ✓ $pkg"
    done
    echo
  fi
  
  if [[ ${#CONFIGURED_RUNTIMES[@]} -gt 0 ]]; then
    log "Runtimes/Configurações aplicadas:"
    for rt in "${CONFIGURED_RUNTIMES[@]}"; do
      echo "  ✓ $rt"
    done
    echo
  fi
  
  if [[ ${#SKIPPED_PACKAGES[@]} -gt 0 ]]; then
    info "Pacotes/Runtimes já instalados (pulados):"
    for pkg in "${SKIPPED_PACKAGES[@]}"; do
      echo "  ⏩ $pkg"
    done
    echo
  fi
  
  if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    warn "Pacotes que falharam na instalação:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
      echo "  ✗ $pkg"
    done
    echo
  fi
  
  # Informações adicionais
  if [[ "$SYNC_HYPR_CONFIGS" == true ]] && [[ -d "$HYPR_DST_DIR" ]]; then
    log "Configurações Hypr sincronizadas em: $HYPR_DST_DIR"
  fi
  if [[ "$SYNC_HYPR_CONFIGS" == true ]] && [[ -d "$HYPRL_DST_DIR" ]]; then
    log "Configurações Hyprl sincronizadas em: $HYPRL_DST_DIR"
  fi
  
  echo
  echo "======================================"
  if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
    log "✨ Setup concluído com sucesso!"
  else
    warn "⚠️  Setup concluído com alguns erros. Verifique os pacotes que falharam."
  fi
  echo "======================================"
  
  if [[ "$SETUP_DELL_XPS_9320" == true ]]; then
    echo
    echo -e "${YELLOW}📌 Nota sobre Dell XPS 13 Plus:${NC}"
    echo "   - A webcam pode precisar de reinicialização para funcionar"
    echo "   - Execute 'sudo dmesg | grep -i ipu6' para verificar o status"
    echo "   - Use 'v4l2-ctl --list-devices' para listar dispositivos de vídeo"
    echo
    echo -e "${YELLOW}📌 IMPORTANTE para Chromium/Chrome usar a webcam:${NC}"
    echo "   - Adicione a flag: --enable-features=WebRTCPipeWireCapturer"
    echo "   - Para Chrome/Chromium permanente, edite o .desktop ou crie alias:"
    echo "     alias chromium='chromium --enable-features=WebRTCPipeWireCapturer'"
  fi
  
  if [[ "$INSTALL_AWS_VPN" == true ]]; then
    echo
    echo -e "${YELLOW}📌 Nota sobre AWS VPN Client:${NC}"
    echo "   - systemd-resolved foi habilitado para suporte DNS"
    echo "   - O serviço awsvpnclient foi habilitado e iniciado"
    echo "   - Para conectar, use o aplicativo AWS VPN Client"
  fi
}

main() {
  # Configurar DNS temporário no início
  setup_temporary_dns
  
  # Verificar se deve rodar em modo interativo
  local no_menu=false
  for arg in "$@"; do
    if [[ "$arg" == "--no-menu" ]]; then
      no_menu=true
    fi
  done
  
  if [[ "$no_menu" == false ]]; then
    interactive_menu
  fi
  
  # Confirmar seleções
  clear
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}     Resumo da Instalação${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo
  echo "Os seguintes componentes serão instalados:"
  echo
  [[ "$INSTALL_GOOGLE_CHROME" == true ]] && echo "  • Google Chrome"
  [[ "$INSTALL_COPYQ" == true ]] && echo "  • CopyQ"
  [[ "$INSTALL_DROPBOX" == true ]] && echo "  • Dropbox"
  [[ "$INSTALL_AWS_VPN" == true ]] && echo "  • AWS VPN Client"
  [[ "$INSTALL_POSTMAN" == true ]] && echo "  • Postman"
  [[ "$INSTALL_JB_TOOLBOX" == true ]] && echo "  • JetBrains Toolbox"
  [[ "$INSTALL_JB_RIDER" == true ]] && echo "  • Rider"
  [[ "$INSTALL_JB_DATAGRIP" == true ]] && echo "  • DataGrip"
  [[ "$INSTALL_CURSOR" == true ]] && echo "  • Cursor IDE"
  [[ "$INSTALL_VSCODE" == true ]] && echo "  • Visual Studio Code"
  [[ "$INSTALL_WINDSURF" == true ]] && echo "  • Windsurf IDE"
  [[ "$INSTALL_MISE_RUNTIMES" == true ]] && echo "  • Mise Runtimes (Node.js + .NET)"
  [[ "$INSTALL_CLAUDE_CODE" == true ]] && echo "  • Claude Code CLI"
  [[ "$INSTALL_CODEX_CLI" == true ]] && echo "  • Codex CLI (OpenAI)"
  [[ "$INSTALL_GEMINI_CLI" == true ]] && echo "  • Gemini CLI (Google)"
  [[ "$SYNC_HYPR_CONFIGS" == true ]] && echo "  • Sincronizar configs Hypr"
  [[ "$SETUP_DELL_XPS_9320" == true ]] && echo "  • Configurações Dell XPS 9320"
  echo
  echo -n "Deseja continuar? (s/N): "
  read -r confirm
  if [[ "$confirm" != "s" ]] && [[ "$confirm" != "S" ]]; then
    echo "Instalação cancelada."
    exit 0
  fi
  
  require_sudo
  ensure_tools
  install_core_apps
  
  if [[ "$SETUP_DELL_XPS_9320" == true ]]; then
    setup_dell_xps_9320_webcam
    setup_dell_xps_9320_optimizations
  fi
  
  activate_mise_in_shell
  configure_mise_runtimes
  install_clis
  sync_hypr_configs
  
  print_summary
}

main "$@"