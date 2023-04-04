
param location string = resourceGroup().location
param tags object
param dnsResolverName string
param name string
param resolverVnetName string
param inboundEndpointSubnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: resolverVnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: inboundEndpointSubnetName
  parent: vnet
}

resource dnsResolver 'Microsoft.Network/dnsResolvers@2022-07-01' existing = {
  name: dnsResolverName
}

resource dnsResolverInboundEndpoint 'Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01' = {
  name: name
  parent: dnsResolver
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        subnet: {
          id: subnet.id
        }
      }
    ]
  }
}


