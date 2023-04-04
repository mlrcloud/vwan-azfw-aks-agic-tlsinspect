
// TODO: verify the required parameters

// Global Parameters
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param snetsInfo array
param centrilazedResolverDns bool
param dnsResolverInboundEndpointIp string
param dnsForwardingRulesetsName string
param sharedResourceGroupName string

module vnetResources '../../modules/Microsoft.Network/vnet.bicep' = {
  name: 'vnetResources_Deploy'
  params: {
    location: location
    tags: tags
    vnetInfo: vnetInfo
    snetsInfo: snetsInfo
    centrilazedResolverDns: centrilazedResolverDns
    dnsResolverInboundEndpointIp: dnsResolverInboundEndpointIp
  }
}

module rulesetsVnetLinks '../../modules/Microsoft.Network/dnsForwardingRulesetsVnetLink.bicep' = {
  name: 'avdRulesetsVnetLinksResources_Deploy'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    vnetResources
  ]
  params: {
    name: '${dnsForwardingRulesetsName}-avd'
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    vnetName: vnetInfo.name
    vnetResourceGroupName: resourceGroup().name
  }
}


