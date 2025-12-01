param name string
param location string = resourceGroup().location
param servicePrincipalId string
param tags object

resource serviceBus 'Microsoft.ServiceBus/namespaces@2025-05-01-preview' = {
  name: '${name}-sb-${uniqueString(resourceGroup().id, name)}'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: 16
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

resource queue 'Microsoft.ServiceBus/namespaces/queues@2025-05-01-preview' = {
  name: 'tax-approval'
  parent: serviceBus
}

resource serviceBusAuthRule 'Microsoft.ServiceBus/namespaces/authorizationRules@2025-05-01-preview' existing = {
  name: 'RootManageSharedAccessKey'
  parent: serviceBus
}

@secure()
output AZURE_SERVICEBUS_CONNECTIONSTRING string = serviceBusAuthRule.listKeys().primaryConnectionString

var RBACRoles = [
  '090c5cfd-751d-490a-894a-3ce6f1109419' // Azure Service Bus Data Owner - Full control over Service Bus resources
]

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in RBACRoles: {
    name: guid(serviceBus.id, servicePrincipalId, roleId)
    scope: serviceBus
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: servicePrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]
