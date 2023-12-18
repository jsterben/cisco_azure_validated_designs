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
    main_resource_group_name                    = string
    catalyst_8000_v_primary_resource_group_name = string
  })
  default = {
    main_resource_group_name                    = "MainResourceGroup"
    catalyst_8000_v_primary_resource_group_name = "Catalyst8000vPrimaryResourceGroup"
  }
}

# 2. vnets, their subnets and peerings:
#   2.1. vnets:
variable "vnets" {
  description = "VNET specifications"
  type = object({
    hub = object({
      name          = string
      address_space = list(string)
    })
    workloads_0 = object({
      name          = string
      address_space = list(string)
    })
    workloads_1 = object({
      name          = string
      address_space = list(string)
    })
  })
  default = {
    hub = {
      name          = "HubVNET"
      address_space = ["10.2.0.0/16"]
    }
    workloads_0 = {
      name          = "Workloads0VNET"
      address_space = ["10.0.0.0/16"]
    }
    workloads_1 = {
      name          = "Workloads1VNET"
      address_space = ["10.1.0.0/16"]
    }
  }
}

#   2.2. subnets under each vnet:
variable "subnets" {
  description = "VNET Subnets specifications"
  type = object({
    hub_vnet_subnet_0 = object({
      name                 = string
      address_prefixes     = list(string)
      virtual_network_name = string
    })
    hub_vnet_subnet_1 = object({
      name                 = string
      address_prefixes     = list(string)
      virtual_network_name = string
    })
    hub_vnet_subnet_2 = object({
      name                 = string
      address_prefixes     = list(string)
      virtual_network_name = string
    })
    hub_vnet_route_server_subnet = object({
      name                 = string
      address_prefixes     = list(string)
      virtual_network_name = string
    })
    workloads_0_vnet_subnet_0 = object({
      name                 = string
      address_prefixes     = list(string)
      virtual_network_name = string
    })
    workloads_1_vnet_subnet_0 = object({
      name                 = string
      address_prefixes     = list(string)
      virtual_network_name = string
    })
    workloads_1_vnet_subnet_1 = object({
      name                 = string
      address_prefixes     = list(string)
      virtual_network_name = string
    })
  })
  default = {
    hub_vnet_subnet_0 = {
      name                 = "Subnet0"
      address_prefixes     = ["10.2.0.0/24"]
      virtual_network_name = "HubVNET"
    }
    hub_vnet_subnet_1 = {
      name                 = "Subnet1"
      address_prefixes     = ["10.2.1.0/24"]
      virtual_network_name = "HubVNET"
    }
    hub_vnet_subnet_2 = {
      name                 = "Subnet2"
      address_prefixes     = ["10.2.2.0/24"]
      virtual_network_name = "HubVNET"
    }
    hub_vnet_route_server_subnet = {
      name                 = "RouteServerSubnet"
      address_prefixes     = ["10.2.255.0/24"]
      virtual_network_name = "HubVNET"
    }
    workloads_0_vnet_subnet_0 = {
      name                 = "Subnet0"
      address_prefixes     = ["10.0.0.0/24"]
      virtual_network_name = "Workloads0VNET"
    }
    workloads_1_vnet_subnet_0 = {
      name                 = "Subnet0"
      address_prefixes     = ["10.1.0.0/24"]
      virtual_network_name = "Workloads1VNET"
    }
    workloads_1_vnet_subnet_1 = {
      name                 = "Subnet1"
      address_prefixes     = ["10.1.1.0/24"]
      virtual_network_name = "Workloads1VNET"
    }
  }
}

#   2.3. vnet peerings:
variable "vnet_peerings" {
  description = "VNET Peerings specifications"
  type = list(object({
    name                         = string
    virtual_network_name         = string
    remote_virtual_network_name  = string
    allow_virtual_network_access = bool
    allow_forwarded_traffic      = bool
    allow_gateway_transit        = bool
    use_remote_gateways          = bool
  }))
  default = [
    {
      name                         = "HubToWorkloads0VNETPeering"
      virtual_network_name         = "HubVNET"
      remote_virtual_network_name  = "Workloads0VNET"
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = true
      use_remote_gateways          = false
    },
    {
      name                         = "HubToWorkloads1VNETPeering"
      virtual_network_name         = "HubVNET"
      remote_virtual_network_name  = "Workloads1VNET"
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = true
      use_remote_gateways          = false
    },
    {
      name                         = "Workloads0ToHubVNETPeering"
      virtual_network_name         = "Workloads0VNET"
      remote_virtual_network_name  = "HubVNET"
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = false
      use_remote_gateways          = true
    },
    {
      name                         = "Workloads1ToHubVNETPeering"
      virtual_network_name         = "Workloads1VNET"
      remote_virtual_network_name  = "HubVNET"
      allow_virtual_network_access = true
      allow_forwarded_traffic      = true
      allow_gateway_transit        = false
      use_remote_gateways          = true
    }
  ]
}

# 3. vms:
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
      nic_name    = string # these 3 fields will need to change if multiple nics are to be deployed on a vm
      vnet_name   = string
      subnet_name = string
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
    vnet_name            = "Workloads0VNET"
    subnet_name          = "Subnet0"
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
      nic_name    = string # these 3 fields will need to change if multiple nics are to be deployed on a vm
      vnet_name   = string
      subnet_name = string
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
    vnet_name            = "Workloads1VNET"
    subnet_name          = "Subnet0"
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
      nic_name    = string # these 3 fields will need to change if multiple nics are to be deployed on a vm
      vnet_name   = string
      subnet_name = string
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
    vnet_name            = "Workloads1VNET"
    subnet_name          = "Subnet1"
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
      nic_name    = string # these 3 fields will need to change if multiple nics are to be deployed on a vm
      vnet_name   = string
      subnet_name = string
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
    vnet_name            = "Workloads1VNET"
    subnet_name          = "Subnet1"
    data_disk = {
      name = "DataDisk0VM3"
      size = "32"
    }
  }
}

# 4. vmxs:
#   4.1. vmx primary:
variable "vmx_primary" {
  description = "vMX primary specifications"
  type = object(
    {
      name = string
      zone = string
    }
  )
  default = {
    name = "VMXPrimary"
    zone = "1"
  }
}

#    4.2. vmx secondary:
variable "vmx_secondary" {
  description = "vMX secondary specifications"
  type = object(
    {
      name = string
      zone = string
    }
  )
  default = {
    name = "VMXSecondary"
    zone = "2"
  }
}

# 5. catalyst 8000v primary:
variable "catalyst_8000v_primary" {
  description = "Catalyst 8000v primary specifications"
  type = object({
    name              = string
    zone              = string
    domain_name_label = string
    vnet_name         = string
    subnet_name       = string
    nsg_rules = list(object({
      name                       = string
      description                = string
      protocol                   = string
      source_port_range          = string
      destination_port_range     = string
      source_address_prefix      = string
      destination_address_prefix = string
      access                     = string
      priority                   = number
      direction                  = string
    }))
    ios_xe_version = string
  })
  default = {
    name              = "Catalyst8000vPrimary"
    zone              = "1"
    domain_name_label = "catalyst-8000-v-primary"
    vnet_name         = "HubVNET"
    subnet_name       = "Subnet2"
    nsg_rules = [
      {
        name                       = "CatalystToSSHInitiator"
        description                = "Allows SSH responses from catalyst router to client initiating the connection"
        protocol                   = "Tcp"
        source_port_range          = "22"
        destination_port_range     = "*"
        source_address_prefix      = "10.2.2.4"
        destination_address_prefix = "207.229.178.140" # this is the ssh initiator ip
        access                     = "Allow"
        priority                   = 100
        direction                  = "Outbound"
      },
      {
        name                       = "CatalystToInternet"
        description                = "Denies any internet communication from catalyst router"
        protocol                   = "*"
        source_port_range          = "*"
        destination_port_range     = "*"
        source_address_prefix      = "10.2.2.4"
        destination_address_prefix = "Internet"
        access                     = "Deny"
        priority                   = 110
        direction                  = "Outbound"
      },
      {
        name                       = "SSHToCatalyst"
        description                = "Allows SSH sessions from initiator client to catalyst router"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "207.229.178.140" # this is the ssh initiator ip
        destination_address_prefix = "10.2.2.4"
        access                     = "Allow"
        priority                   = 100
        direction                  = "Inbound"
      }
    ]
    ios_xe_version = "17_12_01a"
  }
}

# 6. route server:
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
    name             = "RouteServer0"
    meraki_bgp_asn   = "64601"
    catalyst_bgp_asn = "64602"
  }
}

# x. sensitive:
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

# x. miscellaneous:
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
