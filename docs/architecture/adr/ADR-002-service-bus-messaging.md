# ADR-002: Azure Service Bus for Asynchronous Messaging

## Status
**Accepted** - January 2024

## Context

The eShop Azure Platform requires asynchronous communication between services for:
- **Order processing workflows** - Decoupling order placement from downstream processing
- **Event propagation** - Notifying multiple consumers of business events
- **Reliability** - Ensuring messages are not lost during transient failures
- **Scalability** - Handling variable message volumes without overloading services

Key requirements:
1. **Pub/Sub pattern** - Multiple subscribers to order events
2. **Message durability** - At-least-once delivery guarantee
3. **Dead-letter handling** - Failed message investigation
4. **Managed identity support** - No stored credentials
5. **Distributed tracing** - End-to-end correlation across services

## Decision

**Use Azure Service Bus Standard tier with Topics and Subscriptions for asynchronous messaging.**

### Implementation

1. **Topic/Subscription Pattern**
   - `ordersplaced` topic for order lifecycle events
   - `orderprocessingsub` subscription for Logic Apps consumption
   - Enables adding future subscribers without modifying publishers

2. **Message Publishing with Trace Context**
   ```csharp
   // OrdersMessageHandler.cs
   public async Task PublishOrderPlacedAsync(Order order)
   {
       var message = new ServiceBusMessage(JsonSerializer.Serialize(order))
       {
           MessageId = Guid.NewGuid().ToString(),
           ContentType = "application/json",
           Subject = "OrderPlaced"
       };

       // Propagate W3C Trace Context
       if (Activity.Current != null)
       {
           message.ApplicationProperties["TraceId"] = Activity.Current.TraceId.ToString();
           message.ApplicationProperties["SpanId"] = Activity.Current.SpanId.ToString();
           message.ApplicationProperties["traceparent"] = Activity.Current.Id;
       }

       await _sender.SendMessageAsync(message);
   }
   ```

3. **Managed Identity Authentication**
   ```csharp
   // Extensions.cs
   builder.AddAzureServiceBusClient(connectionName, settings =>
   {
       settings.Credential = new DefaultAzureCredential();
   });
   ```

4. **Logic Apps Integration**
   - Service Bus trigger polls subscription every 1 second
   - Managed connector uses managed identity
   - Auto-complete after successful processing

### Architecture

```
┌─────────────────┐     ┌──────────────────────────────┐     ┌─────────────────┐
│  Orders API     │────▶│  Azure Service Bus           │────▶│  Logic Apps     │
│                 │     │  ┌────────────────────────┐  │     │                 │
│  PublishOrder() │     │  │ ordersplaced (topic)   │  │     │  Trigger        │
│                 │     │  │  └─ orderprocessingsub │  │     │  ProcessOrder() │
└─────────────────┘     └──────────────────────────────┘     └─────────────────┘
        │                           │                                 │
        └───────────────────────────┼─────────────────────────────────┘
                                    │
                    TraceId propagation via ApplicationProperties
```

## Consequences

### Positive

| Benefit | Impact |
|---------|--------|
| **Decoupled architecture** | API completes quickly, processing is async |
| **Reliable delivery** | At-least-once with dead-letter support |
| **Scalability** | Topic handles multiple subscribers independently |
| **Observability** | W3C Trace Context flows through messages |
| **Zero credential management** | Managed identity authentication |
| **Native Azure integration** | Logic Apps, Functions connectors available |
| **Enterprise features** | Sessions, duplicate detection, scheduled delivery |

### Negative

| Tradeoff | Mitigation |
|----------|------------|
| **Additional service cost** | Standard tier ~$10/month, scales with usage |
| **Eventual consistency** | Design for idempotency, use message IDs |
| **Local development complexity** | Aspire manages emulator configuration |
| **Message ordering** | Use sessions if strict ordering required |
| **Message size limit** | 256KB Standard, 100MB Premium (use blob for large payloads) |

### Neutral

- Messages have 14-day TTL by default
- Dead-letter queue requires monitoring and handling
- Subscription filters can route messages to specific consumers

## Alternatives Considered

### 1. Azure Queue Storage
- **Pros:** Simple, cheap, built into Storage Account
- **Cons:** No pub/sub, limited features, no dead-letter
- **Rejected because:** Does not support topic/subscription pattern

### 2. Azure Event Grid
- **Pros:** Event-driven, push model, wide integration
- **Cons:** At-most-once delivery, less control over consumption
- **Rejected because:** Requires at-least-once for order processing reliability

### 3. Azure Event Hubs
- **Pros:** High throughput, partitioned, event streaming
- **Cons:** Complex consumer groups, overkill for command messages
- **Rejected because:** Better suited for telemetry/streaming, not business commands

### 4. RabbitMQ (self-hosted or CloudAMQP)
- **Pros:** Open source, flexible routing, well-known
- **Cons:** Operational overhead, no managed identity, separate tooling
- **Rejected because:** Azure Service Bus provides managed experience with Azure integration

### 5. Direct HTTP Calls (Synchronous)
- **Pros:** Simple, immediate feedback
- **Cons:** Tight coupling, cascading failures, no retry/buffering
- **Rejected because:** Does not meet reliability and decoupling requirements

## Message Contract

```json
{
  "messageId": "guid",
  "contentType": "application/json",
  "subject": "OrderPlaced",
  "body": {
    "id": 1,
    "customerName": "John Smith",
    "totalAmount": 99.99,
    "products": [...]
  },
  "applicationProperties": {
    "TraceId": "abc123...",
    "SpanId": "xyz789...",
    "traceparent": "00-abc123...-xyz789...-01"
  }
}
```

## References

- [Azure Service Bus Documentation](https://learn.microsoft.com/azure/service-bus-messaging/)
- [Service Bus Topics and Subscriptions](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-queues-topics-subscriptions)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [Data Architecture](../02-data-architecture.md#data-flow-architecture)
- [Application Architecture](../03-application-architecture.md#communication-patterns)

---

[← ADR-001](ADR-001-aspire-orchestration.md) | [ADR Index](README.md) | [Next: ADR-003 →](ADR-003-observability-strategy.md)
