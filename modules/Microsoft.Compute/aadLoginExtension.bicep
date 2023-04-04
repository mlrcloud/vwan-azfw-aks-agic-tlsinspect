
param location string = resourceGroup().location
param tags object
param name string 
param vmName string

//TODO: COMPLETE


resource vm 'Microsoft.Compute/virtualMachines@2021-04-01' existing = {
  name: vmName
}

resource aadLogin 'Microsoft.Compute/virtualMachines/extensions@2021-04-01' = {
  name: name
  parent: vm
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.ActiveDirectory'
    type: 'AADLoginForWindows'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      mdmId: ''
    }
  }
}

