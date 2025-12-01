// Shared resources module orchestrator
// Deploys user-assigned managed identity, storage account, and monitoring infrastructure
// Provides foundational resources required by Logic Apps workload

@description('Base name for all shared resources.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for shared resources deployment.')
param location string = resourceGroup().location

@description('Tags to apply to all shared resources.')
param tags object

module data 'data/main.bicep' = {
  name: 'DataDeployment'
  scope: resourceGroup()
  params: {
    name: name
    tags: tags
  }
}

@description('Name of the deployed storage account for Logic Apps Standard runtime requirements')
output STORAGE_ACCOUNT_NAME string = data.outputs.STORAGE_ACCOUNT_NAME

module monitoring '../monitoring/main.bicep' = {
  name: 'MonitoringDeployment'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    tags: tags
  }
  dependsOn: [
    data
  ]
}

@description('Resource ID of the Log Analytics workspace for Logic Apps diagnostic logging')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the deployed Application Insights instance for Logic Apps telemetry')
output AZURE_APPLICATION_INSIGHTS_NAME string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_NAME

module messaging 'messaging/main.bicep' = {
  name: 'MessagingDeployment'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    tags: tags
  }
}

@description('Name of the deployed Service Bus namespace for Logic Apps messaging integration')
output AZURE_SERVICEBUS_NAMESPACE_NAME string = messaging.outputs.AZURE_SERVICEBUS_NAMESPACE_NAME
