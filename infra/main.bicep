targetScope = 'subscription'
param solutionName string = 'tax-docs'
param location string

@description('Tags to apply to all resources')
var tags = {
  Solution: solutionName
  Environment: 'Production'
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  ApplicationName: 'Tax-Docs-Processing'
  BusinessUnit: 'Finance'
}

var rgName = 'contoso-${solutionName}-rg'
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: rgName
  location: location
  tags: tags
}

module shared 'modules/shared/main.bicep' = {
  scope: rg
  params: {
    name: solutionName
    tags: tags
  }
}

module workload 'modules/logic-app.bicep' = {
  name: 'WorkloadDeployment'
  scope: resourceGroup(rgName)
  params: {
    name: solutionName
    workspaceId: shared.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
    storageAccountName: shared.outputs.STORAGE_ACCOUNT_NAME
    appInsightsInstrumentationKey: shared.outputs.AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY
    appInsightsConnectionString: shared.outputs.AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING
    tags: tags
  }
}
