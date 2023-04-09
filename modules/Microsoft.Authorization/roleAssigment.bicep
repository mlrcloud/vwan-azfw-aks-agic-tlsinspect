

param name string 
param principalId string
param roleDefinitionId string
param scope string



// az ad sp show --id 26da2792-4d23-4313-b9e7-60bd7c1bf0b1 to get principalId
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: name
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: roleDefinitionId
    scope: scope
  }
}
