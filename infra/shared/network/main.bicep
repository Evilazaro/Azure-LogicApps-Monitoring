/*
  Network Infrastructure Bicep Module
  ====================================

  Description:
    This Bicep module provisions a comprehensive virtual network infrastructure designed to support
    Azure Container Apps, Logic Apps Standard, and data services with private endpoint connectivity.

  Architecture:
    - Virtual Network: 10.0.0.0/16 address space providing isolated network environment
    - API Subnet (10.0.1.0/24): Delegated to Microsoft.App/environments for Container Apps hosting
    - Data Subnet (10.0.2.0/24): Configured for private endpoints with network policies disabled
    - Workflows Subnet (10.0.3.0/24): Delegated to Microsoft.Web/serverFarms for Logic Apps Standard

  Features:
    - Unique resource naming using subscription, resource group, and environment context
    - Subnet delegation for managed service integration
    - Private endpoint support for secure PaaS connectivity
    - Environment-based deployment (dev, test, staging, prod)

  Dependencies:
    - ../../types.bicep: Provides tagsType definition for resource tagging

  Outputs:
    - API_SUBNET_ID: Container Apps Environment subnet reference
    - WEB_APP_SUBNET_ID: Web App VNet integration subnet reference
    - DATA_SUBNET_ID: Private endpoint subnet reference
    - LOGICAPP_SUBNET_ID: Logic Apps Standard subnet reference
    - VNET_ID: Virtual network resource identifier

  Usage Example:
    module network 'shared/network/main.bicep' = {
      name: 'networkDeployment'
      params: {
        name: 'myapp'
        location: 'eastus'
        envName: 'dev'
        tags: { environment: 'dev', project: 'monitoring' }
      }
    }
*/

metadata name = 'Network Infrastructure'
metadata description = 'Deploys virtual network with subnets for Container Apps, Logic Apps, and data services'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for network resources. Used as a prefix for generating unique resource names for the virtual network and subnets.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for network deployment. Determines where the virtual network and all associated subnets will be provisioned.')
@minLength(3)
@maxLength(50)
param location string

@description('Environment name to differentiate deployments. Supports dev, test, staging, and prod environments for lifecycle management.')
@maxLength(10)
@allowed([
  'dev'
  'test'
  'prod'
  'staging'
])
param envName string

@description('Resource tags applied to network resources. Used for cost tracking, resource organization, and governance compliance.')
param tags tagsType

// ========== Variables ==========

@description('Virtual network name with unique suffix. Combines the base name with a unique hash derived from subscription, resource group, name, location, and environment to ensure globally unique naming.')
var vnetName string = '${name}-${uniqueString(subscription().id, resourceGroup().id, resourceGroup().name, name, location, envName)}-vnet'

@description('Subnet name suffix for consistent naming. Appended to subnet purpose prefixes (api, data, workflows) to create unique subnet identifiers.')
var subnetName string = '-${uniqueString(subscription().id, resourceGroup().id, resourceGroup().name, name, location, envName)}-subnet'

// ========== Resources ==========

@description('Virtual network for isolating solution resources. Provides a private address space (10.0.0.0/16) for secure communication between Container Apps, Logic Apps, and data services.')
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

@description('Subnet for Container Apps with delegation to Microsoft.App/environments. Uses address range 10.0.1.0/24 and enables Azure Container Apps Environment to manage network resources within this subnet.')
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

@description('Subnet for data services and private endpoints with network policies disabled. Uses address range 10.0.2.0/24 and disables private endpoint network policies to allow secure private connectivity to Azure PaaS services.')
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

@description('Subnet for Logic Apps Standard with delegation to Microsoft.Web/serverFarms. Uses address range 10.0.3.0/24 and enables VNet integration for Logic Apps workflows to securely access resources within the virtual network.')
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

@description('Resource ID of the API subnet for Container Apps. Use this ID when configuring Container Apps Environment VNet integration.')
output API_SUBNET_ID string = apiSubnet.id

@description('Resource ID of the Web App subnet (same as data subnet for VNet integration). Use this ID when configuring Web App or Function App VNet integration for outbound connectivity.')
output WEB_APP_SUBNET_ID string = dataSubnet.id

@description('Resource ID of the data subnet for private endpoints. Use this ID when creating private endpoints for Azure Storage, Cosmos DB, Service Bus, or other PaaS services.')
output DATA_SUBNET_ID string = dataSubnet.id

@description('Resource ID of the Logic Apps subnet for workflow hosting. Use this ID when configuring Logic Apps Standard VNet integration for secure workflow execution.')
output LOGICAPP_SUBNET_ID string = logicappSubnet.id

@description('Resource ID of the virtual network. Use this ID when configuring peering, DNS settings, or other network-level integrations.')
output VNET_ID string = vnet.id
