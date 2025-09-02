#!/usr/bin/env bash

# Script para testar e corrigir problemas de DNS
# Uso: ./test-dns-fix.sh

set -euo pipefail

# Cores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}Teste e Correção de DNS${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo

# Função para mostrar status
show_status() {
    echo -e "${BOLD}Status Atual:${NC}"
    echo "═══════════════"
    
    echo -e "\n${CYAN}1. systemd-resolved:${NC}"
    if systemctl is-active systemd-resolved >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Ativo${NC}"
    else
        echo -e "   ${RED}✗ Inativo${NC}"
    fi
    
    echo -e "\n${CYAN}2. /etc/resolv.conf:${NC}"
    if [[ -f /etc/resolv.conf ]]; then
        echo "   Conteúdo:"
        cat /etc/resolv.conf | sed 's/^/   /'
    else
        echo -e "   ${RED}✗ Arquivo não existe${NC}"
    fi
    
    echo -e "\n${CYAN}3. resolvectl status:${NC}"
    if command_exists resolvectl; then
        resolvectl status | head -20 | sed 's/^/   /'
    else
        echo -e "   ${RED}✗ resolvectl não encontrado${NC}"
    fi
    
    echo -e "\n${CYAN}4. Teste de DNS:${NC}"
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ DNS funcionando${NC}"
    else
        echo -e "   ${RED}✗ DNS falhando${NC}"
        echo "   Tentando com curl..."
        if curl -s --connect-timeout 5 "https://google.com" >/dev/null 2>&1; then
            echo -e "   ${YELLOW}⚠ curl funciona, mas nslookup falha${NC}"
        else
            echo -e "   ${RED}✗ curl também falha${NC}"
        fi
    fi
    
    echo -e "\n${CYAN}5. Verificação de conectividade:${NC}"
    if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ Conectividade IP OK${NC}"
    else
        echo -e "   ${RED}✗ Sem conectividade IP${NC}"
    fi
}

# Função para corrigir DNS
fix_dns() {
    echo -e "\n${BOLD}Aplicando correções...${NC}"
    echo "═══════════════════"
    
    # 1. Verificar se systemd-resolved está rodando
    if ! systemctl is-active systemd-resolved >/dev/null 2>&1; then
        echo "1. Iniciando systemd-resolved..."
        sudo systemctl start systemd-resolved
        sudo systemctl enable systemd-resolved
    fi
    
    # 2. Verificar se está em modo stub (problema comum)
    if [[ -L /etc/resolv.conf ]] && [[ "$(readlink /etc/resolv.conf)" == "/run/systemd/resolve/stub-resolv.conf" ]]; then
        echo "2. Detectado modo stub, configurando para modo managed..."
        sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    elif [[ -L /etc/resolv.conf ]] && [[ "$(readlink /etc/resolv.conf)" == "/run/systemd/resolve/resolv.conf" ]]; then
        echo "2. Já em modo managed, verificando configuração..."
    else
        echo "2. Configurando systemd-resolved para modo managed..."
        sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    fi
    
    # 3. Reiniciar o serviço
    echo "3. Reiniciando systemd-resolved..."
    sudo systemctl restart systemd-resolved
    
    # 4. Aguardar um pouco
    echo "4. Aguardando estabilização..."
    sleep 3
    
    # 5. Verificar se está funcionando
    echo "5. Verificando status..."
    if resolvectl status 2>/dev/null | grep -q "resolv.conf mode: managed"; then
        echo -e "   ${GREEN}✓ Modo managed ativado${NC}"
    else
        echo -e "   ${YELLOW}⚠ Ainda não em modo managed${NC}"
    fi
    
    # 6. Testar DNS
    echo "6. Testando DNS..."
    if nslookup google.com >/dev/null 2>&1; then
        echo -e "   ${GREEN}✓ DNS funcionando após correção${NC}"
    else
        echo -e "   ${YELLOW}⚠ DNS ainda com problemas${NC}"
        echo "   Tentando configuração manual..."
        
        # Backup do resolv.conf atual
        sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)
        
        # Criar resolv.conf manual com DNS público
        echo "# DNS manual para correção" | sudo tee /etc/resolv.conf >/dev/null
        echo "nameserver 8.8.8.8" | sudo tee -a /etc/resolv.conf >/dev/null
        echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf >/dev/null
        
        echo "   DNS público configurado temporariamente"
    fi
}

# Função para testar 1Password
test_1password() {
    echo -e "\n${BOLD}Testando 1Password CLI...${NC}"
    echo "═══════════════════"
    
    if command_exists op; then
        echo "1. Versão do CLI:"
        op --version
        
        echo -e "\n2. Teste de conectividade:"
        if op account list >/dev/null 2>&1; then
            echo -e "   ${GREEN}✓ 1Password CLI funcionando${NC}"
        else
            echo -e "   ${RED}✗ 1Password CLI falhando${NC}"
            echo "   Erro: $(op account list 2>&1 | head -1)"
        fi
    else
        echo -e "${RED}✗ 1Password CLI não instalado${NC}"
    fi
}

# Função principal
main() {
    echo "Este script vai:"
    echo "1) Mostrar o status atual do DNS"
    echo "2) Aplicar correções se necessário"
    echo "3) Testar o 1Password CLI"
    echo
    
    if [[ "${1:-}" == "--fix" ]]; then
        echo -e "${YELLOW}Modo correção automática ativado${NC}"
        show_status
        fix_dns
        show_status
        test_1password
    else
        echo "Escolha uma opção:"
        echo "1) Mostrar status atual"
        echo "2) Aplicar correções"
        echo "3) Testar 1Password"
        echo "4) Sair"
        echo
        
        echo -n "Escolha (1/2/3/4): "
        read -r choice
        
        case "$choice" in
            1)
                show_status
                ;;
            2)
                fix_dns
                show_status
                ;;
            3)
                test_1password
                ;;
            4)
                echo "Saindo..."
                exit 0
                ;;
            *)
                echo -e "${RED}Opção inválida${NC}"
                exit 1
                ;;
        esac
    fi
}

# Executar função principal
main "$@"
