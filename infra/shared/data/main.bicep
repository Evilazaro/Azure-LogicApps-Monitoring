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
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot' // Hot tier for frequently accessed workflow data
    supportsHttpsTrafficOnly: true // Require secure connections
    minimumTlsVersion: 'TLS1_2' // Enforce TLS 1.2 minimum for security compliance
    allowBlobPublicAccess: true // Disable anonymous public access
    publicNetworkAccess: 'Enabled' // Allow access from public networks
    allowSharedKeyAccess: true // Required for Logic Apps Standard initial connection
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
  }
}

// Role assignments for managed identity to access storage account
// Required for Logic Apps Standard runtime with managed identity authentication
var storageRoles = {
  StorageBlobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  StorageQueueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  StorageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  StorageFileDataSMBShareContributor: '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
}

@description('Assign Storage Blob Data Owner role to managed identity')
resource blobOwnerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(wfSA.id, userAssignedIdentityId, storageRoles.StorageBlobDataOwner)
  scope: wfSA
  properties: {
    principalId: reference(userAssignedIdentityId, '2025-01-31-preview').principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageRoles.StorageBlobDataOwner
    )
    principalType: 'ServicePrincipal'
  }
}

@description('Assign Storage Queue Data Contributor role to managed identity')
resource queueContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(wfSA.id, userAssignedIdentityId, storageRoles.StorageQueueDataContributor)
  scope: wfSA
  properties: {
    principalId: reference(userAssignedIdentityId, '2025-01-31-preview').principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageRoles.StorageQueueDataContributor
    )
    principalType: 'ServicePrincipal'
  }
}

@description('Assign Storage Table Data Contributor role to managed identity')
resource tableContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(wfSA.id, userAssignedIdentityId, storageRoles.StorageTableDataContributor)
  scope: wfSA
  properties: {
    principalId: reference(userAssignedIdentityId, '2025-01-31-preview').principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageRoles.StorageTableDataContributor
    )
    principalType: 'ServicePrincipal'
  }
}

@description('Assign Storage File Data SMB Share Contributor role to managed identity for file share access')
resource fileContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(wfSA.id, userAssignedIdentityId, storageRoles.StorageFileDataSMBShareContributor)
  scope: wfSA
  properties: {
    principalId: reference(userAssignedIdentityId, '2025-01-31-preview').principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageRoles.StorageFileDataSMBShareContributor
    )
    principalType: 'ServicePrincipal'
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

@description('Name of the deployed storage account for Logic Apps workflows')
output AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW string = wfSA.name

@description('Resource ID of the deployed storage account for Logic Apps workflows')
output AZURE_STORAGE_ACCOUNT_ID_WORKFLOW string = wfSA.id

@description('Confirmation that all storage role assignments are complete')
output STORAGE_ROLE_ASSIGNMENTS_COMPLETE bool = blobOwnerRole.id != '' && queueContributorRole.id != '' && tableContributorRole.id != '' && fileContributorRole.id != ''

resource sqlServer 'Microsoft.Sql/servers@2024-11-01-preview' = {
  name: toLower('${cleanedName}server${uniqueSuffix}')
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    primaryUserAssignedIdentityId: userAssignedIdentityId
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      // 'Application' principal type is used for both Managed Identities and Service Principals
      // This allows the managed identity to administer the SQL Server using Entra ID authentication
      principalType: 'Application'
      login: deployer().userPrincipalName
      sid: deployer().objectId
      tenantId: tenant().tenantId
    }
    publicNetworkAccess: 'Enabled' // Can be restricted based on requirements
    minimalTlsVersion: '1.2'
  }
  tags: tags
}

@description('Fully qualified domain name of the deployed SQL Server')
output ORDERSDATABASE_SQLSERVERFQDN string = sqlServer.properties.fullyQualifiedDomainName

@description('Name of the deployed SQL Server instance')
output AZURE_SQL_SERVER_NAME string = sqlServer.name

// Enforce Entra ID-only authentication for SQL Server
// Disables SQL authentication to enhance security
@description('Entra-only authentication configuration for SQL Server')
resource entraOnlyAuth 'Microsoft.Sql/servers/azureADOnlyAuthentications@2024-11-01-preview' = {
  parent: sqlServer
  name: 'Default' // The name for this resource is typically 'Default'
  properties: {
    azureADOnlyAuthentication: true
  }
}

@description('Allow Azure services to access SQL Server')
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2024-11-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database resource for application data
@description('SQL Database for storing application data')
resource sqlDb 'Microsoft.Sql/servers/databases@2024-11-01-preview' = {
  name: 'OrderDb'
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
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368 // 32 GB
    zoneRedundant: false
  }
  tags: tags
}

@description('Name of the deployed SQL Database')
output AZURE_SQL_DATABASE_NAME string = sqlDb.name

// Enable diagnostic settings for SQL Database
@description('Diagnostic settings for SQL Database')
resource sqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlDb.name}-diag'
  scope: sqlDb
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}
