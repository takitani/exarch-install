#!/usr/bin/env bash
set -euo pipefail

# ======================================
# Post-Omarchy setup (Arch + Hyprland)
# - Usa exclusivamente yay (já presente no Omarchy)
# - Instala: dropbox, aws vpn client, copyq, postman, jetbrains toolbox/rider/datagrip
# - Configura mise (já instalado): Node LTS + .NET 8/9
# - Instala CLIs via npm após mise/npm (claude-code)
# ======================================

DEFAULT_NODE="lts"         # Ex.: lts | 22 | 20
DEFAULT_DOTNET_DEFAULT="9" # Default global
EXTRA_DOTNET=("8")          # Versões adicionais

# JetBrains: escolha o modo de instalação
# - Se quiser atualizações fáceis sem Toolbox, use AUR para IDEs
# - Se prefere Toolbox, ative-o e desative as IDEs via AUR
INSTALL_JB_TOOLBOX=${INSTALL_JB_TOOLBOX:-false}
INSTALL_JB_IDES_VIA_AUR=${INSTALL_JB_IDES_VIA_AUR:-true}

# Diretórios de origem/destino dos configs do Hypr/Hyprl para sincronizar
HYPR_SRC_DIR="${HYPR_SRC_DIR:-$(pwd)/dotfiles/hypr}"
HYPRL_SRC_DIR="${HYPRL_SRC_DIR:-$(pwd)/dotfiles/hyprl}"
HYPR_DST_DIR="${HYPR_DST_DIR:-$HOME/.config/hypr}"
HYPRL_DST_DIR="${HYPRL_DST_DIR:-$HOME/.config/hyprl}"

log() { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
info() { printf "\033[1;34m[ .. ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[ !! ]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*" >&2; }

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
  sudo pacman -S --noconfirm --needed "$@"
}

aur() {
  yay -S --noconfirm --needed "$@"
}

install_core_apps() {
  info "Instalando apps dos repositórios oficiais"
  pac copyq || warn "Falha instalando copyq"

  info "Instalando apps via AUR"
  # Dropbox
  aur dropbox || warn "Falha no dropbox (AUR)"
  # AWS VPN Client (tente nomes conhecidos)
  aur aws-vpn-client || aur awsvpnclient || warn "Falha no AWS VPN Client (AUR)"
  # Postman
  aur postman-bin || aur postman || warn "Falha no Postman (AUR)"
  # JetBrains (configurável)
  if [[ "$INSTALL_JB_TOOLBOX" == "true" ]]; then
    aur jetbrains-toolbox || warn "Falha no JetBrains Toolbox (AUR)"
  else
    info "Pulando JetBrains Toolbox (INSTALL_JB_TOOLBOX=false)"
  fi

  if [[ "$INSTALL_JB_IDES_VIA_AUR" == "true" ]]; then
    aur jetbrains-rider || warn "Falha no Rider (AUR)"
    aur jetbrains-datagrip || warn "Falha no DataGrip (AUR)"
  else
    info "Pulando Rider/DataGrip via AUR (INSTALL_JB_IDES_VIA_AUR=false)"
  fi

  # Habilitar Dropbox (systemd --user) caso disponível
  if systemctl --user daemon-reload 2>/dev/null; then
    systemctl --user enable --now dropbox.service || warn "Não foi possível habilitar dropbox.service (user). Abra o app uma vez manualmente."
  fi

  log "Apps principais instalados"
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
  if ! command -v mise >/dev/null 2>&1; then
    warn "Pulando configuração do mise: comando não encontrado."
    return 0
  fi

  info "Instalando Node via mise: ${DEFAULT_NODE}"
  mise install "node@${DEFAULT_NODE}" || warn "Falha em instalar node@${DEFAULT_NODE}"
  mise use -g "node@${DEFAULT_NODE}" || warn "Falha em definir node@${DEFAULT_NODE} como global"

  info ".NET via mise: default ${DEFAULT_DOTNET_DEFAULT} + extras ${EXTRA_DOTNET[*]}"
  local dotnet_pkgs=("dotnet@${DEFAULT_DOTNET_DEFAULT}")
  for v in "${EXTRA_DOTNET[@]}"; do
    dotnet_pkgs+=("dotnet@${v}")
  done
  mise install "${dotnet_pkgs[@]}" || warn "Falha instalando .NET runtimes"
  mise use -g "dotnet@${DEFAULT_DOTNET_DEFAULT}" || warn "Falha definindo .NET global"

  mise reshim || true
  log "mise: Node e .NET configurados"
}

install_clis() {
  activate_mise_in_shell

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm não disponível após mise. Pulando instalação de CLIs npm."
    return 0
  fi

  info "Instalando CLIs npm globais (Claude Code)"
  npm install -g @anthropic-ai/claude-code || warn "Falha ao instalar @anthropic-ai/claude-code"
  # Repetido conforme solicitado
  npm install -g @anthropic-ai/claude-code || warn "Falha ao instalar @anthropic-ai/claude-code (2ª tentativa)"
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

main() {
  require_sudo
  ensure_tools
  install_core_apps
  activate_mise_in_shell
  configure_mise_runtimes
  install_clis
  sync_hypr_configs

  log "Setup pós-Omarchy concluído."
}

main "$@"
