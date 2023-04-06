
param location string = resourceGroup().location
param tags object
param name string 
param vmSize string
@secure()
param adminUsername string
@secure()
param adminPassword string
param nicName string

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' existing = {
  name: nicName
}

resource vm 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'canonical'
        offer: '0001-com-ubuntu-minimal-focal'
        sku: 'minimal-20_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
        diskSizeGB: 127
      }
    }
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        patchSettings: {
          patchMode: 'ImageDefault'
        }
        provisionVMAgent: true
      }
      allowExtensionOperations: true
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
  }
}

