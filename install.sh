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
# Por padrão, tudo marcado exceto JetBrains Toolbox
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
INSTALL_JB_TOOLBOX=false  # Por padrão, instalar IDEs separadamente
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
SETUP_DELL_XPS_9320=false
SETUP_DUAL_KEYBOARD=false  # BR + US Internacional para Dell XPS
INSTALL_CHEZMOI=true
INSTALL_AGE=true
SETUP_DOTFILES_MANAGEMENT=false

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

# Configurações de log
LOG_DIR="$HOME/.local/share/exarch-install"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S).log"
LOG_SUMMARY="$LOG_DIR/install_$(date +%Y%m%d_%H%M%S)_summary.txt"

# Função para escrever no arquivo de log
write_log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

# Função para escrever no sumário
write_summary() {
  echo "$*" >> "$LOG_SUMMARY"
}

# Inicializar arquivos de log
echo "==========================================================" > "$LOG_FILE"
echo "EXARCH INSTALL LOG - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"
echo "==========================================================" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

echo "==========================================================" > "$LOG_SUMMARY"
echo "EXARCH INSTALL SUMMARY - $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_SUMMARY"
echo "==========================================================" >> "$LOG_SUMMARY"
echo "" >> "$LOG_SUMMARY"

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
  echo -e "  ${num}) [$([ "$INSTALL_FIREFOX" == true ] && echo '✓' || echo ' ')] Firefox - Navegador web"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_COPYQ" == true ] && echo '✓' || echo ' ')] CopyQ - Gerenciador de clipboard"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_DROPBOX" == true ] && echo '✓' || echo ' ')] Dropbox - Sincronização de arquivos"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_AWS_VPN" == true ] && echo '✓' || echo ' ')] AWS VPN Client"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_POSTMAN" == true ] && echo '✓' || echo ' ')] Postman - Teste de APIs"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_REMMINA" == true ] && echo '✓' || echo ' ')] Remmina - Cliente de desktop remoto"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_ESPANSO" == true ] && echo '✓' || echo ' ')] Espanso - Text expander (Wayland)"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_NANO" == true ] && echo '✓' || echo ' ')] Nano - Editor de texto simples"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_MICRO" == true ] && echo '✓' || echo ' ')] Micro - Editor de texto moderno"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_KATE" == true ] && echo '✓' || echo ' ')] Kate - Editor de texto avançado do KDE"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_SLACK" == true ] && echo '✓' || echo ' ')] Slack - Comunicação empresarial"; ((num++))
  echo -e "  ${num}) [$([ "$INSTALL_TEAMS" == true ] && echo '✓' || echo ' ')] Microsoft Teams - Comunicação empresarial"; ((num++))
  
  echo
  echo -e "${GREEN}🛠️ JetBrains IDEs ${EXATO_YELLOW}[20]${NC}:${NC}"
  if [[ "$INSTALL_JB_TOOLBOX" == true ]]; then
    echo -e "  ${num}) [✓] JetBrains Toolbox ${CYAN}(gerenciador de IDEs)${NC}"; ((num++))
    echo -e "  ${num}) [$([ "$INSTALL_JB_RIDER" == true ] && echo '✓' || echo ' ')] Rider ${EXATO_DARK}(via Toolbox)${NC}"; ((num++))
    echo -e "  ${num}) [$([ "$INSTALL_JB_DATAGRIP" == true ] && echo '✓' || echo ' ')] DataGrip ${EXATO_DARK}(via Toolbox)${NC}"; ((num++))
  else
    echo -e "  ${num}) [$([ "$INSTALL_JB_TOOLBOX" == true ] && echo '✓' || echo ' ')] JetBrains Toolbox (gerenciador de IDEs)"; ((num++))
    echo -e "  ${num}) [$([ "$INSTALL_JB_RIDER" == true ] && echo '✓' || echo ' ')] Rider - IDE para .NET ${EXATO_DARK}(instalação direta)${NC}"; ((num++))
    echo -e "  ${num}) [$([ "$INSTALL_JB_DATAGRIP" == true ] && echo '✓' || echo ' ')] DataGrip - IDE para bancos de dados ${EXATO_DARK}(instalação direta)${NC}"; ((num++))
  fi
  
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
  echo -e " ${num}) [$([ "$INSTALL_CHEZMOI" == true ] && echo '✓' || echo ' ')] Chezmoi - Gerenciador de dotfiles"; ((num++))
  echo -e " ${num}) [$([ "$INSTALL_AGE" == true ] && echo '✓' || echo ' ')] Age - Criptografia de arquivos"; ((num++))
  echo -e " ${num}) [$([ "$SETUP_DOTFILES_MANAGEMENT" == true ] && echo '✓' || echo ' ')] Configurar gerenciamento de dotfiles (Chezmoi + Age)"; ((num++))
  
  if [[ "$hw_model" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
    echo
    echo -e "${GREEN}💻 Hardware Específico ${EXATO_YELLOW}[50]${NC}:${NC}"
    echo -e " ${num}) [$([ "$SETUP_DELL_XPS_9320" == true ] && echo '✓' || echo ' ')] Configurar Dell XPS 13 Plus (webcam + otimizações)"; ((num++))
    echo -e " ${num}) [$([ "$SETUP_DUAL_KEYBOARD" == true ] && echo '✓' || echo ' ')] Teclados duplos: BR (padrão) + US Internacional"; ((num++))
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
  INSTALL_FIREFOX="${states[1]}"
  INSTALL_COPYQ="${states[2]}"
  INSTALL_DROPBOX="${states[3]}"
  INSTALL_AWS_VPN="${states[4]}"
  INSTALL_POSTMAN="${states[5]}"
  INSTALL_REMMINA="${states[6]}"
  INSTALL_ESPANSO="${states[7]}"
  INSTALL_NANO="${states[8]}"
  INSTALL_MICRO="${states[9]}"
  INSTALL_KATE="${states[10]}"
  INSTALL_SLACK="${states[11]}"
  INSTALL_TEAMS="${states[12]}"
  INSTALL_JB_TOOLBOX="${states[13]}"
  INSTALL_JB_RIDER="${states[14]}"
  INSTALL_JB_DATAGRIP="${states[15]}"
  INSTALL_CURSOR="${states[16]}"
  INSTALL_VSCODE="${states[17]}"
  INSTALL_WINDSURF="${states[18]}"
  INSTALL_MISE_RUNTIMES="${states[19]}"
  INSTALL_CLAUDE_CODE="${states[20]}"
  INSTALL_CODEX_CLI="${states[21]}"
  INSTALL_GEMINI_CLI="${states[22]}"
  SYNC_HYPR_CONFIGS="${states[23]}"
  INSTALL_CHEZMOI="${states[24]}"
  INSTALL_AGE="${states[25]}"
  SETUP_DOTFILES_MANAGEMENT="${states[26]}"
  if [[ ${#states[@]} -gt 27 ]]; then
    SETUP_DELL_XPS_9320="${states[27]}"
  fi
}

toggle_option() {
  case "$1" in
    0) INSTALL_GOOGLE_CHROME=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true) ;;
    1) INSTALL_FIREFOX=$([ "$INSTALL_FIREFOX" == true ] && echo false || echo true) ;;
    2) INSTALL_COPYQ=$([ "$INSTALL_COPYQ" == true ] && echo false || echo true) ;;
    3) INSTALL_DROPBOX=$([ "$INSTALL_DROPBOX" == true ] && echo false || echo true) ;;
    4) INSTALL_AWS_VPN=$([ "$INSTALL_AWS_VPN" == true ] && echo false || echo true) ;;
    5) INSTALL_POSTMAN=$([ "$INSTALL_POSTMAN" == true ] && echo false || echo true) ;;
    6) INSTALL_REMMINA=$([ "$INSTALL_REMMINA" == true ] && echo false || echo true) ;;
    7) INSTALL_ESPANSO=$([ "$INSTALL_ESPANSO" == true ] && echo false || echo true) ;;
    8) INSTALL_NANO=$([ "$INSTALL_NANO" == true ] && echo false || echo true) ;;
    9) INSTALL_MICRO=$([ "$INSTALL_MICRO" == true ] && echo false || echo true) ;;
    10) INSTALL_KATE=$([ "$INSTALL_KATE" == true ] && echo false || echo true) ;;
    11) INSTALL_SLACK=$([ "$INSTALL_SLACK" == true ] && echo false || echo true) ;;
    12) INSTALL_TEAMS=$([ "$INSTALL_TEAMS" == true ] && echo false || echo true) ;;
    13) 
      INSTALL_JB_TOOLBOX=$([ "$INSTALL_JB_TOOLBOX" == true ] && echo false || echo true)
      ;;
    14) 
      INSTALL_JB_RIDER=$([ "$INSTALL_JB_RIDER" == true ] && echo false || echo true)
      ;;
    15) 
      INSTALL_JB_DATAGRIP=$([ "$INSTALL_JB_DATAGRIP" == true ] && echo false || echo true)
      ;;
    16) INSTALL_CURSOR=$([ "$INSTALL_CURSOR" == true ] && echo false || echo true) ;;
    17) INSTALL_VSCODE=$([ "$INSTALL_VSCODE" == true ] && echo false || echo true) ;;
    18) INSTALL_WINDSURF=$([ "$INSTALL_WINDSURF" == true ] && echo false || echo true) ;;
    19) INSTALL_MISE_RUNTIMES=$([ "$INSTALL_MISE_RUNTIMES" == true ] && echo false || echo true) ;;
    20) INSTALL_CLAUDE_CODE=$([ "$INSTALL_CLAUDE_CODE" == true ] && echo false || echo true) ;;
    21) INSTALL_CODEX_CLI=$([ "$INSTALL_CODEX_CLI" == true ] && echo false || echo true) ;;
    22) INSTALL_GEMINI_CLI=$([ "$INSTALL_GEMINI_CLI" == true ] && echo false || echo true) ;;
    23) SYNC_HYPR_CONFIGS=$([ "$SYNC_HYPR_CONFIGS" == true ] && echo false || echo true) ;;
    24) INSTALL_CHEZMOI=$([ "$INSTALL_CHEZMOI" == true ] && echo false || echo true) ;;
    25) INSTALL_AGE=$([ "$INSTALL_AGE" == true ] && echo false || echo true) ;;
    26) SETUP_DOTFILES_MANAGEMENT=$([ "$SETUP_DOTFILES_MANAGEMENT" == true ] && echo false || echo true) ;;
    27) SETUP_DELL_XPS_9320=$([ "$SETUP_DELL_XPS_9320" == true ] && echo false || echo true) ;;
    28) SETUP_DUAL_KEYBOARD=$([ "$SETUP_DUAL_KEYBOARD" == true ] && echo false || echo true) ;;
    a|A) 
      local state=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true)
      INSTALL_GOOGLE_CHROME=$state
      INSTALL_FIREFOX=$state
      INSTALL_COPYQ=$state
      INSTALL_DROPBOX=$state
      INSTALL_AWS_VPN=$state
      INSTALL_POSTMAN=$state
      INSTALL_REMMINA=$state
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
        INSTALL_CHEZMOI=$state
        INSTALL_AGE=$state
        SETUP_DOTFILES_MANAGEMENT=$state
        if [[ "$(detect_hardware)" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
          SETUP_DELL_XPS_9320=$state
          SETUP_DUAL_KEYBOARD=$state
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
      INSTALL_CHEZMOI=true
      INSTALL_AGE=true
      SETUP_DOTFILES_MANAGEMENT=true
      if [[ "$(detect_hardware)" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
        SETUP_DELL_XPS_9320=true
        SETUP_DUAL_KEYBOARD=true
      fi
      ;;
  esac
}

interactive_menu() {
  local hw_model
  hw_model=$(detect_hardware)
  
  # Auto-configurar para Dell XPS 13 Plus
  if [[ "$hw_model" == *"XPS 13 9320"* ]] || [[ "$hw_model" == *"XPS 13 Plus"* ]] || [[ "$hw_model" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
    echo -e "${YELLOW}🔍 Dell XPS 13 Plus detectado - Marcando configurações de hardware específicas...${NC}"
    echo -e "${CYAN}Hardware detectado: '$hw_model'${NC}"
    SETUP_DELL_XPS_9320=true    # Auto-marcar configuração XPS
    SETUP_DUAL_KEYBOARD=true    # Auto-marcar teclados duplos
    echo -e "${GREEN}✓ Configurações marcadas: XPS=$SETUP_DELL_XPS_9320, Teclados=$SETUP_DUAL_KEYBOARD${NC}"
    sleep 2
  fi
  
  while true; do
    show_menu
    
    echo
    echo -n "Digite uma opção: "
    read -r choice
    
    case "$choice" in
      10) # Seção Aplicações (1-12)
        echo "Alternando seção Aplicações..."
        local state=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true)
        INSTALL_GOOGLE_CHROME=$state
        INSTALL_FIREFOX=$state
        INSTALL_COPYQ=$state
        INSTALL_DROPBOX=$state
        INSTALL_AWS_VPN=$state
        INSTALL_POSTMAN=$state
        INSTALL_REMMINA=$state
        INSTALL_ESPANSO=$state
        INSTALL_NANO=$state
        INSTALL_MICRO=$state
        INSTALL_KATE=$state
        INSTALL_SLACK=$state
        INSTALL_TEAMS=$state
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
      40) # Seção Configurações (12-15)
        echo "Alternando seção Configurações..."
        local state=$([ "$SYNC_HYPR_CONFIGS" == true ] && echo false || echo true)
        SYNC_HYPR_CONFIGS=$state
        INSTALL_CHEZMOI=$state
        INSTALL_AGE=$state
        SETUP_DOTFILES_MANAGEMENT=$state
        ;;
      50) # Seção Hardware (13) - se aplicável
        if [[ "$hw_model" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
          echo "Alternando seção Hardware..."
          SETUP_DELL_XPS_9320=$([ "$SETUP_DELL_XPS_9320" == true ] && echo false || echo true)
          SETUP_DUAL_KEYBOARD=$([ "$SETUP_DUAL_KEYBOARD" == true ] && echo false || echo true)
        fi
        ;;
      *[0-9]*) # Números individuais ou múltiplos
        # Dividir entrada por espaços e processar cada número
        for num in $choice; do
          if [[ "$num" =~ ^[0-9]+$ ]]; then
            local index=$((num - 1))
            toggle_option "$index"
          fi
        done
        ;;
      a|A) # Marcar/desmarcar todos
        local state=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true)
        INSTALL_GOOGLE_CHROME=$state
        INSTALL_FIREFOX=$state
        INSTALL_COPYQ=$state
        INSTALL_DROPBOX=$state
        INSTALL_AWS_VPN=$state
        INSTALL_POSTMAN=$state
        INSTALL_REMMINA=$state
        INSTALL_ESPANSO=$state
        INSTALL_NANO=$state
        INSTALL_MICRO=$state
        INSTALL_KATE=$state
        INSTALL_SLACK=$state
        INSTALL_TEAMS=$state
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
        INSTALL_CHEZMOI=$state
        INSTALL_AGE=$state
        SETUP_DOTFILES_MANAGEMENT=$state
        if [[ "$hw_model" == *"XPS"* ]] || [[ "$FORCE_XPS" == true ]]; then
          SETUP_DELL_XPS_9320=$state
        fi
        ;;
      r|R) # Recomendados
        INSTALL_GOOGLE_CHROME=true
        INSTALL_FIREFOX=true
        INSTALL_COPYQ=true
        INSTALL_DROPBOX=true
        INSTALL_AWS_VPN=false
        INSTALL_POSTMAN=false
        INSTALL_REMMINA=true
        INSTALL_ESPANSO=true
        INSTALL_NANO=true
        INSTALL_MICRO=true
        INSTALL_KATE=true
        INSTALL_SLACK=true
        INSTALL_TEAMS=true
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
        INSTALL_CHEZMOI=true
        INSTALL_AGE=true
        SETUP_DOTFILES_MANAGEMENT=false
        SETUP_DELL_XPS_9320=false
        SETUP_DUAL_KEYBOARD=false
        ;;
      d|D) # Desenvolvimento completo
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
        INSTALL_JB_TOOLBOX=false
        INSTALL_JB_RIDER=true
        INSTALL_JB_DATAGRIP=true
        INSTALL_CURSOR=true
        INSTALL_VSCODE=true
        INSTALL_WINDSURF=false
        INSTALL_MISE_RUNTIMES=true
        INSTALL_CLAUDE_CODE=true
        INSTALL_CODEX_CLI=true
        INSTALL_GEMINI_CLI=true
        SYNC_HYPR_CONFIGS=true
        SETUP_DELL_XPS_9320=false
        SETUP_DUAL_KEYBOARD=false
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
    write_summary "🔄 DEBUG: $pkg (pacman)"
    return 0
  fi
  
  # Verificar se já está instalado
  if pacman -Q "$pkg" &>/dev/null; then
    SKIPPED_PACKAGES+=("$pkg (pacman)")
    write_summary "⏩ Já instalado: $pkg (pacman)"
    return 0
  fi
  
  write_log "Tentando instalar $pkg via pacman..."
  if sudo pacman -S --noconfirm --needed "$@" 2>>"$LOG_FILE" 1>&2; then
    INSTALLED_PACKAGES+=("$pkg (pacman)")
    write_summary "✅ Instalado: $pkg (pacman)"
  else
    FAILED_PACKAGES+=("$pkg (pacman)")
    write_summary "❌ Falhou: $pkg (pacman)"
    return 1
  fi
}

aur() {
  local pkg="$1"
  
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] Instalação simulada: yay -S $@"
    INSTALLED_PACKAGES+=("$pkg (AUR) [DEBUG]")
    write_summary "🔄 DEBUG: $pkg (AUR)"
    return 0
  fi
  
  # Verificar se já está instalado
  if yay -Q "$pkg" &>/dev/null 2>&1; then
    SKIPPED_PACKAGES+=("$pkg (AUR)")
    write_summary "⏩ Já instalado: $pkg (AUR)"
    return 0
  fi
  
  write_log "Tentando instalar $pkg via yay (AUR)..."
  if yay -S --noconfirm --needed --sudoloop "$@" 2>&1 | tee -a "$LOG_FILE" | grep -v "cannot use yay as root"; then
    INSTALLED_PACKAGES+=("$pkg (AUR)")
    write_summary "✅ Instalado: $pkg (AUR)"
  else
    FAILED_PACKAGES+=("$pkg (AUR)")
    write_summary "❌ Falhou: $pkg (AUR)"
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

setup_fcitx5_br_layout() {
  local fcitx5_config_dir="$HOME/.config/fcitx5"
  local profile_file="$fcitx5_config_dir/profile"
  
  # Criar diretório se não existir
  mkdir -p "$fcitx5_config_dir"
  
  # Fazer backup se arquivo existir
  if [[ -f "$profile_file" ]]; then
    cp "$profile_file" "${profile_file}.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backup do fcitx5 profile criado"
  fi
  
  # Criar configuração com layout brasileiro
  cat > "$profile_file" << 'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=br
# Default Input Method
DefaultIM=keyboard-br

[Groups/0/Items/0]
# Name
Name=keyboard-br
# Layout
Layout=

[GroupOrder]
0=Default
EOF
  
  if [[ -f "$profile_file" ]]; then
    log "Layout de teclado brasileiro configurado no fcitx5"
    CONFIGURED_RUNTIMES+=("fcitx5 - layout brasileiro")
  else
    warn "Falha ao configurar fcitx5"
  fi
}

setup_fcitx5_dual_layout() {
  local fcitx5_config_dir="$HOME/.config/fcitx5"
  local profile_file="$fcitx5_config_dir/profile"
  
  # Criar diretório se não existir
  mkdir -p "$fcitx5_config_dir"
  
  # Fazer backup se arquivo existir
  if [[ -f "$profile_file" ]]; then
    cp "$profile_file" "${profile_file}.backup.$(date +%Y%m%d_%H%M%S)"
    log "Backup do fcitx5 profile criado"
  fi
  
  # Criar configuração com layouts duplos: BR (padrão) + US Internacional
  cat > "$profile_file" << 'EOF'
[Groups/0]
# Group Name
Name=Default
# Layout
Default Layout=br
# Default Input Method
DefaultIM=keyboard-br

[Groups/0/Items/0]
# Name
Name=keyboard-br
# Layout
Layout=

[Groups/0/Items/1]
# Name
Name=keyboard-us-intl
# Layout
Layout=

[GroupOrder]
0=Default
EOF
  
  if [[ -f "$profile_file" ]]; then
    log "Layouts duplos configurados no fcitx5: BR (padrão) + US Internacional"
    info "Para alternar entre teclados use: Ctrl+Espaço"
    CONFIGURED_RUNTIMES+=("fcitx5 - layouts duplos: BR + US Internacional")
  else
    warn "Falha ao configurar fcitx5 com layouts duplos"
  fi
}

setup_dell_xps_9320_optimizations() {
  info "Aplicando otimizações para Dell XPS 13 Plus (9320)"
  
  # Configurar layout(s) de teclado no fcitx5
  if [[ "$SETUP_DUAL_KEYBOARD" == true ]]; then
    info "Configurando layouts duplos: BR (padrão) + US Internacional no fcitx5..."
    setup_fcitx5_dual_layout
  else
    info "Configurando layout de teclado brasileiro no fcitx5..."
    setup_fcitx5_br_layout
  fi
  
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

configure_chromium_webcam() {
  # Configurar Chromium (padrão no Omarchy) para suporte à webcam no Wayland
  info "Configurando Chromium para webcam no Wayland..."
  
  # Criar diretório de configuração se não existir
  local config_dir="$HOME/.config"
  local chromium_flags_file="$HOME/.config/chromium-flags.conf"
  
  mkdir -p "$config_dir"
  
  # 1. Criar arquivo de flags para Chromium
  if [[ ! -f "$chromium_flags_file" ]]; then
    cat > "$chromium_flags_file" << 'EOF'
# Flags para Chromium no Wayland com suporte à webcam
--enable-features=WebRTCPipeWireCapturer
--ozone-platform=wayland
--enable-wayland-ime
EOF
    log "Arquivo de flags criado: $chromium_flags_file"
  else
    # Verificar se já tem a flag da webcam
    if ! grep -q "WebRTCPipeWireCapturer" "$chromium_flags_file"; then
      echo "--enable-features=WebRTCPipeWireCapturer" >> "$chromium_flags_file"
      log "Flag WebRTCPipeWireCapturer adicionada ao $chromium_flags_file"
    fi
  fi
  
  CONFIGURED_RUNTIMES+=("Chromium configurado para webcam no Wayland")
}

install_core_apps() {
  info "Instalando aplicações selecionadas..."
  
  # Configurar Chromium para suporte à webcam (padrão no Omarchy)
  info "Configurando Chromium para suporte à webcam no Wayland..."
  configure_chromium_webcam
  
  # Editores de texto opcionais
  if [[ "$INSTALL_NANO" == true ]]; then
    info "Instalando nano..."
    pac nano || warn "Falha instalando nano"
  fi
  
  if [[ "$INSTALL_MICRO" == true ]]; then
    info "Instalando micro..."
    pac micro || warn "Falha instalando micro"
  fi
  
  if [[ "$INSTALL_KATE" == true ]]; then
    info "Instalando Kate..."
    pac kate || warn "Falha instalando Kate"
  fi
  
  if [[ "$INSTALL_SLACK" == true ]]; then
    info "Instalando Slack..."
    aur slack-desktop || warn "Falha instalando Slack (AUR)"
  fi

  if [[ "$INSTALL_TEAMS" == true ]]; then
    info "Instalando Microsoft Teams..."
    aur teams-for-linux || warn "Falha instalando Teams (AUR)"
  fi
  
  if [[ "$INSTALL_GOOGLE_CHROME" == true ]]; then
    info "Instalando Google Chrome..."
    aur google-chrome || warn "Falha no Google Chrome (AUR)"
  fi
  
  if [[ "$INSTALL_FIREFOX" == true ]]; then
    info "Instalando Firefox..."
    pac firefox || warn "Falha instalando Firefox"
  fi
  
  if [[ "$INSTALL_COPYQ" == true ]]; then
    info "Instalando CopyQ..."
    pac copyq || warn "Falha instalando copyq"
  fi
  
  if [[ "$INSTALL_ESPANSO" == true ]]; then
    # Espanso - text expander para Wayland
    info "Instalando Espanso (text expander para Wayland)..."
    if aur espanso-wayland; then
      info "Configurando Espanso..."
      
      # Registrar o serviço do usuário
      if command -v espanso &>/dev/null; then
        # Registrar e habilitar o serviço systemd do usuário
        if espanso service register 2>/dev/null; then
          log "Serviço Espanso registrado com sucesso"
          
          # Iniciar o serviço
          if systemctl --user enable --now espanso.service 2>/dev/null; then
            log "Serviço Espanso habilitado e iniciado"
            
            # Criar configuração básica se não existir
            local config_dir="$HOME/.config/espanso"
            local config_file="$config_dir/match/base.yml"
            
            if [[ ! -f "$config_file" ]]; then
              mkdir -p "$config_dir/match"
              cat > "$config_file" << 'EOF'
matches:
  # Expansões básicas de exemplo
  - trigger: ":email"
    replace: "seu.email@exemplo.com"
  
  - trigger: ":date"
    replace: "{{mydate}}"
    vars:
      - name: mydate
        type: date
        params:
          format: "%Y-%m-%d"
  
  - trigger: ":time"
    replace: "{{mytime}}"
    vars:
      - name: mytime
        type: date
        params:
          format: "%H:%M"

  # Correções automáticas comuns
  - trigger: "teh"
    replace: "the"
  
  - trigger: "adn"
    replace: "and"
EOF
              log "Configuração básica do Espanso criada em $config_file"
            fi
            
            CONFIGURED_RUNTIMES+=("Espanso (text expander) - serviço habilitado")
          else
            warn "Falha ao habilitar serviço do Espanso - configure manualmente: systemctl --user enable --now espanso.service"
          fi
        else
          warn "Falha ao registrar serviço do Espanso - configure manualmente: espanso service register"
        fi
      else
        warn "Comando espanso não encontrado após instalação"
      fi
    else
      warn "Falha instalando espanso-wayland"
    fi
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
  
  if [[ "$INSTALL_REMMINA" == true ]]; then
    info "Instalando Remmina (cliente de desktop remoto)..."
    pac remmina || warn "Falha instalando Remmina"
    # Instalar plugins comuns do Remmina
    pac freerdp || warn "Falha instalando plugin RDP para Remmina"
    pac remmina-plugin-vnc || true  # Plugin VNC (pode não existir separado)
  fi
  
  # JetBrains Toolbox - Gerenciador oficial das IDEs JetBrains
  if [[ "$INSTALL_JB_TOOLBOX" == true ]]; then
    info "Instalando JetBrains Toolbox (gerenciador de IDEs)..."
    if aur jetbrains-toolbox; then
      log "JetBrains Toolbox instalado com sucesso!"
      
      # Tentar abrir o Toolbox automaticamente para o usuário configurar
      local ides_to_install=""
      local need_rider=false
      local need_datagrip=false
      
      if [[ "$INSTALL_JB_RIDER" == true ]]; then
        ides_to_install="Rider"
        need_rider=true
      fi
      if [[ "$INSTALL_JB_DATAGRIP" == true ]]; then
        if [[ -n "$ides_to_install" ]]; then
          ides_to_install="$ides_to_install e DataGrip"
        else
          ides_to_install="DataGrip"
        fi
        need_datagrip=true
      fi
      
      if [[ -n "$ides_to_install" ]]; then
        echo
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${YELLOW}     Configuração do JetBrains Toolbox${NC}"
        echo -e "${YELLOW}========================================${NC}"
        echo
        echo -e "${GREEN}📌 O Toolbox precisa ser configurado para instalar: $ides_to_install${NC}"
        echo
        echo "Opções disponíveis:"
        echo "  1) Abrir o Toolbox agora para configurar (recomendado)"
        echo "  2) Instalar $ides_to_install diretamente via AUR (sem Toolbox)"
        echo "  3) Pular e configurar manualmente depois"
        echo
        echo -n "Escolha uma opção (1/2/3): "
        read -r toolbox_choice
        
        case "$toolbox_choice" in
          1)
            echo
            info "Abrindo JetBrains Toolbox..."
            echo -e "${YELLOW}Por favor:${NC}"
            echo "  1. Faça login com sua conta JetBrains"
            echo "  2. Instale $ides_to_install através da interface"
            echo "  3. Pressione ENTER aqui quando terminar"
            echo
            
            # Tentar abrir o Toolbox em background
            if command -v jetbrains-toolbox &>/dev/null; then
              nohup jetbrains-toolbox &>/dev/null 2>&1 &
              echo "Toolbox aberto. Aguardando você configurar..."
              read -p "Pressione ENTER quando terminar de instalar as IDEs..."
              CONFIGURED_RUNTIMES+=("$ides_to_install (via Toolbox)")
            else
              warn "Não foi possível abrir o Toolbox automaticamente"
              echo "Execute 'jetbrains-toolbox' manualmente para configurar"
            fi
            ;;
          2)
            echo
            info "Instalando IDEs diretamente via AUR..."
            # Forçar instalação via AUR
            if [[ "$need_rider" == true ]]; then
              info "Instalando Rider via AUR..."
              aur rider || warn "Falha ao instalar Rider"
            fi
            if [[ "$need_datagrip" == true ]]; then
              info "Instalando DataGrip via AUR..."
              aur datagrip || warn "Falha ao instalar DataGrip"
            fi
            ;;
          3)
            echo
            info "Configuração manual selecionada"
            echo -e "${YELLOW}Lembre-se de abrir o Toolbox depois e instalar: $ides_to_install${NC}"
            CONFIGURED_RUNTIMES+=("$ides_to_install (pendente instalação via Toolbox)")
            ;;
          *)
            warn "Opção inválida. Configure manualmente depois."
            ;;
        esac
      fi
      
      echo
      echo -e "${GREEN}📌 Sobre o JetBrains Toolbox:${NC}"
      echo "   - Gerencia atualizações automaticamente"
      echo "   - Permite múltiplas versões das IDEs"
      echo "   - Acesse com: 'jetbrains-toolbox'"
      echo
    else
      warn "Falha ao instalar JetBrains Toolbox"
      # Se falhou Toolbox, oferecer instalação direta
      if [[ "$INSTALL_JB_RIDER" == true ]] || [[ "$INSTALL_JB_DATAGRIP" == true ]]; then
        echo -n "Deseja instalar Rider/DataGrip diretamente via AUR? (s/N): "
        read -r install_direct
        if [[ "$install_direct" == "s" ]] || [[ "$install_direct" == "S" ]]; then
          # Não zerar as flags, deixar instalar via AUR
          log "Instalação direta via AUR será realizada"
        else
          INSTALL_JB_RIDER=false
          INSTALL_JB_DATAGRIP=false
        fi
      fi
    fi
  else
    local toolbox_manages_ides=false
  fi
  
  # Só instalar Rider/DataGrip via AUR se NÃO estivermos usando Toolbox
  if [[ "$INSTALL_JB_RIDER" == true ]] && [[ "$INSTALL_JB_TOOLBOX" != true ]]; then
    # Verificar todas as possíveis instalações do Rider
    local rider_installed=false
    
    # Verificar instalação via pacman/AUR
    if pacman -Q rider &>/dev/null 2>&1; then
      warn "Rider já está instalado via AUR. Pulando..."
      SKIPPED_PACKAGES+=("rider (AUR) - já instalado")
      rider_installed=true
    fi
    
    # Verificar se existe no PATH (pode ter sido instalado via Toolbox)
    if [[ "$rider_installed" == false ]] && command -v rider &>/dev/null; then
      warn "Rider já está instalado (possivelmente via Toolbox). Pulando..."
      SKIPPED_PACKAGES+=("rider - já instalado via Toolbox")
      rider_installed=true
    fi
    
    # Verificar se o Toolbox tem o Rider instalado
    if [[ "$rider_installed" == false ]] && [[ -d "$HOME/.local/share/JetBrains/Toolbox/apps/Rider" ]]; then
      warn "Rider já está instalado via JetBrains Toolbox. Pulando..."
      SKIPPED_PACKAGES+=("rider - já instalado via Toolbox")
      rider_installed=true
    fi
    
    if [[ "$rider_installed" == false ]]; then
      info "Instalando JetBrains Rider (IDE .NET) via AUR..."
      aur rider || warn "Falha no Rider (AUR)"
    fi
  fi
  
  if [[ "$INSTALL_JB_DATAGRIP" == true ]] && [[ "$INSTALL_JB_TOOLBOX" != true ]]; then
    # Verificar todas as possíveis instalações do DataGrip
    local datagrip_installed=false
    
    # Verificar instalação via pacman/AUR
    if pacman -Q datagrip &>/dev/null 2>&1; then
      warn "DataGrip já está instalado via AUR. Pulando..."
      SKIPPED_PACKAGES+=("datagrip (AUR) - já instalado")
      datagrip_installed=true
    fi
    
    # Verificar se existe no PATH (pode ter sido instalado via Toolbox)
    if [[ "$datagrip_installed" == false ]] && command -v datagrip &>/dev/null; then
      warn "DataGrip já está instalado (possivelmente via Toolbox). Pulando..."
      SKIPPED_PACKAGES+=("datagrip - já instalado via Toolbox")
      datagrip_installed=true
    fi
    
    # Verificar se o Toolbox tem o DataGrip instalado
    if [[ "$datagrip_installed" == false ]] && [[ -d "$HOME/.local/share/JetBrains/Toolbox/apps/DataGrip" ]]; then
      warn "DataGrip já está instalado via JetBrains Toolbox. Pulando..."
      SKIPPED_PACKAGES+=("datagrip - já instalado via Toolbox")
      datagrip_installed=true
    fi
    
    if [[ "$datagrip_installed" == false ]]; then
      info "Instalando JetBrains DataGrip (IDE para bancos de dados) via AUR..."
      aur datagrip || warn "Falha no DataGrip (AUR)"
    fi
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

install_chezmoi_and_age() {
  if [[ "$INSTALL_CHEZMOI" != true ]] && [[ "$INSTALL_AGE" != true ]]; then
    info "Pulando instalação de Chezmoi e Age (nenhum selecionado)"
    return 0
  fi
  
  info "Instalando ferramentas de gerenciamento de dotfiles..."
  
  # Instalar Chezmoi
  if [[ "$INSTALL_CHEZMOI" == true ]]; then
    info "Instalando Chezmoi..."
    if pac chezmoi; then
      INSTALLED_PACKAGES+=("chezmoi (pacman)")
      log "Chezmoi instalado com sucesso"
    else
      warn "Falha ao instalar Chezmoi via pacman, tentando via AUR..."
      if aur chezmoi-bin; then
        INSTALLED_PACKAGES+=("chezmoi-bin (AUR)")
        log "Chezmoi instalado via AUR"
      else
        warn "Falha ao instalar Chezmoi"
        FAILED_PACKAGES+=("chezmoi")
      fi
    fi
  fi
  
  # Instalar Age
  if [[ "$INSTALL_AGE" == true ]]; then
    info "Instalando Age..."
    if pac age; then
      INSTALLED_PACKAGES+=("age (pacman)")
      log "Age instalado com sucesso"
    else
      warn "Falha ao instalar Age via pacman, tentando via AUR..."
      if aur age; then
        INSTALLED_PACKAGES+=("age (AUR)")
        log "Age instalado via AUR"
      else
        warn "Falha ao instalar Age"
        FAILED_PACKAGES+=("age")
      fi
    fi
  fi
}

setup_dotfiles_management() {
  if [[ "$SETUP_DOTFILES_MANAGEMENT" != true ]]; then
    info "Pulando configuração de gerenciamento de dotfiles (não selecionado)"
    return 0
  fi
  
  if ! command -v chezmoi >/dev/null 2>&1; then
    warn "Chezmoi não encontrado. Pulando configuração de dotfiles."
    return 0
  fi
  
  if ! command -v age >/dev/null 2>&1; then
    warn "Age não encontrado. Pulando configuração de dotfiles."
    return 0
  fi
  
  info "Configurando gerenciamento de dotfiles com Chezmoi e Age..."
  
  # Verificar se já existe um repositório de dotfiles configurado
  if [[ -d "$HOME/.local/share/chezmoi" ]]; then
    warn "Repositório de dotfiles já existe em ~/.local/share/chezmoi"
    echo -n "Deseja reconfigurar? (s/N): "
    read -r reconfigure
    if [[ "$reconfigure" != "s" ]] && [[ "$reconfigure" != "S" ]]; then
      info "Mantendo configuração existente"
      return 0
    fi
  fi
  
  echo
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}     Configuração de Dotfiles${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo
  echo "Para configurar o gerenciamento de dotfiles, você precisa:"
  echo "1. Um repositório Git com seus dotfiles"
  echo "2. Uma chave Age para criptografia (opcional)"
  echo
  echo "Opções disponíveis:"
  echo "  1) Configurar com repositório existente"
  echo "  2) Criar novo repositório de dotfiles"
  echo "  3) Configurar apenas Chezmoi (sem Age)"
  echo "  4) Pular configuração (configurar manualmente depois)"
  echo
  echo -n "Escolha uma opção (1/2/3/4): "
  read -r dotfiles_choice
  
  case "$dotfiles_choice" in
    1)
      echo
      echo -n "Digite a URL do seu repositório de dotfiles: "
      read -r repo_url
      if [[ -n "$repo_url" ]]; then
        info "Inicializando Chezmoi com repositório: $repo_url"
        if chezmoi init "$repo_url"; then
          log "Repositório inicializado com sucesso"
          
          # Perguntar sobre chave Age
          echo -n "Deseja configurar criptografia Age? (s/N): "
          read -r use_age
          if [[ "$use_age" == "s" ]] || [[ "$use_age" == "S" ]]; then
            setup_age_encryption
          fi
          
          # Aplicar dotfiles
          echo -n "Deseja aplicar os dotfiles agora? (s/N): "
          read -r apply_now
          if [[ "$apply_now" == "s" ]] || [[ "$apply_now" == "S" ]]; then
            info "Aplicando dotfiles..."
            chezmoi apply
            log "Dotfiles aplicados com sucesso"
          fi
          
          CONFIGURED_RUNTIMES+=("Chezmoi - repositório configurado: $repo_url")
        else
          warn "Falha ao inicializar repositório"
        fi
      fi
      ;;
    2)
      echo
      echo "Criando novo repositório de dotfiles..."
      echo -n "Digite o nome do repositório (ex: dotfiles): "
      read -r repo_name
      if [[ -n "$repo_name" ]]; then
        local repo_dir="$HOME/$repo_name"
        if mkdir -p "$repo_dir" && cd "$repo_dir"; then
          info "Inicializando repositório Git em: $repo_dir"
          git init
          
          # Criar estrutura básica
          mkdir -p home
          echo "# $repo_name" > README.md
          echo "Dotfiles gerenciados com Chezmoi" >> README.md
          
          # Criar arquivo de configuração Chezmoi
          cat > .chezmoi.toml << EOF
[data]
  name = "$(whoami)"
  email = "$(git config --global user.email 2>/dev/null || echo 'seu.email@exemplo.com')"
  hostname = "$(hostname)"
EOF
          
          # Fazer commit inicial
          git add .
          git commit -m "Initial commit: dotfiles setup"
          
          log "Repositório criado em: $repo_dir"
          echo "Para conectar ao GitHub/GitLab:"
          echo "  1. Crie um repositório remoto"
          echo "  2. Execute: git remote add origin <URL>"
          echo "  3. Execute: git push -u origin main"
          echo
          echo "Para usar com Chezmoi:"
          echo "  chezmoi init $repo_dir"
          
          CONFIGURED_RUNTIMES+=("Novo repositório de dotfiles: $repo_dir")
        else
          warn "Falha ao criar repositório"
        fi
      fi
      ;;
    3)
      echo
      info "Configurando Chezmoi sem criptografia..."
      echo -n "Digite a URL do seu repositório de dotfiles: "
      read -r repo_url
      if [[ -n "$repo_url" ]]; then
        if chezmoi init "$repo_url"; then
          log "Chezmoi configurado sem criptografia"
          CONFIGURED_RUNTIMES+=("Chezmoi - sem criptografia: $repo_url")
        else
          warn "Falha ao configurar Chezmoi"
        fi
      fi
      ;;
    4)
      echo
      info "Configuração manual selecionada"
      echo -e "${YELLOW}Para configurar manualmente:${NC}"
      echo "  1. Instale Chezmoi: chezmoi init <repo-url>"
      echo "  2. Configure Age: age-keygen -o ~/.config/age/keys.txt"
      echo "  3. Aplique dotfiles: chezmoi apply"
      echo
      echo "Documentação: https://www.chezmoi.io/"
      ;;
    *)
      warn "Opção inválida. Configure manualmente depois."
      ;;
  esac
}

setup_age_encryption() {
  info "Configurando criptografia Age..."
  
  local age_config_dir="$HOME/.config/age"
  local age_keys_file="$age_config_dir/keys.txt"
  
  # Criar diretório de configuração
  mkdir -p "$age_config_dir"
  
  # Verificar se já existe uma chave
  if [[ -f "$age_keys_file" ]]; then
    warn "Chave Age já existe em $age_keys_file"
    echo -n "Deseja gerar uma nova chave? (s/N): "
    read -r new_key
    if [[ "$new_key" != "s" ]] && [[ "$new_key" != "S" ]]; then
      info "Usando chave existente"
      return 0
    fi
  fi
  
  # Gerar nova chave Age
  info "Gerando nova chave Age..."
  if age-keygen -o "$age_keys_file"; then
    log "Chave Age gerada com sucesso"
    
    # Mostrar chave pública
    echo
    echo -e "${GREEN}Chave pública Age:${NC}"
    echo "----------------------------------------"
    age-keygen -y "$age_keys_file"
    echo "----------------------------------------"
    echo
    echo -e "${YELLOW}⚠️  IMPORTANTE:${NC}"
    echo "   - Guarde a chave pública acima no seu repositório de dotfiles"
    echo "   - A chave privada está em: $age_keys_file"
    echo "   - NUNCA compartilhe a chave privada"
    echo
    
    CONFIGURED_RUNTIMES+=("Age - criptografia configurada")
  else
    warn "Falha ao gerar chave Age"
  fi
}

retry_failed_packages() {
  if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
    log "Nenhum pacote falhou. Não há nada para tentar novamente."
    return 0
  fi
  
  echo
  echo -e "${YELLOW}========================================${NC}"
  echo -e "${YELLOW}     Retry de Pacotes Falhos${NC}"
  echo -e "${YELLOW}========================================${NC}"
  echo
  echo "Os seguintes pacotes falharam na instalação:"
  echo
  for pkg in "${FAILED_PACKAGES[@]}"; do
    echo "  • $pkg"
  done
  echo
  echo -n "Deseja tentar instalá-los novamente? (s/N): "
  read -r confirm
  
  if [[ "$confirm" != "s" ]] && [[ "$confirm" != "S" ]]; then
    return 0
  fi
  
  local retry_success=()
  local still_failed=()
  
  for pkg_info in "${FAILED_PACKAGES[@]}"; do
    # Extrair nome do pacote e método de instalação
    if [[ "$pkg_info" =~ ^(.+)\ \((pacman|AUR|npm)\)$ ]]; then
      local pkg_name="${BASH_REMATCH[1]}"
      local install_method="${BASH_REMATCH[2]}"
      
      info "Tentando reinstalar: $pkg_name ($install_method)"
      
      case "$install_method" in
        "pacman")
          if sudo pacman -S --noconfirm --needed "$pkg_name" 2>/dev/null; then
            retry_success+=("$pkg_info")
            INSTALLED_PACKAGES+=("$pkg_info (retry)")
          else
            still_failed+=("$pkg_info")
          fi
          ;;
        "AUR")
          if yay -S --noconfirm --needed --sudoloop "$pkg_name" 2>&1 | grep -v "cannot use yay as root" > /dev/null; then
            retry_success+=("$pkg_info")
            INSTALLED_PACKAGES+=("$pkg_info (retry)")
          else
            still_failed+=("$pkg_info")
          fi
          ;;
        "npm")
          if npm install -g "$pkg_name" 2>/dev/null; then
            retry_success+=("$pkg_info")
            INSTALLED_PACKAGES+=("$pkg_info (retry)")
          else
            still_failed+=("$pkg_info")
          fi
          ;;
      esac
    fi
  done
  
  # Atualizar a lista de pacotes falhos
  FAILED_PACKAGES=("${still_failed[@]}")
  
  echo
  if [[ ${#retry_success[@]} -gt 0 ]]; then
    log "Pacotes instalados com sucesso no retry:"
    for pkg in "${retry_success[@]}"; do
      echo "  ✓ $pkg"
    done
  fi
  
  if [[ ${#still_failed[@]} -gt 0 ]]; then
    warn "Pacotes que continuaram falhando:"
    for pkg in "${still_failed[@]}"; do
      echo "  ✗ $pkg"
    done
  fi
  
  return 0
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
  # Escrever informações finais no sumário
  write_summary ""
  write_summary "=========================================="
  write_summary "RESUMO FINAL"
  write_summary "=========================================="
  write_summary "Total instalados: ${#INSTALLED_PACKAGES[@]}"
  write_summary "Total pulados (já instalados): ${#SKIPPED_PACKAGES[@]}"
  write_summary "Total falhados: ${#FAILED_PACKAGES[@]}"
  write_summary ""
  
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
  
  if [[ "$INSTALL_ESPANSO" == true ]]; then
    echo
    echo -e "${YELLOW}📌 Nota sobre Espanso (text expander):${NC}"
    echo "   - Serviço habilitado automaticamente (systemctl --user)"
    echo "   - Configuração básica criada em ~/.config/espanso/match/base.yml"
    echo "   - Digite ':email', ':date', ':time' para testar"
    echo "   - Edite a configuração para adicionar suas próprias expansões"
    echo "   - Comando: 'espanso edit' para editar configurações"
  fi
  
  # Nota sobre Chezmoi e Age
  if [[ "$INSTALL_CHEZMOI" == true ]] || [[ "$INSTALL_AGE" == true ]]; then
    echo
    echo -e "${GREEN}📌 Nota sobre Gerenciamento de Dotfiles:${NC}"
    if [[ "$INSTALL_CHEZMOI" == true ]]; then
      echo "   - Chezmoi instalado para gerenciar dotfiles"
      echo "   - Comandos básicos: chezmoi init, chezmoi apply, chezmoi diff"
      echo "   - Documentação: https://www.chezmoi.io/"
    fi
    if [[ "$INSTALL_AGE" == true ]]; then
      echo "   - Age instalado para criptografia de arquivos"
      echo "   - Comandos básicos: age-keygen, age -e, age -d"
      echo "   - Documentação: https://age-encryption.org/"
    fi
    if [[ "$SETUP_DOTFILES_MANAGEMENT" == true ]]; then
      echo "   - Configuração de dotfiles foi realizada"
      echo "   - Para aplicar mudanças: chezmoi apply"
      echo "   - Para ver diferenças: chezmoi diff"
    fi
  fi
  
  # Nota sobre Chromium (sempre configurado)
  echo
  echo -e "${GREEN}📌 Nota sobre Chromium:${NC}"
  echo "   - Webcam configurada automaticamente via PipeWire"
  echo "   - Flags aplicadas em: ~/.config/chromium-flags.conf"
  echo "   - A webcam funcionará em Google Meet, Zoom, Discord, etc."
}

post_install_options() {
  local should_retry=false
  local should_reboot=false
  
  # Opção de retry para pacotes falhos
  if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
    echo
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}     Opções Pós-Instalação${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo
    echo "Existem pacotes que falharam na instalação."
    echo -n "Deseja tentar instalá-los novamente? (s/N): "
    read -r retry_confirm
    
    if [[ "$retry_confirm" == "s" ]] || [[ "$retry_confirm" == "S" ]]; then
      retry_failed_packages
      
      # Mostrar sumário atualizado após retry
      echo
      echo -e "${CYAN}========================================${NC}"
      echo -e "${CYAN}     Sumário Atualizado${NC}"
      echo -e "${CYAN}========================================${NC}"
      
      if [[ ${#FAILED_PACKAGES[@]} -eq 0 ]]; then
        log "✨ Todos os pacotes foram instalados com sucesso após retry!"
      else
        warn "Ainda existem ${#FAILED_PACKAGES[@]} pacotes que falharam."
        for pkg in "${FAILED_PACKAGES[@]}"; do
          echo "  ✗ $pkg"
        done
      fi
    fi
  fi
  
  # Opção de reinicialização
  echo
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}     Finalização${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo
  
  # Determinar se reinicialização é recomendada
  local reboot_recommended=false
  if [[ "$SETUP_DELL_XPS_9320" == true ]]; then
    reboot_recommended=true
    echo -e "${YELLOW}⚠️  Reinicialização recomendada${NC} para aplicar configurações do Dell XPS."
  fi
  
  if [[ "$INSTALL_AWS_VPN" == true ]]; then
    reboot_recommended=true
    echo -e "${YELLOW}⚠️  Reinicialização recomendada${NC} para garantir que os serviços DNS estejam funcionando corretamente."
  fi
  
  # Verificar se algum driver ou módulo do kernel foi instalado
  if [[ "${INSTALLED_PACKAGES[@]}" =~ "ivsc-driver" ]] || [[ "${INSTALLED_PACKAGES[@]}" =~ "ipu6" ]]; then
    reboot_recommended=true
    echo -e "${YELLOW}⚠️  Reinicialização recomendada${NC} para carregar novos drivers/módulos do kernel."
  fi
  
  if [[ "$reboot_recommended" == true ]]; then
    echo
    echo -n "Deseja reiniciar o sistema agora? (s/N): "
  else
    echo -n "Deseja reiniciar o sistema? (s/N): "
  fi
  
  read -r reboot_confirm
  
  if [[ "$reboot_confirm" == "s" ]] || [[ "$reboot_confirm" == "S" ]]; then
    echo
    log "Sistema será reiniciado em 5 segundos..."
    echo "Pressione Ctrl+C para cancelar"
    
    # Não reiniciar em modo debug
    if [[ "$DEBUG_MODE" == true ]]; then
      info "[DEBUG] Reinicialização simulada - não será executada"
    else
      sleep 5
      sudo reboot
    fi
  else
    echo
    log "Setup finalizado. Reinicie o sistema quando conveniente."
  fi
  
  # Exibir informações sobre os arquivos de log
  echo
  echo "======================================"
  echo -e "${GREEN}📁 ARQUIVOS DE LOG GERADOS${NC}"
  echo "======================================"
  echo
  echo -e "${CYAN}Log completo:${NC}"
  echo "  $LOG_FILE"
  echo
  echo -e "${CYAN}Sumário de instalação:${NC}"
  echo "  $LOG_SUMMARY"
  echo
  echo -e "${YELLOW}💡 Dica:${NC} Use 'cat $LOG_SUMMARY' para ver o resumo"
  echo -e "${YELLOW}💡 Dica:${NC} Use 'less $LOG_FILE' para ver o log completo"
  echo
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
  echo "  • Configuração do Chromium para webcam (Wayland)"
  [[ "$INSTALL_GOOGLE_CHROME" == true ]] && echo "  • Google Chrome"
  [[ "$INSTALL_FIREFOX" == true ]] && echo "  • Firefox"
  [[ "$INSTALL_COPYQ" == true ]] && echo "  • CopyQ"
  [[ "$INSTALL_DROPBOX" == true ]] && echo "  • Dropbox"
  [[ "$INSTALL_AWS_VPN" == true ]] && echo "  • AWS VPN Client"
  [[ "$INSTALL_POSTMAN" == true ]] && echo "  • Postman"
  [[ "$INSTALL_REMMINA" == true ]] && echo "  • Remmina (desktop remoto)"
  [[ "$INSTALL_ESPANSO" == true ]] && echo "  • Espanso (text expander)"
  [[ "$INSTALL_NANO" == true ]] && echo "  • Nano (editor de texto)"
  [[ "$INSTALL_MICRO" == true ]] && echo "  • Micro (editor de texto moderno)"
  [[ "$INSTALL_KATE" == true ]] && echo "  • Kate (editor de texto avançado)"
  [[ "$INSTALL_SLACK" == true ]] && echo "  • Slack (comunicação empresarial)"
  [[ "$INSTALL_TEAMS" == true ]] && echo "  • Microsoft Teams (comunicação empresarial)"
  [[ "$INSTALL_JB_TOOLBOX" == true ]] && echo "  • JetBrains Toolbox"
  if [[ "$INSTALL_JB_TOOLBOX" == true ]]; then
    [[ "$INSTALL_JB_RIDER" == true ]] && echo "  • Rider (via Toolbox)"
    [[ "$INSTALL_JB_DATAGRIP" == true ]] && echo "  • DataGrip (via Toolbox)"
  else
    [[ "$INSTALL_JB_RIDER" == true ]] && echo "  • Rider (instalação direta)"
    [[ "$INSTALL_JB_DATAGRIP" == true ]] && echo "  • DataGrip (instalação direta)"
  fi
  [[ "$INSTALL_CURSOR" == true ]] && echo "  • Cursor IDE"
  [[ "$INSTALL_VSCODE" == true ]] && echo "  • Visual Studio Code"
  [[ "$INSTALL_WINDSURF" == true ]] && echo "  • Windsurf IDE"
  [[ "$INSTALL_MISE_RUNTIMES" == true ]] && echo "  • Mise Runtimes (Node.js + .NET)"
  [[ "$INSTALL_CLAUDE_CODE" == true ]] && echo "  • Claude Code CLI"
  [[ "$INSTALL_CODEX_CLI" == true ]] && echo "  • Codex CLI (OpenAI)"
  [[ "$INSTALL_GEMINI_CLI" == true ]] && echo "  • Gemini CLI (Google)"
  [[ "$INSTALL_CHEZMOI" == true ]] && echo "  • Chezmoi (gerenciador de dotfiles)"
  [[ "$INSTALL_AGE" == true ]] && echo "  • Age (criptografia de arquivos)"
  [[ "$SYNC_HYPR_CONFIGS" == true ]] && echo "  • Sincronizar configs Hypr"
  [[ "$SETUP_DOTFILES_MANAGEMENT" == true ]] && echo "  • Configurar gerenciamento de dotfiles"
  [[ "$SETUP_DELL_XPS_9320" == true ]] && echo "  • Configurações Dell XPS 9320"
  [[ "$SETUP_DUAL_KEYBOARD" == true ]] && echo "  • Teclados duplos BR + US Internacional"
  echo
  echo -n "Deseja continuar? (s/N): "
  read -r confirm
  if [[ "$confirm" != "s" ]] && [[ "$confirm" != "S" ]]; then
    echo "Instalação cancelada."
    write_summary "INSTALAÇÃO CANCELADA PELO USUÁRIO"
    echo
    echo "Log salvo em: $LOG_SUMMARY"
    exit 0
  fi
  
  # Registrar configurações selecionadas no log
  write_summary "CONFIGURAÇÕES SELECIONADAS:"
  write_summary "=========================================="
  [[ "$INSTALL_GOOGLE_CHROME" == true ]] && write_summary "• Google Chrome"
  [[ "$INSTALL_FIREFOX" == true ]] && write_summary "• Firefox"
  [[ "$INSTALL_COPYQ" == true ]] && write_summary "• CopyQ"
  [[ "$INSTALL_DROPBOX" == true ]] && write_summary "• Dropbox"
  [[ "$INSTALL_AWS_VPN" == true ]] && write_summary "• AWS VPN Client"
  [[ "$INSTALL_POSTMAN" == true ]] && write_summary "• Postman"
  [[ "$INSTALL_REMMINA" == true ]] && write_summary "• Remmina"
  [[ "$INSTALL_ESPANSO" == true ]] && write_summary "• Espanso"
  [[ "$INSTALL_NANO" == true ]] && write_summary "• Nano"
  [[ "$INSTALL_MICRO" == true ]] && write_summary "• Micro"
  [[ "$INSTALL_KATE" == true ]] && write_summary "• Kate"
  [[ "$INSTALL_SLACK" == true ]] && write_summary "• Slack"
  [[ "$INSTALL_TEAMS" == true ]] && write_summary "• Teams"
  [[ "$INSTALL_JB_TOOLBOX" == true ]] && write_summary "• JetBrains Toolbox"
  [[ "$INSTALL_JB_RIDER" == true ]] && write_summary "• Rider"
  [[ "$INSTALL_JB_DATAGRIP" == true ]] && write_summary "• DataGrip"
  [[ "$INSTALL_CURSOR" == true ]] && write_summary "• Cursor"
  [[ "$INSTALL_VSCODE" == true ]] && write_summary "• VS Code"
  [[ "$INSTALL_WINDSURF" == true ]] && write_summary "• Windsurf"
  [[ "$INSTALL_MISE_RUNTIMES" == true ]] && write_summary "• Mise Runtimes"
  [[ "$INSTALL_CLAUDE_CODE" == true ]] && write_summary "• Claude Code CLI"
  [[ "$INSTALL_CODEX_CLI" == true ]] && write_summary "• Codex CLI"
  [[ "$INSTALL_GEMINI_CLI" == true ]] && write_summary "• Gemini CLI"
  [[ "$INSTALL_CHEZMOI" == true ]] && write_summary "• Chezmoi"
  [[ "$INSTALL_AGE" == true ]] && write_summary "• Age"
  [[ "$SYNC_HYPR_CONFIGS" == true ]] && write_summary "• Sync Hypr Configs"
  [[ "$SETUP_DOTFILES_MANAGEMENT" == true ]] && write_summary "• Setup Dotfiles Management"
  [[ "$SETUP_DELL_XPS_9320" == true ]] && write_summary "• Dell XPS 9320 Config"
  [[ "$SETUP_DUAL_KEYBOARD" == true ]] && write_summary "• Dual Keyboard Setup"
  write_summary ""
  write_summary "INÍCIO DA INSTALAÇÃO: $(date '+%Y-%m-%d %H:%M:%S')"
  write_summary "=========================================="
  write_summary ""
  
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
  install_chezmoi_and_age
  setup_dotfiles_management
  sync_hypr_configs
  
  print_summary
  post_install_options
}

main "$@"