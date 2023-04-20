
param location string = resourceGroup().location
param tags object
param name string


resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: name
  location: location
  tags: tags
}
