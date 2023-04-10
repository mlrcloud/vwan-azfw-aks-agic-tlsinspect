param name string 
param principalId string
param roleDefinitionId string
param vnetName string
param snetName string

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: snetName
  parent: vnet
}

// az ad sp show --id 26da2792-4d23-4313-b9e7-60bd7c1bf0b1 to get principalId
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: name
  scope: subnet
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
  }
}
