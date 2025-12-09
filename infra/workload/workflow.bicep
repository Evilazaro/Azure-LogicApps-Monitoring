param tags object

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: 'process-orders'
  identity: {
    type: 'SystemAssigned'
  }
  location: resourceGroup().location
  tags: tags
}
