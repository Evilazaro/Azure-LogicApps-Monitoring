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

@description('Application Insights Instrumentation Key.')
@secure()
param appInsightsInstrumentationKey string

@description('Resource tags applied to all workload resources.')
param tags object = {}

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

module identity 'identity/main.bicep' = {
  params: {
    name: name
    location: location
    tags: tags
    envName: envName
  }
}


@description('Client ID of the deployed managed identity')
output MANAGED_IDENTITY_CLIENT_ID string = identity.outputs.MANAGED_IDENTITY_CLIENT_ID

output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = identity.outputs.AZURE_MANAGED_IDENTITY_ID

// ========== Modules ==========

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
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    appInsightsConnectionString: appInsightsConnectionString
    tags: tags
  }
}

output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID

output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = services.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = services.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT

// module webApp 'web-app.bicep' = {
//   scope: resourceGroup()
//   params: {
//     name: name
//     envName: envName
//     location: location
//     appInsightsConnectionString: appInsightsConnectionString
//     appInsightsInstrumentationKey: appInsightsInstrumentationKey
//     workspaceId: workspaceId
//     storageAccountId: storageAccountId
//     workflowStorageAccountName: messaging.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
//     logsSettings: allLogsSettings
//     metricsSettings: allMetricsSettings
//     tags: tags
//   }
// }

// @description('Resource ID of the deployed webApp App')
// output PO_WEB_APP_ID string = webApp.outputs.PO_WEB_APP_ID

// @description('Name of the deployed webApp App')
// output PO_WEB_APP_NAME string = webApp.outputs.PO_WEB_APP_NAME

// @description('Default hostname of the webApp App')
// output PO_WEB_APP_DEFAULT_HOST_NAME string = webApp.outputs.PO_WEB_APP_DEFAULT_HOST_NAME

// module api 'web-api.bicep' = {
//   scope: resourceGroup()
//   params: {
//     name: name
//     envName: envName
//     location: location
//     appInsightsConnectionString: appInsightsConnectionString
//     appInsightsInstrumentationKey: appInsightsInstrumentationKey
//     workspaceId: workspaceId
//     storageAccountId: storageAccountId
//     logsSettings: allLogsSettings
//     metricsSettings: allMetricsSettings
//     tags: tags
//   }
// }

// @description('Resource ID of the deployed webApp App')
// output PO_PROC_API_WEB_APP_ID string = api.outputs.PO_PROC_API_WEB_APP_ID

// @description('Name of the deployed webApp App')
// output PO_PROC_API_WEB_APP_NAME string = api.outputs.PO_PROC_API_WEB_APP_NAME

// @description('Default hostname of the webApp App')
// output PO_PROC_API_DEFAULT_HOST_NAME string = api.outputs.PO_PROC_API_DEFAULT_HOST_NAME

// module workflows 'logic-app.bicep' = {
//   scope: resourceGroup()
//   params: {
//     name: name
//     location: location
//     envName: envName
//     workspaceId: workspaceId
//     storageAccountId: storageAccountId
//     metricsSettings: allMetricsSettings
//     appInsightsConnectionString: appInsightsConnectionString
//     appInsightsInstrumentationKey: appInsightsInstrumentationKey
//     workflowStorageAccountName: messaging.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
//     tags: tags
//   }
//   dependsOn: [
//     api
//   ]
// }

// @description('Resource ID of the deployed Logic App')
// output WORKFLOW_ENGINE_ID string = workflows.outputs.WORKFLOW_ENGINE_ID

// @description('Name of the deployed Logic App')
// output WORKFLOW_ENGINE_NAME string = workflows.outputs.WORKFLOW_ENGINE_NAME

// @description('Resource ID of the App Service Plan')
// output WORKFLOW_ENGINE_ASP_ID string = workflows.outputs.WORKFLOW_ENGINE_ASP_ID

// @description('Name of the App Service Plan')
// output APP_SERVICE_PLAN_NAME string = workflows.outputs.APP_SERVICE_PLAN_NAME
