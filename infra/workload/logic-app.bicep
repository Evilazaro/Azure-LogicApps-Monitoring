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

@description('Resource ID of the User Assigned Identity to be used by Service Bus.')
@minLength(50)
param userAssignedIdentityId string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Metrics settings for diagnostic configurations.')
param metricsSettings object[]

@description('Name of the existing storage account required by Logic Apps Standard.')
@minLength(3)
@maxLength(24)
param workflowStorageAccountName string

@description('Connection string for Application Insights instance.')
@secure()
param appInsightsConnectionString string

@description('Resource tags applied to all resources.')
param tags tagsType

// ========== Variables ==========

var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

// ========== Resources ==========

@description('App Service Plan for Logic Apps Standard with elastic scaling')
resource wfASP 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-${resourceSuffix}-asp'
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 3
  }
  kind: 'elastic'
  tags: tags
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

var functionsExtensionVersion = '~4'
var functionsWorkerRuntime = 'dotnet'
var extensionBundleId = 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
var extensionBundleVersion = '[1.*, 2.0.0)'

@description('Logic Apps Standard workflow engine for running business processes')
resource workflowEngine 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${resourceSuffix}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  tags: union(tags, { 'azd-service-name': 'workflows' })
  properties: {
    serverFarmId: wfASP.id
    publicNetworkAccess: 'Enabled'
    storageAccountRequired: true
    siteConfig: {
      alwaysOn: true
      webSocketsEnabled: true
      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 20
      use32BitWorkerProcess: false
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

@description('Application settings configuration for Logic App workflow engine')
resource wfConf 'Microsoft.Web/sites/config@2025-03-01' = {
  parent: workflowEngine
  name: 'appsettings'
  kind: 'functionapp,workflowapp'
  properties: {
    FUNCTIONS_EXTENSION_VERSION: functionsExtensionVersion
    FUNCTIONS_WORKER_RUNTIME: functionsWorkerRuntime
    AzureWebJobsStorage__accountName: workflowStorageAccountName
    AzureWebJobsStorage__blobServiceUri: 'https://${workflowStorageAccountName}.blob.${environment().suffixes.storage}'
    AzureWebJobsStorage__queueServiceUri: 'https://${workflowStorageAccountName}.queue.${environment().suffixes.storage}'
    AzureWebJobsStorage__tableServiceUri: 'https://${workflowStorageAccountName}.table.${environment().suffixes.storage}'
    AzureWebJobsStorage__fileServiceUri: 'https://${workflowStorageAccountName}.file.${environment().suffixes.storage}'
    AzureWebJobsStorage__credential: 'managedidentity'
    AzureWebJobsStorage__managedIdentityResourceId: userAssignedIdentityId
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
    AzureFunctionsJobHost__extensionBundle__id: extensionBundleId
    AzureFunctionsJobHost__extensionBundle__version: extensionBundleVersion
    WORKFLOWS_SUBSCRIPTION_ID: subscription().subscriptionId
    WORKFLOWS_AZURE_RESOURCE_GROUP_NAME: resourceGroup().name
    WORKFLOWS_LOCATION_NAME: location
    WORKFLOWS_TENANT_ID: subscription().tenantId
    WORKFLOWS_MANAGEMENT_BASE_URI: environment().resourceManager
  }
}

@description('Diagnostic settings for Logic App workflow engine')
resource wfDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workflowEngine.name}-diag'
  scope: workflowEngine
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: metricsSettings
  }
}

// ========== Outputs ==========

@description('Resource ID of the deployed Logic App')
output WORKFLOW_ENGINE_ID string = workflowEngine.id

@description('Name of the deployed Logic App')
output WORKFLOW_ENGINE_NAME string = workflowEngine.name

@description('Resource ID of the App Service Plan')
output WORKFLOW_ENGINE_ASP_ID string = wfASP.id

@description('Name of the App Service Plan')
output APP_SERVICE_PLAN_NAME string = wfASP.name
