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

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Instrumentation key for Application Insights instance.')
param appInsightsInstrumentationKey string

@description('Resource tags applied to all workload resources.')
param tags object = {}

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

module messaging 'messaging/main.bicep' = {
  name: 'messagingDeployment'
  scope: resourceGroup()
  params: {
    name: name
    //tags: tags
    envName: envName
    storageAccountId: storageAccountId
    workspaceId: workspaceId
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
  }
}

module apis 'web-app.bicep' = {
  name: 'apisDeployment'
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    appInsightsConnectionString: appInsightsConnectionString
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    //tags: tags
  }
}

@description('Resource ID of the deployed webApp App')
output PO_PROC_API_WEB_APP_ID string = apis.outputs.PO_PROC_API_WEB_APP_ID

@description('Name of the deployed webApp App')
output PO_PROC_API_WEB_APP_NAME string = apis.outputs.PO_PROC_API_WEB_APP_NAME

@description('Default hostname of the webApp App')
output PO_PROC_API_DEFAULT_HOST_NAME string = apis.outputs.PO_PROC_API_DEFAULT_HOST_NAME

@description('Resource ID of the deployed webApp App')
output PO_API_WEB_APP_ID string = apis.outputs.PO_API_WEB_APP_ID

@description('Name of the deployed webApp App')
output PO_API_WEB_APP_NAME string = apis.outputs.PO_API_WEB_APP_NAME

@description('Default hostname of the webApp App')
output PO_API_WEB_APP_DEFAULT_HOST_NAME string = apis.outputs.PO_API_WEB_APP_DEFAULT_HOST_NAME

module workflows 'logic-app.bicep' = {
  name: 'workflowsDeployment'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    envName: envName
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logsSettings: allLogsSettings
    metricsSettings: allMetricsSettings
    appInsightsConnectionString: appInsightsConnectionString
    appInsightsInstrumentationKey: appInsightsInstrumentationKey
    workflowStorageAccountName: messaging.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
    //tags: tags
  }
  dependsOn: [
    apis
  ]
}

@description('Resource ID of the deployed Logic App')
output WORKFLOW_ENGINE_ID string = workflows.outputs.WORKFLOW_ENGINE_ID

@description('Name of the deployed Logic App')
output WORKFLOW_ENGINE_NAME string = workflows.outputs.WORKFLOW_ENGINE_NAME

@description('Resource ID of the App Service Plan')
output WORKFLOW_ENGINE_ASP_ID string = workflows.outputs.WORKFLOW_ENGINE_ASP_ID

@description('Name of the App Service Plan')
output APP_SERVICE_PLAN_NAME string = workflows.outputs.APP_SERVICE_PLAN_NAME
