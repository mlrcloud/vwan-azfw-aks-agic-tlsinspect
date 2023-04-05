


param name string
param keyVaultName string
param objectId string
param permissions object



resource vaults 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName  
}

resource accessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  name: name
  parent: vaults
  properties: {
    accessPolicies: [
      {
        objectId: objectId
        permissions: permissions
        tenantId: tenant().tenantId
      }
    ]
  }
}
