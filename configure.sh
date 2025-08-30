#!/usr/bin/env bash

# Script para configurar facilmente o arquivo .env
# Uso: ./configure.sh

set -euo pipefail

# Cores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}Configuração do Exarch Scripts${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo

env_file="$(dirname "$0")/.env"

# Verificar se já existe
if [[ -f "$env_file" ]]; then
    echo -e "${YELLOW}Arquivo .env já existe.${NC}"
    echo "Conteúdo atual:"
    echo "---"
    cat "$env_file"
    echo "---"
    echo
    echo -n "Deseja reconfigurar? (s/n): "
    read -r resposta
    
    if [[ "$resposta" != "s" && "$resposta" != "S" ]]; then
        echo "Configuração cancelada"
        exit 0
    fi
    
    # Backup
    cp "$env_file" "$env_file.backup.$(date +%Y%m%d_%H%M%S)"
    echo "Backup criado"
fi

echo "Vamos configurar suas informações pessoais/da empresa:"
echo

# Coletar URL do 1Password
echo -n "URL do 1Password da sua empresa (ex: suaempresa.1password.com): "
read -r onepass_url

# Garantir que tem https://
if [[ ! "$onepass_url" =~ ^https:// ]]; then
    if [[ "$onepass_url" =~ ^http:// ]]; then
        onepass_url="${onepass_url/http:/https:}"
    else
        onepass_url="https://$onepass_url"
    fi
fi

# Garantir que termina com /
if [[ ! "$onepass_url" =~ /$ ]]; then
    onepass_url="$onepass_url/"
fi

# Coletar email (opcional)
echo -n "Seu email de login (opcional, deixe vazio para ser perguntado sempre): "
read -r onepass_email

# Criar arquivo .env
cat > "$env_file" << EOF
# Configurações do Exarch Scripts
# Este arquivo contém configurações específicas da empresa/usuário

# 1Password Configuration
ONEPASSWORD_URL="$onepass_url"
ONEPASSWORD_EMAIL="$onepass_email"

# Outras configurações podem ser adicionadas aqui no futuro
# COMPANY_NAME="Sua Empresa"
# DEFAULT_GIT_USER=""
# DEFAULT_GIT_EMAIL=""
EOF

echo
echo -e "${GREEN}✓ Arquivo .env criado com sucesso!${NC}"
echo
echo "Configuração salva:"
echo "  • URL: $onepass_url"
if [[ -n "$onepass_email" ]]; then
    echo "  • Email: $onepass_email"
else
    echo "  • Email: (será solicitado quando necessário)"
fi

echo
echo "Agora você pode usar:"
echo "  • ./install.sh --1pass"
echo "  • ./1password-helper.sh"
echo
echo "A URL e email serão usados automaticamente nos scripts!"