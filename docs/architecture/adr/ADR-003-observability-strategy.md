# ADR-003: OpenTelemetry with Azure Monitor for Observability

← [ADR-002](ADR-002-service-bus-messaging.md) | [ADR Index](README.md)

---

## 📚 Table of Contents

- [🚦 Status](#-status)
- [📝 Context](#-context)
- [✅ Decision](#-decision)
- [🎯 Consequences](#-consequences)
- [🔄 Alternatives Considered](#-alternatives-considered)
- [📊 Telemetry Inventory](#-telemetry-inventory)
- [🧪 Validation](#-validation)
- [🔗 Related ADRs](#-related-adrs)
- [📚 References](#-references)

---

## 🚦 Status

🟢 **Accepted** — January 2024

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 📝 Context

The distributed nature of the solution requires **end-to-end observability** across:

| Component   | Technology            | Telemetry Challenge       |
| ----------- | --------------------- | ------------------------- |
| Orders API  | .NET 10 Container App | Traces, metrics, logs     |
| Web App     | Blazor Server         | User interactions, errors |
| Service Bus | Azure PaaS            | Message correlation       |
| Logic Apps  | Azure PaaS            | Workflow execution        |
| Azure SQL   | Azure PaaS            | Query performance         |

**Requirements:**

1. **Distributed tracing** — Follow requests across service boundaries
2. **Correlation** — Link messages to originating API calls
3. **Metrics** — Track business and technical KPIs
4. **Logs** — Structured logging with context
5. **Dashboards** — Unified view of system health
6. **Alerts** — Proactive issue detection
7. **Cost efficiency** — Optimize telemetry ingestion

**Question:** What observability stack provides comprehensive visibility with minimal vendor lock-in?

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## ✅ Decision

**We will use OpenTelemetry SDK with Azure Monitor Exporter for telemetry collection.**

### 🛠️ Implementation

#### 📊 OpenTelemetry Configuration

From [Extensions.cs](../../../app.ServiceDefaults/Extensions.cs):

```csharp
public static IHostApplicationBuilder ConfigureOpenTelemetry(
    this IHostApplicationBuilder builder)
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

    // Azure Monitor integration
    builder.AddOpenTelemetryExporters();
}

private static IHostApplicationBuilder AddOpenTelemetryExporters(
    this IHostApplicationBuilder builder)
{
    builder.Services.AddOpenTelemetry()
           .UseAzureMonitor();  // Azure Monitor Exporter

    return builder;
}
```

#### 🔗 Trace Context Propagation

From [OrdersMessageHandler.cs](../../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs):

```csharp
// Propagate W3C Trace Context through Service Bus messages
if (Activity.Current != null)
{
    message.ApplicationProperties["traceparent"] = Activity.Current.Id;
    message.ApplicationProperties["tracestate"] = Activity.Current.TraceStateString;
}
```

#### 📊 Application Insights Integration

From [app-insights.bicep](../../../infra/shared/monitoring/app-insights.bicep):

```bicep
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
  }
}
```

### 🔑 Key Decisions

| Aspect       | Decision             | Rationale                     |
| ------------ | -------------------- | ----------------------------- |
| **SDK**      | OpenTelemetry .NET   | Vendor-neutral, CNCF standard |
| **Exporter** | Azure Monitor        | Native Azure integration      |
| **Backend**  | Application Insights | Unified Azure observability   |
| **Traces**   | W3C Trace Context    | Industry standard propagation |
| **Sampling** | Head-based (default) | Cost optimization             |

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 🎯 Consequences

### ✅ Positive

| Benefit                  | Description                                       |
| ------------------------ | ------------------------------------------------- |
| **Vendor neutrality**    | OpenTelemetry is portable to other backends       |
| **Unified telemetry**    | Traces, metrics, logs in one SDK                  |
| **Auto-instrumentation** | ASP.NET Core, HttpClient, EF Core                 |
| **Azure integration**    | Native App Insights features (Live Metrics, etc.) |
| **Cost control**         | Sampling reduces ingestion costs                  |
| **Correlation**          | W3C format works across technologies              |

### ⚠️ Negative

| Drawback                | Mitigation                           |
| ----------------------- | ------------------------------------ | --------------------------------------- |
| **Learning curve**      | OpenTelemetry concepts are new       | SDK abstracts complexity                |
| **Sampling trade-offs** | Some traces may be lost              | Configure sampling rate per environment |
| **Double telemetry**    | App Insights SDK + OTel can conflict | Use OTel-only approach                  |

### ⚖️ Neutral

- Azure Monitor Exporter is Microsoft-maintained
- Application Insights retains data for 90 days (configurable)
- Logic Apps have built-in observability separate from OTel

---

## Alternatives Considered

### Alternative 1: Application Insights SDK (Classic)

```csharp
// Classic App Insights approach
services.AddApplicationInsightsTelemetry();
```

| Criteria           | Assessment                                 |
| ------------------ | ------------------------------------------ |
| **Pros**           | Deep Azure integration, simpler setup      |
| **Cons**           | Vendor lock-in, deprecated for new apps    |
| **Why not chosen** | Microsoft recommends OTel for new projects |

### Alternative 2: Jaeger + Prometheus + ELK

| Criteria           | Assessment                              |
| ------------------ | --------------------------------------- |
| **Pros**           | Open source, self-hosted control        |
| **Cons**           | Operational overhead, multiple backends |
| **Why not chosen** | Prefer managed services                 |

### Alternative 3: Datadog / New Relic

| Criteria           | Assessment                                 |
| ------------------ | ------------------------------------------ |
| **Pros**           | Feature-rich, excellent UX                 |
| **Cons**           | Additional vendor, cost, data residency    |
| **Why not chosen** | Azure-native preferred for Azure workloads |

---

## Telemetry Inventory

### Traces Collected

| Source       | Instrumentation | Spans               |
| ------------ | --------------- | ------------------- |
| ASP.NET Core | Auto            | HTTP requests       |
| HttpClient   | Auto            | Outbound HTTP       |
| EF Core      | Auto            | SQL queries         |
| Service Bus  | Manual          | Message operations  |
| Custom       | Manual          | Business operations |

### Metrics Collected

| Category     | Metrics                        |
| ------------ | ------------------------------ |
| **Runtime**  | GC collections, thread pool    |
| **HTTP**     | Request duration, status codes |
| **Business** | Orders created, batch sizes    |

### Log Levels

| Level         | Usage                                 |
| ------------- | ------------------------------------- |
| `Trace`       | Detailed debugging (disabled in prod) |
| `Debug`       | Development diagnostics               |
| `Information` | Business events                       |
| `Warning`     | Recoverable issues                    |
| `Error`       | Failures requiring attention          |
| `Critical`    | System failures                       |

---

## Validation

The decision is validated by:

1. **End-to-end traces** — API → Service Bus → Logic Apps correlation works
2. **Live Metrics** — Real-time view in Azure portal
3. **Alerts** — Proactive notifications on degradation
4. **Cost analysis** — Sampling keeps ingestion under budget

---

## Related ADRs

- [ADR-001](ADR-001-aspire-orchestration.md) — Aspire dashboard for local observability
- [ADR-002](ADR-002-service-bus-messaging.md) — Trace context in message properties

---

## References

- [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/net/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-enable)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [Observability Architecture](../05-observability-architecture.md)

---

_Last Updated: January 2026_
