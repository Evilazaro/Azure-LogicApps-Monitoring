/*
  Messaging Infrastructure Module
  ===============================
  Deploys Azure Service Bus infrastructure for message brokering.
  
  Overview:
  This module provisions a complete Azure Service Bus messaging solution
  with topic-based publish/subscribe messaging patterns for order processing.
  
  Architecture:
  ┌─────────────────────────────────────────────────────────────┐
  │                  Service Bus Namespace                      │
  │  ┌─────────────────────────────────────────────────────┐   │
  │  │              Orders Topic (ordersplaced)             │   │
  │  │  ┌─────────────────────────────────────────────┐    │   │
  │  │  │   Order Processing Subscription             │    │   │
  │  │  │   - Max Delivery: 10 attempts               │    │   │
  │  │  │   - Lock Duration: 5 minutes                │    │   │
  │  │  │   - TTL: 14 days                            │    │   │
  │  │  │   - Dead-letter enabled                     │    │   │
  │  │  └─────────────────────────────────────────────┘    │   │
  │  └─────────────────────────────────────────────────────┘   │
  └─────────────────────────────────────────────────────────────┘
  
  Components:
  1. Service Bus namespace (Standard tier)
  2. Orders topic for order processing events
  3. Order processing subscription with dead-letter support
  4. Diagnostic settings for monitoring and logging
  
  Key Features:
  - Standard Service Bus tier for topic-based messaging
  - User Assigned Managed Identity for secure authentication
  - Topic-based pub/sub messaging for order processing events
  - Configurable message TTL (14 days) and lock duration (5 minutes)
  - Dead-letter queue support for failed/expired messages
  - Integration with Log Analytics and Storage Account for diagnostics
  
  Parameters:
  - name: Base name for Service Bus namespace (3-20 chars)
  - envName: Environment identifier (dev, test, staging, prod)
  - location: Azure region for deployment
  - userAssignedIdentityId: Resource ID of User Assigned Identity
  - workspaceId: Log Analytics workspace ID for diagnostics
  - storageAccountId: Storage Account ID for diagnostic logs
  - logsSettings: Log Analytics log configuration
  - metricsSettings: Log Analytics metrics configuration
  - tags: Resource tags
  
  Outputs:
  - MESSAGING_SERVICEBUSENDPOINT: Service Bus endpoint URL
  - MESSAGING_SERVICEBUSHOSTNAME: Service Bus hostname
  - MESSAGING_SERVICEBUSNAME: Service Bus namespace name
  
  Usage Example:
  ```bicep
  module messaging 'workload/messaging/main.bicep' = {
    name: 'messaging-deployment'
    params: {
      name: 'myapp'
      envName: 'dev'
      location: 'eastus'
      userAssignedIdentityId: identity.outputs.identityId
      workspaceId: monitoring.outputs.workspaceId
      storageAccountId: storage.outputs.storageAccountId
      logsSettings: logsConfig
      metricsSettings: metricsConfig
      tags: commonTags
    }
  }
  ```
*/

metadata name = 'Messaging Infrastructure'
metadata description = 'Deploys Service Bus namespace with topics and subscriptions for message brokering'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for Service Bus namespace')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name to differentiate deployments.')
@maxLength(10)
@allowed([
  'dev'
  'test'
  'prod'
  'staging'
])
param envName string

@description('Azure region for Service Bus deployment')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Resource ID of the User Assigned Identity to be used by Service Bus')
@minLength(50)
param userAssignedIdentityId string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics')
@minLength(50)
param storageAccountId string

@description('Logs settings for the Log Analytics workspace')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace')
param metricsSettings object[]

@description('Resource tags applied to Service Bus resources')
param tags tagsType

// ========== Variables ==========

// Remove special characters for naming compliance
@description('Cleaned name with special characters removed for Azure naming requirements')
var cleanedName string = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))

// Generate unique suffix for globally unique resource names
@description('Unique suffix for globally unique resource names')
var uniqueSuffix string = uniqueString(resourceGroup().id, name, envName, location)

// Service Bus namespace name limited to 20 characters
@description('Service Bus namespace name (max 20 characters)')
var serviceBusName string = toLower(take('${cleanedName}sb${uniqueSuffix}', 20))

// ========== Resources ==========

@description('Service Bus namespace for message brokering')
resource broker 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' = {
  name: serviceBusName
  location: location
  // Standard SKU provides:
  // - Standard message brokering with topics and subscriptions
  // - Suitable for most workloads with moderate throughput requirements
  // - Maximum message size of 256 KB
  // - Capacity is not applicable for Standard tier (auto-managed)
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
}

// ========== Outputs ==========

@description('Service Bus endpoint URL for message brokering')
output MESSAGING_SERVICEBUSENDPOINT string = broker.properties.serviceBusEndpoint

@description('Service Bus hostname for connection configuration')
output MESSAGING_SERVICEBUSHOSTNAME string = split(replace(broker.properties.serviceBusEndpoint, 'https://', ''), ':')[0]

@description('Name of the Service Bus namespace')
output MESSAGING_SERVICEBUSNAME string = broker.name

// Service Bus Topic for order processing workflow
@description('Service Bus Topic for orders placed to be processed')
resource ordersTopic 'Microsoft.ServiceBus/namespaces/topics@2025-05-01-preview' = {
  parent: broker
  name: 'ordersplaced'
}

@description('Service Bus subscription for processing orders from the topic')
resource ordersSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2025-05-01-preview' = {
  parent: ordersTopic
  name: 'orderprocessingsub'
  properties: {
    // Maximum delivery attempts before message is moved to dead-letter queue
    maxDeliveryCount: 10
    // Duration a message is locked for processing (ISO 8601 duration: 5 minutes)
    lockDuration: 'PT5M'
    // Time-to-live for messages in the subscription (ISO 8601 duration: 14 days)
    defaultMessageTimeToLive: 'P14D'
    // Enable automatic dead-lettering for expired messages
    deadLetteringOnMessageExpiration: true
  }
}

@description('Diagnostic settings for Service Bus namespace')
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
