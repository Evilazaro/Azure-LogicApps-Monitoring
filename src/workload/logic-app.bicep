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

@description('Name of the existing storage account required by Logic Apps Standard.')
@minLength(3)
@maxLength(24)
param workflowStorageAccountName string

@description('Name of the Application Insights instance.')
param appInsightsName string

@description('Resource tags applied to all resources.')
param tags object

resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-asp'
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 1
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

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-mi'
  location: location
  tags: tags
}

resource workflowSA 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: workflowStorageAccountName
  scope: resourceGroup()
}

// ============================================================================
// VARIABLES - RBAC ROLE DEFINITIONS
// ============================================================================

// Storage Account RBAC roles for Logic Apps managed identity
// These roles enable the Logic App to access storage account resources using managed identity
// Reference: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles
var storageRoles = {
  // Storage Account Contributor (17d1049b-9a84-46fb-8f53-869881c3d3ab)
  // Grants full management control over storage account
  // Learn more: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-account-contributor
  contributor: '17d1049b-9a84-46fb-8f53-869881c3d3ab'
  
  // Storage Blob Data Owner (b7e6dc6d-f1e8-4753-8033-0f276bb0955b)
  // Provides full control over blob containers and data, including ACL management
  // Learn more: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-owner
  blobDataOwner: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  
  // Storage Queue Data Contributor (974c5e8b-45b9-4653-ba55-5f855dd0fb88)
  // Allows reading, writing, and deleting Azure Storage queues and queue messages
  // Learn more: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-queue-data-contributor
  queueDataContributor: '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  
  // Storage Table Data Contributor (0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3)
  // Allows reading, writing, and deleting Azure Storage tables and entities
  // Learn more: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-table-data-contributor
  tableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  
  // Storage File Data Privileged Contributor (69566ab7-960f-475b-8e7c-b3118f30c6bd)
  // Allows read, write, delete, and modify ACLs on files/directories (required for Logic Apps file share)
  // Learn more: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor
  fileDataContributor: '69566ab7-960f-475b-8e7c-b3118f30c6bd'
}

var storageRBAC = [
  storageRoles.contributor
  storageRoles.blobDataOwner
  storageRoles.queueDataContributor
  storageRoles.tableDataContributor
  storageRoles.fileDataContributor
]

resource storageRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in storageRBAC: {
    name: guid(logicApp.id, logicApp.name, roleId)
    scope: workflowSA
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: mi.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
  scope: resourceGroup()
}

// Application Insights RBAC role for Logic Apps managed identity
// Reference: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles
var appInsightsRoles = {
  // Monitoring Metrics Publisher (3913510d-42f4-4e42-8a64-420c390055eb)
  // Enables publishing metrics to Azure Monitor (required for custom metrics from Logic Apps)
  // Learn more: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#monitoring-metrics-publisher
  metricsPublisher: '3913510d-42f4-4e42-8a64-420c390055eb'
}

var appInsightsRBAC = [
  appInsightsRoles.metricsPublisher
]

resource appInsightsRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in appInsightsRBAC: {
    name: guid(appInsights.id, appInsights.name, roleId)
    scope: appInsights
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: mi.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

// ============================================================================
// VARIABLES - APP SETTINGS
// ============================================================================

// Service Bus connection configuration

// Core runtime settings
var functionsExtensionVersion = '~4'
var functionsWorkerRuntime = 'dotnet'

// Extension bundle for Logic Apps Standard
var extensionBundleId = 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
var extensionBundleVersion = '[1.*, 2.0.0)'

// Application Insights telemetry
var appInsightsInstrumentationKey = appInsights.properties.InstrumentationKey
var appInsightsConnectionString = appInsights.properties.ConnectionString

// Workflow configuration settings
var workflowsSubscriptionId = subscription().subscriptionId
var workflowsResourceGroupName = resourceGroup().name
var workflowsLocationName = location
var workflowsTenantId = subscription().tenantId

// ============================================================================
// LOGIC APP RESOURCE
// ============================================================================

resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name, envName, location)}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    publicNetworkAccess: 'Enabled'
    storageAccountRequired: true
    siteConfig: {
      appSettings: [
        // Core Azure Functions runtime settings
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: functionsExtensionVersion
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: functionsWorkerRuntime
        }
        // Storage account settings (workflow state, run history, artifacts)
        // Using managed identity for secure authentication
        {
          name: 'AzureWebJobsStorage__accountName'
          value: workflowStorageAccountName
        }
        {
          name: 'AzureWebJobsStorage__blobServiceUri'
          value: 'https://${workflowStorageAccountName}.blob.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__queueServiceUri'
          value: 'https://${workflowStorageAccountName}.queue.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__tableServiceUri'
          value: 'https://${workflowStorageAccountName}.table.${environment().suffixes.storage}'
        }
        {
          name: 'AzureWebJobsStorage__credential'
          value: 'managedidentity'
        }
        {
          name: 'AzureWebJobsStorage__managedIdentityResourceId'
          value: resourceId('Microsoft.ManagedIdentity/userAssignedIdentities', mi.name)
        }
        // Application Insights telemetry and monitoring
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        // Logic Apps Standard extension bundle
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: extensionBundleId
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: extensionBundleVersion
        }
        // Workflow management settings
        {
          name: 'WORKFLOWS_SUBSCRIPTION_ID'
          value: workflowsSubscriptionId
        }
        {
          name: 'WORKFLOWS_RESOURCE_GROUP_NAME'
          value: workflowsResourceGroupName
        }
        {
          name: 'WORKFLOWS_LOCATION_NAME'
          value: workflowsLocationName
        }
        {
          name: 'WORKFLOWS_TENANT_ID'
          value: workflowsTenantId
        }
        {
          name: 'WORKFLOWS_MANAGEMENT_BASE_URI'
          value: environment().resourceManager
        }
      ]
      use32BitWorkerProcess: false
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      netFrameworkVersion: 'v6.0'
    }
  }
}

resource DiagnosticSettingsLogicApp 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logicApp.name}-diag'
  scope: logicApp
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'WorkflowRuntime'
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

@description('Resource ID of the deployed Logic App')
output LOGIC_APP_ID string = logicApp.id

@description('Name of the deployed Logic App')
output LOGIC_APP_NAME string = logicApp.name

@description('Resource ID of the App Service Plan')
output APP_SERVICE_PLAN_ID string = appServicePlan.id

@description('Name of the App Service Plan')
output APP_SERVICE_PLAN_NAME string = appServicePlan.name
