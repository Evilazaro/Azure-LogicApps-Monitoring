param name string
param location string = resourceGroup().location
param workspaceId string
param storageAccountName string

resource appServicePlan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: '${name}${uniqueString(resourceGroup().id, name)}-asp'
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
  name: '${appServicePlan.name}-diag'
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

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-06-01' existing = {
  name: storageAccountName
  scope: resourceGroup()
}

var accountKey = storageAccount.listKeys().keys[0].value

resource logicApp 'Microsoft.Web/sites@2023-01-01' = {
  name: '${name}${uniqueString(resourceGroup().id, name)}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    publicNetworkAccess: 'Enabled'
    storageAccountRequired: true
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'AZURE_STORAGEFILE_CONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${accountKey};BlobEndpoint=https://${storageAccount.name}.blob.core.windows.net/;FileEndpoint=https://${storageAccount.name}.file.core.windows.net/;TableEndpoint=https://${storageAccount.name}.table.core.windows.net/;QueueEndpoint=https://${storageAccount.name}.queue.core.windows.net/'
        }
      ]
    }
  }
}

resource logicappDiagSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logicApp.name}-diag'
  scope: logicApp
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}
