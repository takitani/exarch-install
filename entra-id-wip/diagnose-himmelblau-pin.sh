#!/bin/bash

# Script de diagnóstico completo para problema de PIN do Himmelblau
# Identifica e corrige problemas com Hello PIN no Microsoft Entra ID

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }

# Verifica se está rodando como root
if [[ $EUID -eq 0 ]]; then
   error "Este script não deve ser executado como root"
   exit 1
fi

log "=== Diagnóstico do Himmelblau Hello PIN ==="
echo

# 1. Verificar status do serviço
log "Verificando status do serviço himmelblaud..."
if systemctl is-active --quiet himmelblaud; then
    success "Serviço himmelblaud está ativo"
else
    error "Serviço himmelblaud não está ativo"
    warn "Tentando iniciar o serviço..."
    sudo systemctl start himmelblaud
fi

# 2. Analisar logs para erros específicos
log "Analisando logs recentes do Himmelblau..."
echo
echo "Últimas mensagens de erro relacionadas ao PIN:"
sudo journalctl -u himmelblaud --since "1 hour ago" 2>/dev/null | \
    grep -E "(hello|PIN|Hello key missing|Authentication failed)" | \
    tail -10 || echo "Nenhum erro recente encontrado"

# 3. Verificar configuração PAM
log "Verificando configuração PAM..."
echo
if grep -q "pam_himmelblau.so" /etc/pam.d/system-auth; then
    success "Módulo pam_himmelblau.so está configurado em system-auth"
    
    # Verificar se está na posição correta (antes de pam_unix)
    if grep -B1 "pam_unix.so.*try_first_pass" /etc/pam.d/system-auth | grep -q "pam_himmelblau.so"; then
        success "Módulo está na posição correta (antes de pam_unix)"
    else
        warn "Módulo pode estar na posição errada"
    fi
else
    error "Módulo pam_himmelblau.so não está configurado"
fi

# 4. Verificar configuração do Himmelblau
log "Verificando configuração do Himmelblau..."
if [[ -f /etc/himmelblau/himmelblau.conf ]]; then
    echo "Configuração atual:"
    sudo grep -E "(hello_enabled|hello_pin|prt_renewal|tenant_id)" /etc/himmelblau/himmelblau.conf 2>/dev/null || true
else
    error "Arquivo de configuração não encontrado"
fi

# 5. Verificar estrutura de dados do usuário
log "Verificando dados do usuário no Himmelblau..."
echo
USER_EMAIL="${1:-andre@exato.digital}"
echo "Verificando usuário: $USER_EMAIL"

# Tentar listar cache do usuário
if sudo ls /var/lib/himmelblau/users/ 2>/dev/null | grep -q "$USER_EMAIL"; then
    success "Dados do usuário encontrados"
    
    # Verificar se existe Hello key
    USER_DIR="/var/lib/himmelblau/users/$USER_EMAIL"
    if sudo ls "$USER_DIR" 2>/dev/null | grep -q "hello"; then
        success "Hello key encontrada para o usuário"
    else
        error "Hello key NÃO encontrada - este é o problema!"
        warn "O PIN foi criado mas a chave não foi salva corretamente"
    fi
else
    warn "Dados do usuário não encontrados no cache"
fi

# 6. Verificar cache Kerberos
log "Verificando cache Kerberos..."
if sudo ls /var/cache/himmelblau/ccache/ 2>/dev/null | grep -q "$USER_EMAIL"; then
    success "Cache Kerberos existe para o usuário"
else
    warn "Cache Kerberos não encontrado (pode ser recriado no próximo login)"
fi

# 7. Propor soluções
echo
log "=== DIAGNÓSTICO COMPLETO ==="
echo

PROBLEMS_FOUND=0

# Análise dos problemas encontrados
if sudo journalctl -u himmelblaud --since "1 hour ago" 2>/dev/null | grep -q "Hello key missing"; then
    error "PROBLEMA DETECTADO: Hello key missing"
    echo "  O PIN foi criado mas a chave não foi salva corretamente no Himmelblau"
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi

if sudo journalctl -u himmelblaud --since "1 hour ago" 2>/dev/null | grep -q "Kerberos credential cache load failed"; then
    warn "AVISO: Cache Kerberos expirado ou corrompido"
    echo "  Isso pode causar problemas de autenticação mas não impede o login"
    PROBLEMS_FOUND=$((PROBLEMS_FOUND + 1))
fi

# Soluções propostas
if [[ $PROBLEMS_FOUND -gt 0 ]]; then
    echo
    log "=== SOLUÇÕES RECOMENDADAS ==="
    echo
    echo "1. RESETAR COMPLETAMENTE O CACHE DO USUÁRIO:"
    echo "   sudo systemctl stop himmelblaud"
    echo "   sudo rm -rf /var/lib/himmelblau/users/$USER_EMAIL"
    echo "   sudo rm -rf /var/cache/himmelblau/ccache/*$USER_EMAIL*"
    echo "   sudo systemctl start himmelblaud"
    echo
    echo "2. FORÇAR RECRIAÇÃO DO PIN:"
    echo "   - Faça logout completo"
    echo "   - No login, use sua senha do Microsoft ao invés do PIN"
    echo "   - O sistema deve pedir para criar um novo PIN"
    echo
    echo "3. SE O PROBLEMA PERSISTIR, DESABILITAR TEMPORARIAMENTE O HELLO PIN:"
    echo "   Edite /etc/himmelblau/himmelblau.conf e adicione:"
    echo "   hello_enabled = false"
    echo
    echo "4. APLICAR CORREÇÃO AUTOMÁTICA:"
    echo "   Execute: ./fix-himmelblau-pin-final.sh"
else
    success "Nenhum problema crítico detectado"
    echo "Se ainda assim o PIN não funciona, tente a solução 1 acima"
fi

echo
log "Diagnóstico completo. Para mais detalhes, execute:"
echo "  sudo journalctl -u himmelblaud -f"
echo "  (em outro terminal durante tentativa de login)"