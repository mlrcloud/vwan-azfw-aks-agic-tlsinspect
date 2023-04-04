
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param centrilazedResolverDns bool
param snetsInfo array
param dnsResolverInboundEndpointIp string


resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: vnetInfo.name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetInfo.range
      ]
    }
    dhcpOptions: {
      dnsServers: (centrilazedResolverDns) ? [
        dnsResolverInboundEndpointIp
        '168.63.129.16'
      ] : json('null')
    }
    subnets: [ for snetInfo in snetsInfo : {
      name: '${snetInfo.name}'
      properties: {
        addressPrefix: '${snetInfo.range}'
        delegations: empty(snetInfo.delegations) ? json('null') : [
          {
            name: snetInfo.delegations
            properties: {
              serviceName: snetInfo.delegations
            }
          }
        ]
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Disabled'
      }
    }]
  }
}
