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
  dependsOn: [
    monitoring
  ]
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
    tags: tags
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the deployed storage account for Logic Apps Standard runtime requirements')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = data.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME

@description('Resource ID of the deployed storage account for RBAC role assignments')
output WORKFLOW_STORAGE_ACCOUNT_ID string = data.outputs.WORKFLOW_STORAGE_ACCOUNT_ID

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

@description('Name of the deployed Service Bus namespace for Logic Apps messaging integration')
output AZURE_SERVICEBUS_NAMESPACE_NAME string = messaging.outputs.AZURE_SERVICEBUS_NAMESPACE_NAME

@description('Resource ID of the Service Bus namespace for RBAC role assignments to managed identity')
output AZURE_SERVICEBUS_NAMESPACE_ID string = messaging.outputs.AZURE_SERVICEBUS_NAMESPACE_ID

@description('Fully qualified endpoint of the Service Bus namespace for connection configuration')
output AZURE_SERVICEBUS_ENDPOINT string = messaging.outputs.AZURE_SERVICEBUS_ENDPOINT

@description('Name of the Service Bus queue for workflow message processing')
output AZURE_SERVICEBUS_QUEUE_NAME string = messaging.outputs.AZURE_SERVICEBUS_QUEUE_NAME
