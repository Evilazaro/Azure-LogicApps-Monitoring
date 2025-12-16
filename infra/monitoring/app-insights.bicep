/*
  Application Insights Module
  ===========================
  Deploys workspace-based Application Insights instance.
  
  Features:
  - Workspace-based Application Insights (connected to Log Analytics)
  - Public network access enabled for ingestion and query
  - Diagnostic settings for Application Insights telemetry
  - Web application type for general-purpose monitoring
  
  Outputs:
  - Connection string for application telemetry
  - Instrumentation key for legacy integrations
  - Resource name for reference
*/

metadata name = 'Application Insights'
metadata description = 'Deploys workspace-based Application Insights for application telemetry and monitoring'

// ========== Type Definitions ==========

import { tagsType } from '../types.bicep'

// ========== Parameters ==========

@description('Base name for Application Insights.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for Application Insights deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

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

@description('Resource ID of the Log Analytics workspace for workspace-based Application Insights integration.')
param logAnalyticsWorkspaceId string

@description('Resource ID of the Storage Account for the Application Insights diagnostic settings.')
param storageAccountId string

@description('Logs settings for diagnostic configurations.')
param logsSettings object[]

@description('Metrics settings for diagnostic configurations.')
param metricsSettings object[]

@description('Resource tags applied to Application Insights.')
param tags tagsType

// ========== Resources ==========

@description('Application Insights instance for application telemetry and monitoring')
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-appinsights'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// ========== Outputs ==========

@description('Name of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = appInsights.name

@description('Instrumentation key for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = appInsights.properties.InstrumentationKey

@description('Connection string for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = appInsights.properties.ConnectionString

@description('Diagnostic settings for Application Insights')
resource appDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appInsights.name}-diag'
  scope: appInsights
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}
