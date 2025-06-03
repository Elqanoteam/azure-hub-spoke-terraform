output "resource_group_name" {
  description = "The name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "The ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics workspace"
  value       = azurerm_log_analytics_workspace.hub.id
}

output "hub_virtual_network_id" {
  description = "The ID of the hub virtual network"
  value       = azurerm_virtual_network.hub.id
}

output "spoke_one_virtual_network_id" {
  description = "The ID of spoke one virtual network"
  value       = azurerm_virtual_network.spoke_one.id
}

output "spoke_two_virtual_network_id" {
  description = "The ID of spoke two virtual network"
  value       = azurerm_virtual_network.spoke_two.id
}

output "azure_firewall_id" {
  description = "The ID of the Azure Firewall"
  value       = azurerm_firewall.hub.id
}

output "azure_firewall_private_ip" {
  description = "The private IP address of the Azure Firewall"
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "azure_bastion_id" {
  description = "The ID of the Azure Bastion"
  value       = azurerm_bastion_host.hub.id
}

output "linux_vm_id" {
  description = "The ID of the Linux virtual machine (if deployed)"
  value       = var.deploy_virtual_machines ? azurerm_linux_virtual_machine.spoke_one_linux[0].id : null
}

output "windows_vm_id" {
  description = "The ID of the Windows virtual machine (if deployed)"
  value       = var.deploy_virtual_machines ? azurerm_windows_virtual_machine.spoke_two_windows[0].id : null
}

output "bastion_host_fqdn" {
  description = "The FQDN of the Bastion Host"
  value       = azurerm_bastion_host.hub.dns_name
}

output "firewall_policy_id" {
  description = "The ID of the Azure Firewall Policy"
  value       = azurerm_firewall_policy.main.id
} 