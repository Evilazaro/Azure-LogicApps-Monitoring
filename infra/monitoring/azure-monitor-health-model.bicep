/*
  Azure Monitor Health Model Module
  =================================
  Creates service group hierarchy for organizing health monitoring.
  
  Purpose:
  - Establishes service group for logical organization
  - Connects to root Azure Monitor health model
  - Enables hierarchical health monitoring across services
  
  Note:
  - Deployed at tenant scope for cross-subscription visibility
  - Root service group ID is the Azure default root
*/

metadata name = 'Azure Monitor Health Model'
metadata description = 'Creates service group hierarchy for organizing health monitoring'

// ========== Type Definitions ==========

import { tagsType } from '../types.bicep'

// ========== Parameters ==========

@description('Name of the service group for health model organization.')
@minLength(3)
@maxLength(260)
param name string

@description('Resource tags applied to the service group.')
param tags tagsType

// ========== Resources ==========

// Azure Monitor default root service group (fixed GUID)
// All custom service groups must be parented under this root
@description('Reference to the root service group in Azure Monitor health model')
resource rootSvcGrp 'Microsoft.Management/serviceGroups@2024-02-01-preview' existing = {
  name: '0e2ff29e-431a-420b-8a46-c6f39106927b'
  scope: tenant()
}

@description('Service group for organizing health monitoring hierarchy')
resource svcGrp 'Microsoft.Management/serviceGroups@2024-02-01-preview' = {
  name: name
  scope: tenant()
  tags: tags
  kind: 'ServiceGroup'
  properties: {
    displayName: name
    parent: {
      resourceId: rootSvcGrp.id
    }
  }
}
