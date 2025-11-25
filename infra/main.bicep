targetScope = 'subscription'
param solutionName string = 'contoso-logic-apps'
param location string


var rgName = '${solutionName}-rg'
resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: rgName
  location: location
}

module monitoring 'modules/monitoring/main.bicep' = {
  name: 'monitoringModuleDeployment'
  scope: rg
  params: {
    name: solutionName
    location: location
  }
}

module workload 'modules/logic-app.bicep' = {
  scope: resourceGroup(rgName)
  params: {
    name: solutionName
    workspaceId: monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
  }
}
