#!/bin/bash

# Script para verificar se a flag PipeWire está configurada corretamente

echo "🔍 Verificando configuração da flag PipeWire..."

# Verificar se as flags estão nos arquivos de configuração
echo ""
echo "📁 Verificando arquivos de configuração:"

if [ -f "$HOME/.config/chromium/Default/Preferences" ]; then
    echo "✓ Chromium Preferences encontrado"
    if jq -e '.browser.enabled_labs_experiments' "$HOME/.config/chromium/Default/Preferences" >/dev/null 2>&1; then
        echo "  ✓ Flags experimentais configuradas:"
        jq -r '.browser.enabled_labs_experiments[]' "$HOME/.config/chromium/Default/Preferences" | while read flag; do
            echo "    - $flag"
        done
    else
        echo "  ❌ Flags experimentais não encontradas"
    fi
else
    echo "❌ Chromium Preferences não encontrado"
fi

# Verificar arquivo de flags de linha de comando
echo ""
echo "📝 Verificando flags de linha de comando:"

if [ -f "$HOME/.config/chromium-flags.conf" ]; then
    echo "✓ Arquivo de flags encontrado:"
    cat "$HOME/.config/chromium-flags.conf" | while read line; do
        if [[ $line =~ ^-- ]]; then
            echo "  - $line"
        fi
    done
else
    echo "❌ Arquivo de flags não encontrado"
fi

# Verificar se o PipeWire está rodando
echo ""
echo "🎵 Verificando status do PipeWire:"

if systemctl --user is-active pipewire >/dev/null 2>&1; then
    echo "✓ PipeWire está ativo"
else
    echo "❌ PipeWire não está ativo"
fi

# Verificar dispositivos de vídeo
echo ""
echo "📹 Verificando dispositivos de vídeo:"

if command -v v4l2-ctl >/dev/null 2>&1; then
    echo "✓ v4l2-ctl encontrado"
    echo "  Dispositivos disponíveis:"
    v4l2-ctl --list-devices 2>/dev/null | grep -E "^[[:space:]]*[^[:space:]]" | head -5
else
    echo "⚠ v4l2-ctl não encontrado (instale v4l-utils para ver dispositivos)"
fi

echo ""
echo "💡 Para verificar se funcionou no navegador:"
echo "   1. Abra o Chromium"
echo "   2. Vá para chrome://flags"
echo "   3. Procure por 'pipewire'"
echo "   4. Deve estar marcado como 'Enabled'"
echo ""
echo "🧪 Para testar a câmera:"
echo "   - meet.google.com"
echo "   - webcamtest.com"
echo "   - Qualquer site que use getUserMedia()"
