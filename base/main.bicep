targetScope = 'subscription'

// Global Parameters

@description('Azure region where resource would be deployed')
param location string

@description('Environment')
param env string
@description('Tags associated with all resources')
param tags object 

// Resource Group Names

@description('Resource Groups names')
param resourceGroupNames object

var monitoringResourceGroupName = resourceGroupNames.monitoring
var hubResourceGroupName = resourceGroupNames.hub
var sharedResourceGroupName = resourceGroupNames.shared
var bastionResourceGroupName = resourceGroupNames.bastion
var spokeResourceGroupName = resourceGroupNames.spoke
var securityResourceGroupName = resourceGroupNames.security
var avdResourceGroupName = resourceGroupNames.avd


// Monitoring resources
@description('Monitoring options')
param monitoringOptions object

var deployLogWorkspace = monitoringOptions.deployLogAnalyticsWorkspace
var existingLogWorkspaceName = monitoringOptions.existingLogAnalyticsWorkspaceName
var diagnosticsStorageAccountName = monitoringOptions.diagnosticsStorageAccountName


// Shared resources

@description('Name and range for shared services vNet')
param sharedVnetInfo object 
param dnsResolverInfo object

var sharedSnetsInfo  = sharedVnetInfo.subnets
var centrilazedResolverDnsOnSharedVnet = sharedVnetInfo.centrilazedResolverDns
var dnsResolverName = dnsResolverInfo.name
var dnsResolverInboundEndpointName = dnsResolverInfo.inboundEndpointName
var dnsResolverInboundIp = dnsResolverInfo.inboundEndpointIp
var dnsResolverOutboundEndpointName = dnsResolverInfo.outboundEndpointName
var dnsForwardingRulesetsName = dnsResolverInfo.dnsForwardingRulesetsName

//Add in this section the private dns zones you need
var privateDnsZonesInfo = [
  {
    name: 'privatelink.azure-automation.net'
    vnetLinkName: 'vnet-link-automation-to-'
    vnetName: sharedVnetInfo.name
  }//Azure Automation / (Microsoft.Automation/automationAccounts) / Webhook, DSCAndHybridWorker
  {
    name: format('privatelink{0}', environment().suffixes.sqlServerHostname)
    vnetLinkName: 'vnet-link-sqldatabase-to-'
    vnetName: sharedVnetInfo.name
  } //Azure SQL Database (Microsoft.Sql/servers) / sqlServer
  {
    name: format('privatelink.blob.{0}', environment().suffixes.storage)
    vnetLinkName: 'vnet-link-blob-to-'
    vnetName: sharedVnetInfo.name
  }//Storage account (Microsoft.Storage/storageAccounts) / Blob (blob, blob_secondary)
  {
    name: format('privatelink.file.{0}', environment().suffixes.storage)
    vnetLinkName: 'vnet-link-file-to-'
    vnetName: sharedVnetInfo.name
  }//Storage account (Microsoft.Storage/storageAccounts) / File (file, file_secondary)
  {
    name: format('privatelink.table.{0}', environment().suffixes.storage)
    vnetLinkName: 'vnet-link-table-to-'
    vnetName: sharedVnetInfo.name
  }//Storage account (Microsoft.Storage/storageAccounts) / Table (table, table_secondary)
  {
    name: format('privatelink.queue.{0}', environment().suffixes.storage)
    vnetLinkName: 'vnet-link-queue-to-'
    vnetName: sharedVnetInfo.name
  }//Storage account (Microsoft.Storage/storageAccounts) / Queue (queue, queue_secondary)
  {
    name: format('privatelink.web.{0}', environment().suffixes.storage)
    vnetLinkName: 'vnet-link-web-to-'
    vnetName: sharedVnetInfo.name
  }//Storage account (Microsoft.Storage/storageAccounts) / Web (web, web_secondary)
  {
    name: format('privatelink.dfs.{0}', environment().suffixes.storage)
    vnetLinkName: 'vnet-link-dfs-to-'
    vnetName: sharedVnetInfo.name
  }//Azure Data Lake File System Gen2 (Microsoft.Storage/storageAccounts) / Data Lake File System Gen2 (dfs, dfs_secondary)
  {
    name: format('privatelink.wvd.microsoft.com')
    vnetLinkName: 'vnet-link-wvd-to-'
    vnetName: sharedVnetInfo.name
  }//Azure WVD
]

//Add in this section the dns forwarding rules you need 
var dnsForwardingRulesInfo = [
  {
    name: 'toOnpremise'
    domain: 'mydomain.local.'
    state: 'Enabled'
    dnsServers:  [
      {
          ipAddress: '1.1.1.1'
          port: 53
      }
      {
          ipAddress: '1.2.3.4'
          port: 53
      }
    ]
  }
  {
    name: 'toBlob'
    domain: format('privatelink.blob.{0}.', environment().suffixes.storage)
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers:  []
  }
  {
    name: 'toFile'
    domain: format('privatelink.file.{0}.', environment().suffixes.storage)
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers:  []
  }
  {
    name: 'toSql'
    domain: format('privatelink{0}.', environment().suffixes.sqlServerHostname)
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers:  []
  }
  {
    name: 'toWvd'
    domain: format('privatelink.wvd.microsoft.com.')
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers:  []
  }
]


// Bastion resources

@description('Name and range for bastion services vNet')
param bastionVnetInfo object 

var bastionSnetsInfo  = bastionVnetInfo.subnets
var centrilazedResolverDnsOnBastionVnet = bastionVnetInfo.centrilazedResolverDns


// Spoke resources

@description('Name and range for spoke services vNet')
param spokeVnetInfo object 

var spokeSnetsInfo = spokeVnetInfo.subnets
var centrilazedResolverDnsOnSpokeVnet = spokeVnetInfo.centrilazedResolverDns

@description('Spoke VM configuration details')
param vmSpoke object 

var vmSpokeName = vmSpoke.name
var vmSpokeSize = vmSpoke.sku
var spokeNicName  = vmSpoke.nicName
var vmSpokeAdminUsername = vmSpoke.adminUsername


@description('Admin password for Spoke vm')
@secure()
param vmSpokeAdminPassword string


param privateEndpoints object

var storageAccountName = privateEndpoints.spokeStorageAccount.name
var blobStorageAccountPrivateEndpointName  = privateEndpoints.spokeStorageAccount.privateEndpointName

// Hub resources

@description('Name for VWAN')
param vwanName string
@description('Name and range for Hub')
param hubVnetInfo object 

@description('Azure Firewall configuration parameters')
param firewallConfiguration object

var firewallName = firewallConfiguration.name

var fwPolicyInfo = firewallConfiguration.policy
var appRuleCollectionGroupName = firewallConfiguration.appCollectionRules.name
var appRulesInfo = firewallConfiguration.appCollectionRules.rulesInfo

var networkRuleCollectionGroupName = firewallConfiguration.networkCollectionRules.name
var networkRulesInfo = firewallConfiguration.networkCollectionRules.rulesInfo

var dnatRuleCollectionGroupName  = firewallConfiguration.dnatCollectionRules.name

// TODO If moved to parameters.json, self-reference to other parameters is not supported
@description('Name for hub virtual connections')
param hubVnetConnectionsInfo array = [
  {
    name: 'sharedconn'
    remoteVnetName: sharedVnetInfo.name
    resourceGroup: resourceGroupNames.shared
    enableInternetSecurity: true
  }
  {
    name: 'bastionconn'
    remoteVnetName: bastionVnetInfo.name
    resourceGroup: resourceGroupNames.bastion
    enableInternetSecurity: false
  }
  {
    name: 'avdconn'
    remoteVnetName: avdVnetInfo.name
    resourceGroup: resourceGroupNames.avd
    enableInternetSecurity: true
  }
  {
    name: 'spokeconn'
    remoteVnetName: spokeVnetInfo.name
    resourceGroup: resourceGroupNames.spoke
    enableInternetSecurity: true
  }
]

var privateTrafficPrefix = [
  '172.16.0.0/12' 
  '192.168.0.0/16'
  '${sharedVnetInfo.range}'
  '${bastionVnetInfo.range}'
  '${spokeVnetInfo.range}'
  '${avdVnetInfo.range}'
]


// Azure Virtual Desktop resources

@description('Name and range for avd vNet')
param avdVnetInfo object 
var avdSnetsInfo = avdVnetInfo.subnets

var centrilazedResolverDnsOnAvdVnet = avdVnetInfo.centrilazedResolverDns

// Bastion resources
@description('Name of Azure Bastion instance')
param bastionConfiguration object

var bastionName = bastionConfiguration.name
/* 
  Monitoring resources deployment 
*/
// Checked

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: monitoringResourceGroupName
  location: location
}

module monitoringResources 'monitoring/monitoringResources.bicep' = {
  scope: monitoringResourceGroup
  name: 'monitoringResources_Deploy'
  params: {
    location:location
    env: env
    tags: tags
    deployLogWorkspace: deployLogWorkspace
    existingLogWorkspaceName: existingLogWorkspaceName
    diagnosticsStorageAccountName: diagnosticsStorageAccountName
  }
}

/* 
  Shared resources deployment 
    - Private DNS Resolver
*/
// Checked

resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: sharedResourceGroupName
  location: location
}

module sharedResources 'shared/sharedResources.bicep' = {
  scope: sharedResourceGroup
  name: 'sharedResources_Deploy'
  dependsOn: [
    monitoringResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: sharedVnetInfo 
    snetsInfo: sharedSnetsInfo
    centrilazedResolverDns: centrilazedResolverDnsOnSharedVnet
    dnsResolverName: dnsResolverName
    dnsResolverInboundEndpointName: dnsResolverInboundEndpointName
    dnsResolverInboundEndpointIp: dnsResolverInboundIp
    dnsResolverOutboundEndpointName: dnsResolverOutboundEndpointName
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    dnsForwardingRules: dnsForwardingRulesInfo
    privateDnsZonesInfo: privateDnsZonesInfo 
  }
}

/* 
  Bastion resources deployment 
*/
// Checked

resource bastionResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: bastionResourceGroupName
  location: location
}

module bastionResources 'bastion/bastionResources.bicep' = {
  scope: bastionResourceGroup
  name: 'bastionHostResources_Deploy'
  dependsOn: [
    monitoringResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: bastionVnetInfo 
    snetsInfo: bastionSnetsInfo
    centrilazedResolverDns: centrilazedResolverDnsOnBastionVnet
    dnsResolverInboundEndpointIp: dnsResolverInboundIp
    bastionName: bastionName
  }
}

/*
  Spoke resources
*/
//Checked

resource spokeResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: spokeResourceGroupName
  location: location
}

module spokeResources 'spokes/spokeResources.bicep' = {
  scope: spokeResourceGroup
  name: 'spokeResources_Deploy'
  dependsOn: [
    sharedResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: spokeVnetInfo 
    snetsInfo: spokeSnetsInfo 
    nicName: spokeNicName
    centrilazedResolverDns: centrilazedResolverDnsOnSpokeVnet
    dnsResolverInboundEndpointIp: dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
    vmName: vmSpokeName
    vmSize: vmSpokeSize
    vmAdminUsername: vmSpokeAdminUsername
    vmAdminPassword: vmSpokeAdminPassword
    diagnosticsStorageAccountName: diagnosticsStorageAccountName
    logWorkspaceName: monitoringResources.outputs.logWorkspaceName
    monitoringResourceGroupName: monitoringResourceGroupName
    storageAccountName: storageAccountName
    blobStorageAccountPrivateEndpointName: blobStorageAccountPrivateEndpointName
    blobPrivateDnsZoneName: privateDnsZonesInfo[0].name
  }
}

/* 
  Azure Virtual Desktop Network resources
*/
// Checked

resource avdResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: avdResourceGroupName
  location: location
}

module avdResources 'avd/avdResources.bicep' = {
  scope: avdResourceGroup
  name: 'avdResources_Deploy'
  dependsOn: [
    sharedResources
    spokeResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: avdVnetInfo 
    snetsInfo: avdSnetsInfo
    centrilazedResolverDns: centrilazedResolverDnsOnAvdVnet
    dnsResolverInboundEndpointIp: dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
  }
}

/*
  Network connectivity and security
*/
// Checked

resource securityResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: securityResourceGroupName
  location: location
}

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: hubResourceGroupName
  location: location
}

module vhubResources 'vhub/vhubResources.bicep' = {
  scope: hubResourceGroup
  name: 'vhubResources_Deploy'
  dependsOn: [
    securityResourceGroup
    sharedResources
    avdResources
  ]
  params: {
    location:location
    tags: tags
    securityResourceGroupName: securityResourceGroupName
    vwanName: vwanName
    hubInfo: hubVnetInfo
    monitoringResourceGroupName: monitoringResourceGroupName
    logWorkspaceName: monitoringResources.outputs.logWorkspaceName
    hubResourceGroupName: hubResourceGroupName
    fwPolicyInfo: fwPolicyInfo
    appRuleCollectionGroupName: appRuleCollectionGroupName
    appRulesInfo: appRulesInfo
    networkRuleCollectionGroupName: networkRuleCollectionGroupName
    networkRulesInfo: networkRulesInfo 
    dnatRuleCollectionGroupName: dnatRuleCollectionGroupName
    firewallName:firewallName
    destinationAddresses: privateTrafficPrefix
    hubVnetConnectionsInfo: hubVnetConnectionsInfo
  }
}


/*
  Outputs
*/

output logWorkspaceName string = monitoringResources.outputs.logWorkspaceName

