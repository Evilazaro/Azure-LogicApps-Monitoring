param name string
param location string
param tags object

resource vnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'api-subnet'
        properties: {
          addressPrefix: '10.0.1.0/24'
          delegations: [
            {
              name: 'Microsoft.App.environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'webapp-subnet'
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
      {
        name: 'logicapp-subnet'
        properties: {
          addressPrefix: '10.0.3.0/24'
          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

output apiSubnetId string = vnet.properties.subnets[0].id
output webapiSubnetId string = vnet.properties.subnets[1].id
output logicappSubnetId string = vnet.properties.subnets[2].id
