#!/usr/bin/env bash
# configure-entra-app.sh - Configura aplicação já criada no Entra ID

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Configuração da Aplicação Entra ID no Himmelblau${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Este script configura uma aplicação já criada no portal do Azure."
echo ""
echo "Se ainda não criou a aplicação, consulte:"
echo -e "  ${YELLOW}MANUAL_ENTRA_APP_CREATION.md${NC}"
echo ""

# Solicitar informações
echo -n "Digite o Application ID (Client ID): "
read -r APP_ID

if [[ -z "$APP_ID" ]]; then
    echo -e "${RED}Application ID é obrigatório!${NC}"
    exit 1
fi

echo ""
echo -n "Digite o Client Secret: "
read -rs CLIENT_SECRET
echo ""

if [[ -z "$CLIENT_SECRET" ]]; then
    echo -e "${RED}Client Secret é obrigatório!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[1/5]${NC} Configurando credenciais no Himmelblau..."
if sudo himmelblau cred secret --client-id "$APP_ID" --domain "exato.digital" --secret "$CLIENT_SECRET"; then
    echo -e "${GREEN}✓ Credenciais configuradas${NC}"
else
    echo -e "${RED}✗ Erro ao configurar credenciais${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[2/5]${NC} Verificando credenciais..."
if sudo himmelblau cred list | grep -q "$APP_ID"; then
    echo -e "${GREEN}✓ Credenciais encontradas${NC}"
else
    echo -e "${RED}✗ Problema com as credenciais${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}[3/5]${NC} Adicionando schema extensions..."
if sudo himmelblau application add-schema-extensions --client-id "$APP_ID" 2>/dev/null; then
    echo -e "${GREEN}✓ Schema extensions adicionadas${NC}"
else
    echo -e "${YELLOW}⚠ Schema extensions não disponíveis ou já configuradas${NC}"
fi

echo ""
echo -e "${BLUE}[4/5]${NC} Enumerando usuários do Entra ID..."
echo "(Isso pode demorar alguns segundos...)"
if sudo himmelblau enumerate; then
    echo -e "${GREEN}✓ Usuários enumerados com sucesso${NC}"
else
    echo -e "${YELLOW}⚠ Falha ao enumerar usuários${NC}"
fi

echo ""
echo -e "${BLUE}[5/5]${NC} Testando configuração..."

# Listar usuários disponíveis
echo ""
echo "Usuários disponíveis:"
sudo himmelblau user list 2>/dev/null | head -10 || echo "Nenhum usuário encontrado"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    🎉 CONFIGURAÇÃO CONCLUÍDA!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Salvar configuração
cat > /tmp/himmelblau-setup.txt << EOF
Himmelblau Configuration
========================
Application ID: $APP_ID
Tenant ID: c902ee7d-d8f4-44e7-a09e-bf42b25fa285
Domain: exato.digital
Configured: $(date)
EOF

echo "Configuração salva em: /tmp/himmelblau-setup.txt"
echo ""

echo -e "${YELLOW}Próximos passos:${NC}"
echo ""
echo "1. Teste com um usuário específico:"
echo -e "   ${BLUE}himmelblau auth-test usuario@exato.digital${NC}"
echo ""
echo "2. Verifique se usuário aparece no sistema:"
echo -e "   ${BLUE}getent passwd usuario@exato.digital${NC}"
echo ""
echo "3. Tente fazer login:"
echo -e "   ${BLUE}su - usuario@exato.digital${NC}"
echo ""
echo "4. Para login gráfico (Hyprland):"
echo -e "   Use: ${GREEN}usuario@exato.digital${NC} na tela de login"
echo ""

echo -e "${YELLOW}Comandos úteis:${NC}"
echo ""
echo "• Listar credenciais: ${BLUE}sudo himmelblau cred list${NC}"
echo "• Limpar cache: ${BLUE}sudo himmelblau cache-clear${NC}"
echo "• Verificar status: ${BLUE}himmelblau status${NC}"
echo "• Ver logs: ${BLUE}sudo journalctl -u himmelblaud -f${NC}"
echo ""

echo -e "${GREEN}Himmelblau está pronto para autenticação Microsoft Entra ID!${NC}"