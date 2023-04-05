


param tags object
param name string
param keyVaulName string
param certificateValue string


resource vaults 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaulName
}

resource secrets 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: name
  tags: tags
  parent: vaults
  properties: {
    contentType: 'application/x-pkcs12'
    value: certificateValue
  }
}
