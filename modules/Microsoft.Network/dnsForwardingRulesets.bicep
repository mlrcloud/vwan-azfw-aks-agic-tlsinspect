
param location string = resourceGroup().location
param tags object
param dnsResolverName string
param name string
param outboundEndpointName string

resource dnsResolver 'Microsoft.Network/dnsResolvers@2022-07-01' existing = {
  name: dnsResolverName
}

resource dnsResolverOutboundEndpoint 'Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01' existing = {
  name: outboundEndpointName
  parent: dnsResolver
}

resource dnsForwardingRulesets 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    dnsResolverOutboundEndpoints: [
      {
        id: dnsResolverOutboundEndpoint.id
      }
    ]
  }
}



