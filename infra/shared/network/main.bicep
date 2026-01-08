param name string
param location string
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {}
}
