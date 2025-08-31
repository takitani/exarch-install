#!/bin/bash

# Correção DEFINITIVA para problema de Hello PIN no Himmelblau
# Este script resolve o problema de "Hello key missing" após criação do PIN

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
step() { echo -e "${MAGENTA}[STEP]${NC} $1"; }

# Verificar se está rodando como root
if [[ $EUID -eq 0 ]]; then
   error "Este script não deve ser executado como root"
   exit 1
fi

clear
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     CORREÇÃO DEFINITIVA - Himmelblau Hello PIN              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

# Obter email do usuário
USER_EMAIL="${1:-andre@exato.digital}"
log "Aplicando correção para usuário: $USER_EMAIL"
echo

# 1. PARAR O SERVIÇO
step "1/7 - Parando serviço himmelblaud..."
sudo systemctl stop himmelblaud
sleep 2
success "Serviço parado"

# 2. LIMPAR CACHE CORROMPIDO
step "2/7 - Limpando cache corrompido do usuário..."
sudo rm -rf /var/lib/himmelblau/users/"$USER_EMAIL" 2>/dev/null || true
sudo rm -rf /var/cache/himmelblau/ccache/*"$USER_EMAIL"* 2>/dev/null || true
sudo rm -rf /var/cache/himmelblau/prt_cache/"$USER_EMAIL" 2>/dev/null || true
success "Cache limpo"

# 3. VERIFICAR E CORRIGIR CONFIGURAÇÃO
step "3/7 - Verificando configuração do Himmelblau..."

HIMMELBLAU_CONF="/etc/himmelblau/himmelblau.conf"

# Fazer backup da configuração atual
sudo cp "$HIMMELBLAU_CONF" "$HIMMELBLAU_CONF.bak.$(date +%Y%m%d_%H%M%S)"

# Criar configuração otimizada
sudo tee "$HIMMELBLAU_CONF" > /dev/null << 'EOF'
# Himmelblau configuration - Microsoft Entra ID
# Configuração otimizada para Hello PIN

[global]
# Domínios
domains = exato.digital
pam_allow_groups = exato.digital

# IDs do tenant e aplicação
tenant_id = 17dc9f19-1a4b-4b02-a8f9-0db6e0ada0ed
app_id = c2dea2e2-0eb9-4749-a79e-fd893e2a0c96

# Hello PIN - CRÍTICO para funcionamento
hello_enabled = true
hello_pin_min_length = 4
prt_renewal = true
enable_hello_pin_fetch = true

# Configurações de ID mapping
idmap_range = 200000-2000200000
selinux = false

# Cache e home directories
home_prefix = /home/
home_attr = homeDirectory
home_alias = sAMAccountName
shell = /bin/bash

# Logging
log_level = 3
EOF

success "Configuração atualizada com suporte completo para Hello PIN"

# 4. CORRIGIR PERMISSÕES
step "4/7 - Corrigindo permissões dos diretórios..."
sudo mkdir -p /var/lib/himmelblau/{users,cache}
sudo mkdir -p /var/cache/himmelblau/{ccache,prt_cache,tgt_cache}
# Definir permissões sem depender de usuário específico
sudo chmod 755 /var/lib/himmelblau
sudo chmod 700 /var/lib/himmelblau/users
sudo chmod 755 /var/cache/himmelblau
sudo chmod 700 /var/cache/himmelblau/ccache
success "Permissões corrigidas"

# 5. CONFIGURAR PAM CORRETAMENTE
step "5/7 - Verificando configuração PAM..."

# Verificar se o módulo está na posição correta
if ! grep -q "auth.*pam_himmelblau.so" /etc/pam.d/system-auth; then
    warn "Módulo PAM não configurado, aplicando configuração..."
    
    # Fazer backup
    sudo cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak.$(date +%Y%m%d_%H%M%S)
    
    # Aplicar configuração correta
    sudo tee /etc/pam.d/system-auth > /dev/null << 'EOF'
#%PAM-1.0

auth       required                    pam_faillock.so preauth silent deny=10 unlock_time=120
-auth      [success=2 default=ignore]  pam_systemd_home.so
auth       [success=2 default=ignore]  pam_himmelblau.so
auth       [success=1 default=bad]     pam_unix.so          try_first_pass nullok
auth       [default=die]               pam_faillock.so authfail deny=10 unlock_time=120
auth       optional                    pam_permit.so
auth       required                    pam_env.so
auth       required                    pam_faillock.so      authsucc

-account   [success=1 default=ignore]  pam_systemd_home.so
account    [success=1 default=ignore]  pam_himmelblau.so
account    required                    pam_unix.so
account    optional                    pam_permit.so
account    required                    pam_time.so

-password  [success=1 default=ignore]  pam_systemd_home.so
password   required                    pam_unix.so          try_first_pass nullok shadow
password   optional                    pam_permit.so

-session   optional                    pam_systemd_home.so
session    required                    pam_limits.so
session    required                    pam_unix.so
session    optional                    pam_himmelblau.so
session    optional                    pam_permit.so
EOF
    success "Configuração PAM aplicada"
else
    success "Configuração PAM já está correta"
fi

# 6. REINICIAR SERVIÇO
step "6/7 - Reiniciando serviço himmelblaud..."
sudo systemctl daemon-reload
sudo systemctl start himmelblaud
sleep 3

if systemctl is-active --quiet himmelblaud; then
    success "Serviço reiniciado com sucesso"
else
    error "Falha ao reiniciar serviço"
    sudo journalctl -u himmelblaud -n 20 --no-pager
    exit 1
fi

# 7. FORÇAR RECRIAÇÃO DO HELLO KEY
step "7/7 - Preparando para recriação do Hello PIN..."

# Criar script auxiliar para resetar PIN
cat > /tmp/reset-hello-pin.sh << 'EOF'
#!/bin/bash

# Script para forçar recriação do Hello PIN

echo "=== INSTRUÇÕES PARA RECRIAR O PIN ==="
echo
echo "1. Faça LOGOUT completo (não apenas trocar de usuário)"
echo "2. Na tela de login:"
echo "   - Digite seu email: andre@exato.digital"
echo "   - Use sua SENHA do Microsoft (NÃO o PIN)"
echo "   - Complete a autenticação MFA no celular"
echo
echo "3. Após autenticar com sucesso:"
echo "   - O sistema deve perguntar se deseja criar um PIN"
echo "   - Escolha SIM e crie um novo PIN (mínimo 4 dígitos)"
echo "   - IMPORTANTE: Aguarde a confirmação antes de continuar"
echo
echo "4. Teste o PIN:"
echo "   - Faça logout novamente"
echo "   - Tente logar usando o PIN criado"
echo
echo "Se o PIN ainda não funcionar após estes passos:"
echo "  Execute: sudo himmelblau cache clear andre@exato.digital"
echo "  E repita o processo acima"
EOF

chmod +x /tmp/reset-hello-pin.sh

# VERIFICAÇÃO FINAL
echo
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    CORREÇÃO APLICADA                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

success "Todas as correções foram aplicadas!"
echo

# Verificar logs para confirmar
log "Verificando status atual..."
if sudo journalctl -u himmelblaud -n 5 --no-pager | grep -q "Started Himmelblau"; then
    success "Serviço está rodando normalmente"
else
    warn "Verifique os logs para mais detalhes"
fi

echo
log "=== PRÓXIMOS PASSOS ==="
echo
echo "1. Execute o seguinte comando para ver as instruções:"
echo "   ${BLUE}/tmp/reset-hello-pin.sh${NC}"
echo
echo "2. Para monitorar o processo em tempo real:"
echo "   ${BLUE}sudo journalctl -u himmelblaud -f${NC}"
echo
echo "3. Para verificar se o PIN foi criado corretamente:"
echo "   ${BLUE}sudo ls -la /var/lib/himmelblau/users/$USER_EMAIL/${NC}"
echo "   (Deve aparecer arquivos relacionados ao 'hello' após criar o PIN)"
echo
warn "IMPORTANTE: Você PRECISA fazer logout e login novamente!"
warn "Use sua SENHA do Microsoft primeiro, depois crie um novo PIN"
echo

# Opção de aplicar reset automático
read -p "Deseja limpar COMPLETAMENTE o cache do usuário agora? (s/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Ss]$ ]]; then
    log "Limpando cache completo do usuário..."
    sudo himmelblau cache clear "$USER_EMAIL" 2>/dev/null || {
        sudo systemctl stop himmelblaud
        sudo rm -rf /var/lib/himmelblau/users/"$USER_EMAIL"
        sudo rm -rf /var/cache/himmelblau/*/*"$USER_EMAIL"*
        sudo systemctl start himmelblaud
    }
    success "Cache limpo! Faça logout e siga as instruções acima"
fi

echo
success "Script concluído! Boa sorte com o login!"