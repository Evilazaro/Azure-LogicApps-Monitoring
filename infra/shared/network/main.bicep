// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Name of the virtual network')
@minLength(1)
@maxLength(64)
param name string

@description('Azure region for virtual network deployment')
@minLength(3)
@maxLength(50)
param location string

@description('Resource tags applied to the virtual network')
param tags tagsType

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
    ]
  }
}

output apiSubnetId string = vnet.properties.subnets[0].id
output webapiSubnetId string = vnet.properties.subnets[1].id
