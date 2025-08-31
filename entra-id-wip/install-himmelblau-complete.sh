#!/usr/bin/env bash
# install-himmelblau-complete.sh - Complete automated Himmelblau installation for Microsoft Entra ID
#
# This script performs the entire installation process automatically:
# - Builds from source
# - Installs all components
# - Configures PAM/NSS safely
# - Sets up the service
# - Ready for domain join

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ENTRA_TENANT_ID="c902ee7d-d8f4-44e7-a09e-bf42b25fa285"
ENTRA_DOMAIN="exato.digital"
export HIMMELBLAU_ALLOW_MISSING_SELINUX=1

# Logging
LOG_FILE="/tmp/himmelblau-install-$(date +%Y%m%d_%H%M%S).log"
exec 2> >(tee -a "$LOG_FILE" >&2)

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}    Himmelblau - Microsoft Entra ID Integration Installer${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Tenant ID: $ENTRA_TENANT_ID"
echo "  Domain: $ENTRA_DOMAIN"
echo "  Log file: $LOG_FILE"
echo ""

# Function to print status
status() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Step 1: Create backup
status "Creating system backup..."
BACKUP_DIR="/home/opik/backups/himmelblau-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup critical files (if they exist)
if [[ -d /etc/pam.d ]]; then
    cp -r /etc/pam.d "$BACKUP_DIR/pam.d.backup" 2>/dev/null || warning "Could not backup PAM configs"
fi
if [[ -f /etc/nsswitch.conf ]]; then
    cp /etc/nsswitch.conf "$BACKUP_DIR/nsswitch.conf.backup" 2>/dev/null || warning "Could not backup NSS config"
fi

# Create restore script
cat > "$BACKUP_DIR/restore.sh" << 'RESTORE_SCRIPT'
#!/bin/bash
echo "Restoring system from backup..."
BACKUP_DIR="$(dirname "$0")"

# Stop himmelblau
sudo systemctl stop himmelblaud 2>/dev/null || true
sudo systemctl disable himmelblaud 2>/dev/null || true

# Restore configs
if [[ -d "$BACKUP_DIR/pam.d.backup" ]]; then
    sudo cp -r "$BACKUP_DIR/pam.d.backup"/* /etc/pam.d/
    echo "PAM restored"
fi
if [[ -f "$BACKUP_DIR/nsswitch.conf.backup" ]]; then
    sudo cp "$BACKUP_DIR/nsswitch.conf.backup" /etc/nsswitch.conf
    echo "NSS restored"
fi

echo "System restored. Please reboot if authentication issues persist."
RESTORE_SCRIPT
chmod +x "$BACKUP_DIR/restore.sh"
success "Backup created at $BACKUP_DIR"

# Step 2: Clean and prepare
status "Cleaning previous builds..."
cd /tmp
rm -rf himmelblau-build-* himmelblau 2>/dev/null || true

# Step 3: Clone repository
status "Cloning Himmelblau repository..."
if ! git clone --depth 1 https://github.com/himmelblau-idm/himmelblau.git; then
    error "Failed to clone repository"
fi
cd himmelblau

# Step 4: Build from source
status "Building Himmelblau (this will take 5-10 minutes)..."
if ! cargo build --release 2>&1 | tee -a "$LOG_FILE"; then
    error "Build failed - check $LOG_FILE for details"
fi
success "Build completed successfully"

# Step 5: Install binaries
status "Installing Himmelblau binaries..."

# Main binaries
if [[ -f target/release/aad-tool ]]; then
    sudo install -Dm755 target/release/aad-tool /usr/bin/himmelblau
    success "himmelblau CLI installed"
else
    warning "aad-tool not found"
fi

if [[ -f target/release/himmelblaud ]]; then
    sudo install -Dm755 target/release/himmelblaud /usr/bin/himmelblaud
    success "himmelblaud daemon installed"
else
    error "himmelblaud not found - build may have failed"
fi

if [[ -f target/release/broker ]]; then
    sudo install -Dm755 target/release/broker /usr/bin/himmelblau-broker
    success "himmelblau-broker installed"
fi

# PAM module - check multiple possible locations
PAM_INSTALLED=false
for pam_path in "target/release/libpam_himmelblau.so" "target/release/deps/libpam_himmelblau.so"; do
    if [[ -f "$pam_path" ]]; then
        sudo install -Dm755 "$pam_path" /usr/lib/security/pam_himmelblau.so
        success "PAM module installed"
        PAM_INSTALLED=true
        break
    fi
done
if [[ "$PAM_INSTALLED" == "false" ]]; then
    warning "PAM module not found - authentication may not work"
fi

# NSS module - check multiple possible locations
NSS_INSTALLED=false
for nss_path in "target/release/libnss_himmelblau.so" "target/release/deps/libnss_himmelblau.so"; do
    if [[ -f "$nss_path" ]]; then
        sudo install -Dm755 "$nss_path" /usr/lib/libnss_himmelblau.so.2
        success "NSS module installed"
        NSS_INSTALLED=true
        break
    fi
done
if [[ "$NSS_INSTALLED" == "false" ]]; then
    warning "NSS module not found - user lookups may not work"
fi

# Step 6: Install systemd service
status "Installing systemd service..."
if [[ -f platform/debian/himmelblaud.service ]]; then
    sudo install -Dm644 platform/debian/himmelblaud.service /usr/lib/systemd/system/himmelblaud.service
elif [[ -f platform/opensuse/himmelblaud.service ]]; then
    sudo install -Dm644 platform/opensuse/himmelblaud.service /usr/lib/systemd/system/himmelblaud.service
else
    warning "Service file not found - creating basic one"
    sudo tee /usr/lib/systemd/system/himmelblaud.service > /dev/null << 'SERVICE_FILE'
[Unit]
Description=Himmelblau Authentication Daemon
After=network.target

[Service]
Type=notify
ExecStart=/usr/bin/himmelblaud
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
SERVICE_FILE
fi
sudo systemctl daemon-reload
success "Systemd service configured"

# Step 7: Create directories and configuration
status "Creating configuration..."
sudo mkdir -p /etc/himmelblau /var/lib/himmelblau /var/cache/himmelblau /var/cache/himmelblau-policies /var/log/himmelblau

# Create configuration file
sudo tee /etc/himmelblau/himmelblau.conf > /dev/null << EOF
[global]
# Microsoft Entra ID Configuration
tenant_id = $ENTRA_TENANT_ID
domain = $ENTRA_DOMAIN

# Authentication settings
cache_timeout = 3600
offline_timeout = 86400
require_mfa = false

# Logging
log_level = info
log_file = /var/log/himmelblau/himmelblau.log
EOF
success "Configuration created"

# Step 8: Configure PAM (SAFELY)
if [[ "$PAM_INSTALLED" == "true" ]]; then
    status "Configuring PAM safely..."
    
    # Backup current PAM config
    sudo cp /etc/pam.d/system-auth /etc/pam.d/system-auth.pre-himmelblau 2>/dev/null || true
    
    # Add himmelblau to PAM - as SUFFICIENT so local auth still works
    if ! grep -q "pam_himmelblau" /etc/pam.d/system-auth 2>/dev/null; then
        # Add before pam_unix.so
        sudo sed -i '/auth.*pam_unix.so/i auth       [success=2 default=ignore]  pam_himmelblau.so' /etc/pam.d/system-auth 2>/dev/null || warning "Could not modify PAM auth"
        sudo sed -i '/account.*pam_unix.so/i account    [success=1 default=ignore]  pam_himmelblau.so' /etc/pam.d/system-auth 2>/dev/null || warning "Could not modify PAM account"
        sudo sed -i '/session.*pam_unix.so/a session     optional    pam_himmelblau.so' /etc/pam.d/system-auth 2>/dev/null || warning "Could not modify PAM session"
        success "PAM configured with Himmelblau support"
    else
        warning "Himmelblau already in PAM configuration"
    fi
fi

# Step 9: Configure NSS (SAFELY)
if [[ "$NSS_INSTALLED" == "true" ]]; then
    status "Configuring NSS safely..."
    
    # Backup current NSS config
    sudo cp /etc/nsswitch.conf /etc/nsswitch.conf.pre-himmelblau 2>/dev/null || true
    
    # Add himmelblau to NSS - keeping files as primary
    if ! grep -q "himmelblau" /etc/nsswitch.conf 2>/dev/null; then
        sudo sed -i 's/^passwd:.*/passwd: files himmelblau systemd/' /etc/nsswitch.conf
        sudo sed -i 's/^group:.*/group: files himmelblau systemd/' /etc/nsswitch.conf
        sudo sed -i 's/^shadow:.*/shadow: files himmelblau/' /etc/nsswitch.conf
        success "NSS configured with Himmelblau support"
    else
        warning "Himmelblau already in NSS configuration"
    fi
fi

# Step 10: Start service
status "Starting Himmelblau service..."
sudo systemctl enable himmelblaud
if sudo systemctl start himmelblaud; then
    success "Himmelblau service started"
else
    warning "Service failed to start - check: sudo journalctl -u himmelblaud"
fi

# Final verification
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Installation Complete!${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check what's installed
echo "📋 Installation Summary:"
echo -n "  • himmelblau CLI: "
[[ -f /usr/bin/himmelblau ]] && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${RED}✗ Missing${NC}"

echo -n "  • himmelblaud daemon: "
[[ -f /usr/bin/himmelblaud ]] && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${RED}✗ Missing${NC}"

echo -n "  • PAM module: "
[[ -f /usr/lib/security/pam_himmelblau.so ]] && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${RED}✗ Missing${NC}"

echo -n "  • NSS module: "
[[ -f /usr/lib/libnss_himmelblau.so.2 ]] && echo -e "${GREEN}✓ Installed${NC}" || echo -e "${RED}✗ Missing${NC}"

echo -n "  • Service status: "
if systemctl is-active --quiet himmelblaud; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${YELLOW}⚠ Not running${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}          🎯 PRÓXIMOS PASSOS - INGRESSO NO DOMÍNIO${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}PASSO 1: Teste a autenticação local${NC}"
echo "  Execute: ${BLUE}sudo -v${NC}"
echo "  ✓ Se funcionar, seu sistema está seguro"
echo ""
echo -e "${YELLOW}PASSO 2: Ingresse no domínio Microsoft Entra ID${NC}"
echo "  Execute: ${BLUE}sudo himmelblau domain join${NC}"
echo ""
echo "  O comando vai:"
echo "  • Pedir suas credenciais Microsoft (user@exato.digital)"
echo "  • Fazer autenticação OAuth2 no navegador"
echo "  • Registrar esta máquina no Entra ID"
echo ""
echo -e "${YELLOW}PASSO 3: Teste o login com usuário do Entra ID${NC}"
echo "  Após o join bem-sucedido, teste:"
echo ""
echo "  a) Verificar usuário: ${BLUE}getent passwd seu.usuario@exato.digital${NC}"
echo "  b) Testar sudo: ${BLUE}sudo -u seu.usuario@exato.digital whoami${NC}"
echo "  c) Login gráfico: Na tela de login, use: ${GREEN}usuario@exato.digital${NC}"
echo ""
echo -e "${YELLOW}PASSO 4: Configure permissões (OPCIONAL)${NC}"
echo "  Para dar sudo a usuários do Entra ID:"
echo "  ${BLUE}sudo usermod -aG wheel seu.usuario@exato.digital${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    🔍 TROUBLESHOOTING${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "❓ Se o join falhar:"
echo "  • Verifique conectividade: ${BLUE}ping login.microsoftonline.com${NC}"
echo "  • Verifique logs: ${BLUE}sudo journalctl -u himmelblaud -f${NC}"
echo "  • Tente novamente: ${BLUE}sudo himmelblau domain leave && sudo himmelblau domain join${NC}"
echo ""
echo "❓ Se o login não funcionar:"
echo "  • Verifique o serviço: ${BLUE}systemctl status himmelblaud${NC}"
echo "  • Reinicie o serviço: ${BLUE}sudo systemctl restart himmelblaud${NC}"
echo "  • Verifique cache: ${BLUE}sudo himmelblau cache clear${NC}"
echo ""
echo "❓ Para fazer logout do domínio:"
echo "  ${BLUE}sudo himmelblau domain leave${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    📁 INFORMAÇÕES ÚTEIS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "📁 Backup location: ${YELLOW}$BACKUP_DIR${NC}"
echo "📄 Log file: ${YELLOW}$LOG_FILE${NC}"
echo "🔧 Config file: ${YELLOW}/etc/himmelblau/himmelblau.conf${NC}"
echo ""
echo "🆘 EMERGÊNCIA - Restaurar sistema original:"
echo "  ${RED}bash $BACKUP_DIR/restore.sh${NC}"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Offer to run domain join immediately
echo -e "${GREEN}Deseja ingressar no domínio agora? (s/n)${NC}"
read -r -p "> " response
if [[ "$response" =~ ^[sS]$ ]]; then
    echo ""
    echo -e "${BLUE}Iniciando ingresso no domínio...${NC}"
    echo -e "${YELLOW}NOTA: Você será redirecionado para o navegador para autenticação${NC}"
    echo ""
    sudo himmelblau domain join
    
    # After join, test if it worked
    echo ""
    echo -e "${BLUE}Verificando status do domínio...${NC}"
    if sudo himmelblau domain status 2>/dev/null | grep -q "Joined"; then
        echo -e "${GREEN}✓ Domínio ingressado com sucesso!${NC}"
        echo ""
        echo "Teste com seu usuário:"
        echo "  ${BLUE}getent passwd seu.usuario@exato.digital${NC}"
    else
        echo -e "${YELLOW}⚠ Verifique o status manualmente:${NC}"
        echo "  ${BLUE}sudo himmelblau domain status${NC}"
    fi
else
    echo ""
    echo -e "${BLUE}OK! Quando estiver pronto, execute:${NC}"
    echo "  ${GREEN}sudo himmelblau domain join${NC}"
fi

echo ""
success "Himmelblau está pronto para autenticação Microsoft Entra ID!"