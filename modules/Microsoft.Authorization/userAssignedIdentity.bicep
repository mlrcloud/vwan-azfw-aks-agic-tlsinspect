
param location string = resourceGroup().location
param tags object
param name string 


resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: name
  location: location
  tags: tags
}

output principalId string = identity.properties.principalId
output clientId string = identity.properties.clientId
output identityId string = identity.id
