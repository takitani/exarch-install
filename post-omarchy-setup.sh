#!/usr/bin/env bash
set -euo pipefail

# ======================================
# Post-Omarchy setup (Arch + Hyprland)
# - Menu interativo para seleção de componentes
# - Suporte específico para Dell XPS 13 Plus (9320)
# - Usa exclusivamente yay (já presente no Omarchy)
# - Configura mise (já instalado): Node LTS + .NET 8/9
# ======================================

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
INSTALL_MISE_RUNTIMES=false
INSTALL_CLAUDE_CODE=false
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
NC='\033[0m' # No Color

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
  echo -e "${CYAN}========================================${NC}"
  echo -e "${CYAN}     Omarchy Post-Install Setup${NC}"
  echo -e "${CYAN}========================================${NC}"
  echo
  
  # Detectar hardware
  local hw_model
  hw_model=$(detect_hardware)
  if [[ "$hw_model" == *"XPS 13 9320"* ]] || [[ "$hw_model" == *"XPS 13 Plus"* ]]; then
    echo -e "${YELLOW}🔍 Hardware detectado: Dell XPS 13 Plus (9320)${NC}"
    echo -e "${YELLOW}   Configuração específica disponível!${NC}"
    echo
  fi
  
  echo -e "${PURPLE}Selecione os componentes para instalar:${NC}"
  echo
  echo -e "${GREEN}📦 Aplicações:${NC}"
  echo -e "  1) [$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo '✓' || echo ' ')] Google Chrome - Navegador web"
  echo -e "  2) [$([ "$INSTALL_COPYQ" == true ] && echo '✓' || echo ' ')] CopyQ - Gerenciador de clipboard"
  echo -e "  3) [$([ "$INSTALL_DROPBOX" == true ] && echo '✓' || echo ' ')] Dropbox - Sincronização de arquivos"
  echo -e "  4) [$([ "$INSTALL_AWS_VPN" == true ] && echo '✓' || echo ' ')] AWS VPN Client"
  echo -e "  5) [$([ "$INSTALL_POSTMAN" == true ] && echo '✓' || echo ' ')] Postman - Teste de APIs"
  echo
  echo -e "${GREEN}🛠️ JetBrains IDEs:${NC}"
  echo -e "  6) [$([ "$INSTALL_JB_TOOLBOX" == true ] && echo '✓' || echo ' ')] JetBrains Toolbox"
  echo -e "  7) [$([ "$INSTALL_JB_RIDER" == true ] && echo '✓' || echo ' ')] Rider - IDE para .NET"
  echo -e "  8) [$([ "$INSTALL_JB_DATAGRIP" == true ] && echo '✓' || echo ' ')] DataGrip - IDE para bancos de dados"
  echo
  echo -e "${GREEN}🚀 Desenvolvimento:${NC}"
  echo -e "  9) [$([ "$INSTALL_CURSOR" == true ] && echo '✓' || echo ' ')] Cursor - IDE com IA integrada"
  echo -e " 10) [$([ "$INSTALL_MISE_RUNTIMES" == true ] && echo '✓' || echo ' ')] Mise Runtimes (Node.js LTS + .NET 8/9)"
  echo -e " 11) [$([ "$INSTALL_CLAUDE_CODE" == true ] && echo '✓' || echo ' ')] Claude Code CLI"
  echo
  echo -e "${GREEN}⚙️ Configurações:${NC}"
  echo -e " 12) [$([ "$SYNC_HYPR_CONFIGS" == true ] && echo '✓' || echo ' ')] Sincronizar configurações Hypr/Hyprl"
  echo
  if [[ "$hw_model" == *"XPS"* ]]; then
    echo -e "${GREEN}💻 Hardware Específico:${NC}"
    echo -e " 13) [$([ "$SETUP_DELL_XPS_9320" == true ] && echo '✓' || echo ' ')] Configurar Dell XPS 13 Plus (webcam + otimizações)"
    echo
  fi
  echo -e "${CYAN}----------------------------------------${NC}"
  echo -e "  a) Marcar/Desmarcar todos"
  echo -e "  r) Recomendados (aplicações essenciais)"
  echo -e "  d) Desenvolvimento completo"
  echo -e "  x) Prosseguir com a instalação"
  echo -e "  q) Sair"
  echo
  echo -n "Escolha uma opção: "
}

toggle_option() {
  case "$1" in
    1) INSTALL_GOOGLE_CHROME=$([ "$INSTALL_GOOGLE_CHROME" == true ] && echo false || echo true) ;;
    2) INSTALL_COPYQ=$([ "$INSTALL_COPYQ" == true ] && echo false || echo true) ;;
    3) INSTALL_DROPBOX=$([ "$INSTALL_DROPBOX" == true ] && echo false || echo true) ;;
    4) INSTALL_AWS_VPN=$([ "$INSTALL_AWS_VPN" == true ] && echo false || echo true) ;;
    5) INSTALL_POSTMAN=$([ "$INSTALL_POSTMAN" == true ] && echo false || echo true) ;;
    6) INSTALL_JB_TOOLBOX=$([ "$INSTALL_JB_TOOLBOX" == true ] && echo false || echo true) ;;
    7) INSTALL_JB_RIDER=$([ "$INSTALL_JB_RIDER" == true ] && echo false || echo true) ;;
    8) INSTALL_JB_DATAGRIP=$([ "$INSTALL_JB_DATAGRIP" == true ] && echo false || echo true) ;;
    9) INSTALL_CURSOR=$([ "$INSTALL_CURSOR" == true ] && echo false || echo true) ;;
    10) INSTALL_MISE_RUNTIMES=$([ "$INSTALL_MISE_RUNTIMES" == true ] && echo false || echo true) ;;
    11) INSTALL_CLAUDE_CODE=$([ "$INSTALL_CLAUDE_CODE" == true ] && echo false || echo true) ;;
    12) SYNC_HYPR_CONFIGS=$([ "$SYNC_HYPR_CONFIGS" == true ] && echo false || echo true) ;;
    13) SETUP_DELL_XPS_9320=$([ "$SETUP_DELL_XPS_9320" == true ] && echo false || echo true) ;;
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
      INSTALL_MISE_RUNTIMES=$state
      INSTALL_CLAUDE_CODE=$state
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
      INSTALL_MISE_RUNTIMES=true
      INSTALL_CLAUDE_CODE=true
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
      INSTALL_MISE_RUNTIMES=true
      INSTALL_CLAUDE_CODE=true
      SYNC_HYPR_CONFIGS=true
      if [[ "$(detect_hardware)" == *"XPS"* ]]; then
        SETUP_DELL_XPS_9320=true
      fi
      ;;
  esac
}

interactive_menu() {
  while true; do
    show_menu
    read -r choice
    case "$choice" in
      [1-9]|1[0-3]) toggle_option "$choice" ;;
      a|A|r|R|d|D) toggle_option "$choice" ;;
      x|X) break ;;
      q|Q) 
        echo "Saindo..."
        exit 0
        ;;
      *) echo "Opção inválida!" ; sleep 1 ;;
    esac
  done
}

require_sudo() {
  if [[ ${EUID:-0} -eq 0 ]]; then
    warn "Execute este script como usuário normal (não root)."
  fi
  if ! sudo -v; then
    err "sudo requerido."
    exit 1
  fi
}

ensure_tools() {
  info "Atualizando índices do pacman e garantindo dependências base"
  sudo pacman -Sy --noconfirm --needed base-devel git curl jq ca-certificates unzip rsync
  log "Pacotes base OK"

  if ! command -v yay >/dev/null 2>&1; then
    err "yay não encontrado. O Omarchy deveria trazer o yay. Aborte ou instale o yay manualmente."
    exit 1
  fi
  log "AUR helper: yay"
}

pac() {
  local pkg="$1"
  if sudo pacman -S --noconfirm --needed "$@"; then
    INSTALLED_PACKAGES+=("$pkg (pacman)")
  else
    FAILED_PACKAGES+=("$pkg (pacman)")
    return 1
  fi
}

aur() {
  local pkg="$1"
  if yay -S --noconfirm --needed --sudoloop "$@" 2>&1 | grep -v "cannot use yay as root"; then
    INSTALLED_PACKAGES+=("$pkg (AUR)")
  else
    FAILED_PACKAGES+=("$pkg (AUR)")
    return 1
  fi
}

setup_dell_xps_9320_webcam() {
  info "Configurando webcam para Dell XPS 13 Plus (9320)"
  
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
    aur dropbox || warn "Falha no dropbox (AUR)"
    # Habilitar Dropbox (systemd --user) caso disponível
    if systemctl --user daemon-reload 2>/dev/null; then
      systemctl --user enable --now dropbox.service || warn "Não foi possível habilitar dropbox.service (user)"
    fi
  fi
  
  if [[ "$INSTALL_AWS_VPN" == true ]]; then
    info "Instalando AWS VPN Client..."
    if aur aws-vpn-client || aur awsvpnclient; then
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
  if [[ "$INSTALL_CLAUDE_CODE" != true ]]; then
    info "Pulando instalação do Claude Code (não selecionado)"
    return 0
  fi
  
  activate_mise_in_shell

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm não disponível após mise. Pulando instalação de CLIs npm."
    return 0
  fi

  info "Instalando Claude Code CLI..."
  if npm install -g @anthropic-ai/claude-code; then
    INSTALLED_PACKAGES+=("@anthropic-ai/claude-code (npm)")
  else
    warn "Falha ao instalar @anthropic-ai/claude-code"
    FAILED_PACKAGES+=("@anthropic-ai/claude-code (npm)")
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
  # Verificar se deve rodar em modo interativo
  if [[ "$#" -eq 0 ]] || [[ "$1" != "--no-menu" ]]; then
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
  [[ "$INSTALL_MISE_RUNTIMES" == true ]] && echo "  • Mise Runtimes (Node.js + .NET)"
  [[ "$INSTALL_CLAUDE_CODE" == true ]] && echo "  • Claude Code CLI"
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