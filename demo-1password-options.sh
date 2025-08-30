#!/usr/bin/env bash

# Script de demonstração das opções do 1Password CLI vs Desktop

set -euo pipefail

# Carregar configurações do .env se existir
if [[ -f "$(dirname "$0")/.env" ]]; then
    source "$(dirname "$0")/.env"
fi

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }

echo
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ${BOLD}1Password: CLI vs Desktop Demo${NC}${CYAN}      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo

echo "Este script demonstra as diferenças entre os métodos de configuração:"
echo
echo -e "${BOLD}1. Método CLI (Recomendado para scripts)${NC}"
echo "   ✓ Configuração direta no terminal"
echo "   ✓ Melhor para automação e CI/CD"
echo "   ✓ Funciona em servidores sem interface gráfica"
echo "   ✓ Controle total sobre o processo"
echo "   • Requer Emergency Kit ou dados da conta"
echo

echo -e "${BOLD}2. Método Desktop App (Mais fácil)${NC}"
echo "   ✓ Interface gráfica amigável"
echo "   ✓ Integração automática com o CLI"
echo "   ✓ Não precisa digitar credenciais no terminal"
echo "   • Requer 1Password desktop instalado"
echo "   • Não funciona em servidores headless"
echo

echo -e "${BOLD}Status atual:${NC}"
echo

# Verificar CLI
if command -v op >/dev/null 2>&1; then
    success "1Password CLI instalado"
    
    # Verificar contas
    accounts=$(op account list --format=json 2>/dev/null || echo "[]")
    account_count=$(echo "$accounts" | jq length 2>/dev/null || echo "0")
    
    if [[ "$account_count" -gt 0 ]]; then
        success "$account_count conta(s) configurada(s)"
        echo "$accounts" | jq -r '.[] | "  • \(.shorthand): \(.email)"' 2>/dev/null || true
        
        # Verificar login
        if timeout 3 op vault list >/dev/null 2>&1; then
            success "Logado e pronto para uso"
        else
            warn "Configurado mas não logado"
            echo "  Execute: op signin"
        fi
    else
        warn "CLI instalado mas sem contas configuradas"
    fi
else
    warn "1Password CLI não instalado"
fi

echo

# Verificar desktop app
desktop_apps=(
    "/usr/bin/1password"
    "/usr/local/bin/1password"
    "/opt/1Password/1password"
    "$HOME/.local/bin/1password"
)

desktop_found=false
for app in "${desktop_apps[@]}"; do
    if [[ -f "$app" ]] || [[ -d "$app" ]]; then
        desktop_found=true
        break
    fi
done

# Verificar pacman/flatpak
if pacman -Q 1password 2>/dev/null >/dev/null; then
    desktop_found=true
fi

if flatpak list 2>/dev/null | grep -q "com.onepassword.OnePassword"; then
    desktop_found=true
fi

if [[ "$desktop_found" == true ]]; then
    success "1Password desktop detectado"
else
    warn "1Password desktop não encontrado"
fi

echo

# Mostrar configuração do .env
if [[ -n "${ONEPASSWORD_URL:-}" ]]; then
    success "URL configurada: ${ONEPASSWORD_URL}"
else
    warn "URL não configurada no .env"
    echo "  Execute: ./configure.sh"
fi

if [[ -n "${ONEPASSWORD_EMAIL:-}" ]]; then
    success "Email configurado: ${ONEPASSWORD_EMAIL}"
else
    info "Email não configurado (será solicitado quando necessário)"
fi

echo
echo -e "${BOLD}Comandos disponíveis:${NC}"
echo
echo "• ${CYAN}./configure.sh${NC} - Configurar .env com URL da empresa"
echo "• ${CYAN}./1password-helper.sh${NC} - Setup assistido completo"
echo "• ${CYAN}./install.sh --1pass${NC} - Testar geração de .pgpass"
echo "• ${CYAN}./install.sh${NC} - Menu principal (opção dev)"
echo
echo -e "${BOLD}Para configuração manual via CLI:${NC}"
echo "• ${CYAN}op account add${NC} - Adicionar conta (Setup Code)"
echo "• ${CYAN}op account add --address URL --email EMAIL --secret-key KEY${NC}"
echo "• ${CYAN}op signin${NC} - Fazer login"
echo