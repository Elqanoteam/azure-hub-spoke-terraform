variable "location" {
  description = "The location of this regional hub. All resources, including spoke resources, will be deployed to this region. This region must support availability zones."
  type        = string
  default     = "francecentral"
}

variable "deploy_vpn_gateway" {
  description = "Set to true to include a basic VPN Gateway deployment into the hub. Set to false to leave network space for a VPN Gateway, but do not deploy one."
  type        = bool
  default     = false
}

variable "deploy_virtual_machines" {
  description = "Set to true to include one Windows and one Linux virtual machine for you to experience peering, gateway transit, and bastion access."
  type        = bool
  default     = true
}

variable "admin_username" {
  description = "Username for both the Linux and Windows VM. Must only contain letters, numbers, hyphens, and underscores and may not start with a hyphen or number."
  type        = string
  default     = "azureadmin"
  validation {
    condition     = length(var.admin_username) >= 4 && length(var.admin_username) <= 20
    error_message = "Admin username must be between 4 and 20 characters."
  }
}

variable "admin_password" {
  description = "Password for both the Linux and Windows VM. Password must have 3 of the following: 1 lower case character, 1 upper case character, 1 number, and 1 special character. Must be at least 12 characters."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.admin_password) >= 12 && length(var.admin_password) <= 70
    error_message = "Admin password must be between 12 and 70 characters."
  }
} 