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

module monitoring '../src/monitoring/main.bicep' = {
  name: 'MonitoringDeployment'
  scope: rg
  params: {
    name: solutionName
    tags: tags
    envName: envName
    location: location
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
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: monitoring.outputs.LOGS_STORAGE_ACCOUNT_ID
    appInsightsName: monitoring.outputs.AZURE_APPLICATION_INSIGHTS_NAME
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

// Monitoring
@description('Resource ID of the Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

@description('Name of the Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Name of the Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Resource ID of the Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_ID string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_ID

@description('Connection string for Application Insights')
@secure()
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING
@description('Instrumentation key for Application Insights')
@secure()
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

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
