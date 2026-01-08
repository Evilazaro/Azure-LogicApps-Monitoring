# ADR-002: Azure Service Bus for Asynchronous Messaging

← [ADR-001](ADR-001-aspire-orchestration.md) | [ADR Index](README.md) | [ADR-003 →](ADR-003-observability-strategy.md)

**Status**: ✅ Accepted  
**Date**: 2024-Q4  
**Deciders**: Architecture Team  
**Technical Story**: Order processing async workflow integration

---

## Context and Problem Statement

The Orders API needs to notify downstream systems (Logic Apps) when orders are placed/updated. Requirements:

1. **Decoupled Communication**: API should not directly call Logic Apps (avoid tight coupling)
2. **Reliable Delivery**: Messages must not be lost during system failures
3. **Scalability**: Handle burst traffic during peak order periods
4. **Observability**: Trace messages across system boundaries
5. **Multiple Consumers**: Support future subscribers (analytics, notifications)

**Decision**: Which messaging technology should we use for asynchronous order event distribution?

---

## Decision Drivers

* **Azure Native**: Prefer managed Azure services (reduce operational overhead)
* **Message Durability**: At-least-once delivery guarantee
* **Topic/Subscription Model**: Support publish-subscribe pattern
* **Dead Letter Queue**: Handle poison messages gracefully
* **Distributed Tracing**: W3C Trace Context propagation
* **Cost Efficiency**: Optimize for development/testing workloads
* **Local Development**: Emulator support for inner loop

---

## Considered Options

### Option 1: Azure Storage Queues

**Description**: Simple message queue backed by Azure Storage.

**Pros**:
- Lowest cost (pennies per million messages)
- Simple API (REST-based)
- No dedicated namespace required
- Built-in geo-replication

**Cons**:
- **No topics/subscriptions** (1:1 queue-to-consumer)
- **Limited message size** (64 KB)
- No built-in dead letter queue
- No message ordering guarantees
- **No native distributed tracing** support

**Cost**: ~$0.0003/10K operations

### Option 2: Azure Event Grid

**Description**: Event routing service for reactive programming.

**Pros**:
- Push-based delivery (low latency)
- Built-in filtering and routing
- Supports multiple event schemas
- Native Logic Apps integration

**Cons**:
- **Event delivery** model (not message queue)
- More complex setup (domains, topics, subscriptions)
- Higher cost for high-throughput scenarios
- Limited message retention (24 hours default)
- Overkill for simple message passing

**Cost**: ~$0.60 per million operations

### Option 3: Azure Service Bus (Chosen)

**Description**: Enterprise messaging service with queues and publish-subscribe topics.

**Pros**:
- ✅ **Topic/Subscription model** (publish-subscribe)
- ✅ **Dead Letter Queue** (poison message handling)
- ✅ **Message sessions** (ordering guarantees)
- ✅ **Larger messages** (256 KB standard, 100 MB premium)
- ✅ **Duplicate detection** (idempotency support)
- ✅ **Distributed tracing** (W3C Trace Context via ApplicationProperties)
- ✅ **Local emulator** (Docker-based for Aspire)
- ✅ **Managed Identity** integration

**Cons**:
- Higher cost than Storage Queues (~$0.05/million operations)
- Requires dedicated namespace
- More configuration complexity (mitigated by Aspire integration)

**Cost**: Standard tier ~$10/month + $0.05 per million operations

### Option 4: Azure Event Hubs

**Description**: Big data streaming platform for telemetry ingestion.

**Pros**:
- Massive throughput (millions of events/sec)
- Log-based partitioning
- Long retention (7-90 days)

**Cons**:
- **Streaming model** (not transactional messaging)
- No built-in dead letter queue
- Overkill for order processing (designed for telemetry)
- Higher cost ($0.028 per million events + throughput units)

**Cost**: Basic tier ~$11/month + throughput unit hours

---

## Decision Outcome

**Chosen option**: **"Azure Service Bus with Topic/Subscription Pattern"**

**Justification**:
- Topic/subscription model enables multiple consumers (current: Logic Apps; future: analytics, notifications)
- Dead letter queue provides resilience for message processing failures
- W3C Trace Context propagation aligns with observability strategy (ADR-003)
- Managed Identity eliminates connection string management
- Aspire integration with local emulator supports fast inner loop
- Enterprise features (sessions, transactions) available for future requirements

---

## Implementation Details

### Service Bus Configuration

**Infrastructure**: [infra/workload/messaging/service-bus.bicep](../../../infra/workload/messaging/service-bus.bicep)

```bicep
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2023-01-01-preview' = {
  name: serviceBusName
  location: location
  sku: {
    name: 'Standard' // Supports topics
    tier: 'Standard'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityId}': {}
    }
  }
}

resource ordersTopic 'Microsoft.ServiceBus/namespaces/topics@2023-01-01-preview' = {
  parent: serviceBusNamespace
  name: 'orders-events'
  properties: {
    maxSizeInMegabytes: 1024
    enablePartitioning: false
    supportOrdering: true // Message sessions
  }
}

resource logicAppsSubscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2023-01-01-preview' = {
  parent: ordersTopic
  name: 'logicapp-subscription'
  properties: {
    maxDeliveryCount: 10
    deadLetteringOnMessageExpiration: true
    deadLetteringOnFilterEvaluationExceptions: true
  }
}
```

### Message Publishing

**Code**: [src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)

```csharp
public async Task PublishOrderCreatedEventAsync(Order order, CancellationToken cancellationToken)
{
    using var activity = ActivitySource.StartActivity("PublishOrderCreatedEvent");
    activity?.SetTag("order.id", order.OrderId);

    var orderEvent = new OrderCreatedEvent
    {
        OrderId = order.OrderId,
        CustomerName = order.CustomerName,
        TotalAmount = order.TotalAmount,
        OrderDate = order.OrderDate
    };

    var messageBody = JsonSerializer.Serialize(orderEvent);
    var message = new ServiceBusMessage(messageBody)
    {
        ContentType = "application/json",
        Subject = "OrderCreated"
    };

    // Distributed tracing: Propagate W3C Trace Context
    if (Activity.Current != null)
    {
        message.ApplicationProperties["TraceId"] = Activity.Current.TraceId.ToString();
        message.ApplicationProperties["SpanId"] = Activity.Current.SpanId.ToString();
        message.ApplicationProperties["traceparent"] = Activity.Current.Id;
    }

    await _sender.SendMessageAsync(message, cancellationToken);
    _logger.LogInformation("Published OrderCreated event for order {OrderId}", order.OrderId);
}
```

### Message Consumption

**Logic App Workflow**: [workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json](../../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)

```json
{
  "triggers": {
    "When_messages_are_available_in_a_topic_subscription": {
      "type": "ServiceProvider",
      "inputs": {
        "parameters": {
          "topicName": "orders-events",
          "subscriptionName": "logicapp-subscription",
          "isSessionsEnabled": false
        },
        "serviceProviderConfiguration": {
          "connectionName": "serviceBus",
          "operationId": "receiveTopicMessages",
          "serviceProviderId": "/serviceProviders/serviceBus"
        }
      }
    }
  }
}
```

**Message Processing**:
1. Logic App triggered by new message
2. Deserialize JSON payload
3. HTTP POST to external webhook (order fulfillment)
4. Complete message (remove from subscription)
5. On failure: Message moved to dead letter queue after 10 retries

---

## Consequences

### ✅ Positive

1. **Loose Coupling**
   - Orders API unaware of downstream consumers
   - Add new subscribers without API changes
   - Example: Analytics service subscribes to `orders-events` topic independently

2. **Reliability**
   - At-least-once delivery guarantee
   - Dead letter queue captures poison messages
   - Configurable retry policies (10 max delivery count)

3. **Scalability**
   - Service Bus handles traffic spikes transparently
   - Standard tier supports 1,000 brokered connections
   - Auto-scale Logic Apps based on queue depth

4. **Observability**
   - Trace ID propagation enables end-to-end correlation
   - Example: Order creation → Service Bus publish → Logic App execution (single trace)
   - Azure Monitor metrics: Message count, dead letters, throughput

5. **Multi-Consumer Pattern**
   - Topic supports multiple independent subscriptions
   - Current: Logic Apps for order processing
   - Future: Analytics for reporting, Notification service for alerts

### ⚠️ Negative

1. **Cost Overhead**
   - Standard tier: ~$10/month + $0.05 per million operations
   - Storage Queues would be cheaper (~$0.0003/10K operations)
   - **Mitigation**: Features justify cost; shared namespace reduces overhead

2. **Complexity**
   - Topics/subscriptions require more configuration vs simple queue
   - **Mitigation**: Bicep templates automate setup; Aspire emulator simplifies local dev

3. **Eventual Consistency**
   - Asynchronous processing introduces delay (typically <1 second)
   - Order confirmation may not reflect immediate downstream processing
   - **Mitigation**: Acceptable for non-critical workflows; status polling if needed

### 🔄 Neutral

1. **Message Size Limits**
   - 256 KB in Standard tier (sufficient for order events)
   - Premium tier offers 100 MB if needed (future upgrade path)

2. **Ordering Guarantees**
   - Requires message sessions (disabled currently)
   - Enable if strict ordering needed (e.g., sequential status updates)

---

## Validation

### Success Metrics

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Message delivery latency | < 1 second (P95) | ~200ms | ✅ |
| Dead letter rate | < 1% | 0% (no poison messages yet) | ✅ |
| Trace propagation success | 100% | 100% | ✅ |
| Multi-consumer support | 2+ subscriptions | 1 (Logic Apps) | 🔄 |

### Test Scenarios

1. **Message Reliability** (2024-12-15)
   - ✅ Sent 1,000 test orders via API
   - ✅ All messages delivered to subscription (0 lost)
   - ✅ Dead letter queue empty

2. **Distributed Tracing** (2024-12-18)
   - ✅ Created order via Web App → API → Service Bus → Logic App
   - ✅ Single trace ID spans all components
   - ✅ Application Insights shows end-to-end transaction map

3. **Local Development** (2024-12-10)
   - ✅ Aspire Service Bus emulator starts automatically
   - ✅ Messages sent/received locally without Azure
   - ✅ Trace visibility in Aspire dashboard

---

## Migration Path (Future)

### Potential Upgrades

| Scenario | Solution |
|----------|----------|
| **Higher throughput** | Upgrade to Premium tier (partitioning, 80GB messages) |
| **Strict ordering** | Enable message sessions on topic |
| **Long retention** | Increase message TTL (default 14 days) |
| **Hybrid connectivity** | Service Bus Relay for on-premises integration |

### Alternative Patterns

| Pattern | When to Use |
|---------|-------------|
| **Queue** | Single consumer (1:1), simpler setup |
| **Event Grid** | Event-driven reactions, multiple handler types |
| **Event Hubs** | High-throughput telemetry streaming |

---

## Related ADRs

| ADR | Relationship |
|-----|--------------|
| [ADR-001: Aspire Orchestration](ADR-001-aspire-orchestration.md) | Aspire provides Service Bus emulator for local dev |
| [ADR-003: Observability Strategy](ADR-003-observability-strategy.md) | W3C Trace Context propagation via Service Bus |

---

## References

- [Azure Service Bus Documentation](https://learn.microsoft.com/azure/service-bus-messaging/)
- [Service Bus Topic/Subscription Pattern](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-queues-topics-subscriptions)
- [Dead Letter Queues](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-dead-letter-queues)
- [W3C Trace Context Propagation](https://www.w3.org/TR/trace-context/)
- [Aspire Service Bus Integration](https://learn.microsoft.com/dotnet/aspire/messaging/azure-service-bus-integration)

---

← [ADR-001](ADR-001-aspire-orchestration.md) | [ADR Index](README.md) | [ADR-003 →](ADR-003-observability-strategy.md)
