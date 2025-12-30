# ADR-002: Azure Service Bus for Asynchronous Messaging

## Status

**Accepted** - December 2025

## Context

The solution requires asynchronous communication between the Orders API and Logic Apps workflows. When an order is placed:

1. The API must persist the order and respond quickly to the user
2. Order processing workflows should execute independently
3. Multiple downstream systems may need to react to order events (future requirement)
4. The messaging system must support distributed tracing for end-to-end observability

Key requirements:

- **Decoupling**: API should not wait for workflow completion
- **Reliability**: Messages must not be lost
- **Observability**: Traces should flow across service boundaries
- **Scalability**: Handle burst traffic during peak ordering periods
- **Azure Integration**: Native Logic Apps connector for low-friction integration

## Decision

We adopt **Azure Service Bus** with a **topic/subscription** pattern for order event propagation.

### Topology

```
Orders API → ordersplaced (Topic) → orderprocessingsub (Subscription) → Logic App
```

### Configuration

```bicep
// From messaging/main.bicep
resource ordersTopic 'Microsoft.ServiceBus/namespaces/topics@2025-05-01-preview' = {
  parent: broker
  name: 'ordersplaced'
}

resource ordersSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2025-05-01-preview' = {
  parent: ordersTopic
  name: 'orderprocessingsub'
  properties: {
    maxDeliveryCount: 10
    lockDuration: 'PT5M'
    defaultMessageTimeToLive: 'P14D'
    deadLetteringOnMessageExpiration: true
  }
}
```

### Message Publishing

```csharp
// From OrdersMessageHandler.cs
var message = new ServiceBusMessage(messageBody)
{
    ContentType = "application/json",
    MessageId = order.Id,
    Subject = "OrderPlaced"
};

// Trace context propagation
message.ApplicationProperties["traceparent"] = activity.Id;
message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();

await sender.SendMessageAsync(message, cancellationToken);
```

### Why Topic/Subscription vs Queue

| Pattern | Use Case | Our Choice |
|---------|----------|------------|
| Queue | Point-to-point, single consumer | ❌ |
| Topic/Sub | Publish-subscribe, multiple consumers | ✅ |

We chose topics because:
1. Future subscribers can be added without API changes
2. Logic Apps can use different subscription filters
3. Dead-letter queues per subscription for isolation

## Consequences

### Positive

1. **Loose Coupling**: API completes immediately; workflow processes asynchronously
2. **Reliability**: Messages persisted; automatic retry with dead-lettering
3. **Trace Propagation**: W3C traceparent flows to Logic Apps
4. **Native Logic Apps Connector**: Service Bus trigger is first-class
5. **Fan-out Ready**: Add subscriptions for analytics, notifications, etc.
6. **Managed Identity Support**: No connection strings in production
7. **Local Emulation**: Aspire's Service Bus emulator for development

### Negative

1. **Eventual Consistency**: Order status not immediately reflected in workflows
2. **Complexity**: Additional infrastructure component to manage
3. **Cost**: Service Bus Standard tier has per-operation charges
4. **Message Ordering**: Not guaranteed across partitions (acceptable for orders)
5. **Debugging**: Async flows harder to trace than synchronous calls

### Neutral

1. **Message Size Limit**: 256 KB (Standard tier) - sufficient for orders
2. **Retention**: 14-day TTL configured - adequate for processing

## Alternatives Considered

### Azure Storage Queues

| Aspect | Storage Queues | Service Bus |
|--------|---------------|-------------|
| Price | Lower | Higher |
| Features | Basic FIFO | Topics, subscriptions, dead-letter |
| Transactions | No | Yes |
| Message Size | 64 KB | 256 KB (Standard) |
| Logic Apps Integration | Basic | Rich connector |

**Rejected**: No topic/subscription support; weaker Logic Apps integration.

### Azure Event Grid

| Aspect | Event Grid | Service Bus |
|--------|------------|-------------|
| Pattern | Event-driven push | Message queue pull |
| Delivery | At-least-once | At-least-once |
| Ordering | No guarantee | FIFO per session |
| Logic Apps | Push trigger | Pull trigger |

**Rejected**: Better for event routing; less suitable for command-style messages with guaranteed processing.

### Azure Event Hubs

| Aspect | Event Hubs | Service Bus |
|--------|------------|-------------|
| Use Case | High-throughput streaming | Reliable messaging |
| Consumers | Consumer groups | Subscriptions |
| Retention | Time-based | TTL per message |
| Ordering | Partition-based | Session-based |

**Rejected**: Designed for telemetry/streaming; overkill for order events.

### Direct HTTP Calls (Synchronous)

**Rejected**: Would block API response; create tight coupling; no retry/dead-letter support.

### RabbitMQ / Kafka

**Rejected**: Additional operational overhead; Service Bus is fully managed and Azure-native.

## References

- [Azure Service Bus Documentation](https://learn.microsoft.com/azure/service-bus-messaging/)
- [messaging/main.bicep](../../../infra/workload/messaging/main.bicep) - Infrastructure
- [OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs) - Publisher
- [Data Architecture](../02-data-architecture.md) - Messaging patterns
