
// TODO: verify the required parameters

// Global Parameters
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param snetsInfo array
param nicName string
param centrilazedResolverDns bool
param dnsResolverInboundEndpointIp string
param dnsForwardingRulesetsName string
param sharedResourceGroupName string
param vmName string
param vmSize string
@secure()
param vmAdminUsername string
@secure()
param vmAdminPassword string


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

module rulesetsVnetLinks '../../modules/Microsoft.Network/dnsForwardingRulesetsVnetLink.bicep' = if (!centrilazedResolverDns) {
  name: 'spokeRulesetsVnetLinksResources_Deploy'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    vnetResources
  ]
  params: {
    name: '${dnsForwardingRulesetsName}-spoke'
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    vnetName: vnetInfo.name
    vnetResourceGroupName: resourceGroup().name
  }
}

module nicResources '../../modules/Microsoft.Network/nic.bicep' = {
  name: 'nicResources_Deploy'
  dependsOn: [
    vnetResources
  ]
  params: {
    tags: tags
    name: nicName
    location: location
    vnetName: vnetInfo.name
    vnetResourceGroupName: resourceGroup().name
    snetName: snetsInfo[0].name
    nsgName: ''
  }
}

module vmResources '../../modules/Microsoft.Compute/vm.bicep' = {
  name: 'vmResources_Deploy'
  dependsOn: [
    nicResources
  ]
  params: {
    tags: tags
    name: vmName
    location: location
    vmSize: vmSize
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    nicName: nicName
  }
}
