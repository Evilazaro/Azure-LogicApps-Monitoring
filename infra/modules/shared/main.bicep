param name string
param location string = resourceGroup().location

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${name}-mi'
  location: location
}

module data 'data/main.bicep' = {
  name: 'DataDeployment'
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
