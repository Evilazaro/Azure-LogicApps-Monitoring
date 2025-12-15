@description('The location for the resource(s) to be deployed.')
param location string = resourceGroup().location

param Service_Bus string

resource Messaging 'Microsoft.ServiceBus/namespaces@2024-01-01' existing = {
  name: Service_Bus
}

resource orders_queue 'Microsoft.ServiceBus/namespaces/queues@2024-01-01' = {
  name: 'orders-queue'
  parent: Messaging
}

output serviceBusEndpoint string = Messaging.properties.serviceBusEndpoint

output name string = Service_Bus