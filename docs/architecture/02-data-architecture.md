# Data Architecture

← [Business Architecture](01-business-architecture.md) | [Index](README.md) | [Application Architecture →](03-application-architecture.md)

## Data Architecture Overview

The Azure Logic Apps Monitoring Solution implements a **service-oriented data architecture** where each service owns its data store exclusively. This design ensures loose coupling, independent deployability, and clear data ownership boundaries. Data flows through the system via synchronous API calls (read/write operations) and asynchronous messaging (event propagation), with comprehensive telemetry captured for end-to-end observability.

The architecture supports two deployment models with environment parity:
- **Local Development**: SQL Server container, Service Bus emulator, local storage
- **Azure Deployment**: Azure SQL Database, Azure Service Bus, Azure Storage

---

## Data Architecture Principles

| Principle | Statement | Rationale | Implications |
|-----------|-----------|-----------|--------------|
| **Data Ownership** | Each service owns its data store exclusively | Loose coupling, independent deployability | No shared databases; API-mediated access only |
| **Event-Driven Propagation** | State changes propagated via immutable events | Audit trail, replay capability, loose coupling | Service Bus for all cross-service communication |
| **Data at Rest Encryption** | All persistent data encrypted | Compliance, security posture | Azure SQL TDE, Storage Service Encryption enabled |
| **Observability First** | All data flows instrumented for tracing | End-to-end visibility, debugging capability | W3C Trace Context propagation across all boundaries |
| **Environment Parity** | Same data patterns in dev and production | Reduced deployment risk, consistent behavior | Emulators mirror Azure service behavior |

---

## Data Landscape Map

```mermaid
flowchart LR
    subgraph Producers["⬆️ Data Producers"]
        WebApp["🌐 Web App<br/>(User Input)"]
        API["⚙️ Orders API<br/>(Business Logic)"]
    end

    subgraph Stores["🗄️ Data Stores"]
        OrderDb[("📦 OrderDb<br/>Azure SQL")]
        EventBus["📨 ordersplaced<br/>Service Bus Topic"]
        WorkflowState["📁 Workflow State<br/>Azure Storage"]
    end

    subgraph Consumers["⬇️ Data Consumers"]
        LogicApp["🔄 Logic Apps<br/>(Workflow Automation)"]
        AppInsights["📊 App Insights<br/>(Observability)"]
    end

    WebApp -->|"POST /api/orders"| API
    API -->|"EF Core"| OrderDb
    API -->|"Publish Event"| EventBus
    EventBus -->|"Trigger"| LogicApp
    LogicApp -->|"State"| WorkflowState
    
    API -.->|"Telemetry"| AppInsights
    LogicApp -.->|"Telemetry"| AppInsights
    WebApp -.->|"Telemetry"| AppInsights

    classDef producer fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef store fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef consumer fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px

    class WebApp,API producer
    class OrderDb,EventBus,WorkflowState store
    class LogicApp,AppInsights consumer
```

---

## Data Domain Catalog

| Data Domain | Description | Bounded Context | Primary Store | Owner Service | Steward |
|-------------|-------------|-----------------|---------------|---------------|---------|
| **Order Management** | Customer orders and line items with validation | eShop.Orders | Azure SQL Database | eShop.Orders.API | Order Management Team |
| **Order Events** | Immutable order lifecycle events for downstream processing | Messaging | Service Bus Topic | eShop.Orders.API (publisher) | Platform Team |
| **Workflow State** | Logic App execution state and run history | Automation | Azure Storage | OrdersManagement Logic App | Workflow Team |
| **Operational Telemetry** | Distributed traces, logs, and metrics | Observability | Application Insights | All Services | SRE Team |

---

## Data Store Details

| Store | Technology | Purpose | Owner Service | Location | Tier/SKU |
|-------|------------|---------|---------------|----------|----------|
| **OrderDb** | Azure SQL Database | Order and product persistence with ACID transactions | eShop.Orders.API | Azure / Local SQL Container | General Purpose |
| **ordersplaced** | Service Bus Topic | Order event fan-out to multiple subscribers | eShop.Orders.API (publisher) | Azure / Local Emulator | Standard |
| **orderprocessingsub** | Service Bus Subscription | Logic App event consumption with dead-letter support | Logic Apps (subscriber) | Azure / Local Emulator | Standard |
| **Workflow State** | Azure Storage (File Share) | Logic App definition and run state persistence | OrdersManagement Logic App | Azure Storage Account | Standard LRS |
| **Application Insights** | Log Analytics Workspace | Telemetry storage for traces, logs, and metrics | All Services | Azure | Standard |

---

## Data Flow Architecture

### Write Path: Order Creation

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant Web as 🌐 Web App
    participant API as ⚙️ Orders API
    participant DB as 🗄️ SQL Database
    participant SB as 📨 Service Bus
    participant LA as 🔄 Logic App
    participant AI as 📊 App Insights

    User->>Web: Submit Order Form
    Web->>API: POST /api/orders
    API->>API: Validate Order (FluentValidation)
    API->>DB: BEGIN TRANSACTION
    API->>DB: INSERT Order + Products
    DB-->>API: Commit Success
    API->>SB: Publish OrderPlaced (with TraceContext)
    SB-->>API: Acknowledged
    API-->>Web: 201 Created + Order JSON
    Web-->>User: Success Notification
    
    API-.->AI: Emit Trace Span
    
    Note over SB,LA: Asynchronous Processing Boundary
    SB->>LA: Trigger: Service Bus Message
    LA->>LA: Execute OrderProcessing Workflow
    LA-.->AI: Emit Workflow Telemetry
```

### Read Path: Order Retrieval

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant Web as 🌐 Web App
    participant API as ⚙️ Orders API
    participant DB as 🗄️ SQL Database
    participant AI as 📊 App Insights

    User->>Web: Navigate to Orders Page
    Web->>API: GET /api/orders
    API->>DB: SELECT Orders JOIN OrderProducts
    DB-->>API: Result Set
    API->>API: Map to DTOs
    API-->>Web: JSON Order Collection
    Web-->>User: Render Orders Grid
    
    API-.->AI: Emit Query Trace
```

---

## Monitoring Data Flow Architecture

```mermaid
flowchart LR
    subgraph Sources["📡 Layer 1: Telemetry Sources"]
        direction TB
        WebApp["🌐 Web App<br/>(Blazor Server)"]
        API["⚙️ Orders API<br/>(ASP.NET Core)"]
        LA["🔄 Logic Apps<br/>(Standard)"]
        SB["📨 Service Bus"]
        SQL["🗄️ SQL Database"]
    end

    subgraph Instrumentation["🔧 Layer 2: Instrumentation"]
        direction TB
        OTEL["OpenTelemetry SDK<br/>───────────<br/>📍 Traces<br/>📊 Metrics<br/>📝 Logs"]
        AzureDiag["Azure Diagnostics<br/>───────────<br/>📋 Workflow Runs<br/>⚡ Actions"]
        AzureMon["Azure Monitor<br/>───────────<br/>📈 Platform Metrics"]
    end

    subgraph Collection["📥 Layer 3: Collection & Storage"]
        direction TB
        AI["📊 Application Insights<br/>───────────<br/>APM • Distributed Traces<br/>90 days retention"]
        LAW["📋 Log Analytics Workspace<br/>───────────<br/>Centralized Logs • KQL<br/>30 days retention"]
    end

    subgraph Visualization["📈 Layer 4: Visualization & Alerting"]
        direction TB
        AppMap["🗺️ Application Map"]
        TransactionSearch["🔍 Transaction Search"]
        KQL["📝 KQL Queries"]
        Dashboards["📊 Azure Dashboards"]
        Alerts["🚨 Alert Rules"]
    end

    WebApp -->|"OTLP/HTTP"| OTEL
    API -->|"OTLP/HTTP"| OTEL
    LA -->|"Built-in"| AzureDiag
    SB -->|"Metrics"| AzureMon
    SQL -->|"Metrics"| AzureMon

    OTEL -->|"Export"| AI
    AzureDiag -->|"Diagnostics"| LAW
    AzureMon -->|"Platform"| LAW
    AI <-->|"Workspace Link"| LAW

    AI --> AppMap
    AI --> TransactionSearch
    LAW --> KQL
    AI --> Dashboards
    LAW --> Dashboards
    AI --> Alerts
    LAW --> Alerts

    classDef source fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef instrument fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef collect fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef visual fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

    class WebApp,API,LA,SB,SQL source
    class OTEL,AzureDiag,AzureMon instrument
    class AI,LAW collect
    class AppMap,TransactionSearch,KQL,Dashboards,Alerts visual
```

### Telemetry Sources Detail

| Source | Technology | Telemetry Emitted | Instrumentation |
|--------|------------|-------------------|-----------------|
| **Web App** | Blazor Server | User interactions, page loads, HTTP client calls | OpenTelemetry SDK (auto) |
| **Orders API** | ASP.NET Core | Request traces, business metrics, structured logs | OpenTelemetry SDK (auto + manual) |
| **Logic Apps** | Standard | Workflow runs, action executions, trigger events | Azure Diagnostics (built-in) |
| **Service Bus** | Standard Tier | Message counts, queue depth, dead-letter metrics | Azure Monitor (platform) |
| **SQL Database** | Azure SQL | Query performance, DTU usage, connections | Azure Monitor (platform) |

### Telemetry Data Flow Matrix

| Source | Telemetry Type | Destination | Protocol | Correlation Key |
|--------|---------------|-------------|----------|-----------------|
| Web App | Traces, Logs | Application Insights | OTLP/HTTP | TraceId, SpanId |
| Orders API | Traces, Logs, Metrics | Application Insights | OTLP/HTTP | TraceId, SpanId |
| Service Bus Message | Trace Context | Message Properties | AMQP | traceparent header |
| Logic Apps | Workflow Runs, Actions | Log Analytics | Azure Diagnostics | Operation ID |
| All Services | Health Checks | App Insights Availability | HTTP | Endpoint URL |

### Trace Context Propagation

```mermaid
flowchart LR
    subgraph TraceFlow["🔗 W3C Trace Context Propagation"]
        HTTP["🌐 HTTP Request<br/>───────────<br/>traceparent header<br/>tracestate header"]
        SBMsg["📨 Service Bus<br/>───────────<br/>TraceId property<br/>SpanId property<br/>traceparent property"]
        LACorr["🔄 Logic Apps<br/>───────────<br/>x-ms-workflow-run-id<br/>x-ms-client-tracking-id"]
        AICorr["📊 App Insights<br/>───────────<br/>Operation ID<br/>Parent ID"]
    end

    HTTP -->|"Inject"| SBMsg
    SBMsg -->|"Extract & Link"| LACorr
    HTTP -->|"Auto-capture"| AICorr
    LACorr -->|"Correlate"| AICorr

    classDef trace fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    class HTTP,SBMsg,LACorr,AICorr trace
```

The solution implements **W3C Trace Context** for end-to-end distributed tracing across all service boundaries:

| Component | Propagation Method | Properties |
|-----------|-------------------|------------|
| HTTP Requests | Headers | `traceparent`, `tracestate` |
| Service Bus Messages | Application Properties | `TraceId`, `SpanId`, `traceparent` |
| Logic Apps | Built-in Correlation | Azure-managed Operation ID |
| Application Insights | SDK Auto-instrumentation | Operation ID correlation |

```csharp
// Trace context injection into Service Bus messages
// From: src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs
message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();
message.ApplicationProperties["traceparent"] = activity.Id ?? string.Empty;
```

> 💡 **Tip:** This propagation ensures Logic Apps workflow runs can be correlated with the originating API request in Application Insights, enabling end-to-end transaction visibility.

---

## Telemetry Data Mapping

### Three Pillars of Observability

The solution implements all three pillars of observability for comprehensive system insight:

```mermaid
flowchart TB
    subgraph Sources["📡 Telemetry Sources"]
        API["⚙️ Orders API"]
        Web["🌐 Web App"]
        LA["🔄 Logic Apps"]
        SB["📨 Service Bus"]
        SQL["🗄️ SQL Database"]
    end

    subgraph Pillars["📊 Three Pillars"]
        subgraph Traces["📍 Traces"]
            T1["Request spans"]
            T2["Database spans"]
            T3["HTTP client spans"]
            T4["Messaging spans"]
        end
        
        subgraph Metrics["📈 Metrics"]
            M1["Request metrics"]
            M2["Business metrics"]
            M3["Platform metrics"]
            M4["Custom metrics"]
        end
        
        subgraph Logs["📝 Logs"]
            L1["Application logs"]
            L2["Request logs"]
            L3["Diagnostic logs"]
            L4["Audit logs"]
        end
    end

    subgraph Storage["📥 Storage"]
        AI["Application Insights"]
        LAW["Log Analytics"]
    end

    API --> T1 & T2 & M1 & M2 & L1 & L2
    Web --> T3 & M1 & L1 & L2
    LA --> T4 & M3 & L3
    SB --> M3 & L3
    SQL --> M3 & L3

    Traces --> AI
    Metrics --> AI
    Logs --> AI
    Logs --> LAW

    classDef trace fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef metric fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef log fill:#fff3e0,stroke:#ef6c00,stroke-width:2px

    class T1,T2,T3,T4 trace
    class M1,M2,M3,M4 metric
    class L1,L2,L3,L4 log
```

| Pillar | Description | Data Type | Use Case | Storage |
|--------|-------------|-----------|----------|---------||
| **Traces** | Distributed request flow across services | Spans with TraceId, SpanId, ParentSpanId | End-to-end transaction analysis | Application Insights |
| **Metrics** | Numeric measurements aggregated over time | Counters, Gauges, Histograms | Dashboards, alerts, capacity planning | Azure Monitor Metrics |
| **Logs** | Discrete events with contextual information | Structured JSON with properties | Debugging, auditing, investigation | Log Analytics |

### Metrics Inventory

#### Orders API Metrics

| Metric | Type | Description | Dimensions | Alert Threshold |
|--------|------|-------------|------------|-----------------|
| `http.server.request.duration` | Histogram | Request latency | http.method, http.route, http.status_code | P95 > 2s |
| `http.server.active_requests` | UpDownCounter | Concurrent requests | http.method | > 100 |
| `orders.created` | Counter | Orders created count | - | N/A |
| `orders.total_value` | Counter | Cumulative order value | currency | N/A |
| `db.client.operation.duration` | Histogram | Database query time | db.operation, db.name | P95 > 500ms |

#### Service Bus Metrics (Platform)

| Metric | Type | Description | Alert Threshold |
|--------|------|-------------|-----------------|
| `ActiveMessages` | Gauge | Messages awaiting delivery | > 1000 |
| `DeadLetteredMessages` | Gauge | Failed message count | > 0 |
| `IncomingMessages` | Counter | Messages received | N/A |
| `OutgoingMessages` | Counter | Messages delivered | N/A |

#### SQL Database Metrics (Platform)

| Metric | Type | Description | Alert Threshold |
|--------|------|-------------|-----------------|
| `cpu_percent` | Gauge | CPU utilization | > 80% |
| `dtu_consumption_percent` | Gauge | DTU usage | > 80% |
| `connection_successful` | Counter | Successful connections | N/A |
| `deadlock` | Counter | Deadlock occurrences | > 0 |

#### Logic Apps Metrics (Platform)

| Metric | Type | Description | Alert Threshold |
|--------|------|-------------|-----------------|
| `RunsSucceeded` | Counter | Successful workflow runs | N/A |
| `RunsFailed` | Counter | Failed workflow runs | > 0 |
| `RunLatency` | Gauge | Workflow execution time | > 5min |
| `ActionLatency` | Gauge | Individual action time | > 30s |

### Logs Inventory

#### Orders API Logs

| Log Event | Level | Properties | Example |
|-----------|-------|------------|---------|
| `OrderCreated` | Information | OrderId, CustomerId, Total | "Order ORD-2025-001 created" |
| `OrderValidationFailed` | Warning | OrderId, Errors[] | "Validation failed: Address required" |
| `DatabaseQueryExecuted` | Debug | Query, Duration, RowCount | "SELECT executed in 45ms" |
| `ServiceBusMessagePublished` | Information | MessageId, Topic, TraceId | "OrderPlaced published" |
| `UnhandledException` | Error | Exception, StackTrace | Full exception details |

#### Web App Logs

| Log Event | Level | Properties | Example |
|-----------|-------|------------|---------|
| `PageLoaded` | Information | PageName, LoadTime | "Orders page loaded in 1.2s" |
| `ApiCallFailed` | Warning | Endpoint, StatusCode | "GET /api/orders returned 500" |
| `UserAction` | Information | Action, Component | "User clicked Submit Order" |

#### Logic Apps Logs (Diagnostic)

| Log Event | Level | Table | Properties |
|-----------|-------|-------|-----------|
| `WorkflowRunStarted` | Information | AzureDiagnostics | workflowName, runId |
| `WorkflowRunCompleted` | Information | AzureDiagnostics | runId, status, duration |
| `WorkflowRunFailed` | Error | AzureDiagnostics | runId, errorCode, errorMessage |

### Structured Logging Format

```json
{
  "Timestamp": "2025-12-30T10:30:00.000Z",
  "Level": "Information",
  "MessageTemplate": "Order {OrderId} created with total {Total}",
  "Properties": {
    "OrderId": "ORD-2025-001",
    "Total": 149.99,
    "CustomerId": "CUST-100",
    "TraceId": "abc123def456...",
    "SpanId": "789ghi012...",
    "RequestPath": "/api/orders",
    "SourceContext": "eShop.Orders.API.Controllers.OrdersController"
  },
  "Exception": null
}
```

| Property | Required | Purpose | Example |
|----------|----------|---------|--------|
| `Timestamp` | ✅ Yes | When event occurred | ISO 8601 UTC |
| `Level` | ✅ Yes | Severity | Information, Warning, Error |
| `MessageTemplate` | ✅ Yes | Human-readable message | "Order {OrderId} created" |
| `TraceId` | ✅ Yes | Correlation | W3C trace ID |
| `SpanId` | ✅ Yes | Span correlation | W3C span ID |
| `SourceContext` | Recommended | Origin class | Fully qualified type name |
| `RequestPath` | Recommended | HTTP context | "/api/orders" |

### Metrics vs Logs Decision Guide

| Question | → Metrics | → Logs |
|----------|-----------|--------|
| Is it a number that changes over time? | ✅ | |
| Do you need to aggregate/calculate percentiles? | ✅ | |
| Is it a discrete event with context? | | ✅ |
| Do you need full details for debugging? | | ✅ |
| Is it used for dashboards/alerts on thresholds? | ✅ | |
| Is it used for searching/filtering specific events? | | ✅ |
| Does it have high cardinality (many unique values)? | | ✅ |
| Is it sampled or aggregated? | ✅ | |

---

## Data Lifecycle States

| Stage | Description | Location | Duration | Transition Trigger |
|-------|-------------|----------|----------|-------------------|
| **Creation** | Order submitted via API | Orders API memory | Milliseconds | Validation passes |
| **Persistence** | Order saved to database | Azure SQL | Indefinite | Transaction commit |
| **Publication** | Order event published | Service Bus topic | 14 days TTL | Post-commit hook |
| **Consumption** | Event processed by workflow | Logic App | Minutes | Subscription delivery |
| **Telemetry** | Operational data captured | App Insights | 90 days | Continuous |
| **Archival** | Historical order data | Cold storage | 7 years | Age-based policy |

---

## Data Technology Landscape

| Capability | Technology | Tier | Justification | Alternative Considered |
|------------|------------|------|---------------|------------------------|
| **Transactional Storage** | Azure SQL Database | General Purpose | ACID compliance, EF Core support | Cosmos DB (rejected: overkill for structured data) |
| **Event Streaming** | Azure Service Bus | Standard | Reliable messaging, topic/subscription | Event Hubs (rejected: lower throughput needs) |
| **Workflow State** | Azure Storage | Standard LRS | Logic Apps native integration | N/A (platform requirement) |
| **APM & Tracing** | Application Insights | Standard | Distributed tracing, correlation | Jaeger (rejected: operational overhead) |
| **Log Aggregation** | Log Analytics | Standard | KQL queries, Azure integration | ELK Stack (rejected: operational overhead) |

---

## Data Dependencies Map

```mermaid
flowchart TD
    subgraph Upstream["⬆️ Upstream Data Producers"]
        WebApp["🌐 Web App<br/>(Order Input)"]
    end

    subgraph Core["🎯 Core Data Assets"]
        OrderDb[("📦 OrderDb<br/>Azure SQL")]
        EventBus["📨 Service Bus<br/>ordersplaced"]
    end

    subgraph Downstream["⬇️ Downstream Data Consumers"]
        LogicApp["🔄 Logic Apps<br/>(Workflow Automation)"]
        AppInsights["📊 App Insights<br/>(Analytics & Monitoring)"]
    end

    WebApp -->|"Creates orders"| OrderDb
    OrderDb -->|"Publishes events"| EventBus
    EventBus -->|"Triggers workflows"| LogicApp
    OrderDb -.->|"Emits telemetry"| AppInsights
    LogicApp -.->|"Emits telemetry"| AppInsights

    classDef upstream fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef core fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef downstream fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px

    class WebApp upstream
    class OrderDb,EventBus core
    class LogicApp,AppInsights downstream
```

---

## Data Integration Points

### Data Flow Matrix

| Source | Target | Data Type | Protocol | Pattern | Frequency | Volume |
|--------|--------|-----------|----------|---------|-----------|--------|
| Web App | Orders API | Order JSON | HTTPS/REST | Sync Request/Response | On-demand | ~100/hour |
| Orders API | SQL Database | Order Entity | TDS/EF Core | CRUD | Per request | ~100/hour |
| Orders API | Service Bus | OrderPlaced Event | AMQP | Async Pub/Sub | Per order | ~100/hour |
| Service Bus | Logic Apps | OrderPlaced Event | Connector | Event-driven | Per event | ~100/hour |
| All Services | App Insights | Telemetry | HTTPS/OTLP | Continuous Push | Batched | ~10K/hour |

### Internal Service Communication

| Source | Target | Protocol | Data Format | Pattern | Frequency |
|--------|--------|----------|-------------|---------|-----------|
| Web App | Orders API | HTTPS/REST | JSON | Synchronous Request/Response | On-demand |
| Orders API | SQL Database | TDS (EF Core) | Relational | CRUD Operations | Per request |
| Orders API | Service Bus | AMQP | JSON | Async Pub/Sub | Per order |
| Service Bus | Logic App | Service Bus Connector | JSON | Event-driven Trigger | Per message |
| All Services | App Insights | HTTPS/OTLP | Telemetry | Continuous Push | Batched |

### Service Bus Topology

| Resource | Type | Purpose | Configuration |
|----------|------|---------|---------------|
| **ordersplaced** | Topic | Fan-out order events to multiple subscribers | Standard tier, 1GB |
| **orderprocessingsub** | Subscription | Logic App consumption | MaxDeliveryCount: 10, LockDuration: 5min, TTL: 14 days |

### Message Schema: OrderPlaced Event

```json
{
  "Id": "ORD-2025-001",
  "CustomerId": "CUST-100",
  "Date": "2025-12-30T10:30:00Z",
  "DeliveryAddress": "123 Main St, Seattle, WA 98101",
  "Total": 149.99,
  "Products": [
    {
      "Id": "ITEM-001",
      "OrderId": "ORD-2025-001",
      "ProductId": "PROD-1001",
      "ProductDescription": "Wireless Mouse",
      "Quantity": 2,
      "Price": 25.99
    }
  ]
}
```

| Message Property | Value | Purpose |
|-----------------|-------|---------|
| `ContentType` | `application/json` | MIME type declaration |
| `MessageId` | Order.Id | Deduplication key |
| `Subject` | `OrderPlaced` | Message type discriminator |
| `traceparent` | W3C traceparent | Distributed tracing correlation |

---

## Data Governance

### Data Classification

| Data Element | Classification | Logging | Tracing | Handling |
|--------------|----------------|---------|---------|----------|
| Order ID | Business Identifier | Full | Tagged | Standard |
| Customer ID | PII Reference | ID only | Not tagged | Restricted |
| Delivery Address | PII | Masked | Not included | Confidential |
| Order Total | Financial | Full | Metrics only | Internal |
| Product Details | Business | Full | Tagged | Standard |

### Retention Policies

| Data Store | Retention | Policy Type | Archive Strategy |
|------------|-----------|-------------|------------------|
| SQL Database (Orders) | Indefinite | Business data | Manual archival |
| Log Analytics Logs | 30 days | Operational | Auto-delete |
| Application Insights | 90 days | Telemetry | Export to Storage |
| Service Bus Messages | 14 days | Transient | TTL on subscription |

### Backup and Recovery

| Component | Backup Strategy | RPO | RTO |
|-----------|-----------------|-----|-----|
| Azure SQL Database | Automated geo-redundant | 5 min | 1 hour |
| Service Bus | No backup (transient) | N/A | Replay from source |
| Workflow State | Azure Storage redundancy | Near-zero | Minutes |
| App Insights | Platform managed | N/A | N/A |

---

## Cross-Architecture Relationships

| Related Architecture | Connection | Reference |
|---------------------|------------|-----------|
| **Business Architecture** | Orders data supports Order Fulfillment capability | [Business Architecture](01-business-architecture.md#business-capabilities) |
| **Application Architecture** | Orders API service manages Order data entities | [Application Architecture](03-application-architecture.md#service-catalog) |
| **Technology Architecture** | Azure SQL hosts OrderDb; Service Bus transports events | [Technology Architecture](04-technology-architecture.md#infrastructure-components) |
| **Observability Architecture** | Telemetry data flows to App Insights for monitoring | [Observability Architecture](05-observability-architecture.md#distributed-tracing) |
| **Security Architecture** | Data classification drives access control policies | [Security Architecture](06-security-architecture.md#data-protection) |

---

## Data Architecture Quality Checklist

- [x] All data stores documented with owner service
- [x] Data flow diagrams cover write and read paths
- [x] Data classification applied to all data elements
- [x] Trace context propagation explained
- [x] Cross-architecture references included
- [x] Data landscape map shows all domains
- [x] Metrics inventory documented by source
- [x] Logs inventory documented by source
- [x] Three pillars (traces, metrics, logs) mapped to sources
- [x] Structured logging format defined
- [x] Metrics vs logs decision criteria applied
- [x] Platform metrics from Azure Monitor included
- [x] Data lifecycle states documented
- [x] Data technology landscape with justifications
- [x] Data dependencies map with upstream/downstream

---

## Related Documents

- [Application Architecture](03-application-architecture.md) - Service implementation details
- [Technology Architecture](04-technology-architecture.md) - Azure SQL and Service Bus configuration
- [Observability Architecture](05-observability-architecture.md) - Telemetry and tracing details
- [ADR-002: Service Bus Messaging](adr/ADR-002-service-bus-messaging.md) - Messaging pattern decision
- [Database Migration Guide](../../src/eShop.Orders.API/MIGRATION_GUIDE.md) - EF Core schema management
