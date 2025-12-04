@description('Base name for Service Bus namespace.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
param envName string

@description('Azure region for Service Bus deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Resource tags applied to Service Bus resources.')
param tags object

@description('Name of the storage queue for tax processing workflow tasks')
@minLength(3)
@maxLength(63)
param queueName string = 'taxprocessing'

var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)
var storageAccountName = take('${cleanedName}${uniqueSuffix}stg', 24)

var storageConfig = {
  sku: 'Standard_LRS'
  kind: 'StorageV2'
  accessTier: 'Hot'
  minimumTlsVersion: 'TLS1_2'
  supportsHttpsTrafficOnly: true
}

resource workflowSA 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: length(storageAccountName) >= 3 ? storageAccountName : '${storageAccountName}stg'
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
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  name: 'default'
  parent: workflowSA
}

resource taxProcessing 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' = {
  name: queueName
  parent: queueServices
}

resource storageDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workflowSA.name}-diag'
  scope: workflowSA
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

resource queueServiceDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${queueServices.name}-diag'
  scope: queueServices
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'StorageRead'
        enabled: true
      }
      {
        category: 'StorageWrite'
        enabled: true
      }
      {
        category: 'StorageDelete'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
    ]
  }
}

@description('Name of the deployed storage account')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = workflowSA.name

@description('Resource ID of the deployed storage account')
output WORKFLOW_STORAGE_ACCOUNT_ID string = workflowSA.id
