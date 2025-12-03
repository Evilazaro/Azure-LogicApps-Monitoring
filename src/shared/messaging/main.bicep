// ============================================================================
// SERVICE BUS NAMESPACE MODULE
// ============================================================================
// Deploys Azure Service Bus namespace for messaging integration with Logic Apps.
//
// Configuration:
// - SKU: Standard (supports topics, sessions, duplicate detection)
// - Capacity: 16 messaging units
// - Local Auth: DISABLED (enforces managed identity authentication - IMPORTANT!)
// - Public Network Access: Enabled (can be restricted with firewall rules)
//
// AUTHENTICATION IMPORTANT NOTES:
// 1. disableLocalAuth = true means connection strings/SAS keys are NOT allowed
// 2. Logic Apps MUST use managed identity to connect to Service Bus
// 3. Required RBAC roles for Logic Apps managed identity:
//    - Azure Service Bus Data Owner (Role ID: 090c5cfd-751d-490a-894a-3ce6f1109419)
//      Full access to send/receive messages and manage entities
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#azure-service-bus-data-owner
//
//    - Azure Service Bus Data Sender (Role ID: 69a216fc-b8fb-44d8-bc22-1f3c2cd27a39)
//      Send messages to queues and topics only
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#azure-service-bus-data-sender
//
//    - Azure Service Bus Data Receiver (Role ID: 4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0)
//      Receive and delete messages from queues and subscriptions
//      Docs: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#azure-service-bus-data-receiver
//
// 4. To use connection strings instead:
//    - Change disableLocalAuth to false
//    - Uncomment the serviceBusAuthRule resource and connection string output
//    - Update Logic App connections to use connection string
//    - NOTE: This is less secure and not recommended for production
//
// Diagnostic Settings:
// - Configured to send all logs and metrics to Log Analytics workspace
// - Enables monitoring of message flow, errors, and throttling
//
// References:
// - Service Bus auth: https://learn.microsoft.com/azure/service-bus-messaging/service-bus-authentication-and-authorization
// - Managed identity: https://learn.microsoft.com/azure/service-bus-messaging/service-bus-managed-service-identity
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for Service Bus namespace. Will be suffixed with unique string and -sb for global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
param envName string

@description('Azure region for Service Bus deployment. Should match Logic App region for optimal latency.')
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
param storageAccountId string

@description('Resource tags applied to Service Bus resources for cost tracking and compliance.')
@metadata({
  example: {
    Solution: 'tax-docs'
    Environment: 'prod'
  }
})
param tags object

// ============================================================================
// VARIABLES
// ============================================================================

// Storage account name generation with Azure naming constraints
// Azure Storage account names must:
// - Be 3-24 characters long
// - Contain only lowercase letters and numbers (no hyphens, underscores, or spaces)
// - Be globally unique across all Azure Storage accounts
var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name, envName, location)
var storageAccountName = take('${cleanedName}${uniqueSuffix}stg', 24)

// Storage account configuration aligned with Azure best practices
// Reference: https://learn.microsoft.com/azure/storage/common/storage-account-overview
var storageConfig = {
  sku: 'Standard_LRS' // Locally redundant storage - cost-effective for dev/test
  kind: 'StorageV2' // General-purpose v2 - supports all storage services
  accessTier: 'Hot' // Hot tier for frequently accessed data
  minimumTlsVersion: 'TLS1_2' // Enforce TLS 1.2 minimum for security compliance
  supportsHttpsTrafficOnly: true // Enforce HTTPS-only traffic (security best practice)
}

// ============================================================================
// RESOURCES
// ============================================================================

// Workflow storage account - stores Logic Apps runtime artifacts
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
    allowSharedKeyAccess: true // REQUIRED for Logic Apps file share creation
    networkAcls: {
      bypass: 'AzureServices' // CRITICAL: Allow Azure services (Logic Apps) to bypass firewall
      defaultAction: 'Allow' // Allow all traffic (change to 'Deny' for production with private endpoints)
    }
  }
}

resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = {
  name: 'default'
  parent: workflowSA
}

resource taxProcessing 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' = {
  name: 'taxprocessing'
  parent: queueServices
  properties: {
    metadata: {
      purpose: 'Logic Apps workflow runtime queue for tax processing tasks'
    }
  }
}

// Diagnostic settings for storage account - capture logs and metrics
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

// Diagnostic settings for queue service - capture queue operations
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

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the deployed storage account (generated with unique suffix for global uniqueness)')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = workflowSA.name

@description('Resource ID of the deployed storage account for RBAC role assignments')
output WORKFLOW_STORAGE_ACCOUNT_ID string = workflowSA.id
