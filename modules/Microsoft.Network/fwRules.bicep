

param fwPolicyName string
param ruleCollectionGroupName string 
param rulesInfo object

resource fwPolicy 'Microsoft.Network/firewallPolicies@2021-02-01' existing = {
  name: fwPolicyName
}

resource ruleCollectionGroup 'Microsoft.Network/firewallPolicies/ruleCollectionGroups@2021-02-01' = {
  parent: fwPolicy
  name: ruleCollectionGroupName
  properties: rulesInfo
}
