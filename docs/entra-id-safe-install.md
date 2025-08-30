# Microsoft Entra ID - Guia de Instalação Segura

## ⚠️ LEIA ANTES DE EXECUTAR

Este guia implementa Microsoft Entra ID authentication usando Himmelblau de forma SEGURA, com backups automáticos e procedimentos de rollback.

**IMPORTANTE**: Execute estes comandos em um terminal onde você pode inserir a senha sudo quando necessário.

## Pré-requisitos Validados ✅

- Sistema Arch Linux com Hyprland ✅
- Usuário no grupo wheel ✅  
- Conexão com endpoints Microsoft ✅
- Configuração PAM/NSS limpa ✅
- Tenant ID configurado: `c902ee7d-d8f4-44e7-a09e-bf42b25fa285` ✅

## Execução Passo-a-Passo

### Passo 1: Preparação do Ambiente

```bash
# Navegue para o diretório do projeto
cd /home/opik/Devel/exarch-scripts

# Configure as variáveis de ambiente
export ENTRA_TENANT_ID="c902ee7d-d8f4-44e7-a09e-bf42b25fa285"
export ENTRA_DOMAIN="exato.digital"

# Carregue o módulo seguro
source modules/entra-id-safe.sh
```

### Passo 2: Validação Final

```bash
# Execute uma validação rápida
echo "Validando configuração..."
echo "Tenant ID: $ENTRA_TENANT_ID"
echo "Domain: $ENTRA_DOMAIN"

# Teste sudo access
sudo -v && echo "✅ Sudo OK" || echo "❌ Sudo failed"
```

### Passo 3: Instalação Segura

```bash
# Execute a instalação segura
install_entra_id_safely
```

## O Que o Script Fará

1. **Backup Completo** (`~/backups/himmelblau-TIMESTAMP/`)
   - Configurações PAM originais
   - Arquivo NSS original
   - Estado atual do sistema
   - Script de restore automático

2. **Instalação do Himmelblau**
   - Via AUR (yay)
   - Verificação de integridade dos módulos

3. **Configuração Incremental**
   - NSS primeiro (com fallback para files)
   - PAM depois (como sufficient, não required)
   - Daemon do Himmelblau

4. **Testes de Validação**
   - Autenticação local mantida
   - Módulos PAM carregam corretamente
   - NSS lookups funcionam

## Em Caso de Problemas

### Rollback Automático

Se algo der errado, o script deve fazer rollback automaticamente. Se não:

```bash
# Encontrar backup mais recente
BACKUP_DIR=$(ls -1dt ~/backups/himmelblau-* | head -1)
echo "Usando backup: $BACKUP_DIR"

# Executar restore
bash "$BACKUP_DIR/restore.sh"
```

### Rollback Manual

```bash
# Parar serviços
sudo systemctl stop himmelblaud 2>/dev/null || true
sudo systemctl disable himmelblaud 2>/dev/null || true

# Restaurar PAM
sudo cp ~/backups/himmelblau-*/pam.d.original/system-auth /etc/pam.d/

# Restaurar NSS  
sudo cp ~/backups/himmelblau-*/nsswitch.conf.original /etc/nsswitch.conf

# Reiniciar se necessário
sudo reboot
```

### Acesso de Emergência

Se a autenticação quebrar completamente:

1. **TTY**: `Ctrl+Alt+F2`
2. **Single User**: Boot com parâmetro `single`
3. **Live USB**: Boot e chroot para restaurar

## Após a Instalação

### Verificar Status

```bash
# Verificar serviços
systemctl status himmelblaud

# Verificar autenticação local ainda funciona
sudo -v

# Verificar lookups
id $USER
```

### Join do Domínio

```bash
# Após verificar que tudo está funcionando
sudo himmelblau domain join
```

### Testar Login

```bash
# Teste de lookup de usuário do domínio
# (só funcionará após join bem-sucedido)
getent passwd usuario@exato.digital
```

## Arquivos de Log e Debug

- **Backup**: `~/backups/himmelblau-TIMESTAMP/`
- **Logs de instalação**: `/tmp/exarch-install-TIMESTAMP/`
- **Logs do Himmelblau**: `/var/log/himmelblau.log`
- **Logs do sistema**: `journalctl -u himmelblaud`

## Comandos de Monitoramento

```bash
# Durante a instalação, em outro terminal:
watch "systemctl status himmelblaud; echo '---'; tail -5 /var/log/himmelblau.log 2>/dev/null || echo 'No log yet'"
```

## Validação Pós-Instalação

```bash
# Execute testes após instalação
./test-entra-environment.sh

# Verificar se autenticação local funciona
echo "Testando autenticação local..."
sudo -v && echo "✅ Local auth OK" || echo "❌ Local auth BROKEN"

# Verificar serviço Himmelblau
systemctl is-active himmelblaud && echo "✅ Himmelblau active" || echo "⚠️ Himmelblau not active"
```

## Troubleshooting Comum

### Problema: PAM authentication failure
**Solução**: Restaurar PAM original e reinvestigar
```bash
sudo cp /etc/pam.d/system-auth.pre-himmelblau /etc/pam.d/system-auth
```

### Problema: User lookup fails
**Solução**: Restaurar NSS original
```bash
sudo cp /etc/nsswitch.conf.pre-himmelblau /etc/nsswitch.conf
```

### Problema: Himmelblau não inicia
**Solução**: Verificar logs e configuração
```bash
sudo journalctl -u himmelblaud
cat /etc/himmelblau/himmelblau.conf
```

## Contatos de Suporte

- **Documentação**: `/home/opik/Devel/exarch-scripts/ENTRA_ID_BACKUP_AND_RESTORE.md`
- **Himmelblau GitHub**: https://github.com/himmelblau-idm/himmelblau
- **Logs do processo**: Todos salvos automaticamente

---

## ✅ Checklist de Execução

- [ ] Ambiente preparado (variáveis exportadas)
- [ ] Módulo seguro carregado 
- [ ] Validação final executada
- [ ] `install_entra_id_safely` executado com sucesso
- [ ] Backup criado automaticamente
- [ ] Testes pós-instalação executados
- [ ] Autenticação local verificada
- [ ] Join do domínio (se necessário)

**Ready to go!** Execute quando estiver confortável com os procedimentos.