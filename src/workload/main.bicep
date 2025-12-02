// ============================================================================
// WORKLOAD MODULE ORCHESTRATOR
// ============================================================================
// Orchestrates deployment of Logic Apps workload components:
// 1. Azure Functions API - App Service Plan (Premium) + Function App
// 2. Logic App Workflows - App Service Plan (WS1) + Logic App + Dashboards
//
// Module Dependencies:
// - APIs module deploys first (Function App for API layer)
// - Workflows module deploys after APIs (Logic Apps Standard workflows)
//
// Both modules share monitoring infrastructure (Log Analytics, App Insights)
// from the shared resources module.
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for Logic App and App Service Plan resources. Will be suffixed with unique string for global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name suffix to ensure uniqueness across environments (e.g., dev, test, prod).')
param envName string

@description('Azure region for Logic App deployment. Must support Workflow Standard SKU and Application Insights.')
param location string = resourceGroup().location

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
param workspaceId string

@description('Name of the existing storage account required by Logic Apps Standard for workflow state and artifacts.')
param storageAccountName string

@description('Name of the Application Insights instance for telemetry collection and performance monitoring.')
param appInsightsName string

@description('Name of existing Service Bus namespace for messaging integration with workflows.')
param serviceBusName string

@description('Resource tags applied to Logic App, App Service Plan, and dashboard resources for cost tracking and governance.')
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
    storageAccountName: storageAccountName
    appInsightsName: appInsightsName
    serviceBusName: serviceBusName
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
