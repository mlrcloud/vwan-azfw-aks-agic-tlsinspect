
param location string = resourceGroup().location
param tags object
param name string 


resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

output workspaceName string = logWorkspace.name
output workspaceId string = logWorkspace.id
