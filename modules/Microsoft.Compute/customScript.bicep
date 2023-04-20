@secure()
param name string
param location string = resourceGroup().location
param commandToExecute string
param templateBaseUrl string
param vmName string
param downloadFile string

resource vm 'Microsoft.Compute/virtualMachines@2021-04-01' existing = {
  name: vmName
}

resource customScript 'Microsoft.Compute/virtualMachines/extensions@2021-11-01' = {
  parent: vm
  name: name
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
    }
    protectedSettings: {
      commandToExecute: commandToExecute
      fileUris: [
        uri(templateBaseUrl, downloadFile)
      ]
    }
  }
}
