
param location string = resourceGroup().location
param tags object
param hubInfo object 
param vwanId string


resource hub 'Microsoft.Network/virtualHubs@2021-02-01' = {
  name: hubInfo.name
  location: location
  tags: tags
  properties: {
    addressPrefix: hubInfo.range
    allowBranchToBranchTraffic: false 
    virtualWan: {
      id: vwanId
    }
  }
}

