# Omarchy Linux Post-Installation Scripts

Scripts de configuração pós-instalação para Omarchy Linux (distribuição baseada em Arch Linux com Hyprland).

## post-omarchy-setup.sh

Script automatizado com menu interativo para configurar o ambiente após uma instalação limpa do Omarchy Linux. O script assume que o sistema já possui `yay` instalado (padrão no Omarchy).

### 🎨 Menu Interativo

O script apresenta um menu interativo que permite:
- Seleção individual de componentes para instalar
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

# Execução sem menu (usa configurações padrão)
./post-omarchy-setup.sh --no-menu

# Com variáveis de ambiente customizadas
HYPR_SRC_DIR=/path/to/my/dotfiles/hypr ./post-omarchy-setup.sh
```

### Opções do Menu

- **Números (1-13)**: Marcar/desmarcar componentes individuais
- **a**: Marcar/desmarcar todos
- **r**: Selecionar configuração recomendada (essenciais)
- **d**: Selecionar configuração de desenvolvimento completo
- **x**: Prosseguir com a instalação
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