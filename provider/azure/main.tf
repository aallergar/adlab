terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "ad_rg" {
  name     = "${var.environment}-ad-rg"
  location = var.azure_region
}

# Virtual Network
resource "azurerm_virtual_network" "ad_vnet" {
  name                = "${var.environment}-ad-vnet"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
}

# Subnet
resource "azurerm_subnet" "ad_subnet" {
  name                 = "${var.environment}-ad-subnet"
  resource_group_name  = azurerm_resource_group.ad_rg.name
  virtual_network_name = azurerm_virtual_network.ad_vnet.name
  address_prefixes     = [var.subnet_cidr]
}

# Network Security Group
resource "azurerm_network_security_group" "ad_nsg" {
  name                = "${var.environment}-ad-nsg"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name

  # RDP
  security_rule {
    name                       = "AllowRDP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefixes    = var.allowed_rdp_cidr
    destination_address_prefix = "*"
  }

  # DNS TCP
  security_rule {
    name                       = "AllowDNS-TCP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # DNS UDP
  security_rule {
    name                       = "AllowDNS-UDP"
    priority                   = 111
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # LDAP TCP
  security_rule {
    name                       = "AllowLDAP-TCP"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "389"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # LDAP UDP
  security_rule {
    name                       = "AllowLDAP-UDP"
    priority                   = 121
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "389"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # LDAPS
  security_rule {
    name                       = "AllowLDAPS"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "636"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # Kerberos TCP
  security_rule {
    name                       = "AllowKerberos-TCP"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "88"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # Kerberos UDP
  security_rule {
    name                       = "AllowKerberos-UDP"
    priority                   = 141
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "88"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # SMB
  security_rule {
    name                       = "AllowSMB"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "445"
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # Global Catalog
  security_rule {
    name                       = "AllowGlobalCatalog"
    priority                   = 160
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["3268", "3269"]
    source_address_prefix      = var.vnet_cidr
    destination_address_prefix = "*"
  }

  # WinRM
  security_rule {
    name                       = "AllowWinRM"
    priority                   = 170
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5985", "5986"]
    source_address_prefixes    = var.allowed_rdp_cidr
    destination_address_prefix = "*"
  }
}

# Public IP Address
resource "azurerm_public_ip" "dc_pip" {
  name                = "${var.environment}-dc-pip"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface
resource "azurerm_network_interface" "dc_nic" {
  name                = "${var.environment}-dc-nic"
  location            = azurerm_resource_group.ad_rg.location
  resource_group_name = azurerm_resource_group.ad_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ad_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.dc_pip.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "dc_nic_nsg" {
  network_interface_id      = azurerm_network_interface.dc_nic.id
  network_security_group_id = azurerm_network_security_group.ad_nsg.id
}

# Domain Controller Virtual Machine
resource "azurerm_windows_virtual_machine" "domain_controller" {
  name                = "${var.environment}-dc"
  resource_group_name = azurerm_resource_group.ad_rg.name
  location            = azurerm_resource_group.ad_rg.location
  size                = var.vm_size
  admin_username      = "azureadmin"
  admin_password      = var.admin_password

  network_interface_ids = [
    azurerm_network_interface.dc_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = 128
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# Storage Account for scripts (optional but more reliable)
resource "azurerm_storage_account" "scripts" {
  name                     = "${var.environment}adscripts${random_string.storage_suffix.result}"
  resource_group_name      = azurerm_resource_group.ad_rg.name
  location                 = azurerm_resource_group.ad_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_string" "storage_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_storage_container" "scripts" {
  name                  = "scripts"
  storage_account_name  = azurerm_storage_account.scripts.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "ad_setup_script" {
  name                   = "Setup-AD.ps1"
  storage_account_name   = azurerm_storage_account.scripts.name
  storage_container_name = azurerm_storage_container.scripts.name
  type                   = "Block"
  source_content         = templatefile("${path.module}/Setup-AD.ps1", {
    domain_name         = var.domain_name
    domain_netbios_name = var.domain_netbios_name
    safe_mode_password  = var.safe_mode_password
  })
}

data "azurerm_storage_account_blob_container_sas" "scripts" {
  connection_string = azurerm_storage_account.scripts.primary_connection_string
  container_name    = azurerm_storage_container.scripts.name

  start  = timestamp()
  expiry = timeadd(timestamp(), "24h")

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = true
  }
}

# Custom Script Extension to install Active Directory
resource "azurerm_virtual_machine_extension" "ad_setup" {
  name                       = "install-ad"
  virtual_machine_id         = azurerm_windows_virtual_machine.domain_controller.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    fileUris = ["${azurerm_storage_blob.ad_setup_script.url}${data.azurerm_storage_account_blob_container_sas.scripts.sas}"]
  })

  protected_settings = jsonencode({
    commandToExecute = "powershell.exe -ExecutionPolicy Unrestricted -File Setup-AD.ps1"
  })

  depends_on = [
    azurerm_windows_virtual_machine.domain_controller,
    azurerm_storage_blob.ad_setup_script
  ]
}
