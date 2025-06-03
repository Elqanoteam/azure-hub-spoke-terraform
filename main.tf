terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

provider "azurerm" {
  features {}
}

# Data sources
data "azurerm_client_config" "current" {}

# Create the resource group
resource "azurerm_resource_group" "main" {
  name     = "rg-hub-spoke-${var.location}"
  location = var.location

  tags = {
    Purpose = "Hub-Spoke network topology"
    Environment = "Demo"
  }
}

# Random suffix for unique naming
resource "random_string" "suffix" {
  length  = 13
  special = false
  upper   = false
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "hub" {
  name                = "la-hub-${var.location}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90

  tags = {
    Purpose = "Hub network monitoring"
  }
}

# Diagnostic setting for Log Analytics workspace
resource "azurerm_monitor_diagnostic_setting" "la_hub" {
  name                       = "diag-la-hub"
  target_resource_id         = azurerm_log_analytics_workspace.hub.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# DDoS Protection Plan
resource "azurerm_network_ddos_protection_plan" "main" {
  name                = "vnet-${var.location}-ddos"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

# Network Security Group for Bastion subnet
resource "azurerm_network_security_group" "bastion" {
  name                = "nsg-${var.location}-bastion"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowWebExperienceInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
    description                = "Allow our users in. Update this to be as restrictive as possible."
  }

  security_rule {
    name                       = "AllowControlPlaneInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
    description                = "Service Requirement. Allow control plane access. Regional Tag not yet supported."
  }

  security_rule {
    name                       = "AllowHealthProbesInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
    description                = "Service Requirement. Allow Health Probes."
  }

  security_rule {
    name                       = "AllowBastionHostToHostInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
    description                = "Service Requirement. Allow Required Host to Host Communication."
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "No further inbound traffic allowed."
  }

  security_rule {
    name                       = "AllowSshToVnetOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "22"
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow SSH out to the virtual network"
  }

  security_rule {
    name                       = "AllowRdpToVnetOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "3389"
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow RDP out to the virtual network"
  }

  security_rule {
    name                       = "AllowControlPlaneOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "443"
    destination_address_prefix = "AzureCloud"
    description                = "Required for control plane outbound. Regional prefix not yet supported"
  }

  security_rule {
    name                       = "AllowBastionHostToHostOutbound"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_ranges    = ["8080", "5701"]
    destination_address_prefix = "VirtualNetwork"
    description                = "Service Requirement. Allow Required Host to Host Communication."
  }

  security_rule {
    name                       = "AllowBastionCertificateValidationOutbound"
    priority                   = 140
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "80"
    destination_address_prefix = "Internet"
    description                = "Service Requirement. Allow Required Session and Certificate Validation."
  }

  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "No further outbound traffic allowed."
  }
}

# Diagnostic setting for Bastion NSG
resource "azurerm_monitor_diagnostic_setting" "nsg_bastion" {
  name                       = "diag-nsg-bastion"
  target_resource_id         = azurerm_network_security_group.bastion.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }
}

# Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.location}-hub"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/22"]

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.main.id
    enable = true
  }

  tags = {
    Purpose = "Regional hub network"
  }
}

# Hub subnets
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.1.0/26"]
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion.id
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.2.0/27"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.0.3.0/26"]
}

# Diagnostic setting for Hub VNet
resource "azurerm_monitor_diagnostic_setting" "vnet_hub" {
  name                       = "diag-vnet-hub"
  target_resource_id         = azurerm_virtual_network.hub.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Public IPs for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  count               = 3
  name                = "pip-fw-${var.location}-${format("%02d", count.index)}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# Diagnostic settings for Firewall Public IPs
resource "azurerm_monitor_diagnostic_setting" "pip_firewall" {
  count                      = 3
  name                       = "diag-pip-firewall-${format("%02d", count.index)}"
  target_resource_id         = azurerm_public_ip.firewall[count.index].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Azure Firewall Policy
resource "azurerm_firewall_policy" "main" {
  name                = "fw-policies-${var.location}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Standard"
  threat_intelligence_mode = "Deny"

  insights {
    enabled                            = true
    default_log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id
    retention_in_days                  = 30
  }

  dns {
    proxy_enabled = true
  }
}

# Firewall Policy Rule Collection Group for Network Rules
resource "azurerm_firewall_policy_rule_collection_group" "network_rules" {
  name               = "DefaultNetworkRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 200

  network_rule_collection {
    name     = "org-wide-allowed"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "DNS"
      description           = "Allow DNS outbound (for simplicity, adjust as needed)"
      protocols             = ["UDP"]
      source_addresses      = ["*"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }

    rule {
      name                  = "HTTP"
      description           = "Allow HTTP outbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.100.0.0/24", "10.200.0.0/24"] # Both spoke subnets
      destination_addresses = ["*"]
      destination_ports     = ["80"]
    }

    rule {
      name                  = "HTTPS"
      description           = "Allow HTTPS outbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.100.0.0/24", "10.200.0.0/24"] # Both spoke subnets
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "NTP"
      description           = "Allow NTP for time synchronization"
      protocols             = ["UDP"]
      source_addresses      = ["10.100.0.0/24", "10.200.0.0/24"] # Both spoke subnets
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }
}

# Firewall Policy Rule Collection Group for Application Rules
resource "azurerm_firewall_policy_rule_collection_group" "application_rules" {
  name               = "DefaultApplicationRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 300
  depends_on         = [azurerm_firewall_policy_rule_collection_group.network_rules]

  application_rule_collection {
    name     = "general-internet-access"
    priority = 100
    action   = "Allow"

    rule {
      name        = "AllowGeneralWebAccess"
      description = "Allow general web access for both VMs"
      source_addresses = ["10.100.0.0/24", "10.200.0.0/24"] # Both spoke subnets
      destination_fqdns = ["*"]
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
    }
  }

  dynamic "application_rule_collection" {
    for_each = var.deploy_virtual_machines ? [1] : []
    content {
      name     = "vm-specific-access"
      priority = 200
      action   = "Allow"

      rule {
        name        = "WindowsVirtualMachineHealth"
        description = "Supports Windows Updates and Windows Diagnostics"
        source_addresses = ["10.200.0.0/24"] # The subnet that contains the Windows VMs
        destination_fqdn_tags = ["WindowsDiagnostics", "WindowsUpdate"]
        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}

# Azure Firewall
resource "azurerm_firewall" "hub" {
  name                = "fw-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  zones               = ["1", "2", "3"]
  firewall_policy_id  = azurerm_firewall_policy.main.id

  dynamic "ip_configuration" {
    for_each = range(3)
    content {
      name                 = azurerm_public_ip.firewall[ip_configuration.value].name
      subnet_id            = ip_configuration.value == 0 ? azurerm_subnet.firewall.id : null
      public_ip_address_id = azurerm_public_ip.firewall[ip_configuration.value].id
    }
  }

  depends_on = [
    azurerm_firewall_policy_rule_collection_group.application_rules,
    azurerm_firewall_policy_rule_collection_group.network_rules
  ]
}

# Diagnostic setting for Azure Firewall
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-firewall"
  target_resource_id         = azurerm_firewall.hub.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Public IP for Azure Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "pip-ab-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# Diagnostic setting for Bastion Public IP
resource "azurerm_monitor_diagnostic_setting" "pip_bastion" {
  name                       = "diag-pip-bastion"
  target_resource_id         = azurerm_public_ip.bastion.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Azure Bastion
resource "azurerm_bastion_host" "hub" {
  name                = "ab-${var.location}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"

  ip_configuration {
    name                 = "hub-subnet"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }
}

# Diagnostic setting for Azure Bastion
resource "azurerm_monitor_diagnostic_setting" "bastion" {
  name                       = "diag-bastion"
  target_resource_id         = azurerm_bastion_host.hub.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Route table for next hop to firewall
resource "azurerm_route_table" "to_firewall" {
  name                = "route-to-${var.location}-hub-fw"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "r-nexthop-to-fw"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }
}

# Network Security Group for resources subnet
resource "azurerm_network_security_group" "resources" {
  name                = "nsg-spoke-resources"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowBastionRdpFromHub"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "10.0.1.0/26" # Bastion subnet
    destination_port_ranges    = ["3389"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowBastionSshFromHub"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "10.0.1.0/26" # Bastion subnet
    destination_port_ranges    = ["22"]
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInBound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

# Diagnostic setting for resources NSG
resource "azurerm_monitor_diagnostic_setting" "nsg_resources" {
  name                       = "diag-nsg-resources"
  target_resource_id         = azurerm_network_security_group.resources.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }
}

# Network Security Group for private link endpoints subnet
resource "azurerm_network_security_group" "private_link" {
  name                = "nsg-spoke-privatelinkendpoints"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowAll443InFromVnet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_port_range     = "443"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "DenyAllOutbound"
    priority                   = 1000
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "*"
    destination_address_prefix = "*"
  }
}

# Diagnostic setting for private link NSG
resource "azurerm_monitor_diagnostic_setting" "nsg_private_link" {
  name                       = "diag-nsg-private-link"
  target_resource_id         = azurerm_network_security_group.private_link.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  enabled_log {
    category_group = "allLogs"
  }
}

# Spoke One Virtual Network
resource "azurerm_virtual_network" "spoke_one" {
  name                = "vnet-${var.location}-spoke-one"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.100.0.0/22"]

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.main.id
    enable = true
  }

  tags = {
    Purpose = "Spoke network one"
  }
}

# Spoke One subnets
resource "azurerm_subnet" "spoke_one_resources" {
  name                 = "snet-resources"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke_one.name
  address_prefixes     = ["10.100.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "spoke_one_resources" {
  subnet_id                 = azurerm_subnet.spoke_one_resources.id
  network_security_group_id = azurerm_network_security_group.resources.id
}

resource "azurerm_subnet_route_table_association" "spoke_one_resources" {
  subnet_id      = azurerm_subnet.spoke_one_resources.id
  route_table_id = azurerm_route_table.to_firewall.id
}

resource "azurerm_subnet" "spoke_one_private_link" {
  name                 = "snet-privatelinkendpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke_one.name
  address_prefixes     = ["10.100.1.0/26"]
}

resource "azurerm_subnet_network_security_group_association" "spoke_one_private_link" {
  subnet_id                 = azurerm_subnet.spoke_one_private_link.id
  network_security_group_id = azurerm_network_security_group.private_link.id
}

resource "azurerm_subnet_route_table_association" "spoke_one_private_link" {
  subnet_id      = azurerm_subnet.spoke_one_private_link.id
  route_table_id = azurerm_route_table.to_firewall.id
}

# VNet Peering: Spoke One to Hub
resource "azurerm_virtual_network_peering" "spoke_one_to_hub" {
  name                      = "to_${azurerm_virtual_network.hub.name}"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.spoke_one.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# VNet Peering: Hub to Spoke One
resource "azurerm_virtual_network_peering" "hub_to_spoke_one" {
  name                      = "to_${azurerm_virtual_network.spoke_one.name}"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_one.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on                = [azurerm_virtual_network_peering.spoke_one_to_hub]
}

# Diagnostic setting for Spoke One VNet
resource "azurerm_monitor_diagnostic_setting" "vnet_spoke_one" {
  name                       = "diag-vnet-spoke-one"
  target_resource_id         = azurerm_virtual_network.spoke_one.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Spoke Two Virtual Network
resource "azurerm_virtual_network" "spoke_two" {
  name                = "vnet-${var.location}-spoke-two"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.200.0.0/22"]

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.main.id
    enable = true
  }

  tags = {
    Purpose = "Spoke network two"
  }
}

# Spoke Two subnets
resource "azurerm_subnet" "spoke_two_resources" {
  name                 = "snet-resources"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke_two.name
  address_prefixes     = ["10.200.0.0/24"]
}

resource "azurerm_subnet_network_security_group_association" "spoke_two_resources" {
  subnet_id                 = azurerm_subnet.spoke_two_resources.id
  network_security_group_id = azurerm_network_security_group.resources.id
}

resource "azurerm_subnet_route_table_association" "spoke_two_resources" {
  subnet_id      = azurerm_subnet.spoke_two_resources.id
  route_table_id = azurerm_route_table.to_firewall.id
}

resource "azurerm_subnet" "spoke_two_private_link" {
  name                 = "snet-privatelinkendpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke_two.name
  address_prefixes     = ["10.200.1.0/26"]
}

resource "azurerm_subnet_network_security_group_association" "spoke_two_private_link" {
  subnet_id                 = azurerm_subnet.spoke_two_private_link.id
  network_security_group_id = azurerm_network_security_group.private_link.id
}

resource "azurerm_subnet_route_table_association" "spoke_two_private_link" {
  subnet_id      = azurerm_subnet.spoke_two_private_link.id
  route_table_id = azurerm_route_table.to_firewall.id
}

# VNet Peering: Spoke Two to Hub
resource "azurerm_virtual_network_peering" "spoke_two_to_hub" {
  name                      = "to_${azurerm_virtual_network.hub.name}"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.spoke_two.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# VNet Peering: Hub to Spoke Two
resource "azurerm_virtual_network_peering" "hub_to_spoke_two" {
  name                      = "to_${azurerm_virtual_network.spoke_two.name}"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke_two.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on                = [azurerm_virtual_network_peering.spoke_two_to_hub]
}

# Diagnostic setting for Spoke Two VNet
resource "azurerm_monitor_diagnostic_setting" "vnet_spoke_two" {
  name                       = "diag-vnet-spoke-two"
  target_resource_id         = azurerm_virtual_network.spoke_two.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Network Interface for Linux VM in Spoke One
resource "azurerm_network_interface" "vm_spoke_one_linux" {
  count               = var.deploy_virtual_machines ? 1 : 0
  name                = "nic-vm-${var.location}-spoke-one-linux"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "default"
    subnet_id                     = azurerm_subnet.spoke_one_resources.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Diagnostic setting for Linux VM NIC
resource "azurerm_monitor_diagnostic_setting" "nic_vm_spoke_one_linux" {
  count                      = var.deploy_virtual_machines ? 1 : 0
  name                       = "diag-nic-linux-vm"
  target_resource_id         = azurerm_network_interface.vm_spoke_one_linux[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Linux Virtual Machine in Spoke One
resource "azurerm_linux_virtual_machine" "spoke_one_linux" {
  count               = var.deploy_virtual_machines ? 1 : 0
  name                = "vm-${var.location}-spoke-one-linux"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_D2ds_v4"
  admin_username      = var.admin_username
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.vm_spoke_one_linux[0].id,
  ]

  admin_password = var.admin_password

  os_disk {
    caching                = "ReadOnly"
    storage_account_type   = "Standard_LRS"
    disk_encryption_set_id = null
    diff_disk_settings {
      option    = "Local"
      placement = "CacheDisk"
    }
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  patch_assessment_mode = "ImageDefault"
  patch_mode           = "ImageDefault"

  tags = {
    Purpose = "Demo Linux VM"
  }
}

# Network Interface for Windows VM in Spoke Two
resource "azurerm_network_interface" "vm_spoke_two_windows" {
  count               = var.deploy_virtual_machines ? 1 : 0
  name                = "nic-vm-${var.location}-spoke-two-windows"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "default"
    subnet_id                     = azurerm_subnet.spoke_two_resources.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Diagnostic setting for Windows VM NIC
resource "azurerm_monitor_diagnostic_setting" "nic_vm_spoke_two_windows" {
  count                      = var.deploy_virtual_machines ? 1 : 0
  name                       = "diag-nic-windows-vm"
  target_resource_id         = azurerm_network_interface.vm_spoke_two_windows[0].id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.hub.id

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}

# Windows Virtual Machine in Spoke Two
resource "azurerm_windows_virtual_machine" "spoke_two_windows" {
  count               = var.deploy_virtual_machines ? 1 : 0
  name                = "vm-${var.location}-spoke-two-windows"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  computer_name       = "spoke-two-win"

  network_interface_ids = [
    azurerm_network_interface.vm_spoke_two_windows[0].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  enable_automatic_updates = true
  provision_vm_agent      = true
  patch_assessment_mode   = "ImageDefault"
  patch_mode             = "AutomaticByOS"

  tags = {
    Purpose = "Demo Windows VM"
  }
} 