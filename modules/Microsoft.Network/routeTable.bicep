
param location string = resourceGroup().location
param tags object
param name string
param routes array


resource routeTable 'Microsoft.Network/routeTables@2022-07-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    disableBgpRoutePropagation: false
    routes: routes
  }
}
