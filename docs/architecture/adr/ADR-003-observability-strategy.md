# 📊 ADR-003: OpenTelemetry + Application Insights for Observability

← [ADR-002](ADR-002-service-bus-messaging.md) | **ADR-003** | [ADR Index](README.md)

---

## 📑 Table of Contents

- [Status](#-status)
- [Date](#-date)
- [Context](#-context)
- [Decision](#-decision)
- [Consequences](#-consequences)
- [Telemetry Matrix](#-telemetry-matrix)
- [Alternatives Considered](#-alternatives-considered)
- [Correlation Strategy](#-correlation-strategy)
- [Related Decisions](#-related-decisions)
- [References](#-references)

---

## ✅ Status

✅ **Accepted**

## Date

2025-01

## Context

The Azure Logic Apps Monitoring Solution requires comprehensive observability across:

- **Orders API** (.NET Web API)
- **Web App** (.NET Blazor)
- **Logic Apps** (Azure Logic Apps Standard)
- **Infrastructure** (Service Bus, SQL Database, Container Apps)

Key requirements:

1. **Distributed Tracing**: End-to-end visibility across services and message queues
2. **Metrics Collection**: Application and business KPIs
3. **Log Aggregation**: Centralized logging with correlation
4. **Alerting**: Proactive notification of issues
5. **Dashboards**: Visual analysis and troubleshooting

### Forces

| Force                  | Direction                             |
| ---------------------- | ------------------------------------- |
| Vendor flexibility     | ↗️ Avoid observability vendor lock-in |
| Azure integration      | ↗️ Leverage native Azure tools        |
| Standards adoption     | ↗️ Industry-standard telemetry        |
| Operational simplicity | ↘️ Single platform preferred          |

---


---

## 🛠️ Decision

**Adopt OpenTelemetry SDK for instrumentation** with **Azure Monitor (Application Insights)** as the backend, providing vendor-neutral telemetry collection with Azure-native analysis capabilities.

### Implementation Architecture

```mermaid
---
title: Observability Implementation Architecture
---
flowchart TB
    %% ===== APPLICATIONS =====
    subgraph Apps["Applications"]
        API["Orders API<br/><i>OTel SDK</i>"]
        Web["Web App<br/><i>OTel SDK</i>"]
    end

    %% ===== OPENTELEMETRY LAYER =====
    subgraph OTel["OpenTelemetry Layer"]
        SDK["OTel .NET SDK"]
        Exporter["Azure Monitor<br/>Exporter"]
    end

    %% ===== AZURE MONITOR =====
    subgraph Azure["Azure Monitor"]
        AI["Application<br/>Insights"]
        LAW["Log Analytics<br/>Workspace"]
    end

    %% ===== ANALYSIS TOOLS =====
    subgraph Analysis["Analysis Tools"]
        Map["Application Map"]
        TxSearch["Transaction Search"]
        Metrics["Metrics Explorer"]
        Alerts["Alert Rules"]
    end

    %% ===== CONNECTIONS =====
    API -->|"sends telemetry"| SDK
    Web -->|"sends telemetry"| SDK
    SDK -->|"processes"| Exporter
    Exporter -->|"exports to"| AI
    AI -->|"forwards to"| LAW
    AI -->|"powers"| Map
    AI -->|"powers"| TxSearch
    AI -->|"powers"| Metrics
    LAW -->|"triggers"| Alerts

    %% ===== STYLES - NODE CLASSES =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF

    %% ===== CLASS ASSIGNMENTS =====
    class API,Web primary
    class SDK,Exporter secondary
    class AI,LAW datastore
    class Map,TxSearch,Metrics,Alerts external

    %% ===== SUBGRAPH STYLES =====
    style Apps fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style OTel fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style Azure fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style Analysis fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
```

### Implementation Details

1. **OpenTelemetry Configuration** (`Extensions.cs`):

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
                   .AddRuntimeInstrumentation()
                   .AddMeter("eShop.Orders.API");
        })
        .WithTracing(tracing =>
        {
            tracing.AddSource(builder.Environment.ApplicationName)
                   .AddAspNetCoreInstrumentation()
                   .AddHttpClientInstrumentation()
                   .AddSqlClientInstrumentation();
        });

    builder.AddOpenTelemetryExporters();
    return builder;
}
```

2. **Custom Metrics** (`OrderService.cs`):

```csharp
private static readonly Meter _meter = new("eShop.Orders.API");
private static readonly Counter<int> _ordersPlaced =
    _meter.CreateCounter<int>("eShop.orders.placed");
private static readonly Histogram<double> _orderDuration =
    _meter.CreateHistogram<double>("eShop.orders.processing.duration");
```

3. **Trace Context Propagation** (`OrdersMessageHandler.cs`):

```csharp
// Propagate trace context to Service Bus messages
message.ApplicationProperties["TraceId"] = Activity.Current?.TraceId.ToString();
message.ApplicationProperties["SpanId"] = Activity.Current?.SpanId.ToString();
message.ApplicationProperties["traceparent"] =
    $"00-{Activity.Current?.TraceId}-{Activity.Current?.SpanId}-01";
```

## Consequences

### Positive

| Benefit                       | Impact                                       |
| ----------------------------- | -------------------------------------------- |
| **Vendor Neutrality**         | Can switch backends without re-instrumenting |
| **Standards Compliance**      | W3C Trace Context for correlation            |
| **Rich Auto-instrumentation** | ASP.NET Core, HTTP, SQL, EF Core automatic   |
| **Custom Metrics**            | Business KPIs alongside technical metrics    |
| **Azure Integration**         | Application Map, Transaction Search, Alerts  |
| **Local Development**         | Aspire Dashboard for local OTLP              |

### Negative

| Tradeoff              | Mitigation                                           |
| --------------------- | ---------------------------------------------------- |
| **Two Concepts**      | OTel for collection, Azure for analysis - documented |
| **Learning Curve**    | Team training on both OTel and Azure Monitor         |
| **Data Volume Costs** | Sampling strategies, retention policies              |
| **Logic App Gaps**    | Logic Apps use built-in diagnostics, not OTel        |

### Neutral

- Application Insights pricing model unchanged
- Existing Azure Monitor skills transfer
- KQL queries remain the analysis language

---


---

## 📱 Telemetry Matrix

| Component    | Traces | Metrics | Logs | Method            |
| ------------ | ------ | ------- | ---- | ----------------- |
| Orders API   | ✅     | ✅      | ✅   | OTel SDK          |
| Web App      | ✅     | ✅      | ✅   | OTel SDK          |
| Logic Apps   | ✅     | ✅      | ✅   | Azure Diagnostics |
| Service Bus  | ✅     | ✅      | ✅   | Azure Diagnostics |
| SQL Database | ✅     | ✅      | ✅   | Azure Diagnostics |

---


---

## 🔍 Alternatives Considered

### 1. Application Insights SDK Only

**Description**: Use classic Application Insights .NET SDK

**Why Not Chosen**:

- Vendor lock-in to Azure Monitor
- Harder to migrate to other backends
- Less alignment with industry standards
- Classic SDK being deprecated in favor of OTel

### 2. Jaeger/Zipkin

**Description**: Self-hosted open-source tracing backends

**Why Not Chosen**:

- Operational overhead of hosting
- No native Azure integration
- Separate tools for metrics and logs
- Additional infrastructure to manage

### 3. Datadog/New Relic/Dynatrace

**Description**: Third-party commercial APM platforms

**Why Not Chosen**:

- Additional licensing costs
- Data egress from Azure
- Duplicate capabilities with Azure Monitor
- Extra vendor relationship to manage

### 4. Azure Monitor Agent Only

**Description**: Use Azure Monitor agent without OTel

**Why Not Chosen**:

- Less control over instrumentation
- Missing custom spans and metrics
- No local development option
- Harder to switch vendors later

---


---

## 🔗 Correlation Strategy

### Cross-Service Trace Flow

```mermaid
---
title: Cross-Service Trace Flow
---
sequenceDiagram
    participant Web as Web App
    participant API as Orders API
    participant SB as Service Bus
    participant LA as Logic App
    participant AI as App Insights

    Note over Web,LA: Same TraceId propagated

    Web->>API: HTTP + traceparent
    API->>SB: Message + TraceId property
    SB->>LA: Trigger + correlation

    Web-->>AI: Export
    API-->>AI: Export
    LA-->>AI: Diagnostics

    Note over AI: Application Map shows<br/>complete flow
```

### Correlation Properties

| Hop          | Mechanism           | Property                 |
| ------------ | ------------------- | ------------------------ |
| HTTP         | Header              | `traceparent`            |
| Service Bus  | ApplicationProperty | `TraceId`, `traceparent` |
| Logic App    | Built-in            | `x-ms-workflow-run-id`   |
| App Insights | SDK                 | `operation_Id`           |

---


---

## 🔗 Related Decisions

- [ADR-001: Aspire Orchestration](ADR-001-aspire-orchestration.md) - OTel configured via ServiceDefaults
- [ADR-002: Service Bus Messaging](ADR-002-service-bus-messaging.md) - Trace propagation in messages

---

## 📚 References

- [OpenTelemetry .NET](https://opentelemetry.io/docs/languages/net/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-overview)
- [W3C Trace Context](https://www.w3.org/TR/trace-context/)
- [.NET Aspire Telemetry](https://learn.microsoft.com/dotnet/aspire/fundamentals/telemetry)

---

_← [ADR-002](ADR-002-service-bus-messaging.md) | [ADR Index](README.md)_
