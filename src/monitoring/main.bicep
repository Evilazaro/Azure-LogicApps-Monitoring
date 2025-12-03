// ============================================================================
// MONITORING MODULE - Main Orchestration
// ============================================================================
// This module orchestrates the deployment of Azure monitoring infrastructure
// including Azure Monitor Health Model, Log Analytics Workspace, and 
// Application Insights for Logic Apps Standard observability and diagnostics.
// ============================================================================

@description('Base name for all monitoring resources. Used to generate unique resource names with consistent prefixes.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
@minLength(2)
@maxLength(10)
param envName string

@description('Azure region for monitoring resources deployment. Should match the Logic App deployment region for optimal performance.')
@minLength(3)
param location string = resourceGroup().location

@description('Resource tags applied to all monitoring resources for cost tracking, organization, and compliance.')
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

// Deploy Azure Monitor Health Model for hierarchical resource organization
module healthModel 'azure-monitor-health-model.bicep' = {
  scope: resourceGroup()
  params: {
    name: name
    tags: tags
  }
}

// Deploy Log Analytics Workspace (30-day retention, PerGB2018 pricing tier)
module operationalInsights 'log-analytics-workspace.bicep' = {
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    tags: tags
  }
  dependsOn: [
    healthModel
  ]
}

// Deploy Application Insights with workspace integration (workspace-based model)
module insights 'app-insights.bicep' = {
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    logAnalyticsWorkspaceId: operationalInsights.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    tags: tags
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the Log Analytics workspace for configuring diagnostic settings on Azure resources')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = operationalInsights.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the deployed Application Insights instance for Logic Apps app settings configuration')
output AZURE_APPLICATION_INSIGHTS_NAME string = insights.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Resource ID of the deployed Application Insights instance for RBAC assignments')
output AZURE_APPLICATION_INSIGHTS_ID string = insights.outputs.AZURE_APPLICATION_INSIGHTS_ID

@description('Connection string for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = insights.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
@secure()
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = insights.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

@description('Name of the deployed Log Analytics workspace for reference and manual queries')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = operationalInsights.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Resource ID of the storage account for diagnostic logs and metrics (deployed in monitoring module)')
output LOGS_STORAGE_ACCOUNT_ID string = operationalInsights.outputs.LOGS_STORAGE_ACCOUNT_ID

@description('Name of the deployed storage account for diagnostic logs and metrics (deployed in monitoring module)')
output LOGS_STORAGE_ACCOUNT_NAME string = operationalInsights.outputs.LOGS_STORAGE_ACCOUNT_NAME
