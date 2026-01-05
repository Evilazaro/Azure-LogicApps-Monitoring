# ADR-003: OpenTelemetry for Observability Strategy

## Status

**Accepted** - January 2024

## Context

The eShop Orders Management solution is a distributed system with multiple services communicating via HTTP and Service Bus. Effective observability is critical for:

- Understanding request flow across services
- Diagnosing performance issues
- Monitoring business metrics
- Alerting on failures

### Requirements

| Requirement             | Priority | Description                                    |
| ----------------------- | -------- | ---------------------------------------------- |
| **Distributed Tracing** | High     | Correlate requests across services             |
| **Custom Metrics**      | High     | Business-level metrics (orders placed, errors) |
| **Centralized Logging** | High     | Aggregated logs with correlation               |
| **Azure Integration**   | High     | Native Azure Monitor compatibility             |
| **Vendor Neutrality**   | Medium   | Avoid lock-in to specific APM tool             |
| **Low Overhead**        | Medium   | Minimal performance impact                     |

### Options Considered

| Option                                 | Pros                                           | Cons                            |
| -------------------------------------- | ---------------------------------------------- | ------------------------------- |
| **OpenTelemetry + Azure Monitor**      | Vendor-neutral, .NET native, Azure integration | Configuration complexity        |
| **Application Insights SDK (classic)** | Simple setup, full Azure features              | Vendor lock-in, deprecated path |
| **Prometheus + Grafana**               | Open source, powerful                          | Self-hosted infrastructure      |
| **Datadog/New Relic**                  | Feature-rich APM                               | Cost, external dependency       |

## Decision

We will use **OpenTelemetry** for instrumentation with **Azure Monitor** (Application Insights + Log Analytics) as the telemetry backend.

### Three Pillars Implementation

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenTelemetry SDK                        │
├─────────────────┬─────────────────┬─────────────────────────┤
│     Traces      │     Metrics     │        Logs             │
│  ActivitySource │     Meter       │   ILogger<T>            │
└────────┬────────┴────────┬────────┴───────────┬─────────────┘
         │                 │                    │
         └─────────────────┴────────────────────┘
                           │
                    Azure Monitor Exporter
                           │
         ┌─────────────────┴────────────────────┐
         │           Azure Monitor              │
         ├─────────────────┬────────────────────┤
         │ Application     │   Log Analytics    │
         │ Insights        │   Workspace        │
         └─────────────────┴────────────────────┘
```

### Implementation

**SDK Configuration:** [app.ServiceDefaults/Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)

```csharp
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics =>
    {
        metrics.AddAspNetCoreInstrumentation()
               .AddHttpClientInstrumentation()
               .AddRuntimeInstrumentation()
               .AddMeter("eShop.orders");  // Custom business metrics
    })
    .WithTracing(tracing =>
    {
        tracing.AddSource("eShop.orders")  // Custom activity source
               .AddAspNetCoreInstrumentation()
               .AddGrpcClientInstrumentation()
               .AddHttpClientInstrumentation()
               .AddSqlClientInstrumentation(options =>
                   options.SetDbStatementForText = true);
    });

// Azure Monitor exporter
builder.Services.AddOpenTelemetry()
    .UseAzureMonitor(options =>
    {
        options.ConnectionString = config["APPLICATIONINSIGHTS_CONNECTION_STRING"];
    });
```

**Custom Metrics:** [src/eShop.Orders.API/Services/OrderService.cs](../../../src/eShop.Orders.API/Services/OrderService.cs)

```csharp
private static readonly Meter Meter = new("eShop.orders", "1.0.0");

private static readonly Counter<long> OrdersPlacedCounter =
    Meter.CreateCounter<long>("eShop.orders.placed", "{orders}");

private static readonly Histogram<double> ProcessingDuration =
    Meter.CreateHistogram<double>("eShop.orders.processing.duration", "ms");

private static readonly Counter<long> ProcessingErrors =
    Meter.CreateCounter<long>("eShop.orders.processing.errors", "{errors}");
```

**Custom Traces:** [src/eShop.Orders.API/Controllers/OrdersController.cs](../../../src/eShop.Orders.API/Controllers/OrdersController.cs)

```csharp
private static readonly ActivitySource ActivitySource = new("eShop.orders");

[HttpPost]
public async Task<IActionResult> PlaceOrder([FromBody] Order order)
{
    using var activity = ActivitySource.StartActivity("PlaceOrder", ActivityKind.Server);
    activity?.SetTag("order.customer_id", order.CustomerId);
    activity?.SetTag("order.product_count", order.Products?.Count ?? 0);

    // ... processing

    activity?.SetTag("order.id", result.Id);
    activity?.SetStatus(ActivityStatusCode.Ok);
}
```

**Trace Context Propagation:** [src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)

```csharp
// Propagate W3C Trace Context to Service Bus messages
if (Activity.Current != null)
{
    message.ApplicationProperties["traceparent"] = Activity.Current.Id;
    if (!string.IsNullOrEmpty(Activity.Current.TraceStateString))
    {
        message.ApplicationProperties["tracestate"] = Activity.Current.TraceStateString;
    }
}
```

## Consequences

### Positive

1. **Vendor Neutrality** - OpenTelemetry is CNCF standard; backend can be changed
2. **Native .NET Integration** - First-class support in .NET 8+ and Aspire
3. **Automatic Instrumentation** - ASP.NET Core, HTTP, SQL auto-instrumented
4. **End-to-End Tracing** - Traces flow across HTTP and Service Bus boundaries
5. **Custom Metrics** - Business-level metrics alongside infrastructure metrics
6. **Azure Monitor Integration** - Full Application Insights features available
7. **Local Development** - .NET Aspire dashboard shows telemetry locally

### Negative

1. **Configuration Complexity** - Multiple configuration points for full setup
2. **Azure Dependency** - Azure Monitor exporter requires Azure subscription
3. **Learning Curve** - Team must understand OpenTelemetry concepts
4. **Limited Logic Apps Correlation** - Logic Apps has separate telemetry path

### Neutral

1. **Sampling** - May need to configure sampling for high-volume production
2. **Cost** - Azure Monitor ingestion costs scale with telemetry volume
3. **Retention** - Log Analytics retention policies need configuration

## Metrics Inventory

| Metric                             | Type      | Unit     | Source       |
| ---------------------------------- | --------- | -------- | ------------ |
| `eShop.orders.placed`              | Counter   | {orders} | OrderService |
| `eShop.orders.processing.duration` | Histogram | ms       | OrderService |
| `eShop.orders.processing.errors`   | Counter   | {errors} | OrderService |
| `http.server.request.duration`     | Histogram | ms       | Auto         |
| `http.client.request.duration`     | Histogram | ms       | Auto         |
| `db.client.operation.duration`     | Histogram | ms       | Auto         |

## Trace Sources

| Source                     | Kind   | Tags                                      |
| -------------------------- | ------ | ----------------------------------------- |
| `eShop.orders`             | Custom | order.id, customer_id, product_count      |
| `Microsoft.AspNetCore`     | Auto   | http.method, http.route, http.status_code |
| `System.Net.Http`          | Auto   | http.url, http.method                     |
| `Microsoft.Data.SqlClient` | Auto   | db.statement, db.name                     |

## Dashboard Capabilities

### Application Insights

- **Application Map** - Service dependency visualization
- **Transaction Search** - End-to-end trace exploration
- **Failures** - Error analysis with stack traces
- **Performance** - Latency distributions and dependencies
- **Live Metrics** - Real-time telemetry stream

### Log Analytics

- **KQL Queries** - Advanced log analysis
- **Workbooks** - Custom dashboards
- **Alerts** - Metric and log-based alerting

---

## Related Decisions

- [ADR-001: Aspire Orchestration](ADR-001-aspire-orchestration.md) - Local observability via Aspire dashboard
- [ADR-002: Service Bus Messaging](ADR-002-service-bus-messaging.md) - Trace context propagation

## References

- [OpenTelemetry .NET Documentation](https://opentelemetry.io/docs/languages/net/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)
- [.NET Aspire Telemetry](https://learn.microsoft.com/dotnet/aspire/fundamentals/telemetry)

---

<div align="center">

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**

[⬆ Back to Top](#adr-003-opentelemetry-for-observability-strategy)

</div>
