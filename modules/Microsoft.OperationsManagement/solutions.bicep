
param location string = resourceGroup().location
param tags object
param name string 
param workspaceResourceId string
param product string
param promotionCode string
param publisher string


resource solution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  location: location
  tags: tags
  name: name
  properties: {
    workspaceResourceId: workspaceResourceId
  }
  plan: {
    name: name
    product: product
    promotionCode: promotionCode
    publisher: publisher
  }
}
