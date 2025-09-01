#!/bin/bash

# Função para aplicar o patch completo do Pipewire Camera
# Inclui modificações nos arquivos Preferences para forçar flags como "Enabled"
apply_pipewire_camera_patch() {
  if [[ "$DEBUG_MODE" == true ]]; then
    info "[DEBUG] Aplicando patch completo Pipewire Camera (simulado)"
    return 0
  fi

  info "Aplicando patch completo Pipewire Camera..."
  
  # Função interna para modificar Preferences usando jq
  modify_browser_preferences() {
    local prefs_file="$1"
    local browser_name="$2"
    
    if [[ ! -f "$prefs_file" ]]; then
      return 1
    fi
    
    # Fazer backup
    cp "$prefs_file" "${prefs_file}.backup" 2>/dev/null || true
    
    # Usar jq para adicionar as flags experimentais
    if command -v jq >/dev/null 2>&1; then
      # Adicionar enabled_labs_experiments para forçar flags como "Enabled"
      jq '.browser.enabled_labs_experiments = ["enable-webrtc-pipewire-capturer@1", "enable-webrtc-pipewire-camera@1"]' \
          "$prefs_file" > "${prefs_file}.tmp" && mv "${prefs_file}.tmp" "$prefs_file"
      log "✓ Flags Pipewire forçadas como 'Enabled' em $browser_name"
    else
      warn "jq não encontrado - flags não foram forçadas nos Preferences"
    fi
  }

  # Aguardar navegadores fecharem se estiverem rodando
  if pgrep -f "chromium$" >/dev/null 2>&1 || pgrep -f "google-chrome$" >/dev/null 2>&1; then
    info "Fechando navegadores para aplicar o patch..."
    pkill -f "chromium$" 2>/dev/null || true
    pkill -f "google-chrome$" 2>/dev/null || true
    sleep 3
  fi

  # Modificar Preferences existentes para Chromium
  for profile_dir in "$HOME/.config/chromium/"*/; do
    if [[ -d "$profile_dir" ]]; then
      prefs_file="${profile_dir}Preferences"
      if [[ -f "$prefs_file" ]]; then
        modify_browser_preferences "$prefs_file" "Chromium ($(basename "$profile_dir"))"
      fi
    fi
  done

  # Modificar Local State do Chromium
  if [[ -f "$HOME/.config/chromium/Local State" ]]; then
    cp "$HOME/.config/chromium/Local State" "$HOME/.config/chromium/Local State.backup" 2>/dev/null || true
    if command -v jq >/dev/null 2>&1; then
      jq '.browser.enabled_labs_experiments = ["enable-webrtc-pipewire-capturer@1", "enable-webrtc-pipewire-camera@1"]' \
          "$HOME/.config/chromium/Local State" > "$HOME/.config/chromium/Local State.tmp" && \
          mv "$HOME/.config/chromium/Local State.tmp" "$HOME/.config/chromium/Local State"
      log "✓ Local State do Chromium atualizado"
    fi
  fi

  # Modificar Preferences existentes para Google Chrome
  for profile_dir in "$HOME/.config/google-chrome/"*/; do
    if [[ -d "$profile_dir" ]]; then
      prefs_file="${profile_dir}Preferences"
      if [[ -f "$prefs_file" ]]; then
        modify_browser_preferences "$prefs_file" "Chrome ($(basename "$profile_dir"))"
      fi
    fi
  done

  # Modificar Local State do Chrome
  if [[ -f "$HOME/.config/google-chrome/Local State" ]]; then
    cp "$HOME/.config/google-chrome/Local State" "$HOME/.config/google-chrome/Local State.backup" 2>/dev/null || true
    if command -v jq >/dev/null 2>&1; then
      jq '.browser.enabled_labs_experiments = ["enable-webrtc-pipewire-capturer@1", "enable-webrtc-pipewire-camera@1"]' \
          "$HOME/.config/google-chrome/Local State" > "$HOME/.config/google-chrome/Local State.tmp" && \
          mv "$HOME/.config/google-chrome/Local State.tmp" "$HOME/.config/google-chrome/Local State"
      log "✓ Local State do Chrome atualizado"
    fi
  fi

  # Garantir que as flags de linha de comando também estão corretas
  local chromium_flags_file="$HOME/.config/chromium-flags.conf"
  local chrome_flags_file="$HOME/.config/google-chrome-flags.conf"
  
  # Adicionar flag WebRTCPipeWireCapturer se não existir
  if [[ -f "$chromium_flags_file" ]]; then
    if ! grep -q "enable-features=WebRTCPipeWireCapturer" "$chromium_flags_file"; then
      echo "--enable-features=WebRTCPipeWireCapturer" >> "$chromium_flags_file"
      log "✓ Flag WebRTCPipeWireCapturer adicionada ao Chromium"
    fi
  fi
  
  if [[ -f "$chrome_flags_file" ]]; then
    if ! grep -q "enable-features=WebRTCPipeWireCapturer" "$chrome_flags_file"; then
      echo "--enable-features=WebRTCPipeWireCapturer" >> "$chrome_flags_file"
      log "✓ Flag WebRTCPipeWireCapturer adicionada ao Chrome"
    fi
  fi

  success "Patch completo Pipewire Camera aplicado!"
  info "🎯 Próximos passos:"
  info "   1. As flags já foram forçadas como 'Enabled' nos arquivos de configuração"
  info "   2. Abra chrome://flags para verificar que 'WebRTC PipeWire support' está 'Enabled'"
  info "   3. Teste em meet.google.com, discord.com, ou similar"
}

# Definir funções auxiliares básicas se não existirem
if ! command -v info >/dev/null 2>&1; then
  info() { echo "ℹ️  $*"; }
  warn() { echo "⚠️  $*"; }
  log() { echo "📝 $*"; }
  success() { echo "✅ $*"; }
fi

# Se executado diretamente (não como source), executar a função
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Executar patch
  apply_pipewire_camera_patch
fi