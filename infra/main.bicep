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
param envName string

@description('Deployment timestamp for tracking purposes.')
@maxLength(10)
param deploymentDate string = utcNow('yyyy-MM-dd')

// ========== Variables ==========

// Standardized tags applied to all resources for governance and cost tracking
@description('Core tags applied to all resources for governance and cost tracking')
var coreTags tagsType = {
  Solution: solutionName
  Environment: envName
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  BusinessUnit: 'IT'
  DeploymentDate: deploymentDate
  Repository: 'Azure-LogicApps-Monitoring'
}

@description('Combined tags including Azure Developer CLI (azd) specific tags')
var tags tagsType = union(coreTags, {
  'azd-env-name': envName
  'azd-service-name': 'app'
})

// Resource group naming convention: rg-{solution}-{env}-{location-abbrev}
// Truncates location to 8 chars to keep names concise
@description('Resource group name following naming convention: rg-{solution}-{env}-{location-abbrev}')
var resourceGroupName string = 'rg-${solutionName}-${envName}-${take(location, 8)}'

// ========== Resources ==========

@description('Resource group containing all monitoring and workload resources')
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ========== Modules ==========

// Shared Infrastructure Module
// Deploys identity, monitoring, and data infrastructure
// Must be deployed first as workload module depends on its outputs
module shared 'shared/main.bicep' = {
  scope: rg
  params: {
    name: solutionName
    location: location
    tags: tags
    envName: envName
  }
}

// ========== Outputs ==========

// Identity Outputs
@description('Client ID of the managed identity for application authentication')
output MANAGED_IDENTITY_CLIENT_ID string = shared.outputs.MANAGED_IDENTITY_CLIENT_ID

@description('Name of the managed identity resource')
output MANAGED_IDENTITY_NAME string = shared.outputs.MANAGED_IDENTITY_NAME

// Monitoring Outputs
@description('Name of the Log Analytics workspace for centralized logging')
output AZURE_LOG_ANALYTICS_WORKSPACE_NAME string = shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_NAME

@description('Name of the deployed Application Insights instance')
output APPLICATION_INSIGHTS_NAME string = shared.outputs.APPLICATION_INSIGHTS_NAME

@description('Connection string for Application Insights telemetry')
output APPLICATIONINSIGHTS_CONNECTION_STRING string = shared.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING

@description('Connection string for Application Insights telemetry')
output TELEMETRY_APPINSIGHTSCONNECTIONSTRING string = shared.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING

// Data Outputs
@description('Fully qualified domain name of the SQL Server')
output ORDERSDATABASE_SQLSERVERFQDN string = shared.outputs.ORDERSDATABASE_SQLSERVERFQDN

@description('Name of the deployed SQL Server instance')
output AZURE_SQL_SERVER_NAME string = shared.outputs.AZURE_SQL_SERVER_NAME

@description('Name of the deployed SQL Database')
output AZURE_SQL_DATABASE_NAME string = shared.outputs.AZURE_SQL_DATABASE_NAME

// Workload Infrastructure Module
// Deploys managed identity, messaging (Service Bus), container services, and Logic Apps
// Depends on monitoring outputs for workspace ID and Application Insights connection string
module workload './workload/main.bicep' = {
  scope: resourceGroup(resourceGroupName)
  params: {
    name: solutionName
    location: location
    envName: envName
    workspaceId: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    workspacePrimaryKey: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY
    workspaceCustomerId: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID
    storageAccountId: shared.outputs.AZURE_STORAGE_ACCOUNT_ID_LOGS
    appInsightsConnectionString: shared.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
    userAssignedIdentityId: shared.outputs.AZURE_MANAGED_IDENTITY_ID
    userAssignedIdentityName: shared.outputs.MANAGED_IDENTITY_NAME
    workflowStorageAccountName: shared.outputs.AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW
    workflowStorageAccountId: shared.outputs.AZURE_STORAGE_ACCOUNT_ID_WORKFLOW
    apiSubnetId: shared.outputs.API_SUBNET_ID
    logicappSubnetId: shared.outputs.LOGICAPP_SUBNET_ID
    tags: tags
  }
}

@description('Azure Resource Group name containing all deployed resources')
output AZURE_RESOURCE_GROUP string = rg.name

// Messaging Outputs
@description('Service Bus endpoint URL for message brokering')
output MESSAGING_SERVICEBUSENDPOINT string = workload.outputs.MESSAGING_SERVICEBUSENDPOINT

@description('Service Bus hostname for connection configuration')
output MESSAGING_SERVICEBUSHOSTNAME string = workload.outputs.MESSAGING_SERVICEBUSHOSTNAME

// Container Registry Outputs
@description('Container Registry login server endpoint')
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = workload.outputs.AZURE_CONTAINER_REGISTRY_ENDPOINT

@description('Managed identity resource ID for Container Registry')
output AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID string = workload.outputs.AZURE_CONTAINER_REGISTRY_MANAGED_IDENTITY_ID

@description('Name of the Azure Container Registry')
output AZURE_CONTAINER_REGISTRY_NAME string = workload.outputs.AZURE_CONTAINER_REGISTRY_NAME

// Container Apps Outputs
@description('Name of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_NAME

@description('Resource ID of the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_ID

@description('Default domain for the Container Apps Environment')
output AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

@description('URL for the Orders API deployed in Container Apps')
output ORDERS_API_URL string = workload.outputs.AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN

// Logic Apps Outputs
@description('Name of the deployed Logic App')
output LOGIC_APP_NAME string = workload.outputs.LOGIC_APP_NAME

@description('Content share name for Logic App')
output CONTENT_SHARE_NAME string = workload.outputs.CONTENT_SHARE_NAME

@description('Runtime URL of the Service Bus API connection')
output SERVICE_BUS_CONNECTION_RUNTIME_URL string = workload.outputs.SERVICE_BUS_CONNECTION_RUNTIME_URL

@description('Runtime URL of the Azure Blob Storage API connection')
output AZURE_BLOB_CONNECTION_RUNTIME_URL string = workload.outputs.AZURE_BLOB_CONNECTION_RUNTIME_URL

@description('Azure Tenant ID for Container Apps authentication')
output AZURE_TENANT_ID string = tenant().tenantId

@description('Storage account name for Logic Apps workflows and data')
output AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW string = workload.outputs.AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW
