@description('Base name for the storage account. Must be 3-20 characters to ensure final name meets Azure requirements.')
@minLength(3)
@maxLength(20)
param name string
param location string = resourceGroup().location
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
