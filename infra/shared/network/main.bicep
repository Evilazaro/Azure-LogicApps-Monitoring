/*
  Network Infrastructure Module
  =============================
  Deploys virtual network infrastructure for the solution.
  
  Components:
  - Virtual Network with /16 address space (10.0.0.0/16)
  - API Subnet for Container Apps (/24 - 10.0.1.0/24)
  - Data Subnet for Private Endpoints (/24 - 10.0.2.0/24)
  - Workflows Subnet for Logic Apps Standard (/24 - 10.0.3.0/24)
  
  Subnet Delegations:
  - API Subnet: Microsoft.App/environments (Container Apps)
  - Workflows Subnet: Microsoft.Web/serverFarms (Logic Apps)
  
  Note: Subnets are created sequentially using dependsOn to avoid
  Azure ARM concurrent modification conflicts on VNet resources.
*/

metadata name = 'Network Infrastructure'
metadata description = 'Deploys virtual network with subnets for Container Apps, Logic Apps, and data services'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for network resources')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for network deployment')
@minLength(3)
@maxLength(50)
param location string

@description('Environment name to differentiate deployments.')
@maxLength(10)
@allowed([
  'dev'
  'test'
  'prod'
  'staging'
])
param envName string

@description('Resource tags applied to network resources')
param tags tagsType

// ========== Variables ==========

@description('Virtual network name with unique suffix')
var vnetName string = '${name}-${uniqueString(subscription().id, resourceGroup().id, resourceGroup().name, name, location, envName)}-vnet'

@description('Subnet name suffix for consistent naming')
var subnetName string = '-${uniqueString(subscription().id, resourceGroup().id, resourceGroup().name, name, location, envName)}-subnet'

// ========== Resources ==========

@description('Virtual network for isolating solution resources')
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

@description('Subnet for Container Apps with delegation to Microsoft.App/environments')
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

@description('Subnet for data services and private endpoints with network policies disabled')
resource dataSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnet
  name: 'data${subnetName}'
  properties: {
    addressPrefix: '10.0.2.0/24'
    // Disable network policies to allow private endpoint creation
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
  dependsOn: [
    apiSubnet
  ]
}

@description('Subnet for Logic Apps Standard with delegation to Microsoft.Web/serverFarms')
resource logicappSubnet 'Microsoft.Network/virtualNetworks/subnets@2025-01-01' = {
  parent: vnet
  name: 'workflows${subnetName}'
  properties: {
    addressPrefix: '10.0.3.0/24'
    delegations: [
      {
        name: 'Microsoft.Web/serverFarms'
        properties: {
          serviceName: 'Microsoft.Web/serverFarms'
        }
      }
    ]
  }
  dependsOn: [
    dataSubnet
  ]
}

// ========== Outputs ==========

@description('Resource ID of the API subnet for Container Apps')
output API_SUBNET_ID string = apiSubnet.id

@description('Resource ID of the Web App subnet (same as data subnet for VNet integration)')
output WEB_APP_SUBNET_ID string = dataSubnet.id

@description('Resource ID of the data subnet for private endpoints')
output DATA_SUBNET_ID string = dataSubnet.id

@description('Resource ID of the Logic Apps subnet for workflow hosting')
output logicappSubnetId string = logicappSubnet.id

@description('Resource ID of the virtual network')
output VNET_ID string = vnet.id
