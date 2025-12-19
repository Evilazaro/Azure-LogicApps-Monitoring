/*
  Common Type Definitions
  =======================
  Shared user-defined types used across all Bicep modules.
  
  Purpose:
  - Enforce consistent tagging across all resources
  - Standardize storage account configurations
  - Provide type safety and validation
  
  Usage:
  - Import types in other modules: import { tagsType } from './types.bicep'
  - All exported types are available for use in dependent modules
*/

// ========== Common Type Definitions ==========

@export()
@description('Tags applied to all resources for organization and cost tracking')
type tagsType = {
  @description('Name of the solution')
  Solution: string

  @description('Environment identifier')
  Environment: string

  @description('Management method')
  ManagedBy: string

  @description('Cost center identifier')
  CostCenter: string

  @description('Team responsible for the resources')
  Owner: string

  @description('Business unit')
  BusinessUnit: string

  @description('Deployment timestamp')
  DeploymentDate: string

  @description('Source repository')
  Repository: string
}

@export()
@description('Storage account configuration')
type storageAccountConfig = {
  @description('Storage account SKU')
  sku: 'Standard_LRS' | 'Standard_GRS' | 'Standard_RAGRS' | 'Standard_ZRS'

  @description('Storage account kind')
  kind: 'StorageV2' | 'BlobStorage' | 'BlockBlobStorage'

  @description('Access tier for the storage account')
  accessTier: 'Hot' | 'Cool'

  @description('Minimum TLS version')
  minimumTlsVersion: 'TLS1_0' | 'TLS1_1' | 'TLS1_2'

  @description('Whether HTTPS traffic only is supported')
  supportsHttpsTrafficOnly: bool
}
