
param location string = resourceGroup().location
param tags object
param name string
param privateIPAddress string
param vnetName string
param snetName string
param keyVaultName string
param privateDnsZoneName string
param groupIds string
param sharedResourceGroupName string


resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
}

resource snet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: snetName
  parent: vnet
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: privateDnsZoneName
  scope: resourceGroup(sharedResourceGroupName)
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig'
        properties: {
          groupId: groupIds
          memberName: 'default'
          privateIPAddress: privateIPAddress
        }
      }
    ]
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          groupIds: [ 
            groupIds 
          ]
          privateLinkServiceId: keyVault.id
        }
      }
    ]
    subnet: {
      id: snet.id
    }
  }
}

resource privateDnsZoneGroups 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-02-01' = {
  name: format('{0}/{1}', name, '${groupIds}PrivateDnsZoneGroup')
  dependsOn: [
    privateEndpoint
  ]
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'dnsConfig'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}
