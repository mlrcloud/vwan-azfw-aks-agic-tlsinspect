// Global Parameters
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param snetsInfo array
param privateDnsZonesInfo array
param centrilazedResolverDns bool
param dnsResolverInboundEndpointIp string

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
