# Active Directory Deployment

This Terraform configuration deploys a Windows Server 2022 Domain Controller on Azure with Active Directory automatically installed and configured.

## Prerequisites
- Azure CLI installed and authenticated (`az login`)
- Terraform installed
- Azure subscription with permissions to create resources

## Step-by-Step Deployment

### 1. Authenticate with Azure

```bash
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 2. Configure Your Settings

```bash
# Copy the example file
cp terraform.tfvars.example terraform.tfvars

# Edit the file
vim terraform.tfvars  # or use your preferred editor
```

**Important settings to change:**
- `allowed_rdp_cidr`: Replace with YOUR actual IP (find it: `curl ifconfig.me`)
- `admin_password`: Must be complex (min 12 chars, uppercase, lowercase, number, symbol)
- `safe_mode_password`: Same requirements as admin_password
- `domain_name`: Your desired domain (e.g., corp.example.com)
- `domain_netbios_name`: Short name (e.g., CORP)

**Example terraform.tfvars:**
```hcl
azure_region        = "East US"
environment         = "dev"
vnet_cidr           = "10.0.0.0/16"
subnet_cidr         = "10.0.1.0/24"
vm_size             = "Standard_D2s_v3"
allowed_rdp_cidr    = ["203.0.113.50/32"]  # YOUR IP HERE!
domain_name         = "corp.example.com"
domain_netbios_name = "CORP"
safe_mode_password  = "SafeM0de!Pass123"
admin_password      = "Adm!nP@ssw0rd456"
```

### 3. Deploy

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Deploy (type 'yes' when prompted)
terraform apply
```

### 4. Monitor Deployment

The deployment takes **20-25 minutes**. Run the verification script:

```bash
# Make executable (first time only)
chmod +x verify-deployment.sh

# Check status
./verify-deployment.sh
```

### 5. What Happens During Deployment

**Phase 1: Infrastructure (5-7 min)**
- Creates Resource Group, VNet, NSG, Public IP
- Creates Storage Account (for script hosting)
- Uploads Setup-AD.ps1 to blob storage
- Creates Windows Server VM

**Phase 2: Extension Deployment (1-2 min)**
- Custom Script Extension deployed
- Script downloaded from blob storage to VM

**Phase 3: Script Execution (10-15 min)**
- Installs AD Domain Services role (3-5 min)
- Promotes server to Domain Controller (5-7 min)
- Automatic reboot (2-3 min)

**Phase 4: Finalization (1-2 min)**
- AD services start
- Domain is operational

## Troubleshooting

### Method 1: Check Extension Status

```bash
# Get resource group and VM name from terraform
RG=$(terraform output -raw resource_group_name)
VM=$(terraform output -raw domain_controller_vm_id | awk -F'/' '{print $9}')

# Check extension
az vm extension show \
  --resource-group $RG \
  --vm-name $VM \
  --name install-ad \
  --query "provisioningState"
```

Expected output: `"Succeeded"`

### Method 2: Check Via RDP

1. Get the connection info:
```bash
terraform output rdp_connection_string
terraform output admin_username
```

2. RDP to the VM using:
   - IP from output
   - Username: `azureadmin`
   - Password: from your terraform.tfvars

3. On the VM, open PowerShell and run:
```powershell
# Check the installation log
Get-Content C:\Temp\AD-Setup.log

# Verify AD is installed
Get-WindowsFeature -Name AD-Domain-Services

# Verify domain is working
Get-ADDomain
```

If `Get-ADDomain` returns your domain information, **SUCCESS!** 🎉

## Troubleshooting

### Extension Failed

```bash
# See detailed error
az vm extension show \
  --resource-group $RG \
  --vm-name $VM \
  --name install-ad \
  --query "instanceView.statuses[].message" \
  --output tsv
```

### Script Didn't Run

1. RDP to the VM
2. Check if log file exists: `Test-Path C:\Temp\AD-Setup.log`
3. If it doesn't exist, the script never ran
4. Check extension logs: `Get-ChildItem C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\`

### AD Not Installed

Run manually on the VM to see detailed error:
```powershell
# Check if script is downloaded
Get-ChildItem "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\*\Downloads\"

# Run it manually for debugging
cd "C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\*\Downloads\0"
.\Setup-AD.ps1
```

### Need to Re-run

```bash
# Destroy just the extension
terraform destroy -target=azurerm_virtual_machine_extension.ad_setup

# Re-apply
terraform apply
```

## Common Errors and Fixes

### "Password does not meet complexity requirements"

Your password needs:
- At least 12 characters
- Uppercase letters
- Lowercase letters
- Numbers
- Special characters

Example valid password: `MyP@ssw0rd123!`

### "Extension timeout"

The script is taking longer than expected. This is usually okay - RDP to the VM and check `C:\Temp\AD-Setup.log` to see actual progress.

### "Cannot connect via RDP"

1. Check your IP in `allowed_rdp_cidr`:
```bash
curl ifconfig.me
# Update terraform.tfvars with this IP
terraform apply
```

2. Verify NSG allows RDP:
```bash
az network nsg rule show \
  --resource-group $RG \
  --nsg-name dev-ad-nsg \
  --name AllowRDP
```

## Next Steps After Successful Deployment

1. **Test Domain Join:**
   - Create another Windows VM in the same VNet
   - Set DNS to the DC's private IP
   - Join it to the domain

2. **Create Users:**
```powershell
New-ADUser -Name "John Doe" -SamAccountName jdoe -UserPrincipalName jdoe@corp.example.com -AccountPassword (ConvertTo-SecureString "P@ssw0rd123" -AsPlainText -Force) -Enabled $true
```

3. **Create OUs:**
```powershell
New-ADOrganizationalUnit -Name "Employees" -Path "DC=corp,DC=example,DC=com"
```

4. **Set up Group Policy:**
   - Open Group Policy Management Console
   - Create and configure GPOs as needed

## Cost Management

This deployment costs approximately **$95-100/month** on Azure.

To save costs during testing:
- Stop (deallocate) the VM when not in use: `az vm deallocate --resource-group $RG --name $VM`
- Start it when needed: `az vm start --resource-group $RG --name $VM`
- Note: Domain controller functionality will be unavailable when stopped

## Cleanup

To destroy everything:
```bash
terraform destroy
```
Type `yes` when prompted.
