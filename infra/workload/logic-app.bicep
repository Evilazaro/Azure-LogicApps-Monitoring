/*
  Logic Apps Standard Module (Refactored)
  ======================================
  - App Service Plan (WorkflowStandard / WS1) with elastic scale
  - Logic App Standard (Microsoft.Web/sites) with User Assigned Identity
  - Runtime app settings wired to an existing storage account (required)
  - Optional “private storage” switch (WEBSITE_CONTENTOVERVNET)

  Key refactors vs original:
  - Use storage *resourceId* (no same-RG assumptions)
  - Single listKeys() call reused
  - Conditional WEBSITE_CONTENTOVERVNET
  - WORKFLOWS_TENANT_ID uses tenant().tenantId
  - Safer/cleaner naming and variables
*/

import { triggersType as triggers } from '../types.bicep'

metadata name = 'Logic Apps Standard'
metadata description = 'Deploys Logic Apps Standard workflow engine with App Service Plan'

// ========== Type Definitions ==========
import { tagsType } from '../types.bicep'

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

@description('Resource ID of the User Assigned Identity to be used by the Logic App.')
@minLength(50)
param userAssignedIdentityId string

@description('User Assigned Identity name for reference.')
@minLength(3)
@maxLength(24)
param userAssignedIdentityName string

@description('Service Bus Namespace to be used by the Logic App.')
@minLength(3)
@maxLength(50)
param serviceBusNamespace string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Resource ID of the storage account used for diagnostic logs and metrics.')
@minLength(50)
param diagnosticsStorageAccountId string

@description('Metrics settings for diagnostic configurations.')
param metricsSettings object[]

// workflowStorageAccountId is passed from parent module but not currently used
// The storage account is accessed via managed identity using workflowStorageAccountName
// This parameter is retained for potential future use
// Suppress unused parameter warning as this is part of the module interface
#disable-next-line no-unused-params
param workflowStorageAccountId string

@description('Name of the existing storage account required by Logic Apps Standard runtime.')
@minLength(3)
@maxLength(24)
param workflowStorageAccountName string

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Resource tags applied to all resources.')
param tags tagsType

// ========== Variables ==========
@description('Unique suffix for resource naming based on resource group and parameters')
var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

@description('App Service Plan name for Logic Apps Standard')
var planName = '${name}-${resourceSuffix}-asp'
@description('Logic App workflow engine name')
var logicAppName = '${name}-${resourceSuffix}-logicapp'

// Functions/Logic Apps runtime settings
@description('Azure Functions runtime version')
var functionsExtensionVersion = '~4'
@description('Functions worker runtime language')
var functionsWorkerRuntime = 'dotnet'

@description('Logic Apps extension bundle identifier')
var extensionBundleId = 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
@description('Logic Apps extension bundle version range')
var extensionBundleVersion = '[1.*, 2.0.0)'

// Content share name
@description('File share name for Logic App workflow state')
var contentShareName = 'workflowstate'

// ========== Resources ==========

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup()
}

@description('Unique suffix for connection naming to avoid conflicts')
var connectionSuffix = uniqueString(resourceGroup().id, name, envName)

@description('Service Bus connection name with unique suffix')
var sbConnName = 'servicebus-${connectionSuffix}'

resource sbConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: sbConnName
  location: location
  kind: 'V2'
  properties: {
    displayName: 'Service Bus Connection'
    api: {
      // Reference the managed API in Azure
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
      name: 'servicebus'
      type: 'Microsoft.Web/locations/managedApis'
    }
    // For managed identity authentication
    customParameterValues: {
      authenticationType: 'managedIdentityAuth'
      serviceBusNamespace: '${serviceBusNamespace}.servicebus.windows.net'
    }
  }
}

resource sbConnectionAccessPolicy 'Microsoft.Web/connections/accessPolicies@2018-07-01-preview' = {
  name: logicAppName // Typically named after the Logic App
  parent: sbConnection
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: mi.properties.principalId // The managed identity's principal ID
      }
    }
  }
}

// Create a connection for Storage Account using Managed Identity
resource storageConnection 'Microsoft.Web/connections@2018-07-01-preview' = {
  name: 'storage-connection-${resourceSuffix}'
  location: location
  kind: 'V2'
  properties: {
    displayName: 'Storage Account Connection'
    api: {
      id: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
      name: 'azureblob'
      type: 'Microsoft.Web/locations/managedApis'
    }
    customParameterValues: {
      authenticationType: 'managedIdentityAuth'
      accountName: workflowStorageAccountName
    }
  }
}

resource storageConnectionAccessPolicy 'Microsoft.Web/connections/accessPolicies@2018-07-01-preview' = {
  name: storageConnection.name
  parent: storageConnection
  location: location
  properties: {
    principal: {
      type: 'ActiveDirectory'
      identity: {
        tenantId: subscription().tenantId
        objectId: mi.properties.principalId // The managed identity's principal ID
      }
    }
  }
}

@description('App Service Plan for Logic Apps Standard with elastic scaling')
resource wfASP 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: planName
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 3
  }
  kind: 'elastic'
  tags: tags
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
  }
  dependsOn: [
    mi
    sbConnection
    storageConnection
    sbConnectionAccessPolicy
    storageConnectionAccessPolicy
  ]
}

@description('Logic Apps Standard workflow engine for running business processes')
resource workflowEngine 'Microsoft.Web/sites@2025-03-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  tags: union(tags, {
    'azd-service-name': 'workflows'
  })
  properties: {
    serverFarmId: wfASP.id
    publicNetworkAccess: 'Enabled'
    siteConfig: {
      alwaysOn: true
      webSocketsEnabled: true
    }
  }
  dependsOn: [
    mi
    sbConnection
    sbConnectionAccessPolicy
    storageConnection
    storageConnectionAccessPolicy
  ]
}

@description('Application settings configuration for Logic App workflow engine')
resource wfConf 'Microsoft.Web/sites/config@2025-03-01' = {
  parent: workflowEngine
  name: 'appsettings'
  properties: {
    // Storage Account connection settings (referenced by connections.json)
    STORAGE_API_ID: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'azureblob')
    STORAGE_CONNECTION_ID: storageConnection.id
    STORAGE_RUNTIME_URL: storageConnection.properties.connectionRuntimeUrl

    // Service Bus API Connection settings (referenced by connections.json)
    SERVICEBUS_API_ID: subscriptionResourceId('Microsoft.Web/locations/managedApis', location, 'servicebus')
    SERVICEBUS_CONNECTION_ID: sbConnection.id
    SERVICEBUS_RUNTIME_URL: sbConnection.properties.connectionRuntimeUrl
    // Functions runtime
    FUNCTIONS_EXTENSION_VERSION: functionsExtensionVersion
    FUNCTIONS_WORKER_RUNTIME: functionsWorkerRuntime

    AzureWebJobsStorage__managedIdentityResourceId: userAssignedIdentityId
    AzureWebJobsStorage__credential: 'managedIdentity'
    AzureWebJobsStorage__blobServiceUri: 'https://${workflowStorageAccountName}.blob.${environment().suffixes.storage}/'
    AzureWebJobsStorage__queueServiceUri: 'https://${workflowStorageAccountName}.queue.${environment().suffixes.storage}/'
    AzureWebJobsStorage__tableServiceUri: 'https://${workflowStorageAccountName}.table.${environment().suffixes.storage}/'

    // App Insights
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'

    // Extension bundle for Logic Apps actions
    AzureFunctionsJobHost__extensionBundle__id: extensionBundleId
    AzureFunctionsJobHost__extensionBundle__version: extensionBundleVersion

    // Workflow runtime configuration
    WORKFLOWS_SUBSCRIPTION_ID: subscription().subscriptionId
    WORKFLOWS_RESOURCE_GROUP_NAME: resourceGroup().name
    WORKFLOWS_LOCATION_NAME: location
    WORKFLOWS_TENANT_ID: tenant().tenantId
  }
}

var wfTriggers = loadJsonContent('./workflow-triggers.json')

// resource wk 'Microsoft.Logic/workflows@2019-05-01' = {
//   name: 'wk'
//   location: location
//   tags: tags
//   properties: {
//     definition: {
//       '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
//       triggers: wfTriggers
//     }
//   }
//   dependsOn: [
//     workflowEngine
//     sbConnection
//   ]
// }

@description('Diagnostic settings for Logic App workflow engine')
resource wfDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workflowEngine.name}-diag'
  scope: workflowEngine
  properties: {
    workspaceId: workspaceId
    // Using diagnosticsStorageAccountId for diagnostic logs
    // workflowStorageAccountId is available but not used here as it's for Logic App runtime storage
    storageAccountId: diagnosticsStorageAccountId
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: metricsSettings
  }
}

// ========== Outputs ==========
output logicAppName string = workflowEngine.name
output logicAppId string = workflowEngine.id
output appServicePlanId string = wfASP.id
output contentShareName string = contentShareName
output workflowStorageAccountName string = workflowStorageAccountName

// Service Bus Connection outputs
output serviceBusConnectionName string = sbConnection.name
output serviceBusConnectionId string = sbConnection.id
output serviceBusConnectionRuntimeUrl string = sbConnection.properties.connectionRuntimeUrl
