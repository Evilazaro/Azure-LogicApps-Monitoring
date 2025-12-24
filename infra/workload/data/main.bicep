/*
  Data Infrastructure Module
  ==========================
  Deploys storage infrastructure for Logic Apps and Container Apps.
  
  Components:
  1. Storage account for Logic Apps runtime (Standard tier requirement)
  2. Blob containers for processed orders (success/error segregation)
  3. Azure Files storage for Container Apps persistent volumes
  
  Key Features:
  - Separate containers for success and error order processing
  - Azure Files share for orders-api persistent data
  - Integrated diagnostic logging
*/

metadata name = 'Data Infrastructure'
metadata description = 'Storage accounts and containers for workflow data and Container Apps persistent storage'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for Service Bus namespace.')
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

@description('Metrics settings for the Log Analytics workspace.')
param metricsSettings object[]

@description('Resource tags applied to Service Bus resources.')
param tags tagsType

// Remove special characters for naming compliance
var cleanedName string = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))

// Generate unique suffix for globally unique resource names
var uniqueSuffix string = uniqueString(resourceGroup().id, name, envName, location)

@description('Storage account for Logic Apps workflows and data')
resource wfSA 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: toLower('${cleanedName}wsa${uniqueSuffix}')
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

@description('Blob service for workflow storage account')
resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  parent: wfSA
  name: 'default'
}

// Container for successfully processed orders
// Segregates successful processing for audit and compliance
@description('Blob container for successfully processed orders')
resource poSuccess 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobSvc
  name: 'ordersprocessedsuccessfully'
  properties: {
    publicAccess: 'None'
  }
}

// Container for failed order processing
// Enables separate error handling and retry workflows
@description('Blob container for orders processed with errors')
resource poFailed 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobSvc
  name: 'ordersprocessedwitherrors'
  properties: {
    publicAccess: 'None'
  }
}

@description('Diagnostic settings for workflow storage account')
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

output WORKFLOW_STORAGE_ACCOUNT_NAME string = wfSA.name

module volumeStorage 'storage/main.bicep' = {
  params: {
    name: name
    tags: tags
    envName: envName
    metricsSettings: metricsSettings 
    storageAccountId: storageAccountId
    userAssignedIdentityId: userAssignedIdentityId
    workspaceId: workspaceId
  }
}

// ========== Outputs ==========

@description('Name of the storage account')
output ORDERS_STORAGE_ACCOUNT_NAME string = volumeStorage.outputs.ORDERS_STORAGE_ACCOUNT_NAME

@description('Orders Storage Account Blob Endpoint')
output DATA_BLOBENDPOINT string = volumeStorage.outputs.DATA_BLOBENDPOINT

@description('Name of the file share')
output ORDERS_FILE_SHARE_NAME string = volumeStorage.outputs.ORDERS_FILE_SHARE_NAME

@description('Primary key of the storage account for Orders API Volume Mount')
#disable-next-line outputs-should-not-contain-secrets
output ORDERS_STORAGE_ACCOUNT_KEY string = volumeStorage.outputs.ORDERS_STORAGE_ACCOUNT_KEY
