# Observability Architecture

← [Technology Architecture](04-technology-architecture.md) | [Index](README.md) | [Security Architecture →](06-security-architecture.md)

---

## 1. Observability Principles

| # | Principle | Rationale | Implications |
|---|-----------|-----------|--------------|
| **O-1** | **Vendor-Neutral Instrumentation** | Avoid lock-in, future flexibility | Use OpenTelemetry SDK exclusively |
| **O-2** | **Correlation by Default** | End-to-end visibility across services | W3C Trace Context propagation everywhere |
| **O-3** | **Business-Aligned Metrics** | Connect technology to outcomes | Custom metrics for orders placed, processing time |
| **O-4** | **Actionable Alerts** | Reduce noise, improve response time | Alert on symptoms with runbooks |
| **O-5** | **Cost-Aware Telemetry** | Control data volumes and costs | Sampling strategies, retention policies |
| **O-6** | **Structured Everything** | Enable powerful querying | JSON structured logs, semantic conventions |

---

## 2. Observability Strategy Overview

The solution implements **comprehensive observability** using the three pillars: **Traces**, **Metrics**, and **Logs**. All telemetry flows to Azure Application Insights with Log Analytics for advanced querying.

### Three Pillars Implementation

| Pillar | Technology | Purpose | Storage |
|--------|------------|---------|---------|
| **Traces** | OpenTelemetry + Azure Monitor Exporter | Distributed request tracing | Application Insights |
| **Metrics** | OpenTelemetry Metrics + Custom Counters | Performance monitoring | Azure Monitor Metrics |
| **Logs** | OpenTelemetry Logging + ILogger | Structured event logging | Log Analytics Workspace |

### BDAT Integration View

```mermaid
flowchart TB
    subgraph Business["🏢 Business Architecture"]
        SLO["SLOs & KPIs<br/><i>99.9% availability, <500ms latency</i>"]
        Process["Business Processes<br/><i>Order fulfillment monitoring</i>"]
    end

    subgraph Application["🔧 Application Architecture"]
        Services["Application Services<br/><i>Orders API, Web App</i>"]
        Instrumentation["Instrumentation Points<br/><i>OpenTelemetry SDK</i>"]
    end

    subgraph Data["💾 Data Architecture"]
        TelemetryData["Telemetry Data Model<br/><i>Traces, Metrics, Logs</i>"]
        Retention["Data Retention<br/><i>30-day logs, 90-day metrics</i>"]
    end

    subgraph Technology["⚙️ Technology Architecture"]
        Platforms["Observability Platforms<br/><i>App Insights, Log Analytics</i>"]
        Tools["Monitoring Tools<br/><i>Azure Monitor, KQL</i>"]
    end

    SLO -->|"measured by"| Instrumentation
    Process -->|"monitored via"| Services
    Services -->|"emit"| TelemetryData
    Instrumentation -->|"sends to"| Platforms
    TelemetryData -->|"stored in"| Tools
    Retention -->|"configured in"| Platforms

    classDef business fill:#e3f2fd,stroke:#1565c0
    classDef app fill:#e8f5e9,stroke:#2e7d32
    classDef data fill:#fff3e0,stroke:#ef6c00
    classDef tech fill:#f3e5f5,stroke:#7b1fa2

    class SLO,Process business
    class Services,Instrumentation app
    class TelemetryData,Retention data
    class Platforms,Tools tech
```

### Tooling Decisions

| Capability | Choice | Rationale |
| **Instrumentation SDK** | OpenTelemetry | Vendor-neutral, comprehensive auto-instrumentation |
| **APM Backend** | Application Insights | Native Azure integration, powerful analytics |
| **Log Aggregation** | Log Analytics | KQL queries, Azure integration, 30-day retention |
| **Exporter** | Azure Monitor Exporter | Direct integration without OTLP collector |

---

## 3. SLI/SLO Definitions

### Service Level Indicators (SLIs)

| SLI | Definition | Measurement | Data Source |
|-----|------------|-------------|-------------|
| **Availability** | % of successful HTTP requests | `successCount / totalCount * 100` | Application Insights `requests` |
| **Latency** | P95 response time | `percentile(duration, 95)` | Application Insights `requests` |
| **Throughput** | Orders processed per hour | `count(eShop.orders.placed)` | Custom metrics |
| **Error Rate** | % of 5xx responses | `5xxCount / totalCount * 100` | Application Insights `requests` |
| **Queue Latency** | Time message sits in queue | `dequeue_time - enqueue_time` | Service Bus metrics |

### Service Level Objectives (SLOs)

| Service | SLI | SLO Target | Error Budget | Measurement Window |
|---------|-----|------------|--------------|--------------------|
| **Orders API** | Availability | 99.9% | 43.2 min/month | Rolling 30 days |
| **Orders API** | Latency (P95) | < 500ms | N/A | Rolling 24 hours |
| **Orders API** | Error Rate | < 0.1% | 0.1% of requests | Rolling 24 hours |
| **Web App** | Availability | 99.9% | 43.2 min/month | Rolling 30 days |
| **Logic App** | Success Rate | 99.5% | 3.6 hours/month | Rolling 30 days |
| **Service Bus** | Message Processing | < 5 min | N/A | Per message |

### Error Budget Policy

| Budget Status | Action |
|---------------|--------|
| **> 50% remaining** | Normal development velocity |
| **25-50% remaining** | Prioritize reliability work |
| **< 25% remaining** | Freeze feature development, focus on stability |
| **Exhausted** | Incident review required before new deployments |

---

## 4. Telemetry Inventory

### Telemetry Sources Matrix

| Source | Traces | Metrics | Logs | Correlation | Auto-Instrumented |
|--------|--------|---------|------|-------------|-------------------|
| **Orders API** | ✅ | ✅ | ✅ | TraceId, SpanId | Yes (ASP.NET Core) |
| **Web App** | ✅ | ✅ | ✅ | TraceId, SpanId | Yes (Blazor Server) |
| **Service Bus Publisher** | ✅ | ✅ | ✅ | traceparent header | Manual injection |
| **Logic App** | ⚠️ Limited | ✅ | ✅ | Run ID, Action ID | Azure Diagnostics |
| **SQL Database** | ✅ | ✅ | ✅ | N/A | EF Core instrumentation |
| **Service Bus** | ❌ | ✅ | ✅ | Message ID | Azure Diagnostics |

### Custom Telemetry Inventory

| Name | Type | Source | Description |
|------|------|--------|-------------|
| `eShop.orders.placed` | Counter | OrderService | Orders successfully created |
| `eShop.orders.processing.duration` | Histogram | OrderService | Time to process order |
| `eShop.orders.processing.errors` | Counter | OrderService | Order processing failures |
| `eShop.Orders.API` | ActivitySource | OrdersController | Custom trace spans |
| `eShop.Web.App` | ActivitySource | WebApp | Custom trace spans |

---

## 5. Distributed Tracing

### Trace Propagation Flow

```mermaid
flowchart LR
    subgraph Client["🌐 Client"]
        Browser["Browser"]
    end

    subgraph WebApp["Web App"]
        WA_Span["Span: HTTP Request"]
    end

    subgraph API["Orders API"]
        API_Span["Span: POST /api/orders"]
        DB_Span["Span: SQL INSERT"]
        SB_Span["Span: Service Bus Publish"]
    end

    subgraph ServiceBus["Service Bus"]
        Message["Message with<br/>traceparent header"]
    end

    subgraph LogicApp["Logic App"]
        LA_Span["Span: Workflow Run"]
    end

    subgraph AppInsights["Application Insights"]
        Trace["Correlated Trace<br/>Operation ID"]
    end

    Browser -->|"traceparent"| WA_Span
    WA_Span -->|"traceparent"| API_Span
    API_Span --> DB_Span
    API_Span --> SB_Span
    SB_Span -->|"ApplicationProperties"| Message
    Message -->|"Trigger"| LA_Span

    WA_Span -.-> Trace
    API_Span -.-> Trace
    DB_Span -.-> Trace
    SB_Span -.-> Trace
    LA_Span -.-> Trace

    classDef client fill:#f5f5f5,stroke:#616161
    classDef service fill:#e3f2fd,stroke:#1565c0
    classDef messaging fill:#e8f5e9,stroke:#2e7d32
    classDef observability fill:#f3e5f5,stroke:#7b1fa2

    class Browser client
    class WA_Span,API_Span,DB_Span,SB_Span,LA_Span service
    class Message messaging
    class Trace observability
```

### Correlation ID Strategy

| Context | Header/Property | Example |
|---------|-----------------|---------|
| HTTP Requests | `traceparent` header | `00-abc123...-def456...-01` |
| Service Bus Messages | `ApplicationProperties["traceparent"]` | W3C Trace Context |
| Logs | `TraceId`, `SpanId` properties | Structured log correlation |
| Application Insights | `Operation ID` | Auto-correlated |

### Span Hierarchy Example

```
🔗 Operation: POST /api/orders (2.5s)
├── 📡 HTTP POST /api/orders (1.8s)
│   ├── ✅ Validate Order (10ms)
│   ├── 🗄️ SQL INSERT Orders (200ms)
│   ├── 🗄️ SQL INSERT OrderProducts (150ms)
│   └── 📨 Service Bus Publish (50ms)
└── 🔄 Logic App: ProcessingOrdersPlaced (700ms)
    └── ⚙️ Workflow Actions (700ms)
```

---

## 6. Logging Architecture

### Log Levels and Standards

| Level | Usage | Example |
|-------|-------|---------|
| **Trace** | Detailed diagnostic info | Method entry/exit |
| **Debug** | Development debugging | Variable values, query text |
| **Information** | Normal operations | Order created, message published |
| **Warning** | Recoverable issues | Validation failed, retry occurred |
| **Error** | Failures requiring attention | Unhandled exception, connection failed |
| **Critical** | System failures | Database unavailable after retries |

### Structured Logging Format

All logs follow a consistent JSON structure:

```json
{
  "Timestamp": "2025-12-30T10:30:00.000Z",
  "Level": "Information",
  "MessageTemplate": "Order {OrderId} created for customer {CustomerId}",
  "Properties": {
    "OrderId": "ORD-2025-001",
    "CustomerId": "CUST-100",
    "Total": 149.99,
    "TraceId": "abc123def456...",
    "SpanId": "789xyz...",
    "RequestPath": "/api/orders",
    "SourceContext": "eShop.Orders.API.Services.OrderService"
  }
}
```

### Log Analytics Configuration

| Setting | Value | Purpose |
|---------|-------|---------|
| Workspace SKU | PerGB2018 | Pay-per-GB pricing |
| Retention | 30 days | Log storage duration |
| Destination Type | Dedicated | Separate table per resource |
| Linked Storage | Alerts, Query | Persisted queries and alerts |

---

## 7. Metrics & Monitoring

### Key Metrics

| Metric | Source | Type | Threshold | Alert |
|--------|--------|------|-----------|-------|
| `http.server.request.duration` | Orders API | Histogram | P95 < 2s | Yes |
| `http.server.active_requests` | All Services | UpDownCounter | < 100 | No |
| `eShop.orders.placed` | Orders API | Counter | N/A | No |
| `eShop.orders.processing.duration` | Orders API | Histogram | P95 < 5s | Yes |
| `eShop.orders.processing.errors` | Orders API | Counter | > 0/5min | Yes |
| `db.client.operation.duration` | Orders API | Histogram | P95 < 500ms | Yes |

### Custom Metrics Implementation

From [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs):

```csharp
private static readonly Meter Meter = new("eShop.Orders.API");

private static readonly Counter<long> OrdersPlacedCounter = Meter.CreateCounter<long>(
    "eShop.orders.placed",
    unit: "order",
    description: "Total number of orders successfully placed");

private static readonly Histogram<double> OrderProcessingDuration = Meter.CreateHistogram<double>(
    "eShop.orders.processing.duration",
    unit: "ms",
    description: "Time taken to process order operations");

private static readonly Counter<long> OrderProcessingErrors = Meter.CreateCounter<long>(
    "eShop.orders.processing.errors",
    unit: "error",
    description: "Total number of order processing errors");
```

### Platform Metrics (Azure Monitor)

| Resource | Metric | Alert Threshold |
|----------|--------|-----------------|
| Service Bus | `ActiveMessages` | > 1000 |
| Service Bus | `DeadLetteredMessages` | > 0 |
| SQL Database | `cpu_percent` | > 80% |
| Logic Apps | `RunsFailed` | > 0 |
| Container Apps | `Requests` | N/A (baseline) |

---

## 8. Application Insights Integration

### Instrumentation Approach

Configured in [Extensions.cs](../../app.ServiceDefaults/Extensions.cs):

```csharp
public static TBuilder ConfigureOpenTelemetry<TBuilder>(this TBuilder builder)
{
    builder.Logging.AddOpenTelemetry(logging =>
    {
        logging.IncludeFormattedMessage = true;
        logging.IncludeScopes = true;
        logging.ParseStateValues = true;
    });

    var openTelemetry = builder.Services.AddOpenTelemetry();

    openTelemetry.WithMetrics(metrics =>
    {
        metrics.AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddRuntimeInstrumentation()
            .AddMeter("eShop.Orders.API")
            .AddMeter("eShop.Web.App");
    });

    openTelemetry.WithTracing(tracing =>
    {
        tracing.AddSource("eShop.Orders.API")
            .AddSource("eShop.Web.App")
            .AddSource("Azure.Messaging.ServiceBus")
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddSqlClientInstrumentation();
    });
}
```

### SDK Configuration

| Configuration | Value | Purpose |
|--------------|-------|---------|
| Connection String | App Insights Connection String | Telemetry destination |
| Sampling | None (capture all) | Full visibility |
| Filter | Exclude `/health`, `/alive` | Reduce noise |
| Enrichment | Request/response size | Additional context |

---

## 9. Health Monitoring

### Health Check Endpoints

| Endpoint | Type | Checks | Tags |
|----------|------|--------|------|
| `/health` | Readiness | All registered checks | `ready` |
| `/alive` | Liveness | Self-check only | `live` |

### Health Model

```mermaid
flowchart TB
    subgraph HealthChecks["🏥 Health Checks"]
        Self["Self Check<br/><i>Application running</i>"]
        DB["Database Check<br/><i>SQL connectivity</i>"]
        SB["Service Bus Check<br/><i>Topic accessibility</i>"]
    end

    subgraph Probes["🔍 Container Probes"]
        Liveness["Liveness Probe<br/><i>/alive</i>"]
        Readiness["Readiness Probe<br/><i>/health</i>"]
    end

    subgraph Orchestrator["🎯 Container Apps"]
        Restart["Restart Container"]
        RemoveTraffic["Remove from LB"]
    end

    Self --> Liveness
    Self & DB & SB --> Readiness

    Liveness -->|"Unhealthy"| Restart
    Readiness -->|"Unhealthy"| RemoveTraffic

    classDef check fill:#e8f5e9,stroke:#2e7d32
    classDef probe fill:#e3f2fd,stroke:#1565c0
    classDef action fill:#ffebee,stroke:#c62828

    class Self,DB,SB check
    class Liveness,Readiness probe
    class Restart,RemoveTraffic action
```

### Dependency Health Tracking

| Dependency | Health Check | Failure Impact |
|------------|--------------|----------------|
| SQL Database | `DbContextHealthCheck` | Orders API unhealthy |
| Service Bus | `ServiceBusHealthCheck` | Orders API unhealthy |
| Orders API | HTTP health check | Web App unhealthy |

---

## 10. Alerting Strategy

### Alert Rules

| Alert | Condition | Severity | Action |
|-------|-----------|----------|--------|
| High API Latency | P95 > 2s for 5 min | Warning | Notify team |
| API Errors Spike | Error rate > 5% | Error | Page on-call |
| Service Bus Dead Letters | DLQ count > 0 | Warning | Notify team |
| Logic App Failures | RunsFailed > 0 | Error | Notify team |
| SQL High CPU | cpu_percent > 80% | Warning | Auto-scale review |
| Health Check Failed | Unhealthy > 1 min | Critical | Page on-call |

### Escalation Paths

| Severity | Initial Response | Escalation |
|----------|------------------|------------|
| **Warning** | Slack notification | Review within 4 hours |
| **Error** | Email + Slack | Investigate within 1 hour |
| **Critical** | PagerDuty | Immediate response |

---

## 11. Dashboards & Visualization

### Dashboard Inventory

| Dashboard | Purpose | Primary Users |
|-----------|---------|---------------|
| **Application Map** | Service dependency visualization | Developers, SRE |
| **Transaction Search** | End-to-end trace analysis | Developers |
| **Performance Dashboard** | Latency and throughput | SRE, Management |
| **Live Metrics** | Real-time request flow | SRE during incidents |
| **Failures Dashboard** | Error analysis | Developers |

### Key Visualizations

| Visualization | Source | KQL Query Example |
|---------------|--------|-------------------|
| Request rate over time | `requests` table | `requests \| summarize count() by bin(timestamp, 5m)` |
| Error distribution | `exceptions` table | `exceptions \| summarize count() by type` |
| Dependency latency | `dependencies` table | `dependencies \| summarize avg(duration) by name` |
| Order throughput | Custom metric | `customMetrics \| where name == "eShop.orders.placed"` |

---

## 12. Observability Cost Management

### Data Volume Estimates

| Data Type | Est. Daily Volume | Monthly Cost | Retention |
|-----------|-------------------|--------------|----------|
| **Traces** | 500 MB | ~$1.15 | 90 days |
| **Metrics** | 100 MB | ~$0.25 | 90 days |
| **Logs** | 1 GB | ~$2.50 | 30 days |
| **Custom Metrics** | 10 MB | ~$0.10 | 90 days |
| **Total** | ~1.6 GB/day | **~$4/day** | - |

### Sampling Strategies

| Environment | Sampling Rate | Rationale |
|-------------|---------------|----------|
| **Local** | 100% | Full visibility for debugging |
| **Dev** | 100% | Full visibility for testing |
| **Staging** | 50% | Balance visibility and cost |
| **Production** | 25% | Cost optimization at scale |

### Cost Optimization Techniques

| Technique | Potential Savings | Implementation |
|-----------|-------------------|----------------|
| **Adaptive sampling** | 30-50% | Configure in App Insights SDK |
| **Filter health checks** | 10-20% | Exclude `/health`, `/alive` from traces |
| **Reduce log verbosity** | 20-30% | Set `Warning` level in production |
| **Shorter retention** | 20-40% | 30 days instead of 90 for logs |
| **Aggregate metrics** | 10-15% | Use pre-aggregated metrics |

### Retention Policy

| Data Type | Dev Retention | Prod Retention | Archive |
|-----------|---------------|----------------|--------|
| **Traces** | 30 days | 90 days | None |
| **Metrics** | 30 days | 90 days | None |
| **Logs** | 7 days | 30 days | Blob (optional) |
| **Alerts** | 30 days | 90 days | None |

---

## 13. Runbooks

### Alert Response Runbooks

| Alert | Runbook | First Steps |
|-------|---------|-------------|
| **High API Latency** | [RB-001](#rb-001) | Check App Insights dependency calls, SQL query times |
| **API Errors Spike** | [RB-002](#rb-002) | Review exceptions in App Insights, check recent deployments |
| **Service Bus DLQ** | [RB-003](#rb-003) | Inspect dead-letter messages, check Logic App failures |
| **Logic App Failures** | [RB-004](#rb-004) | Review run history, check trigger conditions |
| **Health Check Failed** | [RB-005](#rb-005) | Verify dependencies, check container logs |

### Sample KQL Queries

**Find slow requests:**
```kusto
requests
| where duration > 2000
| project timestamp, name, duration, resultCode, operation_Id
| order by duration desc
| take 100
```

**Trace end-to-end transaction:**
```kusto
union requests, dependencies, traces, exceptions
| where operation_Id == "<your-operation-id>"
| project timestamp, itemType, name, duration, message
| order by timestamp asc
```

**Order processing metrics:**
```kusto
customMetrics
| where name startswith "eShop.orders"
| summarize sum(valueSum) by name, bin(timestamp, 1h)
| render timechart
```

**Failed Logic App runs:**
```kusto
AzureDiagnostics
| where ResourceType == "WORKFLOWS"
| where status_s == "Failed"
| project TimeGenerated, workflowName_s, error_message_s
| order by TimeGenerated desc
```

---

## Related Documents

- [Business Architecture](01-business-architecture.md) - Observability value stream
- [Data Architecture](02-data-architecture.md) - Telemetry data mapping
- [Application Architecture](03-application-architecture.md) - Service instrumentation
- [Technology Architecture](04-technology-architecture.md) - Azure Monitor resources
- [ADR-003](adr/ADR-003-observability-strategy.md) - Observability strategy decision

---

> 💡 **Tip:** Use the Application Map in Azure Portal to quickly understand service dependencies and identify performance bottlenecks.

> ⚠️ **Warning:** Always test sampling configuration changes in non-production environments first to ensure adequate visibility is maintained.
