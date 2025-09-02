#!/bin/bash

# Script para criar um keyring sem senha via linha de comando

echo "Criando keyring sem senha..."

# Diretório dos keyrings
KEYRING_DIR="$HOME/.local/share/keyrings"
mkdir -p "$KEYRING_DIR"

# Parar o daemon atual se estiver rodando
echo "Parando gnome-keyring-daemon atual..."
killall gnome-keyring-daemon 2>/dev/null
sleep 1

# Criar keyring "login" sem senha
echo "Criando keyring 'login' sem senha..."

# O keyring "login" é especial - ele desbloqueia automaticamente com o login do usuário
# Vamos criar um keyring vazio (sem senha)
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

# Iniciar o daemon com o keyring desbloqueado
echo "Iniciando gnome-keyring-daemon..."
export $(echo -n "" | gnome-keyring-daemon --unlock --start --components=pkcs11,secrets,ssh 2>/dev/null)

# Verificar se funcionou
if [ -n "$GNOME_KEYRING_CONTROL" ]; then
    echo "✓ Gnome-keyring iniciado com sucesso!"
    echo "  GNOME_KEYRING_CONTROL=$GNOME_KEYRING_CONTROL"
else
    echo "⚠ Aviso: Variáveis de ambiente não foram definidas"
fi

echo ""
echo "=== KEYRING CONFIGURADO ==="
echo "Um keyring 'login' sem senha foi criado e definido como padrão."
echo ""
echo "IMPORTANTE: Para que funcione permanentemente:"
echo "1. Faça logout e login novamente"
echo "2. O Chrome/Chromium usará automaticamente este keyring sem pedir senha"
echo ""
echo "Se ainda pedir senha após reiniciar, execute:"
echo "  google-chrome-stable --password-store=basic"