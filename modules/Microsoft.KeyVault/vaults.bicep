

param location string = resourceGroup().location
param tags object
param name string
param accessPolicies object
param enabledForDeployment bool
param enabledForDiskEncryption bool
param enabledForTemplateDeployment bool
param enableRbacAuthorization bool
param enableSoftDelete bool
param networkAcls object
param publicNetworkAccess string
param sku string
param softDeleteRetentionInDays int

var tenantId = { 
  tenantId: tenant().tenantId 
}

resource vaults 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    accessPolicies: array(union(accessPolicies, tenantId))
    enabledForDeployment: enabledForDeployment
    enabledForDiskEncryption: enabledForDiskEncryption
    enabledForTemplateDeployment: enabledForTemplateDeployment
    enableRbacAuthorization: enableRbacAuthorization
    enableSoftDelete: enableSoftDelete
    networkAcls: networkAcls
    publicNetworkAccess: publicNetworkAccess
    sku: {
      name: sku
      family: 'A'
    }
    softDeleteRetentionInDays: softDeleteRetentionInDays
    tenantId: tenant().tenantId
  }
}
