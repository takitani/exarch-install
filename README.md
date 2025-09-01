```
        ███████╗██╗  ██╗ █████╗ ██████╗  ██████╗██╗  ██╗
        ██╔════╝╚██╗██╔╝██╔══██╗██╔══██╗██╔════╝██║  ██║
        █████╗   ╚███╔╝ ███████║██████╔╝██║     ███████║
        ██╔══╝   ██╔██╗ ██╔══██║██╔══██╗██║     ██╔══██║
        ███████╗██╔╝ ██╗██║  ██║██║  ██║╚██████╗██║  ██║
        ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝

               ██╗     ██╗███╗   ██╗██╗   ██╗██╗  ██╗
               ██║     ██║████╗  ██║██║   ██║╚██╗██╔╝
               ██║     ██║██╔██╗ ██║██║   ██║ ╚███╔╝
               ██║     ██║██║╚██╗██║██║   ██║ ██╔██╗
               ███████╗██║██║ ╚████║╚██████╔╝██╔╝ ██╗
               ╚══════╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝  ╚═╝
```

# 🚀 Exarch Scripts - Post-Installation Setup for Omarchy Linux

Scripts de configuração pós-instalação para [**Omarchy Linux**](https://omarchy.org/) - uma distribuição moderna baseada em Arch Linux com Hyprland como gerenciador de janelas.

## 📋 Pré-requisitos

### 1. Instalar Omarchy Linux primeiro!

Este script foi projetado especificamente para rodar **após** a instalação do Omarchy Linux.

1. **Baixe o ISO do Omarchy**: https://omarchy.org/
2. **Instale o sistema** seguindo as instruções da distribuição
3. **Reinicie** e faça login no seu novo sistema Omarchy
4. **Clone este repositório** e execute o script

> ⚠️ **IMPORTANTE**: Este script assume que você já tem o Omarchy Linux instalado com:
> - `yay` (gerenciador AUR - padrão no Omarchy)
> - `mise` (gerenciador de ambientes - padrão no Omarchy)
> - `hyprland` (gerenciador de janelas - padrão no Omarchy)

## post-omarchy-setup.sh

Script automatizado com menu interativo para configurar o ambiente após uma instalação limpa do Omarchy Linux. O script assume que o sistema já possui `yay` instalado (padrão no Omarchy).

### 🎨 Menu Interativo Avançado

O script apresenta um menu interativo moderno com navegação por teclado:
- **Navegação com setas** ↑ ↓ para mover entre opções
- **Barra de espaço** para marcar/desmarcar itens
- **Enter** para confirmar seleção
- **Indicador visual** da opção selecionada
- Perfis pré-configurados (Recomendados, Desenvolvimento Completo)
- Detecção automática de hardware (Dell XPS 13 Plus)
- Visualização clara do que será instalado antes de confirmar

### Funcionalidades Disponíveis

#### 📦 Aplicações Principais
- **Google Chrome** - Navegador web
- **CopyQ** - Gerenciador de clipboard avançado
- **Dropbox** - Cliente de sincronização de arquivos
- **AWS VPN Client** - Cliente VPN da AWS (com configuração automática de serviços)
- **Postman** - Ferramenta para teste de APIs

#### 🛠️ JetBrains IDEs
- **JetBrains Toolbox** - Gerenciador de IDEs JetBrains
- **Rider** - IDE para .NET
- **DataGrip** - IDE para bancos de dados

> **Nota:** Os pacotes são instalados do AUR usando os nomes corretos `rider` e `datagrip`

#### 💻 IDEs e Editores de Código
- **Cursor** - IDE moderna com IA integrada para desenvolvimento

#### 🔐 Autenticação Corporativa
- **Microsoft Entra ID Integration** - Login com contas corporativas Microsoft
- **Multi-factor Authentication (MFA)** - Suporte completo a autenticação em dois fatores
- **Himmelblau Authentication Daemon** - Sistema moderno de autenticação para Linux

#### 🚀 Ambientes de Desenvolvimento via Mise
- **Node.js**: Versão LTS por padrão (com verificação de instalação prévia)
- **.NET SDK**: 
  - Versão 9 como padrão global
  - Versão 8 instalada adicionalmente
  
> **Nota:** O script verifica se os runtimes já estão instalados antes de tentar reinstalá-los

#### 📝 CLIs via NPM
- **Claude Code** - CLI oficial do Claude da Anthropic

#### 🎨 Configurações do Hyprland
- Sincronização de dotfiles do Hypr (`~/.config/hypr`)
- Sincronização de dotfiles do Hyprl (`~/.config/hyprl`)
- Cria backups datados antes de sobrescrever configurações existentes
- Usa `rsync` para sincronização eficiente (com fallback para `cp`)

#### 🔐 Gerenciamento de Dotfiles
- **Chezmoi** - Gerenciador de dotfiles com suporte a templates e criptografia
- **Age** - Ferramenta de criptografia moderna para arquivos sensíveis
- Configuração interativa de repositório de dotfiles
- Geração automática de chaves Age para criptografia
- Suporte a múltiplas opções de configuração (repositório existente, novo repositório, sem criptografia)

#### 💻 Suporte para Dell XPS 13 Plus (9320)

O script detecta automaticamente o Dell XPS 13 Plus e oferece configurações específicas:

**Configuração da Webcam IPU6:**
- Instalação do driver IVSC (via AUR ou compilação do fonte)
- Instalação dos binários e HAL da câmera IPU6
- Configuração de regras udev
- Configuração de módulos para carregamento automático
- Verificação de firmware

**Otimizações de Hardware:**
- Instalação e configuração do `thermald` para gerenciamento térmico
- Instalação e configuração do TLP para gerenciamento de energia
- Instalação do `powertop` para análise de consumo
- Detecção e configuração de áudio Tiger Lake

### Uso

```bash
# Execução padrão com menu interativo
./post-omarchy-setup.sh

# Modo DEBUG (simula instalações sem executar)
./post-omarchy-setup.sh --debug

# Execução sem menu (usa configurações padrão)
./post-omarchy-setup.sh --no-menu

# Combinar opções
./post-omarchy-setup.sh --debug --no-menu

# Com variáveis de ambiente customizadas
HYPR_SRC_DIR=/path/to/my/dotfiles/hypr ./post-omarchy-setup.sh
```

### Controles do Menu Interativo

- **↑/↓**: Navegar entre opções
- **Espaço**: Marcar/desmarcar item selecionado
- **Enter**: Confirmar seleção e prosseguir
- **a**: Marcar/desmarcar todos os itens
- **r**: Aplicar perfil recomendado (essenciais)
- **d**: Aplicar perfil de desenvolvimento completo
- **q**: Sair sem instalar

### Variáveis de Configuração

O script permite customização através de variáveis de ambiente:

```bash
# Versões de runtime
DEFAULT_NODE="lts"              # Versão do Node.js (lts, 22, 20, etc)
DEFAULT_DOTNET_DEFAULT="9"      # Versão padrão do .NET
EXTRA_DOTNET=("8")             # Versões adicionais do .NET

# Diretórios de dotfiles
HYPR_SRC_DIR="./dotfiles/hypr"    # Origem dos configs do Hypr
HYPRL_SRC_DIR="./dotfiles/hyprl"  # Origem dos configs do Hyprl
HYPR_DST_DIR="$HOME/.config/hypr"    # Destino Hypr
HYPRL_DST_DIR="$HOME/.config/hyprl"  # Destino Hyprl
```

### Recursos de Segurança

- **DNS Temporário**: Configura automaticamente DNS (8.8.8.8, 1.1.1.1) durante a execução e restaura ao final
- **Modo Debug**: Use `--debug` para simular todas as instalações sem executar comandos reais
- **Modo fail-safe**: Script usa `set -euo pipefail` para parar em erros
- **Verificação de privilégios**: Requer sudo mas não deve ser executado como root
- **Yay sem root**: O script evita usar yay com sudo (usa --sudoloop para solicitar senha quando necessário)
- **Backups automáticos**: Cria backups datados antes de sobrescrever configurações
- **Tratamento de erros**: Usa `warn` para falhas não-críticas, permitindo continuação
- **Logging colorido**: Feedback visual claro do progresso e status

### Estrutura de Logging

- 🟢 `[ OK ]` - Operação concluída com sucesso
- 🔵 `[ .. ]` - Operação em progresso
- 🟡 `[ !! ]` - Aviso (não-crítico)
- 🔴 `[ERR]` - Erro crítico

### Sumário Final

Ao final da execução, o script apresenta um sumário detalhado contendo:
- ✓ Pacotes instalados com sucesso (com origem: pacman/AUR/npm)
- ✓ Runtimes configurados via mise
- ⏩ Pacotes/Runtimes já instalados (pulados)
- ✗ Pacotes que falharam na instalação
- Diretórios de configuração sincronizados

### Dell XPS 13 Plus (9320) - Informações Adicionais

Se você possui um Dell XPS 13 Plus, o script:

1. **Detecta automaticamente** o hardware durante o menu inicial
2. **Oferece configuração específica** para webcam IPU6
3. **Aplica otimizações** de energia e desempenho
4. **Configura módulos** necessários para carregamento automático

**Após a instalação da webcam:**
- Pode ser necessário reiniciar o sistema
- Verificar status: `sudo dmesg | grep -i ipu6`
- Listar dispositivos: `v4l2-ctl --list-devices`
- Testar webcam: Use aplicativos como `cheese` ou `guvcview`

**Referências:**
- [Arch Wiki - Dell XPS 13 Plus (9320)](https://wiki.archlinux.org/title/Dell_XPS_13_Plus_(9320))

### Pré-requisitos

- Omarchy Linux instalado (Arch Linux + Hyprland)
- `yay` instalado (padrão no Omarchy)
- `mise` instalado (assumido pelo Omarchy)
- Acesso sudo configurado
- Conexão com internet para baixar pacotes

### Notas

- O script é idempotente - pode ser executado múltiplas vezes com segurança
- Dropbox service é habilitado automaticamente via systemd user service
- AWS VPN Client configura automaticamente systemd-resolved e awsvpnclient.service
- O script continua mesmo se algumas instalações falharem (comportamento resiliente)
- O menu interativo facilita a personalização da instalação
- A detecção de hardware é automática e não-intrusiva

### Gerenciamento de Dotfiles com Chezmoi e Age

O script oferece configuração completa para gerenciamento de dotfiles usando **Chezmoi** e **Age**:

#### Chezmoi
- **O que é**: Gerenciador de dotfiles com suporte a templates, criptografia e múltiplas máquinas
- **Vantagens**: 
  - Templates condicionais baseados em sistema/usuário
  - Suporte nativo a criptografia com Age
  - Sincronização bidirecional
  - Suporte a múltiplos repositórios

#### Age
- **O que é**: Ferramenta de criptografia moderna, simples e segura
- **Vantagens**:
  - Criptografia baseada em chaves públicas/privadas
  - Formato compacto e eficiente
  - Integração nativa com Chezmoi
  - Mais simples que GPG

#### Configuração Automática
O script oferece 4 opções de configuração:
1. **Repositório existente**: Conecta a um repositório Git já existente
2. **Novo repositório**: Cria um novo repositório local com estrutura básica
3. **Sem criptografia**: Configura apenas Chezmoi (sem Age)
4. **Manual**: Instala as ferramentas mas deixa a configuração para depois

#### Comandos Úteis
```bash
# Aplicar dotfiles
chezmoi apply

# Ver diferenças
chezmoi diff

# Editar arquivo específico
chezmoi edit ~/.bashrc

# Adicionar novo arquivo
chezmoi add ~/.config/nvim/init.vim

# Criptografar arquivo com Age
age -e -r "age1..." arquivo.txt > arquivo.txt.age

# Descriptografar arquivo
age -d -i ~/.config/age/keys.txt arquivo.txt.age > arquivo.txt
```

#### Documentação
- **Chezmoi**: https://www.chezmoi.io/
- **Age**: https://age-encryption.org/
- **Exemplos**: https://github.com/twpayne/chezmoi/tree/master/docs/examples

## 🔐 Microsoft Entra ID Authentication Integration

### Complete Corporate Authentication Solution

O Exarch Scripts agora inclui **integração completa com Microsoft Entra ID** (Azure AD), permitindo login direto no Linux com contas corporativas da Microsoft.

#### ✨ Recursos
- **🏢 Login corporativo**: Use `usuario@suaempresa.com` para fazer login
- **🔒 Multi-factor Authentication**: MFA automático via Microsoft Authenticator
- **🔄 Sincronização de usuários**: Usuários do Entra ID aparecem automaticamente no sistema
- **🖥️ Suporte completo ao Hyprland**: Funciona tanto no terminal quanto na interface gráfica
- **⚡ Instalação automatizada**: Script completo com compilação e configuração

#### 🚀 Como usar

**Instalação automática (recomendado):**
```bash
./install.sh
# Selecione: "Microsoft Entra ID Authentication"
```

**Resultado:**
- Sistema compilado e instalado automaticamente
- PAM e NSS configurados
- Guias interativas para registro de aplicação
- Testes de conectividade e autenticação
- Login funcionando em 15-20 minutos

#### 📋 O que é instalado
- **Himmelblau**: Daemon de autenticação Microsoft para Linux
- **Módulos PAM**: Integração com sistema de autenticação
- **Módulos NSS**: Resolução de usuários e grupos
- **Configurações**: PAM, NSS e systemd automaticamente configurados

#### 🧪 Após a instalação
```bash
# Testar autenticação
himmelblau auth-test --name usuario@suaempresa.com

# Verificar usuário no sistema  
getent passwd usuario@suaempresa.com

# Login no terminal
su - usuario@suaempresa.com

# Login gráfico no Hyprland
# Use: usuario@suaempresa.com na tela de login
```

#### 📚 Documentação completa
- **[Guia de Setup](docs/entra-id-setup.md)** - Instalação e configuração detalhada
- **[Criação Manual de App](docs/entra-id-app-creation.md)** - Registro manual no portal Azure
- **[Troubleshooting](docs/entra-id-troubleshooting.md)** - Problemas comuns e soluções
- **[Backup e Restore](docs/entra-id-backup-restore.md)** - Procedimentos de segurança

---

## 🔐 Configuração Automática: PostgreSQL .pgpass via 1Password

### Funcionalidade

O script oferece integração completa com 1Password CLI para gerar automaticamente arquivos `.pgpass` a partir de credenciais armazenadas no 1Password.

### Configuração Personalizada

Crie um arquivo `.env` na pasta do projeto para configurar suas informações:

```bash
# .env
ONEPASSWORD_URL="https://suaempresa.1password.com/"
ONEPASSWORD_EMAIL="seu.email@empresa.com"  # Opcional
```

### Como usar

#### Setup inicial (primeira vez)
```bash
# Script auxiliar para configuração guiada
./setup-1password-pgpass.sh
```

#### Gerar .pgpass
```bash
# Modo teste - gera .pgpass_debug
./install.sh --1pass

# Modo produção - via menu interativo
./install.sh
# Selecione: "Configurar ambiente dev (.pgpass via 1Password)"
```

### Recursos

- **Instalação automática** do 1Password CLI e jq
- **Configuração interativa** da conta 1Password
- **Login automático** com detecção de conta
- **Busca inteligente** de credenciais com categoria "Database"
- **Menu de seleção** para escolher quais credenciais incluir
- **Backup automático** de .pgpass existente
- **Permissões corretas** (600) aplicadas automaticamente

### Fluxo do processo

1. Verifica/instala dependências (jq, 1password-cli)
2. Configura conta 1Password se necessário
3. Faz login automático
4. Busca credenciais de banco de dados
5. Apresenta menu de seleção
6. Gera .pgpass com formato correto
7. Aplica permissões de segurança

### Troubleshooting

**1Password CLI não instala:**
- O AUR pode estar fora do ar
- Instale manualmente: https://1password.com/downloads/command-line/

**Credenciais não aparecem:**
- Certifique-se que têm categoria "Database" no 1Password
- Verifique se está autenticado: `op vault list`

**Erro de autenticação:**
- Execute: `op signin` manualmente
- Ou use: `./setup-1password-pgpass.sh` para configuração guiada

## 🖥️ Configuração Automática: Remmina RDP via 1Password

### Visão Geral

O script oferece integração completa com 1Password CLI para gerar automaticamente conexões RDP do Remmina a partir de credenciais de servidores armazenadas no 1Password.

### Configuração

Adicione ao seu arquivo `.env`:
```bash
# Remmina Configuration
SETUP_REMMINA_CONNECTIONS=true
ENABLE_REMMINA_MODULE=true

# Vault mappings (opcional)
VAULT_CATEGORIES=(
  ["Cloud Prod"]="prod"
  ["Cloud Dev"]="dev" 
  ["Personal"]="personal"
)
```

### Como usar

#### Modo teste - gera arquivos de exemplo
```bash
./install.sh --remmina
```

#### Modo produção - via menu interativo
```bash
./install.sh
# Selecione: "Gerar conexões Remmina RDP via 1Password"
```

### Recursos

- **Instalação automática** do Remmina
- **Busca inteligente** de credenciais de servidores
- **Suporte multilíngue** (português + inglês) para nomes de campos
- **Fallbacks múltiplos** para encontrar hostname, username e password
- **Organização por grupos** (prod, dev, personal)
- **Modo debug** para troubleshooting
- **Backup automático** de configurações existentes

### Campos Suportados

O script busca automaticamente por:

**Hostname/Server:**
- `server`, `hostname`, `address`, `ip`, `host`
- `Servidor`, `endereço`, `endereco`
- URLs (extrai hostname automaticamente)

**Username:**
- `username`, `user`, `login`, `account`
- `usuário`, `usuario`, `conta`
- Seção `.login.username`

**Password:**
- `password`, `pass`, `pwd`, `secret`, `chave`
- `senha`
- Seção `.login.password`

### Troubleshooting

**Credenciais não aparecem:**
- Certifique-se que têm categoria "Server" ou "Login" no 1Password
- Verifique se está autenticado: `op vault list`

**Campos não são encontrados:**
- Ative o modo debug: `DEBUG_REMMINA=true ./install.sh`
- Verifique os nomes dos campos no 1Password

**Erro de autenticação:**
- Execute: `op signin` manualmente
- Configure primeiro o 1Password: `./install.sh --1pass`

## 🎥 Solução Automática: Pipewire Camera no Chrome/Chromium

### O Problema

Por padrão, o Chrome e Chromium no Wayland/Arch Linux não conseguem acessar a webcam através do Pipewire, mesmo com as flags de linha de comando configuradas corretamente. As flags ficam como "Default" no `chrome://flags` ao invés de "Enabled".

### Nossa Solução

Este script implementa uma **solução completa e automática** que:

1. **Configura flags de linha de comando** em `~/.config/chromium-flags.conf` e `~/.config/chrome-flags.conf`:
   ```bash
   --enable-webrtc-pipewire-camera
   --enable-features=WebRTCPipeWireCapturer
   --ozone-platform=wayland
   --enable-wayland-ime
   ```

2. **Modifica arquivos .desktop** para incluir as flags automaticamente quando aberto pelo menu do sistema

3. **🔑 INOVAÇÃO: Força as flags como "Enabled" internamente** modificando os arquivos de configuração do navegador:
   - `~/.config/chromium/Default/Preferences`
   - `~/.config/chromium/Local State`
   - `~/.config/google-chrome/Default/Preferences` 
   - `~/.config/google-chrome/Local State`

   Adicionando o campo `enabled_labs_experiments`:
   ```json
   {
     "browser": {
       "enabled_labs_experiments": [
         "enable-webrtc-pipewire-capturer@1",
         "enable-webrtc-pipewire-camera@1"
       ]
     }
   }
   ```

### Como Funciona

O script `apply_pipewire_camera_patch()` é executado automaticamente durante a configuração e:

1. **Detecta** se há navegadores rodando e os fecha temporariamente
2. **Modifica** todos os perfis do Chromium e Chrome existentes
3. **Cria backups** de todos os arquivos modificados
4. **Força** as flags experimentais como "Enabled" nos arquivos internos
5. **Garante** que as flags de linha de comando também estão presentes

### Resultado

Após a execução:
- ✅ A webcam funciona imediatamente no Chrome/Chromium
- ✅ As flags aparecem como "Enabled" em `chrome://flags`
- ✅ Funciona em Google Meet, Discord, Zoom, etc.
- ✅ Configuração persistente (sobrevive a updates)
- ✅ Funciona tanto via linha de comando quanto pelo menu do sistema

### Scripts Auxiliares

- `enable-pipewire-camera.sh`: Script standalone para aplicar o patch
- `enable-pipewire-camera.py`: Versão em Python (mais robusta)
- `pipewire-camera-patch.sh`: Função modular para integração

### Troubleshooting

**Problema com yay:**
- Se receber erro sobre uso de yay como root, o script já trata isso automaticamente

**AWS VPN Client não conecta:**
- Verifique se systemd-resolved está rodando: `systemctl status systemd-resolved`
- Verifique se o serviço está ativo: `systemctl status awsvpnclient`
- Reinicie os serviços se necessário: `sudo systemctl restart systemd-resolved awsvpnclient`

**Webcam não funciona no Dell XPS:**
- Reinicie o sistema após a instalação
- Verifique se os módulos foram carregados: `lsmod | grep -E 'intel_vsc|mei_csi|mei_ace'`
- Verifique logs: `journalctl -xe | grep -i ipu6`

**Mise não encontrado:**
- Instale mise manualmente: `curl -fsSL https://mise.jdx.dev/install.sh | sh`
- Adicione ao PATH conforme instruções da instalação

**Chezmoi/Age não funcionam:**
- Verifique se os pacotes foram instalados: `pacman -Q chezmoi age`
- Para Chezmoi: `chezmoi --version`
- Para Age: `age --version`
- Se não estiverem no PATH, reinicie o terminal ou adicione ao PATH manualmente