#!/bin/bash

# Script de diagnóstico para problemas com gnome-keyring

echo "=== DIAGNÓSTICO DO GNOME-KEYRING ==="
echo ""

# Verificar se o gnome-keyring está instalado
echo "1. Verificando instalação:"
if pacman -Q gnome-keyring &>/dev/null; then
    echo "   ✓ gnome-keyring está instalado ($(pacman -Q gnome-keyring))"
else
    echo "   ✗ gnome-keyring NÃO está instalado"
fi

# Verificar se o processo está rodando
echo ""
echo "2. Verificando processos:"
if pgrep -x gnome-keyring-daemon > /dev/null; then
    echo "   ✓ gnome-keyring-daemon está rodando"
    echo "   PIDs: $(pgrep gnome-keyring-daemon | tr '\n' ' ')"
else
    echo "   ✗ gnome-keyring-daemon NÃO está rodando"
fi

# Verificar configuração do PAM
echo ""
echo "3. Verificando configuração PAM:"
if grep -q "pam_gnome_keyring.so" /etc/pam.d/login; then
    echo "   ✓ PAM está configurado para gnome-keyring em /etc/pam.d/login"
    echo "   Linhas encontradas:"
    grep "pam_gnome_keyring.so" /etc/pam.d/login | sed 's/^/      /'
else
    echo "   ✗ PAM NÃO está configurado para gnome-keyring"
fi

# Verificar configuração do Hyprland
echo ""
echo "4. Verificando autostart do Hyprland:"
HYPR_AUTOSTART="$HOME/.config/hypr/autostart.conf"
if [ -f "$HYPR_AUTOSTART" ]; then
    if grep -q "gnome-keyring-daemon" "$HYPR_AUTOSTART"; then
        echo "   ✓ gnome-keyring está no autostart do Hyprland"
        echo "   Linhas encontradas:"
        grep "gnome-keyring" "$HYPR_AUTOSTART" | sed 's/^/      /'
    else
        echo "   ✗ gnome-keyring NÃO está no autostart do Hyprland"
    fi
else
    echo "   ✗ Arquivo $HYPR_AUTOSTART não existe"
fi

# Verificar variáveis de ambiente
echo ""
echo "5. Verificando variáveis de ambiente:"
if [ -n "$GNOME_KEYRING_CONTROL" ]; then
    echo "   ✓ GNOME_KEYRING_CONTROL está definida: $GNOME_KEYRING_CONTROL"
else
    echo "   ✗ GNOME_KEYRING_CONTROL NÃO está definida"
fi

if [ -n "$SSH_AUTH_SOCK" ]; then
    echo "   ✓ SSH_AUTH_SOCK está definida: $SSH_AUTH_SOCK"
    if [[ "$SSH_AUTH_SOCK" == *"keyring"* ]]; then
        echo "      (Usando gnome-keyring para SSH)"
    fi
else
    echo "   ✗ SSH_AUTH_SOCK NÃO está definida"
fi

# Verificar keyrings existentes
echo ""
echo "6. Verificando keyrings existentes:"
KEYRING_DIR="$HOME/.local/share/keyrings"
if [ -d "$KEYRING_DIR" ]; then
    echo "   Diretório de keyrings: $KEYRING_DIR"
    echo "   Keyrings encontrados:"
    ls -la "$KEYRING_DIR" 2>/dev/null | grep -E "\.keyring$" | sed 's/^/      /'
    
    # Verificar keyring padrão
    if [ -f "$KEYRING_DIR/default" ]; then
        echo "   Keyring padrão: $(cat "$KEYRING_DIR/default")"
    else
        echo "   ⚠ Nenhum keyring padrão definido"
    fi
else
    echo "   ✗ Diretório de keyrings não existe"
fi

# Testar conexão com o daemon
echo ""
echo "7. Testando comunicação com o daemon:"
if command -v secret-tool &> /dev/null; then
    if timeout 2 secret-tool search test test &>/dev/null; then
        echo "   ✓ Comunicação com gnome-keyring funcionando"
    else
        echo "   ✗ Não foi possível comunicar com gnome-keyring"
    fi
else
    echo "   ⚠ secret-tool não está instalado (instale libsecret para testar)"
fi

# Verificar Chrome/Chromium
echo ""
echo "8. Verificando navegadores:"
if command -v google-chrome-stable &> /dev/null; then
    echo "   ✓ Google Chrome está instalado"
    # Verificar se há flags personalizadas
    if [ -f "$HOME/.config/chrome-flags.conf" ]; then
        echo "   Flags personalizadas encontradas:"
        cat "$HOME/.config/chrome-flags.conf" | sed 's/^/      /'
    fi
fi

if command -v chromium &> /dev/null; then
    echo "   ✓ Chromium está instalado"
    if [ -f "$HOME/.config/chromium-flags.conf" ]; then
        echo "   Flags personalizadas encontradas:"
        cat "$HOME/.config/chromium-flags.conf" | sed 's/^/      /'
    fi
fi

# Sugestões
echo ""
echo "=== SUGESTÕES DE SOLUÇÃO ==="

PROBLEMS=0

if ! pgrep -x gnome-keyring-daemon > /dev/null; then
    echo "• O daemon não está rodando. Tente:"
    echo "  gnome-keyring-daemon --start --components=pkcs11,secrets,ssh"
    PROBLEMS=$((PROBLEMS + 1))
fi

if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/login; then
    echo "• PAM não está configurado. Execute:"
    echo "  ./helpers/setup-gnome-keyring.sh"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ ! -f "$HOME/.local/share/keyrings/default" ]; then
    echo "• Nenhum keyring padrão definido. Abra o seahorse e:"
    echo "  1. Crie um novo keyring chamado 'Default' ou 'login'"
    echo "  2. Deixe a senha em branco"
    echo "  3. Defina como padrão"
    PROBLEMS=$((PROBLEMS + 1))
fi

if [ $PROBLEMS -eq 0 ]; then
    echo "✓ Tudo parece estar configurado corretamente!"
    echo ""
    echo "Se ainda tiver problemas:"
    echo "1. Tente reiniciar o sistema"
    echo "2. Ou use o Chrome com: google-chrome-stable --password-store=basic"
fi

echo ""
echo "Para mais informações, execute: ./helpers/setup-gnome-keyring.sh --help"