// Global Parameters
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param snetsInfo array
param dnsResolverName string
param dnsResolverInboundEndpointName string
param dnsResolverOutboundEndpointName string
param privateDnsZonesInfo array
param centrilazedResolverDns bool
param dnsResolverInboundEndpointIp string
param dnsForwardingRulesetsName string
param dnsForwardingRules array

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

module dnsResolverResources '../../modules/Microsoft.Network/dnsResolver.bicep' = {
  name: 'dnsResolverResources_Deploy'
  params: {
    location: location
    tags: tags
    name: dnsResolverName
    vnetName: vnetInfo.name   
  }
}

module dnsResolverInboundEndpointsResources '../../modules/Microsoft.Network/dnsResolverInboundEndpoint.bicep' = {
  name: 'dnsResolverInboundEndpointsRss_Deploy'
  dependsOn: [
    dnsResolverResources
  ]
  params: {
    location: location
    tags: tags
    name: dnsResolverInboundEndpointName 
    dnsResolverName: dnsResolverName
    resolverVnetName: vnetInfo.name
    inboundEndpointSubnetName: vnetInfo.subnets[0].name
  }
}

module dnsResolverOutboundEndpointsResources '../../modules/Microsoft.Network/dnsResolverOutboundEndpoint.bicep' = {
  name: 'dnsResolverOutboundEndpointsRss_Deploy'
  dependsOn: [
    dnsResolverResources
  ]
  params: {
    location: location
    tags: tags
    name: dnsResolverOutboundEndpointName 
    dnsResolverName: dnsResolverName
    resolverVnetName: vnetInfo.name
    outboundEndpointSubnetName: vnetInfo.subnets[1].name
  }
}

module dnsForwardingRulesetsResources '../../modules/Microsoft.Network/dnsForwardingRulesets.bicep' = {
  name: 'dnsForwardingRulesetsRss_Deploy'
  dependsOn: [
    dnsResolverOutboundEndpointsResources
  ]
  params: {
    location: location
    tags: tags
    name: dnsForwardingRulesetsName 
    dnsResolverName: dnsResolverName
    outboundEndpointName: dnsResolverOutboundEndpointName
  }
}

module dnsForwardingRulesResources '../../modules/Microsoft.Network/dnsForwardingRules.bicep' = [ for (rule, i) in dnsForwardingRules : {
  name: 'dnsForwardingRulesRss_Deploy${i}'
  dependsOn: [
    dnsForwardingRulesetsResources
  ]
  params: {
    name: rule.name
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    domainName: rule.domain
    forwardingRuleState: rule.state
    targetDnsServers: rule.dnsServers
    dnsResolverInboundEndpointIp: dnsResolverInboundEndpointIp
  }
}]

module privateDnsZones '../../modules/Microsoft.Network/privateDnsZone.bicep' = [ for (privateDnsZoneInfo, i) in privateDnsZonesInfo : {
  name: 'privateDnsZonesResources_Deploy${i}'
  dependsOn: [
    vnetResources
  ]
  params: {
    location: 'global'
    tags: tags
    name: privateDnsZoneInfo.name
  }
}]

module vnetLinks '../../modules/Microsoft.Network/vnetLink.bicep' = [ for (privateDnsZoneInfo, i) in privateDnsZonesInfo : {
  name: 'sharedVnetLinksResources_Deploy${i}'
  dependsOn: [
    vnetResources
    privateDnsZones
  ]
  params: {
    tags: tags
    name: '${privateDnsZoneInfo.vnetLinkName}shared'
    vnetName: vnetInfo.name
    privateDnsZoneName: privateDnsZoneInfo.name
    vnetResourceGroupName: resourceGroup().name
  }
}]
