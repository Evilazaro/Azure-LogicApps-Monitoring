# ADR-003: Application Insights with OpenTelemetry for Observability

## Status

**Accepted** - December 2025

## Context

As the **primary purpose** of this solution, comprehensive observability is critical. The architecture must demonstrate best practices for:

1. **Distributed Tracing**: Correlate requests across Web App → API → Service Bus → Logic Apps
2. **Metrics Collection**: Track business KPIs (orders placed) and technical metrics (latency)
3. **Structured Logging**: Contextual logs with trace correlation
4. **Health Monitoring**: Proactive detection of service degradation
5. **Alerting**: Automated notifications for anomalies

The solution serves as a **reference implementation** for monitoring Azure Logic Apps Standard in distributed architectures.

## Decision

We adopt **Azure Application Insights** as the observability platform, instrumented via **OpenTelemetry** with the **Azure Monitor Exporter**.

### Implementation Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| Instrumentation | OpenTelemetry .NET | Vendor-neutral telemetry API |
| Export | Azure Monitor Exporter | Send data to Application Insights |
| Storage | Application Insights + Log Analytics | Telemetry retention and querying |
| Visualization | Azure Portal, Application Map | Dashboards and analysis |

### OpenTelemetry Configuration

```csharp
// From Extensions.cs
openTelemetry.WithTracing(tracing =>
{
    tracing.AddSource(builder.Environment.ApplicationName)
        .AddSource("eShop.Orders.API")
        .AddSource("eShop.Web.App")
        .AddSource("Azure.Messaging.ServiceBus")
        .AddAspNetCoreInstrumentation(options =>
        {
            options.Filter = context =>
                !context.Request.Path.StartsWithSegments("/health");
            options.RecordException = true;
        })
        .AddHttpClientInstrumentation(options => options.RecordException = true)
        .AddSqlClientInstrumentation(options => options.RecordException = true);
});

openTelemetry.WithMetrics(metrics =>
{
    metrics.AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation()
        .AddMeter("eShop.Orders.API")
        .AddMeter("eShop.Web.App");
});
```

### Azure Monitor Export

```csharp
// From Extensions.cs
var appInsightsConnectionString = builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"];
if (!string.IsNullOrEmpty(appInsightsConnectionString))
{
    openTelemetry
        .WithTracing(tracing => tracing.AddAzureMonitorTraceExporter(options =>
        {
            options.ConnectionString = appInsightsConnectionString;
        }))
        .WithMetrics(metrics => metrics.AddAzureMonitorMetricExporter(options =>
        {
            options.ConnectionString = appInsightsConnectionString;
        }));
}
```

### Trace Context Propagation to Service Bus

```csharp
// From OrdersMessageHandler.cs
message.ApplicationProperties["traceparent"] = activity.Id;
message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();
```

This ensures Logic Apps workflows appear in the same distributed trace as the originating API request.

### Custom Business Metrics

```csharp
// From OrderService.cs
private static readonly Meter Meter = new("eShop.Orders.API");
private static readonly Counter<long> OrdersPlacedCounter = Meter.CreateCounter<long>(
    "eShop.orders.placed", unit: "order");
private static readonly Histogram<double> OrderProcessingDuration = Meter.CreateHistogram<double>(
    "eShop.orders.processing.duration", unit: "ms");

// Usage
OrdersPlacedCounter.Add(1, new TagList { { "order.status", "success" } });
OrderProcessingDuration.Record(duration, new TagList { { "order.status", "success" } });
```

## Consequences

### Positive

1. **End-to-End Visibility**: Traces span UI → API → Database → Service Bus → Logic Apps
2. **Vendor Neutrality**: OpenTelemetry allows future migration to other backends
3. **Rich Auto-Instrumentation**: ASP.NET Core, HttpClient, SQL, Service Bus traced automatically
4. **Application Map**: Visual service dependency graph in Azure Portal
5. **Kusto Queries**: Powerful log analysis in Log Analytics
6. **Native Logic Apps Integration**: Application Insights connector built-in
7. **Local Development**: Aspire Dashboard for traces/metrics during development
8. **Custom Metrics**: Business KPIs alongside technical metrics

### Negative

1. **Cost**: Application Insights charges per GB ingested
2. **Sampling**: High-volume scenarios may require sampling (data loss)
3. **Learning Curve**: Kusto Query Language (KQL) for advanced analysis
4. **Latency**: Telemetry appears in portal with slight delay (~1-2 minutes)
5. **Logic Apps Gaps**: Some workflow steps may not propagate trace context fully

### Neutral

1. **Retention**: 90-day default; configurable but increases cost
2. **SDK Updates**: OpenTelemetry rapidly evolving; keep dependencies updated

## Alternatives Considered

### Application Insights SDK (Classic)

| Aspect | AI SDK | OpenTelemetry + Azure Monitor |
|--------|--------|------------------------------|
| Vendor Lock-in | Azure-specific | Vendor-neutral |
| Auto-instrumentation | Rich | Comparable |
| Future-proofing | Being deprecated | Recommended path |
| Custom Spans | Possible | Native Activity API |

**Rejected**: Microsoft recommends OpenTelemetry for new applications.

### Jaeger + Prometheus + Grafana

| Aspect | OSS Stack | Azure Application Insights |
|--------|-----------|---------------------------|
| Cost | Infrastructure cost | Pay-per-use |
| Operations | Self-managed | Fully managed |
| Azure Integration | Manual | Native |
| Logic Apps Support | Limited | Built-in |

**Rejected**: Operational overhead; weaker Logic Apps integration.

### Datadog / New Relic / Dynatrace

| Aspect | Third-Party APM | Application Insights |
|--------|-----------------|---------------------|
| Features | Rich | Sufficient |
| Cost | Higher | Lower (Azure credits) |
| Azure Integration | Via agents | Native |
| Logic Apps | Limited | Native connector |

**Rejected**: Additional vendor; cost; less native Azure/Logic Apps integration.

### Log Analytics Only (No APM)

**Rejected**: Loses distributed tracing, application map, and transaction diagnostics.

## Implementation Checklist

- [x] OpenTelemetry configured in ServiceDefaults
- [x] Azure Monitor Exporter for traces and metrics
- [x] Custom ActivitySource for business spans
- [x] Custom Meter for business metrics
- [x] Trace context propagation to Service Bus
- [x] Health check filtering (exclude from traces)
- [x] Structured logging with correlation
- [x] Logic Apps Application Insights integration
- [ ] Alerting rules configuration (manual in Azure Portal)
- [ ] Custom dashboards (manual in Azure Portal)

## References

- [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/net/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)
- [Extensions.cs](../../../app.ServiceDefaults/Extensions.cs) - Implementation
- [OrderService.cs](../../../src/eShop.Orders.API/Services/OrderService.cs) - Custom metrics
- [OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs) - Trace propagation
- [Observability Architecture](../05-observability-architecture.md) - Full details
