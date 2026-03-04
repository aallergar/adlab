variable "azure_region" {
  description = "Azure region to deploy resources"
  type        = string
  default     = "East US"
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
  default     = "dev"
}

variable "vnet_cidr" {
  description = "CIDR block for Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "subnet_cidr" {
  description = "CIDR block for subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "vm_size" {
  description = "Azure VM size for Domain Controller"
  type        = string
  default     = "Standard_D2s_v4"
}

variable "allowed_rdp_cidr" {
  description = "CIDR blocks allowed to RDP to the Domain Controller"
  type        = list(string)
  default     = ["0.0.0.0/0"] # Restrict this in production!
}

variable "domain_name" {
  description = "Active Directory domain name (e.g., corp.example.com)"
  type        = string
}

variable "domain_netbios_name" {
  description = "NetBIOS name for the domain (e.g., CORP)"
  type        = string
}

variable "safe_mode_password" {
  description = "Safe mode administrator password"
  type        = string
  sensitive   = true
}

variable "admin_password" {
  description = "Administrator password for the Windows VM"
  type        = string
  sensitive   = true
}

variable "script_storage_url" {
  description = "URL to PowerShell script in Azure Storage (optional - for file-based approach)"
  type        = string
  default     = ""
}
