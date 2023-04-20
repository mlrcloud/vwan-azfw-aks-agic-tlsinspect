

param name string
param rule object
param nsgName string

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' existing = {
  name: nsgName
}

resource nsgRule 'Microsoft.Network/networkSecurityGroups/securityRules@2021-02-01' = {
  name: name
  parent: nsg
  properties: rule
}
