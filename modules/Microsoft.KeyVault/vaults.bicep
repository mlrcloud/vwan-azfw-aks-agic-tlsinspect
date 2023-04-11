

param location string = resourceGroup().location
param tags object
param name string
//param accessPolicies object TOREVIEW: probably we don't need this
param enabledForDeployment bool
param enabledForDiskEncryption bool
param enabledForTemplateDeployment bool
param enableRbacAuthorization bool
param enableSoftDelete bool
param networkAcls object
param publicNetworkAccess string
param sku string
param softDeleteRetentionInDays int
/*
var tenantId = { 
  tenantId: tenant().tenantId 
}
*/ //TOREVIEW: probably we don't need this

resource vaults 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    accessPolicies: []//array(union(accessPolicies, tenantId)) TOREVIEW: probably we don't need this
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
