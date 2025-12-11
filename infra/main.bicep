targetScope = 'subscription'

metadata name = 'Azure Logic Apps Monitoring Solution'
metadata description = 'Complete monitoring infrastructure for Logic Apps Standard with Application Insights, Log Analytics, and Service Bus'
metadata version = '1.0.0'

// ========== Type Definitions ==========

@description('Tags applied to all resources for organization and cost tracking')
type tagsType = {
  @description('Name of the solution')
  Solution: string
  
  @description('Environment identifier')
  Environment: string
  
  @description('Management method')
  ManagedBy: string
  
  @description('Cost center identifier')
  CostCenter: string
  
  @description('Team responsible for the resources')
  Owner: string
  
  @description('Business unit')
  BusinessUnit: string
  
  @description('Deployment timestamp')
  DeploymentDate: string
  
  @description('Source repository')
  Repository: string
}

// ========== Parameters ==========

@description('Base name for the solution. Used as prefix for all resource names.')
@minLength(3)
@maxLength(20)
param solutionName string = 'eshop-orders'

@description('Azure region where all resources will be deployed.')
@minLength(3)
@maxLength(50)
param location string

@description('Environment name to differentiate deployments.')
@maxLength(10)
param envName string

@description('Deployment timestamp for tracking purposes.')
@maxLength(10)
param deploymentDate string = utcNow('yyyy-MM-dd')

// ========== Variables ==========

// ========== Variables ==========

var tags = {
  Solution: solutionName
  Environment: envName
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  BusinessUnit: 'Finance'
  DeploymentDate: deploymentDate
  Repository: 'Azure-LogicApps-Monitoring'
}

var resourceGroupName = 'rg-${solutionName}-${envName}-${substring(location, 0, min(length(location), 8))}'

// ========== Resources ==========

// ========== Resources ==========

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ========== Modules ==========

module monitoring './monitoring/main.bicep' = {
  scope: rg
  params: {
    name: solutionName
    tags: tags
    envName: envName
    location: location
  }
}

module workload './workload/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: solutionName
    location: location
    envName: envName
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountId: monitoring.outputs.LOGS_STORAGE_ACCOUNT_ID
    appInsightsConnectionString: monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING
    appInsightsInstrumentationKey: monitoring.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY
    tags: tags
  }
}

// // ========== Outputs ==========

// // ========== Outputs ==========

// // Resource Group outputs
// @description('Name of the deployed resource group')
// output AZURE_RESOURCE_GROUP string = resourceGroupName

// @description('Resource ID of the deployed resource group')
// output RESOURCE_GROUP_ID string = rg.id

// // Monitoring outputs
// @description('Resource ID of the Log Analytics workspace')
// output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID

// @description('Name of the Log Analytics workspace')
// output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

// @description('Name of the Application Insights instance')
// output AZURE_APPLICATION_INSIGHTS_NAME string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_NAME

// @description('Resource ID of the Application Insights instance')
// output AZURE_APPLICATION_INSIGHTS_ID string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_ID

// @description('Connection string for Application Insights')
// @secure()
// output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

// @description('Instrumentation key for Application Insights')
// @secure()
// output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

// // Workload outputs
// @description('Resource ID of the deployed webApp App')
// output PO_PROC_API_WEB_APP_ID string = workload.outputs.PO_PROC_API_WEB_APP_ID

// @description('Name of the deployed webApp App')
// output PO_PROC_API_WEB_APP_NAME string = workload.outputs.PO_PROC_API_WEB_APP_NAME

// @description('Default hostname of the webApp App')
// output PO_PROC_API_DEFAULT_HOST_NAME string = workload.outputs.PO_PROC_API_DEFAULT_HOST_NAME

// @description('Resource ID of the deployed webApp App')
// output PO_WEB_APP_ID string = workload.outputs.PO_WEB_APP_ID

// @description('Name of the deployed webApp App')
// output PO_WEB_APP_NAME string = workload.outputs.PO_WEB_APP_NAME

// @description('Default hostname of the webApp App')
// output PO_WEB_APP_DEFAULT_HOST_NAME string = workload.outputs.PO_WEB_APP_DEFAULT_HOST_NAME

// @description('Resource ID of the deployed Logic App')
// output WORKFLOW_ENGINE_ID string = workload.outputs.WORKFLOW_ENGINE_ID

// @description('Name of the deployed Logic App')
// output WORKFLOW_ENGINE_NAME string = workload.outputs.WORKFLOW_ENGINE_NAME

// @description('Resource ID of the App Service Plan')
// output WORKFLOW_ENGINE_ASP_ID string = workload.outputs.WORKFLOW_ENGINE_ASP_ID

// @description('Name of the App Service Plan')
// output APP_SERVICE_PLAN_NAME string = workload.outputs.APP_SERVICE_PLAN_NAME

// @description('Tenant ID of the environment')
// output AZURE_TENANT_ID string = tenant().tenantId
