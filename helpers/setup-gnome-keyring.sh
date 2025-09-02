#!/bin/bash

# Script para configurar o gnome-keyring no Arch Linux com Hyprland
# Isso evita ter que digitar a senha do keyring toda vez que abrir o Chrome

# Verificar se é para reverter
if [[ "$1" == "--revert" ]] || [[ "$1" == "-r" ]]; then
    echo "Revertendo configurações do gnome-keyring..."
    
    # Restaurar backup do PAM se existir
    BACKUP_FILE=$(ls -t /etc/pam.d/login.bak.* 2>/dev/null | head -1)
    if [ -f "$BACKUP_FILE" ]; then
        echo "Restaurando backup do PAM: $BACKUP_FILE"
        sudo cp "$BACKUP_FILE" /etc/pam.d/login
        echo "PAM restaurado!"
    else
        echo "Nenhum backup do PAM encontrado. Removendo configurações manualmente..."
        # Criar arquivo temporário sem as linhas do gnome-keyring
        sudo grep -v "pam_gnome_keyring.so" /etc/pam.d/login > /tmp/pam-login-clean
        sudo mv /tmp/pam-login-clean /etc/pam.d/login
        echo "Configurações do gnome-keyring removidas do PAM"
    fi
    
    # Remover do autostart do Hyprland
    HYPR_AUTOSTART="$HOME/.config/hypr/autostart.conf"
    if [ -f "$HYPR_AUTOSTART" ]; then
        echo "Removendo gnome-keyring do autostart do Hyprland..."
        # Fazer backup antes de modificar
        cp "$HYPR_AUTOSTART" "$HYPR_AUTOSTART.bak.$(date +%Y%m%d_%H%M%S)"
        # Remover linhas relacionadas ao gnome-keyring
        sed -i '/# Gnome Keyring/d' "$HYPR_AUTOSTART"
        sed -i '/gnome-keyring-daemon/d' "$HYPR_AUTOSTART"
        echo "Hyprland autostart limpo!"
    fi
    
    # Matar processos do gnome-keyring se estiverem rodando
    if pgrep gnome-keyring > /dev/null; then
        echo "Parando processos do gnome-keyring..."
        killall gnome-keyring-daemon 2>/dev/null
    fi
    
    echo -e "\n=== REVERSÃO COMPLETA ==="
    echo "As configurações do gnome-keyring foram revertidas."
    echo "Reinicie o sistema ou faça logout/login para completar a reversão."
    exit 0
fi

# Mostrar ajuda
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
    echo "Uso: $0 [OPÇÃO]"
    echo ""
    echo "Configura o gnome-keyring para desbloquear automaticamente no login."
    echo ""
    echo "Opções:"
    echo "  --revert, -r    Reverte todas as configurações feitas por este script"
    echo "  --help, -h      Mostra esta mensagem de ajuda"
    echo ""
    echo "Sem opções, o script configura o gnome-keyring."
    exit 0
fi

echo "Configurando gnome-keyring para desbloquear automaticamente no login..."

# Instalar gnome-keyring se não estiver instalado
if ! pacman -Q gnome-keyring &>/dev/null; then
    echo "Instalando gnome-keyring..."
    sudo pacman -S gnome-keyring
fi

# Instalar seahorse (GUI para gerenciar o keyring - opcional mas útil)
if ! pacman -Q seahorse &>/dev/null; then
    read -p "Deseja instalar seahorse (GUI para gerenciar senhas)? [s/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        sudo pacman -S seahorse
    fi
fi

# Configurar PAM para desbloquear o keyring no login
echo "Configurando PAM..."

# Fazer backup dos arquivos PAM
sudo cp /etc/pam.d/login /etc/pam.d/login.bak.$(date +%Y%m%d)

# Adicionar gnome-keyring ao PAM login
if ! grep -q "pam_gnome_keyring.so" /etc/pam.d/login; then
    echo "Adicionando gnome-keyring ao PAM login..."
    
    # Criar arquivo temporário com as configurações
    cat > /tmp/pam-login-gnome-keyring << 'EOF'
#%PAM-1.0

auth       requisite    pam_nologin.so
auth       include      system-local-login
auth       optional     pam_gnome_keyring.so
account    include      system-local-login
session    include      system-local-login
session    optional     pam_gnome_keyring.so auto_start
password   include      system-local-login
EOF
    
    sudo mv /tmp/pam-login-gnome-keyring /etc/pam.d/login
    echo "PAM configurado!"
else
    echo "gnome-keyring já está configurado no PAM"
fi

# Configurar o Hyprland para iniciar o gnome-keyring
HYPR_AUTOSTART="$HOME/.config/hypr/autostart.conf"

if [ -f "$HYPR_AUTOSTART" ]; then
    if ! grep -q "gnome-keyring-daemon" "$HYPR_AUTOSTART"; then
        echo "Adicionando gnome-keyring ao autostart do Hyprland..."
        cat >> "$HYPR_AUTOSTART" << 'EOF'

# Gnome Keyring - desbloqueia automaticamente no login
exec-once = gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
EOF
        echo "Hyprland configurado!"
    else
        echo "gnome-keyring já está configurado no Hyprland"
    fi
else
    echo "Arquivo $HYPR_AUTOSTART não encontrado. Criando..."
    mkdir -p "$HOME/.config/hypr"
    cat > "$HYPR_AUTOSTART" << 'EOF'
# Autostart do Hyprland

# Gnome Keyring - desbloqueia automaticamente no login
exec-once = gnome-keyring-daemon --start --components=pkcs11,secrets,ssh
EOF
fi

# Criar keyring padrão vazio (sem senha)
echo ""
read -p "Deseja criar um keyring sem senha automaticamente? [S/n] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo "Criando keyring sem senha..."
    
    # Diretório dos keyrings
    KEYRING_DIR="$HOME/.local/share/keyrings"
    mkdir -p "$KEYRING_DIR"
    
    # Parar o daemon atual se estiver rodando
    killall gnome-keyring-daemon 2>/dev/null
    sleep 1
    
    # Criar keyring "login" sem senha
    cat > "$KEYRING_DIR/login.keyring" << 'EOF'
[keyring]
display-name=Login
ctime=0
mtime=0
lock-on-idle=false
lock-after=false
EOF
    
    # Definir o keyring login como padrão
    echo "login" > "$KEYRING_DIR/default"
    
    # Definir permissões corretas
    chmod 600 "$KEYRING_DIR/login.keyring"
    chmod 644 "$KEYRING_DIR/default"
    
    echo "✓ Keyring 'login' sem senha criado e definido como padrão!"
else
    echo -e "\nPara criar manualmente um keyring sem senha:"
    echo "1. Execute: ./helpers/create-blank-keyring.sh"
    echo "2. Ou se tiver o seahorse instalado:"
    echo "   - Abra o seahorse (Senhas e Chaves)"
    echo "   - Crie um novo keyring chamado 'login'"
    echo "   - Deixe a senha em branco"
    echo "   - Defina como padrão"
fi

# Alternativa: configurar Chrome para não usar keyring
echo -e "\n=== ALTERNATIVA ==="
echo "Se preferir, você pode iniciar o Chrome sem usar o keyring:"
echo "Edite o arquivo .desktop do Chrome ou crie um alias:"
echo "google-chrome-stable --password-store=basic"
echo ""
echo "Ou para desabilitar completamente:"
echo "google-chrome-stable --password-store=basic --disable-features=PasswordImport"

echo -e "\n=== CONFIGURAÇÃO COMPLETA ==="
echo "Reinicie o sistema ou faça logout/login para as mudanças terem efeito."
echo "Após reiniciar, o keyring deve desbloquear automaticamente com seu login."