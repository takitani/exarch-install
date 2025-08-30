#!/usr/bin/env bash
# test-entra-credentials.sh - Testa credenciais já configuradas do Entra ID

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

APP_ID="9669afee-37e6-47b1-9b15-da3a7c8f560d"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Teste das Credenciais Entra ID no Himmelblau${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}[1/4]${NC} Verificando se credenciais estão configuradas..."
if sudo himmelblau cred list 2>/dev/null | grep -q "$APP_ID"; then
    echo -e "${GREEN}✓ Credenciais encontradas para Application ID: $APP_ID${NC}"
else
    echo -e "${YELLOW}⚠ Credenciais não encontradas${NC}"
    echo ""
    echo "Para configurar, execute:"
    echo -e "${BLUE}sudo himmelblau cred secret --client-id $APP_ID --domain \"exato.digital\" --secret \"SEU_CLIENT_SECRET\"${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[2/4]${NC} Testando conectividade com Entra ID..."
if timeout 10 sudo himmelblau enumerate 2>&1 | tee /tmp/himmelblau-enumerate.log; then
    echo -e "${GREEN}✓ Conectividade OK${NC}"
else
    echo -e "${YELLOW}⚠ Problema na enumeração (verifique logs)${NC}"
fi

echo ""
echo -e "${BLUE}[3/4]${NC} Verificando usuários disponíveis..."
echo "Primeiros 5 usuários encontrados:"
sudo himmelblau user list 2>/dev/null | head -5 || echo "Nenhum usuário listado"

echo ""
echo -e "${BLUE}[4/4]${NC} Testando usuário específico..."
echo "Testando: usuario@exato.digital"

if himmelblau auth-test usuario@exato.digital 2>&1 | tee /tmp/himmelblau-auth-test.log; then
    echo -e "${GREEN}✓ Teste de autenticação passou${NC}"
else
    echo -e "${YELLOW}⚠ Teste de autenticação falhou${NC}"
fi

echo ""
echo "Verificando se usuário aparece no sistema:"
if getent passwd usuario@exato.digital; then
    echo -e "${GREEN}✓ Usuário encontrado no sistema${NC}"
else
    echo -e "${YELLOW}⚠ Usuário não encontrado no sistema${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Status da Configuração${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Application ID: $APP_ID"
echo "Domain: exato.digital"
echo "Logs disponíveis:"
echo "  - Enumeração: /tmp/himmelblau-enumerate.log"
echo "  - Teste auth: /tmp/himmelblau-auth-test.log"
echo "  - Daemon: sudo journalctl -u himmelblaud -n 20"

echo ""
echo -e "${YELLOW}Próximos passos se tudo funcionou:${NC}"
echo "1. Testar login no terminal:"
echo -e "   ${BLUE}su - usuario@exato.digital${NC}"
echo ""
echo "2. Testar login no Hyprland:"
echo -e "   Use: ${GREEN}usuario@exato.digital${NC} na tela de login"