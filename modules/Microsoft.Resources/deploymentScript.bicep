
param location string = resourceGroup().location
param tags object
param name string
param spnClientId string
@secure()
param spnClientSecret string
param keyVaulName string
@secure()
param certificateValue string
@secure()
param password string


resource deploymentScripts 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '8.3'
    scriptContent: 'Import-Module Az.Accounts -RequiredVersion 2.12.1; Install-Module -Name Az.KeyVault -RequiredVersion 4.9.2; $SecuredPassword = ConvertTo-SecureString ${spnClientSecret} -AsPlainText -Force; $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ${spnClientId}, $SecuredPassword; Connect-AzAccount -ServicePrincipal -TenantId ${tenant().tenantId} -Credential $Credential; Import-AzKeyVaultCertificate -VaultName "${keyVaulName}" -Name "${name}" -CertificateString ${certificateValue} -Password ${password}'
    timeout: 'PT1H'
    cleanupPreference: 'OnSuccess'
    retentionInterval: 'P1D'
  }
}
