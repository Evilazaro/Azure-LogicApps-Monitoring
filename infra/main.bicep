// ============================================================================
// MAIN DEPLOYMENT ORCHESTRATOR
// ============================================================================
// Deploys a complete Azure Logic Apps monitoring solution including:
// - Resource group with standardized naming
// - Shared resources (monitoring, storage, messaging, managed identity)
// - Logic App workload with App Service Plan
// - Monitoring dashboards and diagnostic settings
//
// This is a subscription-level deployment that creates all necessary resources
// for a production-ready Logic Apps Standard deployment with comprehensive
// observability using Azure Monitor, Application Insights, and Log Analytics.
// ============================================================================

targetScope = 'subscription'

metadata name = 'Azure Logic Apps Monitoring Solution'
metadata description = 'Complete monitoring infrastructure for Logic Apps Standard with Application Insights, Log Analytics, and Service Bus'
metadata version = '1.0.0'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for the solution (e.g., tax-docs, invoice-processor). Used as prefix for all resource names to ensure consistency and traceability.')
@minLength(3)
@maxLength(20)
param solutionName string = 'tax-docs'

@description('Azure region where all resources will be deployed (e.g., eastus2, westeurope). Must support Logic Apps Standard, Application Insights, and Service Bus.')
@minLength(3)
param location string

@description('Environment name to differentiate deployments and apply environment-specific configurations.')
@allowed([
  'dev'
  'uat'
  'prod'
])
param envName string

@description('Deployment timestamp for tracking purposes. Auto-generated at deployment time.')
param deploymentDate string = utcNow('yyyy-MM-dd')

// ============================================================================
// VARIABLES
// ============================================================================

@description('Standardized resource tags applied to all resources for cost tracking, organization, and governance policies.')
var tags = {
  Solution: solutionName
  Environment: envName
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  ApplicationName: 'Tax-Docs-Processing'
  BusinessUnit: 'Tax'
  DeploymentDate: deploymentDate
  Repository: 'Azure-LogicApps-Monitoring'
}

@description('Resource group name following Azure naming convention: organization-solution-environment-region-rg')
var rgName = 'contoso-${solutionName}-${envName}-${location}-rg'

// ============================================================================
// RESOURCE GROUP
// ============================================================================

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

// ============================================================================
// SHARED RESOURCES MODULE
// ============================================================================
// Deploys monitoring infrastructure (Log Analytics, Application Insights),
// storage account for Logic Apps runtime, Service Bus namespace for messaging,
// and user-assigned managed identity for secure authentication
// ============================================================================

module shared '../src/shared/main.bicep' = {
  name: 'SharedResourcesDeployment'
  scope: rg
  params: {
    name: solutionName
    envName: envName
    location: location
    tags: tags
  }
}

// ============================================================================
// LOGIC APP WORKLOAD MODULE
// ============================================================================
// Deploys App Service Plan (Workflow Standard SKU), Logic App with system-assigned
// managed identity, and Azure Portal dashboards for monitoring App Service Plan
// and workflow execution metrics
// ============================================================================

module workload '../src/workload/main.bicep' = {
  name: 'WorkloadDeployment'
  scope: resourceGroup(rgName)
  params: {
    name: solutionName
    location: location
    envName: envName
    workspaceId: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: shared.outputs.LOGS_STORAGE_ACCOUNT_ID
    storageAccountName: shared.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
    appInsightsName: shared.outputs.AZURE_APPLICATION_INSIGHTS_NAME
    serviceBusName: shared.outputs.AZURE_SERVICEBUS_NAMESPACE_NAME
    tags: tags
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

// Resource Group
@description('Name of the deployed resource group')
output RESOURCE_GROUP_NAME string = rgName

@description('Resource ID of the deployed resource group')
output RESOURCE_GROUP_ID string = rg.id

// Storage
@description('Name of the deployed storage account')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = shared.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME

@description('Resource ID of the deployed storage account')
output WORKFLOW_STORAGE_ACCOUNT_ID string = shared.outputs.WORKFLOW_STORAGE_ACCOUNT_ID

// Monitoring
@description('Resource ID of the Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Name of the Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = shared.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Resource ID of the Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_ID string = shared.outputs.AZURE_APPLICATION_INSIGHTS_ID

@description('Connection string for Application Insights')
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = shared.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights')
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = shared.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

// Service Bus
@description('Name of the Service Bus namespace')
output AZURE_SERVICEBUS_NAMESPACE_NAME string = shared.outputs.AZURE_SERVICEBUS_NAMESPACE_NAME

@description('Resource ID of the Service Bus namespace')
output AZURE_SERVICEBUS_NAMESPACE_ID string = shared.outputs.AZURE_SERVICEBUS_NAMESPACE_ID

@description('Service Bus namespace endpoint')
output AZURE_SERVICEBUS_ENDPOINT string = shared.outputs.AZURE_SERVICEBUS_ENDPOINT

@description('Name of the Service Bus queue')
output AZURE_SERVICEBUS_QUEUE_NAME string = shared.outputs.AZURE_SERVICEBUS_QUEUE_NAME

// Logic App Workload
@description('Resource ID of the deployed Logic App')
output LOGIC_APP_ID string = workload.outputs.LOGIC_APP_ID

@description('Name of the deployed Logic App')
output LOGIC_APP_NAME string = workload.outputs.LOGIC_APP_NAME

@description('Resource ID of the Logic App Service Plan')
output LOGIC_APP_SERVICE_PLAN_ID string = workload.outputs.LOGIC_APP_SERVICE_PLAN_ID

// API Function App
@description('Resource ID of the API Function App')
output API_FUNCTION_APP_ID string = workload.outputs.API_FUNCTION_APP_ID

@description('Name of the API Function App')
output API_FUNCTION_APP_NAME string = workload.outputs.API_FUNCTION_APP_NAME
