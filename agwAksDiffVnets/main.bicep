targetScope = 'subscription'

// Global Parameters

@description('Azure region where resource would be deployed')
param location string

@description('Environment')
param env string
@description('Tags associated with all resources')
param tags object 


var deploy = false
// Resource Group Names

@description('Resource Groups names')
param resourceGroupNames object

var monitoringResourceGroupName = resourceGroupNames.monitoring
var hubResourceGroupName = resourceGroupNames.hub
var sharedResourceGroupName = resourceGroupNames.shared
var agwResourceGroupName = resourceGroupNames.agw
var aksResourceGroupName = resourceGroupNames.aks
var securityResourceGroupName = resourceGroupNames.security
var mngmntResourceGroupName = resourceGroupNames.mngmnt


// Monitoring resources
@description('Monitoring options')
param monitoringOptions object

var deployLogWorkspace = monitoringOptions.deployLogAnalyticsWorkspace
var existingLogWorkspaceName = monitoringOptions.existingLogAnalyticsWorkspaceName


// Shared resources

@description('Name and range for shared services vNet')
param sharedVnetInfo object 
param dnsResolverInfo object

var sharedSnetsInfo  = sharedVnetInfo.subnets
var centrilazedResolverDnsOnSharedVnet = sharedVnetInfo.centrilazedResolverDns
var dnsResolverName = dnsResolverInfo.name
var dnsResolverInboundEndpointName = dnsResolverInfo.inboundEndpointName
var dnsResolverInboundIp = dnsResolverInfo.inboundEndpointIp
var dnsResolverOutboundEndpointName = dnsResolverInfo.outboundEndpointName
var dnsForwardingRulesetsName = dnsResolverInfo.dnsForwardingRulesetsName

//Add in this section the private dns zones you need
var privateDnsZonesInfo = [
  {
    name: 'manuelpablo.com'
    vnetLinkName: 'vnet-link-manuelpablo-to-'
    vnetName: sharedVnetInfo.name
  }//Required by Azure Firewall to determine the Web Application’s IP address as HTTP headers usually do not contain IP addresses. 
  {
    name: format('privatelink.vaultcore.azure.net')
    vnetLinkName: 'vnet-link-keyvault-to-'
    vnetName: sharedVnetInfo.name
  }//Azure Key Vault (Microsoft.KeyVault/vaults) / vault 
]

//Add in this section the dns forwarding rules you need 
var dnsForwardingRulesInfo = [
  {
    name: 'toOnpremise'
    domain: 'mydomain.local.'
    state: 'Enabled'
    dnsServers:  [
      {
          ipAddress: '1.1.1.1'
          port: 53
      }
      {
          ipAddress: '1.2.3.4'
          port: 53
      }
    ]
  }
  {
    name: 'toManuelPablo'
    domain: 'manuelpablo.com.'
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers: (enableDnsProxy) ? [
      {
        ipAddress: fwPrivateIp
        port: 53
      }
    ] : []
  }
  {
    name: 'toKeyvault'
    domain: 'privatelink.vaultcore.azure.net.'
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers: (enableDnsProxy) ? [
      {
        ipAddress: fwPrivateIp
        port: 53
      }
    ] : []
  }
]


// Agw and AKS resources

@description('Name and range for Agw vNet')
param agwVnetInfo object 

var agwSnetsInfo = agwVnetInfo.subnets
var centrilazedResolverDnsOnAgwVnet = agwVnetInfo.centrilazedResolverDns

@description('Name and range for AKS vNet')
param aksVnetInfo object 

var aksSnetsInfo = aksVnetInfo.subnets
var centrilazedResolverDnsOnAksVnet = aksVnetInfo.centrilazedResolverDns

// Mngmnt resources

@description('Name and range for mngmnt services vNet')
param mngmntVnetInfo object 

var mngmntSnetsInfo = mngmntVnetInfo.subnets
var centrilazedResolverDnsOnMngmntVnet = mngmntVnetInfo.centrilazedResolverDns

@description('Mngmnt VM configuration details')
param vmMngmnt object 

var vmMngmntName = vmMngmnt.name
var vmMngmntSize = vmMngmnt.sku
var mngmntNicName  = vmMngmnt.nicName
var vmMngmntAdminUsername = vmMngmnt.adminUsername


@description('Admin password for Mngmnt vm')
@secure()
param vmMngmntAdminPassword string


// Hub resources

@description('Name for VWAN')
param vwanName string
@description('Name and range for Hub')
param hubVnetInfo object 

@description('Azure Firewall configuration parameters')
param firewallConfiguration object

var firewallName = firewallConfiguration.name
var fwPrivateIp = firewallConfiguration.privateIp
var fwIdentityName = firewallConfiguration.identityName
var fwIdentityKeyVaultAccessPolicyName = firewallConfiguration.keyVaultAccessPolicyName
var fwInterCACertificateName = firewallConfiguration.interCACertificateName
@description('InterCA Certificate for AZ FW - Base64 encoded .PFX')
@secure()
param fwInterCACertificateValue string = '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'

var fwRootCACertificateName = firewallConfiguration.rootCACertificateName
@description('RootCA Certificate for AZ FW - Base64 encoded .PFX')
@secure()
param fwRootCACertificateValue string = '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'

//'LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tDQpNSUlGalRDQ0EzV2dBd0lCQWdJVWZaVHhLS1hpaExFL1Q0dTBCMnBOcXhWZ2FOa3dEUVlKS29aSWh2Y05BUUVMDQpCUUF3VGpFTE1Ba0dBMVVFQmhNQ1ZWTXhDekFKQmdOVkJBZ01BbFZUTVJRd0VnWURWUVFLREF0VFpXeG1JRk5wDQpaMjVsWkRFY01Cb0dBMVVFQXd3VFUyVnNaaUJUYVdkdVpXUWdVbTl2ZENCRFFUQWVGdzB5TXpBME1EVXhPRFEwDQpNREZhRncweU5qQXhNak14T0RRME1ERmFNRTR4Q3pBSkJnTlZCQVlUQWxWVE1Rc3dDUVlEVlFRSURBSlZVekVVDQpNQklHQTFVRUNnd0xVMlZzWmlCVGFXZHVaV1F4SERBYUJnTlZCQU1NRTFObGJHWWdVMmxuYm1Wa0lGSnZiM1FnDQpRMEV3Z2dJaU1BMEdDU3FHU0liM0RRRUJBUVVBQTRJQ0R3QXdnZ0lLQW9JQ0FRRFdGZUZvQ0lPNTNkQmNIUzlvDQpRdzJWMTNXK1pkU2V2NjBnV3c5YVM3SXljOUJTSmhiQUV3RUlPcDdHMjM4YW92eTJMeVNMcFVRZ0EwUWJpTkMxDQp6WEtvSnk0RFhacTVESjZPeHV2Z2FwbGlBTlduUlN6Zyt6Wm5yVXVnYlQraWx3anNCeXJIMGVEYlBGeVlRd28wDQpHRDB3SmQ0MCtYRzRtYkMrb0hNWW9Wa3V5Z3NuVTdZNDRIWEtBZktTMGJCUnhQa1dhZFVGdjNwZ0dvMzFVbFErDQpWVkZkT1UvQ2c2MVJrTmZxMm1JSnZtakw0N3IvYkdaUENwd3ZobW9tQ0FzWWNBcFlZY0ovOEZ2SVF2Sm5HaTFqDQpKYjY2RUswN3IrdFB2MWpuQWNoOEdaWkNJNUJmMERsMWdGVHdadjh6bC9uS3pXUmJwY0g5N2hjeDc2Zm40cytNDQpoWVVFMzBmREFVeWN0VEExQkxDNCtaeXF1bk9TQTB2UlJPc3pCMWdvVHVVNW9oN0Y1V2N4TXBuanRHQWVpTE5uDQpkY1hFbFcvajRiWWUwS3hMYVJxMjFBeVpYODRzU0FkVlJxZStVRVNOdWpxQXN1SjJQYWNwM1RNMlJzQ3V3enJKDQpJWFk1c2duQmxmMjY5NlU3Nnk5cnBUVHc1QjhMTC9HaVR2QUczRXVzQk1uNWhaMWViOS8vb21sc1JMTEI5SGE0DQpJeGVrODlzbk5wZkxobFJmVElEdWVUNUhQS21YTzFXSGw5bDZtSU0zVzRENGo4WjREVzRvNlhmTWRoR0hmb0xzDQpaeGpvbmFIL3RUb094RjF2M29UcWN3TVVZdjFoZ01RMkJQaWFDWXloN3owNW9NZExkajZiRExXN1llUGJPWGZJDQowbHp5YVZaU0hoa2poTGorK1NmbFVZYlZNUUlEQVFBQm8yTXdZVEFkQmdOVkhRNEVGZ1FVekYrNTZxL3hXS1YwDQo5Znk2T0t4RTNiakFSTzB3SHdZRFZSMGpCQmd3Rm9BVXpGKzU2cS94V0tWMDlmeTZPS3hFM2JqQVJPMHdEd1lEDQpWUjBUQVFIL0JBVXdBd0VCL3pBT0JnTlZIUThCQWY4RUJBTUNBWVl3RFFZSktvWklodmNOQVFFTEJRQURnZ0lCDQpBSENxazAwM3ZzSXh0WUxDRlZ2VWZxOWZXZFNsbEVtUWFPUGJIQ3R2b0VWMHI1cDdOMzJKN0tlT2dXRWpxa001DQpuOE82Q3k0L3hYa2dxOThKaFJheERlbDY2Z3VNZ21Yb1FMK0VmdnM2ZFZVUkVSYTdFbzJ0Qlk1ZEtybkRmSXFIDQpWRUNuRTBwcXdRZzBUa2lMbWFyT04wMmo3a0psakppWkovbnFwZDIrVlhBTDMySjFCOXhlMVptQ3EwZXJwK3R3DQpuaXB4TjBTdENETjhrQnRYMFB1NUlvSWpadGZnbW4zbXkySjVRK1JJYTJxUmZlakQ3elQyeHVYVk0zOEgvNVpoDQpHVTZ2Zi9KdW1sRHNid2FZTmJ2YVhoY0VmT1hUek83WWMyUXJtaHNQTU05RmNybFB5SVM5SVhFK2RuSHRod1hwDQp6Z0RVOEhJWEtpZ3o4TzErOFlMVks3UmlEcmF1am1DSW55MDgrZEZZRHZtU0hDY0xtZiswMk9qQUo1VTNiQ1ZODQpEOUoyV1R3RURlSEU4VmswZWdZNDJ3VmlTWWN2RWZqdExxT2x2MjZncXdCcTUzSktTTFhYSWlDTTBOcXk5VWVsDQpaWmZFdmhvbkVIZG8rUUJQZy9VM0RXSDMrZG1VcU84U1RDaUFBdlVxRXhMSDc4Vlo3aHhIbHN0U1g4RVNMUmhrDQpxeEowSnJzMFgxMGVtQWdoZ2xtc1dZNGN2cENNdkx1LzMrZ0U0d0h3RWhGZEZqYlloMlMrVDJ6UFB6TUZpWVVHDQo0SitHWGlUUjBleWFCaWtJZ2p1eHFCUFdqNVhISkFROWV3YVFOc2tNTytzclBxRTZaYnJvRVZVQTgwMDc5S3hXDQpuamtmRGdHWWlkanBMZk1BNlB2TDZibDg0MkVlK3FxOERHeFN3emhFbTJnQQ0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQ0K'

var fwPolicyInfo = firewallConfiguration.policy
var appRuleCollectionGroupName = firewallConfiguration.appCollectionRules.name
var appRulesInfo = firewallConfiguration.appCollectionRules.rulesInfo

var networkRuleCollectionGroupName = firewallConfiguration.networkCollectionRules.name
var networkRulesInfo = firewallConfiguration.networkCollectionRules.rulesInfo

var dnatRuleCollectionGroupName  = firewallConfiguration.dnatCollectionRules.name

var enableDnsProxy = firewallConfiguration.enableDnsProxy

// TODO If moved to parameters.json, self-reference to other parameters is not supported
@description('Name for hub virtual connections')
param hubVnetConnectionsInfo array = [
  {
    name: 'sharedconn'
    remoteVnetName: sharedVnetInfo.name
    resourceGroup: resourceGroupNames.shared
    enableInternetSecurity: true
  }
  {
    name: 'agwconn'
    remoteVnetName: agwVnetInfo.name
    resourceGroup: resourceGroupNames.agw
    enableInternetSecurity: true
  }
  {
    name: 'aksconn'
    remoteVnetName: aksVnetInfo.name
    resourceGroup: resourceGroupNames.aks
    enableInternetSecurity: true
  }
  {
    name: 'mngmntconn'
    remoteVnetName: mngmntVnetInfo.name
    resourceGroup: resourceGroupNames.mngmnt
    enableInternetSecurity: true
  }
]

var privateTrafficPrefix = [
  '172.16.0.0/12' 
  '192.168.0.0/16'
  '${sharedVnetInfo.range}'
  '${agwVnetInfo.range}'
  '${aksVnetInfo.range}'
  '${mngmntVnetInfo.range}'
]


/* 
  Monitoring resources deployment 
*/
// Checked

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: monitoringResourceGroupName
  location: location
}

module monitoringResources '../base/monitoring/monitoringResources.bicep' = if (deploy) {
  scope: monitoringResourceGroup
  name: 'monitoringResources_Deploy'
  params: {
    location:location
    env: env
    tags: tags
    deployLogWorkspace: deployLogWorkspace
    existingLogWorkspaceName: existingLogWorkspaceName
  }
}

/* 
  Shared resources deployment 
    - Private DNS Resolver
*/
// Checked

resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: sharedResourceGroupName
  location: location
}

module sharedResources '../base/shared/sharedResources.bicep' = if (deploy) {
  scope: sharedResourceGroup
  name: 'sharedResources_Deploy'
  dependsOn: [
    monitoringResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: sharedVnetInfo 
    snetsInfo: sharedSnetsInfo
    centrilazedResolverDns: centrilazedResolverDnsOnSharedVnet
    dnsResolverName: dnsResolverName
    dnsResolverInboundEndpointName: dnsResolverInboundEndpointName
    dnsResolverInboundEndpointIp: (enableDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsResolverOutboundEndpointName: dnsResolverOutboundEndpointName
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    dnsForwardingRules: dnsForwardingRulesInfo
    privateDnsZonesInfo: privateDnsZonesInfo 
  }
}

/*
  Agw spoke resources
*/

resource agwResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: agwResourceGroupName
  location: location
}

module agwSpokeResources 'agwSpokeResources.bicep' = if (deploy) {
  scope: agwResourceGroup
  name: 'agwSpokeResources_Deploy'
  dependsOn: [
    sharedResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: agwVnetInfo 
    snetsInfo: agwSnetsInfo 
    centrilazedResolverDns: centrilazedResolverDnsOnAgwVnet
    dnsResolverInboundEndpointIp: (enableDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
  }
}

/*
  AKS spoke resources
*/

resource aksResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: aksResourceGroupName
  location: location
}

module aksSpokeResources 'aksSpokeResources.bicep' = if (deploy) {
  scope: aksResourceGroup
  name: 'aksSpokeResources_Deploy'
  dependsOn: [
    sharedResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: aksVnetInfo 
    snetsInfo: aksSnetsInfo 
    centrilazedResolverDns: centrilazedResolverDnsOnAksVnet
    dnsResolverInboundEndpointIp: (enableDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
  }
}

/*
  Mngmnt resources
*/
//Checked

param keyVaultConfiguration object

var keyVaultName = keyVaultConfiguration.name
var keyVaultAccessPolicies = keyVaultConfiguration.accessPolicies
var keyVaultEnabledForDeployment = keyVaultConfiguration.enabledForDeployment
var keyVaultEnabledForDiskEncryption = keyVaultConfiguration.enabledForDiskEncryption 
var keyVaultEnabledForTemplateDeployment = keyVaultConfiguration.enabledForTemplateDeployment 
var keyVaultEnableRbacAuthorization = keyVaultConfiguration.enableRbacAuthorization 
var keyVaultEnableSoftDelete = keyVaultConfiguration.enableSoftDelete
var keyVaultNetworkAcls = keyVaultConfiguration.networkAcls 
var keyVaultPublicNetworkAccess = keyVaultConfiguration.publicNetworkAccess 
var keyVaultSku = keyVaultConfiguration.sku 
var keyVaultSoftDeleteRetentionInDays = keyVaultConfiguration.softDeleteRetentionInDays 
var keyVaultPrivateEndpointName = keyVaultConfiguration.privateEndpointName 

resource mngmntResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: mngmntResourceGroupName
  location: location
}

module mngmntResources '../base/mngmnt/mngmntResources.bicep' = if (deploy) {
  scope: mngmntResourceGroup
  name: 'mngmntResources_Deploy'
  dependsOn: [
    sharedResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: mngmntVnetInfo 
    snetsInfo: mngmntSnetsInfo 
    nicName: mngmntNicName
    centrilazedResolverDns: centrilazedResolverDnsOnMngmntVnet
    dnsResolverInboundEndpointIp: (enableDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
    vmName: vmMngmntName
    vmSize: vmMngmntSize
    vmAdminUsername: vmMngmntAdminUsername
    vmAdminPassword: vmMngmntAdminPassword
    keyVaultName: keyVaultName
    keyVaultAccessPolicies: keyVaultAccessPolicies
    keyVaultEnabledForDeployment: keyVaultEnabledForDeployment
    keyVaultEnabledForDiskEncryption: keyVaultEnabledForDiskEncryption
    keyVaultEnabledForTemplateDeployment: keyVaultEnabledForTemplateDeployment
    keyVaultEnableRbacAuthorization: keyVaultEnableRbacAuthorization
    keyVaultEnableSoftDelete: keyVaultEnableSoftDelete
    keyVaultNetworkAcls: keyVaultNetworkAcls
    keyVaultPublicNetworkAccess: keyVaultPublicNetworkAccess
    keyVaultSku: keyVaultSku
    keyVaultSoftDeleteRetentionInDays: keyVaultSoftDeleteRetentionInDays
    keyVaultPrivateDnsZoneName: privateDnsZonesInfo[1].name
    keyVaultPrivateEndpointName: keyVaultPrivateEndpointName
  }
}

/*
  Network connectivity and security
*/

resource securityResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: securityResourceGroupName
  location: location
}

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: hubResourceGroupName
  location: location
}

module vhubResources '../base/vhub/vhubResources.bicep' = if (deploy) {
  scope: hubResourceGroup
  name: 'vhubResources_Deploy'
  dependsOn: [
    securityResourceGroup
    sharedResources
    agwSpokeResources
    aksSpokeResources
    mngmntResources
  ]
  params: {
    location:location
    tags: tags
    securityResourceGroupName: securityResourceGroupName
    vwanName: vwanName
    hubInfo: hubVnetInfo
    monitoringResourceGroupName: monitoringResourceGroupName
    logWorkspaceName: monitoringResources.outputs.logWorkspaceName
    hubResourceGroupName: hubResourceGroupName
    mngmntResourceGroupName: mngmntResourceGroupName
    fwIdentityName: fwIdentityName
    fwIdentityKeyVaultAccessPolicyName: fwIdentityKeyVaultAccessPolicyName
    keyVaultName: keyVaultName
    fwInterCACertificateName: fwInterCACertificateName
    fwInterCACertificateValue: fwInterCACertificateValue
    fwRootCACertificateName: fwRootCACertificateName
    fwRootCACertificateValue: fwRootCACertificateValue
    fwPolicyInfo: fwPolicyInfo
    appRuleCollectionGroupName: appRuleCollectionGroupName
    appRulesInfo: appRulesInfo
    networkRuleCollectionGroupName: networkRuleCollectionGroupName
    networkRulesInfo: networkRulesInfo 
    dnatRuleCollectionGroupName: dnatRuleCollectionGroupName
    firewallName:firewallName
    destinationAddresses: privateTrafficPrefix
    hubVnetConnectionsInfo: hubVnetConnectionsInfo
    enableDnsProxy: enableDnsProxy
    dnsResolverInboundEndpointIp: dnsResolverInboundIp
  }
}

/*
  AKS resources
*/

var websiteCertificateName = aksConfiguration.websiteCertificateName
@description('website certificate - Base64 encoded PFX')
@secure()
param websiteCertificateValue string = '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'

param aksConfiguration object

var aksName = aksConfiguration.name
var aksDnsPrefix = aksConfiguration.dnsPrefix
var kubernetesVersion = aksConfiguration.kubernetesVersion
var aksNetworkPlugin = aksConfiguration.networkPlugin
var aksEnableRBAC = aksConfiguration.enableRBAC
var aksNodeResourceGroupName = aksConfiguration.nodeResourceGroupName
var aksDisableLocalAccounts = aksConfiguration.disableLocalAccounts
var aksEnablePrivateCluster = aksConfiguration.enablePrivateCluster
var aksEnableAzurePolicy = aksConfiguration.enableAzurePolicy
var aksEnableSecretStoreCSIDriver = aksConfiguration.enableSecretStoreCSIDriver
var aksServiceCidr = aksConfiguration.serviceCidr
var aksDnsServiceIp = aksConfiguration.dnsServiceIp
var aksUpgradeChannel = aksConfiguration.upgradeChannel


module aksResources 'aksResources.bicep' = {
  scope: aksResourceGroup
  name: 'aksResources_Deploy'
  dependsOn: [
    vhubResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: aksVnetInfo 
    snetsInfo: aksSnetsInfo
    aksName: aksName
    aksDnsPrefix: aksDnsPrefix
    kubernetesVersion: kubernetesVersion
    aksNetworkPlugin: aksNetworkPlugin
    aksEnableRBAC: aksEnableRBAC
    aksNodeResourceGroupName: aksNodeResourceGroupName
    aksDisableLocalAccounts: aksDisableLocalAccounts
    aksEnablePrivateCluster: aksEnablePrivateCluster
    aksEnableAzurePolicy: aksEnableAzurePolicy
    aksEnableSecretStoreCSIDriver: aksEnableSecretStoreCSIDriver
    aksServiceCidr: aksServiceCidr
    aksDnsServiceIp: aksDnsServiceIp
    aksUpgradeChannel: aksUpgradeChannel
    mngmntResourceGroupName: mngmntResourceGroupName
    keyVaultName: keyVaultName
    websiteCertificateName: websiteCertificateName
    websiteCertificateValue: websiteCertificateValue
  }
}

/*
  Agw resources
*/

param agwConfiguration object

var agwIdentityName = agwConfiguration.identityName
var agwIdentityKeyVaultAccessPolicyName = agwConfiguration.keyVaultAccessPolicyName
var wafPolicyName = agwConfiguration.wafPolicyName
var agwPipName = agwConfiguration.publicIpName
var agwName = agwConfiguration.name
var privateIpAddress = agwConfiguration.privateIpAddress
var backendPoolName = agwConfiguration.backendPoolName
var fqdnBackendPool = agwConfiguration.fqdnBackendPool
var websiteDomain = agwConfiguration.websiteDomain
var capacity = agwConfiguration.capacity
var autoScaleMaxCapacity = agwConfiguration.autoScaleMaxCapacity

module agwResources 'agwResources.bicep' = {
  scope: agwResourceGroup
  name: 'agwResources_Deploy'
  dependsOn: [
    aksResources
  ]
  params: {
    location:location
    tags: tags
    agwIdentityName: agwIdentityName
    keyVaultName: keyVaultName
    websiteCertificateName: websiteCertificateName
    mngmntResourceGroupName: mngmntResourceGroupName
    agwIdentityKeyVaultAccessPolicyName: agwIdentityKeyVaultAccessPolicyName
    wafPolicyName: wafPolicyName
    agwPipName: agwPipName
    agwName: agwName
    vnetInfo: agwVnetInfo
    snetsInfo: agwSnetsInfo
    privateIpAddress: privateIpAddress
    backendPoolName: backendPoolName
    fqdnBackendPool: fqdnBackendPool
    fwRootCACertificateName: fwRootCACertificateName
    websiteDomain: websiteDomain
    capacity: capacity
    autoScaleMaxCapacity: autoScaleMaxCapacity
  }
}


/*
  Outputs
*/

output logWorkspaceName string = monitoringResources.outputs.logWorkspaceName

