// ============================================================================
// STORAGE ACCOUNT MODULE
// ============================================================================
// Deploys Azure Storage account required by Logic Apps Standard runtime.
//
// Logic Apps Standard Requirements:
// - Blob Storage: Workflow definitions, run history, artifacts
// - Queue Storage: Durable execution orchestration
// - Table Storage: Workflow state management
// - File Storage: Shared files and configuration
//
// Configuration:
// - SKU: Standard_LRS (locally redundant storage, cost-optimized)
// - Tier: Hot (optimized for frequently accessed data)
// - HTTPS Only: Enforced for all connections
// - Public Access: Enabled (can be restricted with firewall rules)
//
// Naming Strategy:
// - Removes hyphens, underscores, and spaces from input name
// - Appends uniqueString for global uniqueness
// - Adds 'stg' suffix for identification
// - Truncates to 24 characters (Azure Storage naming limit)
//
// RBAC Integration (In Development):
// This module will be extended to assign RBAC roles for managed identity
// authentication instead of connection strings (Azure best practice).
// Required roles:
// - Storage Blob Data Owner (Role ID: b7e6dc6d-f1e8-4753-8033-0f276bb0955b)
// - Storage Queue Data Contributor (Role ID: 974c5e8b-45b9-4653-ba55-5f855dd0fb88)
// - Storage Table Data Contributor (Role ID: 0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3)
// - Storage File Data Privileged Contributor (Role ID: 69566ab7-960f-475b-8e7c-b3118f30c6bd)
//
// References:
// - https://learn.microsoft.com/azure/logic-apps/logic-apps-azure-resource-manager-templates-overview#storage
// - https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for the storage account. Must be 3-20 characters. Will be processed to meet Azure Storage naming requirements.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for storage account deployment. Should match Logic App region for optimal latency.')
param location string = resourceGroup().location

@description('Resource tags applied to the storage account for cost tracking and compliance.')
param tags object

// ============================================================================
// VARIABLES
// ============================================================================

// Generate a storage account name that meets Azure naming requirements:
// - Must be 3-24 characters long
// - Can contain only lowercase letters and numbers
// - Must be globally unique across all Azure Storage accounts
var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name)
var storageAccountName = take('${cleanedName}${uniqueSuffix}stg', 24)

// ============================================================================
// RESOURCES
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: length(storageAccountName) >= 3 ? storageAccountName : '${storageAccountName}stg'
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
    allowBlobPublicAccess: false
    publicNetworkAccess: 'Enabled'
    allowSharedKeyAccess: true // REQUIRED for Logic Apps file share creation
    networkAcls: {
      bypass: 'AzureServices' // CRITICAL: Allow Azure services (Logic Apps) to bypass firewall
      defaultAction: 'Allow' // Allow all traffic (change to 'Deny' for production with private endpoints)
    }
  }
}

// ============================================================================
// FILE SERVICES - Enable file shares for Logic Apps
// ============================================================================

resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = {
  name: 'default'
  parent: storageAccount
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: 7
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the deployed storage account (generated with unique suffix for global uniqueness)')
output STORAGE_ACCOUNT_NAME string = storageAccount.name

@description('Resource ID of the deployed storage account for RBAC role assignments')
output STORAGE_ACCOUNT_ID string = storageAccount.id

