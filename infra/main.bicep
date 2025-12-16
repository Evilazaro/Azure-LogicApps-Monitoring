/*
  Azure Logic Apps Monitoring Solution
  ====================================
  Main deployment orchestrator for the complete monitoring infrastructure.
  
  Purpose:
  - Deploys monitoring infrastructure (Log Analytics, Application Insights)
  - Deploys workload infrastructure (Identity, Messaging, Container Services, Logic Apps)
  - Orchestrates resource group creation at subscription scope
  
  Dependencies:
  - ./monitoring/main.bicep: Monitoring infrastructure module
  - ./workload/main.bicep: Workload infrastructure module
  - ./types.bicep: Shared type definitions
*/

targetScope = 'subscription'

metadata name = 'Azure Logic Apps Monitoring Solution'
metadata description = 'Complete monitoring infrastructure for Logic Apps Standard with Application Insights, Log Analytics, and Service Bus'
metadata version = '1.0.0'

// ========== Type Definitions ==========

import { tagsType } from './types.bicep'

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
@allowed([
  'local'
  'dev'
  'staging'
  'prod'
])
param envName string

@description('Deployment timestamp for tracking purposes.')
@maxLength(10)
param deploymentDate string = utcNow('yyyy-MM-dd')

// ========== Variables ==========

// Standardized tags applied to all resources for governance and cost tracking
var tags tagsType = {
  Solution: solutionName
  Environment: envName
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  BusinessUnit: 'Finance'
  DeploymentDate: deploymentDate
  Repository: 'Azure-LogicApps-Monitoring'
}

// Resource group naming convention: rg-{solution}-{env}-{location-abbrev}
// Truncates location to 8 chars to keep names concise
var resourceGroupName = 'rg-${solutionName}-${envName}-${substring(location, 0, min(length(location), 8))}'

// ========== Resources ==========

@description('Resource group containing all monitoring and workload resources')
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ========== Modules ==========

// Monitoring Infrastructure Module
// Deploys Log Analytics workspace, Application Insights, and health monitoring
module monitoring './monitoring/main.bicep' = {
  scope: rg
  params: {
    name: solutionName
    tags: tags
    envName: envName
    location: location
  }
}

// Workload Infrastructure Module
// Deploys managed identity, messaging (Service Bus), container services, and Logic Apps
// Depends on monitoring outputs for workspace ID and Application Insights connection string
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

// ========== Outputs ==========

// Resource Group & Tenant Outputs
@description('Name of the deployed resource group')
output AZURE_RESOURCE_GROUP string = resourceGroupName

@description('Azure Tenant ID where resources are deployed')
output AZURE_TENANT_ID string = tenant().tenantId

// Application Insights Outputs (Microsoft.Insights/components)
@description('Name of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_NAME

@description('Connection string for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

@description('Instrumentation key for Application Insights telemetry')
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY

@description('Connection string for Application Insights telemetry (alias)')
output TELEMETRY_APPINSIGHTSCONNECTIONSTRING string = monitoring.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING

// Log Analytics Workspace Outputs (Microsoft.OperationalInsights/workspaces)
@description('Name of the deployed Log Analytics workspace')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

// Managed Identity Outputs (Microsoft.ManagedIdentity/userAssignedIdentities)
@description('Client ID of the deployed managed identity')
output MANAGED_IDENTITY_CLIENT_ID string = workload.outputs.MANAGED_IDENTITY_CLIENT_ID

@description('Name of the deployed managed identity')
output MANAGED_IDENTITY_NAME string = workload.outputs.MANAGED_IDENTITY_NAME

@description('Client ID of the deployed managed identity (alias)')
output AZURE_CLIENT_ID string = workload.outputs.AZURE_CLIENT_ID

// Service Bus Outputs (Microsoft.ServiceBus/namespaces)
@description('Azure Service Bus namespace name')
output AZURE_SERVICE_BUS_NAMESPACE string = workload.outputs.AZURE_SERVICE_BUS_NAMESPACE

@description('Azure Service Bus endpoint')
output MESSAGING_SERVICEBUSENDPOINT string = workload.outputs.MESSAGING_SERVICEBUSENDPOINT

// Container Registry Outputs (Microsoft.ContainerRegistry/registries)
@description('Login server endpoint for the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = workload.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT

@description('Name of the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_NAME string = workload.outputs.AZURE_CONTAINER_REGISTRY_NAME

@description('Resource ID of the managed identity used by Container Registry')
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = workload.outputs.AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID

// Container Apps Environment Outputs (Microsoft.App/managedEnvironments)
@description('Name of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME

@description('Resource ID of the Container Apps managed environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID

@description('Default domain for the Container Apps environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

@description('Orders API Endpoint URL')
output ORDERS_API_ENDPOINT string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

// Storage Account Outputs (Microsoft.Storage/storageAccounts)
@description('Name of the workflow storage account')
output WORKFLOW_STORAGE_ACCOUNT_NAME string = workload.outputs.WORKFLOW_STORAGE_ACCOUNT_NAME
