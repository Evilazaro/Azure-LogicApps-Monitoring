param name string
param location string = resourceGroup().location

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${name}-mi'
  location: location
}

module data 'data/main.bicep' = {
  name: 'DataDeployment'
  scope: resourceGroup()
  params: {
    name: name
    managedIdentityName: managedIdentity.name
  }
}

module monitoring '../monitoring/main.bicep' = {
  name: 'MonitoringDeployment'
  scope: resourceGroup()
  params: {
    name: name
    location: location
    managedIdentityName: managedIdentity.name
  }
}

output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = monitoring.outputs.AZURE_LOG_ANALYTICS_WORKSPACE_ID
