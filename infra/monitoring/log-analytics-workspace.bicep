metadata name = 'Log Analytics Workspace'
metadata description = 'Deploys Log Analytics workspace with linked storage accounts for centralized logging'

// ========== Type Definitions ==========

import { tagsType, storageAccountConfig } from '../types.bicep'

// ========== Parameters ==========

@description('Base name for the Log Analytics workspace.')
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

var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)
var logsStorageAccountName = take('${cleanedName}logs${uniqueSuffix}', 24)

var configSA storageAccountConfig = {
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
    name: configSA.sku
  }
  kind: configSA.kind
  tags: tags
  properties: {
    accessTier: configSA.accessTier
    supportsHttpsTrafficOnly: configSA.supportsHttpsTrafficOnly
    minimumTlsVersion: configSA.minimumTlsVersion
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// ========== Outputs ==========

@description('Lifecycle management policy for log storage account to delete old logs after 30 days')
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
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      immediatePurgeDataOn30Days: true
    }
  }
}

@description('Resource ID of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = workspace.id

@description('Name of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = workspace.name

@description('Log Analytics workspace customer ID')
output AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID string = workspace.properties.customerId

@description('Primary Key for the Log Analytics workspace')
@secure()
output AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY string = workspace.listKeys().primarySharedKey

@description('Resource ID of the deployed storage account for logs')
output LOGS_STORAGE_ACCOUNT_ID string = logSA.id

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
