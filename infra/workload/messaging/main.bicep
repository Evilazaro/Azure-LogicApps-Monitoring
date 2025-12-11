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

// resource wfSA 'Microsoft.Storage/storageAccounts@2025-06-01' = {
//   name: storageAccountName
//   location: location
//   sku: {
//     name: saConf.sku
//   }
//   kind: saConf.kind
//   tags: tags
//   properties: {
//     accessTier: saConf.accessTier
//     supportsHttpsTrafficOnly: saConf.supportsHttpsTrafficOnly
//     minimumTlsVersion: saConf.minimumTlsVersion
//     allowBlobPublicAccess: true
//     publicNetworkAccess: 'Enabled'
//     allowSharedKeyAccess: true
//     networkAcls: {
//       bypass: 'AzureServices'
//       defaultAction: 'Allow'
//     }
//   }
// }

// resource qSvc 'Microsoft.Storage/storageAccounts/queueServices@2025-06-01' = {
//   name: 'default'
//   parent: wfSA
// }

// resource poProcQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-06-01' = {
//   name: queueName
//   parent: qSvc
// }

// resource blogSvc 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
//   name: 'default'
//   parent: wfSA
// }

// resource poSuccess 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
//   name: 'ordersprocessedsuccessfully'
//   parent: blogSvc
//   properties: {
//     publicAccess: 'None'
//   }
// }

// resource poFailed 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
//   name: 'ordersprocessedwitherrors'
//   parent: blogSvc
//   properties: {
//     publicAccess: 'None'
//   }
// }

// var rolDefSA = {
//   contributor: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
//   blobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
//   queueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
//   tableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
//   fileDataContributor: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
// }

// var RolIdsSA = [
//   rolDefSA.contributor
//   rolDefSA.blobDataOwner
//   rolDefSA.queueDataContributor
//   rolDefSA.tableDataContributor
//   rolDefSA.fileDataContributor
// ]

// resource wfRaSA 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
//   for roleId in RolIdsSA: {
//     name: guid(deployer().objectId, deployer().tenantId, roleId)
//     scope: wfSA
//     properties: {
//       roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
//       principalId: deployer().objectId
//       principalType: 'User'
//     }
//   }
// ]

// resource saDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${wfSA.name}-diag'
//   scope: wfSA
//   properties: {
//     workspaceId: workspaceId
//     storageAccountId: storageAccountId
//     logAnalyticsDestinationType: 'Dedicated'
//     metrics: metricsSettings
//   }
// }

// resource qDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
//   name: '${qSvc.name}-diag'
//   scope: qSvc
//   properties: {
//     workspaceId: workspaceId
//     storageAccountId: storageAccountId
//     logAnalyticsDestinationType: 'Dedicated'
//     logs: logsSettings
//     metrics: metricsSettings
//   }
// }

// // ========== Outputs ==========

// @description('Name of the deployed storage account')
// output WORKFLOW_STORAGE_ACCOUNT_NAME string = wfSA.name

// @description('Resource ID of the deployed storage account')
// output WORKFLOW_STORAGE_ACCOUNT_ID string = wfSA.id
