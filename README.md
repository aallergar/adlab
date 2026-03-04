# Active Directory Deployment

This Terraform configuration deploys a Windows Server 2022 Domain Controller on cloud Providers (Azure initially) with Active Directory automatically installed and configured.


## Summary

This Terraform setup will:

**Phase 1: Create Infrastructure (5-7 min)**
- Creates Resource Group, VNet, NSG, Public IP
- Creates Storage Account (for script hosting)
- Uploads Setup-AD.ps1 to blob storage
- Creates Windows Server VM

**Phase 2: promote the Windows server to Domain Controller by using CSE (1-2 min)**
- Custom Script Extension deployed
- Script downloaded from blob storage to VM

**Phase 3: Script Execution (10-15 min)**
- Installs AD Domain Services role (3-5 min)
- Promotes server to Domain Controller (5-7 min)
- Automatic reboot (2-3 min)

**Phase 4: Finalization (1-2 min)**
- AD services start
- Domain is operational


## Options

All available options/variables are described in [terraform.tfvars.example](https://github.com/aallergar/adlab/blob/main/provider/azure/terraform.tfvars.example)



## Sample terraform.tfvars configuration

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


## How to use

- Clone this repository
- Move the file `terraform.tfvars.example` to `terraform.tfvars` and edit
- Run `terraform apply`
