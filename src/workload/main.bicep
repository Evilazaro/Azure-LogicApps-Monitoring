
@description('Base name for Logic App and App Service Plan resources. Will be suffixed with unique string for global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
@minLength(2)
@maxLength(10)
param envName string

@description('Azure region for Logic App deployment. Must support Workflow Standard SKU and Application Insights.')
@minLength(3)
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
param storageAccountId string

@description('Name of the Application Insights instance for telemetry collection and performance monitoring.')
param appInsightsName string

@description('Name of existing Service Bus namespace for messaging integration with workflows.')
param workflowStorageAccountName string

@description('Resource tags applied to Logic App, App Service Plan, and dashboard resources for cost tracking and governance.')
@metadata({
  example: {
    Solution: 'tax-docs'
    Environment: 'prod'
  }
})
param tags object

// ============================================================================
// MODULE DEPLOYMENTS
// ============================================================================

module apis 'azure-function.bicep' = {
  name: 'ApiFunctionDeployment'
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
  name: 'LogicAppWorkflowsDeployment'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    envName: envName
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    appInsightsName: appInsightsName
    workflowStorageAccountName: workflowStorageAccountName
    tags: tags
  }
  dependsOn: [
    apis
  ]
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the deployed Logic App for reference and integration')
output LOGIC_APP_ID string = workflows.outputs.LOGIC_APP_ID

@description('Name of the deployed Logic App')
output LOGIC_APP_NAME string = workflows.outputs.LOGIC_APP_NAME

@description('Resource ID of the Logic App App Service Plan')
output LOGIC_APP_SERVICE_PLAN_ID string = workflows.outputs.APP_SERVICE_PLAN_ID

@description('Resource ID of the API Function App')
output API_FUNCTION_APP_ID string = apis.outputs.FUNCTION_APP_ID

@description('Name of the API Function App')
output API_FUNCTION_APP_NAME string = apis.outputs.FUNCTION_APP_NAME
