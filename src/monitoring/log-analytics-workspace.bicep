// Log Analytics Workspace module for centralized logging and monitoring
// Provides KQL query interface, log retention, and integration with Azure Monitor

@description('Base name for the Log Analytics workspace. Will be suffixed with unique string and "-law".')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for the Log Analytics workspace deployment.')
param location string = resourceGroup().location

@description('Tags to apply to the Log Analytics workspace for organization and compliance.')
param tags object

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
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

@description('Resource ID of the deployed Log Analytics workspace for diagnostic settings configuration')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.id

@description('Name of the deployed Log Analytics workspace for reference and queries')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.name
