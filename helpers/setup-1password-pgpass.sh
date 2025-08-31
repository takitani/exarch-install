#!/usr/bin/env bash

# Script auxiliar para configuração interativa do 1Password + .pgpass
# Facilita o processo de setup inicial

set -euo pipefail

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[ .. ]${NC} $*"; }
success() { echo -e "${GREEN}[ OK ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ !! ]${NC} $*"; }
err() { echo -e "${RED}[ERR]${NC} $*" >&2; }

# Função para verificar se o app desktop está rodando
check_desktop_app() {
    pgrep -x "1password" >/dev/null 2>&1 || pgrep -f "1Password" >/dev/null 2>&1
}

echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo -e "${BOLD}Setup Interativo: 1Password + .pgpass${NC}"
echo -e "${CYAN}═══════════════════════════════════════${NC}"
echo

# Verificar se o 1Password CLI está instalado
if ! command -v op >/dev/null 2>&1; then
    warn "1Password CLI não está instalado"
    echo
    echo "Deseja instalar agora? (s/n): "
    read -r resposta
    
    if [[ "$resposta" == "s" || "$resposta" == "S" ]]; then
        info "Instalando 1Password CLI..."
        
        # Instalar jq primeiro se necessário
        if ! command -v jq >/dev/null 2>&1; then
            info "Instalando jq (necessário para processar JSON)..."
            if command -v pacman >/dev/null 2>&1; then
                sudo pacman -S --noconfirm jq || warn "Falha ao instalar jq"
            fi
        fi
        
        # Tentar instalar via yay
        if command -v yay >/dev/null 2>&1; then
            info "Tentando instalar via yay..."
            if yay -S --noconfirm --needed 1password-cli-bin 2>/dev/null || \
               yay -S --noconfirm --needed 1password-cli 2>/dev/null; then
                success "1Password CLI instalado com sucesso!"
            else
                err "Falha na instalação automática"
                echo
                echo "Instale manualmente:"
                echo "1. Via AUR: yay -S 1password-cli-bin"
                echo "2. Via download: https://1password.com/downloads/command-line/"
                exit 1
            fi
        else
            err "yay não encontrado"
            echo "Instale o 1Password CLI manualmente e execute novamente"
            exit 1
        fi
    else
        echo "Instalação cancelada"
        exit 1
    fi
fi

# Verificar se há conta configurada
if ! op account list >/dev/null 2>&1; then
    info "Nenhuma conta 1Password configurada"
    echo
    
    # Verificar se o app desktop está instalado e rodando
    if check_desktop_app; then
        success "1Password desktop detectado!"
        echo
        echo "Você pode usar a integração com o app desktop."
        echo "Para ativar:"
        echo "  1. Abra o 1Password desktop"
        echo "  2. Vá em Settings > Developer"
        echo "  3. Ative 'Integrate with 1Password CLI'"
        echo "  4. Execute este script novamente"
        echo
        echo "Ou podemos configurar uma conta manualmente."
        echo
        echo "O que deseja fazer?"
        echo "1) Configurar conta manualmente"
        echo "2) Vou ativar a integração e volto depois"
        echo
        echo -n "Escolha (1/2): "
        read -r escolha
        
        if [[ "$escolha" == "2" ]]; then
            info "Configure a integração e execute novamente este script"
            exit 0
        fi
    fi
    
    echo "Vamos configurar sua conta do 1Password."
    echo
    echo "Método de configuração:"
    echo "1) Tenho todos os dados (URL, email, Secret Key)"
    echo "2) Quero escanear o QR code do Emergency Kit"
    echo "3) Cancelar"
    echo
    echo -n "Escolha (1/2/3): "
    read -r metodo
    
    case "$metodo" in
        1)
            echo
            info "Vamos coletar as informações necessárias..."
            echo
            
            # Coletar informações
            echo -n "URL da conta (ex: my.1password.com): "
            read -r account_url
            
            echo -n "Email de login: "
            read -r email
            
            echo -n "Secret Key (formato: XX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX): "
            read -r secret_key
            
            echo
            info "Adicionando conta ao 1Password CLI..."
            echo
            
            # Adicionar conta com os dados fornecidos
            if op account add --address "$account_url" --email "$email" --secret-key "$secret_key"; then
                success "Conta adicionada com sucesso!"
            else
                err "Falha ao adicionar conta"
                echo
                echo "Verifique os dados e tente novamente"
                exit 1
            fi
            ;;
            
        2)
            echo
            info "Setup via QR Code"
            echo
            echo "Para usar o QR code:"
            echo "  1. Tenha o Emergency Kit em mãos"
            echo "  2. O QR code está geralmente no topo do documento"
            echo
            echo "O comando a seguir abrirá um prompt interativo."
            echo "Cole o conteúdo do QR code quando solicitado."
            echo
            echo "Pressione ENTER para continuar..."
            read -r
            
            # Adicionar conta via QR/setup code
            if ! op account add; then
                err "Falha ao adicionar conta"
                exit 1
            fi
            
            success "Conta adicionada com sucesso!"
            ;;
            
        3|*)
            echo "Configuração cancelada"
            exit 1
            ;;
    esac
    
    echo
fi

# Fazer login se necessário
if ! op vault list >/dev/null 2>&1; then
    info "Fazendo login no 1Password..."
    
    # Obter account ID
    account_id=$(op account list --format=json 2>/dev/null | jq -r '.[0].shorthand' 2>/dev/null)
    
    if [[ -n "$account_id" ]]; then
        echo "Conta detectada: $account_id"
        echo "Digite sua Master Password:"
        
        if eval $(op signin --account "$account_id"); then
            success "Login realizado com sucesso!"
        else
            err "Falha no login"
            exit 1
        fi
    else
        if eval $(op signin); then
            success "Login realizado com sucesso!"
        else
            err "Falha no login"
            exit 1
        fi
    fi
else
    success "Já está autenticado no 1Password!"
fi

echo
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo -e "${BOLD}Configuração concluída com sucesso!${NC}"
echo -e "${CYAN}════════════════════════════════════════${NC}"
echo
echo "Agora você pode:"
echo "1. Gerar .pgpass de produção: ./install.sh"
echo "2. Gerar .pgpass de teste: ./install.sh --1pass"
echo
echo "Dica: Certifique-se de ter credenciais com categoria 'Database'"
echo "      no seu 1Password para que sejam detectadas!"
echo