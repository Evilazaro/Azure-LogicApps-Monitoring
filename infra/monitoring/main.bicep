metadata name = 'Monitoring Infrastructure'
metadata description = 'Deploys Log Analytics, Application Insights, and health monitoring for the solution'

// ========== Type Definitions ==========

import { tagsType } from '../types.bicep'

// (Note: Diagnostic settings use object[] instead of user-defined types 
// due to Azure Resource Provider schema requirements)

// ========== Parameters ==========

@description('Base name for all monitoring resources.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
@allowed([
  'local'
  'dev'
  'staging'
  'prod'
])
param envName string

@description('Azure region for monitoring resources deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Resource tags applied to all monitoring resources.')
param tags tagsType

// ========== Variables ==========

var allLogsSettings = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

var allMetricsSettings = [
  {
    categoryGroup: 'allMetrics'
    enabled: true
  }
]

// ========== Modules ==========

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

module healthModel 'azure-monitor-health-model.bicep' = {
  params: {
    name: name
    tags: tags
  }
  dependsOn: [
    operational
  ]
}

module insights 'app-insights.bicep' = {
  params: {
    name: name
    envName: envName
    location: location
    logAnalyticsWorkspaceId: operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: operational.outputs.LOGS_STORAGE_ACCOUNT_ID
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
@secure()
output AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY string = operational.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY

// Application Insights Outputs (Microsoft.Insights/components)
@description('Name of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = insights.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Resource ID of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_ID string = insights.outputs.AZURE_APPLICATION_INSIGHTS_ID

@description('Connection string for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = insights.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = insights.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

// Storage Account Outputs (Microsoft.Storage/storageAccounts)
@description('Resource ID of the storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_ID string = operational.outputs.LOGS_STORAGE_ACCOUNT_ID
