
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
param spnClientId string
@secure()
param spnClientSecret string
var dnsServers = [
  dnsResolverInboundEndpointIp
  '168.63.129.16'
]

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
  // identity: {
  //   type: 'UserAssigned'
  //   userAssignedIdentities: {
  //     '${fwIdentity.id}': {}
  //   }
  // }
  properties: {
    sku: {
      tier: 'Premium'
    }
    // transportSecurity:{
    //   certificateAuthority: {
    //     name: fwInterCACertificateName
    //     keyVaultSecretId: fwInterCACertificate.properties.secretUri
    //   }
    // }
    // threatIntelMode: 'Alert'
    // intrusionDetection: {
    //   mode: 'Alert'
    // }
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

resource tlsInspection 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzurePowerShell'
  name: 'tlsInspection'
  location: location
  properties: {
    azPowerShellVersion: '8.3'
    scriptContent: 'Import-Module Az.Accounts -RequiredVersion 2.12.1; Import-Module Az.Network -RequiredVersion 3.0.0; $SecuredPassword = ConvertTo-SecureString ${spnClientSecret} -AsPlainText -Force; $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ${spnClientId}, $SecuredPassword; Connect-AzAccount -ServicePrincipal -TenantId ${tenant().tenantId} -Credential $Credential; $intrusionDetection = New-AzFirewallPolicyIntrusionDetection -Mode "Alert"; if (${enableProxy}){$dnsSettings = New-AzFirewallPolicyDnsSetting -EnableProxy -Server ${dnsServers}}else{$dnsSettings = New-AzFirewallPolicyDnsSetting -Server None}; $snatRanges = New-AzFirewallPolicySnat -PrivateRange $snatRanges; Set-AzFirewallPolicy -Name ${fwPolicyInfo.name} -ResourceGroupName ${resourceGroup().name} -Location ${location} -TransportSecurityName "tsName" -TransportSecurityKeyVaultSecretId ${fwInterCACertificate.properties.secretUri} -UserAssignedIdentityId ${fwIdentity.id} -DnsSetting $dnsSettings -Snat $snatRanges -ThreatIntelMode "Alert" -IntrusionDetection $intrusionDetection -SkuTier "Premium"'    
    //'Import-Module Az.Accounts -RequiredVersion 2.12.1; Import-Module Az.Network -RequiredVersion 3.0.0; $SecuredPassword = ConvertTo-SecureString ${spnClientSecret} -AsPlainText -Force; $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ${spnClientId}, $SecuredPassword; Connect-AzAccount -ServicePrincipal -TenantId ${tenant().tenantId} -Credential $Credential; $intrusionDetection = New-AzFirewallPolicyIntrusionDetection -Mode "Alert"; $dnsSettings = New-AzFirewallPolicyDnsSetting -EnableProxy -Server ${dnsServers} Set-AzFirewallPolicy -Name ${fwPolicyInfo.name} -ResourceGroupName ${resourceGroup().name} -Location ${location} -TransportSecurityName "tsName" -TransportSecurityKeyVaultSecretId ${fwInterCACertificate.properties.secretUri} -UserAssignedIdentityId ${fwIdentity.id} -ThreatIntelMode "Alert" -IntrusionDetection $intrusionDetection -SkuTier "Premium"'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
  }
  dependsOn: [
    fwPolicy
  ]
}
