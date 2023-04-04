
param location string = resourceGroup().location
param tags object
param name string



resource publicIp 'Microsoft.Network/publicIPAddresses@2020-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    publicIPAllocationMethod: 'Static'
    ipTags: []
  }
}
