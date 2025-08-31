#!/usr/bin/env bash
# finalize-himmelblau.sh - Finaliza instalação do Himmelblau já compilado
# Este script instala os binários já compilados e configura tudo para funcionar

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
ENTRA_TENANT_ID="c902ee7d-d8f4-44e7-a09e-bf42b25fa285"
ENTRA_DOMAIN="exato.digital"

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}    Finalizando Instalação do Himmelblau${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Verificar se estamos no diretório correto
if [[ ! -d "/tmp/himmelblau/target/release" ]]; then
    echo -e "${RED}ERRO: Diretório de build não encontrado!${NC}"
    echo "Execute primeiro: ./install-himmelblau-complete.sh"
    exit 1
fi

cd /tmp/himmelblau

echo -e "${BLUE}[1/7]${NC} Instalando binários principais..."
sudo install -Dm755 target/release/aad-tool /usr/bin/himmelblau
echo "  ✓ himmelblau CLI instalado"

sudo install -Dm755 target/release/himmelblaud /usr/bin/himmelblaud  
echo "  ✓ himmelblaud daemon instalado"

if [[ -f target/release/broker ]]; then
    sudo install -Dm755 target/release/broker /usr/bin/himmelblau-broker
    echo "  ✓ himmelblau-broker instalado"
fi

echo -e "${BLUE}[2/7]${NC} Procurando e instalando módulos PAM/NSS..."
# Procurar módulo PAM
PAM_MODULE=$(find target/release -name "*pam*.so" -type f 2>/dev/null | head -1)
if [[ -n "$PAM_MODULE" ]]; then
    sudo install -Dm755 "$PAM_MODULE" /usr/lib/security/pam_himmelblau.so
    echo "  ✓ PAM module instalado: $PAM_MODULE"
else
    echo -e "  ${YELLOW}⚠ PAM module não encontrado${NC}"
fi

# Procurar módulo NSS
NSS_MODULE=$(find target/release -name "*nss*.so" -type f 2>/dev/null | head -1)
if [[ -n "$NSS_MODULE" ]]; then
    sudo install -Dm755 "$NSS_MODULE" /usr/lib/libnss_himmelblau.so.2
    echo "  ✓ NSS module instalado: $NSS_MODULE"
else
    echo -e "  ${YELLOW}⚠ NSS module não encontrado${NC}"
fi

echo -e "${BLUE}[3/7]${NC} Instalando serviço systemd..."
if [[ -f platform/debian/himmelblaud.service ]]; then
    sudo install -Dm644 platform/debian/himmelblaud.service /usr/lib/systemd/system/himmelblaud.service
else
    sudo tee /usr/lib/systemd/system/himmelblaud.service > /dev/null << 'EOF'
[Unit]
Description=Himmelblau Authentication Daemon
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/himmelblaud
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
fi
sudo systemctl daemon-reload
echo "  ✓ Serviço systemd configurado"

echo -e "${BLUE}[4/7]${NC} Criando diretórios e configuração..."
sudo mkdir -p /etc/himmelblau /var/lib/himmelblau /var/cache/himmelblau /var/cache/himmelblau-policies /var/log/himmelblau

sudo tee /etc/himmelblau/himmelblau.conf > /dev/null << EOF
[global]
tenant_id = $ENTRA_TENANT_ID
domain = $ENTRA_DOMAIN
cache_timeout = 3600
offline_timeout = 86400
require_mfa = false
log_level = info
log_file = /var/log/himmelblau/himmelblau.log
EOF
echo "  ✓ Configuração criada"

echo -e "${BLUE}[5/7]${NC} Configurando PAM (com segurança)..."
if [[ -f /usr/lib/security/pam_himmelblau.so ]]; then
    sudo cp /etc/pam.d/system-auth /etc/pam.d/system-auth.pre-himmelblau 2>/dev/null || true
    
    if ! grep -q "pam_himmelblau" /etc/pam.d/system-auth; then
        sudo sed -i '/auth.*pam_unix.so/i auth       [success=2 default=ignore]  pam_himmelblau.so' /etc/pam.d/system-auth
        sudo sed -i '/account.*pam_unix.so/i account    [success=1 default=ignore]  pam_himmelblau.so' /etc/pam.d/system-auth
        sudo sed -i '/session.*pam_unix.so/a session     optional    pam_himmelblau.so' /etc/pam.d/system-auth
        echo "  ✓ PAM configurado"
    else
        echo "  ✓ PAM já configurado"
    fi
fi

echo -e "${BLUE}[6/7]${NC} Configurando NSS (com segurança)..."
if [[ -f /usr/lib/libnss_himmelblau.so.2 ]]; then
    sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.pre-himmelblau 2>/dev/null || true
    
    if ! grep -q "himmelblau" /etc/nsswitch.conf; then
        sudo sed -i 's/^passwd:.*/passwd: files himmelblau systemd/' /etc/nsswitch.conf
        sudo sed -i 's/^group:.*/group: files himmelblau systemd/' /etc/nsswitch.conf
        sudo sed -i 's/^shadow:.*/shadow: files himmelblau/' /etc/nsswitch.conf
        echo "  ✓ NSS configurado"
    else
        echo "  ✓ NSS já configurado"
    fi
fi

echo -e "${BLUE}[7/7]${NC} Iniciando serviço Himmelblau..."
sudo systemctl enable himmelblaud
sudo systemctl restart himmelblaud

if systemctl is-active --quiet himmelblaud; then
    echo -e "  ${GREEN}✓ Serviço rodando!${NC}"
else
    echo -e "  ${YELLOW}⚠ Serviço não iniciou - verifique logs${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}          ✅ INSTALAÇÃO COMPLETA!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Verificação final
echo "📋 Status da instalação:"
echo -n "  • himmelblau CLI: "
which himmelblau >/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
echo -n "  • himmelblaud daemon: "
which himmelblaud >/dev/null && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
echo -n "  • PAM module: "
[[ -f /usr/lib/security/pam_himmelblau.so ]] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
echo -n "  • NSS module: "
[[ -f /usr/lib/libnss_himmelblau.so.2 ]] && echo -e "${GREEN}✓${NC}" || echo -e "${RED}✗${NC}"
echo -n "  • Serviço: "
systemctl is-active --quiet himmelblaud && echo -e "${GREEN}✓ Rodando${NC}" || echo -e "${YELLOW}⚠ Parado${NC}"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}          🎯 AGORA VAMOS INGRESSAR NO DOMÍNIO!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Teste primeiro a autenticação local:${NC}"
echo -e "  ${BLUE}sudo -v${NC}"
echo ""
echo -e "${GREEN}Se funcionou, vamos ingressar no Microsoft Entra ID!${NC}"
echo ""
echo -e "Executar agora o ingresso no domínio? (s/n)"
read -r response

if [[ "$response" =~ ^[sS]$ ]]; then
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}         INGRESSANDO NO DOMÍNIO MICROSOFT ENTRA ID${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "📝 Instruções:"
    echo "  1. Será aberto o navegador para autenticação"
    echo "  2. Faça login com seu usuário @exato.digital"
    echo "  3. Autorize o dispositivo"
    echo "  4. Aguarde a confirmação"
    echo ""
    echo -e "${YELLOW}Iniciando em 3 segundos...${NC}"
    sleep 3
    
    sudo himmelblau domain join
    
    echo ""
    echo -e "${BLUE}Verificando status...${NC}"
    if sudo himmelblau domain status 2>/dev/null | grep -q "Joined"; then
        echo -e "${GREEN}✅ SUCESSO! Domínio ingressado!${NC}"
        echo ""
        echo "Agora teste com seu usuário:"
        echo -e "  ${BLUE}getent passwd seu.usuario@exato.digital${NC}"
        echo ""
        echo "Para fazer login:"
        echo "  • Terminal: su - usuario@exato.digital"
        echo "  • Interface gráfica: use usuario@exato.digital na tela de login"
    else
        echo -e "${YELLOW}Verifique o status:${NC}"
        echo -e "  ${BLUE}sudo himmelblau domain status${NC}"
        echo -e "  ${BLUE}sudo journalctl -u himmelblaud -f${NC}"
    fi
else
    echo ""
    echo "Quando estiver pronto, execute:"
    echo -e "  ${GREEN}sudo himmelblau domain join${NC}"
fi

echo ""
echo -e "${GREEN}Processo finalizado!${NC}"