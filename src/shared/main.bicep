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

resource workloadMi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-${uniqueString(resourceGroup().id, name)}-mi'
  location: location
  tags: tags
}

module data 'data/main.bicep' = {
  name: 'DataDeployment'
  scope: resourceGroup()
  params: {
    name: name
    servicePrincipalId: workloadMi.properties.principalId
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
    servicePrincipalId: workloadMi.properties.principalId
    tags: tags
  }
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
    servicePrincipalId: workloadMi.properties.principalId
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    tags: tags
  }
}
