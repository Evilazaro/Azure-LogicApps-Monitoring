param name string
param location string = resourceGroup().location
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name)}-law'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      immediatePurgeDataOn30Days: true
    }
  }
}

output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.id
