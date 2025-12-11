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

@description('Log Analytics Workspace Customer ID.')
param workspaceCustomerId string

@description('Storage Account ID for diagnostic logs and metrics.')
@minLength(50)
param storageAccountId string

@description('Logs settings for the Log Analytics workspace.')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace.')
param metricsSettings object[]

@description('Connection string for Application Insights instance.')
param appInsightsConnectionString string

@description('Application Insights Instrumentation Key.')
param appInsightsInstrumentationKey string

@description('Resource tags applied to container services.')
param tags object

// ========== Resources ==========

resource registry 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
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

resource registryDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${registry.name}-diag'
  scope: registry
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: logsSettings
    metrics: metricsSettings
  }
}

var appEnvName = toLower('${name}-cae-${uniqueString(subscription().id, resourceGroup().id, location, envName)}')

resource appEnv 'Microsoft.App/managedEnvironments@2025-02-02-preview' = {
  name: appEnvName
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
        customerId: workspaceCustomerId
        dynamicJsonColumns: true
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

var ordersAPIName = 'orders-api'

resource ordersApi 'Microsoft.App/containerapps@2025-02-02-preview' = {
  name: ordersAPIName
  location: location
  kind: 'containerapps'
  identity: {
    type: 'SystemAssigned,UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  tags: union(tags, { 'azd-service-name': 'eShop.Orders.API' })
  properties: {
    managedEnvironmentId: appEnv.id
    environmentId: appEnv.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        exposedPort: 80
        transport: 'Auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      registries: [
        {
          server: registry.properties.loginServer
          identity: userAssignedIdentityId
        }
      ]
      identitySettings: []
      runtime: {
        dotnet: {
          autoConfigureDataProtection: false
        }
      }
      maxInactiveRevisions: 100
    }
    template: {
      containers: [
        {
          image: '${registry.properties.loginServer}/${ordersAPIName}:latest'
          imageType: 'ContainerImage'
          name: ordersAPIName
          resources: {
            cpu: 4
            memory: '8Gi'
          }
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: appInsightsInstrumentationKey
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsightsConnectionString
            }
          ]
        }
      ]
      scale: {
        minReplicas: 3
        maxReplicas: 100
        cooldownPeriod: 300
        pollingInterval: 30
      }
    }
  }
}
