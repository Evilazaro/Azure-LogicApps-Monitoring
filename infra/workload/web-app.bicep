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
param tags object

var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

var aspConfig = {
  sku: {
    name: 'P0v3'
    tier: 'Premium0V3'
    size: 'P0v3'
    family: 'Pv3'
  }
  kind: 'linux'
  reserved: true
}

var appConfig = {
  runtime: 'DOTNETCORE'
  version: '10.0'
  kind: 'app,linux'
}

resource aspPoProc 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-${resourceSuffix}-apis-asp'
  location: location
  sku: {
    name: aspConfig.sku.name
    tier: aspConfig.sku.tier
    size: aspConfig.sku.size
    family: aspConfig.sku.family
    capacity: 3
  }
  kind: aspConfig.kind
  tags: tags
  properties: {
    perSiteScaling: true
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 3
    isSpot: false
    reserved: aspConfig.reserved
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource PoProcAspDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aspPoProc.name}-diag'
  scope: aspPoProc
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

resource PoProcAPI 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${resourceSuffix}-processing-api'
  location: location
  kind: 'web,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: aspPoProc.id
    reserved: aspConfig.reserved
    siteConfig: {
      linuxFxVersion: '${appConfig.runtime}|${appConfig.version}'
      alwaysOn: true
      acrUseManagedIdentityCreds: false
      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 10
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      numberOfWorkers: 3

      autoHealEnabled: true
    }
    httpsOnly: true
  }
}

resource PoProcConfig 'Microsoft.Web/sites/config@2025-03-01' = {
  name: 'appsettings'
  parent: PoProcAPI
  properties: {
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

@description('Resource ID of the deployed webApp App')
output API_WEB_APP_ID string = PoProcAPI.id

@description('Name of the deployed webApp App')
output API_WEB_APP_NAME string = PoProcAPI.name

@description('Default hostname of the webApp App')
output WEB_APP_DEFAULT_HOSTNAME string = PoProcAPI.properties.defaultHostName

resource aspPo 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-${resourceSuffix}-apis-asp'
  location: location
  sku: {
    name: aspConfig.sku.name
    tier: aspConfig.sku.tier
    size: aspConfig.sku.size
    family: aspConfig.sku.family
    capacity: 3
  }
  kind: aspConfig.kind
  tags: tags
  properties: {
    perSiteScaling: true
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 3
    isSpot: false
    reserved: aspConfig.reserved
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
}

resource aspPoDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${aspPo.name}-diag'
  scope: aspPo
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

resource PoAPI 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${resourceSuffix}--api'
  location: location
  kind: 'web,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: aspPo.id
    reserved: aspConfig.reserved
    siteConfig: {
      linuxFxVersion: '${appConfig.runtime}|${appConfig.version}'
      alwaysOn: true
      acrUseManagedIdentityCreds: false
      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 10
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      http20Enabled: true
      numberOfWorkers: 3

      autoHealEnabled: true
    }
    httpsOnly: true
  }
}

resource PoConfig 'Microsoft.Web/sites/config@2025-03-01' = {
  name: 'appsettings'
  parent: PoAPI
  properties: {
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

resource PoAPIDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${PoAPI.name}-diag'
  scope: PoAPI
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}

@description('Resource ID of the deployed webApp App')
output _ORDER_API_WEB_APP_ID string = PoAPI.id

@description('Name of the deployed webApp App')
output _ORDER_API_WEB_APP_NAME string = PoAPI.name

@description('Default hostname of the webApp App')
output _ORDER_API_WEB_APP_DEFAULT_HOSTNAME string = PoAPI.properties.defaultHostName
