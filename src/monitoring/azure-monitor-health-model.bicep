// Azure Monitor Health Model service group for hierarchical health monitoring
// Creates a tenant-level service group for organizing monitoring resources

@description('Name of the service group for health model organization.')
@minLength(3)
@maxLength(50)
param name string

@description('Tags to apply to the service group for organization and governance.')
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

