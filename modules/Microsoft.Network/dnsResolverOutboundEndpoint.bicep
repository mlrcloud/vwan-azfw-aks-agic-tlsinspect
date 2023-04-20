
param location string = resourceGroup().location
param tags object
param dnsResolverName string
param name string
param resolverVnetName string
param outboundEndpointSubnetName string

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: resolverVnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: outboundEndpointSubnetName
  parent: vnet
}

resource dnsResolver 'Microsoft.Network/dnsResolvers@2022-07-01' existing = {
  name: dnsResolverName
}

resource dnsResolverOutboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' = {
  name: name
  parent: dnsResolver
  location: location
  tags: tags
  properties: {
    subnet: {
      id: subnet.id
    }
  }
}



