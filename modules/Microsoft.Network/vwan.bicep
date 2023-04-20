
param location string = resourceGroup().location
param tags object
param name string 

/*

vwanName --> {"code":"DeploymentFailed","message":"At least one resource deployment operation failed. Please list deployment operations for details. Please see https://aka.ms/DeployOperations for usage details.","details":[{"code":"InvalidResourceName","message":"Resource name vwan-preprod-001} is invalid. The name can be up to 80 characters long. It must begin with a word character, and it must end with a word character or with '_'. The name may contain word characters or '.', '-', '_'."}]}
*/

resource vwan 'Microsoft.Network/virtualWans@2021-02-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    disableVpnEncryption: false
    allowBranchToBranchTraffic: false 
    type: 'Standard'
  }
}

output id string = vwan.id
