/*
####################################### CISCO + AZURE VALIDATED DESIGN #######################################
######################### MERAKI vMX ADVANCED ROUTE MANIPULATION WITH CATALYST 8000v #########################

This configuration manages the following resources in your Azure tenant:

    - Hub VNET hosting 1x Catalyst 8000v router, 2x Meraki vMXs, and a Route Server
    - Two workload VNETs hosting 4x Ubuntu VMs to test intra/inter Subnet and intra/inter VNET traffic
        profiles

Refer to ./README.md file for more details.

If modifying code, please follow style conventions as specified here ('terraform fmt' does not do it all):
 https://developer.hashicorp.com/terraform/language/syntax/style

Author: Juan Sterbenc - jsterben@cisco.com | jisterbenc@gmail.com
License: GPL-3.0-or-later, see ./COPYING.txt for more details

##############################################################################################################
*/

# 1. terraform:
terraform {

  # TODO: this should be provided by python
  # change organization and workspace below to point to the right terraform cloud environment, at the time of
  #   coding variables are not allowed in the cloud block
  cloud {
    organization = ""
    workspaces {
      name = ""
    }
  }

  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.81.0"
    }
  }
}

# 2. providers:
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# 3. data subscription source:
data "azurerm_subscription" "subscription" {
}

# 4. resource groups:
resource "azurerm_resource_group" "resource_groups" {
  # using value as identifier of each individual resource group to conform with terraform files and azure
  #   naming styles (lower-case-underscore-separated and camel cases respectively)
  for_each = { for key, value in var.resource_groups : value => value }

  location = var.location
  name     = each.value
  tags     = var.tags
}

# TODO: add use remote/local Route Server in peerings, this is necessary for proper route advertisement to/from
#   spokes VNETs. You may need to wait until Route Server is created for this to work.
# 5. vnets, their subnets, and peerings between them:
#   5.1. all vnets:
resource "azurerm_virtual_network" "vnets" {
  for_each = { for key, value in var.vnets : value.name => value }

  address_space       = each.value.address_space
  location            = var.location
  name                = each.value.name
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  tags                = var.tags
}

#   5.2. subnets under each vnet:
resource "azurerm_subnet" "subnets" {
  for_each = { for key, value in var.subnets : join("", [value.virtual_network_name, value.name]) => value }

  address_prefixes     = each.value.address_prefixes
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  virtual_network_name = azurerm_virtual_network.vnets[each.value.virtual_network_name].name
}

#   5.3. vnet peerings:
resource "azurerm_virtual_network_peering" "vnet_peerings" {
  depends_on = [azurerm_route_server.route_server_0]
  for_each   = { for vnet_peering in var.vnet_peerings : vnet_peering.name => vnet_peering }

  name                         = each.value.name
  remote_virtual_network_id    = azurerm_virtual_network.vnets[each.value.remote_virtual_network_name].id
  resource_group_name          = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  virtual_network_name         = azurerm_virtual_network.vnets[each.value.virtual_network_name].name
  allow_virtual_network_access = each.value.allow_virtual_network_access
  allow_forwarded_traffic      = each.value.allow_forwarded_traffic
  allow_gateway_transit        = each.value.allow_gateway_transit
  use_remote_gateways          = each.value.use_remote_gateways
}

# 6. vms:
#   putting all vm objects under list to ease iterative creation
locals {
  vms = [var.vm_0, var.vm_1, var.vm_2, var.vm_3]
}

#   6.1. nics:
resource "azurerm_network_interface" "vm_nics" {
  for_each = { for vm in local.vms : vm.nic_name => vm }

  location = var.location
  name     = each.value.nic_name
  resource_group_name = (
    azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  )
  enable_accelerated_networking = false
  tags                          = var.tags

  ip_configuration {
    name                          = "IPConfiguration0"
    subnet_id                     = azurerm_subnet.subnets[join("", [each.value.vnet_name, each.value.subnet_name])].id
    private_ip_address_version    = "IPv4"
    private_ip_address_allocation = "Dynamic"
  }
}

#   6.2. actual vms:
resource "azurerm_linux_virtual_machine" "vms" {
  for_each = { for vm in local.vms : vm.vm_name => vm }

  name                            = each.value.vm_name
  resource_group_name             = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  location                        = var.location
  size                            = each.value.size
  network_interface_ids           = [azurerm_network_interface.vm_nics[each.value.nic_name].id]
  admin_username                  = var.vm_credentials.username
  admin_password                  = var.vm_credentials.password
  disable_password_authentication = false
  provision_vm_agent              = true
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = each.value.storage_account_type
  }

  source_image_reference {
    publisher = each.value.publisher
    offer     = each.value.offer
    sku       = each.value.sku
    version   = "latest"
  }
}

#   6.3. azure network watcher extension for networking troubleshooting:
#     use "az vm extension image list --location 'centralus' --output 'table' --name
#       'networkwatcheragentlinux'" in azure clie to fetch below fields

resource "azurerm_virtual_machine_extension" "extensions" {
  for_each = { for vm in local.vms : vm.vm_name => vm }

  name                      = "AzureNetworkWatcherExtension"
  publisher                 = "Microsoft.Azure.NetworkWatcher"
  type                      = "NetworkWatcherAgentLinux"
  type_handler_version      = "1.4" # latest at the time of coding
  virtual_machine_id        = azurerm_linux_virtual_machine.vms[each.value.vm_name].id
  automatic_upgrade_enabled = true
  tags                      = var.tags
}

#   6.4. data disks:
#     6.4.1. actual data disks:
resource "azurerm_managed_disk" "vm_data_disks" {
  for_each = { for vm in local.vms : vm.data_disk.name => vm }

  name                 = each.value.data_disk.name
  resource_group_name  = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  location             = var.location
  storage_account_type = each.value.storage_account_type
  create_option        = "Empty"
  disk_size_gb         = each.value.data_disk.size
  tags                 = var.tags
}

#     6.4.2. data disks attachments to vms:
resource "azurerm_virtual_machine_data_disk_attachment" "vm_data_disks_attachments" {
  for_each = { for vm in local.vms : vm.vm_name => vm }

  virtual_machine_id = azurerm_linux_virtual_machine.vms[each.value.vm_name].id
  managed_disk_id    = azurerm_managed_disk.vm_data_disks[each.value.data_disk.name].id
  lun                = 0
  caching            = "ReadWrite"
}

# 7. vmxs:
#    7.1. accept legal terms from marketplace:
#       only needs to be created once if it is not in your azure tenant already
#       i could not find a way (besides modular hierarchy) to do conditional creation
#         (if it is not present, then create it)
#       due to the complexities of such approach we will just comment this resource block and leave it to the
#         user to determine when it should be un-commented
#       leveraging data blocks to retrieve marketplace agreements fails if not present, there are no exception
#         handling mechanisms for resource errors currently

# resource "azurerm_marketplace_agreement" "vmx_legal_terms" {
#   publisher = "cisco"
#   offer = "cisco-meraki-vmx"
#   plan = "cisco-meraki-vmx"
# }

#    7.1. vmx primary managed application arm template deployment:
resource "azurerm_resource_group_template_deployment" "vmx_primary" {
  # TODO: dependencies will need to be dynamically modified by python, i do not want user to do it
  #   also, attempt modifying arm template vmx.json parameters types from 'string' to 'String'
  # needed as terraform does not infer dependencies from parameters_content field, at the time of coding
  #   terraform does not support functions and formatting under depends_on field, we need to pass the actual
  #   object, if attempting to bypass this you would get a validation error similar to:
  #
  #   │ References in depends_on must be to a whole object (resource, etc), not to an attribute of an object.
  depends_on = [
    azurerm_virtual_network.vnets["HubVNET"],
    azurerm_subnet.subnets["HubVNETSubnet0"]
  ]

  deployment_mode     = "Incremental"
  name                = format("%sARMTemplate", var.vmx_primary.name)
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  parameters_content = jsonencode({
    "location" : { "value" : var.location },
    "vmName" : { "value" : var.vmx_primary.name },
    "merakiAuthToken" : { "value" : var.vmx_primary_token },
    "zone" : { "value" : var.vmx_primary.zone },
    "virtualNetworkName" : { "value" : var.vnets.hub.name },
    "virtualNetworkNewOrExisting" : { "value" : "existing" },
    "virtualNetworkAddressPrefix" : { "value" : var.vnets.hub.address_space[0] },
    "virtualNetworkResourceGroup" : {
      "value" : azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
    },
    "virtualMachineSize" : { "value" : "Standard_F4s_v2" },
    "subnetName" : { "value" : var.subnets.hub_vnet_subnet_0.name },
    "subnetAddressPrefix" : { "value" : var.subnets.hub_vnet_subnet_0.address_prefixes[0] },
    "applicationResourceName" : { "value" : format("%sManagedApplication", var.vmx_primary.name) },
    "managedResourceGroupId" : {
      "value" : join("/", [
        data.azurerm_subscription.subscription.id,
        "resourceGroups",
        format("%sManagedApplicationResourceGroup", var.vmx_primary.name)
      ])
    }
  })
  template_content = file("./arm_templates/vmx.json")
  tags             = var.tags

  # based on hundreds of prior deployments, it should never take more than 4-5 mins, restricting it to 8 mins
  #   in the event something goes wrong and avoid time wasting
  timeouts {
    create = "8m"
    read   = "8m"
    update = "8m"
    delete = "8m"
  }
}

#    7.2. vmx secondary managed application arm template deployment:
resource "azurerm_resource_group_template_deployment" "vmx_secondary" {
  # TODO: dependencies will need to be dynamically modified by python, i do not want user to do it
  # needed as terraform does not infer dependencies from parameters_content field, at the time of coding
  #   terraform does not support functions and formatting under depends_on field, we need to pass the actual
  #   object, if attempting to bypass this you would get a validation error similar to:
  #
  #   │ References in depends_on must be to a whole object (resource, etc), not to an attribute of an object.
  depends_on = [
    azurerm_virtual_network.vnets["HubVNET"],
    azurerm_subnet.subnets["HubVNETSubnet1"]
  ]

  deployment_mode     = "Incremental"
  name                = format("%sARMTemplate", var.vmx_secondary.name)
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  parameters_content = jsonencode({
    "location" : { "value" : var.location },
    "vmName" : { "value" : var.vmx_secondary.name },
    "merakiAuthToken" : { "value" : var.vmx_secondary_token },
    "zone" : { "value" : var.vmx_secondary.zone },
    "virtualNetworkName" : { "value" : var.vnets.hub.name },
    "virtualNetworkNewOrExisting" : { "value" : "existing" },
    "virtualNetworkAddressPrefix" : { "value" : var.vnets.hub.address_space[0] },
    "virtualNetworkResourceGroup" : {
      "value" : azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
    },
    "virtualMachineSize" : { "value" : "Standard_F4s_v2" },
    "subnetName" : { "value" : var.subnets.hub_vnet_subnet_1.name },
    "subnetAddressPrefix" : { "value" : var.subnets.hub_vnet_subnet_1.address_prefixes[0] },
    "applicationResourceName" : { "value" : format("%sManagedApplication", var.vmx_secondary.name) },
    "managedResourceGroupId" : {
      "value" : join("/", [
        data.azurerm_subscription.subscription.id,
        "resourceGroups",
        format("%sManagedApplicationResourceGroup", var.vmx_secondary.name)
      ])
    }
  })
  template_content = file("./arm_templates/vmx.json")
  tags             = var.tags

  # based on hundreds of prior deployments, it should never take more than 4-5 mins, restricting it to 8 mins
  #   in the event something goes wrong and avoid time wasting
  timeouts {
    create = "8m"
    read   = "8m"
    update = "8m"
    delete = "8m"
  }
}

# 8. catalyst 8000v primary:
#   8.1. public ip:
resource "azurerm_public_ip" "catalyst_public_ip" {
  allocation_method   = "Static"
  location            = var.location
  name                = join("", [var.catalyst_8000v_primary.name, "PublicIP"])
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.catalyst_8000_v_primary_resource_group_name].name
  zones               = [var.catalyst_8000v_primary.zone]
  domain_name_label   = var.catalyst_8000v_primary.domain_name_label
  sku                 = "Standard"
  tags                = var.tags
}

#   8.2. nic:
resource "azurerm_network_interface" "catalyst_nic" {
  location                      = var.location
  name                          = join("", [var.catalyst_8000v_primary.name, "NIC"])
  resource_group_name           = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  enable_accelerated_networking = true
  enable_ip_forwarding          = true
  tags                          = var.tags

  ip_configuration {
    name                          = "IPConfiguration0"
    private_ip_address_allocation = "Dynamic"
    subnet_id = azurerm_subnet.subnets[join("",
    [var.catalyst_8000v_primary.vnet_name, var.catalyst_8000v_primary.subnet_name])].id
    private_ip_address_version = "IPv4"
    public_ip_address_id       = azurerm_public_ip.catalyst_public_ip.id
  }
}

#   8.3. network security group:
#     8.3.1. actual network security group:
resource "azurerm_network_security_group" "catalyst_nsg" {
  location            = var.location
  name                = join("", [var.catalyst_8000v_primary.name, "SSHNSG"])
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.catalyst_8000_v_primary_resource_group_name].name
  tags                = var.tags
}

#     8.3.2. nsg security rules:
resource "azurerm_network_security_rule" "nsg_rules" {
  for_each = { for rule in var.catalyst_8000v_primary.nsg_rules :
  join("", [var.catalyst_8000v_primary.name, rule.name]) => rule }

  access                      = each.value.access
  direction                   = each.value.direction
  name                        = each.value.name
  network_security_group_name = azurerm_network_security_group.catalyst_nsg.name
  priority                    = each.value.priority
  protocol                    = each.value.protocol
  resource_group_name         = azurerm_resource_group.resource_groups[var.resource_groups.catalyst_8000_v_primary_resource_group_name].name
  description                 = each.value.description
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix
}

#     8.3.3. nsg to nic association:
resource "azurerm_network_interface_security_group_association" "nsg_to_nic_association" {
  network_interface_id      = azurerm_network_interface.catalyst_nic.id
  network_security_group_id = azurerm_network_security_group.catalyst_nsg.id
}

#   8.4. vms with catalyst router image:
#     it was attempted multiple times to add azure network watcher extension, it was never successful so we
#       removed that block.
#       it is probably because of ios xe restrictions on the linux vm, if future releases allow the extension
#       it can easily be added beneath this block.
#       also, similar to the vmxs above, it is requires to accept once the catalyst marketplace offering
#       before deployment, it is better to accept such terms via azure cli since it is a one-time operation.
#       for this particular ios xe version, we used "az vm terms accept --offer cisco-c8000v-byol --plan
#       17_12_01a-byol --publisher cisco"
#       finally, we are using byol cisco licensing under this infrastructure, should you require payg you will
#       need to modify source image and plan information
resource "azurerm_linux_virtual_machine" "catalyst_router" {
  disable_password_authentication = false
  admin_username                  = var.catalyst_8000v_credentials.username
  admin_password                  = var.catalyst_8000v_credentials.password
  location                        = var.location
  name                            = var.catalyst_8000v_primary.name
  network_interface_ids           = [azurerm_network_interface.catalyst_nic.id]
  resource_group_name             = azurerm_resource_group.resource_groups[var.resource_groups.catalyst_8000_v_primary_resource_group_name].name
  size                            = "Standard_DS2_v2"
  zone                            = var.catalyst_8000v_primary.zone
  tags                            = var.tags

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    offer     = "cisco-c8000v-byol"
    publisher = "cisco"
    sku       = join("-", [var.catalyst_8000v_primary.ios_xe_version, "byol"])
    version   = "latest"
  }

  plan {
    name      = join("-", [var.catalyst_8000v_primary.ios_xe_version, "byol"])
    product   = "cisco-c8000v-byol"
    publisher = "cisco"
  }
}

# 9. route server resources:
#    9.1. public ip address:
resource "azurerm_public_ip" "route_server_0_public_ip" {
  name                = join("", [var.route_server_0.name, "PublicIP"])
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

#    9.2. route server:
resource "azurerm_route_server" "route_server_0" {
  name                = var.route_server_0.name
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  location            = var.location
  subnet_id = azurerm_subnet.subnets[join("",
  [var.vnets.hub.name, var.subnets.hub_vnet_route_server_subnet.name])].id
  sku                  = "Standard"
  public_ip_address_id = azurerm_public_ip.route_server_0_public_ip.id
  tags                 = var.tags
}

#    9.3. bgp peerings:
# it was first attempted to use similar iterative structures as in previous resources (see above this line),
#   but it was found that destruction of multiple "azurerm_route_server_bgp_connection" resource cannot be
#   accomplished in one destroy operation, most of the time (expect in one test where 2 where destroyed at the
#   same time) one destroy operation is required per bgp peering (4 total).
#   the error message you get in failed destroy operations is:
#
#     Error: waiting on deletion future for BGP Connection Bgp Connection:
#     .
#     Code="ConflictError" Message="The current operation could not be executed because it is already in
#     progress." Details=[]
#
#   we tried defining "azurerm_route_server_bgp_connection" resources individually outside for_each iteration
#   but results were the same.
#   the only way to make it work, under azurerm v3.81.0 and terraform v1.6.4, is to serially deploy this by
#   specifying dependencies.

# TODO: remove this, peering is only necessary in this infrastructure between route server and catalyst
#     9.3.1. route server 0 <== ebgp ==> vmx primary:
resource "azurerm_route_server_bgp_connection" "vmx_primary_bgp_peer" {
  name     = format("BGPSessionTo%s", var.vmx_primary.name)
  peer_asn = var.route_server_0.meraki_bgp_asn
  peer_ip = replace(
    azurerm_subnet.subnets[join("", [var.vnets.hub.name, var.subnets.hub_vnet_subnet_0.name])].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
  route_server_id = azurerm_route_server.route_server_0.id
}

# TODO: remove this, peering is only necessary in this infrastructure between route server and catalyst
#     9.3.2. route server 0 <== ebgp ==> vmx secondary:
resource "azurerm_route_server_bgp_connection" "vmx_secondary_bgp_peer" {
  depends_on = [azurerm_route_server_bgp_connection.vmx_primary_bgp_peer]

  name     = format("BGPSessionTo%s", var.vmx_secondary.name)
  peer_asn = var.route_server_0.meraki_bgp_asn
  peer_ip = replace(
    azurerm_subnet.subnets[join("", [var.vnets.hub.name, var.subnets.hub_vnet_subnet_1.name])].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
  route_server_id = azurerm_route_server.route_server_0.id
}

#     9.3.3. route server 0 <== ebgp ==> catalyst primary:
resource "azurerm_route_server_bgp_connection" "catalyst_primary_bgp_peer" {
  depends_on = [azurerm_route_server_bgp_connection.vmx_secondary_bgp_peer]

  name     = format("BGPSessionTo%s", var.catalyst_8000v_primary.name)
  peer_asn = var.route_server_0.catalyst_bgp_asn
  peer_ip = replace(
    azurerm_subnet.subnets[join("", [var.vnets.hub.name, var.subnets.hub_vnet_subnet_2.name])].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
  route_server_id = azurerm_route_server.route_server_0.id
}
