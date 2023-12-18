/*
##############################################################################################################
Variables file

Refer to topology in README.md file to correlate variables to resources deployed.
##############################################################################################################
*/

# 1. resource groups:
variable "resource_groups" {
  description = "Resource Groups specifications"
  type = object({
    main_resource_group_name                      = string
    catalyst_8000_v_primary_resource_group_name   = string
    catalyst_8000_v_secondary_resource_group_name = string
  })
  default = {
    main_resource_group_name                      = "MainResourceGroup"
    catalyst_8000_v_primary_resource_group_name   = "Catalyst8000vPrimaryResourceGroup"
    catalyst_8000_v_secondary_resource_group_name = "Catalyst8000vSecondaryResourceGroup"
  }
}

# 2. vnets, their subnets and peerings:
variable "vnets_and_their_subnets" {
  description = "VNETs and their Subnets specifications"
  type = object({
    vpn_vnet = object({
      name               = string
      ipv4_address_space = list(string)
      subnets = list(object({
        name               = string
        ipv4_address_range = list(string)
      }))
      peerings = object({
        to_hub = object({
          name                  = string
          allow_gateway_transit = bool
          use_remote_gateways   = bool
        })
      })
    })
    workloads_0_vnet = object({
      name               = string
      ipv4_address_space = list(string)
      subnets = list(object({
        name               = string
        ipv4_address_range = list(string)
      }))
      peerings = object({
        to_hub = object({
          name                  = string
          allow_gateway_transit = bool
          use_remote_gateways   = bool
        })
      })
    })
    workloads_1_vnet = object({
      name               = string
      ipv4_address_space = list(string)
      subnets = list(object({
        name               = string
        ipv4_address_range = list(string)
      }))
      peerings = object({
        to_hub = object({
          name                  = string
          allow_gateway_transit = bool
          use_remote_gateways   = bool
        })
      })
    })
    hub_vnet = object({
      name               = string
      ipv4_address_space = list(string)
      subnets = list(object({
        name               = string
        ipv4_address_range = list(string)
      }))
      peerings = object({
        to_vpn = object({
          name                  = string
          allow_gateway_transit = bool
          use_remote_gateways   = bool
        })
        to_workloads_0 = object({
          name                  = string
          allow_gateway_transit = bool
          use_remote_gateways   = bool
        })
        to_workloads_1 = object({
          name                  = string
          allow_gateway_transit = bool
          use_remote_gateways   = bool
        })
      })
    })
  })
  default = {
    vpn_vnet = {
      name               = "VPNVNET"
      ipv4_address_space = ["10.0.0.0/16"]
      subnets = [
        {
          name               = "Subnet0"
          ipv4_address_range = ["10.0.0.0/24"]
        },
        {
          name               = "Subnet1"
          ipv4_address_range = ["10.0.1.0/24"]
        }
      ]
      peerings = {
        to_hub = {
          name                  = "VPNToHubVNETPeering"
          allow_gateway_transit = false
          use_remote_gateways   = false
        }
      }
    }
    workloads_0_vnet = {
      name               = "Workloads0VNET"
      ipv4_address_space = ["10.1.0.0/16"]
      subnets = [
        {
          name               = "Subnet0"
          ipv4_address_range = ["10.1.0.0/24"]
        }
      ]
      peerings = {
        to_hub = {
          name                  = "Workloads0ToHubVNETPeering"
          allow_gateway_transit = false
          use_remote_gateways   = false
        }
      }
    }
    workloads_1_vnet = {
      name               = "Workloads1VNET"
      ipv4_address_space = ["10.2.0.0/16"]
      subnets = [
        {
          name               = "Subnet0"
          ipv4_address_range = ["10.2.0.0/24"]
        },
        {
          name               = "Subnet1"
          ipv4_address_range = ["10.2.1.0/24"]
        }
      ]
      peerings = {
        to_hub = {
          name                  = "Workloads1ToHubVNETPeering"
          allow_gateway_transit = false
          use_remote_gateways   = false
        }
      }
    }
    hub_vnet = {
      name               = "HubVNET"
      ipv4_address_space = ["10.3.0.0/16"]
      subnets = [
        {
          name               = "Subnet0"
          ipv4_address_range = ["10.3.0.0/24"]
        },
        {
          name               = "Subnet1"
          ipv4_address_range = ["10.3.1.0/24"]
        },
        {
          name               = "Subnet2"
          ipv4_address_range = ["10.3.2.0/24"]
        },
        {
          name               = "Subnet3"
          ipv4_address_range = ["10.3.3.0/24"]
        },
        {
          name               = "RouteServerSubnet"
          ipv4_address_range = ["10.3.255.0/24"]
        }
      ]
      peerings = {
        to_vpn = {
          name                  = "HubToVPNVNETPeering"
          allow_gateway_transit = true
          use_remote_gateways   = false
        }
        to_workloads_0 = {
          name                  = "HubToWorkloads0VNETPeering"
          allow_gateway_transit = true
          use_remote_gateways   = false
        }
        to_workloads_1 = {
          name                  = "HubToWorkloads1VNETPeering"
          allow_gateway_transit = true
          use_remote_gateways   = false
        }
      }
    }
  }
}

# 3. vms:
#   all vms here are similar to one another, which may push for the case of simplifying variable blocks below,
#     that is, use a single one and change vm index (0, 1, 2, etc). we will leave it individually defined as
#     there may be a need to have different vms with varying characteristics
#    3.1. vm 0:
variable "vm_0" {
  description = "VM0 specifications"
  type = object(
    {
      vm_name = string
      size    = string # use "Get-AzVMSize -Location 'centralus'" or equivalent to get valid size strings, use this
      #    tool https://azure.microsoft.com/en-us/pricing/vm-selector/amd/ for guidance
      os_disk_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS -
      #    Premium_ZRS
      publisher = string # use "Get-AzVMImagePublisher -Location 'centralus'" or equivalent to get valid
      #     publisher strings
      offer = string # use "Get-AzVMImageOffer -Location 'centralus' -PublisherName 'Canonical'" or equivalent to
      #    get valid offer strings
      sku = string # use "Get-AzVMImageSku -Location 'Central US' -PublisherName 'Canonical' -Offer 'ubuntu'" or
      #    similar to get valid sku strings
      storage_account_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS
      #    - Premium_ZRS types for the data disk storage account
      nic_name = string    # this will need to change if multiple nics are to be deployed on a vm
      data_disk = object({ # this will need to change if multiple data disks are to be deployed on a vm
        name = string
        size = string # size in GB
      })
    }
  )
  default = {
    vm_name              = "VM0"
    size                 = "Standard_D2as_v5"
    os_disk_type         = "Standard_LRS"
    publisher            = "Canonical"
    offer                = "0001-com-ubuntu-server-jammy"
    sku                  = "22_04-lts-gen2"
    storage_account_type = "Standard_LRS"
    nic_name             = "NIC0VM0"
    data_disk = {
      name = "DataDisk0VM0"
      size = "32"
    }
  }
}

#    3.2. vm 1:
variable "vm_1" {
  description = "VM1 specifications"
  type = object(
    {
      vm_name = string
      size    = string # use "Get-AzVMSize -Location 'centralus'" or equivalent to get valid size strings, use this
      #    tool https://azure.microsoft.com/en-us/pricing/vm-selector/amd/ for guidance
      os_disk_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS -
      #    Premium_ZRS
      publisher = string # use "Get-AzVMImagePublisher -Location 'centralus'" or equivalent to get valid
      #     publisher strings
      offer = string # use "Get-AzVMImageOffer -Location 'centralus' -PublisherName 'Canonical'" or equivalent to
      #    get valid offer strings
      sku = string # use "Get-AzVMImageSku -Location 'Central US' -PublisherName 'Canonical' -Offer 'ubuntu'" or
      #    similar to get valid sku strings
      storage_account_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS
      #    - Premium_ZRS types for the data disk storage account
      nic_name = string    # this will need to change if multiple nics are to be deployed on a vm
      data_disk = object({ # this will need to change if multiple data disks are to be deployed on a vm
        name = string
        size = string # size in GB
      })
    }
  )
  default = {
    vm_name              = "VM1"
    size                 = "Standard_D2as_v5"
    os_disk_type         = "Standard_LRS"
    publisher            = "Canonical"
    offer                = "0001-com-ubuntu-server-jammy"
    sku                  = "22_04-lts-gen2"
    storage_account_type = "Standard_LRS"
    nic_name             = "NIC0VM1"
    data_disk = {
      name = "DataDisk0VM1"
      size = "32"
    }
  }
}

#    3.3. vm 2:
variable "vm_2" {
  description = "VM2 specifications"
  type = object(
    {
      vm_name = string
      size    = string # use "Get-AzVMSize -Location 'centralus'" or equivalent to get valid size strings, use this
      #    tool https://azure.microsoft.com/en-us/pricing/vm-selector/amd/ for guidance
      os_disk_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS -
      #    Premium_ZRS
      publisher = string # use "Get-AzVMImagePublisher -Location 'centralus'" or equivalent to get valid
      #     publisher strings
      offer = string # use "Get-AzVMImageOffer -Location 'centralus' -PublisherName 'Canonical'" or equivalent to
      #    get valid offer strings
      sku = string # use "Get-AzVMImageSku -Location 'Central US' -PublisherName 'Canonical' -Offer 'ubuntu'" or
      #    similar to get valid sku strings
      storage_account_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS
      #    - Premium_ZRS types for the data disk storage account
      nic_name = string    # this will need to change if multiple nics are to be deployed on a vm
      data_disk = object({ # this will need to change if multiple data disks are to be deployed on a vm
        name = string
        size = string # size in GB
      })
    }
  )
  default = {
    vm_name              = "VM2"
    size                 = "Standard_D2as_v5"
    os_disk_type         = "Standard_LRS"
    publisher            = "Canonical"
    offer                = "0001-com-ubuntu-server-jammy"
    sku                  = "22_04-lts-gen2"
    storage_account_type = "Standard_LRS"
    nic_name             = "NIC0VM2"
    data_disk = {
      name = "DataDisk0VM2"
      size = "32"
    }
  }
}

#    3.4. vm 3:
variable "vm_3" {
  description = "VM3 specifications"
  type = object(
    {
      vm_name = string
      size    = string # use "Get-AzVMSize -Location 'centralus'" or equivalent to get valid size strings, use this
      #    tool https://azure.microsoft.com/en-us/pricing/vm-selector/amd/ for guidance
      os_disk_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS -
      #    Premium_ZRS
      publisher = string # use "Get-AzVMImagePublisher -Location 'centralus'" or equivalent to get valid
      #     publisher strings
      offer = string # use "Get-AzVMImageOffer -Location 'centralus' -PublisherName 'Canonical'" or equivalent to
      #    get valid offer strings
      sku = string # use "Get-AzVMImageSku -Location 'Central US' -PublisherName 'Canonical' -Offer 'ubuntu'" or
      #    similar to get valid sku strings
      storage_account_type = string # chose between Standard_LRS - StandardSSD_LRS - Premium_LRS - StandardSSD_ZRS
      #    - Premium_ZRS types for the data disk storage account
      nic_name = string    # this will need to change if multiple nics are to be deployed on a vm
      data_disk = object({ # this will need to change if multiple data disks are to be deployed on a vm
        name = string
        size = string # size in GB
      })
    }
  )
  default = {
    vm_name              = "VM3"
    size                 = "Standard_D2as_v5"
    os_disk_type         = "Standard_LRS"
    publisher            = "Canonical"
    offer                = "0001-com-ubuntu-server-jammy"
    sku                  = "22_04-lts-gen2"
    storage_account_type = "Standard_LRS"
    nic_name             = "NIC0VM3"
    data_disk = {
      name = "DataDisk0VM3"
      size = "32"
    }
  }
}

# 4. vmxs:
#    4.1. vmx primary:
variable "vmx_primary" {
  description = "vMX primary specifications"
  type = object(
    {
      name                 = string
      zone                 = string
    }
  )
  default = {
    name = "VMXPrimary"
    zone                 = "1"
  }
}

#    4.2. vmx secondary:
variable "vmx_secondary" {
  description = "vMX secondary specifications"
  type = object(
    {
      name                 = string
      zone                 = string
    }
  )
  default = {
    name = "VMXSecondary"
    zone                 = "2"
  }
}

# 5. catalyst routers:
variable "catalyst_8000_v_routers" {
  description = "Catalyst 8000v routers specifications"
  type = object({
    primary = object({
      ipv4_public_ip_domain_name_prefix = string
      name                              = string
      zone                              = string
      ios_xe_version                    = string
      outside_nsg_security_rules = object({
        inbound = list(object({
          name                       = string
          description                = string
          protocol                   = string
          source_port_range          = string
          destination_port_range     = string
          source_address_prefix      = string
          destination_address_prefix = string
          access                     = string
          priority                   = number
        }))
        outbound = list(object({
          name                       = string
          description                = string
          protocol                   = string
          source_port_range          = string
          destination_port_range     = string
          source_address_prefix      = string
          destination_address_prefix = string
          access                     = string
          priority                   = number
        }))
      })
    })
    secondary = object({
      ipv4_public_ip_domain_name_prefix = string
      name                              = string
      zone                              = string
      ios_xe_version                    = string
      outside_nsg_security_rules = object({
        inbound = list(object({
          name                       = string
          description                = string
          protocol                   = string
          source_port_range          = string
          destination_port_range     = string
          source_address_prefix      = string
          destination_address_prefix = string
          access                     = string
          priority                   = string
        }))
        outbound = list(object({
          name                       = string
          description                = string
          protocol                   = string
          source_port_range          = string
          destination_port_range     = string
          source_address_prefix      = string
          destination_address_prefix = string
          access                     = string
          priority                   = string
        }))
      })
    })
  })
  default = {
    primary = {
      ipv4_public_ip_domain_name_prefix = "catalyst-8000-v-primary"
      name                              = "Catalyst8000vPrimary"
      zone                              = "1"
      # get this from azure portal, navigate to marketplace --> search "catalyst 8000v" --> click "create" on
      #   "Cisco Catalyst 8000V Edge Software - Solution Deployment" --> copy/paste ios xe version from
      #   "Cisco IOS XE Image Version" field
      ios_xe_version = "17.06.01a"
      outside_nsg_security_rules = {
        inbound = [
          {
            name = "AllowInternetInboundToCatalystRouterOutsideIP"
            # could not input multi-line string
            description            = "Allows inbound traffic from the internet into the Catalyst 8000v router outside NIC"
            protocol               = "*"
            source_port_range      = "*"
            destination_port_range = "*"
            source_address_prefix  = "Internet"
            # this is the private ip the router gets from hubvnet/subnet0
            destination_address_prefix = "10.3.0.4/32"
            access                     = "Allow"
            priority                   = 100
          },
          {
            name                   = "DenyInternetToVNETs"
            description            = "Denies the internet from contacting any private IP from any VNET"
            protocol               = "*"
            source_port_range      = "*"
            destination_port_range = "*"
            source_address_prefix  = "Internet"
            # this service tag includes all ip prefixes from all vnets
            destination_address_prefix = "VirtualNetwork"
            access                     = "Deny"
            priority                   = 105
          },
          {
            # needed to suffix "Inbound" to differentiate from equivalent outbound rule, they would both be
            #   called ""DenyInterVNET" otherwise
            name                       = "DenyInterVNETInbound"
            description                = "Denies inter-vnet traffic"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "VirtualNetwork"
            access                     = "Deny"
            priority                   = 110
          }
        ]
        outbound = [
          {
            name = "AllowCatalystRouterOutsideIPToInternet"
            # could not input multi-line string
            description            = "Allows outbound traffic from Catalyst 8000 v router outside NIC to the internet"
            protocol               = "*"
            source_port_range      = "*"
            destination_port_range = "*"
            # this is the private ip the router gets from hubvnet/subnet0
            source_address_prefix      = "10.3.0.4/32"
            destination_address_prefix = "Internet"
            access                     = "Allow"
            priority                   = 100
          },
          {
            name                       = "DenyVNETsToInternet"
            description                = "Denies VNET IP ranges from contacting the internet"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "Internet"
            access                     = "Deny"
            priority                   = 105
          },
          {
            # needed to suffix "Outbound" to differentiate from equivalent inbound rule, they would both be
            #   called ""DenyInterVNET" otherwise
            name                       = "DenyInterVNETOutbound"
            description                = "Denies inter-vnet traffic"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "VirtualNetwork"
            access                     = "Deny"
            priority                   = 110
          }
        ]
      }
    }
    secondary = {
      ipv4_public_ip_domain_name_prefix = "catalyst-8000-v-secondary"
      name                              = "Catalyst8000vSecondary"
      zone                              = "2"
      # get this from azure portal, navigate to marketplace -->
      ios_xe_version = "17.06.01a"
      outside_nsg_security_rules = {
        inbound = [
          {
            name = "AllowInternetInboundToCatalystRouterOutsideIP"
            # could not input multi-line string
            description            = "Allows inbound traffic from the internet into the Catalyst 8000v router outside NIC"
            protocol               = "*"
            source_port_range      = "*"
            destination_port_range = "*"
            source_address_prefix  = "Internet"
            # this is the private ip the router gets from hubvnet/subnet0
            destination_address_prefix = "10.3.2.4/32"
            access                     = "Allow"
            priority                   = 100
          },
          {
            name                   = "DenyInternetToVNETs"
            description            = "Denies the internet from contacting any private IP from any VNET"
            protocol               = "*"
            source_port_range      = "*"
            destination_port_range = "*"
            source_address_prefix  = "Internet"
            # this service tag includes all ip prefixes from all vnets
            destination_address_prefix = "VirtualNetwork"
            access                     = "Deny"
            priority                   = 105
          },
          {
            # needed to suffix "Inbound" to differentiate from equivalent outbound rule, they would both be
            #   called ""DenyInterVNET" otherwise
            name                       = "DenyInterVNETInbound"
            description                = "Denies inter-vnet traffic"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "VirtualNetwork"
            access                     = "Deny"
            priority                   = 110
          }
        ]
        outbound = [
          {
            name = "AllowCatalystRouterOutsideIPToInternet"
            # could not input multi-line string
            description            = "Allows outbound traffic from Catalyst 8000 v router outside NIC to the internet"
            protocol               = "*"
            source_port_range      = "*"
            destination_port_range = "*"
            # this is the private ip the router gets from hubvnet/subnet0
            source_address_prefix      = "10.3.2.4/32"
            destination_address_prefix = "Internet"
            access                     = "Allow"
            priority                   = 100
          },
          {
            name                       = "DenyVNETsToInternet"
            description                = "Denies VNET IP ranges from contacting the internet"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "Internet"
            access                     = "Deny"
            priority                   = 105
          },
          {
            # needed to suffix "Outbound" to differentiate from equivalent inbound rule, they would both be
            #   called ""DenyInterVNET" otherwise
            name                       = "DenyInterVNETOutbound"
            description                = "Denies inter-vnet traffic"
            protocol                   = "*"
            source_port_range          = "*"
            destination_port_range     = "*"
            source_address_prefix      = "VirtualNetwork"
            destination_address_prefix = "VirtualNetwork"
            access                     = "Deny"
            priority                   = 110
          }
        ]
      }
    }
  }
}

# 5. route server:
variable "route_server_0" {
  description = "Route Server 0 specifications"
  type = object(
    {
      name             = string
      meraki_bgp_asn   = number
      catalyst_bgp_asn = number
    }
  )
  default = {
    name = "RouteServer0"
    # TODO: Change variable below to "TO_BE_PROVIDED_BY_PYTHON", testing this manually at the moment
    meraki_bgp_asn   = "64601"
    catalyst_bgp_asn = "64602"
  }
}

# 6. route table:
variable "route_table" {
  description = "Spokes Route Table specifications"
  type = object(
    {
      name = string
      routes = list(
        object(
          {
            name           = string
            address_prefix = string
            # chose between VirtualNetworkGateway - VnetLocal - Internet - VirtualAppliance - None
            next_hop_type  = string
          }
        )
      )
    }
  )
  default = {
    name = "SpokesRouteTable"
    routes = [
      {
        name           = "DefaultRoute"
        address_prefix = "0.0.0.0/0"
        next_hop_type  = "VirtualAppliance"
      }
    ]
  }
}

# 7. sensitive:
variable "vm_credentials" {
  description = "VM credentials"
  type = object(
    {
      username = string
      password = string
    }
  )
  sensitive = true
}

variable "catalyst_8000v_credentials" {
  description = "Catalyst 8000v credentials"
  type = object(
    {
      username = string
      password = string
    }
  )
  sensitive = true
}

variable "vmx_primary_token" {
  description = "Authentication token for vMX primary"
  type        = string
}

variable "vmx_secondary_token" {
  description = "Authentication token for vMX secondary"
  type        = string
}

# 8. miscellaneous:
variable "tags" {
  description = "Tags for resources"
  type        = map(string)
  default = {
    Creator    = "jsterben"
    Management = "Terraform"
    Purpose    = "AzureValidatedDesigns"
  }
}

variable "location" {
  description = "Deployment location"
  type        = string
  default     = "centralus"
}