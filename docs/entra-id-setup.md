# 🔐 Microsoft Entra ID Integration Guide

Complete guide for setting up Microsoft Entra ID authentication on Arch Linux using Himmelblau.

## 🎯 Quick Start

For users who want to get started immediately:

```bash
# 1. Run the automated installation
./install.sh

# 2. Select "Microsoft Entra ID Authentication" from menu

# 3. Follow the interactive prompts for:
#    - Himmelblau compilation and installation  
#    - Application registration guidance
#    - Credential configuration
#    - User testing

# 4. Test login
su - your-user@yourdomain.com
```

## 📋 Overview

This integration allows you to:
- ✅ Login to Linux with Microsoft corporate accounts
- ✅ Use multi-factor authentication (MFA)  
- ✅ Integrate with existing Active Directory users
- ✅ Maintain centralized user management
- ✅ Work with Hyprland (Wayland) login screens

## 🏗️ Architecture

The implementation uses:
- **Himmelblau** - Main authentication daemon
- **PAM modules** - System authentication integration
- **NSS modules** - User/group resolution
- **Microsoft Entra ID** - Identity provider
- **OAuth2 + Device Flow** - Authentication protocol

## 🚀 Installation Process

### Automated Installation

The main install script handles everything:

```bash
./install.sh
# Select: "Microsoft Entra ID Authentication"
```

### Manual Installation Steps

If you prefer manual control:

```bash
# 1. Install dependencies
sudo pacman -S base-devel git rust

# 2. Compile Himmelblau
git clone https://github.com/himmelblau-idm/himmelblau
cd himmelblau
cargo build --release

# 3. Install binaries
sudo install -Dm755 target/release/himmelblaud /usr/bin/
sudo install -Dm755 target/release/aad-tool /usr/bin/himmelblau
sudo install -Dm755 target/release/libnss_himmelblau.so /usr/lib/
sudo install -Dm755 target/release/libpam_himmelblau.so /usr/lib/security/

# 4. Configure PAM (see Configuration section)
# 5. Configure NSS (see Configuration section)
# 6. Start service
sudo systemctl enable --now himmelblaud
```

## ⚙️ Configuration

### PAM Configuration (`/etc/pam.d/system-auth`)

```bash
#%PAM-1.0

auth       required                    pam_faillock.so preauth silent deny=10 unlock_time=120
-auth      [success=2 default=ignore]  pam_systemd_home.so
auth       [success=2 default=ignore]  pam_himmelblau.so
auth       [success=1 default=bad]     pam_unix.so          try_first_pass nullok
auth       [default=die]               pam_faillock.so authfail deny=10 unlock_time=120
auth       optional                    pam_permit.so
auth       required                    pam_env.so
auth       required                    pam_faillock.so      authsucc

-account   [success=1 default=ignore]  pam_systemd_home.so
account    [success=1 default=ignore]  pam_himmelblau.so
account    required                    pam_unix.so
account    optional                    pam_permit.so
account    required                    pam_time.so

-password  [success=1 default=ignore]  pam_systemd_home.so
password   required                    pam_unix.so          try_first_pass nullok shadow
password   optional                    pam_permit.so

-session   optional                    pam_systemd_home.so
session    required                    pam_limits.so
session    required                    pam_unix.so
session    optional                    pam_himmelblau.so
session    optional                    pam_permit.so
```

### NSS Configuration (`/etc/nsswitch.conf`)

```bash
passwd: files himmelblau systemd
group: files himmelblau systemd
shadow: files himmelblau
```

## 🏢 Entra ID Application Setup

### Quick Setup (Recommended)

Use the automated application creation:

```bash
sudo himmelblau application create
# Follow browser authentication prompts
```

### Manual Application Registration

If automated creation fails, follow the [Application Creation Manual](entra-id-app-creation.md).

### Configure Application Credentials

```bash
# Set environment variables
export APP_ID="your-application-id"
export CLIENT_SECRET="your-client-secret"
export DOMAIN="yourdomain.com"

# Configure credentials
sudo himmelblau cred secret --client-id "$APP_ID" --domain "$DOMAIN" --secret "$CLIENT_SECRET"

# Verify configuration
sudo himmelblau cred list --domain "$DOMAIN"
```

## 🧪 Testing and Validation

### Test User Enumeration

```bash
# Enumerate users from Entra ID
sudo himmelblau enumerate --client-id "$APP_ID"

# Check if users appear in system
getent passwd your-user@yourdomain.com
```

### Test Authentication

```bash
# Test authentication flow
himmelblau auth-test --name your-user@yourdomain.com

# Test actual login
su - your-user@yourdomain.com
```

### Test Graphical Login

1. Logout from current session
2. On login screen, enter: `your-user@yourdomain.com`
3. Complete MFA challenge on mobile device

## 📊 Verification Commands

Check if everything is working:

```bash
# Service status
systemctl status himmelblaud

# Check logs
sudo journalctl -u himmelblaud -f

# List configured credentials
sudo himmelblau cred list --domain yourdomain.com

# Test network connectivity
curl -s "https://login.microsoftonline.com/common/v2.0/.well-known/openid_configuration" | jq .

# Verify PAM configuration
grep himmelblau /etc/pam.d/system-auth

# Verify NSS configuration  
grep himmelblau /etc/nsswitch.conf
```

## 🔧 Advanced Configuration

### Custom Domain Configuration

For multiple domains or custom configurations:

```bash
# Add additional domain
sudo himmelblau cred secret --client-id "$APP_ID2" --domain "$DOMAIN2" --secret "$CLIENT_SECRET2"

# List all configured domains
sudo himmelblau cred list --domain "$DOMAIN1"
sudo himmelblau cred list --domain "$DOMAIN2"
```

### Schema Extensions (Optional)

Add POSIX attributes support:

```bash
sudo himmelblau application add-schema-extensions --client-id "$APP_ID"
```

## 🆘 Troubleshooting

See the dedicated [Troubleshooting Guide](entra-id-troubleshooting.md) for:
- Authentication failures
- Permission errors  
- Network connectivity issues
- Application registration problems

## 🔒 Security Notes

- Credentials are stored securely by Himmelblau daemon
- MFA is enforced by Entra ID policies
- Local user accounts remain as fallback
- No passwords are cached locally
- All authentication goes through Microsoft servers

## 📚 Additional Resources

- [Official Himmelblau Documentation](https://github.com/himmelblau-idm/himmelblau)
- [Microsoft Entra ID Documentation](https://docs.microsoft.com/en-us/azure/active-directory/)
- [PAM Configuration Guide](https://wiki.archlinux.org/title/PAM)