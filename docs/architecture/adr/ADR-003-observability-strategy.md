---
title: "ADR-003: OpenTelemetry with Azure Monitor for Observability"
description: Architecture decision to implement OpenTelemetry instrumentation with Azure Monitor
author: Evilazaro
date: 2025-01
status: Accepted
tags: [adr, opentelemetry, observability, architecture-decision]
---

# 📊 ADR-003: OpenTelemetry with Azure Monitor for Observability

> [!NOTE]
> **Status:** Accepted | **Date:** January 2025

<details>
<summary>📍 <strong>Quick Navigation</strong></summary>

| Previous | Index | Next |
|:---------|:------:|--------:|
| [← ADR-002](ADR-002-service-bus-messaging.md) | [📋 ADR Index](README.md) | — |

</details>

---

## 📑 Table of Contents

- [📊 Status](#-status)
- [📋 Context](#-context)
- [✅ Decision](#-decision)
- [⚖️ Consequences](#️-consequences)
- [🔄 Alternatives Considered](#-alternatives-considered)
- [📈 Telemetry Architecture](#-telemetry-architecture)
- [📚 References](#-references)

---

## 📊 Status

**Accepted** - January 2025

---

## 📋 Context

The eShop Orders system is a distributed application with multiple services that need comprehensive observability:

- **Distributed Tracing**: Track requests across API, Logic Apps, and databases
- **Metrics**: Monitor business KPIs and technical performance
- **Logging**: Structured logs with correlation
- **Health Checks**: Liveness and readiness probes

### Requirements

| Requirement         | Priority | Notes                               |
| ------------------- | -------- | ----------------------------------- |
| Distributed tracing | High     | Cross-service correlation           |
| Custom metrics      | High     | Business KPIs (orders placed, etc.) |
| Structured logging  | High     | Searchable, correlated logs         |
| Azure integration   | High     | App Insights, Log Analytics         |
| Vendor neutrality   | Medium   | Avoid deep lock-in                  |
| Performance impact  | Medium   | Low overhead instrumentation        |

### Observability Needs

| Component   | Tracing                                  | Metrics                           | Logging                 |
| ----------- | ---------------------------------------- | --------------------------------- | ----------------------- |
| Orders API  | Incoming requests, DB calls, Service Bus | Order counts, latency, errors     | Business events, errors |
| Web App     | Outgoing HTTP calls, page loads          | Request counts, latency           | User actions, errors    |
| Logic Apps  | Workflow execution, actions              | Workflow metrics (Azure-provided) | Action results          |
| Service Bus | Message processing                       | Queue depth, throughput           | Dead-letters            |

---

## ✅ Decision

We will use **OpenTelemetry SDK** with **Azure Monitor Exporter** for observability instrumentation.

### Implementation

#### OpenTelemetry Configuration

```csharp
// app.ServiceDefaults/Extensions.cs
public static IHostApplicationBuilder ConfigureOpenTelemetry(this IHostApplicationBuilder builder)
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
                   .AddMeter("eShop.Orders");  // Custom meter
        })
        .WithTracing(tracing =>
        {
            tracing.AddAspNetCoreInstrumentation()
                   .AddHttpClientInstrumentation()
                   .AddEntityFrameworkCoreInstrumentation()
                   .AddSource("Azure.Messaging.ServiceBus");
        });

    // Export to Azure Monitor
    builder.AddOpenTelemetryExporters();
    return builder;
}
```

#### Custom Metrics

```csharp
// src/eShop.Orders.API/Services/OrderService.cs
private static readonly Meter s_meter = new("eShop.Orders", "1.0.0");
private static readonly Counter<long> s_ordersPlaced =
    s_meter.CreateCounter<long>("eShop.orders.placed", description: "Number of orders placed");
private static readonly Histogram<double> s_processingDuration =
    s_meter.CreateHistogram<double>("eShop.orders.processing.duration", "ms");

public async Task<Order> CreateOrderAsync(Order order)
{
    var sw = Stopwatch.StartNew();
    // ... order creation logic ...

    s_ordersPlaced.Add(1, new KeyValuePair<string, object?>("status", order.Status));
    s_processingDuration.Record(sw.ElapsedMilliseconds);
}
```

#### Distributed Tracing

```csharp
// W3C Trace Context propagation to Service Bus
var message = new ServiceBusMessage(payload);
if (Activity.Current != null)
{
    message.ApplicationProperties["traceparent"] =
        $"00-{Activity.Current.TraceId}-{Activity.Current.SpanId}-01";
}
```

---

## ⚖️ Consequences

### Benefits

| Benefit                  | Description                               |
| ------------------------ | ----------------------------------------- |
| **Vendor Neutrality**    | OpenTelemetry is CNCF standard, portable  |
| **Auto-Instrumentation** | ASP.NET Core, HTTP, EF Core automatic     |
| **Custom Metrics**       | Business KPIs alongside technical metrics |
| **Distributed Tracing**  | End-to-end request correlation            |
| **Azure Integration**    | Native export to Application Insights     |
| **Structured Logging**   | Correlated, searchable logs               |

### Drawbacks

| Drawback                 | Mitigation                                            |
| ------------------------ | ----------------------------------------------------- |
| **Setup Complexity**     | ServiceDefaults centralizes configuration             |
| **Learning Curve**       | Well-documented, team familiar with tracing           |
| **Performance Overhead** | Minimal with sampling, measured <1%                   |
| **Two Systems**          | Logic Apps uses Azure-native; correlation still works |

### Risks

| Risk                 | Probability | Impact | Mitigation                   |
| -------------------- | ----------- | ------ | ---------------------------- |
| Data volume costs    | Medium      | Medium | Sampling, retention policies |
| Trace context loss   | Low         | Medium | Test across all boundaries   |
| SDK breaking changes | Low         | Low    | Pin versions, test upgrades  |

---

## 🔄 Alternatives Considered

### 1. Application Insights SDK (Direct)

**Pros**: Deep Azure integration, auto-collection, AI detection
**Cons**: Vendor lock-in, less portable, custom metrics more complex
**Why Rejected**: OpenTelemetry provides same benefits with portability

### 2. Prometheus + Grafana

**Pros**: Open source, industry standard, flexible dashboards
**Cons**: Self-hosted, no tracing, additional infrastructure
**Why Rejected**: Operational overhead, prefer managed service

### 3. Datadog / New Relic

**Pros**: Full-featured APM, excellent UX, auto-instrumentation
**Cons**: Cost, additional vendor, less Azure integration
**Why Rejected**: Azure Monitor sufficient, cost-effective

### 4. Jaeger + Custom Metrics

**Pros**: Open source tracing, flexible, Kubernetes native
**Cons**: Self-hosted, no managed option, additional complexity
**Why Rejected**: Prefer managed, Azure-integrated solution

### Comparison Matrix

| Criteria          | OTel + Azure | App Insights | Prometheus | Datadog |
| ----------------- | ------------ | ------------ | ---------- | ------- |
| Vendor Neutral    | ⭐⭐⭐       | ⭐           | ⭐⭐⭐     | ⭐⭐    |
| Tracing           | ⭐⭐⭐       | ⭐⭐⭐       | ❌         | ⭐⭐⭐  |
| Metrics           | ⭐⭐⭐       | ⭐⭐         | ⭐⭐⭐     | ⭐⭐⭐  |
| Azure Integration | ⭐⭐⭐       | ⭐⭐⭐       | ⭐         | ⭐⭐    |
| Cost              | ⭐⭐         | ⭐⭐         | ⭐⭐⭐     | ⭐      |
| Operational       | ⭐⭐⭐       | ⭐⭐⭐       | ⭐         | ⭐⭐⭐  |

---

## 📈 Telemetry Architecture

```mermaid
---
title: OpenTelemetry Telemetry Architecture
---
flowchart TB
    %% ===== CLASS DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== APPLICATIONS LAYER =====
    subgraph Apps["📱 Applications"]
        API["Orders API<br/>(OTel SDK)"]
        Web["Web App<br/>(OTel SDK)"]
        LA["Logic Apps<br/>(Azure native)"]
    end
    style Apps fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== COLLECTION LAYER =====
    subgraph Collect["📡 Collection"]
        Exporter["Azure Monitor<br/>Exporter"]
        Connector["Logic Apps<br/>Diagnostics"]
    end
    style Collect fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== STORAGE LAYER =====
    subgraph Store["💾 Storage"]
        AI["Application<br/>Insights"]
        LAW["Log Analytics<br/>Workspace"]
    end
    style Store fill:#D1FAE5,stroke:#10B981,stroke-width:2px

    %% ===== VISUALIZATION LAYER =====
    subgraph Visualize["📊 Visualization"]
        Portal["Azure Portal"]
        Workbooks["Workbooks"]
        Dashboard["Aspire Dashboard"]
    end
    style Visualize fill:#F3E8FF,stroke:#A855F7,stroke-width:2px

    %% ===== CONNECTIONS =====
    API -->|"sends telemetry"| Exporter
    Web -->|"sends telemetry"| Exporter
    LA -->|"sends diagnostics"| Connector
    Exporter -->|"exports to"| AI
    Connector -->|"writes to"| LAW
    AI -->|"stores in"| LAW
    LAW -->|"displays in"| Portal
    LAW -->|"renders in"| Workbooks
    AI -->|"feeds"| Dashboard

    %% ===== NODE STYLING =====
    class API,Web primary
    class LA external
    class Exporter,Connector trigger
    class AI,LAW datastore
    class Portal,Workbooks,Dashboard secondary
```

---

## 📚 References

- [OpenTelemetry .NET Documentation](https://opentelemetry.io/docs/instrumentation/net/)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-overview)
- [Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)
- [Observability Architecture](../05-observability-architecture.md)

---

[← ADR Index](README.md)
