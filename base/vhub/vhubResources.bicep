
// TODO: verify the required parameters

// Global Parameters
param spnClientId string
@secure()
param spnClientSecret string 
param tenantId string 
param location string = resourceGroup().location
param tags object
param securityResourceGroupName string
param vwanName string 
param hubInfo object 
param monitoringResourceGroupName string
param logWorkspaceName string
param hubResourceGroupName string
param fwIdentityName string
param mngmntResourceGroupName string
param fwInterCACertificateName string
param fwRootCACertificateName string
param fwIdentityKeyVaultAccessPolicyName string
param keyVaultName string
@secure()
param fwInterCACertificateValue string
@secure()
param fwRootCACertificateValue string
param fwPolicyInfo object 
param appRuleCollectionGroupName string
param appRulesInfo object 
param networkRuleCollectionGroupName string
param networkRulesInfo object 
param dnatRuleCollectionGroupName string
param firewallName string
param destinationAddresses array
param hubVnetConnectionsInfo array
param enableDnsProxy bool
param dnsResolverInboundEndpointIp string


var dnatRulesInfo = {
  priority: 100
  ruleCollections: [
    {
      ruleCollectionType: 'FirewallPolicyNatRuleCollection'
      name: 'RemoteAccessRuleCollection'
      action: {
        type: 'Dnat'
      }
      priority: 110
      rules: [
        {
          ruleType: 'NatRule'
          name: 'dns-ssh-access'
          translatedAddress: '10.0.1.4'
          translatedPort: 22
          ipProtocols: [
              'TCP'
          ]
          sourceAddresses: [
              '*'
          ]
          sourceIpGroups: []
          destinationAddresses: [
              firewallResources.outputs.fwPublicIp.address
          ]
          destinationPorts: [
              22
          ]
        }
      ]
    }
  ]
}


module vwanResources '../../modules/Microsoft.Network/vwan.bicep' = {
  name: 'vwanResources_Deploy'
  params: {
    location: location
    tags: tags 
    name: vwanName
  }
}

module hubResources '../../modules/Microsoft.Network/hub.bicep' = {
  name: 'hubResources_Deploy'
  dependsOn: [
    vwanResources
  ]
  params: {
    location: location
    tags: tags
    hubInfo: hubInfo
    vwanId: vwanResources.outputs.id
  }
}

module fwIdentityResources '../../modules/Microsoft.Authorization/userAssignedIdentity.bicep' = {
  name: 'fwIdentityRss_Deploy'
  scope: resourceGroup(securityResourceGroupName)
  params: {
    name: fwIdentityName
    location: location
    tags: tags
  }
}

module fwInterCACertificateResources '../../modules/Microsoft.KeyVault/certificate.bicep' = {
  name: 'fwInterCACertificateResources_Deploy'
  scope: resourceGroup(mngmntResourceGroupName)
  params: {
    tags: tags
    name: fwInterCACertificateName
    keyVaulName: keyVaultName
    certificateValue: fwInterCACertificateValue
  }
}

module fwRootCACerificateResources '../../modules/Microsoft.KeyVault/certificate.bicep' = {
  name: 'fwRootCACertificateResources_Deploy'
  scope: resourceGroup(mngmntResourceGroupName)
  params: {
    tags: tags
    name: fwRootCACertificateName
    keyVaulName: keyVaultName
    certificateValue: fwRootCACertificateValue
  }
}

module fwIdentityKeyVaultAccessPolicy '../../modules/Microsoft.KeyVault/accessPolicies.bicep' = {
  name: 'fwIdentityKeyVaultAccessPolicyResources_Deploy'
  scope: resourceGroup(mngmntResourceGroupName)
  params: {
    name: fwIdentityKeyVaultAccessPolicyName
    keyVaultName: keyVaultName
    objectId: fwIdentityResources.outputs.principalId
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
    fwIdentityResources
  ]
}

module fwPolicyResources '../../modules/Microsoft.Network/fwPolicy.bicep' = {
  name: 'fwPolicyResources_Deploy'
  scope: resourceGroup(securityResourceGroupName)
  params: {
    spnClientId: spnClientId
    spnClientSecret: spnClientSecret 
    tenantId: tenantId 
    location: location
    tags: tags
    monitoringResourceGroupName: monitoringResourceGroupName
    logWorkspaceName: logWorkspaceName
    fwIdentityName: fwIdentityName
    mngmntResourceGroupName: mngmntResourceGroupName
    keyVaulName: keyVaultName
    fwInterCACertificateName: fwInterCACertificateName
    fwPolicyInfo: fwPolicyInfo
    enableProxy: enableDnsProxy
    dnsResolverInboundEndpointIp: dnsResolverInboundEndpointIp
  }
  dependsOn: [
    fwIdentityResources
    fwInterCACertificateResources
    fwRootCACerificateResources
    fwIdentityKeyVaultAccessPolicy
  ]
}

module fwAppRulesResources '../../modules/Microsoft.Network/fwRules.bicep' = {
  name: 'fwAppRulesResources_Deploy'
  scope: resourceGroup(securityResourceGroupName)
  dependsOn: [
    fwPolicyResources
  ]
  params: {
    fwPolicyName: fwPolicyInfo.name
    ruleCollectionGroupName: appRuleCollectionGroupName
    rulesInfo: appRulesInfo
  }
}

module fwNetworkRulesResources '../../modules/Microsoft.Network/fwRules.bicep' = {
  name: 'fwNetworkRulesResources_Deploy'
  scope: resourceGroup(securityResourceGroupName)
  dependsOn: [
    fwPolicyResources
    fwAppRulesResources
  ]
  params: {
    fwPolicyName: fwPolicyInfo.name
    ruleCollectionGroupName: networkRuleCollectionGroupName
    rulesInfo: networkRulesInfo
  }
}

module firewallResources '../../modules/Microsoft.Network/firewall.bicep' = {
  name: 'firewallResources_Deploy'
  scope: resourceGroup(securityResourceGroupName)
  dependsOn: [
    fwPolicyResources
    fwAppRulesResources
    fwNetworkRulesResources
    hubResources
  ]
  params: {
    location: location
    tags: tags
    name: firewallName
    monitoringResourceGroupName: monitoringResourceGroupName
    hubResourceGroupName: hubResourceGroupName
    fwPolicyInfo: fwPolicyInfo
    hubName: hubInfo.name
    logWorkspaceName: logWorkspaceName
  }
}

module fwDnatRulesResources '../../modules/Microsoft.Network/fwRules.bicep' = {
  name: 'fwDnatRulesResources_Deploy'
  scope: resourceGroup(securityResourceGroupName)
  dependsOn: [
    firewallResources
  ]
  params: {
    fwPolicyName: fwPolicyInfo.name
    ruleCollectionGroupName: dnatRuleCollectionGroupName
    rulesInfo: dnatRulesInfo
  }
}

module hubRouteTableResources '../../modules/Microsoft.Network/hubRouteTable.bicep' = {
  name: 'hubRouteTableResources_Deploy'
  dependsOn: [
    hubResources
    firewallResources
  ]
  params: {
    hubInfo: hubInfo
    firewallName: firewallName
    destinations: destinationAddresses
    securityResourceGroupName: securityResourceGroupName
  }
}

module hubVirtualConnectionResources '../../modules/Microsoft.Network/hubVnetConnection.bicep' = [ for (connectInfo, i) in hubVnetConnectionsInfo: {
  name: 'hubVirtualConnectionResources_Deploy${i}'
  dependsOn: [
    hubResources
    hubRouteTableResources
  ]
  params: {
    hubInfo: hubInfo
    connectInfo: connectInfo
    enableInternetSecurity: connectInfo.enableInternetSecurity
  }
}]



