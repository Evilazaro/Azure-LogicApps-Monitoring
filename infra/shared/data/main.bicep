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

@description('Principal ID (Object ID) of the Managed Identity to be used as SQL Server Entra admin')
param entraAdminPrincipalId string

@description('Name of the Managed Identity to be used as SQL Server Entra admin')
param entraAdminLoginName string

@description('Tenant ID for Microsoft Entra authentication')
param tenantId string = subscription().tenantId

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

// Azure SQL Server with Azure AD-only authentication (Entra ID)
// Eliminates SQL authentication for enhanced security posture
// Uses managed identity for administration and application access
@description('Azure SQL Server with Entra ID (Azure AD) authentication only')
resource sqlServer 'Microsoft.Sql/servers@2024-11-01-preview' = {
  name: toLower('${cleanedName}server${uniqueSuffix}')
  location: location
  identity: {
    // User-assigned managed identity for Azure AD authentication
    // Enables passwordless authentication for applications
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    // Designate the managed identity as the primary identity for this server
    // Required for Azure AD-only authentication mode
    primaryUserAssignedIdentityId: userAssignedIdentityId
    administrators: {
      // Configure Azure AD (Entra ID) admin for the SQL Server
      // This admin has full permissions on all databases
      administratorType: 'ActiveDirectory'
      // Enforce Azure AD-only authentication - disables SQL authentication
      // Improves security by eliminating password-based authentication
      azureADOnlyAuthentication: true
      // 'Application' principal type is used for Managed Identities and Service Principals
      // 'User' would be used for individual user accounts
      principalType: 'Application'
      login: entraAdminLoginName
      // Principal ID (Object ID) of the managed identity in Azure AD
      sid: entraAdminPrincipalId
      tenantId: tenantId
    }
    // Public network access enabled for development/testing
    // Consider restricting to 'Disabled' or specific VNets in production
    publicNetworkAccess: 'Enabled'
    // Enforce TLS 1.2 minimum for encrypted connections
    minimalTlsVersion: '1.2'
  }
  tags: tags
}

// Explicit policy to enforce Azure AD-only authentication
// This sub-resource explicitly disables SQL authentication
// Name must be 'Default' per Azure Resource Provider requirements
@description('Enforce Azure AD-only authentication policy for SQL Server')
resource entraOnlyAuth 'Microsoft.Sql/servers/azureADOnlyAuthentications@2024-11-01-preview' = {
  parent: sqlServer
  name: 'Default'
  properties: {
    // Set to true to disable SQL authentication entirely
    // Only Azure AD principals can connect to this server
    azureADOnlyAuthentication: true
  }
}

// Azure SQL Database configuration
// General Purpose tier with Gen5 compute for balanced performance
@description('Azure SQL Database for application data')
resource sqlDb 'Microsoft.Sql/servers/databases@2024-11-01-preview' = {
  name: toLower('${cleanedName}db${uniqueSuffix}')
  parent: sqlServer
  location: location
  identity: {
    // Managed identity for the database enables passwordless connections
    // Applications can authenticate using the same managed identity
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  sku: {
    // GP_Gen5_2: General Purpose tier with 2 vCores (Gen5 compute)
    // Provides balanced compute and memory for most workloads
    name: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2 // 2 vCores
    size: '32GB' // Maximum data size
  }
  properties: {
    // SQL_Latin1_General_CP1_CI_AS: Default SQL Server collation
    // Case-insensitive (CI), accent-sensitive (AS)
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    // 32 GB maximum database size (34,359,738,368 bytes)
    maxSizeBytes: 34359738368
    // Zone redundancy disabled for cost optimization
    // Enable in production for high availability across zones
    zoneRedundant: false
  }
  tags: tags
}

// Diagnostic settings for SQL Database monitoring
// Captures query performance, errors, and resource utilization metrics
@description('Diagnostic settings for SQL Database')
resource sqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlDb.name}-diag'
  scope: sqlDb
  properties: {
    // Send diagnostic data to Log Analytics workspace for querying and alerting
    workspaceId: workspaceId
    // Also archive diagnostic data to storage account for long-term retention
    storageAccountId: storageAccountId
    // Dedicated destination type provides better query performance
    // Alternative is 'AzureDiagnostics' which uses a shared table
    logAnalyticsDestinationType: 'Dedicated'
    // Capture all available log categories (query performance, errors, etc.)
    logs: logsSettings
    // Capture all available metrics (CPU, IO, DTU usage, etc.)
    metrics: metricsSettings
  }
}
