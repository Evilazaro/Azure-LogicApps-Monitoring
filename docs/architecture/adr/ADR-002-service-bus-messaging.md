# ADR-002: Use Azure Service Bus for Event-Driven Messaging

## Status

**Accepted** - January 2025

---

## Context

The solution requires an event-driven architecture to:

1. **Decouple order creation from downstream processing** - The Orders API should not wait for all order processing to complete
2. **Enable multiple consumers** - Logic Apps (and potentially other services) need to react to order events
3. **Ensure reliable delivery** - Order events must not be lost
4. **Support distributed tracing** - Events should carry trace context for end-to-end observability
5. **Scale independently** - Message producers and consumers should scale independently

### Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Reliable delivery | Must | Orders must not be lost |
| Pub/Sub pattern | Must | Multiple subscribers per event |
| Dead letter support | Must | Handle processing failures |
| Trace context propagation | Must | End-to-end observability |
| Managed service | Should | Minimize operational overhead |
| .NET SDK support | Must | First-class language support |

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Azure Service Bus** | Enterprise-grade, topics/subscriptions, DLQ, native Azure integration | Cost at scale |
| **Azure Event Hub** | High throughput, partitioning | No topics/subscriptions, partition ordering |
| **Azure Storage Queues** | Simple, cheap | No pub/sub, limited features |
| **RabbitMQ (self-hosted)** | Flexible, widely adopted | Operational overhead, not managed |
| **Azure Event Grid** | Event-driven, webhooks | Different use case (reactive events) |

---

## Decision

We will use **Azure Service Bus** (Standard tier) with **Topics and Subscriptions** for event-driven messaging.

### Key Implementation

**Message Publishing** ([OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)):

```csharp
public async Task<bool> SendAsync(Order order, string topicName, CancellationToken cancellationToken)
{
    // Create activity for distributed tracing
    using var activity = _activitySource.StartActivity(
        $"ServiceBus.{topicName}.Send", 
        ActivityKind.Producer);

    var message = new ServiceBusMessage(JsonSerializer.Serialize(order))
    {
        ContentType = "application/json",
        MessageId = order.Id.ToString(),
        Subject = "OrderPlaced",
        CorrelationId = order.Id.ToString()
    };

    // Add trace context to message for distributed tracing
    if (activity != null)
    {
        message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
        message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();
        message.ApplicationProperties["traceparent"] = activity.Id ?? string.Empty;
    }

    await using var sender = _serviceBusClient.CreateSender(topicName);
    await sender.SendMessageAsync(message, cancellationToken);
    
    return true;
}
```

**Infrastructure** ([messaging/main.bicep](../../../infra/workload/messaging/main.bicep)):

```bicep
// Service Bus Namespace
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

// Topic for order events
resource ordersTopic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: 'ordersplaced'
}

// Subscription for Logic Apps processing
resource ordersSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: ordersTopic
  name: 'orderprocessingsub'
  properties: {
    deadLetteringOnMessageExpiration: true
    maxDeliveryCount: 10
  }
}
```

### Messaging Topology

```
Service Bus Namespace
└── ordersplaced (Topic)
    └── orderprocessingsub (Subscription)
        └── Dead Letter Queue
```

---

## Consequences

### Positive

1. **Reliable event delivery**
   - At-least-once delivery guarantee
   - Dead letter queue for failed messages
   - Configurable retry policies

2. **Decoupled architecture**
   - Orders API doesn't wait for processing
   - New subscribers can be added without API changes
   - Independent scaling of producers and consumers

3. **Native Azure integration**
   - Managed Identity authentication (no secrets)
   - Logic Apps Service Bus connector
   - Azure Monitor integration

4. **Distributed tracing support**
   - W3C Trace Context in message properties
   - End-to-end correlation in Application Insights
   - Producer/consumer span linking

5. **Operational simplicity**
   - Fully managed service
   - Built-in monitoring
   - Auto-scaling with Standard tier

### Negative

1. **Cost considerations**
   - Standard tier required for topics
   - Cost per operation and message size
   - **Mitigation**: Monitor usage, right-size for workload

2. **Message size limit**
   - 256 KB per message (Standard tier)
   - **Mitigation**: Keep payloads small, use claim check pattern if needed

3. **Eventual consistency**
   - Subscribers see events asynchronously
   - **Mitigation**: Design for eventual consistency, use correlation IDs

### Neutral

1. **Learning curve** - Team needs Service Bus knowledge
2. **Local development** - Requires Service Bus emulator or Azure instance
3. **Message format** - JSON serialization adds overhead vs. binary

---

## Related Decisions

- [ADR-001](ADR-001-aspire-orchestration.md) - Aspire configures Service Bus client and emulator
- [ADR-003](ADR-003-observability-strategy.md) - Trace context propagation enables end-to-end tracing

---

## References

- [Azure Service Bus Documentation](https://learn.microsoft.com/azure/service-bus-messaging/)
- [OrdersMessageHandler Implementation](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)
- [Messaging Infrastructure](../../../infra/workload/messaging/main.bicep)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
