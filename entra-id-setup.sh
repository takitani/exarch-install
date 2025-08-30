#!/usr/bin/env bash
# entra-id-setup.sh - Configura o Himmelblau com Microsoft Entra ID

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Configuração do Microsoft Entra ID com Himmelblau${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Verificar status
echo -e "${BLUE}[1]${NC} Verificando status do Himmelblau..."
if himmelblau status | grep -q "working"; then
    echo -e "  ${GREEN}✓ Himmelblau daemon está funcionando${NC}"
else
    echo -e "  ${RED}✗ Daemon não está respondendo${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    PROCESSO DE CONFIGURAÇÃO DO ENTRA ID${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "O Himmelblau precisa de uma aplicação registrada no Entra ID."
echo ""
echo -e "${YELLOW}Você tem duas opções:${NC}"
echo ""
echo "1) Criar uma nova aplicação (requer permissões de admin)"
echo "2) Usar credenciais de uma aplicação existente"
echo ""
echo -n "Escolha uma opção (1/2): "
read -r option

if [[ "$option" == "1" ]]; then
    echo ""
    echo -e "${BLUE}[2]${NC} Criando aplicação no Entra ID..."
    echo ""
    echo "Este comando vai:"
    echo "  • Abrir o navegador para autenticação"
    echo "  • Criar uma aplicação no seu tenant"
    echo "  • Configurar as permissões necessárias"
    echo ""
    echo -e "${YELLOW}Execute:${NC}"
    echo -e "  ${GREEN}sudo himmelblau application create${NC}"
    echo ""
    echo "Após criar, você receberá:"
    echo "  • Application ID (Client ID)"
    echo "  • Instruções para criar um secret"
    echo ""
    echo "Pressione ENTER quando a aplicação estiver criada..."
    read -r
    
    echo ""
    echo -e "${BLUE}[3]${NC} Configurando credenciais..."
    echo ""
    echo "Agora precisamos adicionar as credenciais."
    echo ""
    echo -n "Digite o Application ID (Client ID): "
    read -r client_id
    
    echo ""
    echo "Você tem:"
    echo "1) Client Secret"
    echo "2) Certificado"
    echo -n "Qual tipo de credencial? (1/2): "
    read -r cred_type
    
    if [[ "$cred_type" == "1" ]]; then
        echo ""
        echo -e "${YELLOW}Para adicionar o secret:${NC}"
        echo -e "  ${GREEN}sudo himmelblau cred secret --app-id $client_id${NC}"
        echo ""
        echo "Você será solicitado a inserir o secret."
    else
        echo ""
        echo -e "${YELLOW}Para gerar certificado:${NC}"
        echo -e "  ${GREEN}sudo himmelblau cred cert --app-id $client_id${NC}"
    fi
    
elif [[ "$option" == "2" ]]; then
    echo ""
    echo -e "${BLUE}[2]${NC} Usando aplicação existente..."
    echo ""
    echo -n "Digite o Application ID (Client ID): "
    read -r client_id
    
    echo ""
    echo -n "Digite o Client Secret: "
    read -s client_secret
    echo ""
    
    echo ""
    echo -e "${YELLOW}Execute este comando para adicionar as credenciais:${NC}"
    echo -e "  ${GREEN}echo '$client_secret' | sudo himmelblau cred secret --app-id $client_id${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    CONFIGURAÇÃO DE SCHEMA (OPCIONAL)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Para suporte completo a POSIX (uid/gid), adicione as extensões de schema:"
echo -e "  ${GREEN}sudo himmelblau application add-schema-extensions --app-id <APP_ID>${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    TESTANDO AUTENTICAÇÃO${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Após configurar as credenciais, teste a autenticação:"
echo ""
echo "1. Teste com um usuário:"
echo -e "  ${GREEN}himmelblau auth-test usuario@exato.digital${NC}"
echo ""
echo "2. Enumere usuários e grupos:"
echo -e "  ${GREEN}sudo himmelblau enumerate${NC}"
echo ""
echo "3. Verifique no sistema:"
echo -e "  ${GREEN}getent passwd usuario@exato.digital${NC}"
echo ""

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}    COMANDOS ÚTEIS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

cat << 'EOF'
# Listar aplicações no tenant
sudo himmelblau application list

# Verificar credenciais configuradas
sudo himmelblau cred list

# Limpar cache
sudo himmelblau cache-clear

# Gerenciar usuários
sudo himmelblau user list
sudo himmelblau user set-posix-attributes <USER_ID> --uid <UID> --gid <GID>

# Gerenciar grupos
sudo himmelblau group list
sudo himmelblau group set-posix-attributes <GROUP_ID> --gid <GID>

# Mapear IDs estaticamente (migração)
sudo himmelblau idmap add <USER_ID> --uid <UID>
EOF

echo ""
echo -e "${GREEN}Script finalizado!${NC}"
echo "Siga as instruções acima para completar a configuração."