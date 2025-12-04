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

@description('Name of the Application Insights instance.')
param appInsightsName string

@description('Resource tags applied to all workload resources.')
param tags object

module messaging 'messaging/main.bicep' = {
  scope: resourceGroup()
  params: {
    name: name
    tags: tags
    envName: envName
    storageAccountId: storageAccountId
    workspaceId: workspaceId
  }
}

module apis 'azure-function.bicep' = {
  scope: resourceGroup()
  params: {
    name: name
    envName: envName
    location: location
    appInsightsName: appInsightsName
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    tags: tags
  }
}

module workflows 'logic-app.bicep' = {
  scope: resourceGroup()
  params: {
    name: name
    location: location
    envName: envName
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    appInsightsName: appInsightsName
    workflowStorageAccountName: messaging.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
    tags: tags
  }
  dependsOn: [
    apis
  ]
}

@description('Resource ID of the deployed Logic App')
output LOGIC_APP_ID string = workflows.outputs.LOGIC_APP_ID

@description('Name of the deployed Logic App')
output LOGIC_APP_NAME string = workflows.outputs.LOGIC_APP_NAME

@description('Resource ID of the Logic App App Service Plan')
output LOGIC_APP_SERVICE_PLAN_ID string = workflows.outputs.APP_SERVICE_PLAN_ID

@description('Resource ID of the API Function App')
output API_FUNCTION_APP_ID string = apis.outputs.FUNCTION_APP_ID

@description('Name of the API Function App')
output API_FUNCTION_APP_NAME string = apis.outputs.FUNCTION_APP_NAME
