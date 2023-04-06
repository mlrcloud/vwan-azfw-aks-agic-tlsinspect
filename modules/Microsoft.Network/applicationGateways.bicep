param location string = resourceGroup().location
param tags object
param name string
param vnetName string
param snetName string
param agwPipName string
param privateIpAddress string
param backendPoolName string
param fqdnBackendPool string
param wafPolicyName string
param agwIdentityName string
param mngmntResourceGroupName string
param keyVaulName string
param websiteCertificateName string
param fwRootCACertificateName string
param websiteDomain string
param capacity int
param autoScaleMaxCapacity int



var applicationGatewayId = resourceId('Microsoft.Network/applicationGateways/', '${name}')


resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  name: snetName
  parent: vnet
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' existing = {
  name: agwPipName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaulName
  scope: resourceGroup(mngmntResourceGroupName)
}

resource certificate 'Microsoft.KeyVault/vaults/secrets@2022-07-01' existing = {
  name: websiteCertificateName
  parent: keyVault
}

resource fwRootCACertificate 'Microsoft.KeyVault/vaults/secrets@2022-07-01' existing = {
  name: fwRootCACertificateName
  parent: keyVault
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2021-08-01' existing = {
  name: wafPolicyName
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: agwIdentityName
}
resource applicationGateway 'Microsoft.Network/applicationGateways@2021-08-01' = {
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
      name: 'WAF_v2'
      tier: 'WAF_v2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIpIPv4'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
      {
        name: 'appGwPrivateFrontendIpIPv4'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAddress: privateIpAddress
          privateIPAllocationMethod: 'Static'
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_443'
        properties: {
          port: 443
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendPoolName
        properties: {
          backendAddresses: [
            {
              ipAddress: null
              fqdn: fqdnBackendPool
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'backendSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
          trustedRootCertificates: [
            {
              id: '${applicationGatewayId}/trustedRootCertificates/azfwRootCA'//resourceId('Microsoft.Network/applicationGateways/', '${agwName}','/trustedRootCertificates/backendSettings0e50b009-6a1a-4cba-83c7-5d8d1ad6803d')
            }
          ]
        }
      }
    ]
    backendSettingsCollection: []
    httpListeners: [
      {
        name: 'listener443'
        properties: {
          frontendIPConfiguration: {
            id: '${applicationGatewayId}/frontendIPConfigurations/appGwPublicFrontendIpIPv4'
          }
          frontendPort: {
            id: '${applicationGatewayId}/frontendPorts/port_443'
          }
          protocol: 'Https'
          sslCertificate: {
            id: '${applicationGatewayId}/sslCertificates/websitecertificate'
          }
          hostName: websiteDomain
          requireServerNameIndication: true
        }
      }
    ]
    listeners: []
    requestRoutingRules: [
      {
        name: 'rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${applicationGatewayId}/httpListeners/listener443'
          }
          priority: 100
          backendAddressPool: {
            id: '${applicationGatewayId}/backendAddressPools/aks-bp'
          }
          backendHttpSettings: {
            id: '${applicationGatewayId}/backendHttpSettingsCollection/backendSettings'
          }
        }
      }
    ]
    routingRules: []
    enableHttp2: false
    sslCertificates: [
      {
        name: 'websitecertificate'
        properties: {
          keyVaultSecretId: certificate.properties.secretUri
        }
      }
    ]
    probes: []
    autoscaleConfiguration: {
      minCapacity: capacity
      maxCapacity: autoScaleMaxCapacity
    }
    firewallPolicy: {
      id: wafPolicy.id
    }
    trustedRootCertificates: [
      {
        name: 'azfwRootCA'
        properties: {
          keyVaultSecretId: fwRootCACertificate.properties.secretUri
        }
      }
    ]
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
}
