// ========== Parameters ==========

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

@description('Resource ID of the User Assigned Identity to be used by Service Bus.')
@minLength(50)
param userAssignedIdentityId string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Logs settings for the Log Analytics workspace.')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace.')
param metricsSettings object[]

@description('Resource tags applied to Service Bus resources.')
param tags object = {}

@description('Name of the storage queue for tax processing workflow tasks')
@minLength(3)
@maxLength(63)
param queueName string = 'orders-queue'

// ========== Variables ==========

var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)
var serviceBusName = toLower(take('${cleanedName}sb${uniqueSuffix}', 20))

// ========== Resources ==========

resource broker 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Premium'
    tier: 'Premium'
    capacity: 16
  }
  tags: tags
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
}

resource orders 'Microsoft.ServiceBus/namespaces/queues@2025-05-01-preview' = {
  name: queueName
  parent: broker
}

resource sbDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${broker.name}-diag'
  scope: broker
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}

resource wfSA 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: toLower('${cleanedName}wsa${uniqueSuffix}')
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  name: 'default'
  parent: wfSA
}

resource poSuccess 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  name: 'ordersprocessedsuccessfully'
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource poFailed 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  name: 'ordersprocessedwitherrors'
  parent: blobSvc
  properties: {
    publicAccess: 'None'
  }
}

resource saDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${wfSA.name}-diag'
  scope: wfSA
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

// ========== Outputs ==========

@description('Name of the deployed storage account')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = wfSA.name

@description('Resource ID of the deployed storage account')
output WORKFLOW_STORAGE_ACCOUNT_ID string = wfSA.id
