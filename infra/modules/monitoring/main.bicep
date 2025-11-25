param name string
param location string = resourceGroup().location
param managedIdentityName string
param tags object

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-07-01' = {
  name: '${name}-${uniqueString(resourceGroup().id, name)}-law'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      immediatePurgeDataOn30Days: true
    }
  }
}

output AZURE_LOG_ANALYTICS_WORKSPACE_ID string = logAnalyticsWorkspace.id

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-${uniqueString(resourceGroup().id, name)}-appinsights'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

output AZURE_APPLICATION_INSIGHTS_NAME string = appInsights.name
output AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY string = appInsights.properties.InstrumentationKey
output AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING string = appInsights.properties.ConnectionString

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' existing = {
  name: managedIdentityName
  scope: resourceGroup()
}

var appInsightsRoles = [
  '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher
]

resource appInsightsRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in appInsightsRoles: {
    name: guid(appInsights.id, managedIdentity.id, roleId)
    scope: appInsights
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: managedIdentity.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appInsights.name}-diagsetting'
  scope: appInsights
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
