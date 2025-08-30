# Microsoft Entra ID Integration - Backup and Restore Procedures

## Overview

This document provides comprehensive backup and restore procedures for Microsoft Entra ID integration using Himmelblau on Arch Linux with Hyprland.

**CRITICAL**: Always maintain access to emergency restoration procedures when modifying authentication systems.

## Backup Strategy

### Automatic Backup Creation

The safe implementation automatically creates timestamped backups before any system modifications:

```bash
BACKUP_DIR="/home/opik/backups/himmelblau-$(date +%Y%m%d_%H%M%S)"
```

### What Gets Backed Up

1. **PAM Configurations** (`/etc/pam.d/`)
   - `system-auth` - Core authentication
   - `login` - Terminal login  
   - `sshd` - SSH authentication
   - All other PAM service configurations

2. **NSS Configuration** (`/etc/nsswitch.conf`)
   - User/group resolution configuration
   - Critical for user lookups

3. **System State Information**
   - Active services list
   - Current user information
   - Authentication status

4. **Himmelblau Configurations** (if they exist)
   - `/etc/himmelblau/himmelblau.conf`
   - Service status

## Emergency Restore Procedures

### Automatic Restore Script

Each backup directory contains an automatic restore script (`restore.sh`) that can be executed in emergency situations:

```bash
# Find latest backup
ls -1dt /home/opik/backups/himmelblau-* | head -1

# Execute restore
sudo /path/to/backup/restore.sh
```

### Manual Restore Steps

If automatic restore fails, follow these manual steps:

#### 1. Stop Himmelblau Services
```bash
sudo systemctl stop himmelblau* 2>/dev/null || true
sudo systemctl disable himmelblau* 2>/dev/null || true
```

#### 2. Restore PAM Configuration
```bash
BACKUP_DIR="/path/to/your/backup"
sudo cp -r "$BACKUP_DIR/pam.d.original"/* /etc/pam.d/
```

#### 3. Restore NSS Configuration  
```bash
sudo cp "$BACKUP_DIR/nsswitch.conf.original" /etc/nsswitch.conf
```

#### 4. Verify System Authentication
```bash
# Test current user can authenticate
sudo -v

# Test user lookup works
id $USER

# Test system services
systemctl status
```

#### 5. Reboot if Necessary
If authentication is still problematic:
```bash
sudo reboot
```

## Backup Directory Structure

```
/home/opik/backups/himmelblau-YYYYMMDD_HHMMSS/
├── pam.d.original/              # Original PAM configurations
├── nsswitch.conf.original       # Original NSS configuration
├── active-services.txt          # System services before changes
├── current-user-info.txt        # User ID information
├── current-user.txt             # Current username
├── restore.sh                   # Automatic restore script
└── himmelblau.conf.backup       # Himmelblau config (if exists)
```

## Emergency Access Methods

### If GUI Login Fails

1. **TTY Access**: `Ctrl+Alt+F2`
2. **SSH Access**: From another machine
3. **Single User Mode**: Boot parameter `single`

### If All Authentication Fails

1. **Boot from live USB**
2. **Mount system partition**
3. **Chroot into system**
4. **Execute restore manually**

```bash
# From live environment
mount /dev/sdXY /mnt
arch-chroot /mnt

# Find and execute restore
ls /home/opik/backups/himmelblau-*/
bash /home/opik/backups/himmelblau-YYYYMMDD_HHMMSS/restore.sh
```

## Validation Procedures

### Before Making Changes

1. **Test Current Authentication**
   ```bash
   sudo -v                    # Test sudo access
   su - $USER                 # Test user switching  
   ssh $USER@localhost        # Test SSH (if enabled)
   ```

2. **Document System State**
   ```bash
   systemctl list-units --state=active > pre-change-services.txt
   loginctl list-sessions > pre-change-sessions.txt
   ```

### After Changes

1. **Test All Authentication Methods**
   ```bash
   # Local authentication
   sudo -v
   
   # User lookup  
   id $USER
   getent passwd $USER
   
   # Service status
   systemctl status himmelblaud
   ```

2. **Test Emergency Access**
   ```bash
   # Test TTY login (different terminal)
   # Test SSH if configured
   ```

## Rollback Scenarios

### Scenario 1: PAM Module Issues
**Symptoms**: Cannot authenticate, "authentication failure" errors
**Solution**: 
```bash
sudo cp /etc/pam.d/system-auth.pre-himmelblau /etc/pam.d/system-auth
```

### Scenario 2: NSS Lookup Failures  
**Symptoms**: `id $USER` fails, user not found
**Solution**:
```bash
sudo cp /etc/nsswitch.conf.pre-himmelblau /etc/nsswitch.conf
```

### Scenario 3: Complete Authentication Failure
**Symptoms**: No login possible, system inaccessible
**Solution**: Boot from live USB and execute full restore

### Scenario 4: Himmelblau Service Issues
**Symptoms**: Service won't start, errors in logs
**Solution**:
```bash
# Check logs
sudo journalctl -u himmelblaud
# Stop service
sudo systemctl stop himmelblau*
# Remove from boot
sudo systemctl disable himmelblau*
```

## Prevention Best Practices

1. **Always Create Backups First**
2. **Keep Multiple TTY Sessions Open** during changes
3. **Test in Non-Production Environment** first
4. **Have Live USB Ready** for emergency access
5. **Document All Changes** with timestamps
6. **Verify Each Step** before proceeding to next

## Recovery Contact Information

- **Himmelblau Documentation**: https://github.com/himmelblau-idm/himmelblau
- **Arch Linux PAM Guide**: https://wiki.archlinux.org/title/PAM
- **Emergency Boot Methods**: https://wiki.archlinux.org/title/General_troubleshooting

## Implementation Log Template

```
Date: YYYY-MM-DD HH:MM:SS
User: opik
System: Arch Linux + Hyprland
Backup Location: /home/opik/backups/himmelblau-YYYYMMDD_HHMMSS/

Changes Made:
- [ ] System backup created
- [ ] Himmelblau installed  
- [ ] PAM configured
- [ ] NSS configured
- [ ] Services started
- [ ] Testing completed

Issues Encountered:
- 

Rollback Required:
- [ ] Yes [ ] No

Notes:
- 
```

## Quick Reference Commands

```bash
# Create emergency backup
sudo cp -r /etc/pam.d/ ~/emergency-pam-backup/
sudo cp /etc/nsswitch.conf ~/emergency-nsswitch.backup

# List all backups
ls -la /home/opik/backups/himmelblau-*/

# Execute latest restore
LATEST=$(ls -1dt /home/opik/backups/himmelblau-* | head -1)
sudo bash "$LATEST/restore.sh"

# Check authentication status
sudo -v && echo "✅ Auth OK" || echo "❌ Auth FAIL"
id $USER && echo "✅ User lookup OK" || echo "❌ User lookup FAIL"
```