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

@description('Logs settings for the Log Analytics workspace.')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace.')
param metricsSettings object[]

@description('Name of the existing storage account required by Logic Apps Standard.')
@minLength(3)
@maxLength(24)
param workflowStorageAccountName string

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Instrumentation key for Application Insights instance.')
param appInsightsInstrumentationKey string

@description('Resource tags applied to all resources.')
param tags object = {}

var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

resource wfASP 'Microsoft.Web/serverfarms@2023-12-01' = {
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
  //tags: tags
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

resource wfASPDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${wfASP.name}-diag'
  scope: wfASP
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    metrics: metricsSettings
  }
}

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-${resourceSuffix}-mi'
  location: location
  //tags: tags
}

resource wfSA 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: workflowStorageAccountName
}

var rolDefSA = {
  contributor: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  blobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  queueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  tableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  fileDataContributor: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
}

var RolIdsSA = [
  rolDefSA.contributor
  rolDefSA.blobDataOwner
  rolDefSA.queueDataContributor
  rolDefSA.tableDataContributor
  rolDefSA.fileDataContributor
]

resource wfRaSA 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in RolIdsSA: {
    name: guid(workflowEngine.id, workflowEngine.name, roleId)
    scope: wfSA
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: mi.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

var functionsExtensionVersion = '~4'
var functionsWorkerRuntime = 'dotnet'
var extensionBundleId = 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
var extensionBundleVersion = '[1.*, 2.0.0)'

resource workflowEngine 'Microsoft.Web/sites@2023-12-01' = {
  name: '${name}-${resourceSuffix}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }
  //tags: tags
  properties: {
    serverFarmId: wfASP.id
    publicNetworkAccess: 'Enabled'
    storageAccountRequired: true
    siteConfig: {
      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 20

      autoHealEnabled: true

      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v6.0'
    }
  }
}

resource wfConf 'Microsoft.Web/sites/config@2025-03-01' = {
  name: 'appsettings'
  parent: workflowEngine
  properties: {
    FUNCTIONS_EXTENSION_VERSION: functionsExtensionVersion
    FUNCTIONS_WORKER_RUNTIME: functionsWorkerRuntime
    AzureWebJobsStorage__accountName: workflowStorageAccountName
    AzureWebJobsStorage__blobServiceUri: 'https://${workflowStorageAccountName}.blob.${environment().suffixes.storage}'
    AzureWebJobsStorage__queueServiceUri: 'https://${workflowStorageAccountName}.queue.${environment().suffixes.storage}'
    AzureWebJobsStorage__tableServiceUri: 'https://${workflowStorageAccountName}.table.${environment().suffixes.storage}'
    AzureWebJobsStorage__fileServiceUri: 'https://${workflowStorageAccountName}.file.${environment().suffixes.storage}'
    AzureWebJobsStorage__credential: 'managedidentity'
    AzureWebJobsStorage__managedIdentityResourceId: mi.id
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
    APPINSIGHTS_PROFILERFEATURE_VERSION: '1.0.0'
    APPINSIGHTS_SNAPSHOTFEATURE_VERSION: '1.0.0'
    APPLICATIONINSIGHTS_ENABLESQLQUERYCOLLECTION: 'true'
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    DiagnosticServices_EXTENSION_VERSION: '~3'
    DISABLE_APPINSIGHTS_SDK: 'disabled'
    IGNORE_APPINSIGHTS_SDK: 'disabled'
    InstrumentationEngine_EXTENSION_VERSION: 'enabled'
    SnapshotDebugger_EXTENSION_VERSION: 'enabled'
    WEBSITE_HEALTHCHECK_MAXPINGFAILURES: '5'
    XDT_MicrosoftApplicationInsights_BaseExtensions: 'enabled'
    XDT_MicrosoftApplicationInsights_Mode: 'recommended'
    XDT_MicrosoftApplicationInsights_PreemptSdk: 'enabled'
    AzureFunctionsJobHost__extensionBundle__id: extensionBundleId
    AzureFunctionsJobHost__extensionBundle__version: extensionBundleVersion
    WORKFLOWS_SUBSCRIPTION_ID: subscription().subscriptionId
    WORKFLOWS_RESOURCE_GROUP_NAME: resourceGroup().name
    WORKFLOWS_LOCATION_NAME: location
    WORKFLOWS_TENANT_ID: subscription().tenantId
    WORKFLOWS_MANAGEMENT_BASE_URI: environment().resourceManager
  }
}

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

@description('Resource ID of the deployed Logic App')
output WORKFLOW_ENGINE_ID string = workflowEngine.id

@description('Name of the deployed Logic App')
output WORKFLOW_ENGINE_NAME string = workflowEngine.name

@description('Resource ID of the App Service Plan')
output WORKFLOW_ENGINE_ASP_ID string = wfASP.id

@description('Name of the App Service Plan')
output APP_SERVICE_PLAN_NAME string = wfASP.name
