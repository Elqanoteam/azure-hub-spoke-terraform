# Azure Hub-Spoke Network Topology with Terraform

This Terraform configuration deploys an Azure hub-and-spoke network topology with virtual machines. It is a conversion of the Microsoft Learn Bicep sample for [Hub and spoke deployment](https://learn.microsoft.com/en-us/samples/mspnp/samples/hub-and-spoke-deployment/).

## Architecture

This deployment creates:

- **Hub Virtual Network** (10.0.0.0/22) with:
  - Azure Bastion subnet
  - VPN Gateway subnet (for future use)
  - Azure Firewall subnet

- **Two Spoke Virtual Networks**:
  - Spoke One (10.100.0.0/22) 
  - Spoke Two (10.200.0.0/22)
  - Each with resources and private link endpoints subnets

- **Azure Firewall** with policies for network security
- **Azure Bastion** for secure VM access
- **DDoS Protection Standard**
- **Log Analytics Workspace** for monitoring
- **Virtual Machines** (optional):
  - Linux VM in Spoke One
  - Windows VM in Spoke Two

## Prerequisites

1. [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
2. [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) 
3. An Azure subscription with appropriate permissions

## Quick Start

1. **Clone or download** this configuration

2. **Authenticate with Azure**:
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

3. **Configure Terraform variables**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your desired values
   ```

4. **Deploy the infrastructure**:
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

## Configuration

### Resource Group

The configuration automatically creates a resource group with the naming pattern: `rg-hub-spoke-{location}` where `{location}` is the value of the `location` variable. The resource group will be created in the same region specified by the `location` variable.

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `location` | Azure region (must support availability zones) | francecentral | No |
| `deploy_virtual_machines` | Deploy sample VMs for testing | `true` | No |
| `deploy_vpn_gateway` | Deploy VPN Gateway (adds ~30 min) | `false` | No |
| `admin_username` | VM admin username | "azureadmin" | No |
| `admin_password` | VM admin password | - | Yes (if VMs enabled) |

### Example terraform.tfvars

```hcl
location = "francecentral"
deploy_virtual_machines = true
deploy_vpn_gateway = false
admin_username = "azureadmin"
admin_password = "YourSecurePassword123!"
```

## Network Design

### Address Spaces

- **Hub**: 10.0.0.0/22
  - Bastion: 10.0.1.0/26
  - Gateway: 10.0.2.0/27
  - Firewall: 10.0.3.0/26

- **Spoke One**: 10.100.0.0/22
  - Resources: 10.100.0.0/24
  - Private Link: 10.100.1.0/26

- **Spoke Two**: 10.200.0.0/22
  - Resources: 10.200.0.0/24
  - Private Link: 10.200.1.0/26

### Security

- **Network Security Groups** with appropriate rules for Bastion, resources, and private endpoints
- **Azure Firewall** with DNS proxy and basic network/application rules
- **Route Tables** directing traffic through the firewall
- **DDoS Protection Standard** on all virtual networks

## Accessing Virtual Machines

When `deploy_virtual_machines = true`, you can access the VMs through Azure Bastion:

1. Navigate to the Azure Portal
2. Go to the virtual machine resource
3. Click "Connect" → "Bastion"
4. Enter the credentials specified in your `terraform.tfvars`

### Linux VM (Spoke One)
- **Username**: As specified in `admin_username`
- **Password**: As specified in `admin_password`
- **Connection**: SSH via Bastion

### Windows VM (Spoke Two)
- **Username**: As specified in `admin_username`
- **Password**: As specified in `admin_password`
- **Connection**: RDP via Bastion

## Monitoring

All resources are configured to send diagnostic logs to the centralized Log Analytics workspace. You can:

- View network topology and flows
- Monitor firewall traffic and decisions
- Analyze resource performance metrics
- Set up alerts and dashboards


## Cleanup

To destroy all resources:

```bash
terraform destroy
```

Confirm by typing `yes` when prompted.

## Customization

### Adding More Spokes

To add additional spoke networks:

1. Copy the spoke virtual network resources
2. Update address spaces to avoid conflicts
3. Add peering relationships with the hub
4. Update firewall rules as needed

### Modifying Firewall Rules

Edit the firewall policy rule collection groups in `main.tf`:

- **Network rules**: For basic network connectivity (DNS, etc.)
- **Application rules**: For web traffic with FQDN filtering

### Integration with Existing Networks

To peer with existing virtual networks:

1. Add additional peering resources
2. Update route tables if needed
3. Modify firewall rules for cross-network traffic

## Related Resources

- [Microsoft Azure Hub-Spoke Reference Architecture](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Original Bicep Sample](https://learn.microsoft.com/en-us/samples/mspnp/samples/hub-and-spoke-deployment/)
- [Azure Firewall Documentation](https://docs.microsoft.com/en-us/azure/firewall/)
- [Azure Bastion Documentation](https://docs.microsoft.com/en-us/azure/bastion/)

