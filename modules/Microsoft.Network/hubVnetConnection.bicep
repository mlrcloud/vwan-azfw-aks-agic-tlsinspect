

param hubInfo object
param connectInfo object
param enableInternetSecurity bool

resource remoteVnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: connectInfo.remoteVnetName
  scope: resourceGroup(connectInfo.resourceGroup)
}

resource hub 'Microsoft.Network/virtualHubs@2021-02-01' existing = {
  name: hubInfo.name
}

resource hubDefaultRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2021-02-01' existing = {
  name: 'defaultRouteTable'
  parent: hub
}

resource hubNoneRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2021-02-01' existing = {
  name: 'noneRouteTable'
  parent: hub
}

resource hubVnetConnection 'Microsoft.Network/virtualHubs/hubVirtualNetworkConnections@2021-02-01' = {
  name: connectInfo.name
  parent: hub
  properties: {
    allowHubToRemoteVnetTransit: true
    allowRemoteVnetToUseHubVnetGateways: true
    enableInternetSecurity: enableInternetSecurity
    remoteVirtualNetwork: {
      id: remoteVnet.id
    }
    routingConfiguration: {
      associatedRouteTable: {
        id: hubDefaultRouteTable.id
      }
      propagatedRouteTables: {
        ids: [
          {
            id: hubNoneRouteTable.id
          }
        ]
        labels: [ 
          'none' 
        ]
      }
    }
  }
}

