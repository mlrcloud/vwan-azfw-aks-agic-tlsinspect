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

@description('Service principal Object Id')
param spnObjectId string
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
  objectId: spnObjectId
  permissions: {
    certificates: [
      'Import'
      'Get'
      'List'
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
var keyVaultPublicNetworkAccess = 'Enabled'
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
param fwInterCACertificatePassword string = '123'
var fwRootCACertificateName = 'rootCA'
@description('RootCA Certificate for AZ FW - Base64 encoded .PFX')
@secure()
param fwRootCACertificateValue string = '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'
@secure()
param fwRootCACertificatePassword string = '123'

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
          rules: [
            {
              ruleType: 'ApplicationRule'
              protocols: [
                {
                    protocolType: 'Https'
                    port: 443
                }
              ]
              targetFqdns: [
                  fqdnBackendPool
              ]
              terminateTLS: true
              sourceAddresses: [
                vnetsInfo.agw.vnet.range
              ]
              name: 'fromAgwToIngressController'
            }
          ]
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
        /* //Scenario: disable app rule, because fw will not act as web proxy so no TLS inspection will be performed
        {
          ruleType: 'NetworkRule'
          sourceAddresses: [
            vnetsInfo.agw.vnet.range
          ]
          destinationAddresses: [
            vnetsInfo.aks.vnet.range
          ]
          destinationPorts: [
            '*'
          ]
          ipProtocols: [
            'Any'
          ]
          name: 'All-Traffic-Allowed-AKS'
        }
        */
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
param websiteCertificatePassword string = '123'

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

