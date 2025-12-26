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
var coreTags tagsType = {
  Solution: solutionName
  Environment: envName
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  BusinessUnit: 'IT'
  DeploymentDate: deploymentDate
  Repository: 'Azure-LogicApps-Monitoring'
}

var tags tagsType = union(coreTags, {
  'azd-env-name': envName
  'azd-service-name': 'app'
})

// Resource group naming convention: rg-{solution}-{env}-{location-abbrev}
// Truncates location to 8 chars to keep names concise
var resourceGroupName string = 'rg-${solutionName}-${envName}-${substring(location, 0, min(length(location), 8))}'

// ========== Resources ==========

@description('Resource group containing all monitoring and workload resources')
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

// ========== Modules ==========

module shared 'shared/main.bicep' = {
  scope: rg
  params: {
    name: solutionName
    location: location
    tags: tags
    envName: envName
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
    workspaceId: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    workspacePrimaryKey: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_PRIMARY_KEY
    workspaceCustomerId: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_CUSTOMER_ID
    storageAccountId: shared.outputs.AZURE_STOARGE_ACCOUNT_ID_LOGS
    appInsightsConnectionString: shared.outputs.APPLICATIONINSIGHTS_CONNECTION_STRING
    userAssignedIdentityId: shared.outputs.AZURE_MANAGED_IDENTITY_ID
    workflowStorageAccountName: shared.outputs.AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW
    tags: tags
  }
}

