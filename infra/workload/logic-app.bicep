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

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Resource ID of the storage account used for diagnostic logs and metrics.')
@minLength(50)
param diagnosticsStorageAccountId string

@description('Metrics settings for diagnostic configurations.')
param metricsSettings object[]

@description('Resource ID of the existing storage account required by Logic Apps Standard runtime (AzureWebJobsStorage + content share).')
@minLength(50)
param workflowStorageAccountId string

@description('Name of the existing storage account required by Logic Apps Standard runtime.')
@minLength(3)
@maxLength(24)
param workflowStorageAccountName string

@description('Confirmation that storage role assignments are complete before configuring Logic App.')
param storageRoleAssignmentsComplete bool

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Enable mounting the content share over VNet. Set true ONLY when private storage + VNet integration + DNS are configured.')
param usePrivateStorage bool = false

@description('If true, sets WEBSITE_RUN_FROM_PACKAGE=1. Only enable when you deploy as package/zip.')
param runFromPackage bool = false

@description('Resource tags applied to all resources.')
param tags tagsType

// ========== Variables ==========
var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

var planName = '${name}-${resourceSuffix}-asp'
var logicAppName = '${name}-${resourceSuffix}-logicapp'

// Functions/Logic Apps runtime settings
var functionsExtensionVersion = '~4'
var functionsWorkerRuntime = 'dotnet'

var extensionBundleId = 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
var extensionBundleVersion = '[1.*, 2.0.0)'

// Content share name
var contentShareName = '${logicAppName}-content'

// Storage connection string for file share (required for initial setup)
// Runtime operations will use managed identity via AzureWebJobsStorage__* settings
var storageKey = listKeys(workflowStorageAccountId, '2025-06-01').keys[0].value
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${workflowStorageAccountName};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageKey}'

// ========== Resources ==========

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
    storageAccountRequired: false // Set to false initially to prevent auto-creation of file share

    siteConfig: {
      alwaysOn: true
      webSocketsEnabled: true

      minimumElasticInstanceCount: 3
      elasticWebAppScaleLimit: 20

      use32BitWorkerProcess: false
      ftpsState: 'FtpsOnly'
      minTlsVersion: '1.2'

      // Pre-configure app settings during site creation to avoid separate deployment
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionsExtensionVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionsWorkerRuntime
        }
        {
          name: 'AzureWebJobsStorage__accountName'
          value: workflowStorageAccountName
        }
        {
          name: 'AzureWebJobsStorage__credentialType'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__managedIdentityResourceId'
          value: userAssignedIdentityId
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: extensionBundleId
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: extensionBundleVersion
        }
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: subscription().subscriptionId
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: resourceGroup().name
        }
        {
          name: 'WORKFLOWS_LOCATION_NAME'
          value: location
        }
        {
          name: 'WORKFLOWS_TENANT_ID'
          value: tenant().tenantId
        }
        {
          name: 'WORKFLOWS_MANAGEMENT_BASE_URI'
          value: environment().resourceManager
        }
      ]
    }

    httpsOnly: true
  }
}

@description('Application settings configuration for Logic App workflow engine')
resource wfConf 'Microsoft.Web/sites/config@2025-03-01' = {
  parent: workflowEngine
  name: 'appsettings'
  properties: {
    // Functions runtime
    FUNCTIONS_EXTENSION_VERSION: functionsExtensionVersion
    FUNCTIONS_WORKER_RUNTIME: functionsWorkerRuntime

    // Required storage settings for Logic Apps Standard host with Managed Identity
    // Note: Requires RBAC role assignments to be complete (storageRoleAssignmentsComplete = ${storageRoleAssignmentsComplete})
    // AzureWebJobsStorage uses managed identity for runtime operations
    AzureWebJobsStorage__accountName: workflowStorageAccountName
    AzureWebJobsStorage__credentialType: 'managedidentity'
    AzureWebJobsStorage__managedIdentityResourceId: userAssignedIdentityId

    // Content share settings required for Logic Apps runtime
    // The file share is pre-created in the storage module with proper role assignments
    WEBSITE_CONTENTSHARE: contentShareName
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING: storageConnectionString

    // Only enable when private storage is correctly configured
    WEBSITE_CONTENTOVERVNET: usePrivateStorage ? '1' : '0'

    // Deployment mode (optional)
    WEBSITE_RUN_FROM_PACKAGE: runFromPackage ? '1' : '0'

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
    WORKFLOWS_MANAGEMENT_BASE_URI: environment().resourceManager
  }
}

@description('Diagnostic settings for Logic App workflow engine')
resource wfDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workflowEngine.name}-diag'
  scope: workflowEngine
  properties: {
    workspaceId: workspaceId
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
