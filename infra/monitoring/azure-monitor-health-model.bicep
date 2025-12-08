@description('Name of the service group for health model organization.')
@minLength(3)
@maxLength(260)
param name string

@description('Resource tags applied to the service group.')
param tags object = {}

resource rootSvcGrp 'Microsoft.Management/serviceGroups@2024-02-01-preview' existing = {
  name: '0e2ff29e-431a-420b-8a46-c6f39106927b'
  scope: tenant()
}

resource svcGrp 'Microsoft.Management/serviceGroups@2024-02-01-preview' = {
  name: name
  scope: tenant()
  //tags: tags
  kind: 'ServiceGroup'
  properties: {
    displayName: name
    parent: {
      resourceId: rootSvcGrp.id
    }
  }
}
