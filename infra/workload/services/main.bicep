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

@description('Resource ID of the User Assigned Identity to be used by Service Bus.')
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
@secure()
param workspacePrimaryKey string

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

@description('Name of the storage account for Container Apps persistent storage.')
param caVolumeMountSAName string

@description('Storage account key for Azure Files mount.')
@secure()
param caVolumeMountSAKey string

@description('Name of the file share for orders-api persistent data.')
param caVolumeMountFileShareName string

@description('Resource tags applied to container services.')
param tags tagsType

// ========== Variables ==========

var storageVolumeName string = 'orders-storage'

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
  sku: {
    name: 'Premium'
  }
}

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

// Generate unique name for Container Apps Environment
// Uses subscription and resource group for uniqueness across deployments
var appEnvName string = toLower('${name}-cae-${uniqueString(subscription().id, resourceGroup().id, location, envName)}')

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
        sharedKey: workspacePrimaryKey
      }
    }
    appInsightsConfiguration: {
      connectionString: appInsightsConnectionString
    }
  }
}

@description('.NET Aspire dashboard component for application observability')
resource dashboard 'Microsoft.App/managedEnvironments/dotNetComponents@2025-10-02-preview' = {
  parent: appEnv
  name: 'aspire-dashboard'
  properties: {
    componentType: 'AspireDashboard'
  }
}

resource appEnvStorage 'Microsoft.App/managedEnvironments/storages@2025-02-02-preview' = {
  parent: appEnv
  name: storageVolumeName
  properties: {
    azureFile: {
      accountName: caVolumeMountSAName
      shareName: caVolumeMountFileShareName
      accountKey: caVolumeMountSAKey
      accessMode: 'ReadWrite'
    }
  }
}

// ========== Outputs ==========

@description('Login server endpoint for the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = registry.properties.loginServer

@description('Name of the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_NAME string = registry.name

@description('Resource ID of the Container Apps managed environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = appEnv.id

@description('Name of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = appEnv.name

@description('Default domain for the Container Apps environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = appEnv.properties.defaultDomain

@description('Name of the storage volume mount for orders-api')
output ORDERS_STORAGE_VOLUME_NAME string = storageVolumeName
