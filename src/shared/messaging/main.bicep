param name string
param location string = resourceGroup().location
param workspaceId string
param tags object

resource serviceBus 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' = {
  name: '${name}-sb-${uniqueString(resourceGroup().id, name)}'
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
    disableLocalAuth: true
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

output AZURE_SERVICEBUS_NAMESPACE_NAME string = serviceBus.name

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: serviceBus.name
  scope: serviceBus
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}
