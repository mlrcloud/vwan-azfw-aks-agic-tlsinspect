
// Global Parameters
param location string = resourceGroup().location
param tags object
param agwIdentityName string
param keyVaultName string
param websiteCertificateName string
@secure()
param websiteCertificateValue string
param mngmntResourceGroupName string
param agwIdentityKeyVaultAccessPolicyName string
param wafPolicyName string
param agwPipName string
param agwName string
param vnetInfo object
param snetsInfo array
param privateIpAddress string
param backendPoolName string
param fqdnBackendPool string
param fwRootCACertificateName string
param websiteDomain string
param capacity int
param autoScaleMaxCapacity int


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
  scope: resourceGroup(mngmntResourceGroupName)
  params: {
    tags: tags
    name: websiteCertificateName
    keyVaulName: keyVaultName
    certificateValue: websiteCertificateValue
  }
}

module agwIdentityKeyVaultAccessPolicy '../modules/Microsoft.KeyVault/accessPolicies.bicep' = {
  name: 'agwIdentityKeyVaultAccessPolicyResources_Deploy'
  scope: resourceGroup(mngmntResourceGroupName)
  params: {
    name: agwIdentityKeyVaultAccessPolicyName
    keyVaultName: keyVaultName
    objectId: agwIdentityResources.outputs.principalId
    permissions: {
      certificates: [
        'list'
        'get'
      ]
      secrets: [
        'backup'
        'delete'
        'get'
        'list'
        'recover'
        'restore'
        'set'
      ]
    }
  }
  dependsOn: [
    agwIdentityResources
  ]
}

module wafPolicyResources '../modules/Microsoft.Network/applicationGatewayWebApplicationFirewallPolicies.bicep' = {
  name: 'wafPolicyResources_Deploy'
  params: {
    name: wafPolicyName
    location: location
    tags: tags
  }
}

module agwPipResources '../modules/Microsoft.Network/publicIp.bicep' = {
  name: 'agwPipResources_Deploy'
  params: {
    name: agwPipName
    location: location
    tags: tags
  }
}

module appgwResources '../modules/Microsoft.Network/applicationGateways.bicep' = {
  name: 'appgwResources_Deploy'
  params: {
    name: agwName
    location: location
    tags: tags
    vnetName: vnetInfo.name
    snetName: snetsInfo[0].name
    agwPipName: agwPipName
    privateIpAddress: privateIpAddress
    backendPoolName: backendPoolName
    fqdnBackendPool: fqdnBackendPool
    wafPolicyName: wafPolicyName
    agwIdentityName: agwIdentityName
    mngmntResourceGroupName: mngmntResourceGroupName
    keyVaulName: keyVaultName
    websiteCertificateName: websiteCertificateName
    fwRootCACertificateName: fwRootCACertificateName
    websiteDomain: websiteDomain
    capacity: capacity
    autoScaleMaxCapacity: autoScaleMaxCapacity
  }
  dependsOn: [
    agwIdentityResources
    websiteCerificateResources
    wafPolicyResources
    agwPipResources
  ]
}
