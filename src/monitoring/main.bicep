// ============================================================================
// MONITORING MODULE ORCHESTRATOR
// ============================================================================
// Deploys the complete observability stack for Logic Apps:
// 1. Azure Monitor Health Model - Hierarchical service group organization
// 2. Log Analytics Workspace - Centralized log aggregation and KQL queries
// 3. Application Insights - APM, distributed tracing, and telemetry
//
// This module provides workspace-based Application Insights (best practice)
// integrated with Log Analytics for unified querying across all log sources.
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for all monitoring resources. Used to generate unique resource names with consistent prefixes.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
param envName string

@description('Azure region for monitoring resources deployment. Should match the Logic App deployment region for optimal performance.')
param location string = resourceGroup().location

@description('Resource tags applied to all monitoring resources for cost tracking, organization, and compliance.')
param tags object

// ============================================================================
// MODULE DEPLOYMENTS
// ============================================================================

// Deploy Azure Monitor Health Model for hierarchical resource organization
module healthModel 'azure-monitor-health-model.bicep' = {
  name: 'deployAzureMonitorHealthModel'
  scope: resourceGroup()
  params: {
    name: name
    tags: tags
  }
}

// Deploy Log Analytics Workspace (30-day retention, PerGB2018 pricing tier)
module operationalInsights 'log-analytics-workspace.bicep' = {
  name: 'deployLogAnalyticsWorkspace'
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
  name: 'deployAppInsights'
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
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = insights.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = insights.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

@description('Name of the deployed Log Analytics workspace for reference and manual queries')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = operationalInsights.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME
