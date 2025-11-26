// Monitoring module orchestrator
// Deploys Azure Monitor health model, Log Analytics workspace, and Application Insights
// Provides complete observability stack for Logic Apps workload

@description('Base name for all monitoring resources.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for monitoring resources deployment.')
param location string = resourceGroup().location

@description('Principal ID of the managed identity requiring monitoring access.')
param servicePrincipalId string

@description('Tags to apply to all monitoring resources.')
param tags object

module healthModel 'azure-monitor-health-model.bicep' = {
  name: 'deployAzureMonitorHealthModel'
  scope: resourceGroup()
  params: {
    name: name
    tags: tags
  }
}

module operationalInsights 'log-analytics-workspace.bicep' = {
  name: 'deployLogAnalyticsWorkspace'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    tags: tags
  }
  dependsOn: [
    healthModel
  ]
}

@description('Resource ID of the Log Analytics workspace for workload diagnostic settings')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = operationalInsights.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

module insights 'app-insights.bicep' = {
  name: 'deployAppInsights'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    servicePrincipalId: servicePrincipalId
    logAnalyticsWorkspaceId: operationalInsights.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    tags: tags
  }
}

@description('Application Insights instrumentation key for Logic Apps telemetry configuration')
@secure()
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = insights.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

@description('Application Insights connection string for Logic Apps telemetry configuration')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = insights.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING