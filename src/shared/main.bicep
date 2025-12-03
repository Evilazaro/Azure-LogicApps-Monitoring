// ============================================================================
// SHARED RESOURCES MODULE - Main Orchestration
// ============================================================================
// Orchestrates deployment of shared infrastructure components including:
// - Monitoring stack (Log Analytics, Application Insights, Health Model)
// - Messaging infrastructure (Storage accounts with queues for Logic Apps)
// These resources are shared across the workload tier.
// ============================================================================

@description('Base name for all shared resources. Used as prefix to ensure consistent naming across modules.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
@minLength(2)
@maxLength(10)
param envName string

@description('Azure region for shared resources deployment. Should match Logic App deployment region.')
@minLength(3)
param location string = resourceGroup().location

@description('Resource tags applied to all shared resources for cost tracking, organization, and compliance.')
@metadata({
  example: {
    Solution: 'tax-docs'
    Environment: 'prod'
  }
})
param tags object

// ============================================================================
// MODULE DEPLOYMENTS
// ============================================================================

// Deploy monitoring stack (Log Analytics, Application Insights, Health Model)
module monitoring '../monitoring/main.bicep' = {
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    tags: tags
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_ID string = monitoring.outputs.LOGS_STORAGE_ACCOUNT_ID

@description('Name of the deployed storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_NAME string = monitoring.outputs.LOGS_STORAGE_ACCOUNT_NAME

@description('Resource ID of the Log Analytics workspace for Logic Apps diagnostic logging configuration')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the Log Analytics workspace for reference and manual KQL queries')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Name of the deployed Application Insights instance for Logic Apps app settings and telemetry')
output AZURE_APPLICATION_INSIGHTS_NAME string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Resource ID of the deployed Application Insights instance for RBAC assignments')
output AZURE_APPLICATION_INSIGHTS_ID string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_ID

@description('Connection string for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY
