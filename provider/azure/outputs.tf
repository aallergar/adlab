output "domain_controller_public_ip" {
  description = "Public IP address of the Domain Controller"
  value       = azurerm_public_ip.dc_pip.ip_address
}

output "domain_controller_private_ip" {
  description = "Private IP address of the Domain Controller"
  value       = azurerm_network_interface.dc_nic.private_ip_address
}

output "domain_controller_vm_id" {
  description = "VM ID of the Domain Controller"
  value       = azurerm_windows_virtual_machine.domain_controller.id
}

output "resource_group_name" {
  description = "Resource Group Name"
  value       = azurerm_resource_group.ad_rg.name
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.ad_vnet.id
}

output "subnet_id" {
  description = "Subnet ID"
  value       = azurerm_subnet.ad_subnet.id
}

output "nsg_id" {
  description = "Network Security Group ID"
  value       = azurerm_network_security_group.ad_nsg.id
}

output "storage_account_name" {
  description = "Storage Account Name (contains Setup-AD.ps1)"
  value       = azurerm_storage_account.scripts.name
}

output "script_blob_url" {
  description = "URL of the Setup-AD.ps1 script in blob storage"
  value       = azurerm_storage_blob.ad_setup_script.url
  sensitive   = true
}

output "rdp_connection_string" {
  description = "RDP connection command"
  value       = "mstsc /v:${azurerm_public_ip.dc_pip.ip_address}"
}

output "admin_username" {
  description = "Admin username for the VM"
  value       = "azureadmin"
}

output "extension_status_check" {
  description = "Command to check extension status"
  value       = "az vm extension show --resource-group ${azurerm_resource_group.ad_rg.name} --vm-name ${azurerm_windows_virtual_machine.domain_controller.name} --name install-ad"
}
