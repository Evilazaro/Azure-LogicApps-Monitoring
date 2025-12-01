param name string
param location string = resourceGroup().location
param tags object

resource serviceBus 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' = {
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 16
  }
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2025-05-01-preview' = {
  name: 'tax-approval'
  parent: serviceBus
}
