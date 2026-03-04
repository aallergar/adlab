#!/bin/bash

# Azure AD Terraform Deployment Verification Script
# Run this after 'terraform apply' completes

echo "=========================================="
echo "Azure AD Deployment Verification"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get resource group from terraform
RG=$(terraform output -raw resource_group_name 2>/dev/null)
VM_NAME=$(terraform output -raw domain_controller_vm_id 2>/dev/null | awk -F'/' '{print $9}')
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null)

if [ -z "$RG" ]; then
    echo -e "${RED}✗ Could not get resource group from terraform output${NC}"
    echo "Make sure 'terraform apply' has completed successfully"
    exit 1
fi

echo "Resource Group: $RG"
echo "VM Name: $VM_NAME"
echo "Storage Account: $STORAGE_ACCOUNT"
echo ""

# 1. Check VM is running
echo "1. Checking VM status..."
VM_STATUS=$(az vm get-instance-view --resource-group "$RG" --name "$VM_NAME" --query "instanceView.statuses[?code=='PowerState/running']" -o tsv 2>/dev/null)
if [ -n "$VM_STATUS" ]; then
    echo -e "${GREEN}✓ VM is running${NC}"
else
    echo -e "${YELLOW}⚠ VM is not running or not ready yet${NC}"
fi
echo ""

# 2. Check storage account and blob
echo "2. Checking storage account and script..."
BLOB_EXISTS=$(az storage blob exists --account-name "$STORAGE_ACCOUNT" --container-name scripts --name Setup-AD.ps1 --query exists -o tsv 2>/dev/null)
if [ "$BLOB_EXISTS" = "true" ]; then
    echo -e "${GREEN}✓ Setup-AD.ps1 uploaded to storage${NC}"
else
    echo -e "${RED}✗ Script not found in storage${NC}"
fi
echo ""

# 3. Check extension status
echo "3. Checking Custom Script Extension..."
EXT_STATE=$(az vm extension show --resource-group "$RG" --vm-name "$VM_NAME" --name install-ad --query "provisioningState" -o tsv 2>/dev/null)
if [ "$EXT_STATE" = "Succeeded" ]; then
    echo -e "${GREEN}✓ Extension provisioning succeeded${NC}"
elif [ "$EXT_STATE" = "Creating" ] || [ "$EXT_STATE" = "Updating" ]; then
    echo -e "${YELLOW}⚠ Extension is still deploying: $EXT_STATE${NC}"
elif [ -n "$EXT_STATE" ]; then
    echo -e "${RED}✗ Extension state: $EXT_STATE${NC}"
    echo ""
    echo "Extension error details:"
    az vm extension show --resource-group "$RG" --vm-name "$VM_NAME" --name install-ad --query "instanceView.statuses[].message" -o tsv 2>/dev/null
else
    echo -e "${YELLOW}⚠ Extension not found yet (may still be deploying)${NC}"
fi
echo ""

# 4. Show connection info
echo "=========================================="
echo "Connection Information"
echo "=========================================="
PUBLIC_IP=$(terraform output -raw domain_controller_public_ip 2>/dev/null)
echo "RDP Connection: mstsc /v:$PUBLIC_IP"
echo "Username: azureadmin"
echo "Password: [from terraform.tfvars]"
echo ""

# 5. Next steps
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo ""
echo "1. Wait for deployment to complete (~20-25 minutes total)"
echo ""
echo "2. Monitor extension status:"
echo "   watch -n 30 './verify-deployment.sh'"
echo ""
echo "3. Once extension succeeds, RDP to the VM:"
echo "   mstsc /v:$PUBLIC_IP"
echo ""
echo "4. On the VM, check the log file:"
echo "   Get-Content C:\Temp\AD-Setup.log -Wait"
echo ""
echo "5. After reboot, verify domain:"
echo "   Get-ADDomain"
echo ""

# 6. Useful commands
echo "=========================================="
echo "Useful Commands"
echo "=========================================="
echo ""
echo "Check extension status:"
echo "  az vm extension show --resource-group $RG --vm-name $VM_NAME --name install-ad"
echo ""
echo "View extension logs (on VM via RDP):"
echo "  Get-Content C:\Temp\AD-Setup.log"
echo ""
echo "Re-run extension if needed:"
echo "  terraform destroy -target=azurerm_virtual_machine_extension.ad_setup"
echo "  terraform apply"
echo ""
