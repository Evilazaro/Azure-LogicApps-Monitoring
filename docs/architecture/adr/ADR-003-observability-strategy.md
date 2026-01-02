# ADR-003: OpenTelemetry-Based Observability Strategy

## Status
**Accepted** - January 2024

## Context

The eShop Azure Platform requires comprehensive observability to:
- **Debug distributed transactions** - Trace requests across Web App, API, Service Bus, Logic Apps
- **Monitor performance** - Track latency, throughput, error rates
- **Alert on issues** - Proactive notification of degraded service
- **Analyze trends** - Capacity planning and optimization

Key requirements:
1. **Vendor-neutral instrumentation** - Avoid lock-in to specific APM vendor
2. **Automatic instrumentation** - Minimal code changes for standard scenarios
3. **Custom metrics** - Business-specific measurements (orders placed, processing time)
4. **Distributed tracing** - End-to-end correlation across service boundaries
5. **Azure integration** - Native support for Azure Monitor and Application Insights

## Decision

**Implement observability using OpenTelemetry SDK with Azure Monitor/Application Insights as the backend.**

### Implementation

1. **Three Pillars Coverage**
   
   | Pillar | Implementation | Export Target |
   |--------|---------------|---------------|
   | **Traces** | OpenTelemetry SDK + Auto-instrumentation | Application Insights |
   | **Metrics** | OpenTelemetry Meters + Custom counters | Azure Monitor Metrics |
   | **Logs** | ILogger + OpenTelemetry Log Provider | Log Analytics |

2. **Instrumentation Configuration**
   ```csharp
   // Extensions.cs - ConfigureOpenTelemetry()
   builder.Services.AddOpenTelemetry()
       .WithMetrics(metrics =>
       {
           metrics.AddAspNetCoreInstrumentation()
               .AddHttpClientInstrumentation()
               .AddRuntimeInstrumentation();
       })
       .WithTracing(tracing =>
       {
           tracing.AddSource(builder.Environment.ApplicationName)
               .AddAspNetCoreInstrumentation(options => 
                   options.RecordException = true)
               .AddHttpClientInstrumentation()
               .AddSqlClientInstrumentation(options =>
               {
                   options.SetDbStatementForText = true;
                   options.RecordException = true;
               });
       });
   ```

3. **Custom Business Metrics**
   ```csharp
   // OrderService.cs
   private static readonly Meter Meter = new("eShop.Orders.API", "1.0.0");
   private static readonly Counter<long> OrdersPlacedCounter = 
       Meter.CreateCounter<long>("eShop.orders.placed");
   private static readonly Histogram<double> ProcessingDuration = 
       Meter.CreateHistogram<double>("eShop.orders.processing.duration");
   ```

4. **Distributed Trace Context Propagation**
   ```csharp
   // OrdersMessageHandler.cs - Service Bus message publishing
   if (Activity.Current != null)
   {
       message.ApplicationProperties["TraceId"] = Activity.Current.TraceId.ToString();
       message.ApplicationProperties["SpanId"] = Activity.Current.SpanId.ToString();
       message.ApplicationProperties["traceparent"] = Activity.Current.Id;
   }
   ```

### Telemetry Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  Web App    │────▶│  Orders API │────▶│ Service Bus │────▶│ Logic Apps  │
│             │     │             │     │             │     │             │
│  TraceId: A │     │  TraceId: A │     │  TraceId: A │     │  TraceId: A │
│  SpanId: 1  │     │  SpanId: 2  │     │  (property) │     │  RunId: X   │
└──────┬──────┘     └──────┬──────┘     └─────────────┘     └──────┬──────┘
       │                   │                                        │
       │                   │                                        │
       ▼                   ▼                                        ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                       Application Insights                              │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  Transaction Search: TraceId = A                                 │   │
│  │  ├─ Request: POST /api/orders (SpanId: 1)                       │   │
│  │  │   └─ Dependency: HTTP POST api/orders (SpanId: 2)            │   │
│  │  │       ├─ Dependency: SQL INSERT (SpanId: 3)                  │   │
│  │  │       └─ Dependency: Service Bus Send (SpanId: 4)            │   │
│  │  └─ (Correlated) Logic App Run: X                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

## Consequences

### Positive

| Benefit | Impact |
|---------|--------|
| **Vendor neutrality** | Can switch to Jaeger, Zipkin, Datadog with config change |
| **Automatic instrumentation** | HTTP, SQL, Runtime metrics out-of-the-box |
| **End-to-end tracing** | Single TraceId across all services |
| **Rich Azure integration** | Application Map, Transaction Search, Live Metrics |
| **Custom metrics support** | Business KPIs alongside infrastructure metrics |
| **Structured logging** | Context (TraceId, SpanId) automatically included |
| **Industry standard** | CNCF project, wide community support |

### Negative

| Tradeoff | Mitigation |
|----------|------------|
| **Learning curve** | Well-documented patterns in ServiceDefaults |
| **SDK overhead** | Minimal (<1% CPU), sampling available for high-volume |
| **Azure Monitor cost** | Configure retention, sampling, data caps |
| **Trace context propagation** | Manual for non-HTTP protocols (Service Bus) |
| **Logic Apps correlation** | Relies on workflow run ID, not direct OTEL |

### Neutral

- Application Insights samples at 100% by default (adjustable)
- Log Analytics retention is 30 days by default (configurable)
- Custom metrics count toward Azure Monitor limits

## Alternatives Considered

### 1. Application Insights SDK Only (Classic)
- **Pros:** Native Azure, automatic Azure correlation
- **Cons:** Vendor lock-in, no standard API
- **Rejected because:** OpenTelemetry provides portability with same Azure features

### 2. Prometheus + Grafana
- **Pros:** Open source, flexible dashboards, wide adoption
- **Cons:** Operational overhead, separate deployment, no native tracing
- **Rejected because:** Requires additional infrastructure management

### 3. Jaeger for Tracing + Prometheus for Metrics
- **Pros:** Open source, CNCF projects, detailed tracing
- **Cons:** Multiple systems, no unified view, operational complexity
- **Rejected because:** Application Insights provides unified experience

### 4. Datadog / New Relic (Commercial APM)
- **Pros:** Rich features, unified platform, excellent UX
- **Cons:** Cost at scale, another vendor relationship, data egress
- **Rejected because:** Azure Monitor sufficient for requirements, no additional vendor

### 5. Minimal Logging Only
- **Pros:** Simple, low overhead
- **Cons:** No tracing, no metrics, reactive debugging only
- **Rejected because:** Does not meet observability requirements for distributed systems

## Metrics Catalog

| Metric | Type | Description | Source |
|--------|------|-------------|--------|
| `http.server.request.duration` | Histogram | HTTP request latency | OTEL Auto |
| `http.server.active_requests` | UpDownCounter | Concurrent requests | OTEL Auto |
| `db.client.operation.duration` | Histogram | Database query time | OTEL Auto |
| `eShop.orders.placed` | Counter | Orders created | Custom |
| `eShop.orders.deleted` | Counter | Orders deleted | Custom |
| `eShop.orders.processing.duration` | Histogram | Processing time | Custom |

## References

- [OpenTelemetry .NET Documentation](https://opentelemetry.io/docs/instrumentation/net/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)
- [W3C Trace Context Specification](https://www.w3.org/TR/trace-context/)
- [Observability Architecture](../05-observability-architecture.md)
- [Data Architecture - Telemetry Mapping](../02-data-architecture.md#telemetry-data-mapping)

---

[← ADR-002](ADR-002-service-bus-messaging.md) | [ADR Index](README.md) | [Next: ADR-004 →](ADR-004-managed-identity.md)
