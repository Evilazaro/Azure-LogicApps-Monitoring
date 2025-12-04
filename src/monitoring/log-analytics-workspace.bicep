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

@description('Resource tags applied to the Log Analytics workspace.')
param tags object

var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)
var logsStorageAccountName = take('${cleanedName}logs${uniqueSuffix}stg', 24)

var storageConfig = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
  accessTier: 'Hot'
  minimumTlsVersion: 'TLS1_2'
  supportsHttpsTrafficOnly: true
}

resource logsSA 'Microsoft.Storage/storageAccounts@2025-06-01' = {
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
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

@description('Name of the deployed storage account for logs')
output LOGS_STORAGE_ACCOUNT_NAME string = logsSA.name

@description('Resource ID of the deployed storage account for logs')
output LOGS_STORAGE_ACCOUNT_ID string = logsSA.id

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
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
  dependsOn: [
    logsSA
  ]
}

@description('Resource ID of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalytics.id

@description('Name of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = logAnalytics.name

