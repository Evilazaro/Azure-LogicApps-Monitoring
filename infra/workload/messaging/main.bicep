/*
  Messaging Infrastructure Module
  ===============================
  Deploys Service Bus and storage infrastructure for workflow orchestration.
  
  Components:
  1. Service Bus Premium namespace with order queue
  2. Storage account for Logic Apps runtime (Standard tier requirement)
  3. Blob containers for processed orders (success/error segregation)
  
  Key Features:
  - Premium Service Bus tier for enhanced performance and scalability
  - Capacity of 16 messaging units
  - Managed identity authentication for Service Bus
  - Separate containers for success and error order processing
  - Diagnostic settings for all resources
*/

metadata name = 'Messaging Infrastructure'
metadata description = 'Deploys Service Bus namespace, queues, and workflow storage account'

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

// ========== Variables ==========

// Remove special characters for naming compliance
var cleanedName string = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))

// Generate unique suffix for globally unique resource names
var uniqueSuffix string = uniqueString(resourceGroup().id, name, envName, location)

// Service Bus namespace name limited to 20 characters
var serviceBusName string = toLower(take('${cleanedName}sb${uniqueSuffix}', 20))

// ========== Resources ==========

@description('Service Bus namespace for message brokering')
resource broker 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Premium'
    tier: 'Premium'
    capacity: 16
  }
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
}

@description('Service Bus Topic for orders placed to be processed')
resource ordersTopic 'Microsoft.ServiceBus/namespaces/topics@2025-05-01-preview' = {
  parent: broker
  name: 'OrdersPlaced'
}

@description('Service Bus subscription for processing orders from the topic')
resource ordersSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2025-05-01-preview' = {
  parent: ordersTopic
  name: 'OrderProcessingSubscription'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    defaultMessageTimeToLive: 'P14D'
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

@description('Messaging Service Bus Host Name')
output MESSAGING_SERVICEBUSHOSTNAME string = broker.name

@description('Azure Service Bus endpoint')
output MESSAGING_SERVICEBUSENDPOINT string = broker.properties.serviceBusEndpoint

