
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

module aksClusterResources '../modules/Microsoft.ContainerService/managedClusters.bicep' = {
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


