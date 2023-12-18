# Purpose

This project compiles terraform files which deploy validated designs for Cisco cloud services in the Azure 
public cloud. It is a work in progress but our aim is to cover the following:

- Recommended Azure networking architectures (e.g. hub and spoke VNET design)
- Cisco Meraki and Cisco Catalyst SDWAN integration
- Security and Routing with Cisco Secure Firewall and/or Catalyst 8000v
- Popular use-cases combining Cisco cloud services

# How to Use this?

## The More Scalable, Future-Proof, Secured Way

Not going to sugarcoat it, if you want to leverage this approach it will take significantly more time to get 
everything set up, that is just the way it is. You will have to do the heavy lifting once though, 
once there any future additions to this project (or modifications of your own) would be easily deployed. With
that said, what do you need to get this started?:

 1. [Install Terraform in your computer](https://developer.hashicorp.com/terraform/install)
 2. [Clone this repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)
 3. Access to an Azure Tenant:  
  
    - If you do not have one, [you can create one for free](https://azure.microsoft.com/en-us/get-started/)  
    - Make sure you have Azure AD (Entra ID called nowdays) with at least [User Administrator Role](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference#user-administrator)  
    - Make sure there is a Subscription in place, you should have [Owner Role](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview) on it  
  
 4. Access to a Terraform cloud tenant:  

    - If you do not have one, [you can create one for free](https://www.hashicorp.com/products/terraform?ajs_aid=fd28c575-128f-4af1-ad25-7648fffb38f2&product_intent=terraform)
    - Create a [Workspace](https://developer.hashicorp.com/terraform/cloud-docs/workspaces) on it

 5. Access to a Cisco Meraki organization:  

    - If you do not have one, [you can create one for free](https://documentation.meraki.com/General_Administration/Organizations_and_Networks/Creating_a_Dashboard_Account_and_Organization)
    - We recommend having at least two vMX licences (small, medium, or large), particularly to deploy HA designs. If
        you do not, contact your Meraki sales team to get a [free trial](https://documentation.meraki.com/Getting_Started_with_Meraki/Getting_Started_Resources/Meraki_Free_Trials)
    - We aso recommend having at some [physical Meraki MXs](https://meraki.cisco.com/product-collateral/mx-sizing-guide/?file) to test Meraki SDWAN/AutoVPN into Azure, you can get them 
        via free trials as indicated above

 5. Set up [dynamic credentials authentication](https://developer.hashicorp.com/terraform/enterprise/workspaces/dynamic-provider-credentials/azure-configuration) for your Terraform runs against Azure
 6. With your favorite IDE tool (e.g. Pycharm, VSCode), open repository and: 

    - Navigate to [./terraform_projects](./terraform_projects) and select the one you want to deploy
    - Edit variables.tf if you need different naming for your deployment
    - Provide all the necessary sensitive variables in secret.tfvars, the vMX authentication tokens can be 
      gathered as indicated [here](https://documentation.meraki.com/MX/MX_Installation_Guides/vMX_Setup_Guide_for_Microsoft_Azure#Meraki_Dashboard_Configuration)
    - Change first "cloud" block in main.tf file to point towards your terraform cloud tenant + 
        workspace, e.g.:
```
  cloud {  
    organization = "MyTerraformCloudOrganizationName"  
    workspaces {  
      name = "MyWorkspaceName"  
    }  
  }
```
  8. Using your favorite shell, navigate to the cloned repository, then go to infrastructure folder you want
      to deploy under [./terraform_projects](./terraform_projects)
  9. Perform [terraform init, login, plan, apply, destroy, etc. operations](https://developer.hashicorp.com/terraform/cli/run)
  10. As you run different Terraform projects (from this repository or others), you can add more workspaces 
      as indicated in step 4. and [modifying a bit the Azure Entra ID Application](https://developer.hashicorp.com/terraform/enterprise/workspaces/dynamic-provider-credentials/azure-configuration#configure-azure-active-directory-application-to-trust-a-generic-issuer)

## The Quick, Easier-to-Test Way

This process basically simplifies things by avoiding setting up Terraform cloud altogether, and the ensuing
Service Principal/Managed Application in Azure (along with the dynamic credentials). Terraform state file 
lives locally in the computer used to manage cloud infrastructure, there is no GUI-based visibility on 
terraform runs, and authentication to Azure happens via enviroment variables created when logging in via Azure 
CLI. 

Gets you to play faster with Terraform, and being totally transparent this is the way I started interacting 
with Terraform when manipulating Cisco + Azure infrastructure, but should be scoped to just learning/testing.
Production infrastructure automated by Terraform should rely on Terraform Cloud or similar offering.

With that considered, this interaction entails:

1. [Install Terraform in your computer](https://developer.hashicorp.com/terraform/install)
2. [Clone this repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository)
3. Access to an Azure Tenant:  

   - If you do not have one, [you can create one for free](https://azure.microsoft.com/en-us/get-started/)
   - Make sure there is a Subscription in place, you should have [Owner Role](https://learn.microsoft.com/en-us/azure/role-based-access-control/overview) on it

4. [Install Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
5. Access to a Cisco Meraki organization:

   - If you do not have one, [you can create one for free](https://documentation.meraki.com/General_Administration/Organizations_and_Networks/Creating_a_Dashboard_Account_and_Organization)
   - We recommend having at least two vMX licences (small, medium, or large), particularly to deploy HA designs. If
       you do not, contact your Meraki sales team to get a [free trial](https://documentation.meraki.com/Getting_Started_with_Meraki/Getting_Started_Resources/Meraki_Free_Trials)
   - We aso recommend having at some [physical Meraki MXs](https://meraki.cisco.com/product-collateral/mx-sizing-guide/?file) to test Meraki SDWAN/AutoVPN into Azure, you can get them 
       via free trials as indicated above

6. With your favorite IDE tool (e.g. Pycharm, VSCode), open repository and: 

    - Navigate to [./terraform_projects](./terraform_projects) and select the one you want to deploy
    - Edit variables.tf if you need different naming for your deployment
    - Provide all the necessary sensitive variables in secret.tfvars, the vMX authentication tokens can be 
      gathered as indicated [here](https://documentation.meraki.com/MX/MX_Installation_Guides/vMX_Setup_Guide_for_Microsoft_Azure#Meraki_Dashboard_Configuration)
    - Delete or comment out first "cloud" block in main.tf file:
```
# cloud {  
#  organization = "MyTerraformCloudOrganizationName"  
#    workspaces {
#      name = "MyWorkspaceName"  
#    }  
#  } 
```

7. Using your favorite shell, navigate to the cloned repository, then go to infrastructure folder you want
      to deploy under [./terraform_projects](./terraform_projects)
8. [Login to your Azure tenant via Azure CLI](https://learn.microsoft.com/en-us/cli/azure/authenticate-azure-cli-interactively)
9. Perform [terraform init, login, plan, apply, destroy, etc. operations](https://developer.hashicorp.com/terraform/cli/run)

# Validated Designs

At this time, the automated validated designs published here are:

1. Advanced BGP Manipulation:

   - Topology at [./documentation/advanced_bgp_manipulation_topologies.svg](./documentation/advanced_bgp_manipulation_topologies.svg)
   - Hub and spoke VNET design, all networking services reside in hub VNET
   - Leverages Catalyst 8000v to perform BGP summarization and physical Meraki MX hub routes 
       prioritization (AS path pre-prending on secondary vMX hub for physical hub routes)
   - Dynamically advertises routes between Azure and Meraki SDWAN fabric

2. High-Availability Meraki vMX SDWAN with Catalyst 8000v:

    - Topology at [./documentation/high_availability_meraki_sdwan_and_catalyst_8000v_topologies.pdf](./documentation/high_availability_meraki_sdwan_and_catalyst_8000v_topologies.pdf)
    - Hub and spoke VNET design, main routing and security services reside in hub VNET, SDWAN services are
        placed in segregated VNET
    - High-Availability is accomplished via [Availability Zones](https://learn.microsoft.com/en-us/azure/reliability/availability-zones-overview?tabs=azure-cli)
    - Catalyst 8000vs handle all Azure routing, NATing, and security
    - Dynamically advertises routes between Azure and Meraki SDWAN fabric

# Terraform Coding Approaches

Generally speaking, there is no one perfect way to code something. There are solutions more elegant than 
others but quite often you will find pros and cons on different techniques. When it comes to coding our 
Terraform files, we will follow 3 approaches:

1. Make variables.tf file readable:

    - That is, code them in a way that are easy to understand and that model the stuff you will end up
        deploying (e.g. a Subnet is an element within VNET dictionary)
    - This is what was adopted in design #2
    - Pros: 

        - Variables files are easy to understand and model infrastrucutre
        - You input a certain element only once

    - Cons:

        - Terraform configuration language does not precisely align to variable models
        - Particularly in situations where iteration makes sense (i.e. deploy multiple VNETs, VMs, etc), 
            getting to a place where you can instruct Terraform to perform it requires heavy modifications
        - Requires intermediary locals block to convert variables dictionaries into something Terraform
            can iterate on, adding complexity to main.tf file

2. Make main.tf file readable:

    - Avoid adding stuff in main configuration file, whenever possible only code resources block with 
        for_each iterations if applicable
    - This is what was adopted in design #1
    - Polar opposite of #1 approach
    - Pros:

        - main.tf file has only the necessary extra Terraform language (anything beyond resource blocks) 
            to deploy infrastructure, making it quite readable

    - Cons:

        - To accomplish this, you will need to complicate variables.tf file, not only by making longer 
            dictionaries, but also by adding the same element (i.e. Workloads1 VNET) multiple times in 
            different variables
        - Someone customizing variables.tf file will need to make sure to input same element in different
            places

3. Replace variables.tf file by YAML equivalent:

    - Do away with variables.tf by replacing it with YAML file
    - This will be imported via into locals via [yamldecode function](https://developer.hashicorp.com/terraform/language/functions/yamldecode)
    - Pros:

        - Makes it easier to mix automation tooling, all being fed the same input (Ansible, Terraform, 
            python)
        - YAML is easier to read than variables.td dictionaries
        - You can hide Terraform operations and interact with a simpler tool, like a python CLI utility
        - This will be adopted for a future design

    - Cons:

        - Requires a lot more coding to get it to work
        - Proficiency in multiple automation tools
        - Needs extra caution on when the YAML input file is modified

# Roadmap

Stuff we are working on and will be published here once completed:

1. Add more automation files for validated designs, we are scoping the following:

    - Getting started with Meraki vMX and Azure networking
    - Meraki vMX SDWAN with Cisco Secure Firewall for routing, NATing and security 
        (single-arm and HA options)
    - Multi-region HA options (leveragin L2 tunnels with Catalyst 8000v and Azure vWAN services)
    - Cisco Secure Firewall true-HA, leveraging its powerful clustering feature with Azure Gateway Load 
        Balancer

2. Easier consumption of this repository:

    - We get it, learning a new tool like Terraform is not easy, and you may not have the time
    - We are working on building a python CLI wrapper for all this, basically you will tell python how to
        authenticate with relevant components (Azure, Meraki, etc), what validated design you want to 
        deploy, and it will handle the rest

3. Better documentation:

    - Will be creating videos showcasing different ways to consume this repository
    - Topologies will be standardized to .svg format

# Author

Juan Sterbenc  
Solutions Engineer  
Cisco Systems  .:||:..:||:.  
jsterbenc@cisco.com | jisterbenc@gmail.com

# Shout-outs

[John Shea](https://github.com/johshea)  
Guided me through different ways of inputting variables elegantly into Terraform main file

# License

GPL-3.0-or-later, see [./COPYING.txt](./COPYING.txt) for more details