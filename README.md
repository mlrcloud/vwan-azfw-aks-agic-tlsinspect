# Fast Deploy: Hub-spoke network topology with Azure Virtual WAN, Azure Firewall and DNS Private Resolver

This repository contains an Azure Bicep template to simplify the deployment of a Hub and Spoke topology using Azure Virtual WAN secured with Azure Firewall in test or demo scenarios. It also includes Azure DNS Private Resolver as DNS for hybrid domain resolution. This template may be used by other scenarios as their networking infrastructure and be built on top of it (i.e. [Fast Deploy: Azure Virtual Desktop](https://github.com/mlrcloud/avd-fast-deploy)).

The following diagrams show a detailed architecture of each of the logical resources created by this template. You also can use Bicep Visualizer from Visual Studio Code bicep extension to get a relationship diagram between deployed logical resources. Relevant resources for the specific scenario covered in this repository are deployed into the following resource groups:

- **rg-hub**: resources associated with Azure vWAN.
![rg-hub resources](/doc/images/visualizer/rg-hub.png)
- **rg-security**: resources associated with Azure Firewall integrated with Azure vWAN.
![rg-security resources](/doc/images/visualizer/rg-security.png)
- **rg-monitor**: a storage account and a Log Analytics Workspace to store the diagnostics information.
![rg-monitor resources](/doc/images/visualizer/rg-monitor.png)
- **rg-bastion**: a bastion to access different workloads deployed in spokes.
![rg-bastion resources](/doc/images/visualizer/rg-bastion.png)
- **rg-shared**: resources associated with a spoke that hosts the common services used by other workloads. For example: Private DNS Resolver, Key Vault for secrets and certicates, etc.
![rg-shared resources](/doc/images/visualizer/rg-shared.png)
- **rg-spoke**: an example spoke to show the deployment of an application with consumption of a Private Endpoint.
![rg-spoke resources](/doc/images/visualizer/rg-spoke.png)

The following resource groups are associated with other scenarios using this template as a reference for their networking requirements:

- **rg-avd**: network configuration for provisioning Azure Virtual Desktop with different usage scenarios.

![rg-avd resources](/doc/images/visualizer/rg-avd.png)

For more information on how to deploy these scenarios, see [Fast Deploy: Azure Virtual Desktop](https://github.com/mlrcloud/avd-fast-deploy).

The following diagram shows a detailed architecture of the networking topology resources created by this template. 

![Global Nerwork Topology](/doc/images/networking/global-network-topology.png)

Note that we are using Azure vWAN Routing Intent and Routing Policies. This way Private Traffic Routing Policy is configured on the Virtual WAN Hub, so all branch-to-branch, branch-to-virtual network, virtual network-to-branch and inter-hub traffic will be sent via Azure Firewall deployed in the Virtual WAN Hub. Internet Traffic Routing Policy is also configured on our Virtual WAN hub, so all branch (User VPN (Point-to-site VPN), Site-to-site VPN, and ExpressRoute) and Virtual Network connections to that Virtual WAN Hub will forward Internet-bound traffic to the Azure Firewall resource, except for Azure Bastion vNet because this configuration would break Internet connectivity and the control plane, so we will select “Remove Internet Traffic Security” for this connection. 

![Detailed Nerwork Topology](/doc/images/networking/detailed-network-topology.png)

The following picture shows the configuration of each connection from Azure Firewall Manager:

![Coonections configuration](/doc/images/vwan-config/az-fw-manager-config.png)

## Repository structure

This repository is organized in the following folders:

- **base**: folder containing Bicep file that deploy the environment. It deploys *avd*, *bastion*,*monitoring*, *shared*, *spokes* and *vhub* resources mentioned above.

![base resources](/doc/images/repo-structure/base.png)

- **doc**: contains documents and images related to this scenario.
- **modules**: Bicep modules that integrates the different resources used by the base scripts.
- **utils**: extra files required to deploy this scenario.

## Pre-requisites

Bicep is the language used for defining declaratively the Azure resources required in this template. You would need to configure your development environment with Bicep support to successfully deploy this scenario.

- [Installing Bicep with Azure CLI](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-cli)
- [Installing Bicep with Azure PowerShell](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/install#azure-powershell)

As alternative, you can use [Azure Shell with PowerShell](https://ms.portal.azure.com/#cloudshell/) that already includes support for Bicep.

After validating Bicep installation, you would need to configure the Azure subscription where the resources would be deployed. You need to make sure that you have at least enough quota for creating:

- 1 vWAN Hub
- 1 Azure Firewall Premium
- 2 Standard_DS2_V2 Virtual Machines
- 2 Storage Account
- 1 Log Analytics Workspace
- 10 Private DNS Zones

[Check resource usage against limits](https://docs.microsoft.com/en-us/azure/networking/check-usage-against-limits#azure-portal) Azure documentation article to understand how you can review your actual usage through Azure Portal.

## How to deploy

1. Customize the parameters.default.json file to adapt the default values to your specific environment. Some resources like storage accounts required a unique name across all Azure subscriptions. If you use the default name, the deployment may fail because another user has already deploy this template. We recommend to change the following parameters:
    - *monitoringOptions.diagnosticsStorageAccountName* to avoid name collision with an existing storage account.
    - *privateEndpoints.spokeStorageAccount.name* to avoid name collision with an existing storage account.
2. Execute `./deploy.PowerShell.ps1` or `./deploy.CLI.ps1` script based on the current command line Azure tools available in your computer. If you use the PowerShell option, the verbose mode would allow you to see the status of the deployment in real time.
    - If you receive an error about your Execution Policy, please change it using [Set-ExecutionPolicy -ExecutionPolicy RemoteSigned](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.security/set-executionpolicy?view=powershell-7.2)
3. Wait around 40-50 minutes. Deploying the vWAN Hub and Firewall takes time.

## Parameters

*The default parameter file contains all the possible options available in this environment. We recommend to adjust only the values of the parameters described here.*

- *location*
  - "type": "string",
  - "description": "Allows to configure the Azure region where the resources should be deployed. Only tested at this time on North Europe and West Europe."

- *resourceGroupNames*
  - "type": "string",
  - "description": "Allows to configure the specific resource group where the resources associated to that service would be deployed. You can define the same resource group name for all resources in a test environment to simplify management and deletion after finishing with the evaluation."

- *deployLogAnalyticsWorkspace*
  - "type": "bool",
  - "description": "If an existing Log Analytics Workspace should be used you need to configure this parameter to true."

- *existingLogWorkspaceName*
  - "type": "string",
  - "description": "If the previous parameter is configured to true, you need to specific the Log Analytics Workspace name here."
  
- *sharedVnetInfo.centralizedResolverDns*
  - "type": "bool",
  - "description": "If a centralized-approach for DNS resolution is required, that is, DNS settings will be set to use Azure DNS Private Resolver Inbound IP, you need to configure this parameter to true. Otherwise, vNet DNS settings will be set as "Default" and Forwarding Ruleset will be linked to each vNet."

- *vmSpoke1.adminUsername*
  - "type": "string",
  - "description": "User name of the local admin configured for the virtual machine deployed on the application spoke."

## Known Issues

- **I'm not able to delete my vWAN and Azure Firewall resources. I get an error**

This template deploys Azure Firewall and vWAN in different resource groups. In this configuration, if you try to delete the resource groups containing these resources an error is triggered. While this specific issue is fixed, the only way to clean everything is stopping the firewall with the following commands:
```
$firewall = Get-AzFirewall -Name "azfw" -ResourceGroupName "rg-security"
$firewall.Deallocate()
$firewall | Set-AzFirewall
```
After that, you would be able to delete the resources without any error.

