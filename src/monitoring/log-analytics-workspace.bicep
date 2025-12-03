// ============================================================================
// LOG ANALYTICS WORKSPACE MODULE
// ============================================================================
// Provides centralized log aggregation and analytics using Kusto Query Language (KQL).
// 
// Configuration:
// - SKU: PerGB2018 (pay-as-you-go pricing based on data ingested)
// - Retention: 30 days (configurable, balances cost and compliance)
// - Immediate Purge: Enabled (data deleted immediately after 30 days)
// - Identity: System-assigned managed identity for secure data access
//
// This workspace serves as the central repository for:
// - Logic Apps WorkflowRuntime logs
// - Application Insights telemetry
// - Service Bus diagnostic logs
// - App Service Plan metrics
//
// Reference: https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for the Log Analytics workspace. Will be suffixed with unique string and "-law" to ensure global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
param envName string

@description('Azure region for the Log Analytics workspace deployment. Should match application resources for optimal data transfer costs.')
param location string = resourceGroup().location

@description('Resource tags applied to the Log Analytics workspace for cost tracking, organization, and compliance.')
param tags object

// ============================================================================
// VARIABLES
// ============================================================================

// Generate a storage account name that meets Azure naming requirements:
// - Must be 3-24 characters long
// - Can contain only lowercase letters and numbers
// - Must be globally unique across all Azure Storage accounts
var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)

// Storage account configuration
var storageConfig = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
  accessTier: 'Hot'
  minimumTlsVersion: 'TLS1_2'
  supportsHttpsTrafficOnly: true
}

// ============================================================================
// RESOURCES
// ============================================================================

// Logs storage account - stores diagnostic logs separately from workflow data
var logsStorageAccountName = take('${cleanedName}logs${uniqueSuffix}stg', 24)

resource logsSA 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: length(logsStorageAccountName) >= 3 ? logsStorageAccountName : '${logsStorageAccountName}stg'
  location: location
  sku: {
    name: storageConfig.sku
  }
  kind: storageConfig.kind
  tags: tags
  properties: {
    accessTier: storageConfig.accessTier
    supportsHttpsTrafficOnly: storageConfig.supportsHttpsTrafficOnly
    minimumTlsVersion: storageConfig.minimumTlsVersion
    allowBlobPublicAccess: false // Logs don't need public access
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the deployed storage account for logs (generated with unique suffix for global uniqueness)')
output LOGS_STORAGE_ACCOUNT_NAME string = logsSA.name

@description('Resource ID of the deployed storage account for logs')
output LOGS_STORAGE_ACCOUNT_ID string = logsSA.id

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-law'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      immediatePurgeDataOn30Days: true
    }
  }
}

@description('Resource ID of the deployed Log Analytics workspace for diagnostic settings configuration')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.id

@description('Name of the deployed Log Analytics workspace for reference and queries')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.name
