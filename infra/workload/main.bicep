// ========== Type Definitions ==========

@description('Tags applied to all resources for organization and cost tracking')
type tagsType = {
  @description('Name of the solution')
  Solution: string

  @description('Environment identifier')
  Environment: string

  @description('Management method')
  ManagedBy: string

  @description('Cost center identifier')
  CostCenter: string

  @description('Team responsible for the resources')
  Owner: string

  @description('Business unit')
  BusinessUnit: string

  @description('Deployment timestamp')
  DeploymentDate: string

  @description('Source repository')
  Repository: string
}

// ========== Parameters ==========

@description('Base name for Logic App and App Service Plan resources.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
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

@description('Azure Service Bus Name')
output AZURE_SERVICE_BUS_NAMESPACE string = messaging.outputs.AZURE_SERVICE_BUS_NAMESPACE

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

@description('Resource ID of the Container Apps managed environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID

@description('Default domain for the Container Apps environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

@description('Login server endpoint for the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = services.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT

@description('Name of the deployed storage account')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = messaging.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME

@description('Resource ID of the deployed Logic App')
output WORKFLOW_ENGINE_ID string = workflows.outputs.WORKFLOW_ENGINE_ID

@description('Name of the deployed Logic App')
output WORKFLOW_ENGINE_NAME string = workflows.outputs.WORKFLOW_ENGINE_NAME

@description('Resource ID of the App Service Plan')
output WORKFLOW_ENGINE_ASP_ID string = workflows.outputs.WORKFLOW_ENGINE_ASP_ID

@description('Name of the App Service Plan')
output APP_SERVICE_PLAN_NAME string = workflows.outputs.APP_SERVICE_PLAN_NAME

// ========== Outputs ==========

@description('Client ID of the deployed managed identity')
output AZURE_CLIENT_ID string = identity.outputs.AZURE_CLIENT_ID

output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = identity.outputs.AZURE_MANAGED_IDENTITY_ID
