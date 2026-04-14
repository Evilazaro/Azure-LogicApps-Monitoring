/*
  Application Insights Module
  ===========================
  Deploys a workspace-based Application Insights instance for centralized
  application telemetry and monitoring.
  
  Features:
  - Workspace-based Application Insights (connected to Log Analytics workspace)
  - Public network access enabled for both ingestion and query operations
  - Diagnostic settings for forwarding Application Insights telemetry to
    Log Analytics and Storage Account
  - Web application type configuration for general-purpose monitoring scenarios
  - Unique resource naming using resource group, environment, and location
  
  Parameters:
  - name: Base name prefix for the Application Insights resource
  - location: Azure region for deployment (defaults to resource group location)
  - envName: Environment identifier (dev, test, staging, prod)
  - logAnalyticsWorkspaceId: Resource ID of the Log Analytics workspace for integration
  - storageAccountId: Resource ID of the Storage Account for diagnostic logs
  - logsSettings: Array of log category configurations for diagnostics
  - metricsSettings: Array of metric category configurations for diagnostics
  - tags: Resource tags for organization and cost management
  
  Outputs:
  - APPLICATION_INSIGHTS_NAME: Name of the deployed Application Insights instance
  - APPLICATION_INSIGHTS_INSTRUMENTATION_KEY: Instrumentation key for legacy SDK integrations
  - APPLICATIONINSIGHTS_CONNECTION_STRING: Connection string for modern SDK telemetry
  
  Usage Example:
  ```bicep
  module appInsights 'shared/monitoring/app-insights.bicep' = {
    name: 'appInsightsDeploy'
    params: {
      name: 'myapp'
      envName: 'dev'
      logAnalyticsWorkspaceId: logAnalytics.outputs.workspaceId
      storageAccountId: storageAccount.outputs.id
      logsSettings: [{ category: 'AppTraces', enabled: true }]
      metricsSettings: [{ category: 'AllMetrics', enabled: true }]
      tags: { environment: 'dev' }
    }
  }
  ```
*/

metadata name = 'Application Insights'
metadata description = 'Deploys workspace-based Application Insights for application telemetry and monitoring'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for Application Insights.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for Application Insights deployment.')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Environment name to differentiate deployments.')
@maxLength(10)
@allowed([
  'dev'
  'test'
  'prod'
  'staging'
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

// ========== Outputs ==========

@description('Name of the deployed Application Insights instance')
output APPLICATION_INSIGHTS_NAME string = appInsights.name

@description('Instrumentation key for Application Insights telemetry')
output APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = appInsights.properties.InstrumentationKey

@description('Connection string for Application Insights telemetry')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = appInsights.properties.ConnectionString
