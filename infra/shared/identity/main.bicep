/*
  Managed Identity Module
  =======================
  Deploys a user-assigned managed identity with comprehensive role assignments
  for Azure workload resources following the principle of least privilege.
  
  Purpose:
  - Creates a single user-assigned managed identity for all workload resources
  - Implements principle of least privilege with specific, scoped role assignments
  - Configures role assignments for both the managed identity and deployment user
  - Supports both interactive (User) and CI/CD (ServicePrincipal) deployment scenarios
  
  Assigned Roles:
  - Storage: Account Contributor, Blob Data Contributor, Blob Data Owner,
             Table Data Contributor, Queue Data Contributor, File Data roles
  - Monitoring: Metrics Publisher, Contributor, Application Insights Component Contributor,
                Application Insights Snapshot Debugger
  - Service Bus: Data Owner, Data Receiver, Data Sender
  - Container Registry: ACR Pull, ACR Push
  - Resource Notifications: System Topics Subscriber
  
  Parameters:
  - name: Base name for the managed identity resource
  - location: Azure region for deployment
  - envName: Environment identifier (dev, test, prod, staging)
  - tags: Resource tags for organization and cost tracking
  - deployerPrincipalType: Principal type for deployment user role assignments
  
  Outputs:
  - MANAGED_IDENTITY_CLIENT_ID: Client ID for application authentication
  - MANAGED_IDENTITY_NAME: Name of the created managed identity resource
  - AZURE_MANAGED_IDENTITY_ID: Full resource ID of the managed identity
  - AZURE_MANAGED_IDENTITY_PRINCIPAL_ID: Principal ID for permission assignments
  
  Usage:
  This module creates deterministic, idempotent role assignments using guid()
  to generate consistent assignment names across redeployments.
*/

metadata name = 'Managed Identity'
metadata description = 'Deploys user-assigned managed identity with role assignments for workload resources'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for the managed identity')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for managed identity deployment')
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

@description('Resource tags applied to the managed identity')
param tags tagsType

@description('Principal type of the deployer (User for interactive, ServicePrincipal for CI/CD)')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

// ========== Variables ==========

@description('Unique suffix for resource naming based on subscription, resource group, and parameters')
var resourceSuffix string = uniqueString(subscription().subscriptionId, resourceGroup().id, name, envName, location)

// ========== Resources ==========

@description('User-assigned managed identity for workload resources')
resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2025-01-31-preview' = {
  name: '${name}-${resourceSuffix}-mi'
  location: location
  tags: tags
}

// ========== Outputs ==========

@description('Managed Identity ClientId (internal use only)')
output MANAGED_IDENTITY_CLIENT_ID string = mi.properties.clientId

@description('Name of the managed identity resource')
output MANAGED_IDENTITY_NAME string = mi.name

// ========== Role Assignments ==========

/*
  Built-in Azure Role Definition IDs
  -----------------------------------
  These GUIDs represent Azure's built-in role definitions and are consistent
  across all Azure subscriptions. Roles are organized by service category:
  
  Storage Roles:
  - Storage Account Contributor: Manage storage accounts
  - Storage Blob Data Contributor/Owner: Read, write, delete blob data
  - Storage Table/Queue Data Contributor: Access table and queue data
  - Storage File Data roles: Various file share access levels
  
  Monitoring Roles:
  - Monitoring Metrics Publisher: Publish metrics to Azure Monitor
  - Monitoring Contributor: Full access to monitoring resources
  - Application Insights roles: Manage and debug App Insights components
  
  Messaging Roles:
  - Service Bus Data Owner/Receiver/Sender: Full messaging access
  - Resource Notifications Subscriber: Subscribe to system topics
  
  Container Roles:
  - ACR Pull/Push: Pull and push container images
*/
@description('Array of Azure built-in role definition IDs for resource access')
var roles string[] = [
  '17d1049b-9a84-46fb-8f53-869881c3d3ab' // Storage Account Contributor
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Blob Data Owner
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor
  '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data Privileged Contributor
  'bbf004e3-0e4b-4f86-ae4f-1f8fb47b357b' // Storage File Data SMB Admin
  'a235d3ee-5935-4cfb-8cc5-a3303ad5995e' // Storage File Data SMB MI Admin
  '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb' // Storage File Data SMB Share Contributor
  'a7264617-510b-434b-a828-9731dc254ea7' // Storage File Data SMB Share Elevated Contributor
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
// Each assignment uses guid() with subscription, resource group, identity, and role IDs
// to create deterministic, idempotent assignment names that won't conflict on redeployment
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
// Uses deployer() function to reference the principal executing the deployment
@description('Role assignments for deployment user to access Azure resources')
resource userRA 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for role in roles: {
    name: guid(subscription().id, resourceGroup().id, deployer().objectId, role)
    scope: resourceGroup()
    properties: {
      principalId: deployer().objectId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role)
      principalType: deployerPrincipalType
    }
  }
]

// ========== Outputs ==========

@description('Resource ID of the deployed managed identity (internal use only)')
output AZURE_MANAGED_IDENTITY_ID string = mi.id

@description('Managed Identity Principal ID for assigning permissions')
output AZURE_MANAGED_IDENTITY_PRINCIPAL_ID string = mi.properties.principalId
