@description('Base name for Application Insights. Will be suffixed with unique string and "-appinsights" for global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for Application Insights deployment. Must match Log Analytics workspace region for workspace-based model.')
@minLength(3)
param location string = resourceGroup().location

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
@minLength(2)
@maxLength(10)
param envName string

@description('Resource ID of the Log Analytics workspace for workspace-based Application Insights integration (best practice).')
param logAnalyticsWorkspaceId string

@description('Resource tags applied to Application Insights and diagnostic settings for organization and governance.')
@metadata({
  example: {
    Solution: 'tax-docs'
    Environment: 'prod'
  }
})
param tags object

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-appinsights'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    // Public network access enabled for Application Insights ingestion and querying
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = appInsights.name

@description('Resource ID of the deployed Application Insights instance for RBAC assignments')
output AZURE_APPLICATION_INSIGHTS_ID string = appInsights.id

@description('Instrumentation key for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = appInsights.properties.InstrumentationKey

@description('Connection string for Application Insights telemetry (recommended over instrumentation key)')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = appInsights.properties.ConnectionString

// ============================================================================
// DIAGNOSTIC SETTINGS
// ============================================================================

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appInsights.name}-diagsetting'
  scope: appInsights
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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
