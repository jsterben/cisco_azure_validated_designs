/*
####################################### CISCO + AZURE VALIDATED DESIGN #######################################
########################### MERAKI vMX SDWAN + CATALYST 8000v ROUTING AND SECURITY ###########################

This configuration manages the following resources in your Azure tenant:

    - Hub VNET hosting 2x Catalyst 8000v routers
    - Two workload VNETs hosting 3 Ubuntu VMs to test intra/inter Subnet and intra/inter VNET traffic profiles
    - VPN VNET hosting 2x Cisco Meraki vMXs
    - Azure networking components to make this functional (NSGs, Route Tables, Route Servers, etc)

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
      version = "~>3.78.0"
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
  for_each            = { for key, value in var.vnets_and_their_subnets : value.name => value }

  address_space       = each.value.ipv4_address_space
  location            = var.location
  name                = each.value.name
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  tags                = var.tags
}

#   5.2. all vnet subnets:
locals {
  subnets = concat(
    [for subnet in var.vnets_and_their_subnets.hub_vnet.subnets : merge(subnet,
    { virtual_network_name = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.hub_vnet.name].name })],
    [for subnet in var.vnets_and_their_subnets.vpn_vnet.subnets : merge(subnet,
    { virtual_network_name = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.vpn_vnet.name].name })],
    [for subnet in var.vnets_and_their_subnets.workloads_0_vnet.subnets : merge(subnet,
    { virtual_network_name = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.workloads_0_vnet.name].name })],
    [for subnet in var.vnets_and_their_subnets.workloads_1_vnet.subnets : merge(subnet,
    { virtual_network_name = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.workloads_1_vnet.name].name })]
  )
  hub_vnet_subnet_0_reference = join("",
    [var.vnets_and_their_subnets.hub_vnet.name, var.vnets_and_their_subnets.hub_vnet.subnets[0].name])
  hub_vnet_subnet_1_reference = join("",
    [var.vnets_and_their_subnets.hub_vnet.name, var.vnets_and_their_subnets.hub_vnet.subnets[1].name])
  hub_vnet_subnet_2_reference = join("",
    [var.vnets_and_their_subnets.hub_vnet.name, var.vnets_and_their_subnets.hub_vnet.subnets[2].name])
  hub_vnet_subnet_3_reference = join("",
    [var.vnets_and_their_subnets.hub_vnet.name, var.vnets_and_their_subnets.hub_vnet.subnets[3].name])
  hub_vnet_subnet_4_reference = join("",
    [var.vnets_and_their_subnets.hub_vnet.name, var.vnets_and_their_subnets.hub_vnet.subnets[4].name])
  vpn_vnet_subnet_0_reference = join("",
    [var.vnets_and_their_subnets.vpn_vnet.name, var.vnets_and_their_subnets.vpn_vnet.subnets[0].name])
  vpn_vnet_subnet_1_reference = join("",
    [var.vnets_and_their_subnets.vpn_vnet.name, var.vnets_and_their_subnets.vpn_vnet.subnets[1].name])
  workloads_0_vnet_subnet_0_reference = join("",
    [var.vnets_and_their_subnets.workloads_0_vnet.name, var.vnets_and_their_subnets.workloads_0_vnet.subnets[0].name])
  workloads_1_vnet_subnet_0_reference = join("",
    [var.vnets_and_their_subnets.workloads_1_vnet.name, var.vnets_and_their_subnets.workloads_1_vnet.subnets[0].name])
  workloads_1_vnet_subnet_1_reference = join("",
    [var.vnets_and_their_subnets.workloads_1_vnet.name, var.vnets_and_their_subnets.workloads_1_vnet.subnets[1].name])
}

resource "azurerm_subnet" "subnets" {
  for_each = { for subnet in local.subnets : join("", [subnet.virtual_network_name, subnet.name]) => subnet}

  address_prefixes     = each.value.ipv4_address_range
  name                 = each.value.name
  resource_group_name  = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  virtual_network_name = each.value.virtual_network_name
}

#   5.5. vnet peerings:
#     locals definition is needed as azurerm vnet peering resource requires remote vnet peer id and local peer
#       vnet name, embedding those two into variables is impossible for the former and non-elegant for the
#       latter.
locals {
  vnet_peerings = [
    # 5.5.1. vpn ==> hub:
    merge(
      var.vnets_and_their_subnets.vpn_vnet.peerings.to_hub,
      {
        virtual_network_name      = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.vpn_vnet.name].name
        remote_virtual_network_id = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.hub_vnet.name].id
      }
    ),
    # 5.5.2. workloads 0 ==> hub:
    merge(
      var.vnets_and_their_subnets.workloads_0_vnet.peerings.to_hub,
      {
        virtual_network_name      = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.workloads_0_vnet.name].name
        remote_virtual_network_id = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.hub_vnet.name].id
      }
    ),
    # 5.5.3. workloads 1 ==> hub:
    merge(
      var.vnets_and_their_subnets.workloads_1_vnet.peerings.to_hub,
      {
        virtual_network_name      = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.workloads_1_vnet.name].name
        remote_virtual_network_id = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.hub_vnet.name].id
      }
    ),
    # 5.5.4. vpn <== hub:
    merge(
      var.vnets_and_their_subnets.hub_vnet.peerings.to_vpn,
      {
        virtual_network_name      = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.hub_vnet.name].name
        remote_virtual_network_id = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.vpn_vnet.name].id
      }
    ),
    # 5.5.5. workloads 0 <== hub:
    merge(
      var.vnets_and_their_subnets.hub_vnet.peerings.to_workloads_0,
      {
        virtual_network_name      = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.hub_vnet.name].name
        remote_virtual_network_id = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.workloads_0_vnet.name].id
      }
    ),
    # 5.5.6. workloads 1 <== hub:
    merge(
      var.vnets_and_their_subnets.hub_vnet.peerings.to_workloads_1,
      {
        virtual_network_name      = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.hub_vnet.name].name
        remote_virtual_network_id = azurerm_virtual_network.vnets[var.vnets_and_their_subnets.workloads_1_vnet.name].id
      }
    )
  ]
}

resource "azurerm_virtual_network_peering" "vnet_peering" {
  for_each                  = { for peering in local.vnet_peerings : peering.name => peering }

  name                      = each.value.name
  remote_virtual_network_id = each.value.remote_virtual_network_id
  resource_group_name = (
    azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  )
  virtual_network_name         = each.value.virtual_network_name
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = each.value.allow_gateway_transit
  use_remote_gateways          = each.value.use_remote_gateways
}

# 6. vms:
#   6.1. nics - necessary before defining vms:
#     subnets are referenced via list index as they are defined as list entities under
#       var.vnets_and_their_subnets, since subnet naming conventions (subnet<x>) use numbers, this would not
#       impact readability on below blocks, we would still run into problems if var.vnets[<vnet>].subnets
#       member change, moving to object definition would be recommended.
locals {
  vm_nic_to_subnet_associations = [
    {
      vm_nic_name = var.vm_0.nic_name
      subnet_id   = azurerm_subnet.subnets[local.workloads_0_vnet_subnet_0_reference].id
    },
    {
      vm_nic_name = var.vm_1.nic_name
      subnet_id   = azurerm_subnet.subnets[local.workloads_1_vnet_subnet_0_reference].id
    },
    {
      vm_nic_name = var.vm_2.nic_name
      subnet_id   = azurerm_subnet.subnets[local.workloads_1_vnet_subnet_0_reference].id
    },
    {
      vm_nic_name = var.vm_3.nic_name
      subnet_id   = azurerm_subnet.subnets[local.workloads_1_vnet_subnet_1_reference].id
    }
  ]
}

resource "azurerm_network_interface" "vm_nics" {
  for_each = { for association in local.vm_nic_to_subnet_associations : association.vm_nic_name => association }

  location = var.location
  name     = each.value.vm_nic_name
  resource_group_name = (
    azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  )
  enable_accelerated_networking = false
  tags                          = var.tags

  ip_configuration {
    name                          = "IPConfiguration0"
    subnet_id                     = each.value.subnet_id
    private_ip_address_version    = "IPv4"
    private_ip_address_allocation = "Dynamic"
  }
}

#   6.2. actual vms:
locals {
  vms = [var.vm_0, var.vm_1, var.vm_2, var.vm_3]
}

resource "azurerm_linux_virtual_machine" "vms" {
  for_each                        = { for vm in local.vms : vm.vm_name => vm }

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
# TODO: continue styling here

#   6.3. azure network watcher extension for networking troubleshooting:
#     use "az vm extension image list --location 'centralus' --output 'table' --name
#       'networkwatcheragentlinux'" to fetch below fields

resource "azurerm_virtual_machine_extension" "extensions" {
  for_each                  = { for vm in local.vms : vm.vm_name => vm }
  name                      = "AzureNetworkWatcherExtension"
  publisher                 = "Microsoft.Azure.NetworkWatcher"
  type                      = "NetworkWatcherAgentLinux"
  type_handler_version      = "1.4" # latest at the time of coding
  virtual_machine_id        = azurerm_linux_virtual_machine.vms[each.value.vm_name].id
  automatic_upgrade_enabled = true
}

#   6.4. data disks:
#     6.4.1. actual data disks:
resource "azurerm_managed_disk" "vm_data_disks" {
  for_each             = { for vm in local.vms : vm.vm_name => vm }
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
  for_each           = { for vm in local.vms : vm.vm_name => vm }
  virtual_machine_id = azurerm_linux_virtual_machine.vms[each.value.vm_name].id
  managed_disk_id    = azurerm_managed_disk.vm_data_disks[each.value.vm_name].id
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
  depends_on = [
    azurerm_virtual_network.vnets["VPNVNET"],
    azurerm_subnet.subnets["VPNVNETSubnet0"]
  ]

  deployment_mode     = "Incremental"
  name                = format("%sARMTemplate", var.vmx_primary.name)
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  # needed as terraform does not infer dependencies from parameters_content field, at the time of coding
  #   terraform does not support functions and formatting under depends_on field, we need to pass the actual
  #   object, if attempting to bypass this you would get a validation error similar to:
  #
  #   │ References in depends_on must be to a whole object (resource, etc), not to an attribute of an object.
  parameters_content = jsonencode({
    "location" : { "value" : var.location },
    "vmName" : { "value" : var.vmx_primary.name },
    "merakiAuthToken" : { "value" : var.vmx_primary_token },
    "zone" : { "value" : var.vmx_primary.zone },
    "virtualNetworkName" : { "value" : var.vnets_and_their_subnets.vpn_vnet.name },
    "virtualNetworkNewOrExisting" : { "value" : "existing" },
    "virtualNetworkAddressPrefix" : { "value" : var.vnets_and_their_subnets.vpn_vnet.ipv4_address_space[0] },
    "virtualNetworkResourceGroup" : {
      "value" : azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
    },
    "virtualMachineSize" : { "value" : "Standard_F4s_v2" },
    "subnetName" : { "value" : var.vnets_and_their_subnets.vpn_vnet.subnets[0].name },
    "subnetAddressPrefix" : { "value" : var.vnets_and_their_subnets.vpn_vnet.subnets[0].ipv4_address_range[0] },
    "applicationResourceName" : { "value" : format("%sManagedApplication", var.vmx_primary.name) },
    "managedResourceGroupId" : {
      "value" : join("/", [
        data.azurerm_subscription.subscription.id,
        "resourceGroups",
        format("%sManagedApplicationResourceGroup", var.vmx_primary.name)
      ])
    }
  })
  template_content = file("./arm_templates/vmx/vmx.json")
  tags             = var.tags
}

#    7.2. vmx secondary managed application arm template deployment:
resource "azurerm_resource_group_template_deployment" "vmx_secondary" {
    # TODO: dependencies will need to be dynamically modified by python, i do not want user to do it
  depends_on = [
    azurerm_virtual_network.vnets["VPNVNET"],
    azurerm_subnet.subnets["VPNVNETSubnet1"]
  ]

  deployment_mode     = "Incremental"
  name                = format("%sARMTemplate", var.vmx_secondary.name)
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  # needed as terraform does not infer dependencies from parameters_content field, at the time of coding
  #   terraform does not support functions and formatting under depends_on field, we need to pass the actual
  #   object, if attempting to bypass this you would get a validation error similar to:
  #
  #   │ References in depends_on must be to a whole object (resource, etc), not to an attribute of an object.
  parameters_content = jsonencode({
    "location" : { "value" : var.location },
    "vmName" : { "value" : var.vmx_secondary.name },
    "merakiAuthToken" : { "value" : var.vmx_secondary_token },
    "zone" : { "value" : var.vmx_secondary.zone },
    "virtualNetworkName" : { "value" : var.vnets_and_their_subnets.vpn_vnet.name },
    "virtualNetworkNewOrExisting" : { "value" : "existing" },
    "virtualNetworkAddressPrefix" : { "value" : var.vnets_and_their_subnets.vpn_vnet.ipv4_address_space[0] },
    "virtualNetworkResourceGroup" : {
      "value" : azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
    },
    "virtualMachineSize" : { "value" : "Standard_F4s_v2" },
    "subnetName" : { "value" : var.vnets_and_their_subnets.vpn_vnet.subnets[1].name },
    "subnetAddressPrefix" : { "value" : var.vnets_and_their_subnets.vpn_vnet.subnets[1].ipv4_address_range[0] },
    "applicationResourceName" : { "value" : format("%sManagedApplication", var.vmx_secondary.name) },
    "managedResourceGroupId" : {
      "value" : join("/", [
        data.azurerm_subscription.subscription.id,
        "resourceGroups",
        format("%sManagedApplicationResourceGroup", var.vmx_secondary.name)
      ])
    }
  })
  template_content = file("./arm_templates/vmx/vmx.json")
  tags             = var.tags
}

# 8. catalyst 8000v routers:
locals {
  catalyst_routers = [
    merge(
      var.catalyst_8000_v_routers.primary,
      {
        resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.
        catalyst_8000_v_primary_resource_group_name].name
        outside_subnet = azurerm_subnet.subnets[local.hub_vnet_subnet_0_reference].id,
        inside_subnet  = azurerm_subnet.subnets[local.hub_vnet_subnet_1_reference].id,
        ios_xe_version = replace(var.catalyst_8000_v_routers.primary.ios_xe_version, ".", "_")
      }
    ),
    merge(
      var.catalyst_8000_v_routers.secondary,
      {
        resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.
        catalyst_8000_v_secondary_resource_group_name].name
        outside_subnet = azurerm_subnet.subnets[local.hub_vnet_subnet_2_reference].id,
        inside_subnet  = azurerm_subnet.subnets[local.hub_vnet_subnet_3_reference].id,
        ios_xe_version = replace(var.catalyst_8000_v_routers.secondary.ios_xe_version, ".", "_")
      }
    )
  ]
}

#   8.1. public ips:
#     if using pycharm ide, references on "catalyst.router" and "each.value" objects will be displayed as
#       unresolved, however terraform does evaluate them correctly
resource "azurerm_public_ip" "catalyst_public_ips" {
  for_each            = { for catalyst_router in local.catalyst_routers : catalyst_router.name => catalyst_router }
  allocation_method   = "Static"
  location            = var.location
  name                = join("", [each.value.name, "PublicIP"])
  resource_group_name = each.value.resource_group_name
  zones               = [each.value.zone]
  domain_name_label   = each.value.ipv4_public_ip_domain_name_prefix
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "outside_nics" {
  for_each = { for catalyst_router in local.catalyst_routers :
  catalyst_router.name => catalyst_router }
  location                      = var.location
  name                          = join("", [each.value.name, "OutsideNIC"])
  resource_group_name           = each.value.resource_group_name
  enable_accelerated_networking = true
  enable_ip_forwarding          = true
  tags                          = var.tags
  ip_configuration {
    name                          = "IPConfiguration0"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = each.value.outside_subnet
    private_ip_address_version    = "IPv4"
    public_ip_address_id          = azurerm_public_ip.catalyst_public_ips[each.value.name].id
  }
}

#   8.3. inside nics:
resource "azurerm_network_interface" "inside_nics" {
  for_each = { for catalyst_router in local.catalyst_routers :
  catalyst_router.name => catalyst_router }
  location                      = var.location
  name                          = join("", [each.value.name, "InsideNIC"])
  resource_group_name           = each.value.resource_group_name
  enable_accelerated_networking = true
  enable_ip_forwarding          = true
  tags                          = var.tags
  ip_configuration {
    name                          = "IPConfiguration0"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = each.value.inside_subnet
    private_ip_address_version    = "IPv4"
  }
}

#   8.4. network security groups:
#     8.4.1. actual network security groups:
resource "azurerm_network_security_group" "nsgs" {
  for_each = { for catalyst_router in local.catalyst_routers :
  catalyst_router.name => catalyst_router }
  location            = var.location
  name                = join("", [each.value.name, "OutsideNSG"])
  resource_group_name = each.value.resource_group_name
  tags                = var.tags
}

#     8.4.2. nsg security rules:
locals {
  nsg_rules = concat(
    concat(
      [for rule in var.catalyst_8000_v_routers.primary.outside_nsg_security_rules.inbound :
        merge(
          rule,
          {
            direction = "Inbound",
            network_security_group_name = azurerm_network_security_group.nsgs[var.catalyst_8000_v_routers.primary
            .name].name,
            resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.
            catalyst_8000_v_primary_resource_group_name].name,
            router_name = var.catalyst_8000_v_routers.primary.name
      })]
    ),
    concat(
      [for rule in var.catalyst_8000_v_routers.primary.outside_nsg_security_rules.outbound :
        merge(
          rule,
          {
            direction = "Outbound",
            network_security_group_name = azurerm_network_security_group.nsgs[var.catalyst_8000_v_routers.primary
            .name].name,
            resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.
            catalyst_8000_v_primary_resource_group_name].name,
            router_name = var.catalyst_8000_v_routers.primary.name
      })]
    ),
    concat(
      [for rule in var.catalyst_8000_v_routers.secondary.outside_nsg_security_rules.inbound :
        merge(
          rule,
          {
            direction = "Inbound",
            network_security_group_name = azurerm_network_security_group.nsgs[var.catalyst_8000_v_routers.secondary
            .name].name,
            resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.
            catalyst_8000_v_secondary_resource_group_name].name,
            router_name = var.catalyst_8000_v_routers.secondary.name
      })]
    ),
    concat(
      [for rule in var.catalyst_8000_v_routers.secondary.outside_nsg_security_rules.outbound :
        merge(
          rule,
          {
            direction = "Outbound",
            network_security_group_name = azurerm_network_security_group.nsgs[var.catalyst_8000_v_routers.secondary
            .name].name,
            resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.
            catalyst_8000_v_secondary_resource_group_name].name,
            router_name = var.catalyst_8000_v_routers.secondary.name
      })]
    )
  )
}

resource "azurerm_network_security_rule" "nsg_rules" {
  for_each                    = { for rule in local.nsg_rules : join("", [rule.router_name, rule.name, rule.direction]) => rule }
  access                      = each.value.access
  direction                   = each.value.direction
  name                        = each.value.name
  network_security_group_name = each.value.network_security_group_name
  priority                    = each.value.priority
  protocol                    = each.value.protocol
  resource_group_name         = each.value.resource_group_name
  description                 = each.value.description
  source_port_range           = each.value.source_port_range
  destination_port_range      = each.value.destination_port_range
  source_address_prefix       = each.value.source_address_prefix
  destination_address_prefix  = each.value.destination_address_prefix

}

#   8.5. subnet to nic associations:
resource "azurerm_subnet_network_security_group_association" "nsg_to_subnet_associations" {
  for_each = { for catalyst_router in local.catalyst_routers :
  catalyst_router.name => catalyst_router }
  network_security_group_id = azurerm_network_security_group.nsgs[each.value.name].id
  subnet_id                 = each.value.outside_subnet
}

#   8.6. vms with catalyst router image:
resource "azurerm_linux_virtual_machine" "catalyst_router" {
  for_each = { for catalyst_router in local.catalyst_routers :
  catalyst_router.name => catalyst_router }
  disable_password_authentication = false
  admin_username                  = var.catalyst_8000v_credentials.username
  admin_password                  = var.catalyst_8000v_credentials.password
  location                        = var.location
  name                            = each.value.name
  network_interface_ids = [
    azurerm_network_interface.outside_nics[each.value.name].id,
    azurerm_network_interface.inside_nics[each.value.name].id
  ]
  resource_group_name = each.value.resource_group_name
  size                = "Standard_DS2_v2"
  zone                = each.value.zone
  tags                = var.tags
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    offer     = "cisco-c8000v"
    publisher = "cisco"
    sku       = join("-", [each.value.ios_xe_version, "byol"])
    version   = "latest"
  }
  plan {
    name      = join("-", [each.value.ios_xe_version, "byol"])
    product   = "cisco-c8000v"
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
  name                 = var.route_server_0.name
  resource_group_name  = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  location             = var.location
  subnet_id            = azurerm_subnet.subnets[local.hub_vnet_subnet_4_reference].id
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
#   the only way to make it work, under azurerm v3.78.0 and terraform v1.6.2, is to serially deploy this by
#   specifying dependencies.

#     9.3.1. route server 0 <== ebgp ==> vmx primary:
resource "azurerm_route_server_bgp_connection" "vmx_primary_bgp_peer" {
  name     = format("BGPSessionTo%s", var.vmx_primary.name)
  peer_asn = var.route_server_0.meraki_bgp_asn
  peer_ip = replace(
    azurerm_subnet.subnets[local.vpn_vnet_subnet_0_reference].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
  route_server_id = azurerm_route_server.route_server_0.id
}

#     9.3.2. route server 0 <== ebgp ==> vmx secondary:
resource "azurerm_route_server_bgp_connection" "vmx_secondary_bgp_peer" {
  depends_on = [azurerm_route_server_bgp_connection.vmx_primary_bgp_peer]

  name       = format("BGPSessionTo%s", var.vmx_secondary.name)
  peer_asn   = var.route_server_0.meraki_bgp_asn
  peer_ip = replace(
    azurerm_subnet.subnets[local.vpn_vnet_subnet_1_reference].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
  route_server_id = azurerm_route_server.route_server_0.id
}

#     9.3.3. route server 0 <== ebgp ==> catalyst primary:
resource "azurerm_route_server_bgp_connection" "catalyst_primary_bgp_peer" {
  depends_on = [azurerm_route_server_bgp_connection.vmx_secondary_bgp_peer]

  name       = format("BGPSessionTo%s", var.catalyst_8000_v_routers.primary.name)
  peer_asn   = var.route_server_0.catalyst_bgp_asn
  peer_ip = replace(
    azurerm_subnet.subnets[local.hub_vnet_subnet_1_reference].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
  route_server_id = azurerm_route_server.route_server_0.id
}

#     9.3.4. route server 0 <== ebgp ==> catalyst secondary:
resource "azurerm_route_server_bgp_connection" "catalyst_secondary_bgp_peer" {
  depends_on = [azurerm_route_server_bgp_connection.catalyst_primary_bgp_peer]

  name       = format("BGPSessionTo%s", var.catalyst_8000_v_routers.secondary.name)
  peer_asn   = var.route_server_0.catalyst_bgp_asn
  peer_ip = replace(
    azurerm_subnet.subnets[local.hub_vnet_subnet_3_reference].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
  route_server_id = azurerm_route_server.route_server_0.id
}

# 10. route table:
#   10.1. actual route table:
resource "azurerm_route_table" "spokes_route_table" {
  name                = var.route_table.name
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  location            = var.location
  tags                = var.tags
}

#   10.2. routes:
# single route at the moment but leaving for_each iteration in case more are added in the future
resource "azurerm_route" "routes" {
  for_each            = { for route in var.route_table.routes : route.name => route }
  address_prefix      = each.value.address_prefix
  name                = each.value.name
  next_hop_type       = each.value.next_hop_type
  resource_group_name = azurerm_resource_group.resource_groups[var.resource_groups.main_resource_group_name].name
  route_table_name    = azurerm_route_table.spokes_route_table.name
  # catalyst primary inside ip is the next hop
  next_hop_in_ip_address = replace(
    azurerm_subnet.subnets[local.hub_vnet_subnet_1_reference].address_prefixes[0],
    # matches last ipv4 address octet and its subnet mask (e.g. /24) from subnet range and replaces it by
    # .4, which is the ip the vmx will be assigned
  "/\\.\\d\\/\\d{1,2}$/", ".4")
}

#   10.3. route table to subnet associations:
locals {
  spoke_subnet_ids = concat(
    [
      for subnet in var.vnets_and_their_subnets.vpn_vnet.subnets :
      {
        name = join("", [var.vnets_and_their_subnets.vpn_vnet.name, subnet.name]),
        id   = azurerm_subnet.subnets[join("", [var.vnets_and_their_subnets.vpn_vnet.name, subnet.name])].id
      }
    ],
    [
      for subnet in var.vnets_and_their_subnets.workloads_0_vnet.subnets :
      {
        name = join("", [var.vnets_and_their_subnets.workloads_0_vnet.name, subnet.name]),
        id   = azurerm_subnet.subnets[join("", [var.vnets_and_their_subnets.workloads_0_vnet.name, subnet.name])].id
      }
    ],
    [
      for subnet in var.vnets_and_their_subnets.workloads_1_vnet.subnets :
      {
        name = join("", [var.vnets_and_their_subnets.workloads_1_vnet.name, subnet.name]),
        id   = azurerm_subnet.subnets[join("", [var.vnets_and_their_subnets.workloads_1_vnet.name, subnet.name])].id
      }
    ]
  )
}

resource "azurerm_subnet_route_table_association" "spoke_route_table_to_subnet_associations" {
  for_each       = { for spoke_subnet_id in local.spoke_subnet_ids : spoke_subnet_id.name => spoke_subnet_id }
  route_table_id = azurerm_route_table.spokes_route_table.id
  subnet_id      = each.value.id
}
