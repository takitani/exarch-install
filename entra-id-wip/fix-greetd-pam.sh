#!/bin/bash

# Script para corrigir problemas de PAM com greetd

set -e

echo "========================================"
echo "Corrigindo configuração PAM do greetd"
echo "========================================"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Criar configuração PAM específica para greetd-greeter
echo -e "${GREEN}[1/4]${NC} Criando configuração PAM para greetd-greeter..."
sudo tee /etc/pam.d/greetd-greeter > /dev/null << 'EOF'
#%PAM-1.0
auth        required    pam_permit.so
account     required    pam_permit.so
session     required    pam_permit.so
EOF

# Step 2: Ajustar configuração do greetd principal
echo -e "${GREEN}[2/4]${NC} Ajustando configuração PAM do greetd..."
sudo tee /etc/pam.d/greetd > /dev/null << 'EOF'
#%PAM-1.0
auth        requisite   pam_nologin.so
auth        include     system-local-login
account     include     system-local-login
session     include     system-local-login
EOF

# Step 3: Adicionar usuário greeter ao grupo tty para acesso ao terminal
echo -e "${GREEN}[3/4]${NC} Adicionando usuário greeter aos grupos necessários..."
sudo usermod -a -G tty greeter

# Step 4: Reiniciar serviço greetd
echo -e "${GREEN}[4/4]${NC} Reiniciando serviço greetd..."
sudo systemctl restart greetd

echo
echo "========================================"
echo -e "${GREEN}✓ Correção aplicada!${NC}"
echo "========================================"
echo
echo "Status do greetd:"
systemctl status greetd --no-pager -n 5 || true
echo
echo "Se ainda houver problemas, tente:"
echo "  sudo journalctl -u greetd -f"
echo