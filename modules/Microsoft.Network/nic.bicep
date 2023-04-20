
param location string = resourceGroup().location
param tags object
param name string 
param snetName string
param nsgName string
param vnetName string
param vnetResourceGroupName string


resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetResourceGroupName)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: snetName
  parent: vnet
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = if (!empty(nsgName)) {
  name: nsgName
}

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnet.id
          }
          primary: true
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    networkSecurityGroup: (!empty(nsgName)) ? {
      id: nsg.id 
    }: json('null')
  }
}

