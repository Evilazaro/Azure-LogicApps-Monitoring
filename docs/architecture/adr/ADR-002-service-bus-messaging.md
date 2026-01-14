# ADR-002: Azure Service Bus for Asynchronous Messaging

[← ADR Index](README.md)

---

## Status

**Accepted** - January 2025

---

## Context

The eShop Orders system needs to communicate order events between services:

- Orders API creates orders and publishes events
- Logic Apps subscribes to process orders asynchronously
- Multiple subscribers may need the same events in the future

### Requirements

| Requirement             | Priority | Notes                                       |
| ----------------------- | -------- | ------------------------------------------- |
| Asynchronous processing | High     | Decouple order creation from processing     |
| Reliable delivery       | High     | Orders must not be lost                     |
| Multiple subscribers    | High     | Logic Apps, future analytics                |
| Azure native            | High     | Integration with Container Apps, Logic Apps |
| Message ordering        | Medium   | Per-order sequence preservation             |
| Distributed tracing     | Medium   | Correlation across services                 |

### Current Flow

1. User places order via Web App
2. Web App calls Orders API
3. Orders API persists to SQL Database
4. Orders API publishes event to messaging system
5. Logic App receives event and processes order
6. Logic App stores result in blob storage

---

## Decision

We will use **Azure Service Bus Topics** for asynchronous order event messaging.

### Implementation

#### Topic Structure

```
Service Bus Namespace: sb-orders-{env}
├── Topic: orders-placed
│   ├── Subscription: logic-app-processor
│   └── Subscription: (future) analytics
└── Topic: (future) orders-completed
```

#### Publishing Messages

```csharp
// src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs
public async Task PublishOrderPlacedAsync(Order order)
{
    var message = new ServiceBusMessage(JsonSerializer.Serialize(order))
    {
        ContentType = "application/json",
        Subject = "order-placed",
        CorrelationId = Activity.Current?.TraceId.ToString()
    };

    // Propagate W3C trace context
    if (Activity.Current != null)
    {
        message.ApplicationProperties["traceparent"] =
            $"00-{Activity.Current.TraceId}-{Activity.Current.SpanId}-01";
    }

    await _sender.SendMessageAsync(message);
}
```

#### Receiving Messages (Logic App)

```json
{
  "triggers": {
    "When_a_message_is_received_in_a_topic_subscription": {
      "type": "ServiceBus",
      "inputs": {
        "parameters": {
          "topicName": "orders-placed",
          "subscriptionName": "logic-app-processor"
        },
        "serviceProviderConfiguration": {
          "connectionName": "serviceBus"
        }
      }
    }
  }
}
```

---

## Consequences

### Benefits

| Benefit               | Description                                           |
| --------------------- | ----------------------------------------------------- |
| **Decoupling**        | Orders API doesn't wait for processing to complete    |
| **Reliability**       | At-least-once delivery with dead-letter queues        |
| **Scalability**       | Multiple subscribers without code changes             |
| **Tracing**           | W3C trace context propagation for distributed tracing |
| **Azure Integration** | Native Logic Apps Service Bus connector               |
| **Message Filtering** | Subscription filters for selective processing         |

### Drawbacks

| Drawback            | Mitigation                                      |
| ------------------- | ----------------------------------------------- |
| **Additional Cost** | Standard tier ~$10/month, acceptable            |
| **Complexity**      | Simpler than alternatives, well-documented      |
| **Latency**         | Sub-second, acceptable for async workflows      |
| **At-least-once**   | Idempotent handlers, deduplication where needed |

### Risks

| Risk                 | Probability | Impact | Mitigation                     |
| -------------------- | ----------- | ------ | ------------------------------ |
| Message loss         | Low         | High   | Dead-letter queues, monitoring |
| Duplicate processing | Medium      | Low    | Idempotent handlers            |
| Throttling           | Low         | Medium | Standard tier has high limits  |
| Region outage        | Low         | High   | Geo-DR for production          |

---

## Alternatives Considered

### 1. Azure Storage Queues

**Pros**: Simple, cheap, built-in to Azure
**Cons**: No topics/subscriptions, no message ordering, limited features
**Why Rejected**: Need pub/sub pattern for multiple subscribers

### 2. Azure Event Grid

**Pros**: Event-driven, serverless scaling, fan-out
**Cons**: At-most-once delivery, no message storage, best for events not commands
**Why Rejected**: Need reliable delivery guarantee for orders

### 3. Azure Event Hubs

**Pros**: High throughput, partitioning, long retention
**Cons**: Consumer complexity, overkill for order volume
**Why Rejected**: Event Hubs designed for streaming, not command/event messages

### 4. RabbitMQ (Self-hosted)

**Pros**: Open source, rich features, platform-agnostic
**Cons**: Operational overhead, no Logic Apps connector, self-managed
**Why Rejected**: Prefer managed service, need Logic Apps integration

### 5. Direct HTTP Calls

**Pros**: Simple, synchronous, no extra services
**Cons**: Tight coupling, no retry/resilience, blocking
**Why Rejected**: Need async processing and decoupling

### Comparison Matrix

| Criteria          | Service Bus | Storage Queue | Event Grid | Event Hubs | RabbitMQ |
| ----------------- | ----------- | ------------- | ---------- | ---------- | -------- |
| Pub/Sub           | ⭐⭐⭐      | ❌            | ⭐⭐⭐     | ⭐⭐       | ⭐⭐⭐   |
| Reliable Delivery | ⭐⭐⭐      | ⭐⭐          | ⭐         | ⭐⭐⭐     | ⭐⭐⭐   |
| Logic Apps        | ⭐⭐⭐      | ⭐⭐          | ⭐⭐⭐     | ⭐⭐       | ❌       |
| Cost              | ⭐⭐        | ⭐⭐⭐        | ⭐⭐⭐     | ⭐         | ⭐       |
| Complexity        | ⭐⭐        | ⭐⭐⭐        | ⭐⭐       | ⭐         | ⭐       |

---

## Message Schema

### Order Placed Event

```json
{
  "orderId": "string (GUID)",
  "customerId": "string (GUID)",
  "orderDate": "2025-01-15T10:30:00Z",
  "status": "Placed",
  "items": [
    {
      "productId": "string (GUID)",
      "productName": "string",
      "quantity": 1,
      "unitPrice": 29.99
    }
  ],
  "shippingAddress": {
    "street": "string",
    "city": "string",
    "state": "string",
    "postalCode": "string",
    "country": "string"
  },
  "totalAmount": 29.99
}
```

---

## References

- [Azure Service Bus Documentation](https://learn.microsoft.com/azure/service-bus-messaging/)
- [OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)
- [Logic App Workflow](../../../workflows/OrdersManagement/)
- [messaging/main.bicep](../../../infra/workload/messaging/main.bicep)

---

[← ADR Index](README.md)
