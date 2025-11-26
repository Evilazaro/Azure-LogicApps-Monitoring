param name string
param location string = resourceGroup().location
param servicePrincipalId string
param tags object

module operationalInsights 'log-analytics-workspace.bicep' = {
  name: 'deployLogAnalyticsWorkspace'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    tags: tags
  }
}

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

output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = insights.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = insights.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING
