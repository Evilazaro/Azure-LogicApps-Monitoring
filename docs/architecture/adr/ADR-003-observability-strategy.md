# ADR-003: Use OpenTelemetry with Application Insights for Observability

## Status

**Accepted** - January 2025

---

## Context

The distributed nature of the solution (Web App → API → Service Bus → Logic Apps) requires comprehensive observability to:

1. **Debug distributed transactions** - Trace requests across service boundaries
2. **Monitor application health** - Track errors, latency, and throughput
3. **Business intelligence** - Measure order volumes, processing times
4. **Alerting** - Proactive notification of issues
5. **Capacity planning** - Understand resource utilization

### Requirements

| Requirement | Priority | Notes |
|-------------|----------|-------|
| Distributed tracing | Must | End-to-end request correlation |
| Custom metrics | Must | Business-specific measurements |
| Structured logging | Must | Queryable, contextual logs |
| Azure integration | Should | Native dashboard, alerts |
| Vendor neutrality | Should | Avoid lock-in to single vendor |
| Low overhead | Must | Minimal performance impact |

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **OpenTelemetry + App Insights** | Vendor-neutral, comprehensive, Azure-native export | Learning curve |
| **Application Insights SDK only** | Simple setup, deep Azure integration | Microsoft-specific |
| **Jaeger + Prometheus** | Open source, no cost | Operational overhead, self-hosted |
| **Datadog/New Relic** | Full-featured APM | Cost, third-party dependency |
| **Elastic APM** | Open source option | Operational complexity |

---

## Decision

We will use **OpenTelemetry SDK** for instrumentation with **Azure Application Insights** as the telemetry backend.

### Key Implementation

**OpenTelemetry Configuration** ([Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)):

```csharp
private static IHostApplicationBuilder ConfigureOpenTelemetry(this IHostApplicationBuilder builder)
{
    builder.Logging.AddOpenTelemetry(logging =>
    {
        logging.IncludeFormattedMessage = true;
        logging.IncludeScopes = true;
    });

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
                   .AddAspNetCoreInstrumentation()
                   .AddHttpClientInstrumentation();
        });

    builder.AddOpenTelemetryExporters();
    return builder;
}

private static IHostApplicationBuilder AddOpenTelemetryExporters(this IHostApplicationBuilder builder)
{
    var useOtlpExporter = !string.IsNullOrWhiteSpace(
        builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]);

    if (useOtlpExporter)
    {
        builder.Services.AddOpenTelemetry().UseOtlpExporter();
    }

    return builder;
}
```

**Custom Business Metrics** ([OrderService.cs](../../../src/eShop.Orders.API/Services/OrderService.cs)):

```csharp
private readonly Counter<long> _ordersPlacedCounter;
private readonly Histogram<double> _processingDuration;
private readonly Counter<long> _processingErrors;
private readonly Counter<long> _ordersDeletedCounter;

public OrderService(IMeterFactory meterFactory, ...)
{
    var meter = meterFactory.Create("eShop.Orders");
    
    _ordersPlacedCounter = meter.CreateCounter<long>(
        "eShop.orders.placed", "count", "Total orders placed");
    
    _processingDuration = meter.CreateHistogram<double>(
        "eShop.orders.processing.duration", "ms", "Processing duration");
    
    _processingErrors = meter.CreateCounter<long>(
        "eShop.orders.processing.errors", "count", "Processing errors");
    
    _ordersDeletedCounter = meter.CreateCounter<long>(
        "eShop.orders.deleted", "count", "Orders deleted");
}

// Usage in PlaceOrderAsync:
_ordersPlacedCounter.Add(1);
_processingDuration.Record(elapsed.TotalMilliseconds);
```

**Trace Context Propagation** ([OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)):

```csharp
using var activity = _activitySource.StartActivity(
    $"ServiceBus.{topicName}.Send", 
    ActivityKind.Producer);

if (activity != null)
{
    message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
    message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();
    message.ApplicationProperties["traceparent"] = activity.Id ?? string.Empty;
}
```

### Three Pillars Implementation

| Pillar | Technology | Configuration |
|--------|------------|---------------|
| **Traces** | OpenTelemetry Tracing | ASP.NET Core, HttpClient, custom ActivitySource |
| **Metrics** | OpenTelemetry Metrics | Runtime, HTTP, custom Meter |
| **Logs** | OpenTelemetry Logging | Structured with trace correlation |

---

## Consequences

### Positive

1. **Vendor neutrality**
   - OpenTelemetry is CNCF standard
   - Can switch backends (Jaeger, Zipkin, etc.) without code changes
   - Future-proof investment

2. **Comprehensive visibility**
   - Automatic instrumentation for HTTP, database
   - Custom business metrics with `eShop.*` namespace
   - Correlated logs with TraceId/SpanId

3. **Azure-native integration**
   - Application Insights backend handles collection, storage, analysis
   - Seamless Azure Monitor integration
   - Built-in dashboards (Application Map, Transaction Search)

4. **Local development experience**
   - .NET Aspire Dashboard shows traces, logs, metrics locally
   - Same instrumentation works in cloud and local
   - Immediate feedback during development

5. **End-to-end distributed tracing**
   - W3C Trace Context propagation
   - Cross-service correlation (HTTP, Service Bus)
   - Single TraceId across entire request flow

### Negative

1. **Complexity**
   - OpenTelemetry has many configuration options
   - **Mitigation**: ServiceDefaults encapsulates configuration

2. **SDK overhead**
   - Instrumentation adds some CPU/memory overhead
   - **Mitigation**: Sampling, appropriate instrumentation scope

3. **Data volume**
   - High traffic generates significant telemetry
   - **Mitigation**: Sampling policies, retention management

### Neutral

1. **Learning curve** - Team needs OpenTelemetry concepts
2. **Two technologies** - OpenTelemetry SDK + Application Insights backend
3. **Export latency** - Small delay before data appears in portal

---

## Telemetry Summary

### Metrics Emitted

| Metric | Type | Source |
|--------|------|--------|
| `http.server.request.duration` | Histogram | Auto (ASP.NET Core) |
| `http.client.request.duration` | Histogram | Auto (HttpClient) |
| `eShop.orders.placed` | Counter | Custom |
| `eShop.orders.processing.duration` | Histogram | Custom |
| `eShop.orders.processing.errors` | Counter | Custom |
| `eShop.orders.deleted` | Counter | Custom |

### Trace Spans

| Span | Kind | Source |
|------|------|--------|
| HTTP Server Request | Server | Auto |
| HTTP Client Request | Client | Auto |
| SQL Query | Client | Auto (with EF Core) |
| ServiceBus.Send | Producer | Custom |

---

## Related Decisions

- [ADR-001](ADR-001-aspire-orchestration.md) - Aspire provides local dashboard and OTLP configuration
- [ADR-002](ADR-002-service-bus-messaging.md) - Trace context propagated in Service Bus messages

---

## References

- [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/dotnet/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)
- [ServiceDefaults Implementation](../../../app.ServiceDefaults/Extensions.cs)
- [Custom Metrics Implementation](../../../src/eShop.Orders.API/Services/OrderService.cs)
- [Trace Propagation Implementation](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)
