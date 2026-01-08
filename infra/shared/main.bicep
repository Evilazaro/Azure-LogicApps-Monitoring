/*
  Shared Infrastructure Module
  ============================
  Orchestrates deployment of shared infrastructure components.
  
  Components:
  - Identity: User-assigned managed identity with role assignments
  - Monitoring: Log Analytics workspace and Application Insights
  - Data: Storage accounts and SQL Server database
  
  Deployment Order:
  - Identity first (required by other modules)
  - Monitoring second (provides workspace IDs for diagnostics)
  - Data last (depends on identity and monitoring outputs)
*/

metadata name = 'Shared Infrastructure'
metadata description = 'Deploys identity, monitoring, and data infrastructure for the solution'

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
param envName string

@description('Resource tags applied to the managed identity.')
param tags tagsType

// ========== Variables ==========

// Diagnostic settings for comprehensive logging across all resources
// Captures all log categories for centralized monitoring
@description('Diagnostic settings configuration for capturing all log categories')
var allLogsSettings object[] = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

// Diagnostic settings for comprehensive metrics across all resources
// Captures all metric categories for performance monitoring
@description('Diagnostic settings configuration for capturing all metric categories')
var allMetricsSettings object[] = [
  {
    categoryGroup: 'allMetrics'
    enabled: true
  }
]

// ========== Modules ==========

module network 'network/main.bicep' = {
  params: {
    name: '${name}-vnet-${envName}'
    location: location
    tags: tags
  }
}

// Identity Module: Deploys user-assigned managed identity
// Must be deployed first as other modules depend on its output
@description('Deploys user-assigned managed identity with role assignments')
module identity 'identity/main.bicep' = {
  params: {
    name: name
    location: location
    tags: tags
    envName: envName
  }
  dependsOn: [
    network
  ]
}

// ========== Identity Outputs ==========

@description('Resource ID of the deployed managed identity (internal use only)')
output AZURE_MANAGED_IDENTITY_ID string = identity.outputs.AZURE_MANAGED_IDENTITY_ID

@description('Managed Identity ClientId (internal use only)')
output MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.MANAGED_IDENTITY_CLIENT_ID

@description('Name of the managed identity resource')
output MANAGED_IDENTITY_NAME string = identity.outputs.MANAGED_IDENTITY_NAME

// Monitoring Module: Deploys Log Analytics workspace and Application Insights
// Provides centralized logging and telemetry infrastructure
@description('Deploys Log Analytics workspace and Application Insights for centralized monitoring')
module monitoring 'monitoring/main.bicep' = {
  params: {
    name: name
    location: location
    tags: tags
    envName: envName
  }
}

// ========== Monitoring Outputs ==========

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
output AZURE_STORAGE_ACCOUNT_ID_LOGS string = monitoring.outputs.AZURE_STORAGE_ACCOUNT_ID_LOGS

// Data Module: Deploys storage accounts and SQL Server
// Provides storage for workflows and persistent data
@description('Deploys storage accounts and SQL Server database for workflow data storage')
module data 'data/main.bicep' = {
  params: {
    name: name
    envName: envName
    location: location
    userAssignedIdentityId: identity.outputs.AZURE_MANAGED_IDENTITY_ID
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: monitoring.outputs.AZURE_STORAGE_ACCOUNT_ID_LOGS
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    dataSubnetId: network.outputs.DATA_SUBNET_ID
    vnetId: network.outputs.VNET_ID
    tags: tags
  }
}

// ========== Data Outputs ==========

@description('Storage account name for Logic Apps workflows and data')
output AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW string = data.outputs.AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW

@description('Resource ID of the storage account for Logic Apps workflows and data')
output AZURE_STORAGE_ACCOUNT_ID_WORKFLOW string = data.outputs.AZURE_STORAGE_ACCOUNT_ID_WORKFLOW

@description('Fully qualified domain name of the SQL Server for database connections')
output ORDERSDATABASE_SQLSERVERFQDN string = data.outputs.ORDERSDATABASE_SQLSERVERFQDN

@description('Name of the deployed SQL Server instance')
output AZURE_SQL_SERVER_NAME string = data.outputs.AZURE_SQL_SERVER_NAME

@description('Name of the deployed SQL Database')
output AZURE_SQL_DATABASE_NAME string = data.outputs.AZURE_SQL_DATABASE_NAME

// ========== Network Outputs ==========

@description('Resource ID of the API subnet for workload resources')
output API_SUBNET_ID string = network.outputs.API_SUBNET_ID

@description('Resource ID of the Web App subnet for workload resources')
output WEBAPP_SUBNET_ID string = network.outputs.WEB_APP_SUBNET_ID

@description('Resource ID of the Logic App subnet for Logic Apps Standard')
output LOGICAPP_SUBNET_ID string = network.outputs.logicappSubnetId
