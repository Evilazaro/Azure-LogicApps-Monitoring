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

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

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

@description('App Service Plan for Purchase Order Processing API')
resource PoProcAsp 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-${resourceSuffix}-poproc-asp'
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

@description('Diagnostic settings for Purchase Order Processing App Service Plan')
resource PoProcAspDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${PoProcAsp.name}-diag'
  scope: PoProcAsp
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

@description('Web App for Purchase Order Processing API')
resource PoProcAPI 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${resourceSuffix}-poproc-api'
  location: location
  kind: 'web,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: union(tags, { 'azd-service-name': 'PoProcAPI' })
  properties: {
    serverFarmId: PoProcAsp.id
    reserved: aspConf.reserved
    siteConfig: {
      linuxFxVersion: '${appConf.runtime}|${appConf.version}'
      alwaysOn: true
      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 10
      numberOfWorkers: 3
      http20Enabled: true
    }
    httpsOnly: true
  }
}

@description('Application settings for Purchase Order Processing API')
resource PoProcConf 'Microsoft.Web/sites/config@2025-03-01' = {
  parent: PoProcAPI
  name: 'appsettings'
  properties: {
    ASPNETCORE_ENVIRONMENT: 'Production'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsightsInstrumentationKey
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
  }
}

@description('Diagnostic settings for Purchase Order Processing API')
resource PoProcApiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${PoProcAPI.name}-diag'
  scope: PoProcAPI
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
output PO_PROC_API_WEB_APP_ID string = PoProcAPI.id

@description('Name of the deployed webApp App')
output PO_PROC_API_WEB_APP_NAME string = PoProcAPI.name

@description('Default hostname of the webApp App')
output PO_PROC_API_DEFAULT_HOST_NAME string = PoProcAPI.properties.defaultHostName
