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
param solutionName string = 'orders'

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
    workspacePrimaryKey: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY
    workspaceCustomerId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID
    storageAccountId: monitoring.outputs.LOGS_STORAGE_ACCOUNT_ID
    appInsightsConnectionString: monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING
    tags: tags
  }
}


@description('Client ID of the deployed managed identity')
output MANAGED_IDENTITY_CLIENT_ID string = workload.outputs.MANAGED_IDENTITY_CLIENT_ID

output AZURE_CONTAINER_REGISTRY_ENDPOINT string = workload.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT

output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = workload.outputs.AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID

output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID

output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

// ========== Outputs ==========

// Resource Group outputs
@description('Name of the deployed resource group')
output AZURE_RESOURCE_GROUP string = resourceGroupName

