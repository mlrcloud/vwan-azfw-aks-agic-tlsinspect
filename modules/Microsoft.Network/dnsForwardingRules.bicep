

param dnsForwardingRulesetsName string
param name string
param domainName string
param forwardingRuleState string
param targetDnsServers array
param dnsResolverInboundEndpointIp string


resource dnsForwardingRulesets 'Microsoft.Network/dnsForwardingRulesets@2022-07-01' existing = {
  name: dnsForwardingRulesetsName
}

resource dnsForwardingRules 'Microsoft.Network/dnsForwardingRulesets/forwardingRules@2022-07-01' = {
  name: name
  parent: dnsForwardingRulesets
  properties: {
    domainName: domainName
    forwardingRuleState: forwardingRuleState
    targetDnsServers: (empty(targetDnsServers)) ? [
      {
        ipAddress: dnsResolverInboundEndpointIp
        port: 53
      }
    ] : targetDnsServers
  }
}



