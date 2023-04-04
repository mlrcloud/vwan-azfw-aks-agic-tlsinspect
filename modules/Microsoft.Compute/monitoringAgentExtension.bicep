
param location string = resourceGroup().location
param tags object
param vmName string
param logWorkspaceName string
param monitoringResourceGroupName string


resource vm 'Microsoft.Compute/virtualMachines@2021-04-01' existing = {
  name: vmName
}

resource logWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logWorkspaceName
  scope: resourceGroup(monitoringResourceGroupName)
}

//Supports the VM Insights features and associates the VM with a Log Workspace
resource monitoringAgentExtension 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = {
  parent: vm
  name: 'MicrosoftMonitoringAgent'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: logWorkspace.properties.customerId
    }
    protectedSettings: {
      workspaceKey: listKeys(logWorkspace.id, '2015-03-20').primarySharedKey
    }
  }
}
