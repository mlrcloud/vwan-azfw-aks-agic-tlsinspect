
param location string = resourceGroup().location
param tags object
param logWorkspaceName string 
param monitoringResourceGroupName string
param fwPolicyInfo object 
param fwIdentityName string
param mngmntResourceGroupName string
param keyVaulName string
param fwInterCACertificateName string
param enableProxy bool
param dnsResolverInboundEndpointIp string


resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logWorkspaceName
  scope: resourceGroup(monitoringResourceGroupName)
}

resource fwIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: fwIdentityName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaulName
  scope: resourceGroup(mngmntResourceGroupName)
}

resource fwInterCACertificate 'Microsoft.KeyVault/vaults/secrets@2022-07-01' existing = {
  name: fwInterCACertificateName
  parent: keyVault
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2022-09-01' = {
  name: fwPolicyInfo.name
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${fwIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      tier: 'Premium'
    }
    transportSecurity:{
      certificateAuthority: {
        name: fwInterCACertificateName
        keyVaultSecretId: fwInterCACertificate.properties.secretUri
      }
    }
    threatIntelMode: 'Alert'
    intrusionDetection: {
      mode: 'Alert'
    }
    snat: {
      privateRanges: fwPolicyInfo.snatRanges
    }
    dnsSettings: {
      servers: (enableProxy) ? [
        dnsResolverInboundEndpointIp
        '168.63.129.16'
      ] : json('null')
      enableProxy: enableProxy
    }
    insights: {
      isEnabled: true
      logAnalyticsResources: {
        defaultWorkspaceId: {
          id: logWorkspace.id
        }
      }
    }
  }
}


