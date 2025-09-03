#!/usr/bin/env bash

# Helper script para facilitar o setup do 1Password CLI
# Este script detecta o melhor método e guia o usuário

set -euo pipefail

# Carregar configurações do .env se existir
if [[ -f "$(dirname "$0")/.env" ]]; then
    source "$(dirname "$0")/.env"
fi

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "${BLUE}→${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
err() { echo -e "${RED}✗${NC} $*" >&2; }

# Detectar se tem o app desktop
detect_1password_app() {
    # Verificar se o executável existe
    local apps=(
        "/usr/bin/1password"
        "/usr/local/bin/1password"
        "/opt/1Password/1password"
        "$HOME/.local/bin/1password"
        "/var/lib/flatpak/app/com.onepassword.OnePassword"
        "$HOME/.local/share/flatpak/app/com.onepassword.OnePassword"
    )
    
    for app in "${apps[@]}"; do
        if [[ -f "$app" ]] || [[ -d "$app" ]]; then
            return 0
        fi
    done
    
    # Verificar se está instalado via pacman/yay
    if pacman -Q 1password 2>/dev/null || yay -Q 1password 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Tentar abrir o 1Password desktop
open_1password_app() {
    info "Tentando abrir o 1Password desktop..."
    
    # Tentar diferentes comandos
    if command -v 1password >/dev/null 2>&1; then
        1password & 2>/dev/null
        return 0
    fi
    
    # Tentar via flatpak
    if command -v flatpak >/dev/null 2>&1; then
        if flatpak list | grep -q "com.onepassword.OnePassword"; then
            flatpak run com.onepassword.OnePassword & 2>/dev/null
            return 0
        fi
    fi
    
    # Tentar via xdg-open
    if xdg-open "1password://" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Função para configuração via CLI
configure_cli_method() {
    echo "Configuração via 1Password CLI"
    echo
    echo "Você precisa de um dos seguintes:"
                echo "• Emergency Kit com Setup Code (começa com A3-)"
            echo "• Dados da conta: URL, email e Secret Key"
    echo
    echo "O que você tem?"
    echo "1) Setup Code do Emergency Kit"
    echo "2) Dados completos (URL, email, Secret Key)"
    echo "3) Não tenho nada disso"
    echo
    echo -n "Escolha (1/2/3): "
    read -r metodo_cli
    
    case "$metodo_cli" in
        1)
            echo
            info "Digite ou cole o Setup Code"
            echo "Formato: A3-XXXXXX-XXXXXX-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX"
            echo
            
            # Usar URL do .env se disponível para evitar prompt
            if [[ -n "${ONEPASSWORD_URL:-}" ]]; then
                # Clean URL - remove https:// and trailing slashes
                local clean_url="${ONEPASSWORD_URL}"
                clean_url="${clean_url#https://}"
                clean_url="${clean_url#http://}"
                clean_url="${clean_url%/}"
                
                echo "Usando URL pré-configurada: ${clean_url}"
                echo -n "Digite o email da sua conta: "
                read -r email
                
                if op account add --address "${clean_url}" --email "${email}"; then
                    success "Conta adicionada via Setup Code!"
                    # Fazer login
                    attempt_signin_cli
                else
                    err "Falha ao adicionar conta"
                    echo "Verifique se a URL está correta e sua conexão de rede"
                    return 1
                fi
            else
                echo "Digite sua URL da conta quando solicitado"
                if op account add; then
                    success "Conta adicionada via Setup Code!"
                    # Fazer login
                    attempt_signin_cli
                else
                    err "Falha ao adicionar conta"
                    return 1
                fi
            fi
            ;;
            
        2)
            echo
            info "Digite os dados da conta:"
            echo
            
            # Usar URL do .env se disponível
            local default_url=""
            if [[ -n "${ONEPASSWORD_URL:-}" ]]; then
                default_url="$ONEPASSWORD_URL"
                echo "URL detectada do arquivo de configuração: $default_url"
                echo -n "Usar essa URL? (s/n): "
                read -r use_default
                
                if [[ "$use_default" =~ ^[sS] ]]; then
                    url="$default_url"
                else
                    echo -n "Digite a URL (ex: my.1password.com): "
                    read -r url
                fi
            else
                echo -n "URL (ex: my.1password.com): "
                read -r url
            fi
            
            # Email do .env se disponível
            local default_email=""
            if [[ -n "${ONEPASSWORD_EMAIL:-}" ]]; then
                default_email="$ONEPASSWORD_EMAIL"
                echo "Email detectado: $default_email"
                echo -n "Usar esse email? (s/n): "
                read -r use_default_email
                
                if [[ "$use_default_email" =~ ^[sS] ]]; then
                    email="$default_email"
                else
                    echo -n "Digite o email: "
                    read -r email
                fi
            else
                echo -n "Email: "
                read -r email
            fi
            
            echo -n "Secret Key: "
            read -r secret_key
            
            echo
            info "Adicionando conta..."
            
            if op account add --address "$url" --email "$email" --secret-key "$secret_key"; then
                success "Conta adicionada via dados manuais!"
                # Fazer login
                attempt_signin_cli
            else
                err "Falha ao adicionar conta"
                return 1
            fi
            ;;
            
        3)
            echo
            warn "Você precisa do Emergency Kit ou dados da conta"
            echo
            echo "O Emergency Kit contém:"
            echo "• Setup Code (QR code)"
            echo "• Secret Key"
            echo "• URL da conta"
            echo
            echo "Você pode encontrar em:"
            echo "• Email de boas-vindas do 1Password"
            echo "• PDF baixado durante o cadastro"
            echo "• Configurações da conta no site 1password.com"
            echo
            return 1
            ;;
    esac
}

# Função para tentar fazer signin
attempt_signin_cli() {
    echo
    info "Fazendo login..."
    echo "Digite sua Master Password:"
    
    local account=$(op account list --format=json 2>/dev/null | jq -r '.[0].shorthand' 2>/dev/null)
    
    if [[ -n "$account" ]]; then
        if eval $(op signin --account "$account"); then
            success "Login realizado com sucesso!"
            return 0
        else
            err "Falha no login"
            return 1
        fi
    else
        if eval $(op signin); then
            success "Login realizado com sucesso!"
            return 0
        else
            err "Falha no login"
            return 1
        fi
    fi
}

echo
echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  ${BOLD}1Password CLI - Setup Assistido${NC}${CYAN}      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
echo

# Verificar se o CLI já está instalado
if ! command -v op >/dev/null 2>&1; then
    warn "1Password CLI não está instalado"
    echo
    echo "Instalando automaticamente..."
    
    # Instalar jq se necessário
    if ! command -v jq >/dev/null 2>&1; then
        info "Instalando jq..."
        sudo pacman -S --noconfirm jq 2>/dev/null || true
    fi
    
    # Instalar 1Password CLI
    if command -v yay >/dev/null 2>&1; then
        info "Instalando 1Password CLI via AUR..."
        yay -S --noconfirm --needed 1password-cli-bin 2>/dev/null || \
        yay -S --noconfirm --needed 1password-cli 2>/dev/null || {
            err "Falha na instalação automática"
            echo
            echo "Instale manualmente:"
            echo "  • yay -S 1password-cli-bin"
            echo "  • Ou baixe de: https://1password.com/downloads/command-line/"
            exit 1
        }
    fi
    
    # Verificar se foi instalado
    if command -v op >/dev/null 2>&1; then
        success "1Password CLI instalado com sucesso!"
    else
        err "Instalação falhou"
        exit 1
    fi
fi

# Verificar se já está configurado (melhor detecção)
# Usar formato JSON para evitar prompts
accounts_json=$(timeout 5 op account list --format=json 2>/dev/null)
exit_code=$?

if [[ $exit_code -eq 0 ]] && [[ "$accounts_json" != "[]" ]] && [[ -n "$accounts_json" ]]; then
    success "1Password CLI já está configurado!"
    
    # Verificar se está logado  
    if ! timeout 3 op vault list >/dev/null 2>&1; then
        info "Fazendo login..."
        account=$(op account list --format=json 2>/dev/null | jq -r '.[0].shorthand' 2>/dev/null)
        
        if [[ -n "$account" ]] && [[ "$account" != "null" ]]; then
            eval $(op signin --account "$account")
        else
            eval $(op signin)
        fi
    fi
    
    success "Tudo pronto! Você pode usar o script principal agora."
    echo
    echo "Execute: ./install.sh --1pass"
    exit 0
fi

# Configurar conta
echo -e "${BOLD}Configuração da Conta 1Password${NC}"
echo

# Detectar app desktop
if detect_1password_app; then
    success "1Password desktop detectado!"
    echo
    echo "Você tem três opções:"
    echo
    echo "1) Configurar via CLI (recomendado para scripts)"
    echo "   • Configuração direta no terminal"
    echo "   • Melhor para automação"
    echo "   • Precisa do Emergency Kit ou dados da conta"
    echo
    echo "2) Usar integração com o app (mais fácil)"
    echo "   • Abre o 1Password desktop"
    echo "   • Ativa a integração com CLI"
    echo "   • Não precisa digitar senhas no terminal"
    echo
    echo "3) Configurar manualmente"
    echo "   • Adiciona conta via terminal (método antigo)"
    echo "   • Precisa do Emergency Kit"
    echo
    echo -n "Escolha (1/2/3): "
    read -r escolha
    
    if [[ "$escolha" == "1" ]]; then
        info "Configuração via CLI (recomendado)"
        echo
        
        # Configuração CLI-first
        configure_cli_method
        exit $?
        
    elif [[ "$escolha" == "2" ]]; then
        info "Vamos configurar a integração com o app desktop"
        echo
        
        # Tentar abrir o app
        if open_1password_app; then
            success "1Password desktop está abrindo..."
            sleep 3
        else
            info "Abra o 1Password desktop manualmente"
        fi
        
        echo
        echo "No 1Password desktop:"
        echo
        echo "1. Faça login na sua conta"
        echo "2. Vá em Settings (ou Preferences)"
        echo "3. Clique em Developer"
        echo "4. Ative 'Integrate with 1Password CLI'"
        echo "5. Autorize quando solicitado"
        echo
        echo "Pressione ENTER quando terminar..."
        read -r
        
        # Testar se funcionou
        if op account list >/dev/null 2>&1; then
            success "Integração configurada com sucesso!"
            
            # Testar login
            if op vault list >/dev/null 2>&1; then
                success "Login automático funcionando!"
            else
                info "Tentando login..."
                eval $(op signin)
            fi
            
            echo
            success "Tudo pronto! Execute: ./install.sh --1pass"
            exit 0
        else
            warn "Integração não detectada"
            echo "Vamos tentar configuração manual..."
            echo
        fi
    fi
else
    # Se não tem desktop app, só oferece CLI
    info "1Password desktop não detectado. Usando configuração via CLI."
    echo
    configure_cli_method
    exit $?
fi

# Fim do script principal
