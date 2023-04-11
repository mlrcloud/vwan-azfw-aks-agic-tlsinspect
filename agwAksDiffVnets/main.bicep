targetScope = 'subscription'

// Global Parameters

@description('Azure region where resource would be deployed')
param location string

@description('Tags associated with all resources')
param tags object 


var deploy = true //Only for testing purspose

// Resource Group Names

@description('Resource Groups names')

var monitoringResourceGroupName = 'rg-monitor'
var hubResourceGroupName = 'rg-hub'
var sharedResourceGroupName = 'rg-shared'
var agwResourceGroupName = 'rg-agw'
var aksResourceGroupName = 'rg-aks'
var securityResourceGroupName = 'rg-security'
var mngmntResourceGroupName = 'rg-mngmnt'


/* 
  Monitoring resources deployment 
*/

@description('Monitoring options')
param monitoringOptions object

var deployLogWorkspace = monitoringOptions.deployLogAnalyticsWorkspace
var existingLogWorkspaceName = monitoringOptions.existingLogAnalyticsWorkspaceName

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = if (deploy) {
  name: monitoringResourceGroupName
  location: location
}

module monitoringResources '../base/monitoring/monitoringResources.bicep' = if (deploy) {
  scope: monitoringResourceGroup
  name: 'monitoringResources_Deploy'
  params: {
    location:location
    tags: tags
    deployLogWorkspace: deployLogWorkspace
    existingLogWorkspaceName: existingLogWorkspaceName
  }
}

/*
  vnet resources deployment 
*/

var vnetsInfo = {
  shared: {
    vnet: {
      name: 'vnet-shared'
      range: '10.0.17.0/24'
    }
    snet: [
      {
        name: 'snet-dns-inbound'
        range: '10.0.17.0/28'
        delegations: 'Microsoft.Network/dnsResolvers'
        routeTable: {}
        privateEndpointNetworkPolicies: 'Disabled'
      }
      {
        name: 'snet-dns-outbound'
        range: '10.0.17.16/28'
        delegations: 'Microsoft.Network/dnsResolvers'
        routeTable: {}
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
  }
  agw: {
    vnet: {
      name: 'vnet-agw'
      range: '10.0.4.0/23' 
    } 
    snets: [
      {
        name: 'myAGSubnet'
        range: '10.0.4.0/24'
        delegations: ''
        routeTable: {
          name: 'rt-agw'
          routes: [
            {
              name: 'fromAgwToInternet'
              properties: {
                addressPrefix: '0.0.0.0/0'
                nextHopType: 'Internet'
              }
            }
          ]
        }
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
  }
  aks: {
    vnet: {
      name: 'vnet-aks'
      range: '10.0.2.0/23' 
    } 
    snets: [
      {
        name: 'snet-aks'
        range: '10.0.2.0/24'
        delegations: ''
        routeTable: {
          name: 'rt-aks'
          routes: [
            {
              name: 'fromAksToInternet'
              properties: {
                addressPrefix: '0.0.0.0/0'
                nextHopType: 'VirtualAppliance'
                nextHopIpAddress: '10.0.0.132'
              }
            }
          ]
        }
        privateEndpointNetworkPolicies: 'Disabled'
      }
    ]
  }
  mngmnt: {
    vnet: {
      name: 'vnet-mngmnt'
      range: '10.0.1.0/24' 
    }
    snets: [
      {
        name: 'snet-vmMngmnt'
        range: '10.0.1.0/26'
        delegations: ''
        routeTable: {
          name: 'rt-vmMngmnt'
          routes: [
            {
              name: 'fromVmMangmntToKvPe'
              properties: {
                addressPrefix: '10.0.6.68/32'
                nextHopType: 'VirtualAppliance'
                nextHopIpAddress: '10.0.0.132'
              }
            }
          ]
        }
        privateEndpointNetworkPolicies: 'Disabled'
      }
      {
        name: 'snet-plinks'
        range: '10.0.1.64/26'
        delegations: ''
        routeTable: {}
        privateEndpointNetworkPolicies: 'RouteTableEnabled'
      }
    ]
  }
}


/*
  Shared resources deployment 
    - Private DNS Resolver
*/

param centrilazedResolverDnsOnSharedVnet bool = true
var dnsResolverName = 'dns-resolver'
var dnsResolverInboundEndpointName = 'inbound-endpoint'
var dnsResolverInboundIp = '10.0.17.4'
var dnsResolverOutboundEndpointName = 'outbound-endpoint'
var dnsForwardingRulesetsName = 'dnsfwrulesets'

@description('Application Azure Private Zone Name')
param websitePrivateDnsZonesName string

//Add in this section the private dns zones you need
var privateDnsZonesInfo = [
  {
    name: websitePrivateDnsZonesName
    vnetLinkName: 'vnet-link-website-to-'
    vnetName: vnetsInfo.shared.vnet.name
  }//Required by Azure Firewall to determine the Web Application’s IP address as HTTP headers usually do not contain IP addresses. 
  {
    name: format('privatelink.vaultcore.azure.net')
    vnetLinkName: 'vnet-link-keyvault-to-'
    vnetName: vnetsInfo.shared.vnet.name
  }//Azure Key Vault (Microsoft.KeyVault/vaults) / vault 
]

//Add in this section the dns forwarding rules you need 
var dnsForwardingRulesInfo = [
  {
    name: 'toWebsite'
    domain: '${websitePrivateDnsZonesName}.'
    state: 'Enabled' //If centrilazedResolverDns=True you should set this to 'Disabled'
    dnsServers: (enableFirewallDnsProxy) ? [
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
    dnsServers: (enableFirewallDnsProxy) ? [
      {
        ipAddress: fwPrivateIp
        port: 53
      }
    ] : []
  }
]

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
    vnetInfo: vnetsInfo.shared.vnet 
    snetsInfo: vnetsInfo.shared.snet
    centrilazedResolverDns: centrilazedResolverDnsOnSharedVnet
    dnsResolverName: dnsResolverName
    dnsResolverInboundEndpointName: dnsResolverInboundEndpointName
    dnsResolverInboundEndpointIp: (enableFirewallDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsResolverOutboundEndpointName: dnsResolverOutboundEndpointName
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    dnsForwardingRules: dnsForwardingRulesInfo
    privateDnsZonesInfo: privateDnsZonesInfo 
  }
}

/* 
  Agw spoke resources
*/

param centrilazedResolverDnsOnAgwVnet bool = false


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
    vnetInfo: vnetsInfo.agw.vnet 
    snetsInfo: vnetsInfo.agw.snets 
    centrilazedResolverDns: centrilazedResolverDnsOnAgwVnet
    dnsResolverInboundEndpointIp: (enableFirewallDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
  }
}

/*
  AKS spoke resources
*/

param centrilazedResolverDnsOnAksVnet bool = true


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
    vnetInfo: vnetsInfo.aks.vnet 
    snetsInfo: vnetsInfo.aks.snets 
    centrilazedResolverDns: centrilazedResolverDnsOnAksVnet
    dnsResolverInboundEndpointIp: (enableFirewallDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
  }
}

/*
  Mngmnt resources
*/

param centrilazedResolverDnsOnMngmntVnet bool = true

@description('Service principal Id')
param spnClientId string
@description('Service principal secret')
@secure()
param spnClientSecret string
var customScriptName = 'custo-script'
param templateBaseUrl string
var downloadFile = 'download.sh'


@description('Random GUID for cluster names')
param guid string = substring(newGuid(), 0, 4)
var keyVaultName = 'kv-agw-fw-aks-tls-c155' //'kv-agw-fw-aks-tls-${guid}'

var keyVaultAccessPolicies = {
  objectId: spnClientId
  permissions: {
    certificates: [
      'import'
    ]
    keys: []
    secrets: []
  }
}

var keyVaultEnabledForDeployment = false
var keyVaultEnabledForDiskEncryption = false
var keyVaultEnabledForTemplateDeployment = true
var keyVaultEnableRbacAuthorization = false
var keyVaultEnableSoftDelete = true
var keyVaultNetworkAcls = {
  bypass: 'AzureServices'
  defaultAction: 'Allow'
  ipRules: []
  virtualNetworkRules: []
} 
var keyVaultPublicNetworkAccess = 'Disabled'
var keyVaultSku = 'standard' 
var keyVaultSoftDeleteRetentionInDays = 7
var keyVaultPrivateEndpointName = 'kv-pe'
var keyVaultPrivateEndpointIp = '10.0.1.68'


var vmMngmntName = 'vm-mngmnt'
var vmMngmntSize = 'Standard_DS2_V2'
var mngmntNicName  = 'nic-vm-mngmnt'
var vmMngmntAdminUsername = 'azureAdmin'


@description('Admin password for Mngmnt vm')
@secure()
param vmMngmntAdminPassword string

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
    fqdnBackendPool: fqdnBackendPool
    downloadFile: downloadFile
    customScriptName: customScriptName
    spnClientId: spnClientId
    templateBaseUrl: templateBaseUrl
    spnClientSecret: spnClientSecret
    aksName: aksName
    certName: websiteCertificateName
    aksResourceGroupName: aksResourceGroupName
    dnsPrivateZoneResourceGroupName: sharedResourceGroupName
    vnetInfo: vnetsInfo.mngmnt.vnet 
    snetsInfo: vnetsInfo.mngmnt.snets 
    nicName: mngmntNicName
    centrilazedResolverDns: centrilazedResolverDnsOnMngmntVnet
    dnsResolverInboundEndpointIp: (enableFirewallDnsProxy) ? fwPrivateIp : dnsResolverInboundIp
    dnsForwardingRulesetsName: dnsForwardingRulesetsName
    sharedResourceGroupName: sharedResourceGroupName
    vmName: vmMngmntName
    vmSize: vmMngmntSize
    vmAdminUsername: vmMngmntAdminUsername
    vmAdminPassword: vmMngmntAdminPassword
    websitePrivateDnsZonesName: websitePrivateDnsZonesName
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
    keyVaultPrivateEndpointIp: keyVaultPrivateEndpointIp
  }
}

/*
  Network connectivity and security
*/

var vwanName = 'vwan'
@description('Name and range for Hub')
var hubVnetInfo = {
  name: 'hub'
  range: '10.0.0.0/24'
} 

var firewallName = 'azfw'
var fwPrivateIp = '10.0.0.132'
var fwIdentityName = 'azfw-identity'
var fwIdentityKeyVaultAccessPolicyName = 'add' //This is mandatory in order to add permissions to the vault access policies property
var fwInterCACertificateName = 'interCA'
@description('InterCA Certificate for AZ FW - Base64 encoded .PFX')
@secure()
param fwInterCACertificateValue string = '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'
@secure()
param fwInterCACertificatePassword string = 'Pa$$word1!'
var fwRootCACertificateName = 'rootCA'
@description('RootCA Certificate for AZ FW - Base64 encoded .PFX')
@secure()
param fwRootCACertificateValue string = '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'
@secure()
param fwRootCACertificatePassword string = 'Pa$$word1!'

var fwPolicyInfo = {
  name: 'fwpolicy'
  snatRanges: [
    '172.16.0.0/12'
    '192.168.0.0/16'
    '198.18.0.0/15'
    '100.64.0.0/10'
  ]
}
var appRuleCollectionGroupName = 'fwapprulegroup'
var appRulesInfo = {
  priority: 300
  ruleCollections: [
      {
          ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
          action: {
              type: 'Allow'
          }
          name: 'AksFwWeRuleCollection'
          priority: 100
          rules: []
      }
  ]
}
var networkRuleCollectionGroupName = 'fwnetrulegroup'
var networkRulesInfo = {
  priority: 200
  ruleCollections: [
    {
      ruleCollectionType: 'FirewallPolicyFilterRuleCollection'
      name: 'aksfwnr'
      action: {
        type: 'Allow'
      }
      priority: 210
      rules: [
        {
          ruleType: 'NetworkRule'
          sourceAddresses: [
            vnetsInfo.agw.vnet.range
          ]
          destinationAddresses: [
            keyVaultPrivateEndpointIp
          ]
          destinationPorts: [
            '443'
          ]
          ipProtocols: [
            'TCP'
          ]
          name: 'fromAgwToKeyVault'
        }
        {
          ruleType: 'NetworkRule'
          sourceAddresses: [
            vnetsInfo.mngmnt.vnet.range
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '*'
          ]
          ipProtocols: [
            'Any'
          ]
          name: 'All-Traffic-Allowed-vmMngmnt'
        }
        {
          ruleType: 'NetworkRule'
          sourceAddresses: [
            vnetsInfo.aks.vnet.range
          ]
          destinationAddresses: [
            '*'
          ]
          destinationPorts: [
            '*'
          ]
          ipProtocols: [
            'Any'
          ]
          name: 'All-Traffic-Allowed-AKS'
        }
      ]
    }
  ]
}

var dnatRuleCollectionGroupName  = 'fwdnatrulegroup'

param enableFirewallDnsProxy bool = true

// TODO If moved to parameters.json, self-reference to other parameters is not supported
@description('Name for hub virtual connections')
var hubVnetConnectionsInfo = [
  {
    name: 'sharedconn'
    remoteVnetName: vnetsInfo.shared.vnet.name
    resourceGroup: sharedResourceGroupName
    enableInternetSecurity: true
  }
  {
    name: 'agwconn'
    remoteVnetName: vnetsInfo.agw.vnet.name
    resourceGroup: agwResourceGroupName
    enableInternetSecurity: true
  }
  {
    name: 'aksconn'
    remoteVnetName: vnetsInfo.aks.vnet.name
    resourceGroup: aksResourceGroupName
    enableInternetSecurity: true
  }
  {
    name: 'mngmntconn'
    remoteVnetName: vnetsInfo.mngmnt.vnet.name
    resourceGroup: mngmntResourceGroupName
    enableInternetSecurity: true
  }
]

var privateTrafficPrefix = [
  '172.16.0.0/12' 
  '192.168.0.0/16'
  '${vnetsInfo.shared.vnet.range}'
  '${vnetsInfo.agw.vnet.range}'
  '${vnetsInfo.aks.vnet.range}'
  '${vnetsInfo.mngmnt.vnet.range}'
]

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
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
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
    fwInterCACertificatePassword: fwInterCACertificatePassword
    fwRootCACertificateName: fwRootCACertificateName
    fwRootCACertificateValue: fwRootCACertificateValue
    fwRootCACertificatePassword: fwRootCACertificatePassword
    fwPolicyInfo: fwPolicyInfo
    appRuleCollectionGroupName: appRuleCollectionGroupName
    appRulesInfo: appRulesInfo
    networkRuleCollectionGroupName: networkRuleCollectionGroupName
    networkRulesInfo: networkRulesInfo 
    dnatRuleCollectionGroupName: dnatRuleCollectionGroupName
    firewallName:firewallName
    destinationAddresses: privateTrafficPrefix
    hubVnetConnectionsInfo: hubVnetConnectionsInfo
    enableDnsProxy: enableFirewallDnsProxy
    dnsResolverInboundEndpointIp: dnsResolverInboundIp
  }
}

/*
  AKS resources
*/

var websiteCertificateName = 'websiteCertificate'
@description('website certificate - Base64 encoded PFX')
@secure()
param websiteCertificateValue string = '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'
@secure()
param websiteCertificatePassword string = 'Pa$$word1!'

var aksName = 'aks'
var aksDnsPrefix = 'agw-fw-aks-dns'
var kubernetesVersion = '1.24.9'
var aksNetworkPlugin = 'azure'
var aksEnableRBAC = true
var aksNodeResourceGroupName = 'MC_rg-aks_agw-fw-aks_westeurope'
var aksDisableLocalAccounts = false
var aksEnablePrivateCluster = false
var aksEnableAzurePolicy = false
var aksEnableSecretStoreCSIDriver = true
var aksServiceCidr = '10.100.0.0/16'
var aksDnsServiceIp = '10.100.0.10'
var aksUpgradeChannel = 'patch'

module aksResources 'aksResources.bicep' = if (deploy) {
  scope: aksResourceGroup
  name: 'aksResources_Deploy'
  dependsOn: [
    vhubResources
  ]
  params: {
    location:location
    tags: tags
    vnetInfo: vnetsInfo.aks.vnet 
    snetsInfo: vnetsInfo.aks.snets
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
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret
    websiteCertificateName: websiteCertificateName
    websiteCertificateValue: websiteCertificateValue
    websiteCertificatePassword: websiteCertificatePassword
  }
}

/*
  Agw resources
*/

var agwIdentityName = 'agw-identity'
var agwIdentityKeyVaultAccessPolicyName = 'add' ////This is mandatory in order to add permissions to the vault access policies property
var wafPolicyName = 'waf-policy'
var agwPipName = 'agw-pip'
var agwName = 'agw'
var privateIpAddress = '10.0.4.4'
var backendPoolName = 'aks-bp'
param agwConfiguration object
var fqdnBackendPool = agwConfiguration.fqdnBackendPool
var websiteDomain = agwConfiguration.websiteDomain
var capacity = 0
var autoScaleMaxCapacity = 10

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
    vnetInfo: vnetsInfo.agw.vnet
    snetsInfo: vnetsInfo.agw.snets
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

