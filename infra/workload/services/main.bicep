param name string
param location string
param envnName string
param tags object

resource appImages 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: toLower('${name}acr${uniqueString(subscription().id, resourceGroup().id, location,envnName)}')
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  sku: {
    name: 'Premium'
  }
}

param containerAppEnvironmentName string = toLower('${name}-cae-${uniqueString(subscription().id, resourceGroup().id, location, envnName)}')

resource containerAppEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: containerAppEnvironmentName
  location: 'East US 2'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: '6a0ff81b-c2b4-4e81-81b0-9f2e82d79d61'
        dynamicJsonColumns: false
      }
    }
    zoneRedundant: false
    kedaConfiguration: {}
    daprConfiguration: {}
    customDomainConfiguration: {}
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
        enableFips: false
      }
    ]
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
    publicNetworkAccess: 'Enabled'
  }
}
