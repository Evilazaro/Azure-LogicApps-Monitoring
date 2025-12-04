@description('Base name for Application Insights.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for Application Insights deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
param envName string

@description('Resource ID of the Log Analytics workspace for workspace-based Application Insights integration.')
param logAnalyticsWorkspaceId string

@description('Resource ID of the Storage Account for the Application Insights diagnostic settings.')
param storageAccountId string

@description('Resource tags applied to Application Insights.')
param tags object

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-appinsights'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('Name of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = applicationInsights.name

@description('Resource ID of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_ID string = applicationInsights.id

@description('Instrumentation key for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = applicationInsights.properties.InstrumentationKey

@description('Connection string for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = applicationInsights.properties.ConnectionString

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${applicationInsights.name}-diag'
  scope: applicationInsights
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}
