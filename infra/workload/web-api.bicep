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
param appInsightsConnectionString string

@description('Application Insights Instrumentation Key.')
param appInsightsInstrumentationKey string

@description('Resource tags applied to all resources.')
param tags object = {}

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
      acrUseManagedIdentityCreds: false
      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 10
      ftpsState: 'Enabled'
      webSocketsEnabled: true
      minTlsVersion: '1.2'
      http20Enabled: true
      numberOfWorkers: 3
      http20ProxyFlag: 1
      autoHealEnabled: true
    }
    httpsOnly: true
  }
}

resource PoProcConf 'Microsoft.Web/sites/config@2025-03-01' = {
  name: 'appsettings'
  parent: PoProcAPI
  properties: {
    ASPNETCORE_ENVIRONMENT: 'Production'
    APPINSIGHTS_INSTRUMENTATIONKEY: appInsightsInstrumentationKey
    APPINSIGHTS_PROFILERFEATURE_VERSION: '1.0.0'
    APPINSIGHTS_SNAPSHOTFEATURE_VERSION: '1.0.0'
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
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
  }
}

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
