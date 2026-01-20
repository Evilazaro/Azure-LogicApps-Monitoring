---
title: Data Architecture
description: Data architecture documentation covering data domains, flows, telemetry mapping, trace context propagation, and data lifecycle for the Azure Logic Apps Monitoring Solution.
author: Architecture Team
date: 2026-01-20
version: 1.0.0
tags:
  - data-architecture
  - togaf
  - telemetry
  - observability
---

# 🗄️ Data Architecture

> [!NOTE]
> **Target Audience:** Data Engineers, Platform Engineers, Developers
> **Reading Time:** ~15 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                                               |     Index      |                                                         Next |
| :----------------------------------------------------- | :------------: | -----------------------------------------------------------: |
| [← Business Architecture](01-business-architecture.md) | **Data Layer** | [Application Architecture →](03-application-architecture.md) |

</details>

---

## 📑 Table of Contents

- [Data Architecture Overview](#-data-architecture-overview)
- [Data Architecture Principles](#-data-architecture-principles)
- [Data Landscape Map](#-data-landscape-map)
- [Data Domain Catalog](#-data-domain-catalog)
- [Data Store Details](#-data-store-details)
- [Data Flow Architecture](#-data-flow-architecture)
- [Monitoring Data Flow Architecture](#-monitoring-data-flow-architecture)
- [Telemetry Data Mapping](#-telemetry-data-mapping)
- [Trace Context Propagation](#-trace-context-propagation)
- [Data Dependencies Map](#-data-dependencies-map)
- [Data Lifecycle States](#-data-lifecycle-states)
- [Cross-Architecture Relationships](#-cross-architecture-relationships)

---

## 📊 Data Architecture Overview

> [!IMPORTANT]
> The solution implements a **service-oriented data architecture** where each service owns its data stores. This ensures loose coupling, independent deployability, and clear data ownership boundaries.

### Data Stores Inventory

| Store                    | Technology                 | Owner Service              | Purpose                       |
| ------------------------ | -------------------------- | -------------------------- | ----------------------------- |
| **OrderDb**              | Azure SQL Database         | eShop.Orders.API           | Order and product persistence |
| **ordersplaced**         | Service Bus Topic          | eShop.Orders.API           | Order event propagation       |
| **orderprocessingsub**   | Service Bus Subscription   | Logic Apps                 | Order event consumption       |
| **Workflow State**       | Azure Storage (File Share) | OrdersManagement Logic App | Workflow execution state      |
| **Application Insights** | Application Insights       | All Services               | Telemetry storage             |
| **Log Analytics**        | Log Analytics Workspace    | Platform                   | Centralized log aggregation   |

---

## 📋 Data Architecture Principles

| Principle                     | Statement                                       | Rationale                                        | Implications                                               |
| ----------------------------- | ----------------------------------------------- | ------------------------------------------------ | ---------------------------------------------------------- |
| **Data Ownership**            | Each service owns its data store exclusively    | Loose coupling, independent deployability        | No shared databases, API-mediated access only              |
| **Event Sourcing**            | State changes propagated via immutable events   | Audit trail, temporal queries, replay capability | Service Bus for all cross-service communication            |
| **Data at Rest Encryption**   | All persistent data encrypted                   | Compliance, security posture                     | Azure SQL TDE, Storage Service Encryption enabled          |
| **Schema Evolution**          | All schemas support backward-compatible changes | Zero-downtime deployments                        | Additive changes only, versioned APIs for breaking changes |
| **Trace Context Propagation** | All messages include W3C Trace Context          | End-to-end correlation                           | TraceId, SpanId in Service Bus ApplicationProperties       |

---

## 🗺️ Data Landscape Map

```mermaid
---
title: Data Landscape Map
---
flowchart LR
    %% ===== BUSINESS DATA DOMAINS =====
    subgraph BusinessDomains["📊 Business Data Domains"]
        Orders["📦 Orders Domain"]
        Events["📨 Order Events Domain"]
    end

    %% ===== TRANSACTIONAL STORES =====
    subgraph TransactionalStores["🗄️ Transactional Stores"]
        OrderDb[("OrderDb<br/>Azure SQL")]
    end

    %% ===== MESSAGING STORES =====
    subgraph MessagingStores["📨 Messaging Stores"]
        Topic["ordersplaced<br/>Service Bus Topic"]
        Sub["orderprocessingsub<br/>Subscription"]
    end

    %% ===== WORKFLOW STORES =====
    subgraph WorkflowStores["📁 Workflow Stores"]
        BlobSuccess["Success Blobs<br/>/ordersprocessedsuccessfully"]
        BlobError["Error Blobs<br/>/ordersprocessedwitherrors"]
    end

    %% ===== TELEMETRY STORES =====
    subgraph TelemetryStores["📊 Telemetry Stores"]
        AppInsights["Application Insights"]
        LogAnalytics["Log Analytics"]
    end

    %% ===== CONNECTIONS =====
    Orders -->|"persists to"| OrderDb
    Orders -->|"publishes to"| Topic
    Events -->|"flows through"| Topic
    Topic -->|"delivers to"| Sub
    Sub -->|"stores success"| BlobSuccess
    Sub -->|"stores errors"| BlobError
    OrderDb -.->|"emits telemetry"| AppInsights
    Topic -.->|"emits diagnostics"| LogAnalytics

    %% ===== STYLES - NODE CLASSES =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5

    %% ===== CLASS ASSIGNMENTS =====
    class Orders,Events primary
    class OrderDb datastore
    class Topic,Sub secondary
    class BlobSuccess,BlobError datastore
    class AppInsights,LogAnalytics external

    %% ===== SUBGRAPH STYLES =====
    style BusinessDomains fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style TransactionalStores fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style MessagingStores fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style WorkflowStores fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style TelemetryStores fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
```

---

## 📂 Data Domain Catalog

| Data Domain               | Description                      | Bounded Context | Primary Store | Owner Service | Steward               |
| ------------------------- | -------------------------------- | --------------- | ------------- | ------------- | --------------------- |
| **Order Management**      | Customer orders and line items   | eShop.Orders    | Azure SQL     | Orders API    | Order Management Team |
| **Order Events**          | Immutable order lifecycle events | Messaging       | Service Bus   | Platform      | Platform Team         |
| **Workflow State**        | Logic App execution artifacts    | Automation      | Azure Storage | Logic Apps    | Workflow Team         |
| **Operational Telemetry** | Traces, metrics, logs            | Observability   | App Insights  | All Services  | SRE Team              |

---

## 🗃️ Data Store Details

| Store                  | Technology                 | Purpose                       | Owner Service                | Location                    | Tier/SKU        |
| ---------------------- | -------------------------- | ----------------------------- | ---------------------------- | --------------------------- | --------------- |
| **OrderDb**            | Azure SQL Database         | Order and product persistence | eShop.Orders.API             | Azure / Local SQL Container | General Purpose |
| **ordersplaced**       | Service Bus Topic          | Order event propagation       | eShop.Orders.API (publisher) | Azure / Local Emulator      | Standard        |
| **orderprocessingsub** | Service Bus Subscription   | Order event consumption       | Logic Apps (subscriber)      | Azure / Local Emulator      | Standard        |
| **Workflow State**     | Azure Storage (File Share) | Logic App workflow state      | OrdersManagement Logic App   | Azure Storage Account       | Standard LRS    |
| **Success Blobs**      | Azure Blob Storage         | Processed order artifacts     | Logic Apps                   | Azure Storage Account       | Standard LRS    |
| **Error Blobs**        | Azure Blob Storage         | Failed order artifacts        | Logic Apps                   | Azure Storage Account       | Standard LRS    |

---

## 🔀 Data Flow Architecture

### Write Path (Order Placement)

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant Web as 🌐 Web App
    participant API as 📡 Orders API
    participant DB as 🗄️ SQL Database
    participant SB as 📨 Service Bus
    participant LA as 🔄 Logic App

    User->>Web: Submit Order Form
    Web->>API: POST /api/orders
    API->>API: Validate Order
    API->>DB: INSERT Order + Products
    DB-->>API: Confirmation
    API->>SB: Publish OrderPlaced Message
    Note over API,SB: Message includes TraceId, SpanId
    SB-->>API: Acknowledgment
    API-->>Web: 201 Created + Order
    Web-->>User: Success Message

    Note over SB,LA: Async Processing
    SB->>LA: Trigger: Service Bus Message
    LA->>LA: Execute OrdersPlacedProcess
    LA->>API: POST /api/orders/process
    API-->>LA: 201 Created
    LA->>LA: Store to Success Blob
```

### Read Path (Order Retrieval)

```mermaid
sequenceDiagram
    autonumber
    participant User as 👤 User
    participant Web as 🌐 Web App
    participant API as 📡 Orders API
    participant DB as 🗄️ SQL Database

    User->>Web: View Orders Page
    Web->>API: GET /api/orders
    API->>DB: SELECT Orders with Products
    Note over API,DB: EF Core eager loading
    DB-->>API: Order Data
    API-->>Web: JSON Order Collection
    Web-->>User: Render Orders Grid
```

---

## 📊 Monitoring Data Flow Architecture

```mermaid
---
title: Monitoring Data Flow Architecture
---
flowchart LR
    %% ===== TELEMETRY SOURCES =====
    subgraph Sources["📡 Layer 1: Telemetry Sources"]
        API["⚙️ Orders API"]
        Web["🌐 Web App"]
        LA["🔄 Logic Apps"]
        SB["📨 Service Bus"]
        SQL["🗄️ SQL Database"]
    end

    %% ===== INSTRUMENTATION =====
    subgraph Instrumentation["🔧 Layer 2: Instrumentation"]
        OTEL["OpenTelemetry SDK<br/><i>Traces, Metrics, Logs</i>"]
        AzDiag["Azure Diagnostics<br/><i>Platform telemetry</i>"]
    end

    %% ===== COLLECTION =====
    subgraph Collection["📥 Layer 3: Collection"]
        AI["Application Insights<br/><i>APM & Traces</i>"]
        LAW["Log Analytics<br/><i>Logs & Diagnostics</i>"]
    end

    %% ===== VISUALIZATION =====
    subgraph Visualization["📈 Layer 4: Visualization"]
        AppMap["Application Map"]
        TxSearch["Transaction Search"]
        Dashboards["Azure Dashboards"]
        Alerts["Alert Rules"]
    end

    %% ===== CONNECTIONS =====
    API -->|"sends OTLP/HTTP"| OTEL
    Web -->|"sends OTLP/HTTP"| OTEL
    LA -->|"exports ARM Diagnostics"| AzDiag
    SB -->|"exports ARM Diagnostics"| AzDiag
    SQL -->|"exports ARM Diagnostics"| AzDiag
    OTEL -->|"exports to"| AI
    AzDiag -->|"exports to"| LAW
    AI -->|"forwards to"| LAW
    AI -->|"renders"| AppMap
    AI -->|"renders"| TxSearch
    LAW -->|"renders"| Dashboards
    LAW -->|"triggers"| Alerts

    %% ===== STYLES - NODE CLASSES =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5

    %% ===== CLASS ASSIGNMENTS =====
    class API,Web,LA,SB,SQL primary
    class OTEL,AzDiag secondary
    class AI,LAW datastore
    class AppMap,TxSearch,Dashboards,Alerts external

    %% ===== SUBGRAPH STYLES =====
    style Sources fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Instrumentation fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style Collection fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style Visualization fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
```

---

## 📡 Telemetry Data Mapping

### Three Pillars of Observability

| Pillar      | Description                                 | Data Type                                | Use Case                              | Storage               |
| ----------- | ------------------------------------------- | ---------------------------------------- | ------------------------------------- | --------------------- |
| **Traces**  | Distributed request flow across services    | Spans with TraceId, SpanId, ParentSpanId | End-to-end transaction analysis       | Application Insights  |
| **Metrics** | Numeric measurements aggregated over time   | Counters, Gauges, Histograms             | Dashboards, alerts, capacity planning | Azure Monitor Metrics |
| **Logs**    | Discrete events with contextual information | Structured JSON with properties          | Debugging, auditing, investigation    | Log Analytics         |

### Metrics Inventory by Source

#### Orders API Metrics

| Metric                             | Type      | Unit    | Dimensions            | Alert Threshold |
| ---------------------------------- | --------- | ------- | --------------------- | --------------- |
| `http.server.request.duration`     | Histogram | seconds | method, route, status | P95 > 2s        |
| `eShop.orders.placed`              | Counter   | count   | order.status          | N/A             |
| `eShop.orders.processing.duration` | Histogram | ms      | order.status          | P95 > 5s        |
| `eShop.orders.processing.errors`   | Counter   | error   | error.type            | > 10/min        |
| `eShop.orders.deleted`             | Counter   | count   | -                     | N/A             |

#### Platform Metrics (Azure Monitor)

| Source           | Metric                    | Type    | Purpose                 |
| ---------------- | ------------------------- | ------- | ----------------------- |
| **Service Bus**  | `ActiveMessages`          | Gauge   | Queue depth monitoring  |
| **Service Bus**  | `DeadLetteredMessages`    | Gauge   | Failed message tracking |
| **SQL Database** | `cpu_percent`             | Gauge   | Database load           |
| **SQL Database** | `dtu_consumption_percent` | Gauge   | DTU utilization         |
| **Logic Apps**   | `RunsSucceeded`           | Counter | Workflow success rate   |
| **Logic Apps**   | `RunsFailed`              | Counter | Workflow failure rate   |

### Logs Inventory by Source

| Log Type         | Source       | Level       | Format            | Retention |
| ---------------- | ------------ | ----------- | ----------------- | --------- |
| Request Logs     | Orders API   | Information | Structured JSON   | 90 days   |
| Error Logs       | All Services | Error       | Structured JSON   | 90 days   |
| Workflow Runs    | Logic Apps   | Information | Azure Diagnostics | 30 days   |
| Database Logs    | SQL Database | Warning+    | Azure Diagnostics | 30 days   |
| Service Bus Logs | Service Bus  | Warning+    | Azure Diagnostics | 30 days   |

### Structured Logging Format

```json
{
  "Timestamp": "2026-01-20T10:30:00.000Z",
  "Level": "Information",
  "MessageTemplate": "Order {OrderId} placed successfully",
  "Properties": {
    "OrderId": "ORD-2026-001",
    "CustomerId": "CUST-100",
    "Total": 149.99,
    "TraceId": "abc123def456...",
    "SpanId": "789ghi012...",
    "RequestPath": "/api/orders",
    "SourceContext": "eShop.Orders.API.Services.OrderService"
  }
}
```

---

## 🔗 Trace Context Propagation

> [!TIP]
> The solution implements **W3C Trace Context** for cross-service correlation:

```mermaid
---
title: W3C Trace Context Flow
---
flowchart LR
    %% ===== TRACE CONTEXT FLOW =====
    subgraph TraceContext["🔗 W3C Trace Context Flow"]
        HTTP["HTTP Request<br/><code>traceparent</code> header"]
        SB["Service Bus<br/><code>ApplicationProperties</code>"]
        LA["Logic Apps<br/><code>x-ms-workflow-run-id</code>"]
        AI["App Insights<br/><code>Operation ID</code>"]
    end

    %% ===== CONNECTIONS =====
    HTTP -->|"Propagates to"| SB
    SB -->|"Extracts for"| LA
    HTTP -->|"Auto-captures to"| AI
    LA -.->|"Correlates with"| AI

    %% ===== STYLES - NODE CLASSES =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF

    %% ===== CLASS ASSIGNMENTS =====
    class HTTP,SB,LA,AI primary

    %% ===== SUBGRAPH STYLES =====
    style TraceContext fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
```

### Implementation in OrdersMessageHandler

```csharp
// From src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs
message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();
message.ApplicationProperties["traceparent"] = activity.Id ?? string.Empty;
```

---

## 📌 Data Dependencies Map

```mermaid
---
title: Data Dependencies Map
---
flowchart TD
    %% ===== UPSTREAM (DATA PRODUCERS) =====
    subgraph Upstream["⬆️ Upstream (Data Producers)"]
        WebApp["🌐 Web App<br/>(Order Input)"]
    end

    %% ===== CORE DATA ASSETS =====
    subgraph CoreAssets["🎯 Core Data Assets"]
        OrderDb[("🗄️ OrderDb<br/>Azure SQL")]
        EventBus["📨 Service Bus<br/>ordersplaced"]
    end

    %% ===== DOWNSTREAM (DATA CONSUMERS) =====
    subgraph Downstream["⬇️ Downstream (Data Consumers)"]
        LogicApp["🔄 Logic Apps<br/>(Workflow Automation)"]
        AppInsights["📊 App Insights<br/>(Analytics & Monitoring)"]
    end

    %% ===== CONNECTIONS =====
    WebApp -->|"Creates orders"| OrderDb
    OrderDb -->|"Publishes events"| EventBus
    EventBus -->|"Triggers workflows"| LogicApp
    OrderDb -.->|"Emits telemetry"| AppInsights
    LogicApp -.->|"Emits telemetry"| AppInsights

    %% ===== STYLES - NODE CLASSES =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF

    %% ===== CLASS ASSIGNMENTS =====
    class WebApp primary
    class OrderDb,EventBus datastore
    class LogicApp,AppInsights secondary

    %% ===== SUBGRAPH STYLES =====
    style Upstream fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style CoreAssets fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style Downstream fill:#ECFDF5,stroke:#10B981,stroke-width:2px
```

---

## 🔄 Data Lifecycle States

| Stage           | Description                 | Location          | Duration     | Transition Trigger    |
| --------------- | --------------------------- | ----------------- | ------------ | --------------------- |
| **Creation**    | Order submitted via API     | Orders API memory | Milliseconds | Validation passes     |
| **Persistence** | Order saved to database     | Azure SQL         | Indefinite   | Transaction commit    |
| **Publication** | Order event published       | Service Bus topic | 14 days TTL  | Post-commit hook      |
| **Consumption** | Event processed by workflow | Logic App         | Minutes      | Subscription delivery |
| **Telemetry**   | Operational data captured   | App Insights      | 90 days      | Continuous            |

---

## 🌐 Cross-Architecture Relationships

| Related Architecture           | Connection                                             | Reference                                                                  |
| ------------------------------ | ------------------------------------------------------ | -------------------------------------------------------------------------- |
| **Business Architecture**      | Orders data supports Order Management capability       | [Business Capabilities](01-business-architecture.md#business-capabilities) |
| **Application Architecture**   | Orders API service manages Order data entities         | [Application Architecture](03-application-architecture.md)                 |
| **Technology Architecture**    | Azure SQL hosts OrderDb; Service Bus transports events | [Technology Architecture](04-technology-architecture.md)                   |
| **Observability Architecture** | Telemetry data flows to App Insights for monitoring    | [Observability Architecture](05-observability-architecture.md)             |

---

<div align="center">

[← Business Architecture](01-business-architecture.md) | **Data Layer** | [Application Architecture →](03-application-architecture.md)

</div>
