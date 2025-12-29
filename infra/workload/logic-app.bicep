/*
  Logic Apps Standard Module
  ==========================
  Deploys Logic Apps Standard workflow engine with elastic App Service Plan.
  
  Components:
  1. App Service Plan (WorkflowStandard tier)
     - Elastic scaling: 3-20 instances
     - WS1 SKU for production workloads
  2. Logic App (functionapp, workflowapp kind)
     - Managed identity authentication
     - Application Insights integration
     - Functions runtime v4
  
  Configuration:
  - Uses existing storage account (required for Logic Apps Standard)
  - Extension bundle for workflow actions/triggers
  - Always-on enabled for reliable execution
  - HTTPS only with TLS 1.2 minimum
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

@description('Resource ID of the User Assigned Identity to be used by Service Bus.')
@minLength(50)
param userAssignedIdentityId string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Metrics settings for diagnostic configurations.')
param metricsSettings object[]

@description('Name of the existing storage account required by Logic Apps Standard.')
@minLength(3)
@maxLength(24)
param workflowStorageAccountName string

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Resource tags applied to all resources.')
param tags tagsType

// ========== Variables ==========

var resourceSuffix string = uniqueString(resourceGroup().id, name, envName, location)

// ========== Resources ==========

@description('App Service Plan for Logic Apps Standard with elastic scaling')
resource wfASP 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-${resourceSuffix}-asp'
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
    // Scale the entire plan uniformly rather than individual sites
    perSiteScaling: false
    // Enable automatic elastic scaling based on workload demand
    elasticScaleEnabled: true
    // Maximum number of instances the plan can scale out to under heavy load
    maximumElasticWorkerCount: 20
    // Use standard instances instead of low-cost spot instances for reliability
    isSpot: false
    // Windows-based hosting for Logic Apps Standard runtime
    reserved: false
    // Standard App Service containers (not Xenon)
    isXenon: false
    // Standard virtualization (not Hyper-V)
    hyperV: false
    // Auto-scaling manages worker count dynamically (0 = automatic)
    targetWorkerCount: 0
    // Auto-scaling manages worker size dynamically (0 = automatic)
    targetWorkerSizeId: 0
    // Zone redundancy disabled for cost optimization (enable for production HA)
    zoneRedundant: false
  }
}

// ========== Variables ==========

// Azure Functions runtime configuration for Logic Apps Standard
// Logic Apps Standard is built on Azure Functions v4 runtime
var functionsExtensionVersion string = '~4'
var functionsWorkerRuntime string = 'dotnet'

// Workflow extension bundle provides Logic Apps actions and triggers
// The bundle includes all standard connectors and actions without requiring individual installations
// Version range [1.*, 2.0.0) allows automatic patch updates within 1.x but prevents breaking changes from 2.0
var extensionBundleId string = 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
var extensionBundleVersion string = '[1.*, 2.0.0)'

@description('Logic Apps Standard workflow engine for running business processes')
resource workflowEngine 'Microsoft.Web/sites@2025-03-01' = {
  name: '${name}-${resourceSuffix}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  tags: union(tags, { 'azd-service-name': 'workflows' })
  properties: {
    serverFarmId: wfASP.id
    publicNetworkAccess: 'Enabled'
    // Logic Apps Standard requires a storage account for workflow state and runtime data
    storageAccountRequired: true
    siteConfig: {
      // Keep the app always loaded to prevent cold starts and ensure reliable execution
      alwaysOn: true
      // WebSockets support required for Logic Apps runtime communication
      webSocketsEnabled: true
      // Minimum number of pre-warmed instances to handle baseline load
      minimumElasticInstanceCount: 3
      // Maximum number of instances allowed during scale-out
      elasticWebAppScaleLimit: 20
      // Use 64-bit worker process for better performance and memory capacity
      use32BitWorkerProcess: false
      // Require FTPS (FTP over SSL) for secure file transfers
      ftpsState: 'FtpsOnly'
      // Enforce TLS 1.2 minimum for secure HTTPS connections
      minTlsVersion: '1.2'
    }
    httpsOnly: true
  }
}

// Configure Logic App runtime settings
// Uses managed identity for storage authentication (no connection strings)
// All workflow settings configured for Azure environment
@description('Application settings configuration for Logic App workflow engine')
resource wfConf 'Microsoft.Web/sites/config@2025-03-01' = {
  parent: workflowEngine
  name: 'appsettings'
  kind: 'functionapp,workflowapp'
  properties: {
    FUNCTIONS_EXTENSION_VERSION: functionsExtensionVersion
    FUNCTIONS_WORKER_RUNTIME: functionsWorkerRuntime
    // Managed identity authentication for storage
    AzureWebJobsStorage__accountName: workflowStorageAccountName
    AzureWebJobsStorage__blobServiceUri: 'https://${workflowStorageAccountName}.blob.${environment().suffixes.storage}'
    AzureWebJobsStorage__queueServiceUri: 'https://${workflowStorageAccountName}.queue.${environment().suffixes.storage}'
    AzureWebJobsStorage__tableServiceUri: 'https://${workflowStorageAccountName}.table.${environment().suffixes.storage}'
    AzureWebJobsStorage__credentialType: 'managedIdentity'
    AzureWebJobsStorage__managedIdentityResourceId: userAssignedIdentityId
    // Website content share configuration for Logic Apps using managed identity
    WEBSITE_CONTENTOVERVNET: '1'
    WEBSITE_CONTENTSHARE: '${workflowEngine.name}-content'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__accountName: workflowStorageAccountName
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__fileServiceUri: 'https://${workflowStorageAccountName}.file.${environment().suffixes.storage}'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__credentialType: 'managedIdentity'
    WEBSITE_CONTENTAZUREFILECONNECTIONSTRING__managedIdentityResourceId: userAssignedIdentityId
    // Application Insights
    APPLICATIONINSIGHTS_CONNECTION_STRING: appInsightsConnectionString
    ApplicationInsightsAgent_EXTENSION_VERSION: '~3'
    // Extension bundle for Logic Apps actions
    AzureFunctionsJobHost__extensionBundle__id: extensionBundleId
    AzureFunctionsJobHost__extensionBundle__version: extensionBundleVersion
    // Workflow runtime configuration
    WORKFLOWS_SUBSCRIPTION_ID: subscription().subscriptionId
    WORKFLOWS_RESOURCE_GROUP_NAME: resourceGroup().name
    WORKFLOWS_LOCATION_NAME: location
    WORKFLOWS_TENANT_ID: subscription().tenantId
    WORKFLOWS_MANAGEMENT_BASE_URI: environment().resourceManager
  }
}

@description('Diagnostic settings for Logic App workflow engine')
resource wfDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workflowEngine.name}-diag'
  scope: workflowEngine
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: metricsSettings
  }
}
