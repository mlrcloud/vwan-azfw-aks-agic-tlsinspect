
// Global Parameters
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param snetsInfo array
param centrilazedResolverDns bool
param dnsResolverInboundEndpointIp string
param dnsForwardingRulesetsName string
param sharedResourceGroupName string


module routeTableResources '../modules/Microsoft.Network/routeTable.bicep' = [ for rt in snetsInfo: if (!empty(rt.routeTable)) {
  name: 'routeTableRssFor${rt.name}_Deploy'
  params: {
    location: location
    tags: tags
    name: rt.routeTable.name
    routes: rt.routeTable.routes
  }
}]

module vnetResources '../modules/Microsoft.Network/vnet.bicep' = {
  name: 'vnetResources_Deploy'
  params: {
    location: location
    tags: tags
    vnetInfo: vnetInfo
    snetsInfo: snetsInfo
    centrilazedResolverDns: centrilazedResolverDns
    dnsResolverInboundEndpointIp: dnsResolverInboundEndpointIp
  }
  dependsOn: [
    routeTableResources
  ]
}

module rulesetsVnetLinks '../modules/Microsoft.Network/dnsForwardingRulesetsVnetLink.bicep' = if (!centrilazedResolverDns) {
  name: 'rulesetsVnetLinksResources_Deploy'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    vnetResources
  ]
  params: {
    name: '${dnsForwardingRulesetsName}-agwSpoke'
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    vnetName: vnetInfo.name
    vnetResourceGroupName: resourceGroup().name
  }
}

