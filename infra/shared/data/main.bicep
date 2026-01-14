/*
  Data Infrastructure Module
  ==========================
  Deploys storage infrastructure for Logic Apps and Container Apps.
  
  Components:
  1. Storage account for Logic Apps runtime (Standard tier requirement)
  2. Blob containers for processed orders (success/error segregation)
  3. Azure Files storage for Container Apps persistent volumes
  
  Key Features:
  - Separate containers for success and error order processing
  - Azure Files share for orders-api persistent data
  - Integrated diagnostic logging
*/

metadata name = 'Data Infrastructure'
metadata description = 'Storage accounts and containers for workflow data and Container Apps persistent storage'

// ========== Type Definitions ==========

import { tagsType } from '../../types.bicep'

// ========== Parameters ==========

@description('Base name for storage resources')
@minLength(3)
@maxLength(20)
param name string

@description('Environment name to differentiate deployments.')
@maxLength(10)
@allowed([
  'dev'
  'test'
  'prod'
  'staging'
])
param envName string

@description('Azure region for storage deployment')
@minLength(3)
@maxLength(50)
param location string = resourceGroup().location

@description('Resource ID of the User Assigned Identity to be used by storage resources')
@minLength(50)
param userAssignedIdentityId string

@description('Resource ID of the Log Analytics workspace for diagnostic logs and metrics')
@minLength(50)
param workspaceId string

@description('Storage Account ID for diagnostic logs and metrics')
@minLength(50)
param storageAccountId string

@description('Resource ID of the data subnet for private endpoints')
@minLength(50)
param dataSubnetId string

@description('Resource ID of the virtual network for private DNS zone linking')
@minLength(50)
param vnetId string

@description('Logs settings for the Log Analytics workspace')
param logsSettings object[]

@description('Metrics settings for the Log Analytics workspace')
param metricsSettings object[]

@description('Resource tags applied to storage resources')
param tags tagsType

@description('Principal type of the deployer (User for interactive, ServicePrincipal for CI/CD)')
@allowed([
  'User'
  'ServicePrincipal'
])
param deployerPrincipalType string = 'User'

// ========== Variables ==========

// Remove special characters for naming compliance
// Storage account names must be lowercase alphanumeric only
@description('Cleaned name with special characters removed for Azure naming requirements')
var cleanedName string = toLower(replace(replace(replace(name, '-', ''), '_', ''), ' ', ''))

// Generate unique suffix for globally unique resource names
@description('Unique suffix for globally unique resource names')
var uniqueSuffix string = uniqueString(resourceGroup().id, name, envName, location)

// ========== Storage Resources ==========

@description('Storage account for Logic Apps workflows and data')
resource wfSA 'Microsoft.Storage/storageAccounts@2025-06-01' = {
  name: toLower('${cleanedName}wsa${uniqueSuffix}')
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  tags: tags
  properties: {
    accessTier: 'Hot' // Hot tier for frequently accessed workflow data
    supportsHttpsTrafficOnly: true // Require secure connections
    minimumTlsVersion: 'TLS1_2' // Enforce TLS 1.2 minimum for security compliance
    allowBlobPublicAccess: true // Required for Logic Apps Standard blob triggers
    publicNetworkAccess: 'Enabled' // Required for initial provisioning, secured via private endpoints
    allowSharedKeyAccess: true // Required for Logic Apps Standard initial connection
    networkAcls: {
      bypass: 'AzureServices, Logging, Metrics' // Allow trusted Azure services
      defaultAction: 'Allow' // Allow public access for development environments
      ipRules: []
      virtualNetworkRules: []
    }
  }
}

@description('Blob service for workflow storage account')
resource blobSvc 'Microsoft.Storage/storageAccounts/blobServices@2025-06-01' = {
  parent: wfSA
  name: 'default'
}

// File service for Logic Apps content share
@description('File service for workflow storage account')
resource fileSvc 'Microsoft.Storage/storageAccounts/fileServices@2025-06-01' = {
  parent: wfSA
  name: 'default'
}

@description('File share name for Logic App workflow state')
var contentShareName = 'workflowstate'

@description('File share for Logic App content (pre-created to avoid 403 errors)')
resource contentShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2025-06-01' = {
  parent: fileSvc
  name: contentShareName
  properties: {
    shareQuota: 5120 // 5GB quota
    enabledProtocols: 'SMB'
  }
}

// Container for successfully processed orders
// Segregates successful processing for audit and compliance
@description('Blob container for successfully processed orders')
resource poSuccess 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobSvc
  name: 'ordersprocessedsuccessfully'
  properties: {
    publicAccess: 'None'
  }
}

// Container for failed order processing
// Enables separate error handling and retry workflows
@description('Blob container for orders processed with errors')
resource poFailed 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobSvc
  name: 'ordersprocessedwitherrors'
  properties: {
    publicAccess: 'None'
  }
}

// Container for completed order processing
// Enables tracking of all completed orders
@description('Blob container for completed order processing')
resource poCompleted 'Microsoft.Storage/storageAccounts/blobServices/containers@2025-06-01' = {
  parent: blobSvc
  name: 'ordersprocessedcompleted'
  properties: {
    publicAccess: 'None'
  }
}

@description('Diagnostic settings for workflow storage account')
resource saDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${wfSA.name}-diag'
  scope: wfSA
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    metrics: metricsSettings
  }
}

// ========== Private Endpoint Resources for Storage ==========

@description('Private DNS Zone for Storage Blob')
resource blobPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.blob.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

@description('Link blob DNS zone to virtual network')
resource blobPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: blobPrivateDnsZone
  name: '${blobPrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Private endpoint for Storage Blob')
resource blobPrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: '${wfSA.name}-blob-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: dataSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${wfSA.name}-blob-pe-connection'
        properties: {
          privateLinkServiceId: wfSA.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

@description('Private DNS zone group for blob private endpoint')
resource blobPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: blobPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob-core-windows-net'
        properties: {
          privateDnsZoneId: blobPrivateDnsZone.id
        }
      }
    ]
  }
}

@description('Private DNS Zone for Storage File')
resource filePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.file.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

@description('Link file DNS zone to virtual network')
resource filePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: filePrivateDnsZone
  name: '${filePrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Private endpoint for Storage File')
resource filePrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: '${wfSA.name}-file-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: dataSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${wfSA.name}-file-pe-connection'
        properties: {
          privateLinkServiceId: wfSA.id
          groupIds: [
            'file'
          ]
        }
      }
    ]
  }
}

@description('Private DNS zone group for file private endpoint')
resource filePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: filePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-file-core-windows-net'
        properties: {
          privateDnsZoneId: filePrivateDnsZone.id
        }
      }
    ]
  }
}

@description('Private DNS Zone for Storage Table')
resource tablePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.table.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

@description('Link table DNS zone to virtual network')
resource tablePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: tablePrivateDnsZone
  name: '${tablePrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Private endpoint for Storage Table')
resource tablePrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: '${wfSA.name}-table-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: dataSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${wfSA.name}-table-pe-connection'
        properties: {
          privateLinkServiceId: wfSA.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }
}

@description('Private DNS zone group for table private endpoint')
resource tablePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: tablePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-table-core-windows-net'
        properties: {
          privateDnsZoneId: tablePrivateDnsZone.id
        }
      }
    ]
  }
}

@description('Private DNS Zone for Storage Queue')
resource queuePrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink.queue.${environment().suffixes.storage}'
  location: 'global'
  tags: tags
}

@description('Link queue DNS zone to virtual network')
resource queuePrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: queuePrivateDnsZone
  name: '${queuePrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Private endpoint for Storage Queue')
resource queuePrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: '${wfSA.name}-queue-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: dataSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${wfSA.name}-queue-pe-connection'
        properties: {
          privateLinkServiceId: wfSA.id
          groupIds: [
            'queue'
          ]
        }
      }
    ]
  }
}

@description('Private DNS zone group for queue private endpoint')
resource queuePrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: queuePrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-queue-core-windows-net'
        properties: {
          privateDnsZoneId: queuePrivateDnsZone.id
        }
      }
    ]
  }
}

// ========== Storage Outputs ==========

@description('Name of the deployed storage account for Logic Apps workflows')
output AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW string = wfSA.name

@description('Resource ID of the deployed storage account for Logic Apps workflows')
output AZURE_STORAGE_ACCOUNT_ID_WORKFLOW string = wfSA.id

// ========== SQL Server Resources ==========

@description('SQL Server instance for application database with Entra ID authentication')
resource sqlServer 'Microsoft.Sql/servers@2024-11-01-preview' = {
  name: toLower('${cleanedName}server${uniqueSuffix}')
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    primaryUserAssignedIdentityId: userAssignedIdentityId
    administrators: {
      administratorType: 'ActiveDirectory'
      azureADOnlyAuthentication: true
      // Principal type varies based on deployer:
      // - 'User' for interactive deployments (uses userPrincipalName)
      // - 'Application' for CI/CD with Service Principals (uses objectId as login)
      principalType: deployerPrincipalType == 'ServicePrincipal' ? 'Application' : 'User'
      // Service Principals don't have userPrincipalName, use objectId instead
      login: deployerPrincipalType == 'ServicePrincipal' ? deployer().objectId : deployer().userPrincipalName
      sid: deployer().objectId
      tenantId: tenant().tenantId
    }
    publicNetworkAccess: 'Enabled'
    minimalTlsVersion: '1.2'
  }
  tags: tags
}

@description('Fully qualified domain name of the deployed SQL Server')
output ORDERSDATABASE_SQLSERVERFQDN string = sqlServer.properties.fullyQualifiedDomainName

@description('Name of the deployed SQL Server instance')
output AZURE_SQL_SERVER_NAME string = sqlServer.name

// Enforce Entra ID-only authentication for SQL Server
// Disables SQL authentication to enhance security
@description('Entra-only authentication configuration for SQL Server')
resource entraOnlyAuth 'Microsoft.Sql/servers/azureADOnlyAuthentications@2024-11-01-preview' = {
  parent: sqlServer
  name: 'Default' // The name for this resource is typically 'Default'
  properties: {
    azureADOnlyAuthentication: true
  }
}

// ========== Private Endpoint Resources ==========

@description('Private DNS Zone for SQL Server private endpoint')
resource sqlPrivateDnsZone 'Microsoft.Network/privateDnsZones@2024-06-01' = {
  name: 'privatelink${environment().suffixes.sqlServerHostname}'
  location: 'global'
  tags: tags
}

@description('Link private DNS zone to virtual network')
resource sqlPrivateDnsZoneLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = {
  parent: sqlPrivateDnsZone
  name: '${sqlPrivateDnsZone.name}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetId
    }
  }
}

@description('Private endpoint for SQL Server')
resource sqlPrivateEndpoint 'Microsoft.Network/privateEndpoints@2025-01-01' = {
  name: '${sqlServer.name}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: dataSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${sqlServer.name}-pe-connection'
        properties: {
          privateLinkServiceId: sqlServer.id
          groupIds: [
            'sqlServer'
          ]
        }
      }
    ]
  }
}

@description('Private DNS zone group for SQL Server private endpoint')
resource sqlPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2025-01-01' = {
  parent: sqlPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-database-windows-net'
        properties: {
          privateDnsZoneId: sqlPrivateDnsZone.id
        }
      }
    ]
  }
}

@description('Allow Azure services to access SQL Server - removed as using private endpoint')
resource allowAzureServices 'Microsoft.Sql/servers/firewallRules@2024-11-01-preview' = {
  parent: sqlServer
  name: 'AllowAllWindowsAzureIps'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// SQL Database resource for application data
@description('SQL Database for storing application data')
resource sqlDb 'Microsoft.Sql/servers/databases@2024-11-01-preview' = {
  name: 'OrderDb'
  parent: sqlServer
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  sku: {
    name: 'GP_Gen5_2'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 2
    size: '32GB'
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 34359738368 // 32 GB
    zoneRedundant: false
  }
  tags: tags
}

// ========== SQL Outputs ==========

@description('Name of the deployed SQL Database')
output AZURE_SQL_DATABASE_NAME string = sqlDb.name

// ========== Diagnostic Settings ==========

// Enable diagnostic settings for SQL Database
@description('Diagnostic settings for SQL Database')
resource sqlDiag 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${sqlDb.name}-diag'
  scope: sqlDb
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logAnalyticsDestinationType: 'Dedicated'
    logs: logsSettings
    metrics: metricsSettings
  }
}
