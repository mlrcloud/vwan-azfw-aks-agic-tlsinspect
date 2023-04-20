
param hubInfo object 
param firewallName string
param destinations array
param securityResourceGroupName string
    

resource hub 'Microsoft.Network/virtualHubs@2021-02-01' existing = {
  name: hubInfo.name
}

resource firewall 'Microsoft.Network/azureFirewalls@2020-06-01' existing = {
  name: firewallName
  scope: resourceGroup(securityResourceGroupName)
}

resource hubNoneRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2021-02-01' = {
  name: 'noneRouteTable'
  parent: hub
  properties: {
    labels: [ 
      'none' 
    ]
    routes: []
  }
}

resource hubDefaultRouteTable 'Microsoft.Network/virtualHubs/hubRouteTables@2021-02-01' = {
  name: 'defaultRouteTable'
  parent: hub
  properties: {
    labels: [ 
      'default' 
    ]
    routes: [
      {
        destinations: destinations
        destinationType: 'CIDR'
        name: 'all_traffic'
        nextHop: firewall.id
        nextHopType: 'ResourceId'
      }
    ]
  }
}

