// ============================================================================
// USER-ASSIGNED MANAGED IDENTITY MODULE
// ============================================================================
// Deploys a user-assigned managed identity for Logic Apps Standard workload.
//
// Purpose:
// - Provides a reusable identity for RBAC-based authentication
// - Enables credential-free access to Azure resources
// - Supports multiple resource assignments (Storage, Service Bus, App Insights)
//
// RBAC Roles (Assigned in logic-app.bicep):
// 1. Storage Account (4 roles):
//    - Storage Blob Data Owner (b7e6dc6d-f1e8-4753-8033-0f276bb0955b)
//    - Storage Queue Data Contributor (974c5e8b-45b9-4653-ba55-5f855dd0fb88)
//    - Storage Table Data Contributor (0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3)
//    - Storage File Data Privileged Contributor (69566ab7-960f-475b-8e7c-b3118f30c6bd)
//
// 2. Service Bus (3 roles):
//    - Azure Service Bus Data Owner (090c5cfd-751d-490a-894a-3ce6f1109419)
//    - Azure Service Bus Data Sender (69a216fc-b8fb-44d8-bc22-1f3c2cd27a39)
//    - Azure Service Bus Data Receiver (4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0)
//
// 3. Application Insights (1 role):
//    - Monitoring Metrics Publisher (3913510d-42f4-4e42-8a64-420c390055eb)
//
// Reference: https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Base name for the user-assigned managed identity. Will be suffixed with -mi.')
@minLength(3)
@maxLength(20)
param name string

@description('Azure region for managed identity deployment. Should match Logic App region.')
param location string = resourceGroup().location

@description('Resource tags applied to the managed identity for organization and governance.')
param tags object

// ============================================================================
// RESOURCES
// ============================================================================

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${name}-mi'
  location: location
  tags: tags
}

// ============================================================================
// OUTPUTS
// ============================================================================

@description('Resource ID of the user-assigned managed identity for identity assignment in Logic App')
output MANAGED_IDENTITY_ID string = userAssignedIdentity.id

@description('Name of the user-assigned managed identity')
output MANAGED_IDENTITY_NAME string = userAssignedIdentity.name

@description('Principal ID (object ID) of the managed identity for RBAC role assignments')
output MANAGED_IDENTITY_PRINCIPAL_ID string = userAssignedIdentity.properties.principalId

@description('Client ID (application ID) of the managed identity for app settings configuration')
output MANAGED_IDENTITY_CLIENT_ID string = userAssignedIdentity.properties.clientId
