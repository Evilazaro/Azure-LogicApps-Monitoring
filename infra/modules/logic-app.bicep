param name string
param appServicePlanName string
param location string

resource appServicePlan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: appServicePlanName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'linux'
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
  properties: {
    reserved: true
  }
}

resource logicApp 'Microsoft.App/logicApps@2025-10-02-preview' = {
  name: name
  scope: appServicePlan
  properties: {
  
  }
}
