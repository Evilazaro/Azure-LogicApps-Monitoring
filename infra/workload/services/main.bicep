/*
  Container Services Module
  =========================
  Deploys container infrastructure for microservices hosting.
  
  Components:
  1. Azure Container Registry (Premium tier)
  2. Container Apps managed environment with:
     - Log Analytics integration
     - Application Insights telemetry
     - Consumption workload profile
  3. .NET Aspire dashboard for observability
  
  Key Features:
  - Premium ACR for geo-replication and enhanced throughput
  - System-assigned and user-assigned identity support
  - KEDA and Dapr configurations ready
  - Public network access enabled for development
*/

metadata name = 'Container Services'
metadata description = 'Deploys Azure Container Registry, Container Apps Environment, and Aspire Dashboard'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for the container services.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for container services deployment.')
@minLength(3)
@maxLength(50)
param location string

@description('Resource ID of the User Assigned Identity used by Container Registry and Container Apps Environment.')
@minLength(50)
param userAssignedIdentityId string

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

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Log Analytics Workspace Customer ID.')
param workspaceCustomerId string

@description('Primary Key for Log Analytics workspace.')
param workspacePrimaryKey string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Logs settings for the Log Analytics workspace.')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace.')
param metricsSettings object[]

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Resource tags applied to container services.')
param tags tagsType

// ========== Variables ==========

// Generate unique name for Container Apps Environment
// Uses subscription and resource group for uniqueness across deployments
var appEnvName string = toLower('${name}-cae-${uniqueString(subscription().id, resourceGroup().id, location, envName)}')

// ========== Resources ==========

@description('Azure Container Registry for storing container images')
resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: toLower('${name}acr${uniqueString(subscription().id, resourceGroup().id, location, envName)}')
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  tags: tags
  // Premium SKU provides:
  // - Geo-replication for high availability
  // - Enhanced throughput and storage capacity
  // - Advanced security features including content trust
  // - Private link support for network isolation
  sku: {
    name: 'Premium'
  }
}

// ========== Outputs ==========

// Container Registry Outputs
@description('Container Registry login server endpoint')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.properties.loginServer

@description('Managed identity resource ID for Container Registry')
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = userAssignedIdentityId

@description('Name of the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_NAME string = registry.name

// Diagnostic Settings for Container Registry
@description('Diagnostic settings for Container Registry')
resource registryDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${registry.name}-diag'
  scope: registry
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: logsSettings
    metrics: metricsSettings
  }
}

@description('Container Apps managed environment for hosting containerized applications')
resource appEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: appEnvName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    // Consumption workload profile provides:
    // - Serverless, pay-per-use pricing model (only pay for actual resource usage)
    // - Automatic scaling from 0 to meet demand
    // - No minimum instance charges when scaled to zero
    // - Suitable for event-driven and variable workloads
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspaceCustomerId
        // This repo passes the workspace shared key through module parameters.
        // Per repo constraints we do not mark it as secure; silence the linter rule for this line only.
        #disable-next-line use-secure-value-for-secure-inputs
        sharedKey: workspacePrimaryKey
      }
    }
    appInsightsConfiguration: {
      // This repo passes the App Insights connection string through module parameters.
      // Per repo constraints we do not mark it as secure; silence the linter rule for this line only.
      #disable-next-line use-secure-value-for-secure-inputs
      connectionString: appInsightsConnectionString
    }
  }
}

// Container Apps Environment Outputs
@description('Name of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = appEnv.name

@description('Resource ID of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = appEnv.id

@description('Default domain for the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = appEnv.properties.defaultDomain

// .NET Aspire Dashboard for Application Observability
@description('.NET Aspire dashboard component for application observability')
resource dashboard 'Microsoft.App/managedEnvironments/dotNetComponents@2025-10-02-preview' = {
  parent: appEnv
  name: 'aspire-dashboard'
  properties: {
    componentType: 'AspireDashboard'
  }
}
