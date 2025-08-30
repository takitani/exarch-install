# Himmelblau - Instalação Manual Completa

## ✅ Status: Compilação foi bem-sucedida!

A compilação do Himmelblau do código fonte funcionou perfeitamente (48.38s de build), mas os binários foram removidos automaticamente. Vamos reinstalar do zero com instalação direta.

## 🚀 Comandos para Execução Manual

Execute estes comandos **em sequência** no seu terminal:

### 1. Preparação do Ambiente

```bash
# Configurar variáveis
export ENTRA_TENANT_ID="c902ee7d-d8f4-44e7-a09e-bf42b25fa285"
export ENTRA_DOMAIN="exato.digital"
export HIMMELBLAU_ALLOW_MISSING_SELINUX=1

# Navegar para diretório temporário
cd /tmp
```

### 2. Clone e Build do Himmelblau

```bash
# Remover builds antigos
rm -rf himmelblau-build-* himmelblau

# Clonar repositório
git clone --depth 1 https://github.com/himmelblau-idm/himmelblau.git
cd himmelblau

# Compilar (pode demorar 5-10 minutos)
cargo build --release
```

### 3. Instalação dos Binários

Execute **dentro do diretório himmelblau** após a compilação:

```bash
# Verificar se compilou corretamente
ls -la target/release/ | grep -E "aad-tool|himmelblaud|broker"

# Instalar binários principais
sudo install -Dm755 target/release/aad-tool /usr/bin/himmelblau
sudo install -Dm755 target/release/himmelblaud /usr/bin/himmelblaud

# Se existir o broker
if [[ -f target/release/broker ]]; then
    sudo install -Dm755 target/release/broker /usr/bin/himmelblau-broker
fi

# Instalar módulo PAM (verificar vários locais possíveis)
if [[ -f target/release/libpam_himmelblau.so ]]; then
    sudo install -Dm755 target/release/libpam_himmelblau.so /usr/lib/security/pam_himmelblau.so
elif [[ -f target/release/deps/libpam_himmelblau.so ]]; then
    sudo install -Dm755 target/release/deps/libpam_himmelblau.so /usr/lib/security/pam_himmelblau.so
else
    echo "⚠️  PAM module not found - checking deps..."
    find target/release -name "*pam*" -name "*.so"
fi

# Instalar módulo NSS
if [[ -f target/release/libnss_himmelblau.so ]]; then
    sudo install -Dm755 target/release/libnss_himmelblau.so /usr/lib/libnss_himmelblau.so.2
elif [[ -f target/release/deps/libnss_himmelblau.so ]]; then
    sudo install -Dm755 target/release/deps/libnss_himmelblau.so /usr/lib/libnss_himmelblau.so.2
else
    echo "⚠️  NSS module not found - checking deps..."
    find target/release -name "*nss*" -name "*.so"
fi

# Instalar serviço systemd
sudo install -Dm644 platform/debian/himmelblaud.service /usr/lib/systemd/system/himmelblau.service

# Recarregar systemd
sudo systemctl daemon-reload
```

### 4. Configuração de Diretórios

```bash
# Criar diretórios necessários
sudo mkdir -p /etc/himmelblau
sudo mkdir -p /var/lib/himmelblau
sudo mkdir -p /var/cache/himmelblau
sudo mkdir -p /var/log/himmelblau

# Configurar permissões
sudo chown root:root /etc/himmelblau /var/lib/himmelblau
sudo chmod 755 /etc/himmelblau
sudo chmod 700 /var/lib/himmelblau
```

### 5. Configuração do Himmelblau

```bash
# Criar arquivo de configuração
sudo tee /etc/himmelblau/himmelblau.conf > /dev/null << EOF
[global]
# Microsoft Entra ID Configuration
tenant_id = c902ee7d-d8f4-44e7-a09e-bf42b25fa285
domain = exato.digital

# Authentication settings
cache_timeout = 3600
offline_timeout = 86400
require_mfa = false

# Logging
log_level = info
log_file = /var/log/himmelblau/himmelblau.log
EOF

echo "✅ Configuração criada em /etc/himmelblau/himmelblau.conf"
```

### 6. Verificação da Instalação

```bash
# Verificar binários instalados
echo "📋 Verificando instalação..."
which himmelblau
which himmelblaud
ls -la /usr/lib/security/pam_himmelblau.so
ls -la /usr/lib/libnss_himmelblau.so.2
systemctl status himmelblaud.service

echo "✅ Se todos os comandos acima foram bem-sucedidos, Himmelblau está instalado!"
```

## 🔧 Próximos Passos Após Instalação

### 1. Configurar PAM e NSS (SEGURANÇA)

⚠️ **IMPORTANTE**: Só faça isso depois de confirmar que todos os binários foram instalados corretamente!

```bash
# Carreguar o módulo seguro
cd /home/opik/Devel/exarch-scripts
source modules/entra-id-safe.sh

# Configurar NSS (adiciona himmelblau mas mantém files como primary)
configure_nss_safely

# Configurar PAM (adiciona himmelblau como sufficient)
configure_pam_safely
```

### 2. Iniciar Serviços

```bash
# Habilitar e iniciar Himmelblau daemon
sudo systemctl enable himmelblaud
sudo systemctl start himmelblaud

# Verificar status
sudo systemctl status himmelblaud
```

### 3. Join do Domínio

```bash
# Fazer join no domínio Microsoft Entra ID
sudo himmelblau domain join

# Verificar usuários (após join bem-sucedido)
getent passwd usuario@exato.digital
```

## 🆘 Em Caso de Problemas

### Rollback de Emergência

```bash
# Se algo der errado, restaurar do backup
BACKUP_DIR=$(ls -1dt ~/backups/himmelblau-* | head -1)
bash "$BACKUP_DIR/restore.sh"
```

### Logs para Debug

```bash
# Logs do Himmelblau
sudo journalctl -u himmelblau -f

# Logs de autenticação
sudo journalctl | grep -i himmelblau

# Testar autenticação local
sudo -v
```

## 📝 Resumo dos Arquivos Importantes

- **Binários**: `/usr/bin/himmelblau`, `/usr/bin/himmelblaud`
- **PAM module**: `/usr/lib/security/pam_himmelblau.so`
- **NSS module**: `/usr/lib/libnss_himmelblau.so.2`
- **Serviço**: `/usr/lib/systemd/system/himmelblau.service`
- **Config**: `/etc/himmelblau/himmelblau.conf`
- **Backup**: `~/backups/himmelblau-*`

---

## ✅ Checklist de Execução

- [ ] Variáveis de ambiente configuradas
- [ ] Himmelblau clonado e compilado
- [ ] Binários instalados (`himmelblau`, `himmelblaud`)
- [ ] Módulos PAM/NSS instalados
- [ ] Serviço systemd instalado
- [ ] Diretórios e permissões configurados
- [ ] Arquivo de configuração criado
- [ ] Verificação da instalação executada
- [ ] PAM/NSS configurados com segurança
- [ ] Serviço iniciado
- [ ] Join do domínio executado

**Pronto para começar!** 🚀