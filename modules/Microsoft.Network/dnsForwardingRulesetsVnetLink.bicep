

param dnsForwardingRulesetsName string
param name string
param vnetName string
param vnetResourceGroupName string

resource dnsForwardingRulesets 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' existing = {
  name: dnsForwardingRulesetsName
}

resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  scope: resourceGroup(vnetResourceGroupName)
  name: vnetName
}

resource vnetLink 'Microsoft.Network/dnsForwardingRulesets/virtualNetworkLinks@2022-07-01' = {
  name: name
  parent: dnsForwardingRulesets
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
  }
}



