# Observability Architecture

← [Technology Architecture](04-technology-architecture.md) | **Observability** | [Security Architecture →](06-security-architecture.md)

---

## Observability Principles

| #       | Principle                          | Rationale                         | Implications                      |
| ------- | ---------------------------------- | --------------------------------- | --------------------------------- |
| **O-1** | **Vendor-Neutral Instrumentation** | Avoid lock-in, future flexibility | Use OpenTelemetry SDK             |
| **O-2** | **Correlation by Default**         | End-to-end visibility             | W3C Trace Context propagation     |
| **O-3** | **Business-Aligned Metrics**       | Connect tech to outcomes          | Custom metrics for orders KPIs    |
| **O-4** | **Actionable Alerts**              | Reduce noise, improve response    | Alert on symptoms, not causes     |
| **O-5** | **Cost-Aware Telemetry**           | Control data volumes              | Sampling and filtering strategies |

---

## Three Pillars Overview

```mermaid
flowchart TB
    subgraph Pillars["📊 Three Pillars of Observability"]
        direction LR
        Traces["🔍 Traces<br/><i>Distributed request flow</i>"]
        Metrics["📈 Metrics<br/><i>Quantitative measurements</i>"]
        Logs["📝 Logs<br/><i>Discrete event records</i>"]
    end

    subgraph Collection["📥 Collection Layer"]
        SDK["OpenTelemetry SDK<br/><i>.NET instrumentation</i>"]
        Agent["Azure Diagnostics<br/><i>Platform telemetry</i>"]
    end

    subgraph Backend["💾 Backend Layer"]
        APM["Application Insights<br/><i>APM platform</i>"]
        LogStore["Log Analytics<br/><i>Log aggregation</i>"]
    end

    subgraph Consumption["👁️ Consumption Layer"]
        Dashboards["Azure Dashboards"]
        Alerts["Alert Rules"]
        Queries["KQL Queries"]
        AppMap["Application Map"]
    end

    Traces & Metrics & Logs --> SDK & Agent
    SDK & Agent --> APM & LogStore
    APM & LogStore --> Dashboards & Alerts & Queries & AppMap

    classDef pillars fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef collection fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef backend fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef consumption fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

    class Traces,Metrics,Logs pillars
    class SDK,Agent collection
    class APM,LogStore backend
    class Dashboards,Alerts,Queries,AppMap consumption
```

---

## Distributed Tracing Strategy

### Trace Flow Architecture

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant Web as 🌐 Web App
    participant API as 📡 Orders API
    participant DB as 🗄️ SQL
    participant SB as 📨 Service Bus
    participant LA as 🔄 Logic App
    participant AI as 📊 App Insights

    User->>Web: HTTP Request
    Note over Web: Activity Started<br/>TraceId: abc123

    Web->>API: HTTP + traceparent header
    Note over API: Activity Continued<br/>ParentSpanId: web-span

    API->>DB: SQL Query
    Note over API,DB: EF Core instrumentation

    API->>SB: Publish Message
    Note over API,SB: ApplicationProperties:<br/>TraceId, SpanId, traceparent

    API-->>Web: HTTP Response
    Web-->>User: Page Rendered

    SB->>LA: Trigger Workflow
    Note over LA: Correlation via<br/>Message properties

    Web -.-> AI: Export traces
    API -.-> AI: Export traces
    LA -.-> AI: Diagnostic logs
```

### Trace Context Propagation

| Component            | Propagation Method       | Properties                         |
| -------------------- | ------------------------ | ---------------------------------- |
| HTTP Requests        | Headers                  | `traceparent`, `tracestate`        |
| Service Bus Messages | ApplicationProperties    | `TraceId`, `SpanId`, `traceparent` |
| Logic Apps           | Built-in correlation     | Azure-managed                      |
| Application Insights | SDK auto-instrumentation | Operation ID                       |

### Span Inventory

| Service        | Span Name              | Kind     | Key Tags                                 |
| -------------- | ---------------------- | -------- | ---------------------------------------- |
| **Orders API** | `PlaceOrder`           | Server   | `order.id`, `order.total`, `http.method` |
| **Orders API** | `SaveOrderStarted`     | Internal | `order.id`, `order.customer_id`          |
| **Orders API** | `SendOrderMessage`     | Producer | `messaging.destination.name`, `order.id` |
| **Web App**    | `HTTP GET /api/orders` | Client   | `http.url`, `http.status_code`           |

---

## Metrics Catalog

### Application Metrics (Custom)

| Metric Name                        | Type      | Unit  | Description                | Dimensions     |
| ---------------------------------- | --------- | ----- | -------------------------- | -------------- |
| `eShop.orders.placed`              | Counter   | order | Orders successfully placed | `order.status` |
| `eShop.orders.processing.duration` | Histogram | ms    | Order processing time      | `order.status` |
| `eShop.orders.processing.errors`   | Counter   | error | Order processing failures  | `error.type`   |
| `eShop.orders.deleted`             | Counter   | order | Orders deleted             | -              |

### Platform Metrics (Auto-instrumented)

| Metric Name                    | Source       | Type      | Purpose               |
| ------------------------------ | ------------ | --------- | --------------------- |
| `http.server.request.duration` | ASP.NET Core | Histogram | API latency           |
| `http.client.request.duration` | HttpClient   | Histogram | Outbound call latency |
| `db.client.operation.duration` | EF Core      | Histogram | Database query time   |

### Azure Monitor Metrics

| Resource         | Metric                    | Alert Threshold   | Action               |
| ---------------- | ------------------------- | ----------------- | -------------------- |
| **Service Bus**  | `ActiveMessages`          | > 1000 for 10 min | Scale consumers      |
| **Service Bus**  | `DeadLetteredMessages`    | > 0               | Investigate failures |
| **SQL Database** | `dtu_consumption_percent` | > 80% for 15 min  | Scale up             |
| **Logic Apps**   | `RunsFailed`              | > 3 in 5 min      | Check workflow logs  |

---

## Logging Strategy

### Log Levels and Usage

| Level           | Usage                       | Example                   |
| --------------- | --------------------------- | ------------------------- |
| **Critical**    | Application cannot continue | Startup failures          |
| **Error**       | Operation failed            | Database connection error |
| **Warning**     | Unexpected but recoverable  | Retry triggered           |
| **Information** | Significant events          | Order placed successfully |
| **Debug**       | Diagnostic details          | SQL query generated       |
| **Trace**       | Verbose debugging           | Method entry/exit         |

### Structured Logging Schema

```json
{
  "Timestamp": "2026-01-20T10:30:00.000Z",
  "Level": "Information",
  "MessageTemplate": "Order {OrderId} placed successfully in {Duration:F2}ms",
  "Properties": {
    "OrderId": "ORD-2026-001",
    "Duration": 245.5,
    "CustomerId": "CUST-100",
    "TraceId": "abc123def456...",
    "SpanId": "789ghi012...",
    "RequestPath": "/api/orders",
    "SourceContext": "eShop.Orders.API.Services.OrderService"
  }
}
```

### Log Correlation Requirements

| Property        | Required    | Purpose                   |
| --------------- | ----------- | ------------------------- |
| `TraceId`       | ✅ Yes      | Cross-service correlation |
| `SpanId`        | ✅ Yes      | Span-level correlation    |
| `OrderId`       | Recommended | Business entity tracking  |
| `SourceContext` | Recommended | Log source identification |

---

## OpenTelemetry Configuration

### Instrumentation Sources

```csharp
// From Extensions.cs
openTelemetry.WithTracing(tracing =>
{
    tracing.AddSource(builder.Environment.ApplicationName)
        .AddSource("eShop.Orders.API")
        .AddSource("eShop.Web.App")
        .AddSource("Azure.Messaging.ServiceBus")
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddSqlClientInstrumentation();
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

### Exporters Configuration

| Exporter          | Target                   | Configuration                           |
| ----------------- | ------------------------ | --------------------------------------- |
| **OTLP**          | Aspire Dashboard (local) | `OTEL_EXPORTER_OTLP_ENDPOINT`           |
| **Azure Monitor** | Application Insights     | `APPLICATIONINSIGHTS_CONNECTION_STRING` |

---

## Health Monitoring

### Health Check Endpoints

| Endpoint  | Purpose               | Tags   |
| --------- | --------------------- | ------ |
| `/health` | Overall health status | all    |
| `/alive`  | Liveness probe        | `live` |

### Custom Health Checks

| Check        | Source                | Evaluates                |
| ------------ | --------------------- | ------------------------ |
| `self`       | ServiceDefaults       | Application is running   |
| `database`   | DbContextHealthCheck  | SQL connectivity         |
| `servicebus` | ServiceBusHealthCheck | Service Bus connectivity |

### Health Check Implementation

```csharp
// From HealthChecks/DbContextHealthCheck.cs
public async Task<HealthCheckResult> CheckHealthAsync(
    HealthCheckContext context,
    CancellationToken cancellationToken = default)
{
    try
    {
        var canConnect = await _dbContext.Database
            .CanConnectAsync(cancellationToken);

        return canConnect
            ? HealthCheckResult.Healthy("Database connection is healthy")
            : HealthCheckResult.Unhealthy("Cannot connect to database");
    }
    catch (Exception ex)
    {
        return HealthCheckResult.Unhealthy("Database health check failed", ex);
    }
}
```

---

## Alert Rules Catalog

| Alert                   | Severity | Condition                 | Response                     |
| ----------------------- | -------- | ------------------------- | ---------------------------- |
| **High API Latency**    | Warning  | P95 > 2s for 5 min        | Investigate slow queries     |
| **API Error Spike**     | Critical | Error rate > 5% for 5 min | Page on-call                 |
| **Queue Depth Growing** | Warning  | Depth > 1000 for 10 min   | Scale consumers              |
| **Database DTU High**   | Warning  | DTU > 80% for 15 min      | Consider scaling             |
| **Failed Workflows**    | Critical | > 3 failures in 5 min     | Check Logic App logs         |
| **Dead Letters**        | Warning  | Count > 0                 | Investigate message failures |

---

## SLI/SLO Definitions

| SLI              | Definition               | Measurement                 | SLO      | Error Budget   |
| ---------------- | ------------------------ | --------------------------- | -------- | -------------- |
| **Availability** | % of successful requests | `successCount / totalCount` | 99.9%    | 43.2 min/month |
| **Latency**      | P95 response time        | `percentile(duration, 95)`  | < 500ms  | N/A            |
| **Throughput**   | Orders processed/hour    | `count(orders.placed)`      | > 500/hr | N/A            |
| **Error Rate**   | % of 5xx responses       | `errorCount / totalCount`   | < 0.1%   | N/A            |

---

## Observability Platform Architecture

```mermaid
flowchart LR
    subgraph Sources["📡 Telemetry Sources"]
        API["Orders API"]
        Web["Web App"]
        LA["Logic Apps"]
        SB["Service Bus"]
        SQL["SQL Database"]
    end

    subgraph Ingestion["📥 Ingestion"]
        OTEL["OpenTelemetry<br/>Collector"]
        DiagSettings["Diagnostic<br/>Settings"]
    end

    subgraph Storage["💾 Storage"]
        AI["Application<br/>Insights"]
        LAW["Log Analytics<br/>Workspace"]
    end

    subgraph Analysis["🔍 Analysis"]
        KQL["KQL Queries"]
        AppMap["Application Map"]
        TxSearch["Transaction Search"]
    end

    subgraph Action["⚡ Action"]
        Alerts["Alert Rules"]
        Dashboards["Dashboards"]
        Workbooks["Workbooks"]
    end

    API & Web -->|"OTLP"| OTEL --> AI
    LA & SB & SQL -->|"ARM"| DiagSettings --> LAW
    AI --> LAW
    AI --> KQL & AppMap & TxSearch
    LAW --> KQL
    KQL --> Alerts & Dashboards & Workbooks

    classDef source fill:#fff3e0,stroke:#ef6c00
    classDef ingestion fill:#e3f2fd,stroke:#1565c0
    classDef storage fill:#e8f5e9,stroke:#2e7d32
    classDef analysis fill:#f3e5f5,stroke:#7b1fa2
    classDef action fill:#fce4ec,stroke:#c2185b

    class API,Web,LA,SB,SQL source
    class OTEL,DiagSettings ingestion
    class AI,LAW storage
    class KQL,AppMap,TxSearch analysis
    class Alerts,Dashboards,Workbooks action
```

---

## Cross-Architecture Relationships

| Related Architecture         | Connection                               | Reference                                                                                       |
| ---------------------------- | ---------------------------------------- | ----------------------------------------------------------------------------------------------- |
| **Business Architecture**    | SLOs measure business KPIs               | [Quality Attributes](01-business-architecture.md#quality-attribute-requirements)                |
| **Data Architecture**        | Telemetry data flows documented          | [Telemetry Mapping](02-data-architecture.md#telemetry-data-mapping)                             |
| **Application Architecture** | Services instrumented with OpenTelemetry | [Cross-Cutting Concerns](03-application-architecture.md#cross-cutting-concerns-servicedefaults) |
| **Technology Architecture**  | Monitoring platforms defined             | [Platform Decomposition](04-technology-architecture.md#platform-decomposition)                  |

---

_← [Technology Architecture](04-technology-architecture.md) | [Security Architecture →](06-security-architecture.md)_
