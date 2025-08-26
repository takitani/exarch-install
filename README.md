# Omarchy Linux Post-Installation Scripts

Scripts de configuração pós-instalação para Omarchy Linux (distribuição baseada em Arch Linux com Hyprland).

## post-omarchy-setup.sh

Script automatizado para configurar o ambiente após uma instalação limpa do Omarchy Linux. O script assume que o sistema já possui `yay` instalado (padrão no Omarchy).

### Funcionalidades Implementadas

#### 🔧 Preparação do Sistema
- Atualização dos índices do pacman
- Instalação de dependências base: `base-devel`, `git`, `curl`, `jq`, `ca-certificates`, `unzip`, `rsync`
- Verificação da presença do `yay` (AUR helper)

#### 📦 Aplicações Principais
Instalação automatizada via pacman/AUR:
- **CopyQ** - Gerenciador de clipboard avançado
- **Dropbox** - Cliente de sincronização de arquivos
- **AWS VPN Client** - Cliente VPN da AWS
- **Postman** - Ferramenta para teste de APIs

#### 🛠️ JetBrains IDEs
Opções configuráveis para instalação:
- **JetBrains Toolbox** (opcional via `INSTALL_JB_TOOLBOX`)
- **Rider** - IDE para .NET (opcional via `INSTALL_JB_IDES_VIA_AUR`)
- **DataGrip** - IDE para bancos de dados (opcional via `INSTALL_JB_IDES_VIA_AUR`)

> **Nota:** Os pacotes são instalados do AUR usando os nomes corretos `rider` e `datagrip`

#### 🚀 Ambientes de Desenvolvimento via Mise
Configuração automatizada de runtimes usando `mise` (assumindo já instalado):
- **Node.js**: Versão LTS por padrão (com verificação de instalação prévia)
- **.NET SDK**: 
  - Versão 9 como padrão global
  - Versão 8 instalada adicionalmente
  
> **Nota:** O script verifica se os runtimes já estão instalados antes de tentar reinstalá-los

#### 📝 CLIs via NPM
- **Claude Code** - CLI oficial do Claude da Anthropic (instalado globalmente)

#### 🎨 Configurações do Hyprland
Sincronização de dotfiles:
- Sincroniza diretórios de configuração do Hypr (`~/.config/hypr`)
- Sincroniza diretórios de configuração do Hyprl (`~/.config/hyprl`)
- Cria backups datados antes de sobrescrever configurações existentes
- Usa `rsync` para sincronização eficiente (com fallback para `cp`)

### Variáveis de Configuração

O script permite customização através de variáveis de ambiente:

```bash
# Versões de runtime
DEFAULT_NODE="lts"              # Versão do Node.js (lts, 22, 20, etc)
DEFAULT_DOTNET_DEFAULT="9"      # Versão padrão do .NET
EXTRA_DOTNET=("8")             # Versões adicionais do .NET

# JetBrains
INSTALL_JB_TOOLBOX=false       # Instalar JetBrains Toolbox
INSTALL_JB_IDES_VIA_AUR=true   # Instalar IDEs via AUR

# Diretórios de dotfiles
HYPR_SRC_DIR="./dotfiles/hypr"    # Origem dos configs do Hypr
HYPRL_SRC_DIR="./dotfiles/hyprl"  # Origem dos configs do Hyprl
HYPR_DST_DIR="$HOME/.config/hypr"    # Destino Hypr
HYPRL_DST_DIR="$HOME/.config/hyprl"  # Destino Hyprl
```

### Uso

```bash
# Execução padrão
./post-omarchy-setup.sh

# Com configurações customizadas
INSTALL_JB_TOOLBOX=true ./post-omarchy-setup.sh

# Especificando diretórios de dotfiles
HYPR_SRC_DIR=/path/to/my/dotfiles/hypr ./post-omarchy-setup.sh
```

### Recursos de Segurança

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

### Pré-requisitos

- Omarchy Linux instalado (Arch Linux + Hyprland)
- `yay` instalado (padrão no Omarchy)
- `mise` instalado (assumido pelo Omarchy)
- Acesso sudo configurado

### Notas

- O script é idempotente - pode ser executado múltiplas vezes com segurança
- Dropbox service é habilitado automaticamente via systemd user service
- O script continua mesmo se algumas instalações falharem (comportamento resiliente)