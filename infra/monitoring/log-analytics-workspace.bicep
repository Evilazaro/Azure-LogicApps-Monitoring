// ========== Type Definitions ==========

@description('Storage account configuration')
type storageAccountConfig = {
  @description('Storage account SKU')
  sku: 'Standard_LRS' | 'Standard_GRS' | 'Standard_RAGRS' | 'Standard_ZRS'
  
  @description('Storage account kind')
  kind: 'StorageV2' | 'BlobStorage' | 'BlockBlobStorage'
  
  @description('Access tier for the storage account')
  accessTier: 'Hot' | 'Cool'
  
  @description('Minimum TLS version')
  minimumTlsVersion: 'TLS1_0' | 'TLS1_1' | 'TLS1_2'
  
  @description('Whether HTTPS traffic only is supported')
  supportsHttpsTrafficOnly: bool
}

// ========== Parameters ==========

@description('Base name for the Log Analytics workspace.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
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
param tags object = {}

// ========== Variables ==========

var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)
var logsStorageAccountName = take('${cleanedName}logs${uniqueSuffix}', 24)

var configSA = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
  accessTier: 'Hot'
  minimumTlsVersion: 'TLS1_2'
  supportsHttpsTrafficOnly: true
}

// ========== Resources ==========

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

@description('Resource ID of the deployed storage account for logs')
output LOGS_STORAGE_ACCOUNT_ID string = logSA.id

resource saPolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2025-06-01' = {
  name: 'default'
  parent: logSA
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

resource saAlerts 'Microsoft.OperationalInsights/workspaces/linkedstorageaccounts@2025-02-01' = {
  parent: workspace
  name: 'Alerts'
  properties: {
    storageAccountIds: [
      logSA.id
    ]
  }
}

resource saQuery 'Microsoft.OperationalInsights/workspaces/linkedstorageaccounts@2025-02-01' = {
  parent: workspace
  name: 'Query'
  properties: {
    storageAccountIds: [
      logSA.id
    ]
  }
}
