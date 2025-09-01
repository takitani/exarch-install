# Helpers

Este diretório contém scripts auxiliares para configuração e diagnóstico do sistema.

## PipeWire Camera

### Problema
A flag "PipeWire Camera support" no Chromium/Chrome está configurada como "Default" ao invés de "Enabled", impedindo o uso correto da câmera com PipeWire.

### Solução Automatizada (Recomendada)

#### Script Bash com Modificação de Configuração
O script `enable-pipewire-camera.sh` automatiza a configuração da flag PipeWire modificando os arquivos de configuração do navegador.

**Vantagens:**
- ✅ Configuração automática via bash
- ✅ Modifica arquivos de configuração diretamente
- ✅ Funciona com qualquer versão do Chromium/Chrome
- ✅ Configura flags de linha de comando
- ✅ Atualiza atalhos do desktop

**Como usar:**

1. **Execução direta:**
   ```bash
   cd helpers
   chmod +x enable-pipewire-camera.sh
   ./enable-pipewire-camera.sh
   ```

2. **Execução com sudo (para atalhos do sistema):**
   ```bash
   cd helpers
   sudo ./enable-pipewire-camera.sh
   ```

**O que o script faz:**
1. Verifica se o PipeWire está rodando
2. Modifica arquivos `Preferences` de cada perfil
3. Atualiza arquivo `Local State`
4. Configura flags de linha de comando
5. Modifica atalhos do desktop
6. Oferece opção de fechar navegadores

### Solução Manual (Legacy)

#### Script Shell Original
O script `pipewire-camera-patch.sh` é uma versão mais antiga que pode ser usada como referência.

**⚠️ Limitações:**
- Versão mais antiga
- Pode não funcionar com versões mais recentes do navegador

## Diagnóstico

### Teste de Câmera
Para verificar se a câmera está funcionando:

1. Abra o Chromium/Chrome
2. Vá para `chrome://flags`
3. Procure por "pipewire"
4. Deve estar marcado como "Enabled"
5. Teste em sites como:
   - meet.google.com
   - webcamtest.com
   - any webcam testing site

### Logs de Diagnóstico
Se houver problemas, verifique:

```bash
# Status do PipeWire
systemctl --user status pipewire

# Logs do PipeWire
journalctl --user -u pipewire -f

# Verificar dispositivos de vídeo
v4l2-ctl --list-devices
```

## Dependências

### Sistema
- Chromium ou Google Chrome
- PipeWire rodando
- jq (opcional, para melhor manipulação de JSON)
- sed (fallback se jq não estiver disponível)

## Instalação Automática

O script `enable-pipewire-camera.sh` instala automaticamente:

1. Verifica dependências do sistema
2. Configura flags PipeWire
3. Atualiza configurações do navegador
4. Modifica atalhos do desktop

## Troubleshooting

### Erro: "Flag não encontrada"
- Verifique se o Chromium está atualizado
- A flag pode ter mudado de nome em versões mais recentes

### Erro: "Permissão negada"
- Execute com sudo para modificar atalhos do sistema
- Verifique permissões dos arquivos de configuração

### Flag não persiste após reinicialização
- Verifique se há múltiplos perfis do navegador
- Execute o script para cada perfil se necessário
- Verifique se os atalhos do desktop foram atualizados

### Problemas com jq
- Se jq não estiver instalado, o script usa sed como fallback
- Para melhor confiabilidade, instale jq: `sudo pacman -S jq`

## Contribuição

Para melhorar os scripts:

1. Teste em diferentes versões do Chromium/Chrome
2. Adicione suporte para outros navegadores se necessário
3. Melhore o tratamento de erros
4. Adicione mais opções de configuração
5. Mantenha compatibilidade com bash puro
