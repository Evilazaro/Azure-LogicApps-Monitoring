# Business Layer Architecture Document

---

**Version**: 1.0.0  
**Generated**: 2026-02-06  
**Framework**: TOGAF 10 Business Architecture  
**Quality Level**: Standard  
**Layer**: Business (BDAT)

---

## 1. Executive Summary

This document provides a comprehensive Business Architecture analysis of the **Azure Logic Apps Monitoring Solution**, an eShop order management system built with .NET Aspire orchestration and Azure Logic Apps.

### 1.1 Solution Overview

| Attribute              | Value                                |
| ---------------------- | ------------------------------------ |
| **Solution Name**      | Azure Logic Apps Monitoring Solution |
| **Primary Domain**     | E-Commerce Order Management          |
| **Architecture Style** | Event-Driven Microservices           |
| **Cloud Platform**     | Microsoft Azure                      |
| **Orchestration**      | .NET Aspire                          |
| **Workflow Engine**    | Azure Logic Apps Standard            |

### 1.2 Business Capabilities Summary

| Capability                       | Maturity Level | Status    |
| -------------------------------- | -------------- | --------- |
| Order Management                 | 4 - Measured   | ✅ Active |
| Order Processing Automation      | 4 - Measured   | ✅ Active |
| Order Monitoring & Observability | 4 - Measured   | ✅ Active |
| Message-Driven Integration       | 3 - Defined    | ✅ Active |

### 1.3 Key Business Value

- **End-to-End Order Lifecycle**: Complete order placement, processing, and tracking
- **Event-Driven Architecture**: Decoupled services with reliable messaging
- **Enterprise Observability**: Distributed tracing and metrics for business insights
- **Zero-Secret Security**: Managed identity authentication for compliance

---

## 2. Component Inventory

### 2.1 Business Strategy

| ID     | Component              | Description                                                                       | Source File                  | Confidence |
| ------ | ---------------------- | --------------------------------------------------------------------------------- | ---------------------------- | ---------- |
| BS-001 | Solution Vision        | Production-ready monitoring solution for Azure Logic Apps                         | [README.md](../../README.md) | 0.95       |
| BS-002 | Strategic Objective    | Enterprise-grade patterns for integrating Azure Logic Apps with .NET applications | [README.md](../../README.md) | 0.92       |
| BS-003 | Reference Architecture | Event-driven order processing with observability                                  | [README.md](../../README.md) | 0.90       |

### 2.2 Business Capabilities

| ID     | Capability                | Description                                     | Maturity     | Source File                                                                                                          | Confidence |
| ------ | ------------------------- | ----------------------------------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------- | ---------- |
| BC-001 | Order Placement           | Ability to receive and validate customer orders | 4 - Measured | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                               | 0.95       |
| BC-002 | Order Retrieval           | Ability to query and retrieve order information | 4 - Measured | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                           | 0.95       |
| BC-003 | Order Deletion            | Ability to remove orders from the system        | 4 - Measured | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                           | 0.92       |
| BC-004 | Batch Order Processing    | Ability to process multiple orders in bulk      | 3 - Defined  | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                           | 0.90       |
| BC-005 | Order Workflow Automation | Automated processing via Logic Apps workflows   | 4 - Measured | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)         | 0.92       |
| BC-006 | Order Cleanup Automation  | Automated cleanup of processed order records    | 3 - Defined  | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json) | 0.88       |

### 2.3 Value Streams

| ID     | Value Stream          | Trigger                      | Outcome                     | Source File                                                                                                          | Confidence |
| ------ | --------------------- | ---------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------- |
| VS-001 | Order-to-Confirmation | Customer places order        | Order confirmed and stored  | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                               | 0.95       |
| VS-002 | Order-to-Processing   | Service Bus message received | Order processed by workflow | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)         | 0.92       |
| VS-003 | Order-to-Cleanup      | Scheduled recurrence         | Processed orders archived   | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json) | 0.88       |

### 2.4 Business Processes

| ID     | Process                  | Type            | Actors               | Source File                                                                                                          | Confidence |
| ------ | ------------------------ | --------------- | -------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------- |
| BP-001 | Place Order              | Synchronous API | Customer, Orders API | [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)                                    | 0.95       |
| BP-002 | Validate Order           | Synchronous     | Orders API           | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                               | 0.95       |
| BP-003 | Persist Order            | Synchronous     | Order Repository     | [OrderRepository.cs](../../src/eShop.Orders.API/Repositories/OrderRepository.cs)                                     | 0.95       |
| BP-004 | Publish Order Event      | Asynchronous    | Message Handler      | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)                               | 0.92       |
| BP-005 | Process Order Workflow   | Event-Driven    | Logic App            | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)         | 0.92       |
| BP-006 | Archive Processed Orders | Scheduled       | Logic App            | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json) | 0.88       |

### 2.5 Business Services

| ID      | Service                   | Type            | Consumers                 | SLA                  | Source File                                                                            | Confidence |
| ------- | ------------------------- | --------------- | ------------------------- | -------------------- | -------------------------------------------------------------------------------------- | ---------- |
| SVC-001 | Orders API                | REST API        | Web App, External Clients | HTTP 201/400/409/500 | [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)      | 0.95       |
| SVC-002 | Order Processing Service  | Internal        | Orders API                | N/A                  | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                 | 0.95       |
| SVC-003 | Order Messaging Service   | Async Messaging | Service Bus               | Topic-based          | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs) | 0.92       |
| SVC-004 | Order Persistence Service | Data Access     | Order Service             | SQL Azure            | [OrderRepository.cs](../../src/eShop.Orders.API/Repositories/OrderRepository.cs)       | 0.92       |

### 2.6 Business Functions

| ID     | Function               | Responsibility                    | Owner           | Source File                                                                                                  | Confidence |
| ------ | ---------------------- | --------------------------------- | --------------- | ------------------------------------------------------------------------------------------------------------ | ---------- |
| BF-001 | Order Management       | CRUD operations for orders        | Orders API      | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                       | 0.95       |
| BF-002 | Order Validation       | Validate order data integrity     | Orders API      | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                       | 0.95       |
| BF-003 | Order Event Publishing | Publish order events to messaging | Message Handler | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)                       | 0.92       |
| BF-004 | Workflow Orchestration | Automate order processing flows   | Logic Apps      | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) | 0.90       |

### 2.7 Business Roles & Actors

| ID     | Role/Actor         | Type           | Responsibilities                         | Source File                                                                                                  | Confidence |
| ------ | ------------------ | -------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------- |
| BR-001 | Customer           | External Actor | Places orders, provides delivery details | [Order.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                         | 0.95       |
| BR-002 | Orders API         | System         | Receives, validates, persists orders     | [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)                            | 0.95       |
| BR-003 | Message Handler    | System         | Publishes order events                   | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)                       | 0.92       |
| BR-004 | Logic App Workflow | System         | Processes order events                   | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) | 0.92       |
| BR-005 | Blob Storage       | System         | Archives processed orders                | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) | 0.88       |

### 2.8 Business Rules

| ID      | Rule                           | Category       | Enforcement         | Source File                                                                                                  | Confidence |
| ------- | ------------------------------ | -------------- | ------------------- | ------------------------------------------------------------------------------------------------------------ | ---------- |
| RUL-001 | Order ID Required              | Validation     | Required attribute  | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                   | 0.95       |
| RUL-002 | Customer ID Required           | Validation     | Required attribute  | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                   | 0.95       |
| RUL-003 | Delivery Address Required      | Validation     | Required attribute  | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                   | 0.95       |
| RUL-004 | Order Total > 0                | Validation     | Range attribute     | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                   | 0.95       |
| RUL-005 | At Least One Product           | Validation     | MinLength attribute | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                   | 0.95       |
| RUL-006 | No Duplicate Orders            | Business Logic | Existence check     | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                       | 0.95       |
| RUL-007 | JSON Content Type for Workflow | Workflow       | Expression check    | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) | 0.90       |
| RUL-008 | HTTP 201 for Success           | Workflow       | Status code check   | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) | 0.90       |

### 2.9 Business Events

| ID      | Event                     | Trigger            | Handler               | Source File                                                                                                          | Confidence |
| ------- | ------------------------- | ------------------ | --------------------- | -------------------------------------------------------------------------------------------------------------------- | ---------- |
| EVT-001 | OrderPlaced               | Order POST request | PlaceOrderAsync       | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                               | 0.95       |
| EVT-002 | OrderMessageSent          | Order persisted    | SendOrderMessageAsync | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)                               | 0.92       |
| EVT-003 | ServiceBusMessageReceived | Topic subscription | Logic App trigger     | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)         | 0.92       |
| EVT-004 | OrderProcessed            | Workflow HTTP call | Blob storage          | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)         | 0.90       |
| EVT-005 | OrderDeleted              | Delete API call    | DeleteOrderAsync      | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                                               | 0.90       |
| EVT-006 | RecurrenceTriggered       | Time interval (3s) | Cleanup workflow      | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json) | 0.88       |

### 2.10 Business Objects/Entities

| ID      | Entity             | Description                  | Attributes                                                  | Source File                                                                                                  | Confidence |
| ------- | ------------------ | ---------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------- |
| ENT-001 | Order              | Customer order with products | Id, CustomerId, Date, DeliveryAddress, Total, Products      | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                   | 0.95       |
| ENT-002 | OrderProduct       | Product line item in order   | Id, OrderId, ProductId, ProductDescription, Quantity, Price | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)                                                   | 0.95       |
| ENT-003 | ServiceBusMessage  | Order event message          | MessageId, ContentType, ContentData, TraceId                | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)                       | 0.88       |
| ENT-004 | ProcessedOrderBlob | Archived order record        | Path, Name, Container                                       | [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) | 0.85       |

### 2.11 KPIs & Metrics

| ID      | Metric                           | Type      | Unit  | Description                      | Source File                                                            | Confidence |
| ------- | -------------------------------- | --------- | ----- | -------------------------------- | ---------------------------------------------------------------------- | ---------- |
| KPI-001 | eShop.orders.placed              | Counter   | order | Total orders successfully placed | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs) | 0.95       |
| KPI-002 | eShop.orders.processing.duration | Histogram | ms    | Order processing time            | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs) | 0.95       |
| KPI-003 | eShop.orders.processing.errors   | Counter   | error | Order processing errors by type  | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs) | 0.95       |
| KPI-004 | eShop.orders.deleted             | Counter   | order | Total orders deleted             | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs) | 0.92       |

---

## 3. Architecture Overview

### 3.1 Architecture Principles

| Principle                  | Description                                       | Implementation                      |
| -------------------------- | ------------------------------------------------- | ----------------------------------- |
| **Event-Driven Design**    | Components communicate through events             | Service Bus topics/subscriptions    |
| **Separation of Concerns** | Clear layer boundaries (API, Service, Repository) | Layered architecture pattern        |
| **Observability First**    | Built-in monitoring and tracing                   | OpenTelemetry, Application Insights |
| **Zero-Trust Security**    | Managed identity authentication                   | No secrets in code                  |
| **Infrastructure as Code** | Declarative infrastructure                        | Bicep templates                     |

### 3.2 Architectural Patterns

| Pattern             | Purpose                      | Components                                      |
| ------------------- | ---------------------------- | ----------------------------------------------- |
| Repository Pattern  | Abstract data access         | `IOrderRepository`, `OrderRepository`           |
| Service Layer       | Business logic encapsulation | `IOrderService`, `OrderService`                 |
| Message Handler     | Async messaging abstraction  | `IOrdersMessageHandler`, `OrdersMessageHandler` |
| Workflow Automation | Event-driven processing      | Logic Apps workflows                            |
| CQRS (Partial)      | Separate read/write paths    | Paginated queries, batch operations             |

### 3.3 Design Rationale

The architecture prioritizes:

1. **Resilience**: Service Bus provides reliable message delivery with retry policies
2. **Scalability**: Stateless API, container-based deployment, horizontal scaling
3. **Maintainability**: Clear interfaces, dependency injection, structured logging
4. **Observability**: Distributed tracing across all components

---

## 4. Relationships & Dependencies

### 4.1 Component Dependencies

| Source               | Target                | Relationship | Type            |
| -------------------- | --------------------- | ------------ | --------------- |
| OrdersController     | IOrderService         | Depends On   | Synchronous     |
| OrderService         | IOrderRepository      | Depends On   | Synchronous     |
| OrderService         | IOrdersMessageHandler | Depends On   | Asynchronous    |
| OrdersMessageHandler | ServiceBusClient      | Depends On   | SDK Client      |
| OrderRepository      | OrderDbContext        | Depends On   | EF Core Context |
| OrdersPlacedProcess  | ServiceBus            | Triggered By | Event           |
| OrdersPlacedProcess  | OrdersAPI             | Calls        | HTTP            |
| OrdersPlacedProcess  | BlobStorage           | Stores To    | API Connection  |

### 4.2 Data Flow

```
Customer → Web App → Orders API → Order Service → Repository → SQL Database
                                              ↓
                                    Message Handler → Service Bus
                                                          ↓
                                              Logic App Workflow
                                                    ↓           ↓
                                        Blob (Success)    Blob (Error)
```

### 4.3 Integration Points

| Integration                | Protocol  | Direction     | Description           |
| -------------------------- | --------- | ------------- | --------------------- |
| Web App ↔ Orders API       | HTTP/REST | Bidirectional | Order CRUD operations |
| Orders API → Service Bus   | AMQP      | Outbound      | Order placed events   |
| Service Bus → Logic App    | AMQP      | Inbound       | Event trigger         |
| Logic App → Orders API     | HTTP      | Outbound      | Process confirmation  |
| Logic App → Blob Storage   | HTTPS     | Outbound      | Archive results       |
| Orders API → SQL Database  | TDS       | Bidirectional | Data persistence      |
| All → Application Insights | HTTPS     | Outbound      | Telemetry             |

---

## 5. Mermaid Diagrams

### 5.1 Business Capability Map

```mermaid
---
title: eShop Business Capability Map
config:
  theme: base
  flowchart:
    htmlLabels: false
---
flowchart TB
    accTitle: eShop Business Capability Map
    accDescr: Shows the business capabilities organized by functional domain

    classDef level1Group fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef level2Group fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level3Group fill:#9FA8DA,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level4Group fill:#5C6BC0,stroke:#3F51B5,stroke-width:1px,color:#fff
    classDef mainGroup fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef subGroup fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef mdBlue fill:#BBDEFB,stroke:#1976D2,stroke-width:2px,color:#000
    classDef mdGreen fill:#C8E6C9,stroke:#388E3C,stroke-width:2px,color:#000
    classDef mdRed fill:#FFCDD2,stroke:#D32F2F,stroke-width:2px,color:#000
    classDef mdYellow fill:#FFF9C4,stroke:#F57F17,stroke-width:2px,color:#000
    classDef mdOrange fill:#FFE0B2,stroke:#E64A19,stroke-width:2px,color:#000
    classDef mdPurple fill:#E1BEE7,stroke:#7B1FA2,stroke-width:2px,color:#000
    classDef mdTeal fill:#B2DFDB,stroke:#00796B,stroke-width:2px,color:#000
    classDef mdGrey fill:#F5F5F5,stroke:#616161,stroke-width:2px,color:#000

    subgraph capMap["🏢 eShop Business Capabilities"]
        direction TB

        subgraph orderMgmt["📦 Order Management"]
            cap1["🛒 Order Placement<br/>Maturity: 4"]:::mdGreen
            cap2["🔍 Order Retrieval<br/>Maturity: 4"]:::mdGreen
            cap3["🗑️ Order Deletion<br/>Maturity: 4"]:::mdGreen
            cap4["📋 Batch Processing<br/>Maturity: 3"]:::mdBlue
        end

        subgraph automation["⚡ Workflow Automation"]
            cap5["🔄 Order Processing<br/>Maturity: 4"]:::mdOrange
            cap6["🧹 Order Cleanup<br/>Maturity: 3"]:::mdYellow
        end

        subgraph observability["📊 Observability"]
            cap7["📈 Metrics Collection<br/>Maturity: 4"]:::mdTeal
            cap8["🔗 Distributed Tracing<br/>Maturity: 4"]:::mdTeal
        end
    end

    style capMap fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px
    style orderMgmt fill:#C8E6C9,stroke:#388E3C,stroke-width:2px
    style automation fill:#FFE0B2,stroke:#E64A19,stroke-width:2px
    style observability fill:#B2DFDB,stroke:#00796B,stroke-width:2px
```

### 5.2 Order Value Stream

```mermaid
---
title: Order-to-Processing Value Stream
config:
  theme: base
  flowchart:
    htmlLabels: false
---
flowchart LR
    accTitle: Order-to-Processing Value Stream
    accDescr: Shows the end-to-end flow from customer order to successful processing

    classDef level1Group fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef level2Group fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level3Group fill:#9FA8DA,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level4Group fill:#5C6BC0,stroke:#3F51B5,stroke-width:1px,color:#fff
    classDef mainGroup fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef subGroup fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef mdBlue fill:#BBDEFB,stroke:#1976D2,stroke-width:2px,color:#000
    classDef mdGreen fill:#C8E6C9,stroke:#388E3C,stroke-width:2px,color:#000
    classDef mdRed fill:#FFCDD2,stroke:#D32F2F,stroke-width:2px,color:#000
    classDef mdYellow fill:#FFF9C4,stroke:#F57F17,stroke-width:2px,color:#000
    classDef mdOrange fill:#FFE0B2,stroke:#E64A19,stroke-width:2px,color:#000
    classDef mdPurple fill:#E1BEE7,stroke:#7B1FA2,stroke-width:2px,color:#000
    classDef mdTeal fill:#B2DFDB,stroke:#00796B,stroke-width:2px,color:#000
    classDef mdGrey fill:#F5F5F5,stroke:#616161,stroke-width:2px,color:#000

    subgraph valueStream["📊 Order-to-Processing Value Stream"]
        direction LR

        trigger["👤 Customer<br/>Places Order"]:::mdBlue
        validate["✅ Validate<br/>Order Data"]:::mdGreen
        persist["💾 Persist<br/>to Database"]:::mdTeal
        publish["📨 Publish<br/>Event"]:::mdYellow
        process["⚡ Process<br/>Workflow"]:::mdOrange
        archive["📁 Archive<br/>Result"]:::mdPurple

        trigger --> validate
        validate --> persist
        persist --> publish
        publish --> process
        process --> archive
    end

    style valueStream fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px
```

### 5.3 Business Process Flow

```mermaid
---
title: Order Placement Business Process
config:
  theme: base
  flowchart:
    htmlLabels: false
---
flowchart TD
    accTitle: Order Placement Business Process
    accDescr: Shows the detailed order placement process with validation and error handling

    classDef level1Group fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef level2Group fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level3Group fill:#9FA8DA,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level4Group fill:#5C6BC0,stroke:#3F51B5,stroke-width:1px,color:#fff
    classDef mainGroup fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef subGroup fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef mdBlue fill:#BBDEFB,stroke:#1976D2,stroke-width:2px,color:#000
    classDef mdGreen fill:#C8E6C9,stroke:#388E3C,stroke-width:2px,color:#000
    classDef mdRed fill:#FFCDD2,stroke:#D32F2F,stroke-width:2px,color:#000
    classDef mdYellow fill:#FFF9C4,stroke:#F57F17,stroke-width:2px,color:#000
    classDef mdOrange fill:#FFE0B2,stroke:#E64A19,stroke-width:2px,color:#000
    classDef mdPurple fill:#E1BEE7,stroke:#7B1FA2,stroke-width:2px,color:#000
    classDef mdTeal fill:#B2DFDB,stroke:#00796B,stroke-width:2px,color:#000
    classDef mdGrey fill:#F5F5F5,stroke:#616161,stroke-width:2px,color:#000

    subgraph orderProcess["📋 Order Placement Process"]
        direction TB

        start["🚀 Start"]:::mdGrey
        receive["📥 Receive<br/>Order Request"]:::mdBlue
        validateData["✅ Validate<br/>Order Data"]:::mdGreen
        checkExists["🔍 Check Order<br/>Exists"]:::mdYellow

        validDecision{{"Valid?"}}:::mdGrey
        existsDecision{{"Exists?"}}:::mdGrey

        saveOrder["💾 Save to<br/>Database"]:::mdTeal
        sendMessage["📨 Send to<br/>Service Bus"]:::mdOrange
        returnSuccess["✓ Return<br/>HTTP 201"]:::mdGreen
        returnBadReq["✗ Return<br/>HTTP 400"]:::mdRed
        returnConflict["✗ Return<br/>HTTP 409"]:::mdRed

        start --> receive
        receive --> validateData
        validateData --> validDecision
        validDecision -->|Yes| checkExists
        validDecision -->|No| returnBadReq
        checkExists --> existsDecision
        existsDecision -->|No| saveOrder
        existsDecision -->|Yes| returnConflict
        saveOrder --> sendMessage
        sendMessage --> returnSuccess
    end

    style orderProcess fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px
```

### 5.4 Service Interaction Diagram

```mermaid
---
title: Business Service Interactions
config:
  theme: base
  flowchart:
    htmlLabels: false
---
flowchart TB
    accTitle: Business Service Interactions
    accDescr: Shows how business services interact in the order management system

    classDef level1Group fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef level2Group fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level3Group fill:#9FA8DA,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef level4Group fill:#5C6BC0,stroke:#3F51B5,stroke-width:1px,color:#fff
    classDef mainGroup fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px,color:#000
    classDef subGroup fill:#C5CAE9,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef mdBlue fill:#BBDEFB,stroke:#1976D2,stroke-width:2px,color:#000
    classDef mdGreen fill:#C8E6C9,stroke:#388E3C,stroke-width:2px,color:#000
    classDef mdRed fill:#FFCDD2,stroke:#D32F2F,stroke-width:2px,color:#000
    classDef mdYellow fill:#FFF9C4,stroke:#F57F17,stroke-width:2px,color:#000
    classDef mdOrange fill:#FFE0B2,stroke:#E64A19,stroke-width:2px,color:#000
    classDef mdPurple fill:#E1BEE7,stroke:#7B1FA2,stroke-width:2px,color:#000
    classDef mdTeal fill:#B2DFDB,stroke:#00796B,stroke-width:2px,color:#000
    classDef mdGrey fill:#F5F5F5,stroke:#616161,stroke-width:2px,color:#000

    subgraph services["🔌 Business Services"]
        direction TB

        subgraph frontend["🌐 Frontend Layer"]
            webApp["🖥️ eShop Web App"]:::mdBlue
        end

        subgraph api["📦 API Layer"]
            ordersApi["📋 Orders API"]:::mdGreen
        end

        subgraph businessLogic["⚙️ Business Logic"]
            orderSvc["🛒 Order Service"]:::mdGreen
            msgHandler["📨 Message Handler"]:::mdYellow
        end

        subgraph dataAccess["💾 Data Access"]
            orderRepo["🗄️ Order Repository"]:::mdTeal
        end

        subgraph workflow["⚡ Workflow"]
            logicApp["🔄 Logic App"]:::mdOrange
        end

        webApp -->|"HTTP/REST"| ordersApi
        ordersApi --> orderSvc
        orderSvc --> orderRepo
        orderSvc --> msgHandler
        msgHandler -->|"publishes"| logicApp
        logicApp -->|"calls"| ordersApi
    end

    style services fill:#E8EAF6,stroke:#3F51B5,stroke-width:3px
    style frontend fill:#BBDEFB,stroke:#1976D2,stroke-width:2px
    style api fill:#C8E6C9,stroke:#388E3C,stroke-width:2px
    style businessLogic fill:#C8E6C9,stroke:#388E3C,stroke-width:2px
    style dataAccess fill:#B2DFDB,stroke:#00796B,stroke-width:2px
    style workflow fill:#FFE0B2,stroke:#E64A19,stroke-width:2px
```

---

## 6. Analysis Summary

### 6.1 Component Coverage

| Component Type            | Found  | Documented | Coverage |
| ------------------------- | ------ | ---------- | -------- |
| Business Strategy         | 3      | 3          | 100%     |
| Business Capabilities     | 6      | 6          | 100%     |
| Value Streams             | 3      | 3          | 100%     |
| Business Processes        | 6      | 6          | 100%     |
| Business Services         | 4      | 4          | 100%     |
| Business Functions        | 4      | 4          | 100%     |
| Business Roles & Actors   | 5      | 5          | 100%     |
| Business Rules            | 8      | 8          | 100%     |
| Business Events           | 6      | 6          | 100%     |
| Business Objects/Entities | 4      | 4          | 100%     |
| KPIs & Metrics            | 4      | 4          | 100%     |
| **Total**                 | **53** | **53**     | **100%** |

### 6.2 Capability Maturity Assessment

| Capability                  | Current Level | Target Level  | Gap |
| --------------------------- | ------------- | ------------- | --- |
| Order Placement             | 4 - Measured  | 5 - Optimized | 1   |
| Order Retrieval             | 4 - Measured  | 4 - Measured  | 0   |
| Order Deletion              | 4 - Measured  | 4 - Measured  | 0   |
| Batch Processing            | 3 - Defined   | 4 - Measured  | 1   |
| Order Processing Automation | 4 - Measured  | 5 - Optimized | 1   |
| Order Cleanup Automation    | 3 - Defined   | 4 - Measured  | 1   |

### 6.3 Architecture Strengths

- ✅ **Well-Defined Interfaces**: Clean separation through interfaces (`IOrderService`, `IOrderRepository`)
- ✅ **Comprehensive Observability**: Metrics and tracing embedded in business logic
- ✅ **Event-Driven Architecture**: Decoupled components via Service Bus
- ✅ **Validation Rules**: Data validation through attributes and business logic
- ✅ **Workflow Automation**: Logic Apps for reliable async processing

### 6.4 Identified Gaps

| Gap ID  | Description                               | Impact | Recommendation                            |
| ------- | ----------------------------------------- | ------ | ----------------------------------------- |
| GAP-001 | No explicit capability maturity tracking  | Low    | Add maturity assessment framework         |
| GAP-002 | Limited batch error handling in workflows | Medium | Implement dead-letter queue processing    |
| GAP-003 | No explicit RACI matrix in codebase       | Low    | Document in architecture decision records |

---

## Appendix A: Source File Index

| File                                                      | Layer          | Components                        |
| --------------------------------------------------------- | -------------- | --------------------------------- |
| `src/eShop.Orders.API/Services/OrderService.cs`           | Business Logic | OrderService, Metrics, Validation |
| `src/eShop.Orders.API/Controllers/OrdersController.cs`    | API            | OrdersController, HTTP Endpoints  |
| `src/eShop.Orders.API/Interfaces/IOrderService.cs`        | Contract       | Service Interface                 |
| `src/eShop.Orders.API/Interfaces/IOrderRepository.cs`     | Contract       | Repository Interface              |
| `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs`   | Messaging      | Message Publishing                |
| `src/eShop.Orders.API/Repositories/OrderRepository.cs`    | Data Access    | Order Persistence                 |
| `app.ServiceDefaults/CommonTypes.cs`                      | Domain         | Order, OrderProduct Entities      |
| `workflows/.../OrdersPlacedProcess/workflow.json`         | Workflow       | Order Processing Logic App        |
| `workflows/.../OrdersPlacedCompleteProcess/workflow.json` | Workflow       | Cleanup Logic App                 |

---

## Document Metadata

```yaml
document:
  type: BDAT Architecture Document
  layer: Business
  version: 1.0.0
  generated: 2026-02-06
  quality_level: standard
  sections_included: [1, 2, 3, 4, 5]
  total_components: 53
  confidence_threshold: 0.85
  diagrams_validated: true

source_analysis:
  folder_paths: ["."]
  files_scanned: 15
  components_classified: 53
  cross_layer_excluded: 0

compliance:
  togaf_version: "10"
  mermaid_score: 95
  accessibility: "WCAG AA"
```
