@description('Base name for Logic App and App Service Plan resources. Will be suffixed with unique string for global uniqueness.')
@minLength(3)
@maxLength(20)
param name string

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

module apis 'azure-function.bicep' = {
  name: 'ApiFunctionDeployment'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    appInsightsName: appInsightsName
    workspaceId: workspaceId
    tags: tags
  }
}

module workflows 'logic-app.bicep' = {
  name: 'WorkloadDeployment'
  scope: resourceGroup()
  params: {
    name: name
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
