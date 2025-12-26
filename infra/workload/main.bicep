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

// Identity Module: Deploys user-assigned managed identity
// Must be deployed first as other modules depend on its output
module identity 'identity/main.bicep' = {
  params: {
    name: name
    location: location
    tags: tags
    envName: envName
  }
}

module data 'data/main.bicep' = {
  params: {
    name: name
    envName: envName
    location: location
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    metricsSettings: allMetricsSettings
    userAssignedIdentityId: identity.outputs.AZURE_MANAGED_IDENTITY_ID
    tags: tags
  }
}

// Messaging Module: Deploys Service Bus and workflow storage
// Provides message queue infrastructure and Logic Apps storage backend
module messaging 'messaging/main.bicep' = {
  params: {
    name: name
    tags: tags
    envName: envName
    userAssignedIdentityId: identity.outputs.AZURE_MANAGED_IDENTITY_ID
    storageAccountId: storageAccountId
    workspaceId: workspaceId
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
  }
}

// Container Services Module: Deploys ACR, Container Apps Environment, and Aspire Dashboard
// Provides container hosting infrastructure for microservices
module services 'services/main.bicep' = {
  params: {
    name: name
    location: location
    userAssignedIdentityId: identity.outputs.AZURE_MANAGED_IDENTITY_ID
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

// Logic Apps Module: Deploys Logic Apps Standard workflow engine
// Depends on identity and messaging storage account outputs
module workflows 'logic-app.bicep' = {
  params: {
    name: name
    location: location
    envName: envName
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    metricsSettings: allMetricsSettings
    appInsightsConnectionString: appInsightsConnectionString
    userAssignedIdentityId: identity.outputs.AZURE_MANAGED_IDENTITY_ID
    workflowStorageAccountName: data.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
    tags: tags
  }
}

// ========== Outputs ==========

// Managed Identity Outputs (Microsoft.ManagedIdentity/userAssignedIdentities)
@description('Client ID of the deployed managed identity')
output MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.MANAGED_IDENTITY_CLIENT_ID

@description('Name of the deployed managed identity')
output MANAGED_IDENTITY_NAME string = identity.outputs.MANAGED_IDENTITY_NAME

@description('Resource ID of the managed identity used by Container Registry')
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = identity.outputs.AZURE_MANAGED_IDENTITY_ID

@description('Messaging Service Bus Host Name')
output MESSAGING_SERVICEBUSHOSTNAME string = messaging.outputs.MESSAGING_SERVICEBUSHOSTNAME

@description('Azure Service Bus endpoint')
output MESSAGING_SERVICEBUSENDPOINT string = messaging.outputs.MESSAGING_SERVICEBUSENDPOINT

// Container Registry Outputs (Microsoft.ContainerRegistry/registries)
@description('Name of the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_NAME string = services.outputs.AZURE_CONTAINER_REGISTRY_NAME

@description('Login server endpoint for the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = services.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT

// Container Apps Environment Outputs (Microsoft.App/managedEnvironments)
@description('Name of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME

@description('Resource ID of the Container Apps managed environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID

@description('Default domain for the Container Apps environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

@description('Azure Storage Workflow State Account Name')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = data.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME

@description('Name of the storage volume mount for orders-api')
output ORDERS_STORAGE_VOLUME_NAME string = services.outputs.ORDERS_STORAGE_VOLUME_NAME

// Logic Apps Outputs
@description('Name of the deployed Logic App workflow engine')
output LOGIC_APP_NAME string = workflows.outputs.LOGIC_APP_NAME

@description('Resource ID of the deployed Logic App workflow engine')
output LOGIC_APP_ID string = workflows.outputs.LOGIC_APP_ID

@description('Default hostname of the Logic App workflow engine')
output LOGIC_APP_DEFAULT_HOSTNAME string = workflows.outputs.LOGIC_APP_DEFAULT_HOSTNAME

@description('Name of the App Service Plan hosting the Logic App')
output APP_SERVICE_PLAN_NAME string = workflows.outputs.APP_SERVICE_PLAN_NAME

@description('Resource ID of the App Service Plan')
output APP_SERVICE_PLAN_ID string = workflows.outputs.APP_SERVICE_PLAN_ID
