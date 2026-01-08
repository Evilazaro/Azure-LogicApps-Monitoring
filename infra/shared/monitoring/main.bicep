/*
  Monitoring Infrastructure Module
  ================================
  Orchestrates deployment of all monitoring and observability components.
  
  Components:
  - Log Analytics workspace with linked storage accounts
  - Application Insights for telemetry collection
  - Azure Monitor health model for service hierarchy
  
  Key Features:
  - Centralized logging with 30-day retention
  - Workspace-based Application Insights integration
  - Diagnostic settings for all resources
*/

metadata name = 'Monitoring Infrastructure'
metadata description = 'Deploys Log Analytics, Application Insights, and health monitoring for the solution'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// Note: Diagnostic settings use object[] instead of user-defined types
// due to Azure Resource Provider schema requirements

// ========== Parameters ==========

@description('Base name for all monitoring resources')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness')
@minLength(2)
@maxLength(10)
param envName string

@description('Azure region for monitoring resources deployment')
@minLength(3)
@maxLength(50)
param location string

@description('Resource tags applied to all monitoring resources')
param tags tagsType

// ========== Variables ==========

// Diagnostic settings configuration for comprehensive logging
// Captures all log categories from monitoring resources
@description('Diagnostic settings configuration for capturing all log categories')
var allLogsSettings object[] = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

// Diagnostic settings configuration for comprehensive metrics
// Captures all metric categories from monitoring resources
@description('Diagnostic settings configuration for capturing all metric categories')
var allMetricsSettings object[] = [
  {
    categoryGroup: 'allMetrics'
    enabled: true
  }
]

// ========== Modules ==========

// Log Analytics Workspace Module: Deploys workspace with linked storage
// Provides centralized logging infrastructure with 30-day retention
@description('Deploys Log Analytics workspace with linked storage accounts')
module operational 'log-analytics-workspace.bicep' = {
  params: {
    name: name
    envName: envName
    location: location
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    tags: tags
  }
}

// Azure Monitor Health Model Module: Creates service group hierarchy
// Enables hierarchical health monitoring across services
@description('Creates service group hierarchy for organizing health monitoring')
module healthModel 'azure-monitor-health-model.bicep' = {
  params: {
    name: name
    tags: tags
  }
  dependsOn: [
    operational
  ]
}

// Application Insights Module: Deploys workspace-based Application Insights
// Provides application telemetry and monitoring capabilities
@description('Deploys workspace-based Application Insights for application telemetry')
module insights 'app-insights.bicep' = {
  params: {
    name: name
    envName: envName
    location: location
    logAnalyticsWorkspaceId: operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: operational.outputs.AZURE_STORAGE_ACCOUNT_ID_LOGS
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    tags: tags
  }
}

// ========== Outputs ==========

// Log Analytics Workspace Outputs (Microsoft.OperationalInsights/workspaces)
@description('Resource ID of the Log Analytics workspace for configuring diagnostic settings')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Log Analytics workspace customer ID')
output AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID string = operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID

@description('Primary Key for the Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY string = operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY

// Application Insights Outputs (Microsoft.Insights/components)
@description('Name of the deployed Application Insights instance')
output APPLICATION_INSIGHTS_NAME string = insights.outputs.APPLICATION_INSIGHTS_NAME

@description('Connection string for Application Insights telemetry')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = insights.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
output APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = insights.outputs.APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

// Storage Account Outputs (Microsoft.Storage/storageAccounts)
@description('Resource ID of the storage account for diagnostic logs and metrics')
output AZURE_STORAGE_ACCOUNT_ID_LOGS string = operational.outputs.AZURE_STORAGE_ACCOUNT_ID_LOGS
