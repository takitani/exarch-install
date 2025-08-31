#!/bin/bash

# Script para configurar client_id do Entra ID no himmelblau

set -e

echo "========================================"
echo "Configurando Client ID do Entra ID"
echo "========================================"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "PROBLEMA IDENTIFICADO:"
echo "- O himmelblau não tem client_id configurado"
echo "- Logs mostram: 'Failed to acquire user object from graph'"
echo "- Logs mostram: 'Authentication failed. Hello key missing.'"
echo
echo "SOLUÇÕES:"
echo

echo -e "${GREEN}OPÇÃO 1: Criar novo aplicativo no Azure AD${NC}"
echo "sudo himmelblau application create --display-name 'Omarchy Linux Login'"
echo
echo "Isso vai:"
echo "- Criar um novo app registration no Azure AD"
echo "- Configurar automaticamente o client_id no himmelblau.conf"
echo "- Gerar um client_secret se necessário"
echo

echo -e "${GREEN}OPÇÃO 2: Usar client_id existente${NC}"
echo "Se você já tem um client_id de outro aplicativo:"
echo "sudo himmelblau application configure --client-id SEU_CLIENT_ID_AQUI"
echo

echo -e "${GREEN}OPÇÃO 3: Configuração manual${NC}"
echo "Editar /etc/himmelblau/himmelblau.conf e adicionar:"
echo "client_id = SEU_CLIENT_ID_AQUI"
echo "client_secret = SEU_CLIENT_SECRET_AQUI  # se necessário"
echo

echo -e "${YELLOW}DEPOIS DE CONFIGURAR:${NC}"
echo "sudo systemctl restart himmelblaud"
echo "Tente fazer login novamente com andre@exato.digital"
echo

echo "========================================"
echo "Qual opção você quer usar?"
echo "1) Criar novo aplicativo (recomendado)"
echo "2) Usar client_id existente"
echo "3) Configuração manual"
echo "========================================"