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
  name     = "HQ_BETA_Hub"
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

# Hub Virtual Network
resource "azurerm_virtual_network" "hub" {
  name                = "HQ_BETA_Hub_vNet"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.100.250.0/24"]

  tags = {
    Purpose = "Regional hub network"
  }
}

# Hub subnets
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.100.250.128/27"]
}

resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.100.250.0/26"]
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
  name                = "pip-fw-${var.location}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
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
      source_addresses      = ["10.100.251.0/27"] # App subnet
      destination_addresses = ["*"]
      destination_ports     = ["80"]
    }

    rule {
      name                  = "HTTPS"
      description           = "Allow HTTPS outbound"
      protocols             = ["TCP"]
      source_addresses      = ["10.100.251.0/27"] # App subnet
      destination_addresses = ["*"]
      destination_ports     = ["443"]
    }

    rule {
      name                  = "NTP"
      description           = "Allow NTP for time synchronization"
      protocols             = ["UDP"]
      source_addresses      = ["10.100.251.0/27"] # App subnet
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    rule {
      name                  = "RDP"
      description           = "Allow RDP inbound to Windows VM"
      protocols             = ["TCP"]
      source_addresses      = ["*"]
      destination_addresses = ["10.100.251.0/27"]
      destination_ports     = ["3389"]
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
      description = "Allow general web access for Windows VM"
      source_addresses = ["10.100.251.0/27"] # App subnet
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

  application_rule_collection {
    name     = "vm-specific-access"
    priority = 200
    action   = "Allow"

    rule {
      name        = "WindowsVirtualMachineHealth"
      description = "Supports Windows Updates and Windows Diagnostics"
      source_addresses = ["10.100.251.0/27"] # App subnet
      destination_fqdn_tags = ["WindowsDiagnostics", "WindowsUpdate"]
      protocols {
        type = "Https"
        port = 443
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

  ip_configuration {
    name                 = azurerm_public_ip.firewall.name
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  depends_on = [
    azurerm_firewall_policy_rule_collection_group.application_rules,
    azurerm_firewall_policy_rule_collection_group.network_rules
  ]
}

# Route table for next hop to firewall
resource "azurerm_route_table" "to_firewall" {
  name                = "HQ_BETA_Apps_RouteTable_FC"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  route {
    name                   = "BETA"
    address_prefix         = "10.100.250.0/24"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub.ip_configuration[0].private_ip_address
  }

  route {
    name           = "Internet"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}

# Network Security Group for app subnet
resource "azurerm_network_security_group" "app_subnet" {
  name                = "nsg-app-subnet"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "AllowRdpInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_port_range     = "3389"
    destination_address_prefix = "*"
    description                = "Allow RDP access to Windows VM"
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

# Spoke App Virtual Network
resource "azurerm_virtual_network" "app_spoke" {
  name                = "HQ_BETA_App7_vNet"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.100.251.0/26"]

  tags = {
    Purpose = "App spoke network"
  }
}

# App spoke subnets
resource "azurerm_subnet" "app_subnet" {
  name                 = "App7_Sub1"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.app_spoke.name
  address_prefixes     = ["10.100.251.0/27"]
}

resource "azurerm_subnet_network_security_group_association" "app_subnet" {
  subnet_id                 = azurerm_subnet.app_subnet.id
  network_security_group_id = azurerm_network_security_group.app_subnet.id
}

resource "azurerm_subnet_route_table_association" "app_subnet" {
  subnet_id      = azurerm_subnet.app_subnet.id
  route_table_id = azurerm_route_table.to_firewall.id
}

# VNet Peering: App Spoke to Hub
resource "azurerm_virtual_network_peering" "app_to_hub" {
  name                      = "HQ_BETA_App7_Peer"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.app_spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
}

# VNet Peering: Hub to App Spoke
resource "azurerm_virtual_network_peering" "hub_to_app" {
  name                      = "to_${azurerm_virtual_network.app_spoke.name}"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.app_spoke.id
  allow_forwarded_traffic   = false
  allow_gateway_transit     = false
  use_remote_gateways       = false
  depends_on                = [azurerm_virtual_network_peering.app_to_hub]
}

# Public IP for Windows VM
resource "azurerm_public_ip" "windows_vm" {
  count               = var.deploy_virtual_machines ? 1 : 0
  name                = "pip-vm-windows"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface for Windows VM
resource "azurerm_network_interface" "vm_windows" {
  count               = var.deploy_virtual_machines ? 1 : 0
  name                = "nic-vm-windows"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "default"
    subnet_id                     = azurerm_subnet.app_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.windows_vm[0].id
  }
}

# Windows Virtual Machine
resource "azurerm_windows_virtual_machine" "windows_vm" {
  count               = var.deploy_virtual_machines ? 1 : 0
  name                = "vm-windows-app"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  computer_name       = "win-app-vm"

  network_interface_ids = [
    azurerm_network_interface.vm_windows[0].id,
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