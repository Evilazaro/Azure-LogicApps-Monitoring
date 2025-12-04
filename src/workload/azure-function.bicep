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

@description('Resource tags applied to all resources.')
param tags object

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

var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)
var appServicePlanName = '${name}-${resourceSuffix}-apis-asp'
var functionAppName = '${name}-${resourceSuffix}-api'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
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

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup()
}

resource webApi 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: functionAppConfig.kind
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
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
          value: appInsights.properties.ConnectionString
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

resource webApiDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${webApi.name}-diag'
  scope: webApi
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'AppServiceHTTPLogs'
        enabled: true
      }
      {
        category: 'AppServiceConsoleLogs'
        enabled: true
      }
      {
        category: 'AppServiceAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}

resource DiagnosticSettingsAsp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appServicePlan.name}-diag'
  scope: appServicePlan
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}

@description('Resource ID of the deployed Function App')
output FUNCTION_APP_ID string = webApi.id

@description('Name of the deployed Function App')
output FUNCTION_APP_NAME string = webApi.name

@description('Default hostname of the Function App')
output FUNCTION_APP_DEFAULT_HOSTNAME string = webApi.properties.defaultHostName
