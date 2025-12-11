@description('Base name for the container services.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for container services deployment.')
@minLength(3)
@maxLength(50)
param location string

@description('Resource ID of the User Assigned Identity to be used by Service Bus.')
@minLength(50)
param userAssignedIdentityId string

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
param envName string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics.')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Logs settings for the Log Analytics workspace.')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace.')
param metricsSettings object[]

@description('Resource tags applied to container services.')
param tags object

// ========== Resources ==========

resource imgRegistry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: toLower('${name}acr${uniqueString(subscription().id, resourceGroup().id, location, envName)}')
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  tags: tags
  sku: {
    name: 'Premium'
  }
}

resource imgRegistryDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${imgRegistry.name}-diag'
  scope: imgRegistry
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: logsSettings
    metrics: metricsSettings
  }
}

param containerAppEnvironmentName string = toLower('${name}-cae-${uniqueString(subscription().id, resourceGroup().id, location, envName)}')

resource containerAppEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: containerAppEnvironmentName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned, UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspaceId
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
