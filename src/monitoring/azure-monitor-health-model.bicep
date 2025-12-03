// ============================================================================
// AZURE MONITOR HEALTH MODEL MODULE
// ============================================================================
// Creates a hierarchical service group structure for Azure Monitor to organize
// and categorize monitoring resources. Enables logical grouping of resources
// for better observability and resource management.
//
// NOTE: This module uses a preview API version (2024-02-01-preview).
// Verify API availability in your target Azure environment before deployment.
// ============================================================================

@description('Name of the service group for health model organization. Should be descriptive (e.g., solution name or business unit).')
@minLength(3)
@maxLength(260)
param name string

@description('Resource tags applied to the service group for organization, governance, and cost tracking.')
@metadata({
  example: {
    Solution: 'tax-docs'
    Environment: 'prod'
  }
})
param tags object

resource rootServiceGroup 'Microsoft.Management/serviceGroups@2024-02-01-preview' existing = {
  name: '0e2ff29e-431a-420b-8a46-c6f39106927b'
  scope: tenant()
}

resource serviceGroup 'Microsoft.Management/serviceGroups@2024-02-01-preview' = {
  name: name
  scope: tenant()
  tags: tags
  kind: 'ServiceGroup'
  properties: {
    displayName: name
    parent: {
      resourceId: rootServiceGroup.id
    }
  }
}

