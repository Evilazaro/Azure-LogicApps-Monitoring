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
@description('Storage account configuration with security and performance settings')
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
// ========== Trigger Type Definitions ==========

@description('Connection reference for API connections')
type connectionType = {
  referenceName: string
}

@description('Host configuration for API connection triggers')
type hostType = {
  connection: connectionType
}

@description('Query parameters for the trigger')
type queriesType = {
  subscriptionType: string
}

@description('Input configuration for Service Bus trigger')
type triggerInputsType = {
  host: hostType
  method: string
  path: string
  queries: queriesType
}

@description('Recurrence schedule for the trigger')
type recurrenceType = {
  interval: int
  frequency: 'Second' | 'Minute' | 'Hour' | 'Day' | 'Week' | 'Month'
  timeZone: string
}

@description('Service Bus topic subscription trigger (auto-complete)')
type serviceBusTopicTriggerType = {
  type: 'ApiConnection'
  inputs: triggerInputsType
  recurrence: recurrenceType
}

@description('Triggers definition for the workflow')
@export()
type triggersType = {
  @description('Trigger that fires when a message is received in a Service Bus topic subscription')
  'When_a_message_is_received_in_a_topic_subscription_(auto-complete)': serviceBusTopicTriggerType
}
