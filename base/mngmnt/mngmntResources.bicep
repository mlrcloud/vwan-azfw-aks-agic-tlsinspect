
// TODO: verify the required parameters

// Global Parameters
param customScriptName string
param spnClientId string
@secure()
param spnClientSecret string
param templateBaseUrl string
param aksResourceGroupName string
param dnsPrivateZoneResourceGroupName string
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param snetsInfo array
param nicName string
param centrilazedResolverDns bool
param dnsResolverInboundEndpointIp string
param dnsForwardingRulesetsName string
param sharedResourceGroupName string
param vmName string
param vmSize string
@secure()
param vmAdminUsername string
@secure()
param vmAdminPassword string
param privateDnsZonesName string
param aksName string
param certName string
param keyVaultName string
param keyVaultAccessPolicies object
param keyVaultEnabledForDeployment bool
param keyVaultEnabledForDiskEncryption bool
param keyVaultEnabledForTemplateDeployment bool
param keyVaultEnableRbacAuthorization bool
param keyVaultEnableSoftDelete bool
param keyVaultNetworkAcls object
param keyVaultPublicNetworkAccess string
param keyVaultSku string
param keyVaultSoftDeleteRetentionInDays int
param keyVaultPrivateEndpointName string
param keyVaultPrivateDnsZoneName string
param downloadFile string
param fqdnBackendPool string
var keyVaultNameResourceGroupName = resourceGroup().name


module vnetResources '../../modules/Microsoft.Network/vnet.bicep' = {
  name: 'vnetResources_Deploy'
  params: {
    location: location
    tags: tags
    vnetInfo: vnetInfo
    snetsInfo: snetsInfo
    centrilazedResolverDns: centrilazedResolverDns
    dnsResolverInboundEndpointIp: dnsResolverInboundEndpointIp
  }
}

module rulesetsVnetLinks '../../modules/Microsoft.Network/dnsForwardingRulesetsVnetLink.bicep' = if (!centrilazedResolverDns) {
  name: 'mngmntRulesetsVnetLinksResources_Deploy'
  scope: resourceGroup(sharedResourceGroupName)
  dependsOn: [
    vnetResources
  ]
  params: {
    name: '${dnsForwardingRulesetsName}-mngmnt'
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    vnetName: vnetInfo.name
    vnetResourceGroupName: resourceGroup().name
  }
}

module nicResources '../../modules/Microsoft.Network/nic.bicep' = {
  name: 'nicResources_Deploy'
  dependsOn: [
    vnetResources
  ]
  params: {
    tags: tags
    name: nicName
    location: location
    vnetName: vnetInfo.name
    vnetResourceGroupName: resourceGroup().name
    snetName: snetsInfo[0].name
    nsgName: ''
  }
}

module vmResources '../../modules/Microsoft.Compute/vm.bicep' = {
  name: 'vmResources_Deploy'
  dependsOn: [
    nicResources
  ]
  params: {
    tags: tags
    name: vmName
    location: location
    vmSize: vmSize
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    nicName: nicName
  }
}

module vmCustomScript '../../modules/Microsoft.Compute/customScript.bicep' = {
  name: 'customScriptResources_Deploy'
  dependsOn: [
    vmResources
  ]
  params: {
    downloadFile: downloadFile
    vmName: vmName
    name: customScriptName
    location: location
    templateBaseUrl: templateBaseUrl
    commandToExecute: 'bash download.sh ${vmAdminUsername} ${spnClientId} ${spnClientSecret} ${tenant().tenantId} ${aksResourceGroupName} ${location} ${privateDnsZonesName} ${aksName} ${keyVaultName} ${certName} ${dnsPrivateZoneResourceGroupName} ${templateBaseUrl} ${keyVaultNameResourceGroupName} ${fqdnBackendPool}'
  }
}

module keyVaultResources '../../modules/Microsoft.KeyVault/vaults.bicep' = {
  name: 'keyVaultResources_Deploy'
  params: {
    location: location
    tags: tags
    name: keyVaultName
    accessPolicies: keyVaultAccessPolicies
    enabledForDeployment: keyVaultEnabledForDeployment
    enabledForDiskEncryption: keyVaultEnabledForDiskEncryption
    enabledForTemplateDeployment: keyVaultEnabledForTemplateDeployment
    enableRbacAuthorization: keyVaultEnableRbacAuthorization
    enableSoftDelete: keyVaultEnableSoftDelete
    networkAcls: keyVaultNetworkAcls
    publicNetworkAccess: keyVaultPublicNetworkAccess
    sku: keyVaultSku
    softDeleteRetentionInDays: keyVaultSoftDeleteRetentionInDays
  }
  dependsOn: [
    vnetResources
  ]
}

module keyVaultPrivateEndpointResources '../../modules/Microsoft.Network/keyVaultPrivateEndpoint.bicep' = [for i in range(0, length(snetsInfo)): if (snetsInfo[i].name == 'snet-plinks') {
  name: 'keyVaultPrivateEndpointResources_Deploy${i}'
  dependsOn: [
    vnetResources
    keyVaultResources
  ]
  params: {
    location: location
    tags: tags
    name: keyVaultPrivateEndpointName
    vnetName: vnetInfo.name
    snetName: snetsInfo[i].name
    keyVaultName: keyVaultName
    privateDnsZoneName: keyVaultPrivateDnsZoneName
    groupIds: 'vault'
    sharedResourceGroupName: sharedResourceGroupName
  }
}]
