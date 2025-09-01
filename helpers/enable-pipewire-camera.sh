#!/bin/bash

# Script para habilitar automaticamente o suporte Pipewire Camera no Chrome/Chromium
set -e

echo "============================================================"
echo "Habilitador de Pipewire Camera para Chrome/Chromium"
echo "============================================================"

# Verificar se Pipewire está rodando
if systemctl --user is-active pipewire >/dev/null 2>&1; then
    echo "✓ Pipewire está ativo"
else
    echo "⚠ AVISO: Pipewire não está ativo!"
    echo "  Execute: systemctl --user start pipewire"
fi

# Função para fazer backup
backup_file() {
    local file="$1"
    if [ -f "$file" ]; then
        cp "$file" "${file}.backup"
        echo "  ✓ Backup criado: ${file}.backup"
    fi
}

# Função para modificar Preferences usando jq
modify_preferences() {
    local prefs_file="$1"
    
    if [ ! -f "$prefs_file" ]; then
        return 1
    fi
    
    # Fazer backup
    backup_file "$prefs_file"
    
    # Usar jq para adicionar as flags experimentais
    if command -v jq >/dev/null 2>&1; then
        # Adicionar enabled_labs_experiments
        jq '.browser.enabled_labs_experiments = ["enable-webrtc-pipewire-capturer@1", "enable-webrtc-pipewire-camera@1"]' \
            "$prefs_file" > "${prefs_file}.tmp" && mv "${prefs_file}.tmp" "$prefs_file"
        echo "  ✓ Flags Pipewire habilitadas em: $prefs_file"
    else
        # Fallback sem jq - usar sed (mais arriscado mas funciona)
        echo "  ⚠ jq não encontrado, usando sed (menos confiável)"
        
        # Verificar se já existe enabled_labs_experiments
        if grep -q "enabled_labs_experiments" "$prefs_file"; then
            # Substituir valor existente
            sed -i 's/"enabled_labs_experiments":\[[^]]*\]/"enabled_labs_experiments":["enable-webrtc-pipewire-capturer@1","enable-webrtc-pipewire-camera@1"]/' "$prefs_file"
        else
            # Adicionar novo campo no browser
            sed -i 's/"browser":{/"browser":{"enabled_labs_experiments":["enable-webrtc-pipewire-capturer@1","enable-webrtc-pipewire-camera@1"],/' "$prefs_file"
        fi
        echo "  ✓ Flags Pipewire habilitadas (via sed) em: $prefs_file"
    fi
}

# Função para modificar Local State
modify_local_state() {
    local state_file="$1"
    
    if [ ! -f "$state_file" ]; then
        return 1
    fi
    
    backup_file "$state_file"
    
    if command -v jq >/dev/null 2>&1; then
        jq '.browser.enabled_labs_experiments = ["enable-webrtc-pipewire-capturer@1", "enable-webrtc-pipewire-camera@1"]' \
            "$state_file" > "${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
        echo "  ✓ Local State atualizado: $state_file"
    else
        if grep -q "enabled_labs_experiments" "$state_file"; then
            sed -i 's/"enabled_labs_experiments":\[[^]]*\]/"enabled_labs_experiments":["enable-webrtc-pipewire-capturer@1","enable-webrtc-pipewire-camera@1"]/' "$state_file"
        else
            sed -i 's/"browser":{/"browser":{"enabled_labs_experiments":["enable-webrtc-pipewire-capturer@1","enable-webrtc-pipewire-camera@1"],/' "$state_file"
        fi
        echo "  ✓ Local State atualizado (via sed): $state_file"
    fi
}

# Configurar flags de linha de comando
setup_command_flags() {
    local flags_file="$1"
    local browser_name="$2"
    
    echo ""
    echo "📝 Configurando flags de linha de comando para $browser_name..."
    
    # Flags necessárias
    local required_flags=(
        "--enable-webrtc-pipewire-camera"
        "--enable-features=WebRTCPipeWireCapturer"
        "--ozone-platform=wayland"
        "--enable-wayland-ime"
    )
    
    # Criar arquivo se não existir
    touch "$flags_file"
    
    # Adicionar flags que não existem
    for flag in "${required_flags[@]}"; do
        if ! grep -q "^${flag}$" "$flags_file" 2>/dev/null; then
            echo "$flag" >> "$flags_file"
            echo "  + Adicionada: $flag"
        fi
    done
    
    echo "  ✓ Flags configuradas em: $flags_file"
}

# Processar Chromium
if [ -d "$HOME/.config/chromium" ]; then
    echo ""
    echo "📦 Processando Chromium..."
    
    # Modificar Preferences de cada perfil
    for profile_dir in "$HOME/.config/chromium/"*/; do
        if [ -d "$profile_dir" ]; then
            profile_name=$(basename "$profile_dir")
            prefs_file="${profile_dir}Preferences"
            
            if [ -f "$prefs_file" ]; then
                echo "  Perfil: $profile_name"
                modify_preferences "$prefs_file"
            fi
        fi
    done
    
    # Modificar Local State
    modify_local_state "$HOME/.config/chromium/Local State"
    
    # Configurar flags
    setup_command_flags "$HOME/.config/chromium-flags.conf" "Chromium"
else
    echo "⚠ Chromium não encontrado"
fi

# Processar Google Chrome
if [ -d "$HOME/.config/google-chrome" ]; then
    echo ""
    echo "📦 Processando Google Chrome..."
    
    # Modificar Preferences de cada perfil
    for profile_dir in "$HOME/.config/google-chrome/"*/; do
        if [ -d "$profile_dir" ]; then
            profile_name=$(basename "$profile_dir")
            prefs_file="${profile_dir}Preferences"
            
            if [ -f "$prefs_file" ]; then
                echo "  Perfil: $profile_name"
                modify_preferences "$prefs_file"
            fi
        fi
    done
    
    # Modificar Local State
    modify_local_state "$HOME/.config/google-chrome/Local State"
    
    # Configurar flags
    setup_command_flags "$HOME/.config/chrome-flags.conf" "Chrome"
else
    echo "⚠ Google Chrome não encontrado"
fi

# Modificar atalhos do desktop para incluir flags
echo ""
echo "🔧 Modificando atalhos do desktop..."

# Função para atualizar arquivo .desktop
update_desktop_file() {
    local desktop_file="$1"
    local browser_name="$2"
    
    if [ -f "$desktop_file" ]; then
        backup_file "$desktop_file"
        
        # Determinar o executável correto baseado no browser
        local executable=""
        local flags="--enable-webrtc-pipewire-camera --enable-features=WebRTCPipeWireCapturer --ozone-platform=wayland --enable-wayland-ime"
        
        if [[ "$browser_name" == *"chromium"* ]]; then
            executable="/usr/bin/chromium"
        elif [[ "$browser_name" == *"chrome"* ]]; then
            executable="/usr/bin/google-chrome-stable"
        else
            executable="$(which chromium 2>/dev/null || which google-chrome 2>/dev/null || echo "chromium")"
        fi
        
        # Adicionar flags ao comando Exec se não existirem
        if ! grep -q "enable-webrtc-pipewire-camera" "$desktop_file"; then
            # Substituir a linha Exec principal
            sed -i "s|^Exec=.*|Exec=$executable $flags %U|" "$desktop_file"
            
            # Substituir as outras linhas Exec (new-window, incognito)
            sed -i "s|^Exec=.*--new-window|Exec=$executable $flags --new-window|" "$desktop_file"
            sed -i "s|^Exec=.*--incognito|Exec=$executable $flags --incognito|" "$desktop_file"
            
            echo "  ✓ Atualizado: $desktop_file"
            echo "    Executável: $executable"
            echo "    Flags: $flags"
        else
            echo "  → Já configurado: $desktop_file"
        fi
    fi
}

# Atualizar arquivos .desktop do sistema
for desktop_file in /usr/share/applications/{chromium,google-chrome,google-chrome-stable}.desktop; do
    if [ -f "$desktop_file" ]; then
        # Precisa sudo para modificar arquivos do sistema
        if [ -w "$desktop_file" ]; then
            update_desktop_file "$desktop_file" "$(basename $desktop_file .desktop)"
        else
            echo "  ⚠ Sem permissão para modificar: $desktop_file"
            echo "    Execute com sudo se quiser modificar atalhos do sistema"
        fi
    fi
done

# Atualizar arquivos .desktop locais do usuário
for desktop_file in "$HOME/.local/share/applications/"{chromium,google-chrome,google-chrome-stable}.desktop; do
    if [ -f "$desktop_file" ]; then
        update_desktop_file "$desktop_file" "$(basename $desktop_file .desktop)"
    fi
done

echo ""
echo "============================================================"
echo "✅ CONFIGURAÇÃO CONCLUÍDA!"
echo "============================================================"

# Verificar se há navegadores rodando
if pgrep -f "chrom(e|ium)" >/dev/null; then
    echo ""
    echo "⚠ Navegadores detectados em execução!"
    read -p "🔄 Deseja fechar todos os navegadores agora? (s/N): " response
    
    if [[ "$response" =~ ^[Ss]$ ]]; then
        pkill -f "chrom(e|ium)" 2>/dev/null || true
        sleep 2
        echo "✓ Navegadores fechados"
    else
        echo ""
        echo "⚠ IMPORTANTE: Reinicie o navegador para aplicar as mudanças!"
    fi
else
    echo ""
    echo "ℹ Nenhum navegador em execução detectado"
fi

echo ""
echo "💡 PARA VERIFICAR SE FUNCIONOU:"
echo "  1. Abra o Chrome/Chromium"
echo "  2. Acesse chrome://flags"
echo "  3. Procure por 'pipewire'"
echo "  4. Deve estar marcado como 'Enabled'"
echo "  5. Teste em meet.google.com ou similar"
echo ""
echo "📌 NOTA: Se ainda aparecer como 'Default', tente:"
echo "  - Fechar TODAS as janelas do navegador"
echo "  - Aguardar alguns segundos"
echo "  - Abrir novamente"
echo ""