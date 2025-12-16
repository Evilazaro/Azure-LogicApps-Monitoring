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
@secure()
param workspacePrimaryKey string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Connection string for Application Insights instance.')
@secure()
param appInsightsConnectionString string

@description('Resource tags applied to all workload resources.')
param tags tagsType

// ========== Variables ==========

var allLogsSettings = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

var allMetricsSettings = [
  {
    categoryGroup: 'allMetrics'
    enabled: true
  }
]

// ========== Modules ==========

module identity 'identity/main.bicep' = {
  params: {
    name: name
    location: location
    tags: tags
    envName: envName
  }
}

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
    workflowStorageAccountName: messaging.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
    tags: tags
  }
}

// ========== Outputs ==========

// Managed Identity Outputs (Microsoft.ManagedIdentity/userAssignedIdentities)
@description('Client ID of the deployed managed identity')
output MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.MANAGED_IDENTITY_CLIENT_ID

@description('Name of the deployed managed identity')
output MANAGED_IDENTITY_NAME string = identity.outputs.MANAGED_IDENTITY_NAME

@description('Client ID of the deployed managed identity (alias)')
output AZURE_CLIENT_ID string = identity.outputs.AZURE_CLIENT_ID

@description('Resource ID of the managed identity used by Container Registry')
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = identity.outputs.AZURE_MANAGED_IDENTITY_ID

// Service Bus Outputs (Microsoft.ServiceBus/namespaces)
@description('Azure Service Bus namespace name')
output AZURE_SERVICE_BUS_NAMESPACE string = messaging.outputs.AZURE_SERVICE_BUS_NAMESPACE

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

// Logic Apps Standard Outputs (Microsoft.Web/sites)
@description('Resource ID of the deployed Logic App')
output WORKFLOW_ENGINE_ID string = workflows.outputs.WORKFLOW_ENGINE_ID

@description('Name of the deployed Logic App')
output WORKFLOW_ENGINE_NAME string = workflows.outputs.WORKFLOW_ENGINE_NAME

// App Service Plan Outputs (Microsoft.Web/serverfarms)
@description('Resource ID of the App Service Plan')
output WORKFLOW_ENGINE_ASP_ID string = workflows.outputs.WORKFLOW_ENGINE_ASP_ID

@description('Name of the App Service Plan')
output APP_SERVICE_PLAN_NAME string = workflows.outputs.APP_SERVICE_PLAN_NAME

// Storage Account Outputs (Microsoft.Storage/storageAccounts)
@description('Name of the workflow storage account')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = messaging.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
