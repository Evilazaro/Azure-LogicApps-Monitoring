/*
  Storage Infrastructure Module
  =============================
  Deploys Azure Storage Account with Azure Files share for Container Apps persistent storage.
  
  Components:
  1. Storage Account (Standard_LRS) with Azure Files enabled
  2. File Share for orders-api persistent data
  
  Key Features:
  - SMB 3.0 protocol support for Orders API Volume Mounting
  - Secure transfer required (HTTPS/SMB 3.0)
  - TLS 1.2 minimum version
  - Hot access tier for frequently accessed data
  - Diagnostic logging to Log Analytics
*/

metadata name = 'Storage Infrastructure'
metadata description = 'Deploys Azure Storage Account and File Share for Container Apps persistent storage'

// ========== Type Definitions ==========

import { tagsType } from '../../../types.bicep'

// ========== Parameters ==========

@description('Base name for the storage account.')
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

@description('Azure region for storage deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Resource ID of the User Assigned Identity for role assignments.')
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

@description('Resource tags applied to storage resources.')
param tags tagsType

// ========== Variables ==========

// Remove special characters for naming compliance
var cleanedName string = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))

// Generate unique suffix for globally unique storage account name
var uniqueSuffix string = uniqueString(resourceGroup().id, name, envName, location)

// Storage account name: max 24 chars, alphanumeric only
var storageAccountName string = toLower('${cleanedName}fs${uniqueSuffix}')

// File share name for orders-api persistent storage
var fileShareName string = 'orders-data'

// ========== Resources ==========

@description('Storage account for Container Apps persistent file storage')
resource caSA 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
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
    encryption: {
      services: {
        file: {
          enabled: true
          keyType: 'Account'
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

@description('File service for the storage account')
resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  parent: caSA
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

@description('File share for orders-api persistent data storage')
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  parent: fileService
  name: fileShareName
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 5120 // 5 GB
    enabledProtocols: 'SMB' // SMB protocol for Container Apps
  }
}

@description('Diagnostic settings for storage account')
resource storageAccountDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${caSA.name}-diag'
  scope: caSA
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

// ========== Outputs ==========

@description('Name of the storage account')
output ORDERS_STORAGE_ACCOUNT_NAME string = caSA.name

@description('Orders Storage Account Blob Endpoint')
output DATA_BLOBENDPOINT string = caSA.properties.primaryEndpoints.blob

@description('Name of the file share')
output ORDERS_FILE_SHARE_NAME string = fileShare.name

@description('Primary key of the storage account for Orders API Volume Mount')
#disable-next-line outputs-should-not-contain-secrets
output ORDERS_STORAGE_ACCOUNT_KEY string = caSA.listKeys().keys[0].value
