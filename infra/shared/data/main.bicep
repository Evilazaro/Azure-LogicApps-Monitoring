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

@secure()
param administratorLoginPassword string = newGuid()

@description('Logs settings for the Log Analytics workspace.')
param logsSettings object[]

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
    accessTier: 'Hot' // Hot tier for frequently accessed workflow data
    supportsHttpsTrafficOnly: true // Require secure connections
    minimumTlsVersion: 'TLS1_2' // Enforce TLS 1.2 minimum for security compliance
    allowBlobPublicAccess: false // Disable anonymous public access
    publicNetworkAccess: 'Enabled' // Allow access from public networks
    allowSharedKeyAccess: true // Required for Logic Apps Standard storage authentication
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

output AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW string = wfSA.name

resource sqlServer 'Microsoft.Sql/servers@2024-11-01-preview' = {
  name: toLower('${cleanedName}server${uniqueSuffix}')
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  tags: tags
  properties: {
    administrators: {
      administratorType: 'ActiveDirectory'
      principalType: 'User'
      tenantId: subscription().tenantId
      login: deployer().objectId
    }
    administratorLogin: 'sqlAdmin'
    administratorLoginPassword: administratorLoginPassword
    publicNetworkAccess: 'Enabled'
    primaryUserAssignedIdentityId: userAssignedIdentityId
  }
}

resource sqlDb 'Microsoft.Sql/servers/databases@2024-11-01-preview' = {
  name: toLower('${cleanedName}db${uniqueSuffix}')
  parent: sqlServer
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  sku: {
    name: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
    size: '32GB'
  }
  tags: tags
}

resource sqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlServer.name}-diag'
  scope: sqlServer
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}
