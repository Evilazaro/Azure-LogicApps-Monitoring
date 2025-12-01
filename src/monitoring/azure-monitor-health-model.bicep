// ============================================================================
// AZURE MONITOR HEALTH MODEL MODULE
// ============================================================================
// Creates a tenant-level service group for hierarchical organization of
// monitoring resources. Service groups enable:
// - Logical grouping of related Azure Monitor resources
// - Hierarchical health rollup (child health impacts parent)
// - Centralized health dashboards across multiple subscriptions
//
// Architecture:
// - Parent: Root service group (tenant-level, ID: 0e2ff29e-431a-420b-8a46-c6f39106927b)
// - Child: Solution-specific service group (created by this module)
//
// Note: Service groups are a preview feature. Ensure preview features are
// enabled in your Azure subscription before deploying this resource.
//
// Reference: https://learn.microsoft.com/azure/azure-monitor/service-groups/overview
// ============================================================================

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Name of the service group for health model organization. Should be descriptive (e.g., solution name or business unit).')
@minLength(3)
@maxLength(50)
param name string

@description('Resource tags applied to the service group for organization, governance, and cost tracking.')
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

