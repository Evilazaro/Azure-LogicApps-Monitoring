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
param appInsightsConnectionString string

@description('Resource tags applied to all resources.')
param tags object

var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

var appServicePlanConfig = {
  sku: {
    name: 'P0v3'
    tier: 'Premium0V3'
    size: 'P0v3'
    family: 'Pv3'
  }
  kind: 'linux'
  reserved: true
}

var functionAppConfig = {
  runtime: 'DOTNETCORE'
  version: '9.0'
  kind: 'app,linux'
}

resource asp 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-${resourceSuffix}-apis-asp'
  location: location
  sku: {
    name: appServicePlanConfig.sku.name
    tier: appServicePlanConfig.sku.tier
    size: appServicePlanConfig.sku.size
    family: appServicePlanConfig.sku.family
    capacity: 1
  }
  kind: appServicePlanConfig.kind
  tags: tags
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: false
    maximumElasticWorkerCount: 1
    isSpot: false
    reserved: appServicePlanConfig.reserved
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource api 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${resourceSuffix}-api'
  location: location
  kind: functionAppConfig.kind
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: asp.id
    reserved: appServicePlanConfig.reserved
    siteConfig: {
      linuxFxVersion: '${functionAppConfig.runtime}|${functionAppConfig.version}'
      alwaysOn: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      appSettings: [
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
      ]
    }
    httpsOnly: true
  }
}

resource apiDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${api.name}-diag'
  scope: api
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}

resource aspDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${asp.name}-diag'
  scope: asp
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

@description('Resource ID of the deployed Function App')
output FUNCTION_APP_ID string = api.id

@description('Name of the deployed Function App')
output FUNCTION_APP_NAME string = api.name

@description('Default hostname of the Function App')
output FUNCTION_APP_DEFAULT_HOSTNAME string = api.properties.defaultHostName
