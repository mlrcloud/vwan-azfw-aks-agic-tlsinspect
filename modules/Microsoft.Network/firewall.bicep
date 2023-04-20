
param location string = resourceGroup().location
param tags object
param logWorkspaceName string 
param monitoringResourceGroupName string
param hubResourceGroupName string
param fwPolicyInfo object 
param name string
param hubName string


resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logWorkspaceName
  scope: resourceGroup(monitoringResourceGroupName)
}

resource fwPolicy 'Microsoft.Network/firewallPolicies@2022-09-01' existing = {
  name: fwPolicyInfo.name
}

resource hub 'Microsoft.Network/virtualHubs@2021-02-01' existing = {
  name: hubName
  scope: resourceGroup(hubResourceGroupName)
}

resource firewall 'Microsoft.Network/azureFirewalls@2020-06-01' = {
  name: name
  location: location
  tags: tags
  zones: [
    '1'
    '2'
    '3'
  ]
  properties: {
    sku: {
      name: 'AZFW_Hub'
      tier: 'Premium'
    }
    additionalProperties: {
      //'Network.FTP.AllowActiveFTP': 'true'
    }
    hubIPAddresses: {
      publicIPs: {
        /*
        addresses: [
          {
            address: fwPublicIp.properties.ipAddress
          }
        ]
        */
        //TODO: Not supported in the last API version
        count: 1
      }
    }
    networkRuleCollections: []
    applicationRuleCollections: []
    natRuleCollections: []
    virtualHub: {
      id: hub.id
    }
    firewallPolicy: {
      id: fwPolicy.id
    }
  }
}

resource firewallDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diagsetting'
  scope: firewall
  properties: {
    storageAccountId: null
    eventHubAuthorizationRuleId: null
    eventHubName: null
    workspaceId: logWorkspace.id
    logs: [
      {
        category: 'AzureFirewallApplicationRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRule'
        enabled: true
      }
      {
        category: 'AzureFirewallNatRule'
        enabled: true
      }
      {
        category: 'AzureFirewallThreatIntelligence'
        enabled: true
      }
      {
        category: 'AzureFirewallIdpsSignature'
        enabled: true
      }
      {
        category: 'AzureFirewallDNSquery'
        enabled: true
      }
      {
        category: 'AzureFirewallFQDNResolutionFailure'
        enabled: true
      }
      {
        category: 'AzureFirewallFatFlowLog'
        enabled: true
      }
      {
        category: 'AzureFirewallFlowTraceLog'
        enabled: true
      }
      {
        category: 'AzureFirewallNetworkRuleAggregation'
        enabled: true
      }
      {
        category: 'AzureFirewallApplicationRuleAggregation'
        enabled: true
      }
      {
        category: 'AzureFirewallNatRuleAggregation'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output fwPublicIp object = firewall.properties.hubIPAddresses.publicIPs.addresses[0]
