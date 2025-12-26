// ========== Type Definitions ==========

import { tagsType } from '../types.bicep'

// ========== Parameters ==========

@description('Base name for the managed identity.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for managed identity deployment.')
@minLength(3)
@maxLength(50)
param location string

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

@description('Resource tags applied to the managed identity.')
param tags tagsType

// ========== Variables ==========

// Diagnostic settings configuration for comprehensive logging
// These settings are passed to child modules for consistent logging across all resources
// 'allLogs' captures all available log categories from each resource type
var allLogsSettings object[] = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

// Diagnostic settings configuration for comprehensive metrics collection
// 'allMetrics' captures all available metric categories from each resource type
var allMetricsSettings object[] = [
  {
    categoryGroup: 'allMetrics'
    enabled: true
  }
]

// ========== Modules ==========

// Identity Module: Deploys user-assigned managed identity
// Must be deployed first as other modules depend on its output for authentication
// Provides a single identity for all workload resources to use
module identity 'identity/main.bicep' = {
  params: {
    name: name
    location: location
    tags: tags
    envName: envName
  }
}
// Output the managed identity resource ID for use by workload modules
// This identity will be assigned to resources like SQL Server, Storage, Service Bus
@description('Resource ID of the deployed managed identity (internal use only)')
output AZURE_MANAGED_IDENTITY_ID string = identity.outputs.AZURE_MANAGED_IDENTITY_ID

// Monitoring Module: Deploys Log Analytics workspace and Application Insights
// Provides centralized logging and application telemetry for all resources
module monitoring 'monitoring/main.bicep' = {
  params: {
    name: name
    tags: tags
    envName: envName
  }
}

// ========== Outputs ==========

// Log Analytics Workspace Outputs (Microsoft.OperationalInsights/workspaces)
@description('Resource ID of the Log Analytics workspace for configuring diagnostic settings')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Log Analytics workspace customer ID')
output AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID

@description('Primary Key for the Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY

// Application Insights Outputs (Microsoft.Insights/components)
@description('Name of the deployed Application Insights instance')
output APPLICATION_INSIGHTS_NAME string = monitoring.outputs.APPLICATION_INSIGHTS_NAME

@description('Connection string for Application Insights telemetry')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = monitoring.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
output APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = monitoring.outputs.APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

// Storage Account Outputs (Microsoft.Storage/storageAccounts)
@description('Resource ID of the storage account for diagnostic logs and metrics')
output AZURE_STOARGE_ACCOUNT_ID_LOGS string = monitoring.outputs.AZURE_STOARGE_ACCOUNT_ID_LOGS

// Data Module: Deploys storage accounts and Azure SQL Database
// Depends on both identity (for authentication) and monitoring (for diagnostics)
// Provides data persistence layer for applications
module data 'data/main.bicep' = {
  params: {
    name: name
    envName: envName
    location: location
    // Pass the managed identity for SQL Server authentication and storage access
    userAssignedIdentityId: identity.outputs.AZURE_MANAGED_IDENTITY_ID
    // Configure diagnostic logging to send to Log Analytics workspace
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    // Archive diagnostic data to storage account for compliance
    storageAccountId: monitoring.outputs.AZURE_STOARGE_ACCOUNT_ID_LOGS
    // Configure the managed identity as SQL Server Entra (Azure AD) administrator
    entraAdminLoginName: identity.name
    entraAdminPrincipalId: identity.outputs.AZURE_MANAGED_IDENTITY_PRINCIPAL_ID
    // Use subscription tenant for Azure AD authentication
    tenantId: subscription().tenantId
    // Apply consistent logging and metrics settings
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    tags: tags
  }
}

@description('Storage account name for Logic Apps workflows and data')
output AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW string = data.outputs.AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW
