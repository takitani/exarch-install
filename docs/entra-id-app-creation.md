# 📋 CRIAÇÃO MANUAL DA APLICAÇÃO NO MICROSOFT ENTRA ID

O comando automático precisa de permissões especiais, então vamos criar a aplicação manualmente no portal do Azure.

## 🚀 PASSO A PASSO

### 1. Acesse o Portal do Azure
```
https://portal.azure.com
```

### 2. Navegue para Entra ID
- No menu lateral, clique em **"Microsoft Entra ID"**
- Ou pesquise por "Entra ID" na barra de busca

### 3. Registre uma Nova Aplicação
- Clique em **"App registrations"** no menu lateral
- Clique em **"+ New registration"**

### 4. Preencha os Dados da Aplicação
```
Name: Himmelblau-Linux-Auth
Description: Himmelblau authentication for Linux systems
Supported account types: Accounts in this organizational directory only
Redirect URI: (Leave blank for now)
```

### 5. Após Criar, Anote as Informações
Na página "Overview" da aplicação criada, você verá:

```
Application (client) ID: [COPIE ESTE VALOR]
Directory (tenant) ID: c902ee7d-d8f4-44e7-a09e-bf42b25fa285 ✓
```

### 6. Crie um Client Secret
- Vá em **"Certificates & secrets"**
- Clique em **"+ New client secret"**
- Description: `Himmelblau Linux Secret`
- Expires: `24 months`
- Clique **"Add"**
- **⚠️ COPIE O VALOR DO SECRET AGORA!** (só aparece uma vez)

### 7. Configure Permissões API
- Vá em **"API permissions"**
- Clique **"+ Add a permission"**
- Selecione **"Microsoft Graph"**
- Escolha **"Application permissions"**
- Adicione estas permissões:
  - `User.Read.All`
  - `Group.Read.All` 
  - `Directory.Read.All`
- Clique **"Grant admin consent"** (botão azul)
- Status deve ficar **"Granted for [sua organização]"**

### 8. Configure Autenticação (Opcional)
- Vá em **"Authentication"**
- Em **"Advanced settings"**:
  - ✅ `Allow public client flows: Yes`

## 🔧 CONFIGURAÇÃO NO HIMMELBLAU

Após criar a aplicação, execute estes comandos:

### 1. Configure as Credenciais
```bash
# Substitua <APP_ID> pelo Application ID que você copiou
# Substitua <CLIENT_SECRET> pelo secret que você copiou

echo '<CLIENT_SECRET>' | sudo himmelblau cred secret --app-id <APP_ID>
```

### 2. Adicione Schema Extensions (Opcional)
```bash
sudo himmelblau application add-schema-extensions --app-id <APP_ID>
```

### 3. Enumere Usuários
```bash
sudo himmelblau enumerate
```

### 4. Teste Autenticação
```bash
himmelblau auth-test usuario@exato.digital
```

### 5. Verificar no Sistema
```bash
getent passwd usuario@exato.digital
```

## 📝 TEMPLATE PARA COPIAR

Quando tiver criado a aplicação, preencha estes valores:

```
Application ID: _________________________________
Client Secret: __________________________________
Tenant ID: c902ee7d-d8f4-44e7-a09e-bf42b25fa285 ✓
Domain: exato.digital ✓
```

## 🎯 COMANDO FINAL

Depois de preencher os valores acima, execute:

```bash
# Substitua pelos valores reais:
APP_ID="seu-application-id-aqui"
CLIENT_SECRET="seu-client-secret-aqui"

# Configure no Himmelblau:
echo "$CLIENT_SECRET" | sudo himmelblau cred secret --app-id "$APP_ID"

# Enumere usuários:
sudo himmelblau enumerate

# Teste:
himmelblau auth-test usuario@exato.digital
getent passwd usuario@exato.digital
```

## 🆘 TROUBLESHOOTING

### Se der erro de permissão:
- Verifique se você é admin do tenant
- Verifique se as permissões foram concedidas com admin consent

### Se usuários não aparecerem:
- Aguarde alguns minutos após enumerar
- Verifique se os usuários têm atributos POSIX configurados
- Execute `sudo himmelblau cache-clear` e tente novamente

### Se autenticação não funcionar:
- Verifique os logs: `journalctl -u himmelblaud -f`
- Teste conectividade: `ping login.microsoftonline.com`
- Reinicie o serviço: `sudo systemctl restart himmelblaud`

---

**Depois de criar, me avise que eu ajudo com os próximos passos!** 🚀