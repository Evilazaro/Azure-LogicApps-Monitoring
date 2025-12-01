// Application Insights module for APM (Application Performance Monitoring)
// Provides telemetry collection, distributed tracing, and performance analytics
// Integrated with Log Analytics workspace for unified query experience

@description('Base name for Application Insights. Will be suffixed with unique string and "-appinsights".')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for Application Insights deployment.')
param location string = resourceGroup().location

@description('Principal ID of the managed identity that needs Monitoring Metrics Publisher access.')
param servicePrincipalId string

@description('Resource ID of the Log Analytics workspace for Application Insights integration.')
param logAnalyticsWorkspaceId string

@description('Tags to apply to Application Insights and related diagnostic settings.')
param tags object

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${name}-${uniqueString(resourceGroup().id, name)}-appinsights'
  location: location
  kind: 'web'
  tags: tags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

@description('Name of the deployed Application Insights instance')
output AZURE_APPLICATION_INSIGHTS_NAME string = appInsights.name

// RBAC Role: Monitoring Metrics Publisher
// Allows the managed identity to publish custom metrics to Application Insights
// Reference: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#monitoring-metrics-publisher
var appInsightsRoles = [
  '3913510d-42f4-4e42-8a64-420c390055eb'
]

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in appInsightsRoles: {
    name: guid(appInsights.id, servicePrincipalId, roleId)
    scope: appInsights
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: servicePrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${appInsights.name}-diagsetting'
  scope: appInsights
  properties: {
    workspaceId: logAnalyticsWorkspaceId
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
