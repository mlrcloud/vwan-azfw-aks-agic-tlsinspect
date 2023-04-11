
// Global Parameters
param location string = resourceGroup().location
param tags object
param vnetInfo object 
param snetsInfo array
param aksName string
param aksDnsPrefix string
param kubernetesVersion string
param aksNetworkPlugin string
param aksEnableRBAC bool
param aksNodeResourceGroupName string
param aksDisableLocalAccounts bool
param aksEnablePrivateCluster bool
param aksEnableAzurePolicy bool
param aksEnableSecretStoreCSIDriver bool
param aksServiceCidr string
param aksDnsServiceIp string
param aksUpgradeChannel string
param mngmntResourceGroupName string
param websiteCertificateName string
param keyVaultName string
@secure()
param websiteCertificateValue string
param spnClientId string
@secure()
param spnClientSecret string
@secure()
param websiteCertificatePassword string

module aksCluster '../modules/Microsoft.ContainerService/managedClusters.bicep' = {
  name: 'aksClusterResources_Deploy'
  params: {
    location: location
    tags: tags
    name: aksName
    dnsPrefix: aksDnsPrefix
    kubernetesVersion: kubernetesVersion
    networkPlugin: aksNetworkPlugin
    enableRBAC: aksEnableRBAC 
    nodeResourceGroup: aksNodeResourceGroupName
    disableLocalAccounts: aksDisableLocalAccounts 
    enablePrivateCluster: aksEnablePrivateCluster
    enableAzurePolicy: aksEnableAzurePolicy
    enableSecretStoreCSIDriver: aksEnableSecretStoreCSIDriver
    vnetName: vnetInfo.name
    snetName: snetsInfo[0].name
    serviceCidr: aksServiceCidr
    dnsServiceIp: aksDnsServiceIp
    upgradeChannel: aksUpgradeChannel
  }
}

var aksSnetRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/4d97b98b-1d4f-4787-a291-c67834d212e7'
var aksSnetRoleAssigmentName = guid('${vnetInfo.name}/${snetsInfo[0].name}/Microsoft.Authorization/','4d97b98b-1d4f-4787-a291-c67834d212e7', aksCluster.outputs.clusterPrincipalId)

module aksSnetRoleAssignmentResources '../modules/Microsoft.Authorization/aksRoleAssigment.bicep' = {
  name: 'aksSnetRoleAssignmentResources_Deploy'
  params: {
    name: aksSnetRoleAssigmentName
    roleDefinitionId: aksSnetRoleDefinitionId
    principalId: aksCluster.outputs.clusterPrincipalId
    vnetName: vnetInfo.name
    snetName: snetsInfo[0].name
  }
  dependsOn: [
    aksCluster
  ]
}

/*
module websiteCertificateResources '../modules/Microsoft.KeyVault/certificate.bicep' = {
  name: 'websiteCertificateResources_Deploy'
  scope: resourceGroup(mngmntResourceGroupName)
  params: {
    tags: tags
    name: websiteCertificateName
    keyVaulName: keyVaultName
    certificateValue: websiteCertificateValue
  }
}
*/

module websiteCertificateResources '../modules/Microsoft.Resources/deploymentScript.bicep' = {
  name: 'websiteCertificateResources_Deploy'
  scope: resourceGroup(mngmntResourceGroupName)
  params: {
    location: location
    tags: tags
    name: websiteCertificateName
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    keyVaulName: keyVaultName
    certificateValue: websiteCertificateValue
    password: websiteCertificatePassword
  }
}

