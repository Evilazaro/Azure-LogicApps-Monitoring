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
  properties: {
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2025-05-01-preview' = {
  name: 'tax-approval'
  parent: serviceBus
}

resource serviceBusAuthRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2025-05-01-preview' existing = {
  name: 'RootManageSharedAccessKey'
  parent: serviceBus
}

@secure()
output AZURE_SERVICEBUS_CONNECTIONSTRING string = serviceBusAuthRule.listKeys().primaryConnectionString
