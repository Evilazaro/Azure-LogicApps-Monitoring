param name string
param location string
param tags object

resource appImages 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: name
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  sku: {
    name: 'Premium'
  }
}
