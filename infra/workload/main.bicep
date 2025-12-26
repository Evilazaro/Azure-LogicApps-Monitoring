/*
  Workload Infrastructure Module
  ==============================
  Orchestrates deployment of all workload components.
  
  Components:
  1. Identity: Managed identity with role assignments
  2. Messaging: Service Bus namespace, queues, and workflow storage
  3. Services: Container Registry and Container Apps Environment
  4. Workflows: Logic Apps Standard with App Service Plan
  
  Deployment Order:
  - Identity first (required by other modules)
  - Messaging and Services in parallel (both use identity)
  - Workflows last (depends on identity and messaging storage)
*/

metadata name = 'Workload Infrastructure'
metadata description = 'Deploys identity, messaging, services, and Logic Apps workflows'

// ========== Type Definitions ==========

import { tagsType } from '../types.bicep'

// ========== Parameters ==========

@description('Base name for Logic App and App Service Plan resources.')
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

@description('Azure region for Logic App deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Resource ID of the User Assigned Identity to be used by workload resources.')
@minLength(50)
param userAssignedIdentityId string

@description('User Assigned Identity name to be used by Container Services.')
@minLength(3)
@maxLength(50)
param userAssignedIdentityClientId string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Log Analytics Workspace Customer ID.')
param workspaceCustomerId string

@description('Primary Key for Log Analytics workspace.')
param workspacePrimaryKey string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Workflow Storage Account Name for Logic Apps runtime.')
param workflowStorageAccountName string

@description('Resource tags applied to all workload resources.')
param tags tagsType

// ========== Variables ==========

var allLogsSettings object[] = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

var allMetricsSettings object[] = [
  {
    categoryGroup: 'allMetrics'
    enabled: true
  }
]

// ========== Modules ==========

// Messaging Module: Deploys Service Bus namespace and topics
// Provides message queue infrastructure for order processing
@description('Deploys Service Bus namespace with topics and subscriptions for message brokering')
module messaging 'messaging/main.bicep' = {
  params: {
    name: name
    tags: tags
    envName: envName
    userAssignedIdentityId: userAssignedIdentityId
    storageAccountId: storageAccountId
    workspaceId: workspaceId
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
  }
}

// ========== Outputs ==========

// Messaging Outputs
@description('Service Bus endpoint URL for message brokering')
output MESSAGING_SERVICEBUSENDPOINT string = messaging.outputs.MESSAGING_SERVICEBUSENDPOINT

@description('Service Bus hostname for connection configuration')
output MESSAGING_SERVICEBUSHOSTNAME string = messaging.outputs.MESSAGING_SERVICEBUSHOSTNAME

// Container Services Module: Deploys ACR, Container Apps Environment, and Aspire Dashboard
// Provides container hosting infrastructure for microservices
@description('Deploys Azure Container Registry, Container Apps Environment, and Aspire Dashboard')
module services 'services/main.bicep' = {
  params: {
    name: name
    location: location
    userAssignedIdentityId: userAssignedIdentityId
    userAssignedIdentityClientId: userAssignedIdentityClientId
    envName: envName
    workspaceId: workspaceId
    workspaceCustomerId: workspaceCustomerId
    workspacePrimaryKey: workspacePrimaryKey
    storageAccountId: storageAccountId
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    appInsightsConnectionString: appInsightsConnectionString
    tags: tags
  }
}

// Container Registry Outputs
@description('Container Registry login server endpoint')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = services.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT

@description('Managed identity resource ID for Container Registry')
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = services.outputs.AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID

@description('Name of the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_NAME string = services.outputs.AZURE_CONTAINER_REGISTRY_NAME

// Container Apps Outputs
@description('Name of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME

@description('Resource ID of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID

@description('Default domain for the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

// Logic Apps Module: Deploys Logic Apps Standard workflow engine
// Depends on identity and messaging storage account outputs
@description('Deploys Logic Apps Standard workflow engine with App Service Plan')
module workflows 'logic-app.bicep' = {
  params: {
    name: name
    location: location
    envName: envName
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    metricsSettings: allMetricsSettings
    appInsightsConnectionString: appInsightsConnectionString
    userAssignedIdentityId: userAssignedIdentityId
    workflowStorageAccountName: workflowStorageAccountName
    tags: tags
  }
}
