#!/usr/bin/env bash

# Script para debug de chaves SSH no 1Password
# Uso: ./debug-ssh-keys.sh

set -euo pipefail

# Cores
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}Debug de Chaves SSH no 1Password${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo

# Função para verificar se comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar dependências
if ! command_exists op; then
    echo -e "${RED}✗ 1Password CLI não encontrado${NC}"
    echo "Execute: ./install.sh --1pass"
    exit 1
fi

if ! command_exists jq; then
    echo -e "${RED}✗ jq não encontrado${NC}"
    echo "Execute: sudo pacman -S jq"
    exit 1
fi

# Verificar status do 1Password
echo -e "${BOLD}1. Status do 1Password CLI:${NC}"
echo "═══════════════════════"

if op account list >/dev/null 2>&1; then
    echo -e "   ${GREEN}✓ CLI autenticado${NC}"
    
    # Listar contas
    echo "   Contas configuradas:"
    op account list --format=json 2>/dev/null | jq -r '.[] | "     • \(.shorthand) (\(.address))"' || echo "     Erro ao listar contas"
else
    echo -e "   ${RED}✗ CLI não autenticado${NC}"
    echo "   Execute: op signin"
    exit 1
fi

# Verificar vaults
echo -e "\n${BOLD}2. Vaults disponíveis:${NC}"
echo "═══════════════════"

if op vault list >/dev/null 2>&1; then
    echo "   Vaults:"
    op vault list --format=json 2>/dev/null | jq -r '.[] | "     • \(.name) (\(.id))"' || echo "     Erro ao listar vaults"
else
    echo -e "   ${RED}✗ Erro ao listar vaults${NC}"
    echo "   Execute: op signin"
    exit 1
fi

# Listar itens SSH
echo -e "\n${BOLD}3. Itens SSH encontrados:${NC}"
echo "═══════════════════════"

local ssh_items
if ssh_items=$(op item list --format=json 2>/dev/null | jq '[.[] | select(.category == "SSH_KEY" or .category == "ssh_key" or .category == "SSH" or .category == "ssh")]' 2>/dev/null); then
    local ssh_count
    ssh_count=$(echo "$ssh_items" | jq length 2>/dev/null || echo "0")
    
    if [[ "$ssh_count" -gt 0 ]]; then
        echo -e "   ${GREEN}✓ Encontrados $ssh_count item(s) SSH${NC}"
        echo "   Itens:"
        echo "$ssh_items" | jq -r '.[] | "     • \(.title) (ID: \(.id), Vault: \(.vault.name))"'
    else
        echo -e "   ${YELLOW}⚠ Nenhum item SSH encontrado${NC}"
        echo "   Tentando busca alternativa..."
        
        # Busca alternativa por título
        local all_items
        if all_items=$(op item list --format=json 2>/dev/null); then
            echo "   Itens que podem ser SSH keys:"
            echo "$all_items" | jq -r '.[] | select(.title | test("ssh|key|id_rsa|id_ed25519|github|gitlab|server", "i")) | "     • \(.title) (ID: \(.id), Categoria: \(.category), Vault: \(.vault.name))"'
        fi
    fi
else
    echo -e "   ${RED}✗ Erro ao buscar itens SSH${NC}"
fi

# Busca por nome específico se fornecido
if [[ -n "${1:-}" ]]; then
    local search_name="$1"
    echo -e "\n${BOLD}4. Buscando item específico: '$search_name'${NC}"
    echo "═══════════════════════════════════════"
    
    # Busca por título
    local found_items
    if found_items=$(op item list --format=json 2>/dev/null | jq "[.[] | select(.title | test(\"$search_name\", \"i\"))]" 2>/dev/null); then
        local found_count
        found_count=$(echo "$found_items" | jq length 2>/dev/null || echo "0")
        
        if [[ "$found_count" -gt 0 ]]; then
            echo -e "   ${GREEN}✓ Encontrados $found_count item(s) com '$search_name'${NC}"
            echo "   Itens:"
            echo "$found_items" | jq -r '.[] | "     • \(.title) (ID: \(.id), Categoria: \(.category), Vault: \(.vault.name))"'
            
            # Mostrar detalhes do primeiro item
            local first_item
            first_item=$(echo "$found_items" | jq '.[0]' 2>/dev/null)
            if [[ -n "$first_item" ]]; then
                echo -e "\n   ${BOLD}Detalhes do primeiro item:${NC}"
                local item_id
                item_id=$(echo "$first_item" | jq -r '.id')
                
                echo "   Tentando ler chave privada..."
                local vault_name
                vault_name=$(echo "$first_item" | jq -r '.vault.name // "Private"')
                
                # Tentar diferentes formatos
                local private_key
                if private_key=$(op read "op://$vault_name/$item_id/private key?ssh-format=openssh" 2>/dev/null); then
                    if [[ -n "$private_key" ]]; then
                        echo -e "   ${GREEN}✓ Chave privada lida com sucesso${NC}"
                        echo "   Tipo: $(echo "$private_key" | head -1 | grep -o "BEGIN.*PRIVATE KEY" || echo "Desconhecido")"
                    else
                        echo -e "   ${YELLOW}⚠ Chave privada vazia${NC}"
                    fi
                else
                    echo -e "   ${RED}✗ Erro ao ler chave privada${NC}"
                    echo "   Tentando campos alternativos..."
                    
                    # Verificar campos
                    local item_details
                    if item_details=$(op item get "$item_id" --format=json 2>/dev/null); then
                        echo "   Campos disponíveis:"
                        echo "$item_details" | jq -r '.fields[]? | "     • \(.label): \(.value // .reference // "")"' 2>/dev/null || echo "     Nenhum campo encontrado"
                        
                        echo "   Notas:"
                        local notes
                        notes=$(echo "$item_details" | jq -r '.notes // ""' 2>/dev/null)
                        if [[ -n "$notes" ]]; then
                            echo "     $notes" | head -5
                        else
                            echo "     Nenhuma nota"
                        fi
                    fi
                fi
            fi
        else
            echo -e "   ${YELLOW}⚠ Nenhum item encontrado com '$search_name'${NC}"
        fi
    else
        echo -e "   ${RED}✗ Erro na busca${NC}"
    fi
fi

# Instruções de uso
echo -e "\n${BOLD}5. Como usar:${NC}"
echo "═══════════════"
echo "   Para debug de item específico:"
echo "     ./debug-ssh-keys.sh 'nome-da-chave'"
echo
echo "   Para listar todas as chaves:"
echo "     ./debug-ssh-keys.sh"
echo
echo "   Para testar leitura de chave:"
echo "     op read 'op://vault/item/private key?ssh-format=openssh'"
