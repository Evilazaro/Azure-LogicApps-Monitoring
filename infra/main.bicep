// Main deployment orchestrator for Azure Logic Apps Monitoring solution
// Deploys resource group, shared resources (monitoring infrastructure, storage), and Logic App workload
targetScope = 'subscription'

@description('Base name for the solution. Used as prefix for all resource names to ensure consistency.')
@minLength(3)
@maxLength(20)
param solutionName string = 'tax-docs'

@description('Azure region where all resources will be deployed. Must support Logic Apps and Application Insights.')
param location string

@description('Environment name (e.g., dev, test, prod) to differentiate deployments.')
param envName string

@description('Tags to apply to all resources')
var tags = {
  Solution: solutionName
  Environment: envName
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  ApplicationName: 'Tax-Docs-Processing'
  BusinessUnit: 'Tax'
}

var rgName = 'contoso-${solutionName}-${envName}-${location}-rg'
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: rgName
  location: location
  tags: tags
}

module shared '../src/shared/main.bicep' = {
  name: 'SharedResourcesDeployment'
  scope: rg
  params: {
    name: solutionName
    location: location
    tags: tags
  }
}

module workload '../src/logic-app.bicep' = {
  name: 'WorkloadDeployment'
  scope: resourceGroup(rgName)
  params: {
    name: solutionName
    workspaceId: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountName: shared.outputs.STORAGE_ACCOUNT_NAME
    appInsightsName: shared.outputs.AZURE_APPLICATION_INSIGHTS_NAME
    serviceBusName: shared.outputs.AZURE_SERVICEBUS_NAMESPACE_NAME
    tags: tags
  }
}
