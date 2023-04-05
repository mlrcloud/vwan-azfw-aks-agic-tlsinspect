
param location string = resourceGroup().location
param tags object
param logWorkspaceName string 
param monitoringResourceGroupName string
param fwPolicyInfo object 
param enableProxy bool
param dnsResolverInboundEndpointIp string


resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logWorkspaceName
  scope: resourceGroup(monitoringResourceGroupName)
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2021-02-01' = {
  name: fwPolicyInfo.name
  location: location
  tags: tags
  properties: {
    sku: {
      tier: 'Premium'
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

