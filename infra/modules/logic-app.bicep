param name string
param location string = resourceGroup().location
param workspaceId string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${name}-mi'
  location: location
}

var storageRBACRoles = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
  '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher
]

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: 'logicappsstorage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
  }
}

resource storageAccountRoleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in storageRBACRoles: {
    name: guid(storageAccount.id, managedIdentity.id, roleId)
    scope: storageAccount
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: managedIdentity.properties.principalId
      principalType: 'ServicePrincipal'
    }
  }
]

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: '${name}-asp'
  location: location
  sku: {
    name: 'WS1'
    tier: 'WorkflowStandard'
    size: 'WS1'
    family: 'WS'
    capacity: 1
  }
  kind: 'elastic'
  properties: {
    perSiteScaling: false
    elasticScaleEnabled: true
    maximumElasticWorkerCount: 20
    isSpot: false
    reserved: false
    isXenon: false
    hyperV: false
    targetWorkerCount: 0
    targetWorkerSizeId: 0
    zoneRedundant: false
    asyncScalingEnabled: false
  }
}

resource diagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diag'
  scope: appServicePlan
  properties: {
    workspaceId: workspaceId
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}
