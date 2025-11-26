@description('Base name for the storage account. Must be 3-20 characters to ensure final name meets Azure requirements.')
@minLength(3)
@maxLength(20)
param name string
param location string = resourceGroup().location
@description('Principal ID of the managed identity that needs access to the storage account')
param servicePrincipalId string
@description('Tags to apply to the storage account for organization and governance')
param tags object

// Generate a storage account name that meets Azure naming requirements:
// - 3-24 characters, lowercase alphanumeric only
// - uniqueString (13 chars) + 'stg' (3 chars) = 16 chars minimum guaranteed
var cleanedName = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))
var uniqueSuffix = uniqueString(resourceGroup().id, name)
var storageAccountName = take('${cleanedName}${uniqueSuffix}stg', 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: length(storageAccountName) >= 3 ? storageAccountName : '${storageAccountName}stg'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}

@description('Name of the deployed storage account (generated with unique suffix)')
output STORAGE_ACCOUNT_NAME string = storageAccount.name

// RBAC Roles for Logic Apps Standard Storage Requirements
// Logic Apps Standard requires specific storage permissions for workflow state, artifacts, and runtime data
// Following least-privilege principle - only essential roles for Logic Apps functionality
// References:
// - Storage Blob Data Owner: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-owner
// - Storage Queue Data Contributor: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-queue-data-contributor  
// - Storage Table Data Contributor: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-table-data-contributor
// - Storage File Data Privileged Contributor: https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor
var storageRBACRoles = [
  'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' // Storage Blob Data Owner - Full control over blob containers and data
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor - Read, write, and delete queue messages
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor - Read, write, and delete table data
  '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data Privileged Contributor - Read, write, and modify files/directories
]

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for roleId in storageRBACRoles: {
    name: guid(storageAccount.id, servicePrincipalId, roleId)
    scope: storageAccount
    properties: {
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleId)
      principalId: servicePrincipalId
      principalType: 'ServicePrincipal'
    }
  }
]
