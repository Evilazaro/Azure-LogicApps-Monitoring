// ============================================================================
// SHARED RESOURCES MODULE ORCHESTRATOR
// ============================================================================
// Orchestrates deployment of foundational resources required by Logic Apps:
// 1. Storage Account - Runtime artifacts, state, and workflow definitions
// 2. Monitoring Infrastructure - Log Analytics, Application Insights, Health Model
// 3. Service Bus Namespace - Messaging and queue-based integrations
//
// Module Dependencies:
// - Data module (storage) deploys first (no dependencies)
// - Monitoring module deploys after data (uses tags, location)
// - Messaging module deploys last (requires workspace ID for diagnostics)
//
// Note: User-assigned managed identity should be added here in future versions
// to enable RBAC-based authentication instead of connection strings.
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for all shared resources. Used as prefix to ensure consistent naming across modules.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
param envName string

@description('Azure region for shared resources deployment. Should match Logic App deployment region.')
param location string = resourceGroup().location

@description('Resource tags applied to all shared resources for cost tracking, organization, and compliance.')
param tags object

// ============================================================================
// MODULE DEPLOYMENTS
// ============================================================================

// Deploy monitoring stack (Log Analytics, Application Insights, Health Model)
module monitoring '../monitoring/main.bicep' = {
  name: 'MonitoringDeployment'
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    tags: tags
  }
}

// Deploy storage account for Logic Apps Standard runtime
module data 'data/main.bicep' = {
  name: 'DataDeployment'
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    tags: tags
  }
}

// Deploy Service Bus namespace for messaging integration
module messaging 'messaging/main.bicep' = {
  name: 'MessagingDeployment'
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: data.outputs.LOGS_STORAGE_ACCOUNT_ID
    tags: tags
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_ID string = data.outputs.LOGS_STORAGE_ACCOUNT_ID

@description('Name of the deployed storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_NAME string = data.outputs.LOGS_STORAGE_ACCOUNT_NAME

@description('Resource ID of the Log Analytics workspace for Logic Apps diagnostic logging configuration')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the Log Analytics workspace for reference and manual KQL queries')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Name of the deployed Application Insights instance for Logic Apps app settings and telemetry')
output AZURE_APPLICATION_INSIGHTS_NAME string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Resource ID of the deployed Application Insights instance for RBAC assignments')
output AZURE_APPLICATION_INSIGHTS_ID string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_ID

@description('Connection string for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY
