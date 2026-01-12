param name string
param location string
param envName string
param tags object

var vnetName = '${name}-${uniqueString(resourceGroup().id, name, location, envName)}-vnet'
var subnetName = '-${uniqueString(resourceGroup().id, name, location, envName)}-subnet'

resource vnet 'Microsoft.Network/virtualNetworks@2025-01-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
}

resource apiSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnet
  name: 'api${subnetName}'
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

resource dataSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnet
  name: 'data${subnetName}'
  properties: {
    addressPrefix: '10.0.2.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource logicappSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnet
  name: 'logicapp${subnetName}'
  properties: {
    addressPrefix: '10.0.3.0/24'
  }
}

output API_SUBNET_ID string = apiSubnet.id
output WEB_APP_SUBNET_ID string = dataSubnet.id
output DATA_SUBNET_ID string = dataSubnet.id
output logicappSubnetId string = logicappSubnet.id
output VNET_ID string = vnet.id
