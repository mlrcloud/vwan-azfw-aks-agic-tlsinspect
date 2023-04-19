targetScope = 'subscription'

// Global Parameters

@description('Azure region where resource would be deployed')
param location string

@description('Tags associated with all resources')
param tags object = {
  project: 'tls-inspection'
  environment: 'demo'
}

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

var deployLogWorkspace = true
var existingLogWorkspaceName = ''

resource monitoringResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: monitoringResourceGroupName
  location: location
}

module monitoringResources '../base/monitoring/monitoringResources.bicep' = {
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
                addressPrefix: '10.0.1.68/32'
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

resource sharedResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: sharedResourceGroupName
  location: location
}

module sharedResources '../base/shared/sharedResources.bicep' = {
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


resource agwResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: agwResourceGroupName
  location: location
}

module agwSpokeResources 'agwSpokeResources.bicep' = {
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


resource aksResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: aksResourceGroupName
  location: location
}

module aksSpokeResources 'aksSpokeResources.bicep' = {
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
param templateBaseUrl string = 'https://raw.githubusercontent.com/pabloameijeirascanay/test/main/artifacts/' //TOREVIEW: Change this after change repo visibility
var downloadFile = 'download.sh'


@description('Random GUID for cluster names')
param guid string = substring(newGuid(), 0, 4)
var keyVaultName = 'kv-agw-fw-aks-tls-${guid}' //'kv-agw-fw-aks-tls-${guid}'

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
var vmMngmntAdminUsername = 'azureadmin'


@description('Admin password for Mngmnt vm')
@secure()
param vmMngmntAdminPassword string

resource mngmntResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: mngmntResourceGroupName
  location: location
}

module mngmntResources '../base/mngmnt/mngmntResources.bicep' = {
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
    agwResourceGroupName: agwResourceGroupName
    agwName: agwName
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
param fwInterCACertificateValue string
@secure()
param fwInterCACertificatePassword string
var fwRootCACertificateName = 'rootCA'
@description('RootCA Certificate for AZ FW - Base64 encoded .PFX')
@secure()
param fwRootCACertificateValue string
@secure()
param fwRootCACertificatePassword string

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
        //Scenario agw + azfw network rules: disable app rule, because fw will not act as web proxy so no TLS inspection will be performed. 
        // AGW Default Probe doesn't work because it uses protocol//localhost:ports for health check so the responde code is 404 and only 200-399 code are allowed.
        
        //Scenario agw +azfw app rules: enable app rule, because fw will act as web proxy so TLS inspection will be performed.
        // AGW Default Probe doesn't work because SNI doesn't work. "If a custom probe isn't configured, then Application Gateway sends a default probe in this format - <protocol>://127.0.0.1:<port>/. 
        //For example, for a default HTTPS probe, it will be sent as https://127.0.0.1:443/. 
        //Note that, the 127.0.0.1 mentioned here is only used as HTTP host header and as per RFC 6066, won't be used as SNI header."
        //url: https://learn.microsoft.com/en-us/azure/application-gateway/ssl-overview#for-probe-traffic
        /* 
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

resource securityResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: securityResourceGroupName
  location: location
}

resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: hubResourceGroupName
  location: location
}

module vhubResources '../base/vhub/vhubResources.bicep' = {
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
param websiteCertificateValue string 
@secure()
param websiteCertificatePassword string

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

module aksResources 'aksResources.bicep' = {
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

