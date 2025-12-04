
@description('Base name for all monitoring resources.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
param envName string

@description('Azure region for monitoring resources deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Resource tags applied to all monitoring resources.')
param tags object

module healthModel 'azure-monitor-health-model.bicep' = {
  name: 'healthModelDeployment'
  scope: resourceGroup()
  params: {
    name: name
    tags: tags
  }
}

module operational 'log-analytics-workspace.bicep' = {
  name: 'operationalDeployment'
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    tags: tags
  }
}

module insights 'app-insights.bicep' = {
  name: 'insightsDeployment'
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    logAnalyticsWorkspaceId: operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: operational.outputs.LOGS_STORAGE_ACCOUNT_ID
    tags: tags
  }
}

@description('Resource ID of the Log Analytics workspace for configuring diagnostic settings')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = insights.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Resource ID of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_ID string = insights.outputs.AZURE_APPLICATION_INSIGHTS_ID

@description('Connection string for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = insights.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = insights.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

@description('Name of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Resource ID of the storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_ID string = operational.outputs.LOGS_STORAGE_ACCOUNT_ID

@description('Name of the deployed storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_NAME string = operational.outputs.LOGS_STORAGE_ACCOUNT_NAME
