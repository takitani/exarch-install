#!/usr/bin/env bash
# helpers/entra-id-test.sh - Microsoft Entra ID integration test utilities

# Source core functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/modules/entra-id.sh"

# Test mode for Microsoft Entra ID
test_entra_id_mode() {
  info "🔐 Microsoft Entra ID Integration Test Mode"
  
  while true; do
    echo
    echo "╔═══════════════════════════════════════════╗"
    echo "║   Microsoft Entra ID Integration Test     ║"
    echo "╚═══════════════════════════════════════════╝"
    echo
    echo "1) Install Azure CLI (if needed)"
    echo "2) Login to Azure (az login)"
    echo "3) Test SSH login to Azure VM"
    echo "4) Show current Azure account"
    echo "5) Generate SSH keys (if needed)"
    echo "6) Full authentication test"
    echo "0) Exit"
    echo
    echo -n "Choose option: "
    
    # Add timeout to prevent infinite loop
    if ! read -r -t 30 option; then
      echo
      warn "Input timeout - exiting test mode"
      return 0
    fi
    
    case "$option" in
      1)
        echo
        info "Installing Azure CLI..."
        
        if command -v az >/dev/null 2>&1; then
          success "Azure CLI already installed"
          echo "Version: $(az version --output tsv --query '"azure-cli"' 2>/dev/null)"
        else
          echo "Installing Azure CLI via yay..."
          if yay -S azure-cli --noconfirm; then
            success "Azure CLI installed successfully"
          else
            err "Failed to install Azure CLI"
            echo "Try manually: yay -S azure-cli"
          fi
        fi
        ;;
        
      2)
        echo
        info "Logging into Azure..."
        
        if az account show >/dev/null 2>&1; then
          warn "Already logged in to Azure"
          echo "Current account: $(az account show --query user.name -o tsv 2>/dev/null)"
          echo "Tenant: $(az account show --query tenantId -o tsv 2>/dev/null)"
          echo
          echo -n "Login again? (y/n): "
          if ! read -r -t 10 relogin || [[ "$relogin" != "y" ]]; then
            continue
          fi
        fi
        
        echo "Opening browser for Azure login..."
        echo "This will open your browser to login to Azure"
        
        if az login --tenant "$ENTRA_TENANT_ID"; then
          success "Azure login successful!"
          echo "Account: $(az account show --query user.name -o tsv 2>/dev/null)"
          echo "Subscription: $(az account show --query name -o tsv 2>/dev/null)"
        else
          err "Azure login failed"
        fi
        ;;
        
      3)
        echo
        info "Testing SSH login to Azure VM..."
        
        if ! command -v az >/dev/null 2>&1; then
          err "Azure CLI not installed - run option 1 first"
          continue
        fi
        
        if ! az account show >/dev/null 2>&1; then
          err "Not logged in to Azure - run option 2 first"
          continue
        fi
        
        echo "Available VMs in your subscription:"
        echo "Loading VMs..."
        
        if ! az vm list --output table --query "[].{Name:name, ResourceGroup:resourceGroup, Location:location, PowerState:powerState}" 2>/dev/null; then
          warn "No VMs found or unable to list VMs"
          echo
          echo "To test SSH login manually:"
          echo "  az ssh vm -n <VM_NAME> -g <RESOURCE_GROUP>"
        else
          echo
          echo -n "Enter VM name to test SSH: "
          if read -r -t 30 vm_name && [[ -n "$vm_name" ]]; then
            echo -n "Enter resource group: "
            if read -r -t 30 rg_name && [[ -n "$rg_name" ]]; then
              echo
              echo "Attempting SSH connection to $vm_name in $rg_name..."
              echo "Command: az ssh vm -n $vm_name -g $rg_name"
              echo
              az ssh vm -n "$vm_name" -g "$rg_name"
            fi
          else
            echo "Timeout - skipping SSH test"
          fi
        fi
        ;;
        
      4)
        echo
        info "Current Azure account information..."
        
        if ! command -v az >/dev/null 2>&1; then
          err "Azure CLI not installed"
          continue
        fi
        
        if az account show >/dev/null 2>&1; then
          echo "✓ Logged in to Azure"
          echo
          az account show --output table
          echo
          echo "Available subscriptions:"
          az account list --output table --query "[].{Name:name, SubscriptionId:id, TenantId:tenantId, IsDefault:isDefault}"
        else
          err "Not logged in to Azure"
          echo "Run option 2 to login"
        fi
        ;;
        
      5)
        echo
        info "Generating SSH keys (if needed)..."
        
        if [[ -f ~/.ssh/id_rsa ]] || [[ -f ~/.ssh/id_ed25519 ]]; then
          success "SSH keys already exist"
          echo
          echo "Public keys:"
          [[ -f ~/.ssh/id_rsa.pub ]] && echo "RSA: ~/.ssh/id_rsa.pub"
          [[ -f ~/.ssh/id_ed25519.pub ]] && echo "Ed25519: ~/.ssh/id_ed25519.pub"
          echo
          echo -n "Generate new keys anyway? (y/n): "
          if ! read -r -t 10 generate_new || [[ "$generate_new" != "y" ]]; then
            continue
          fi
        fi
        
        echo "Generating Ed25519 SSH key pair..."
        if ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""; then
          success "SSH keys generated successfully"
          echo "Public key:"
          cat ~/.ssh/id_ed25519.pub
        else
          err "Failed to generate SSH keys"
        fi
        ;;
        
      6)
        echo
        info "Full authentication test..."
        
        echo "=== Step 1: Check Azure CLI ==="
        if ! command -v az >/dev/null 2>&1; then
          err "❌ Azure CLI not installed"
          echo "Run option 1 to install"
          continue
        fi
        success "✓ Azure CLI installed"
        
        echo
        echo "=== Step 2: Check Azure login ==="
        if ! az account show >/dev/null 2>&1; then
          err "❌ Not logged in to Azure"
          echo "Run option 2 to login"
          continue
        fi
        success "✓ Logged in to Azure"
        echo "Account: $(az account show --query user.name -o tsv)"
        echo "Tenant: $(az account show --query tenantId -o tsv)"
        
        echo
        echo "=== Step 3: Check SSH keys ==="
        if [[ -f ~/.ssh/id_rsa.pub ]] || [[ -f ~/.ssh/id_ed25519.pub ]]; then
          success "✓ SSH keys exist"
        else
          warn "⚠️ No SSH keys found"
          echo "Run option 5 to generate keys"
        fi
        
        echo
        echo "=== Step 4: Test VM listing ==="
        if az vm list --output table --query "[].{Name:name, ResourceGroup:resourceGroup}" 2>/dev/null | head -5; then
          success "✓ Can list VMs"
        else
          warn "⚠️ No VMs found or insufficient permissions"
        fi
        
        echo
        success "Authentication test completed!"
        echo "Ready to use: az ssh vm -n <VM_NAME> -g <RESOURCE_GROUP>"
        ;;
        
      0)
        echo "Exiting test mode"
        return 0
        ;;
        
      *)
        warn "Invalid option"
        ;;
    esac
    
    echo
    echo "Press Enter to continue..."
    read -r
  done
}

# Run test mode if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  test_entra_id_mode
fi