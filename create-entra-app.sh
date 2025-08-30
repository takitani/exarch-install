#!/usr/bin/env bash
# create-entra-app.sh - Cria aplicação no Microsoft Entra ID para Himmelblau

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TENANT_ID="c902ee7d-d8f4-44e7-a09e-bf42b25fa285"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Criação de Aplicação no Microsoft Entra ID${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${YELLOW}Informações do seu Tenant:${NC}"
echo "  Tenant ID: $TENANT_ID"
echo "  Domínio: exato.digital"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    O QUE VOCÊ PRECISA FAZER${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "O Himmelblau precisa de uma aplicação registrada no Entra ID."
echo "Isso é como criar uma 'conta de serviço' para o Himmelblau."
echo ""

echo -e "${GREEN}OPÇÃO 1: Criar automaticamente (RECOMENDADO)${NC}"
echo "═════════════════════════════════════════════"
echo ""
echo "Execute este comando (vai abrir o navegador):"
echo ""
echo -e "  ${BLUE}sudo himmelblau application create${NC}"
echo ""
echo "O que vai acontecer:"
echo "  1. Abrirá o navegador"
echo "  2. Você faz login como admin do tenant"
echo "  3. Autoriza a criação da aplicação"
echo "  4. O comando retorna o Application ID"
echo ""
echo "Pressione ENTER para continuar com esta opção..."
read -r

echo ""
echo -e "${YELLOW}Executando criação da aplicação...${NC}"
echo ""
sudo himmelblau application create

echo ""
echo -e "${GREEN}✓ Aplicação criada!${NC}"
echo ""
echo "Agora você deve ter recebido um Application ID (Client ID)."
echo ""
echo -n "Cole o Application ID aqui: "
read -r APP_ID

if [[ -z "$APP_ID" ]]; then
    echo -e "${RED}Application ID não pode estar vazio!${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    CONFIGURANDO CREDENCIAIS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Agora precisamos configurar as credenciais para a aplicação."
echo ""
echo "Você tem duas opções:"
echo "  1) Gerar um certificado (mais seguro)"
echo "  2) Criar um client secret (mais simples)"
echo ""
echo -n "Escolha (1/2): "
read -r cred_choice

if [[ "$cred_choice" == "1" ]]; then
    echo ""
    echo -e "${YELLOW}Gerando certificado...${NC}"
    sudo himmelblau cred cert --app-id "$APP_ID"
    echo -e "${GREEN}✓ Certificado gerado e configurado!${NC}"
else
    echo ""
    echo -e "${YELLOW}Para criar um client secret:${NC}"
    echo ""
    echo "1. Acesse: https://portal.azure.com"
    echo "2. Vá em: Azure Active Directory > App registrations"
    echo "3. Encontre a aplicação criada (ID: $APP_ID)"
    echo "4. Vá em: Certificates & secrets > New client secret"
    echo "5. Crie um secret e copie o valor"
    echo ""
    echo -n "Cole o client secret aqui: "
    read -rs CLIENT_SECRET
    echo ""
    
    if [[ -z "$CLIENT_SECRET" ]]; then
        echo -e "${RED}Client secret não pode estar vazio!${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}Configurando secret...${NC}"
    echo "$CLIENT_SECRET" | sudo himmelblau cred secret --app-id "$APP_ID"
    echo -e "${GREEN}✓ Secret configurado!${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    ADICIONANDO EXTENSÕES DE SCHEMA${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Adicionando suporte POSIX (uid/gid) ao Entra ID..."
sudo himmelblau application add-schema-extensions --app-id "$APP_ID"
echo -e "${GREEN}✓ Extensões de schema adicionadas!${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    VERIFICANDO CONFIGURAÇÃO${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Verificando credenciais..."
if sudo himmelblau cred list | grep -q "$APP_ID"; then
    echo -e "${GREEN}✓ Credenciais configuradas corretamente!${NC}"
else
    echo -e "${RED}✗ Problema com as credenciais${NC}"
fi

echo ""
echo "Enumerando usuários do Entra ID..."
echo "(Isso pode demorar alguns segundos...)"
echo ""
sudo himmelblau enumerate

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    🎉 CONFIGURAÇÃO COMPLETA!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Agora você pode:"
echo ""
echo "1. Testar autenticação de um usuário:"
echo -e "   ${BLUE}himmelblau auth-test usuario@exato.digital${NC}"
echo ""
echo "2. Verificar se usuário aparece no sistema:"
echo -e "   ${BLUE}getent passwd usuario@exato.digital${NC}"
echo ""
echo "3. Fazer login:"
echo -e "   ${BLUE}su - usuario@exato.digital${NC}"
echo ""
echo "4. No Hyprland, use na tela de login:"
echo -e "   ${GREEN}usuario@exato.digital${NC}"
echo ""

# Salvar configuração
cat > /tmp/himmelblau-config.txt << EOF
Himmelblau Configuration
========================
Tenant ID: $TENANT_ID
Application ID: $APP_ID
Domain: exato.digital
Date: $(date)
EOF

echo "Configuração salva em: /tmp/himmelblau-config.txt"
echo ""
echo -e "${GREEN}Processo finalizado com sucesso!${NC}"