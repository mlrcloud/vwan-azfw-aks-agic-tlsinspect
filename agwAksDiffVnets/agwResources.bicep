
// Global Parameters
param location string = resourceGroup().location
param tags object
param agwIdentityName string
param keyVaultName string
param websiteCertificateName string
@secure()
param websiteCertificateValue string


module agwIdentityResources '../modules/Microsoft.Authorization/userAssignedIdentity.bicep' = {
  name: 'agwIdentityRss_Deploy'
  params: {
    name: agwIdentityName
    location: location
    tags: tags
  }
}

module websiteCerificateResources '../modules/Microsoft.KeyVault/certificate.bicep' = {
  name: 'websiteCertificateResources_Deploy'
  params: {
    tags: tags
    name: websiteCertificateName
    keyVaulName: keyVaultName
    certificateValue: websiteCertificateValue
  }
}

