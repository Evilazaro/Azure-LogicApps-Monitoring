# Data Architecture Documentation

> **Repository:** Evilazaro/Azure-LogicApps-Monitoring  
> **Document Version:** 1.0  
> **Date:** 2026-01-28  
> **Classification:** TOGAF ADM Phase C - Data Architecture

---

## Table of Contents

- [Data Architecture Overview](#311-data-architecture-overview)
- [Data Entities & Models](#312-data-entities--models)
- [Data Stores Landscape](#313-data-stores-landscape)
- [Data Flow Architecture](#314-data-flow-architecture)
- [Monitoring Data Flow Architecture](#315-monitoring-data-flow-architecture)
- [Data State Management](#316-data-state-management)
- [Data Security & Governance](#317-data-security--governance)
- [Data Infrastructure (IaC)](#318-data-infrastructure-iac)

---

## 3.1.1 Data Architecture Overview

### TOGAF BDAT Framework

This documentation follows the TOGAF Business Data Architecture (BDAT) classification model to organize data components into four distinct categories: **System of Record (SoR)** for authoritative data sources, **System of Reference (SoRef)** for shared reference data and archives, **System of Engagement (SoE)** for transient interaction data, and **System of Insight (SoI)** for observability and analytics. This framework ensures clear data ownership, consistent governance, and aligned data management practices across the solution.

### Executive Summary

The eShop Orders Management solution implements a cloud-native data architecture on Microsoft Azure, centered around an event-driven order processing workflow. The architecture integrates a Blazor frontend (eShop.Web.App), an ASP.NET Core REST API (eShop.Orders.API), and an Azure Logic App workflow (OrdersPlacedProcess) that orchestrates asynchronous order processing through Azure Service Bus messaging.

Core data patterns include persistent relational storage via Azure SQL Database for order data, event-driven pub/sub messaging through Azure Service Bus topics, and blob-based archival storage for processed orders. The architecture employs Entity Framework Core for data access with a clear separation between domain models (Order, OrderProduct) and database entities (OrderEntity, OrderProductEntity).

The observability strategy leverages OpenTelemetry for distributed tracing, custom metrics via System.Diagnostics.Metrics, and structured logging exported to Azure Application Insights and Log Analytics Workspace. All infrastructure is defined as code using Bicep templates, ensuring reproducible deployments and version-controlled configuration.

### Data Architecture Principles

| Principle                   | Description                                    | Implementation                                     |
| --------------------------- | ---------------------------------------------- | -------------------------------------------------- |
| **Single Source of Truth**  | Each data element has one authoritative source | Azure SQL Database (OrderDb) as SoR for order data |
| **Event-Driven Processing** | Decouple producers and consumers via messaging | Service Bus topics with subscription-based routing |
| **Immutable Audit Trail**   | Processed orders archived for compliance       | Blob containers for success/error order archives   |
| **Defense in Depth**        | Multiple security layers for data protection   | Entra ID auth, TLS 1.2, Private Endpoints          |
| **Observable by Design**    | Built-in telemetry at every layer              | OpenTelemetry + Application Insights integration   |

### TOGAF BDAT Alignment

- 💾 **System of Record (SoR):** Azure SQL Database (OrderDb) - Authoritative source for order data
- 📚 **System of Reference (SoRef):** Azure Storage Account (blob containers, file share) - Processed order archives and workflow state
- ⚡ **System of Engagement (SoE):** Azure Service Bus (ordersplaced topic) - Transient message queue for order processing
- 📊 **System of Insight (SoI):** Log Analytics Workspace, Application Insights - Observability and analytics data

### Data Architecture Overview Diagram

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif',
    'fontSize': '13px',
    'lineColor': '#546e7a',
    'textColor': '#263238',
    'mainBkg': '#ffffff',
    'nodeBorder': '#78909c',
    'clusterBkg': '#eceff1',
    'clusterBorder': '#b0bec5',
    'primaryColor': '#bbdefb',
    'primaryBorderColor': '#1e88e5',
    'primaryTextColor': '#0d47a1'
  }
}}%%
flowchart TB
    classDef sor fill:#bbdefb,stroke:#1e88e5,stroke-width:2px,color:#0d47a1,rx:8,ry:8
    classDef soref fill:#b2dfdb,stroke:#00897b,stroke-width:2px,color:#004d40,rx:8,ry:8
    classDef soe fill:#ffe082,stroke:#ffb300,stroke-width:2px,color:#e65100,rx:8,ry:8
    classDef soi fill:#d1c4e9,stroke:#5e35b1,stroke-width:2px,color:#311b92,rx:8,ry:8
    classDef external fill:#cfd8dc,stroke:#546e7a,stroke-width:2px,color:#263238,rx:8,ry:8
    classDef api fill:#b3e5fc,stroke:#039be5,stroke-width:2px,color:#01579b,rx:6,ry:6
    classDef workflow fill:#e1bee7,stroke:#8e24aa,stroke-width:2px,color:#4a148c,rx:6,ry:6

    subgraph EXT["🌐 External Layer"]
        HTTPClient{{"HTTP Client<br/>[Ext]"}}
    end

    subgraph APP["⚙️ Application Layer"]
        WebApp["eShop.Web.App<br/>Blazor<br/>[Frontend]"]
        OrdersAPI["eShop.Orders.API<br/>ASP.NET Core<br/>[API]"]
        LogicApp["OrdersPlacedProcess<br/>Logic App<br/>[Workflow]"]
    end

    subgraph DATA["💾 Data Layer"]
        subgraph SOR["💾 System of Record"]
            OrderDB[("OrderDb<br/>Azure SQL<br/>[SoR]")]
        end
        subgraph SOE["⚡ System of Engagement"]
            ServiceBus[["ordersplaced<br/>Service Bus Topic<br/>[SoE]"]]
        end
        subgraph SOREF["📚 System of Reference"]
            BlobStorage>"Blob Containers<br/>Azure Storage<br/>[SoRef]"]
            FileShare>"workflowstate<br/>File Share<br/>[SoRef]"]
        end
    end

    subgraph MON["📊 Monitoring Layer"]
        AppInsights["Application Insights<br/>Traces & Metrics<br/>[SoI]"]
        LogAnalytics["Log Analytics<br/>Workspace<br/>[SoI]"]
    end

    HTTPClient -->|"REST/HTTPS"| WebApp
    HTTPClient -->|"REST/HTTPS"| OrdersAPI
    WebApp -->|"REST/HTTPS"| OrdersAPI
    OrdersAPI -->|"EF Core/SQL"| OrderDB
    OrdersAPI -.->|"AMQP"| ServiceBus
    ServiceBus -.->|"Trigger"| LogicApp
    LogicApp -->|"REST/HTTPS"| OrdersAPI
    LogicApp -->|"Blob API"| BlobStorage
    LogicApp -->|"SMB"| FileShare
    OrdersAPI -.->|"OTLP"| AppInsights
    LogicApp -.->|"Diagnostics"| LogAnalytics
    AppInsights -->|"Export"| LogAnalytics

    class HTTPClient external
    class WebApp,OrdersAPI api
    class LogicApp workflow
    class OrderDB sor
    class ServiceBus soe
    class BlobStorage,FileShare soref
    class AppInsights,LogAnalytics soi
```

---

## 3.1.2 Data Entities & Models

### Overview

The domain model centers on the Order aggregate, which represents customer purchase transactions with associated line items. The solution employs a clear separation between database entities (OrderEntity, OrderProductEntity) persisted via Entity Framework Core and domain transfer objects (Order, OrderProduct) used for API communication and business logic.

### Entity Inventory

| Entity             | Primary Key | Foreign Keys             | Source File                                                                                                          |
| ------------------ | ----------- | ------------------------ | -------------------------------------------------------------------------------------------------------------------- |
| OrderEntity        | Id (string) | None                     | [src/eShop.Orders.API/data/Entities/OrderEntity.cs](src/eShop.Orders.API/data/Entities/OrderEntity.cs)               |
| OrderProductEntity | Id (string) | OrderId → OrderEntity.Id | [src/eShop.Orders.API/data/Entities/OrderProductEntity.cs](src/eShop.Orders.API/data/Entities/OrderProductEntity.cs) |
| Order (DTO)        | Id (string) | None                     | [app.ServiceDefaults/CommonTypes.cs](app.ServiceDefaults/CommonTypes.cs)                                             |
| OrderProduct (DTO) | Id (string) | OrderId → Order.Id       | [app.ServiceDefaults/CommonTypes.cs](app.ServiceDefaults/CommonTypes.cs)                                             |

### Entity Attributes

**OrderEntity** (Database Entity)

- `Id`: string(100) - Primary Key
- `CustomerId`: string(100) - Customer identifier
- `Date`: DateTime - Order creation timestamp
- `DeliveryAddress`: string(500) - Shipping address
- `Total`: decimal(18,2) - Order total amount
- `Products`: ICollection\<OrderProductEntity\> - Navigation property

**OrderProductEntity** (Database Entity)

- `Id`: string(100) - Primary Key
- `OrderId`: string(100) - Foreign Key to OrderEntity
- `ProductId`: string(100) - Product identifier
- `ProductDescription`: string(500) - Product description
- `Quantity`: int - Quantity ordered
- `Price`: decimal(18,2) - Unit price

### Relationships & Indexes

**Relationships:**

- OrderEntity → OrderProductEntity: **One-to-Many** (Cascade Delete on OrderEntity deletion)

**Database Indexes:**

- Orders Table:
  - `IX_Orders_CustomerId` (CustomerId column)
  - `IX_Orders_Date` (Date column)
- OrderProducts Table:
  - `IX_OrderProducts_OrderId` (OrderId column - FK index)
  - `IX_OrderProducts_ProductId` (ProductId column)

### Entity-Relationship Diagram

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Roboto, sans-serif',
    'fontSize': '12px',
    'primaryColor': '#bbdefb',
    'primaryBorderColor': '#1e88e5',
    'primaryTextColor': '#0d47a1',
    'lineColor': '#546e7a',
    'attributeBackgroundColorOdd': '#eceff1',
    'attributeBackgroundColorEven': '#ffffff'
  }
}}%%
erDiagram
    ORDER_ENTITY ||--o{ ORDER_PRODUCT_ENTITY : "contains"

    ORDER_ENTITY {
        string Id PK "Primary Key - 100 chars"
        string CustomerId "Customer identifier - 100 chars"
        datetime Date "Order date"
        string DeliveryAddress "Delivery address - 500 chars"
        decimal Total "Order total - precision 18,2"
    }

    ORDER_PRODUCT_ENTITY {
        string Id PK "Primary Key - 100 chars"
        string OrderId FK "Foreign Key to ORDER_ENTITY"
        string ProductId "Product identifier - 100 chars"
        string ProductDescription "Product description - 500 chars"
        int Quantity "Product quantity"
        decimal Price "Unit price - precision 18,2"
    }

    ORDER ||--o{ ORDER_PRODUCT : "contains"

    ORDER {
        string Id PK "Domain model ID"
        string CustomerId "Customer identifier"
        datetime Date "Order date"
        string DeliveryAddress "Delivery address"
        decimal Total "Order total"
    }

    ORDER_PRODUCT {
        string Id PK "Domain model ID"
        string OrderId FK "Reference to Order"
        string ProductId "Product identifier"
        string ProductDescription "Product description"
        int Quantity "Product quantity"
        decimal Price "Unit price"
    }
```

---

## 3.1.3 Data Stores Landscape

### Storage Strategy Overview

The data storage strategy implements a multi-tier approach aligned with TOGAF classifications. Persistent relational data resides in Azure SQL Database, transient messaging flows through Azure Service Bus, reference data and archives are stored in Azure Blob Storage, and observability data aggregates in Azure Log Analytics. Each store is configured for its specific persistence and access patterns.

### 💾 System of Record (SoR)

| Store   | Technology                                | Purpose                             | Source                                                       |
| ------- | ----------------------------------------- | ----------------------------------- | ------------------------------------------------------------ |
| OrderDb | Azure SQL Database (Gen5, 2 vCores, 32GB) | Authoritative source for order data | [infra/shared/data/main.bicep](infra/shared/data/main.bicep) |

### 📚 System of Reference (SoRef)

| Store                       | Technology                              | Purpose                                | Source                                                       |
| --------------------------- | --------------------------------------- | -------------------------------------- | ------------------------------------------------------------ |
| Workflow Storage Account    | Azure Storage (StorageV2, Standard_LRS) | Blob containers and file share storage | [infra/shared/data/main.bicep](infra/shared/data/main.bicep) |
| ordersprocessedsuccessfully | Blob Container                          | Successfully processed orders archive  | [infra/shared/data/main.bicep](infra/shared/data/main.bicep) |
| ordersprocessedwitherrors   | Blob Container                          | Orders with processing errors          | [infra/shared/data/main.bicep](infra/shared/data/main.bicep) |
| ordersprocessedcompleted    | Blob Container                          | Completed order processing             | [infra/shared/data/main.bicep](infra/shared/data/main.bicep) |
| workflowstate               | File Share (5GB, SMB)                   | Logic App workflow state persistence   | [infra/shared/data/main.bicep](infra/shared/data/main.bicep) |

### ⚡ System of Engagement (SoE)

| Store                 | Technology                        | Purpose                             | Source                                                                     |
| --------------------- | --------------------------------- | ----------------------------------- | -------------------------------------------------------------------------- |
| Service Bus Namespace | Azure Service Bus (Standard tier) | Message broker for async processing | [infra/workload/messaging/main.bicep](infra/workload/messaging/main.bicep) |
| ordersplaced (Topic)  | Service Bus Topic                 | Pub/sub for order placed events     | [infra/workload/messaging/main.bicep](infra/workload/messaging/main.bicep) |
| orderprocessingsub    | Service Bus Subscription          | Logic App trigger subscription      | [infra/workload/messaging/main.bicep](infra/workload/messaging/main.bicep) |

### 📊 System of Insight (SoI)

| Store                   | Technology                           | Purpose                     | Source                                                                                                         |
| ----------------------- | ------------------------------------ | --------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Log Analytics Workspace | Azure Log Analytics (PerGB2018)      | Centralized log aggregation | [infra/shared/monitoring/log-analytics-workspace.bicep](infra/shared/monitoring/log-analytics-workspace.bicep) |
| Application Insights    | Azure App Insights (workspace-based) | APM and distributed tracing | [infra/shared/monitoring/app-insights.bicep](infra/shared/monitoring/app-insights.bicep)                       |

### Configuration Details

**Service Bus:**

- Topic: `ordersplaced`
- Subscription: `orderprocessingsub`
  - maxDeliveryCount: 10
  - lockDuration: PT5M (5 minutes)
  - defaultMessageTimeToLive: P14D (14 days)
  - deadLetteringOnMessageExpiration: true

**SQL Server:**

- Authentication: Entra ID-only (azureADOnlyAuthentication: true)
- TLS: 1.2 minimum
- Network: Private endpoint with Private DNS Zone

### Data Stores Landscape Diagram

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif',
    'fontSize': '13px',
    'lineColor': '#546e7a',
    'textColor': '#263238',
    'clusterBkg': '#eceff1',
    'clusterBorder': '#b0bec5'
  }
}}%%
flowchart TB
    classDef sor fill:#bbdefb,stroke:#1e88e5,stroke-width:2px,color:#0d47a1,rx:8,ry:8
    classDef soref fill:#b2dfdb,stroke:#00897b,stroke-width:2px,color:#004d40,rx:8,ry:8
    classDef soe fill:#ffe082,stroke:#ffb300,stroke-width:2px,color:#e65100,rx:8,ry:8
    classDef soi fill:#d1c4e9,stroke:#5e35b1,stroke-width:2px,color:#311b92,rx:8,ry:8

    subgraph SOR["💾 System of Record (SoR) - Persistent"]
        direction TB
        OrderDB[("OrderDb<br/>Azure SQL Database<br/>Gen5, 2 vCores, 32GB<br/>Entra ID Auth, TLS 1.2")]
    end

    subgraph SOE["⚡ System of Engagement (SoE) - Distributed"]
        direction TB
        SBNamespace[["Service Bus Namespace<br/>Standard Tier"]]
        SBTopic[["ordersplaced Topic<br/>Pub/Sub Pattern"]]
        SBSub[["orderprocessingsub<br/>maxDelivery: 10<br/>TTL: 14 days"]]
        SBNamespace --> SBTopic
        SBTopic --> SBSub
    end

    subgraph SOREF["📚 System of Reference (SoRef) - Persistent"]
        direction TB
        StorageAccount>"Workflow Storage Account<br/>StorageV2, Standard_LRS"]
        BlobSuccess>"ordersprocessedsuccessfully<br/>Blob Container"]
        BlobErrors>"ordersprocessedwitherrors<br/>Blob Container"]
        BlobCompleted>"ordersprocessedcompleted<br/>Blob Container"]
        FileShare>"workflowstate<br/>File Share, 5GB, SMB"]
        StorageAccount --> BlobSuccess
        StorageAccount --> BlobErrors
        StorageAccount --> BlobCompleted
        StorageAccount --> FileShare
    end

    subgraph SOI["📊 System of Insight (SoI) - Persistent"]
        direction TB
        LogAnalytics["Log Analytics Workspace<br/>PerGB2018, 30 days retention"]
        AppInsights["Application Insights<br/>Workspace-based, Kind: web"]
        DiagStorage>"Diagnostic Storage<br/>30 days lifecycle"]
        AppInsights --> LogAnalytics
        DiagStorage --> LogAnalytics
    end

    class OrderDB sor
    class SBNamespace,SBTopic,SBSub soe
    class StorageAccount,BlobSuccess,BlobErrors,BlobCompleted,FileShare soref
    class LogAnalytics,AppInsights,DiagStorage soi
```

---

## 3.1.4 Data Flow Architecture

### Data Flow Overview

The data flow architecture implements both synchronous REST/HTTP patterns for client interactions and asynchronous AMQP messaging for event-driven order processing. Inbound flows accept orders via the API, processing flows validate and persist data, internal flows publish events to Service Bus, and outbound flows return order data to clients or archive processed orders to blob storage.

### 📥 Inbound Flows

| Flow              | Source      | Target           | Protocol       | Source File                                                                                                                                                                    |
| ----------------- | ----------- | ---------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| PlaceOrder        | HTTP Client | OrdersController | REST/HTTP POST | [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                   |
| PlaceOrdersBatch  | HTTP Client | OrdersController | REST/HTTP POST | [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                   |
| ProcessOrder      | HTTP Client | OrdersController | REST/HTTP POST | [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                   |
| ServiceBusTrigger | Service Bus | Logic App        | AMQP           | [workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json](workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) |

### ⚙️ Processing Flows

| Flow             | Source       | Target          | Protocol       | Source File                                                                                                                                                                    |
| ---------------- | ------------ | --------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| OrderValidation  | OrderService | OrderService    | In-process     | [src/eShop.Orders.API/Services/OrderService.cs](src/eShop.Orders.API/Services/OrderService.cs)                                                                                 |
| OrderToEntity    | OrderMapper  | OrderRepository | In-process     | [src/eShop.Orders.API/data/OrderMapper.cs](src/eShop.Orders.API/data/OrderMapper.cs)                                                                                           |
| LogicAppHttpCall | Logic App    | Orders API      | REST/HTTP POST | [workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json](workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) |

### 🔄 Internal Flows

| Flow                | Source               | Target               | Protocol    | Source File                                                                                                    |
| ------------------- | -------------------- | -------------------- | ----------- | -------------------------------------------------------------------------------------------------------------- |
| SaveOrder           | OrderService         | OrderRepository      | EF Core/SQL | [src/eShop.Orders.API/Repositories/OrderRepository.cs](src/eShop.Orders.API/Repositories/OrderRepository.cs)   |
| PublishOrderMessage | OrderService         | OrdersMessageHandler | In-process  | [src/eShop.Orders.API/Services/OrderService.cs](src/eShop.Orders.API/Services/OrderService.cs)                 |
| SendToServiceBus    | OrdersMessageHandler | Service Bus          | AMQP        | [src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs](src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs) |

### 📤 Outbound Flows

| Flow             | Source           | Target       | Protocol       | Source File                                                                                                                                                                    |
| ---------------- | ---------------- | ------------ | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| GetOrders        | OrdersController | HTTP Client  | REST/HTTP GET  | [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                   |
| GetOrderById     | OrdersController | HTTP Client  | REST/HTTP GET  | [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                   |
| BlobSuccessWrite | Logic App        | Storage Blob | Azure Blob API | [workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json](workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) |
| BlobErrorWrite   | Logic App        | Storage Blob | Azure Blob API | [workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json](workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) |

### Data Flow Diagram

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif',
    'fontSize': '13px',
    'lineColor': '#546e7a',
    'textColor': '#263238'
  }
}}%%
flowchart LR
    classDef inbound fill:#b3e5fc,stroke:#039be5,stroke-width:2px,color:#01579b,rx:6,ry:6
    classDef processing fill:#ffcc80,stroke:#fb8c00,stroke-width:2px,color:#e65100,rx:6,ry:6
    classDef storage fill:#c5cae9,stroke:#3949ab,stroke-width:2px,color:#1a237e,rx:6,ry:6
    classDef outbound fill:#c5e1a5,stroke:#7cb342,stroke-width:2px,color:#33691e,rx:6,ry:6
    classDef external fill:#cfd8dc,stroke:#546e7a,stroke-width:2px,color:#263238,rx:8,ry:8

    subgraph IN["📥 Inbound Flows"]
        direction TB
        Client{{"HTTP Client"}}
        PlaceOrder["PlaceOrder<br/>POST /api/orders"]
        PlaceBatch["PlaceOrdersBatch<br/>POST /api/orders/batch"]
        ProcessOrder["ProcessOrder<br/>POST /api/orders/process"]
        SBTrigger["ServiceBusTrigger<br/>AMQP Message"]
    end

    subgraph PROC["⚙️ Processing Flows"]
        direction TB
        OrdersCtrl["OrdersController<br/>ASP.NET Core"]
        OrderSvc["OrderService<br/>Validation & Business Logic"]
        OrderMapper["OrderMapper<br/>Entity Transformation"]
        MsgHandler["OrdersMessageHandler<br/>Message Publishing"]
        LogicApp["Logic App<br/>OrdersPlacedProcess"]
    end

    subgraph STORE["💾 Storage Flows"]
        direction TB
        OrderRepo["OrderRepository<br/>EF Core"]
        OrderDB[("OrderDb<br/>Azure SQL")]
        ServiceBus[["Service Bus<br/>ordersplaced"]]
        BlobSuccess>"ordersprocessed<br/>successfully"]
        BlobError>"ordersprocessed<br/>witherrors"]
    end

    subgraph OUT["📤 Outbound Flows"]
        direction TB
        GetOrders["GetOrders<br/>GET /api/orders"]
        GetById["GetOrderById<br/>GET /api/orders/{id}"]
        Response{{"HTTP Response<br/>Order JSON"}}
    end

    Client -->|"REST/HTTP POST<br/>Order JSON"| PlaceOrder
    Client -->|"REST/HTTP POST<br/>Order[] JSON"| PlaceBatch
    Client -->|"REST/HTTP POST<br/>Order JSON"| ProcessOrder
    ServiceBus -.->|"AMQP<br/>ServiceBusMessage"| SBTrigger

    PlaceOrder --> OrdersCtrl
    PlaceBatch --> OrdersCtrl
    ProcessOrder --> OrdersCtrl
    SBTrigger --> LogicApp

    OrdersCtrl --> OrderSvc
    OrderSvc --> OrderMapper
    OrderSvc --> MsgHandler
    LogicApp -->|"HTTP POST"| OrdersCtrl

    OrderMapper --> OrderRepo
    OrderRepo -->|"INSERT/UPDATE<br/>OrderEntity"| OrderDB
    MsgHandler -.->|"Publish<br/>ServiceBusMessage"| ServiceBus
    LogicApp -->|"Write Success<br/>Order Binary"| BlobSuccess
    LogicApp -->|"Write Error<br/>Order Binary"| BlobError

    OrderDB --> GetOrders
    OrderDB --> GetById
    GetOrders --> Response
    GetById --> Response

    class Client,Response external
    class PlaceOrder,PlaceBatch,ProcessOrder,SBTrigger inbound
    class OrdersCtrl,OrderSvc,OrderMapper,MsgHandler,LogicApp processing
    class OrderRepo,OrderDB,ServiceBus,BlobSuccess,BlobError storage
    class GetOrders,GetById outbound
```

### Key Transaction Sequence (Place Order Flow)

The PlaceOrder transaction represents the primary business flow, demonstrating synchronous API processing followed by asynchronous event-driven workflow execution.

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Roboto, sans-serif',
    'fontSize': '12px',
    'actorBkg': '#bbdefb',
    'actorBorder': '#1e88e5',
    'actorTextColor': '#0d47a1',
    'actorLineColor': '#546e7a',
    'signalColor': '#263238',
    'signalTextColor': '#263238',
    'noteBkgColor': '#ffe082',
    'noteBorderColor': '#ffb300',
    'noteTextColor': '#e65100',
    'activationBkgColor': '#b3e5fc',
    'activationBorderColor': '#039be5',
    'sequenceNumberColor': '#ffffff'
  }
}}%%
sequenceDiagram
    autonumber

    participant Client as HTTP Client
    participant API as Orders API<br/>(ASP.NET Core)
    participant SVC as OrderService<br/>(Business Logic)
    participant MAP as OrderMapper<br/>(Transformation)
    participant REPO as OrderRepository<br/>(EF Core)
    participant DB as OrderDb<br/>(Azure SQL)
    participant MSG as OrdersMessageHandler<br/>(Publisher)
    participant SB as Service Bus<br/>(ordersplaced)
    participant LA as Logic App<br/>(Workflow)
    participant BLOB as Blob Storage<br/>(Archive)

    Note over Client,BLOB: 📥 Order Placement Flow

    Client->>+API: POST /api/orders<br/>Order JSON
    API->>+SVC: PlaceOrderAsync(order)

    Note right of SVC: ⚙️ Validation & Processing
    SVC->>SVC: ValidateOrder(order)
    SVC->>+MAP: ToEntity(order)
    MAP-->>-SVC: OrderEntity

    SVC->>+REPO: SaveAsync(orderEntity)
    REPO->>+DB: INSERT Orders<br/>OrderEntity
    DB-->>-REPO: Saved
    REPO-->>-SVC: Order saved

    Note right of SVC: 📤 Publish to Service Bus
    SVC->>+MSG: PublishOrderAsync(order)
    MSG-)SB: Publish<br/>ServiceBusMessage (JSON)
    MSG-->>-SVC: Published

    SVC-->>-API: Order result
    API-->>-Client: 201 Created<br/>Order JSON

    Note over SB,BLOB: ⚡ Async Processing

    SB-)+LA: Trigger<br/>ServiceBusMessage

    activate LA
    LA->>+API: POST /api/orders/process<br/>Order JSON
    API->>+SVC: ProcessOrderAsync(order)
    SVC-->>-API: Processed
    API-->>-LA: 200 OK

    alt Success
        LA->>BLOB: Write to ordersprocessedsuccessfully
    else Error
        LA->>BLOB: Write to ordersprocessedwitherrors
    end
    deactivate LA

    Note over Client,BLOB: ✅ Order Flow Complete
```

---

## 3.1.5 Monitoring Data Flow Architecture

### Observability Overview

The observability strategy implements a comprehensive 5-layer telemetry pipeline using OpenTelemetry as the instrumentation standard. The solution collects metrics (custom counters and histograms), structured logs (via ILogger), distributed traces (via ActivitySource), and health check data. Telemetry flows from application instrumentation through OTLP and Azure Monitor exporters to Application Insights and Log Analytics for aggregation and analysis.

### 🔧 Layer 1: Instrumentation

| Component                | Type    | Configuration                                                                       | Source                                                                                                                   |
| ------------------------ | ------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| ActivitySource           | Traces  | Sources: eShop.Orders.API, eShop.Web.App, Azure.Messaging.ServiceBus                | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs)                                                   |
| Meter (eShop.Orders.API) | Metrics | orders.placed, orders.deleted, orders.processing.errors, orders.processing.duration | [src/eShop.Orders.API/Services/OrderService.cs](src/eShop.Orders.API/Services/OrderService.cs)                           |
| DbContextHealthCheck     | Health  | Timeout: 5s, Tag: ready                                                             | [src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs](src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs)   |
| ServiceBusHealthCheck    | Health  | Timeout: 5s, Tag: ready                                                             | [src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs](src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs) |
| SelfHealthCheck          | Health  | Tag: live                                                                           | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs)                                                   |
| OpenTelemetry Logging    | Logs    | IncludeFormattedMessage: true, IncludeScopes: true                                  | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs)                                                   |

### 📡 Layer 2: Collection & Transport

| Component                    | Protocol      | Configuration                                           | Source                                                                 |
| ---------------------------- | ------------- | ------------------------------------------------------- | ---------------------------------------------------------------------- |
| OTLP Exporter                | OTLP          | OTEL_EXPORTER_OTLP_ENDPOINT                             | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs) |
| Azure Monitor Exporter       | Azure Monitor | APPLICATIONINSIGHTS_CONNECTION_STRING                   | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs) |
| ASP.NET Core Instrumentation | Traces        | Filter: /health, /alive excluded; RecordException: true | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs) |
| HTTP Client Instrumentation  | Traces        | RecordException: true                                   | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs) |
| SQL Client Instrumentation   | Traces        | RecordException: true                                   | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs) |

### 🗄️ Layer 3: Aggregation & Storage

| Component                  | Retention | Type                  | Source                                                                                                         |
| -------------------------- | --------- | --------------------- | -------------------------------------------------------------------------------------------------------------- |
| Log Analytics Workspace    | 30 days   | PerGB2018             | [infra/shared/monitoring/log-analytics-workspace.bicep](infra/shared/monitoring/log-analytics-workspace.bicep) |
| Application Insights       | 30 days   | workspace-based       | [infra/shared/monitoring/app-insights.bicep](infra/shared/monitoring/app-insights.bicep)                       |
| Diagnostic Storage Account | 30 days   | auto-delete lifecycle | [infra/shared/monitoring/log-analytics-workspace.bicep](infra/shared/monitoring/log-analytics-workspace.bicep) |

### 📊 Layer 4: Analysis & Visualization

| Component  | Purpose                      | Source |
| ---------- | ---------------------------- | ------ |
| Dashboards | _Not configured in codebase_ | N/A    |
| Workbooks  | _Not configured in codebase_ | N/A    |

### 🚨 Layer 5: Action & Alerting

| Component     | Purpose                      | Source |
| ------------- | ---------------------------- | ------ |
| Alert Rules   | _Not configured in codebase_ | N/A    |
| Action Groups | _Not configured in codebase_ | N/A    |

### Telemetry Summary

| Telemetry          | Type    | Source          | Sink                   | Retention |
| ------------------ | ------- | --------------- | ---------------------- | --------- |
| Distributed Traces | Traces  | ActivitySource  | Application Insights   | 30 days   |
| Custom Metrics     | Metrics | Meter           | Application Insights   | 30 days   |
| Structured Logs    | Logs    | ILogger + OTel  | Log Analytics          | 30 days   |
| Health Checks      | Health  | /health, /alive | ASP.NET Core endpoints | N/A       |

### Monitoring Data Flow Diagram

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif',
    'fontSize': '13px',
    'lineColor': '#546e7a',
    'textColor': '#263238'
  }
}}%%
flowchart TB
    classDef l1 fill:#b2ebf2,stroke:#00acc1,stroke-width:2px,color:#006064,rx:6,ry:6
    classDef l2 fill:#b3e5fc,stroke:#039be5,stroke-width:2px,color:#01579b,rx:6,ry:6
    classDef l3 fill:#c5cae9,stroke:#3949ab,stroke-width:2px,color:#1a237e,rx:6,ry:6
    classDef l4 fill:#d1c4e9,stroke:#5e35b1,stroke-width:2px,color:#311b92,rx:6,ry:6
    classDef l5 fill:#f8bbd0,stroke:#d81b60,stroke-width:2px,color:#880e4f,rx:6,ry:6

    subgraph L1["🔧 Layer 1: Instrumentation"]
        direction LR
        ActivitySrc["ActivitySource<br/>eShop.Orders.API<br/>eShop.Web.App<br/>Azure.Messaging.ServiceBus"]
        Meter["Meter (eShop.Orders.API)<br/>orders.placed<br/>orders.deleted<br/>orders.processing.errors<br/>orders.processing.duration"]
        DbHealth["DbContextHealthCheck<br/>Timeout: 5s, Tag: ready"]
        SBHealth["ServiceBusHealthCheck<br/>Timeout: 5s, Tag: ready"]
        SelfHealth["SelfHealthCheck<br/>Tag: live"]
        OTelLog["OpenTelemetry Logging<br/>FormattedMessage: true<br/>Scopes: true"]
    end

    subgraph L2["📡 Layer 2: Collection & Transport"]
        direction LR
        OTLPExp["OTLP Exporter<br/>Traces, Metrics<br/>OTEL_EXPORTER_OTLP_ENDPOINT"]
        AzMonExp["Azure Monitor Exporter<br/>Traces, Metrics<br/>APPLICATIONINSIGHTS_CONNECTION_STRING"]
        ASPInst["ASP.NET Core Instrumentation<br/>Filter: /health, /alive excluded<br/>RecordException: true"]
        HTTPInst["HTTP Client Instrumentation<br/>RecordException: true"]
        SQLInst["SQL Client Instrumentation<br/>RecordException: true"]
    end

    subgraph L3["🗄️ Layer 3: Aggregation & Storage"]
        direction LR
        LogAnalytics["Log Analytics Workspace<br/>Retention: 30 days<br/>SKU: PerGB2018"]
        AppInsights["Application Insights<br/>Type: workspace-based<br/>Kind: web"]
        DiagStorage["Diagnostic Storage Account<br/>Lifecycle: 30 days auto-delete"]
    end

    subgraph L4["📊 Layer 4: Analysis & Visualization"]
        direction LR
        Dashboards["Dashboards<br/>(Not configured)"]
        Workbooks["Workbooks<br/>(Not configured)"]
    end

    subgraph L5["🚨 Layer 5: Action & Alerting"]
        direction LR
        AlertRules["Alert Rules<br/>(Not configured)"]
        ActionGroups["Action Groups<br/>(Not configured)"]
    end

    ActivitySrc -->|"Traces"| OTLPExp
    ActivitySrc -->|"Traces"| AzMonExp
    Meter -->|"Metrics"| OTLPExp
    Meter -->|"Metrics"| AzMonExp
    DbHealth -->|"Health"| ASPInst
    SBHealth -->|"Health"| ASPInst
    SelfHealth -->|"Health"| ASPInst
    OTelLog -->|"Logs"| OTLPExp

    ASPInst -->|"Traces"| OTLPExp
    HTTPInst -->|"Traces"| OTLPExp
    SQLInst -->|"Traces"| OTLPExp

    OTLPExp -->|"OTLP"| AppInsights
    AzMonExp -->|"Azure Monitor"| AppInsights
    AppInsights -->|"Export"| LogAnalytics
    DiagStorage -->|"Diagnostics"| LogAnalytics

    LogAnalytics -.->|"Query"| Dashboards
    LogAnalytics -.->|"Query"| Workbooks
    AppInsights -.->|"Query"| Dashboards
    AppInsights -.->|"Query"| Workbooks

    Dashboards -.->|"Trigger"| AlertRules
    Workbooks -.->|"Trigger"| AlertRules
    AlertRules -.->|"Notify"| ActionGroups

    class ActivitySrc,Meter,DbHealth,SBHealth,SelfHealth,OTelLog l1
    class OTLPExp,AzMonExp,ASPInst,HTTPInst,SQLInst l2
    class LogAnalytics,AppInsights,DiagStorage l3
    class Dashboards,Workbooks l4
    class AlertRules,ActionGroups l5
```

---

## 3.1.6 Data State Management

### Lifecycle Overview

The Order entity follows a well-defined lifecycle from initial receipt through validation, persistence, asynchronous processing, and archival. The state machine handles both success and failure paths, with dead-letter support for failed message processing and separate blob containers for archiving orders based on processing outcome.

### Order Lifecycle States

| State            | Description                     | Trigger                                  |
| ---------------- | ------------------------------- | ---------------------------------------- |
| Received         | Order received via HTTP POST    | Client submits POST /api/orders          |
| Validating       | Order validation in progress    | OrderService.PlaceOrderAsync()           |
| Mapping          | Converting to entity            | Validation passed                        |
| Persisting       | Saving to database              | OrderMapper.ToEntity()                   |
| Publishing       | Sending to Service Bus          | EF Core SaveChanges()                    |
| Published        | Message accepted by Service Bus | OrdersMessageHandler.PublishOrderAsync() |
| Triggered        | Logic App triggered             | Service Bus subscription                 |
| Processing       | Logic App processing            | Logic App receives message               |
| ArchivingSuccess | Writing to success blob         | Processing succeeded                     |
| ArchivingError   | Writing to error blob           | Processing failed                        |
| Completed        | Order lifecycle complete        | Blob write successful                    |
| Rejected         | Validation failed               | Invalid order data                       |

### State Transitions

**Success Path:**
Received → Validating → Mapping → Persisting → Publishing → Published → Triggered → Processing → ArchivingSuccess → Completed

**Failure Paths:**

- Validating → Rejected (validation failure → 400 Bad Request)
- Processing → ArchivingError → CompletedWithErrors (processing failure)

### Retention Policies

| Store                        | Retention  | Policy                         |
| ---------------------------- | ---------- | ------------------------------ |
| Azure SQL Database (OrderDb) | Indefinite | No auto-purge configured       |
| Service Bus Messages         | 14 days    | defaultMessageTimeToLive: P14D |
| Blob Archives                | Indefinite | No lifecycle policy configured |
| Log Analytics                | 30 days    | SKU: PerGB2018 default         |
| Application Insights         | 30 days    | Workspace-based default        |
| Diagnostic Storage           | 30 days    | Lifecycle auto-delete          |

### Data State Lifecycle Diagram

```mermaid
%%{init: {
  'theme': 'base',
  'themeVariables': {
    'fontFamily': 'Segoe UI, Roboto, sans-serif',
    'fontSize': '12px',
    'primaryColor': '#bbdefb',
    'primaryBorderColor': '#1e88e5',
    'primaryTextColor': '#0d47a1',
    'lineColor': '#546e7a',
    'stateBkg': '#eceff1',
    'stateLabelColor': '#263238',
    'transitionColor': '#546e7a',
    'transitionLabelColor': '#263238',
    'compositeBackground': '#e0e0e0',
    'compositeBorder': '#b0bec5',
    'noteBkgColor': '#ffe082',
    'noteBorderColor': '#ffb300',
    'noteTextColor': '#e65100',
    'specialStateColor': '#1e88e5'
  }
}}%%
stateDiagram-v2
    direction TB

    [*] --> Received: HTTP POST /api/orders

    state "📥 Inbound" as Inbound {
        Received --> Validating: OrderService.PlaceOrderAsync()

        state Validating {
            [*] --> CheckingCustomerId
            CheckingCustomerId --> CheckingProducts: CustomerId valid
            CheckingProducts --> CheckingTotal: Products valid
            CheckingTotal --> ValidationComplete: Total valid
            CheckingCustomerId --> ValidationFailed: Invalid
            CheckingProducts --> ValidationFailed: Invalid
            CheckingTotal --> ValidationFailed: Invalid
        }
    }

    Validating --> Mapping: Validation passed
    Validating --> Rejected: Validation failed

    state "⚙️ Processing" as Processing {
        Mapping --> Persisting: OrderMapper.ToEntity()

        state Persisting {
            [*] --> SavingOrder
            SavingOrder --> SavingProducts: Order saved
            SavingProducts --> PersistComplete: Products saved
        }
    }

    Persisting --> Publishing: EF Core SaveChanges()

    state "📤 Publishing" as Publishing_State {
        Publishing --> MessageQueued: OrdersMessageHandler.PublishOrderAsync()
        MessageQueued --> Published: Service Bus accepts message
    }

    Published --> [*]: API returns 201 Created

    state "⚡ Async Processing" as AsyncProc {
        Published --> Triggered: Service Bus trigger
        Triggered --> LogicAppProcessing: Logic App receives message

        state LogicAppProcessing {
            [*] --> CallingAPI
            CallingAPI --> ProcessingResponse: HTTP POST /process
        }

        LogicAppProcessing --> ArchivingSuccess: Processing succeeded
        LogicAppProcessing --> ArchivingError: Processing failed
    }

    state "📚 Archival" as Archival {
        ArchivingSuccess --> ArchivedSuccess: Write to ordersprocessedsuccessfully
        ArchivingError --> ArchivedError: Write to ordersprocessedwitherrors
    }

    ArchivedSuccess --> Completed
    ArchivedError --> CompletedWithErrors

    Rejected --> [*]: API returns 400 Bad Request
    Completed --> [*]: Order lifecycle complete
    CompletedWithErrors --> [*]: Order lifecycle complete with errors

    note right of Validating
        Validation includes:
        - CustomerId: required, max 100 chars
        - Products: at least 1 required
        - Total: calculated from products
    end note

    note right of Persisting
        Database operations:
        - INSERT into Orders table
        - INSERT into OrderProducts table
        - Cascade delete on Order deletion
    end note

    note right of Publishing_State
        Service Bus config:
        - Topic: ordersplaced
        - TTL: 14 days
        - Dead letter: enabled
    end note
```

---

## 3.1.7 Data Security & Governance

### Authentication Mechanisms

| Component            | Authentication Method                           | Source                                                                     |
| -------------------- | ----------------------------------------------- | -------------------------------------------------------------------------- |
| Azure SQL Database   | Entra ID-only (azureADOnlyAuthentication: true) | [infra/shared/data/main.bicep](infra/shared/data/main.bicep)               |
| Service Bus          | Managed Identity                                | [infra/workload/messaging/main.bicep](infra/workload/messaging/main.bicep) |
| Storage Account      | Managed Identity / SAS                          | [infra/shared/data/main.bicep](infra/shared/data/main.bicep)               |
| Application Insights | Connection String                               | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs)     |

### Data Encryption

| Layer      | Encryption Type    | Configuration                         |
| ---------- | ------------------ | ------------------------------------- |
| In Transit | TLS 1.2 minimum    | SQL Server minimalTlsVersion: '1.2'   |
| At Rest    | Azure-managed keys | Default for SQL, Storage, Service Bus |
| Network    | Private Endpoints  | SQL Server with Private DNS Zone      |

### Access Control Patterns

- **Principle of Least Privilege:** Services use Managed Identity with minimal RBAC roles
- **Network Isolation:** Private endpoints for SQL Database
- **No Shared Secrets:** Entra ID authentication eliminates SQL connection string passwords

---

## 3.1.8 Data Infrastructure (IaC)

### Bicep Resource Inventory

| Resource                | Bicep File                                                                                                     | Dependencies                      |
| ----------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------- |
| SQL Server + Database   | [infra/shared/data/main.bicep](infra/shared/data/main.bicep)                                                   | Virtual Network, Private DNS Zone |
| Storage Account         | [infra/shared/data/main.bicep](infra/shared/data/main.bicep)                                                   | None                              |
| Service Bus Namespace   | [infra/workload/messaging/main.bicep](infra/workload/messaging/main.bicep)                                     | None                              |
| Log Analytics Workspace | [infra/shared/monitoring/log-analytics-workspace.bicep](infra/shared/monitoring/log-analytics-workspace.bicep) | Storage Account (diagnostics)     |
| Application Insights    | [infra/shared/monitoring/app-insights.bicep](infra/shared/monitoring/app-insights.bicep)                       | Log Analytics Workspace           |

### Configuration Parameters

| Parameter          | Description    | Default          |
| ------------------ | -------------- | ---------------- |
| SQL Server SKU     | Gen5, 2 vCores | 32GB storage     |
| Service Bus Tier   | Standard       | Pub/sub enabled  |
| Storage Redundancy | Standard_LRS   | Local redundancy |
| Log Analytics SKU  | PerGB2018      | 30-day retention |

### Deployment Considerations

- **Order:** Deploy shared infrastructure (networking, monitoring) before workload resources
- **Dependencies:** SQL private endpoint requires VNet and DNS zone
- **Post-deployment:** Run database migrations after SQL deployment
