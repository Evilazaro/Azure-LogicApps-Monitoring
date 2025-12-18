/*
  Managed Identity Module
  =======================
  Deploys user-assigned managed identity with comprehensive role assignments.
  
  Purpose:
  - Single managed identity for all workload resources
  - Principle of least privilege with specific role assignments
  - Role assignments for both managed identity and deployment user
  
  Assigned Roles:
  - Storage: Account Contributor, Blob Data Contributor
  - Monitoring: Metrics Publisher, Contributor, Application Insights
  - Service Bus: Data Owner, Receiver, Sender
  - Container Registry: ACR Pull, ACR Push
*/

metadata name = 'Managed Identity'
metadata description = 'Deploys user-assigned managed identity with role assignments for workload resources'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for the managed identity.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for managed identity deployment.')
@minLength(3)
@maxLength(50)
param location string

@description('Environment name suffix to ensure uniqueness.')
@minLength(2)
@maxLength(10)
@allowed([
  'local'
  'dev'
  'staging'
  'prod'
])
param envName string

@description('Resource tags applied to the managed identity.')
param tags tagsType

// ========== Variables ==========

var resourceSuffix = uniqueString(resourceGroup().id, name, envName, location)

// ========== Resources ==========

@description('User-assigned managed identity for workload resources')
resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${name}-${resourceSuffix}-mi'
  location: location
  tags: tags
}

// Built-in Azure role definition IDs for managed identity
// These GUIDs are consistent across all Azure subscriptions
var roles = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher
  '749f88d5-cbae-40b8-bcfc-e573ddc772fa' // Monitoring Contributor
  'ae349356-3a1b-4a5e-921d-050484c6347e' // Application Insights Component Contributor
  '08954f03-6346-4c2e-81c0-ec3a5cfae23b' // Application Insights Snapshot Debugger
  '090c5cfd-751d-490a-894a-3ce6f1109419' // Azure Service Bus Data Owner
  '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0' // Azure Service Bus Data Receiver
  '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39' // Azure Service Bus Data Sender
  '0b962ed2-6d56-471c-bd5f-3477d83a7ba4' // Azure Resource Notifications System Topics Subscriber
  '7f951dda-4ed3-4680-a7ca-43fe172d538d' // Azure Container Registry ACR Pull
  '8311e382-0749-4cb8-b61a-304f252e45ec' // Azure Container Registry ACR Push
]

// Assign roles to managed identity for resource access
// Uses loop to assign all roles at resource group scope
@description('Role assignments for managed identity to access Azure resources')
resource miRA 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(subscription().id, resourceGroup().id, mi.id, role)
    scope: resourceGroup()
    properties: {
      principalId: mi.properties.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
      principalType: 'ServicePrincipal'
    }
  }
]

// Assign same roles to deployment user for administrative access
// Allows user to manage resources during and after deployment
@description('Role assignments for deployment user to access Azure resources')
resource userRA 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(subscription().id, resourceGroup().id, deployer().objectId, role)
    scope: resourceGroup()
    properties: {
      principalId: deployer().objectId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
      principalType: 'User'
    }
  }
]

// ========== Outputs ==========

@description('Client ID of the deployed managed identity')
output MANAGED_IDENTITY_CLIENT_ID string = mi.properties.clientId

@description('Name of the deployed managed identity')
output MANAGED_IDENTITY_NAME string = mi.name

@description('Resource ID of the deployed managed identity (internal use only)')
output AZURE_MANAGED_IDENTITY_ID string = mi.id
