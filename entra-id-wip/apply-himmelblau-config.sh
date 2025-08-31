#!/bin/bash

# Script para aplicar configuração do himmelblau com client_id e client_secret

set -e

echo "========================================"
echo "Configurando himmelblau com Client ID"
echo "========================================"
echo

# Dados extraídos do arquivo
CLIENT_ID="YOUR_CLIENT_ID_HERE"
CLIENT_SECRET="YOUR_CLIENT_SECRET_HERE"
DOMAIN="exato.digital"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

# Step 1: Adicionar client_id ao himmelblau.conf
echo -e "${GREEN}[1/3]${NC} Adicionando client_id ao himmelblau.conf..."
sudo sed -i '/^domain = exato.digital/a client_id = 9669afee-37e6-47b1-9b15-da3a7c8f560d' /etc/himmelblau/himmelblau.conf

# Step 2: Configurar client_secret
echo -e "${GREEN}[2/3]${NC} Configurando client_secret..."
sudo himmelblau cred secret --client-id "$CLIENT_ID" --domain "$DOMAIN" --secret "$CLIENT_SECRET"

# Step 3: Reiniciar himmelblaud
echo -e "${GREEN}[3/3]${NC} Reiniciando himmelblaud..."
sudo systemctl restart himmelblaud

echo
echo "========================================"
echo -e "${GREEN}✓ Configuração completa!${NC}"
echo "========================================"
echo
echo "Agora você pode tentar fazer login com:"
echo "  Usuário: andre@exato.digital"
echo "  PIN: [seu PIN do Entra ID]"
echo
echo "Para monitorar logs em tempo real:"
echo "  sudo journalctl -u himmelblaud -f"