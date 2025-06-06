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

output "app_spoke_virtual_network_id" {
  description = "The ID of the app spoke virtual network"
  value       = azurerm_virtual_network.app_spoke.id
}

output "azure_firewall_id" {
  description = "The ID of the Azure Firewall"
  value       = azurerm_firewall.hub.id
}

output "azure_firewall_private_ip" {
  description = "The private IP address of the Azure Firewall"
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "windows_vm_id" {
  description = "The ID of the Windows virtual machine (if deployed)"
  value       = var.deploy_virtual_machines ? azurerm_windows_virtual_machine.windows_vm[0].id : null
}

output "windows_vm_public_ip" {
  description = "The public IP address of the Windows virtual machine (if deployed)"
  value       = var.deploy_virtual_machines ? azurerm_public_ip.windows_vm[0].ip_address : null
}

output "firewall_policy_id" {
  description = "The ID of the Azure Firewall Policy"
  value       = azurerm_firewall_policy.main.id
}

output "route_table_id" {
  description = "The ID of the route table"
  value       = azurerm_route_table.to_firewall.id
} 