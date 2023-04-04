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
var agwAksResourceGroupName = resourceGroupNames.agwAks
var securityResourceGroupName = resourceGroupNames.security


// Monitoring resources
@description('Monitoring options')
param monitoringOptions object

var deployLogWorkspace = monitoringOptions.deployLogAnalyticsWorkspace
var existingLogWorkspaceName = monitoringOptions.existingLogAnalyticsWorkspaceName


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
    name: 'manuelpablo.com'
    vnetLinkName: 'vnet-link-manuelpablo-to-'
    vnetName: sharedVnetInfo.name
  }//Required by Azure Firewall to determine the Web Application’s IP address as HTTP headers usually do not contain IP addresses. 
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
    name: 'toManuelPablo'
    domain: 'manuelpablo.com.'
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers:  []
  }
]


// Agw and AKS resources

@description('Name and range for Agw and AKS vNet')
param agwAksVnetInfo object 

var agwAksSnetsInfo = agwAksVnetInfo.subnets
var centrilazedResolverDnsOnAgwAksVnet = agwAksVnetInfo.centrilazedResolverDns


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
    name: 'agwaksconn'
    remoteVnetName: agwAksVnetInfo.name
    resourceGroup: resourceGroupNames.agwAks
    enableInternetSecurity: true
  }
]

var privateTrafficPrefix = [
  '172.16.0.0/12' 
  '192.168.0.0/16'
  '${sharedVnetInfo.range}'
  '${agwAksVnetInfo.range}'
]


/* 
  Monitoring resources deployment 
*/
// Checked

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: monitoringResourceGroupName
  location: location
}

module monitoringResources '../base/monitoring/monitoringResources.bicep' = {
  scope: monitoringResourceGroup
  name: 'monitoringResources_Deploy'
  params: {
    location:location
    env: env
    tags: tags
    deployLogWorkspace: deployLogWorkspace
    existingLogWorkspaceName: existingLogWorkspaceName
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

module sharedResources '../base/shared/sharedResources.bicep' = {
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
  Agw and AKS resources
*/
//Checked

resource agwAksResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: agwAksResourceGroupName
  location: location
}

module agwAksResources 'agwAksResources.bicep' = {
  scope: agwAksResourceGroup
  name: 'agwAksResources_Deploy'
  dependsOn: [
    sharedResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: agwAksVnetInfo 
    snetsInfo: agwAksSnetsInfo 
    centrilazedResolverDns: centrilazedResolverDnsOnAgwAksVnet
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

module vhubResources '../base/vhub/vhubResources.bicep' = {
  scope: hubResourceGroup
  name: 'vhubResources_Deploy'
  dependsOn: [
    securityResourceGroup
    sharedResources
    agwAksResources
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

