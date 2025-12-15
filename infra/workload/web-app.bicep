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

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Workflow Storage Account Name for the API App.')
param workflowStorageAccountName string

@description('Logs settings for the Log Analytics workspace.')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace.')
param metricsSettings object[]

@description('Connection string for Application Insights instance.')
@secure()
param appInsightsConnectionString string

@description('Application Insights Instrumentation Key.')
@secure()
param appInsightsInstrumentationKey string

@description('Resource tags applied to all resources.')
param tags tagsType

// ========== Variables ==========

var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

var aspConf = {
  sku: {
    name: 'P0v3'
    tier: 'Premium0V3'
    size: 'P0v3'
    family: 'Pv3'
  }
  kind: 'linux'
  reserved: true
}

var appConf = {
  runtime: 'DOTNETCORE'
  version: '9.0'
  kind: 'app,linux'
}

// ========== Resources ==========

@description('App Service Plan for Purchase Order Web Application')
resource PoASP 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-${resourceSuffix}-po-asp'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: aspConf.sku.name
    tier: aspConf.sku.tier
    size: aspConf.sku.size
    family: aspConf.sku.family
    capacity: 3
  }
  kind: aspConf.kind
  tags: tags
  properties: {
    perSiteScaling: true
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 3
    isSpot: false
    reserved: aspConf.reserved
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

@description('Diagnostic settings for Purchase Order App Service Plan')
resource aspPoDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${PoASP.name}-diag'
  scope: PoASP
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

@description('Web App for Purchase Order management application')
resource PoWebApp 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${resourceSuffix}-po-webapp'
  location: location
  kind: 'web,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: union(tags, { 'azd-service-name': 'PoWebApp' })
  properties: {
    serverFarmId: PoASP.id
    reserved: aspConf.reserved
    siteConfig: {
      linuxFxVersion: '${appConf.runtime}|${appConf.version}'
      alwaysOn: true
      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 10
      numberOfWorkers: 3
      webSocketsEnabled: true // Already enabled ✓
      http20Enabled: true // This needs verification
    }
    clientAffinityEnabled: true // Already enabled ✓
    clientAffinityProxyEnabled: true // This needs verification
    httpsOnly: true
  }
}

@description('Application settings for Purchase Order Web Application')
resource PoConf 'Microsoft.Web/sites/config@2025-03-01' = {
  parent: PoWebApp
  name: 'appsettings'
  properties: {
    ASPNETCORE_ENVIRONMENT: 'Production'
    AzureWebJobsStorage__accountName: workflowStorageAccountName
    AzureWebJobsStorage__queueServiceUri: 'https://${workflowStorageAccountName}.queue.${environment().suffixes.storage}'
    AzureWebJobsStorage__credential: 'managedidentity'
    AzureWebJobsStorage__managedIdentityResourceId: PoWebApp.identity.principalId
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
    AZURE_TENANT_ID: tenant().tenantId
  }
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

@description('Reference to existing workflow storage account')
resource wfSA 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: workflowStorageAccountName
  scope: resourceGroup()
}

@description('Role assignments granting Web App access to workflow storage account')
resource wfRaSA 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in RolIdsSA: {
    name: guid(PoWebApp.id, PoWebApp.name, roleId)
    scope: wfSA
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: PoWebApp.identity.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

@description('Diagnostic settings for Purchase Order Web Application')
resource PoWEBDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${PoWebApp.name}-diag'
  scope: PoWebApp
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}

// ========== Outputs ==========

@description('Resource ID of the deployed webApp App')
output PO_WEB_APP_ID string = PoWebApp.id

@description('Name of the deployed webApp App')
output PO_WEB_APP_NAME string = PoWebApp.name

@description('Default hostname of the webApp App')
output PO_WEB_APP_DEFAULT_HOST_NAME string = PoWebApp.properties.defaultHostName
