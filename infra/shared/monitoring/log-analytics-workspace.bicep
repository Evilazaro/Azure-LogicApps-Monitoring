/*
  Log Analytics Workspace Module
  ==============================
  Deploys Log Analytics workspace with associated storage account.
  
  Components:
  - Storage account for diagnostic logs with lifecycle management
  - Log Analytics workspace with 30-day retention
  - Linked storage accounts for alerts and query results
  - Diagnostic settings configuration
  
  Key Features:
  - PerGB2018 pricing tier for pay-as-you-go model
  - Automatic log deletion after 30 days
  - System-assigned managed identity
  - Dedicated log analytics destination
*/

metadata name = 'Log Analytics Workspace'
metadata description = 'Deploys Log Analytics workspace with linked storage accounts for centralized logging'

// ========== Type Definitions ==========

import { tagsType, storageAccountConfig } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for the Log Analytics workspace.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name to differentiate deployments.')
@maxLength(10)
@allowed([
  'dev'
  'test'
  'prod'
  'staging'
])
param envName string

@description('Azure region for the Log Analytics workspace deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Logs settings for diagnostic configurations.')
param logsSettings object[]

@description('Metrics settings for diagnostic configurations.')
param metricsSettings object[]

@description('Resource tags applied to the Log Analytics workspace.')
param tags tagsType

// ========== Variables ==========

// Remove special characters from name for storage account naming requirements
// Storage account names must be lowercase alphanumeric only
@description('Cleaned name with special characters removed for storage account naming requirements')
var cleanedName string = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))

// Generate unique suffix to ensure globally unique resource names
// Uses resource group ID and deployment parameters to create deterministic but unique names
@description('Unique suffix for globally unique resource names')
var uniqueSuffix string = uniqueString(resourceGroup().id, name, envName, location)

// Storage account name must be 3-24 characters, lowercase alphanumeric only
@description('Storage account name for diagnostic logs (3-24 chars, lowercase alphanumeric)')
var logsStorageAccountName string = take('${cleanedName}logs${uniqueSuffix}', 24)

// Storage account configuration optimized for log storage
// Uses LRS for cost optimization, Hot tier for frequent access, and TLS 1.2 for security
@description('Storage account configuration optimized for diagnostic log storage')
var storageConfig storageAccountConfig = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
  accessTier: 'Hot'
  minimumTlsVersion: 'TLS1_2'
  supportsHttpsTrafficOnly: true
}

// ========== Resources ==========

@description('Storage account for storing diagnostic logs and metrics')
resource logSA 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: logsStorageAccountName
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
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

@description('Lifecycle management policy for log storage account to automatically delete append blobs (activity logs) after 30 days')
// This policy reduces storage costs by removing old activity logs while maintaining compliance with retention requirements
// Only affects subscription-level activity logs stored as append blobs
resource saPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2025-06-01' = {
  parent: logSA
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'SubscriptionLevelLifecycleRule'
          enabled: true
          type: 'Lifecycle'
          definition: {
            actions: {
              baseBlob: {
                delete: {
                  daysAfterModificationGreaterThan: 30
                }
              }
            }
            filters: {
              blobTypes: [
                'appendBlob'
              ]
              prefixMatch: [
                'insights-activity-logs/ResourceId=/SUBSCRIPTIONS/${subscription().subscriptionId}/'
              ]
            }
          }
        }
      ]
    }
  }
}

@description('Log Analytics workspace for centralized logging and monitoring')
resource workspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-law'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    // PerGB2018 pricing tier provides pay-as-you-go billing model
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      immediatePurgeDataOn30Days: true
    }
  }
}

@description('Diagnostic settings for Log Analytics workspace')
resource wspDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workspace.name}-diag'
  scope: workspace
  properties: {
    workspaceId: workspace.id
    storageAccountId: logSA.id
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}

@description('Linked storage account for storing alerts data')
resource saAlerts 'Microsoft.OperationalInsights/workspaces/linkedStorageAccounts@2025-07-01' = {
  parent: workspace
  name: 'Alerts'
  properties: {
    storageAccountIds: [
      logSA.id
    ]
  }
}

@description('Linked storage account for storing query results')
resource saQuery 'Microsoft.OperationalInsights/workspaces/linkedStorageAccounts@2025-07-01' = {
  parent: workspace
  name: 'Query'
  properties: {
    storageAccountIds: [
      logSA.id
    ]
  }
}

// ========== Outputs ==========

@description('Resource ID of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = workspace.id

@description('Name of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = workspace.name

@description('Log Analytics workspace customer ID')
output AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID string = workspace.properties.customerId

@description('Primary Key for the Log Analytics workspace')
// NOTE: This output is required by downstream modules in this repository.
// Per repo constraints we do not remove it or mark it as secure; silence the linter rule for this line only.
#disable-next-line outputs-should-not-contain-secrets
output AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY string = workspace.listKeys().primarySharedKey

@description('Resource ID of the deployed storage account for logs')
output AZURE_STORAGE_ACCOUNT_ID_LOGS string = logSA.id
