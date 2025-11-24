targetScope = 'subscription'
param location string

resource rg 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: 'ey-logic-apps'
  location: location
}

module logicAppModule 'modules/logic-app.bicep' = {
  name: 'deployLogicApp'
  scope: rg
}
