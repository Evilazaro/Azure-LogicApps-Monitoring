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
param tags object

// ============================================================================
// VARIABLES
// ============================================================================

// Queue configuration for tax processing
var queueConfig = {
  name: 'tax-processing-queue'
  maxSizeInMegabytes: 1024
  defaultMessageTimeToLive: 'P14D' // 14 days
  maxDeliveryCount: 10
}

// ============================================================================
// RESOURCES
// ============================================================================

resource serviceBus 'Microsoft.ServiceBus/namespaces@2024-01-01' = {
  name: '${name}-sb-${uniqueString(resourceGroup().id, name, envName, location)}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true // ENFORCES MANAGED IDENTITY - connection strings will NOT work
    minimumTlsVersion: '1.2'
    zoneRedundant: false
  }
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  name: queueConfig.name
  parent: serviceBus
  properties: {
    maxSizeInMegabytes: queueConfig.maxSizeInMegabytes
    requiresDuplicateDetection: false
    requiresSession: false
    defaultMessageTimeToLive: queueConfig.defaultMessageTimeToLive
    deadLetteringOnMessageExpiration: true
    enableBatchedOperations: true
    maxDeliveryCount: queueConfig.maxDeliveryCount
    duplicateDetectionHistoryTimeWindow: 'PT10M'
  }
}

// UNCOMMENT BELOW to use connection string authentication (NOT RECOMMENDED)
// Must also change disableLocalAuth to false above
// resource serviceBusAuthRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2022-10-01-preview' existing = {
//   name: 'RootManageSharedAccessKey'
//   parent: serviceBus
// }

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${serviceBus.name}-diag'
  scope: serviceBus
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        enabled: true
        categoryGroup: 'allLogs'
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
        retentionPolicy: {
          enabled: false
          days: 0
        }
      }
    ]
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Name of the deployed Service Bus namespace')
output AZURE_SERVICEBUS_NAMESPACE_NAME string = serviceBus.name

@description('Resource ID of the Service Bus namespace for RBAC role assignments')
output AZURE_SERVICEBUS_NAMESPACE_ID string = serviceBus.id

@description('Fully qualified domain name of the Service Bus namespace endpoint')
output AZURE_SERVICEBUS_ENDPOINT string = serviceBus.properties.serviceBusEndpoint

@description('Name of the deployed queue')
output AZURE_SERVICEBUS_QUEUE_NAME string = queue.name
