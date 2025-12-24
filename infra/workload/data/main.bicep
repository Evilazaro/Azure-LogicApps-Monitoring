/*
  Data Infrastructure Module (CURRENTLY UNUSED)
  =============================================
  NOTE: This file appears to be orphaned and is not referenced by any parent modules.
  The functionality provided here is already covered by the messaging/main.bicep module.
  
  Consider removing this file or integrating it into the main deployment flow.
  
  Components:
  1. Storage account for Logic Apps runtime (Standard tier requirement)
  2. Blob containers for processed orders (success/error segregation)
  
  Key Features:
  - Separate containers for success and error order processing
*/

metadata name = 'Data Infrastructure (Unused)'
metadata description = 'Storage account and blob containers for workflow data - Currently not deployed'

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
var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))

// Generate unique suffix for globally unique resource names
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)

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
    allowBlobPublicAccess: true
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
output CA_STORAGE_ACCOUNT_NAME string = volumeStorage.outputs.CA_STORAGE_ACCOUNT_NAME

@description('Resource ID of the storage account')
output CA_STORAGE_ACCOUNT_ID string = volumeStorage.outputs.CA_STORAGE_ACCOUNT_ID

@description('Name of the file share')
output CA_FILE_SHARE_NAME string = volumeStorage.outputs.CA_FILE_SHARE_NAME

@description('Storage account endpoint for Azure Files')
output CA_FILE_ENDPOINT string = volumeStorage.outputs.CA_FILE_ENDPOINT

@description('Primary key of the storage account for Container Apps mount')
#disable-next-line outputs-should-not-contain-secrets
output CA_STORAGE_ACCOUNT_KEY string = volumeStorage.outputs.CA_STORAGE_ACCOUNT_KEY
