
param location string = resourceGroup().location
param tags object
param name string 
param aadLogin bool
param vmSize string
param vmRedundancy string
param availabilitySetName string
param availabilityZones array
param adminUsername string 
@secure()
param adminPassword string 
param nicName string 
param osDiskName string 
param storageAccountType string 
param vmGalleryImage object
param loopIndex int

var countOfSelectedAZ = length(availabilityZones)

resource nic 'Microsoft.Network/networkInterfaces@2021-02-01' existing = {
  name: nicName
}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2021-04-01' existing = if (vmRedundancy == 'availabilitySet') {
  name: availabilitySetName
}

resource vm 'Microsoft.Compute/virtualMachines@2021-04-01' = {
  name: name
  location: location
  tags: tags
  identity: (aadLogin) ? {
    type: 'SystemAssigned'
  }: json('null')
  zones: (vmRedundancy == 'availabilityZone') ? array(availabilityZones[loopIndex%countOfSelectedAZ]) : json('null')
  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: vmSize
    }
    availabilitySet: (vmRedundancy == 'availabilitySet') ? {
      id: availabilitySet.id
    }: json('null')
    osProfile: {
      computerName: name
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
      }
    }
    storageProfile: {
      osDisk: {
        name: osDiskName
        managedDisk: {
          storageAccountType: storageAccountType
        }
        osType: 'Windows'
        createOption: 'FromImage'
      }
      imageReference: (!empty(vmGalleryImage.imageId)) ? {
        id: vmGalleryImage.imageId 
      } : {
        publisher: vmGalleryImage.imagePublisher
        offer: vmGalleryImage.imageOffer
        sku: vmGalleryImage.imageSKU
        version: vmGalleryImage.imageVersion
      }
      dataDisks: []
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
