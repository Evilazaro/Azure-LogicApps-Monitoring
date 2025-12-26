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

var allLogsSettings object[] = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

var allMetricsSettings object[] = [
  {
    categoryGroup: 'allMetrics'
    enabled: true
  }
]

// Identity Module: Deploys user-assigned managed identity
// Must be deployed first as other modules depend on its output
module identity 'identity/main.bicep' = {
  params: {
    name: name
    location: location
    tags: tags
    envName: envName
  }
}
@description('Resource ID of the deployed managed identity (internal use only)')
output AZURE_MANAGED_IDENTITY_ID string = identity.outputs.AZURE_MANAGED_IDENTITY_ID

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

// Storage Account Outputs (Microsoft.Storage/storageAccounts)
@description('Resource ID of the storage account for diagnostic logs and metrics')
output LOGS_STORAGE_ACCOUNT_ID string = monitoring.outputs.LOGS_STORAGE_ACCOUNT_ID

module data 'data/main.bicep' = {
  params: {
    name: name
    envName: envName
    location: location
    userAssignedIdentityId: identity.outputs.AZURE_MANAGED_IDENTITY_ID
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: monitoring.outputs.LOGS_STORAGE_ACCOUNT_ID
    administratorLoginPassword: '123#@!qweEWQ' // Replace with secure parameter or Key Vault reference in production
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    tags: tags
  }
}

@description('Storage account name for Logic Apps workflows and data')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = data.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
