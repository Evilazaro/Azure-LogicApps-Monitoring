# Data Architecture

## Data Architecture Overview

The Azure Logic Apps Monitoring Solution implements a **service-oriented data architecture** where each service owns its data and exposes it through well-defined APIs. This approach ensures loose coupling, independent scalability, and clear data ownership boundaries.

### Data Stores Inventory

| Store                    | Technology         | Purpose                                           | Deployment               |
| ------------------------ | ------------------ | ------------------------------------------------- | ------------------------ |
| **OrderDb**              | Azure SQL Database | Transactional order and product data              | Azure (Entra ID auth)    |
| **Service Bus**          | Azure Service Bus  | Event message queue for order events              | Azure (Managed Identity) |
| **Workflow Storage**     | Azure Blob Storage | Processed order archives (success/error/complete) | Azure (Managed Identity) |
| **Log Analytics**        | Azure Monitor Logs | Centralized telemetry and diagnostic data         | Azure (30-day retention) |
| **Application Insights** | Azure Monitor APM  | Distributed traces, metrics, dependencies         | Azure (workspace-based)  |

### Data Ownership by Service

| Service                         | Owned Data                                                        | Access Pattern                    |
| ------------------------------- | ----------------------------------------------------------------- | --------------------------------- |
| **eShop.Orders.API**            | Orders, OrderProducts tables                                      | Read/Write via EF Core            |
| **OrdersPlacedProcess**         | ordersprocessedsuccessfully, ordersprocessedwitherrors containers | Write-only (archive)              |
| **OrdersPlacedCompleteProcess** | ordersprocessedcompleted container                                | Write (archive), Delete (cleanup) |
| **All Services**                | Application Insights telemetry                                    | Write-only (emit), Read via KQL   |

---

## Data Architecture Principles

| Principle                         | Statement                                                  | Rationale                                                    | Implications                                               |
| --------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------- |
| **Single Source of Truth**        | Each data entity has exactly one authoritative source      | Eliminates data inconsistency and synchronization complexity | Orders API owns order data; other services read via API    |
| **Service Data Isolation**        | Services cannot directly access another service's database | Enables independent evolution and deployment                 | Logic Apps call Orders API HTTP endpoint, not SQL directly |
| **Event-Driven Synchronization**  | Cross-service data sharing via published events            | Decouples producers from consumers, improves resilience      | Service Bus topic for order placed events                  |
| **Schema Evolution**              | Data schemas support backward-compatible changes           | Prevents breaking changes during deployments                 | EF Core migrations with additive changes                   |
| **Telemetry as First-Class Data** | Observability data follows same rigor as business data     | Enables debugging, compliance, and operational excellence    | OpenTelemetry instrumentation at every service boundary    |
| **Zero-Trust Data Access**        | All data access authenticated via Managed Identity         | Eliminates secrets, reduces attack surface                   | No connection strings in code; Entra ID everywhere         |

---

## Data Landscape Map

```mermaid
flowchart TB
    subgraph Producers["📤 Data Producers"]
        direction TB
        WebApp["eShop.Web.App<br/>(User Input)"]
        OrdersAPI["eShop.Orders.API<br/>(Business Logic)"]
        LogicApp["Logic Apps<br/>(Workflow State)"]
    end

    subgraph TransactionalData["💾 Transactional Data Domain"]
        direction TB
        subgraph SQLServer["Azure SQL Server"]
            OrdersTable[("Orders<br/>Table")]
            ProductsTable[("OrderProducts<br/>Table")]
        end
    end

    subgraph MessagingData["📨 Messaging Data Domain"]
        direction TB
        subgraph ServiceBus["Azure Service Bus"]
            Topic["ordersplaced<br/>Topic"]
            Subscription["orderprocessingsub<br/>Subscription"]
        end
    end

    subgraph ArchiveData["📁 Archive Data Domain"]
        direction TB
        subgraph BlobStorage["Azure Blob Storage"]
            SuccessContainer["ordersprocessed<br/>successfully"]
            ErrorContainer["ordersprocessed<br/>witherrors"]
            CompleteContainer["ordersprocessed<br/>completed"]
        end
    end

    subgraph TelemetryData["📊 Telemetry Data Domain"]
        direction TB
        AppInsights["Application Insights<br/>(Traces, Metrics, Deps)"]
        LogAnalytics["Log Analytics<br/>(All Logs, Diagnostics)"]
    end

    subgraph Consumers["📥 Data Consumers"]
        direction TB
        Dashboards["Azure Portal<br/>Dashboards"]
        KQL["KQL Queries<br/>& Alerts"]
        AspireDash["Aspire Dashboard<br/>(Local Dev)"]
    end

    WebApp -->|HTTP POST| OrdersAPI
    OrdersAPI -->|EF Core| SQLServer
    OrdersAPI -->|Publish| Topic
    Topic --> Subscription
    Subscription -->|Trigger| LogicApp
    LogicApp -->|Archive Success| SuccessContainer
    LogicApp -->|Archive Error| ErrorContainer
    LogicApp -->|Move Complete| CompleteContainer

    WebApp -.->|OTLP| AppInsights
    OrdersAPI -.->|OTLP| AppInsights
    LogicApp -.->|Diagnostics| LogAnalytics
    SQLServer -.->|Diagnostics| LogAnalytics
    ServiceBus -.->|Diagnostics| LogAnalytics
    BlobStorage -.->|Diagnostics| LogAnalytics
    AppInsights -.->|Workspace Link| LogAnalytics

    LogAnalytics --> Dashboards
    LogAnalytics --> KQL
    AppInsights --> AspireDash

    classDef producer fill:#e8f5e9,stroke:#2e7d32
    classDef transactional fill:#e3f2fd,stroke:#1565c0
    classDef messaging fill:#fff3e0,stroke:#ef6c00
    classDef archive fill:#f5f5f5,stroke:#616161
    classDef telemetry fill:#f3e5f5,stroke:#7b1fa2
    classDef consumer fill:#e1f5fe,stroke:#0277bd

    class WebApp,OrdersAPI,LogicApp producer
    class SQLServer,OrdersTable,ProductsTable transactional
    class ServiceBus,Topic,Subscription messaging
    class BlobStorage,SuccessContainer,ErrorContainer,CompleteContainer archive
    class AppInsights,LogAnalytics telemetry
    class Dashboards,KQL,AspireDash consumer
```

---

## Data Domain Catalog

| Domain                | Bounded Context  | Primary Store                | Data Steward          | Description                                           |
| --------------------- | ---------------- | ---------------------------- | --------------------- | ----------------------------------------------------- |
| **Order Management**  | eShop Orders     | Azure SQL Database           | Orders API            | Customer orders with products, addresses, totals      |
| **Event Messaging**   | Order Events     | Azure Service Bus            | Orders API (producer) | Order placed events for async processing              |
| **Workflow Archives** | Processed Orders | Azure Blob Storage           | Logic Apps            | Historical record of processed orders (success/error) |
| **Observability**     | Telemetry        | Log Analytics / App Insights | Platform              | Traces, metrics, logs across all services             |

---

## Data Store Details

| Store                           | Technology               | Purpose                                                | Owner Service               | Location                |
| ------------------------------- | ------------------------ | ------------------------------------------------------ | --------------------------- | ----------------------- |
| **Orders**                      | Azure SQL Table          | Order header data (id, customer, date, address, total) | eShop.Orders.API            | `[dbo].[Orders]`        |
| **OrderProducts**               | Azure SQL Table          | Order line items (id, orderId, productId, qty, price)  | eShop.Orders.API            | `[dbo].[OrderProducts]` |
| **ordersplaced**                | Service Bus Topic        | Order placed event messages (JSON payload)             | eShop.Orders.API            | Namespace/Topics        |
| **orderprocessingsub**          | Service Bus Subscription | Subscription for Logic App trigger                     | OrdersPlacedProcess         | Namespace/Subscriptions |
| **ordersprocessedsuccessfully** | Blob Container           | Successfully processed order JSON files                | OrdersPlacedProcess         | Storage/Containers      |
| **ordersprocessedwitherrors**   | Blob Container           | Failed order processing JSON files                     | OrdersPlacedProcess         | Storage/Containers      |
| **ordersprocessedcompleted**    | Blob Container           | Archived completed orders                              | OrdersPlacedCompleteProcess | Storage/Containers      |
| **workflowstate**               | Azure Files Share        | Logic App workflow state and artifacts                 | Logic App Runtime           | Storage/FileShares      |

### Entity Relationship Model

```mermaid
erDiagram
    Orders {
        string Id PK "Max 100 chars"
        string CustomerId "Max 100 chars, indexed"
        datetime Date "Required, indexed"
        string DeliveryAddress "Max 500 chars"
        decimal Total "Precision 18,2"
    }

    OrderProducts {
        string Id PK "Max 100 chars"
        string OrderId FK "Max 100 chars, indexed"
        string ProductId "Max 100 chars, indexed"
        string ProductDescription "Max 500 chars"
        int Quantity "Required, >= 1"
        decimal Price "Precision 18,2"
    }

    Orders ||--o{ OrderProducts : "contains"
```

---

## Data Flow Architecture

### End-to-End Data Flow

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant Web as 🌐 Web App
    participant API as ⚙️ Orders API
    participant DB as 💾 SQL Database
    participant SB as 📨 Service Bus
    participant LA as 🔄 Logic App
    participant Blob as 📁 Blob Storage

    rect rgb(232, 245, 233)
        Note over User,API: Write Path - Order Placement
        User->>Web: Submit Order Form
        Web->>API: POST /api/orders
        API->>DB: INSERT Orders + OrderProducts
        DB-->>API: Success
        API->>SB: Publish OrderPlaced message
        SB-->>API: Acknowledged
        API-->>Web: 201 Created + Order
        Web-->>User: Order Confirmed UI
    end

    rect rgb(227, 242, 253)
        Note over SB,Blob: Async Processing Path
        SB->>LA: Trigger (message received)
        LA->>API: POST /api/orders/process
        API-->>LA: 201 Success / Error
        alt Success
            LA->>Blob: Create blob (success container)
        else Error
            LA->>Blob: Create blob (error container)
        end
    end

    rect rgb(255, 243, 224)
        Note over User,DB: Read Path - View Orders
        User->>Web: Navigate to Orders List
        Web->>API: GET /api/orders
        API->>DB: SELECT Orders JOIN OrderProducts
        DB-->>API: Result Set
        API-->>Web: Order[] JSON
        Web-->>User: Render Orders Table
    end
```

### Write Path Details

1. **User Input** → Blazor form captures order with products
2. **HTTP POST** → `OrdersAPIService.PlaceOrderAsync()` sends JSON to API
3. **Validation** → `OrderService.PlaceOrderAsync()` validates business rules
4. **Persistence** → `OrderRepository.SaveOrderAsync()` uses EF Core transaction
5. **Event Publishing** → `OrdersMessageHandler.SendOrderMessageAsync()` publishes to Service Bus
6. **Response** → 201 Created returned with order entity

### Read Path Details

1. **User Navigation** → Blazor page triggers data fetch
2. **HTTP GET** → `OrdersAPIService.GetOrdersAsync()` calls API
3. **Query Execution** → `OrderRepository.GetAllOrdersAsync()` uses split query for performance
4. **Response** → JSON array with orders and nested products

---

## Monitoring Data Flow Architecture

### Four-Layer Observability Model

```mermaid
flowchart LR
    subgraph Layer1["📡 Layer 1: Sources"]
        direction TB
        WebApp["Web App<br/>(Blazor)"]
        OrdersAPI["Orders API<br/>(ASP.NET Core)"]
        LogicApp["Logic Apps<br/>(Standard)"]
        ServiceBus["Service Bus<br/>(Standard)"]
        SQLServer["SQL Server<br/>(Azure)"]
        Storage["Storage<br/>(Blob/Files)"]
    end

    subgraph Layer2["🔧 Layer 2: Instrumentation"]
        direction TB
        OTelSDK["OpenTelemetry SDK<br/>(Traces, Metrics, Logs)"]
        AzMonExp["Azure Monitor<br/>Exporter"]
        DiagSettings["Diagnostic<br/>Settings"]
    end

    subgraph Layer3["📊 Layer 3: Collection"]
        direction TB
        AppInsights["Application Insights<br/>(APM Data)"]
        LogAnalytics["Log Analytics<br/>Workspace"]
    end

    subgraph Layer4["👁️ Layer 4: Visualization"]
        direction TB
        AppMap["Application Map"]
        TransactionSearch["Transaction Search"]
        LiveMetrics["Live Metrics"]
        Workbooks["Azure Workbooks"]
        Alerts["Alert Rules"]
        AspireDash["Aspire Dashboard<br/>(Local Dev)"]
    end

    WebApp --> OTelSDK
    OrdersAPI --> OTelSDK
    OTelSDK --> AzMonExp
    AzMonExp --> AppInsights

    LogicApp --> DiagSettings
    ServiceBus --> DiagSettings
    SQLServer --> DiagSettings
    Storage --> DiagSettings
    DiagSettings --> LogAnalytics

    AppInsights -->|Workspace Link| LogAnalytics

    LogAnalytics --> AppMap
    LogAnalytics --> TransactionSearch
    LogAnalytics --> LiveMetrics
    LogAnalytics --> Workbooks
    LogAnalytics --> Alerts
    AppInsights --> AspireDash

    classDef source fill:#e1f5fe,stroke:#0277bd
    classDef instrument fill:#f3e5f5,stroke:#7b1fa2
    classDef collect fill:#e8f5e9,stroke:#2e7d32
    classDef visualize fill:#fff8e1,stroke:#f9a825

    class WebApp,OrdersAPI,LogicApp,ServiceBus,SQLServer,Storage source
    class OTelSDK,AzMonExp,DiagSettings instrument
    class AppInsights,LogAnalytics collect
    class AppMap,TransactionSearch,LiveMetrics,Workbooks,Alerts,AspireDash visualize
```

---

## Telemetry Data Mapping

### Three Pillars Overview

| Pillar      | Purpose                      | Collection Method                             | Storage                              |
| ----------- | ---------------------------- | --------------------------------------------- | ------------------------------------ |
| **Traces**  | Request flow across services | OpenTelemetry spans with W3C Trace Context    | Application Insights → Log Analytics |
| **Metrics** | Quantitative measurements    | OpenTelemetry meters + Azure platform metrics | Application Insights → Log Analytics |
| **Logs**    | Discrete events and errors   | Structured logging + diagnostic settings      | Application Insights + Log Analytics |

### Metrics Inventory by Source

| Source           | Metric Name                        | Type      | Description                       |
| ---------------- | ---------------------------------- | --------- | --------------------------------- |
| **Orders API**   | `eShop.orders.placed`              | Counter   | Total orders successfully placed  |
| **Orders API**   | `eShop.orders.processing.duration` | Histogram | Order processing time (ms)        |
| **Orders API**   | `eShop.orders.processing.errors`   | Counter   | Order processing failures by type |
| **Orders API**   | `eShop.orders.deleted`             | Counter   | Orders deleted from system        |
| **ASP.NET Core** | `http.server.request.duration`     | Histogram | HTTP request latency              |
| **EF Core**      | `db.client.operation.duration`     | Histogram | Database query duration           |
| **Service Bus**  | `Messages`                         | Gauge     | Messages in topic/subscription    |
| **Service Bus**  | `DeadLetteredMessages`             | Gauge     | Dead-lettered message count       |
| **Logic Apps**   | `RunsSucceeded`                    | Counter   | Successful workflow runs          |
| **Logic Apps**   | `RunsFailed`                       | Counter   | Failed workflow runs              |
| **SQL Database** | `cpu_percent`                      | Gauge     | CPU utilization                   |
| **SQL Database** | `storage_percent`                  | Gauge     | Storage utilization               |

### Logs Inventory by Source

| Source          | Log Category      | Content                                                    | Severity Levels                    |
| --------------- | ----------------- | ---------------------------------------------------------- | ---------------------------------- |
| **Web App**     | Application       | User actions, HTTP client calls, SignalR events            | Information, Warning, Error        |
| **Orders API**  | Application       | Order operations, repository calls, Service Bus publishing | Debug, Information, Warning, Error |
| **Orders API**  | EF Core           | SQL queries, connection events, migrations                 | Debug, Information                 |
| **Service Bus** | OperationalLogs   | Message delivery, throttling, errors                       | Information, Warning, Error        |
| **Logic Apps**  | WorkflowRuntime   | Trigger events, action executions, failures                | Information, Warning, Error        |
| **SQL Server**  | SQLInsights       | Query performance, deadlocks, errors                       | Information, Warning, Error        |
| **Storage**     | StorageRead/Write | Blob operations, access patterns                           | Information                        |

### Telemetry-to-Source Mapping

```mermaid
flowchart TB
    subgraph Sources["Application Sources"]
        direction LR
        WA["Web App"]
        OA["Orders API"]
        LA["Logic App"]
    end

    subgraph Traces["📍 Distributed Traces"]
        direction TB
        T1["PlaceOrder<br/>(Client Span)"]
        T2["PlaceOrder<br/>(Server Span)"]
        T3["SaveOrderAsync<br/>(DB Span)"]
        T4["SendOrderMessage<br/>(Producer Span)"]
        T5["OrdersPlacedProcess<br/>(Workflow Span)"]
    end

    subgraph Metrics["📈 Metrics"]
        direction TB
        M1["orders.placed"]
        M2["processing.duration"]
        M3["http.request.duration"]
        M4["db.operation.duration"]
    end

    subgraph Logs["📝 Structured Logs"]
        direction TB
        L1["Order {OrderId} placed<br/>for customer {CustomerId}"]
        L2["Saved order {OrderId}<br/>to database"]
        L3["Published message<br/>to topic {TopicName}"]
        L4["Workflow triggered<br/>for message {MessageId}"]
    end

    WA --> T1
    OA --> T2
    OA --> T3
    OA --> T4
    LA --> T5

    OA --> M1
    OA --> M2
    OA --> M3
    OA --> M4

    OA --> L1
    OA --> L2
    OA --> L3
    LA --> L4

    T1 -.->|TraceId| T2
    T2 -.->|SpanId| T3
    T2 -.->|SpanId| T4
    T4 -.->|TraceParent| T5

    classDef source fill:#e3f2fd,stroke:#1565c0
    classDef trace fill:#e8f5e9,stroke:#2e7d32
    classDef metric fill:#fff3e0,stroke:#ef6c00
    classDef log fill:#f3e5f5,stroke:#7b1fa2

    class WA,OA,LA source
    class T1,T2,T3,T4,T5 trace
    class M1,M2,M3,M4 metric
    class L1,L2,L3,L4 log
```

---

## Cross-Architecture Relationships

### Data ↔ Business Architecture

| Business Capability | Data Domain      | Primary Store | Data Operations   |
| ------------------- | ---------------- | ------------- | ----------------- |
| Order Management    | Order Management | Azure SQL     | CRUD operations   |
| Event Messaging     | Order Events     | Service Bus   | Publish/Subscribe |
| Workflow Automation | Processed Orders | Blob Storage  | Archive/Move      |
| Observability       | Telemetry        | Log Analytics | Query/Alert       |

### Data ↔ Application Architecture

| Application Component  | Data Interactions     | Access Pattern          |
| ---------------------- | --------------------- | ----------------------- |
| `OrdersController`     | Orders, OrderProducts | REST API → Repository   |
| `OrderRepository`      | Azure SQL             | EF Core DbContext       |
| `OrdersMessageHandler` | Service Bus           | ServiceBusClient        |
| `OrdersPlacedProcess`  | Service Bus, Blob     | Managed API Connections |

### Data ↔ Technology Architecture

| Data Store           | Infrastructure Resource                    | Bicep Module                                      |
| -------------------- | ------------------------------------------ | ------------------------------------------------- |
| Azure SQL            | `Microsoft.Sql/servers`                    | `shared/data/main.bicep`                          |
| Service Bus          | `Microsoft.ServiceBus/namespaces`          | `workload/messaging/main.bicep`                   |
| Blob Storage         | `Microsoft.Storage/storageAccounts`        | `shared/data/main.bicep`                          |
| Log Analytics        | `Microsoft.OperationalInsights/workspaces` | `shared/monitoring/log-analytics-workspace.bicep` |
| Application Insights | `Microsoft.Insights/components`            | `shared/monitoring/app-insights.bicep`            |

---

## Data Security Controls

| Control                   | Implementation                                | Configuration                         |
| ------------------------- | --------------------------------------------- | ------------------------------------- |
| **Encryption at Rest**    | Azure Storage Service Encryption, TDE for SQL | Platform-managed keys                 |
| **Encryption in Transit** | TLS 1.2 minimum                               | `minimumTlsVersion: 'TLS1_2'`         |
| **Access Control**        | Managed Identity + RBAC                       | No shared keys in code                |
| **Network Security**      | Public access with Azure service bypass       | `networkAcls.bypass: 'AzureServices'` |
| **Audit Logging**         | Diagnostic settings to Log Analytics          | All categories enabled                |
| **Data Retention**        | 30-day Log Analytics, 14-day Service Bus TTL  | Configured in Bicep                   |
