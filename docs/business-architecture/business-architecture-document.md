# Business Architecture Document

## eShop Orders Management Platform

**Document Version**: 1.0  
**Generated**: 2026-01-29  
**TOGAF Phase**: Business Architecture (Phase B)  
**BDAT Layer**: Business

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Capabilities](#2-business-capabilities)
3. [Business Processes](#3-business-processes)
4. [Business Services](#4-business-services)
5. [Business Functions](#5-business-functions)
6. [Organizational Structure](#6-organizational-structure)
7. [Actors & Stakeholders](#7-actors--stakeholders)
8. [Value Streams](#8-value-streams)
9. [Business Objects](#9-business-objects)
10. [Business Goals](#10-business-goals)
11. [Relationships & Dependencies](#11-relationships--dependencies)
12. [Appendix](#12-appendix)

---

## 1. Executive Summary

### Overview

This Business Architecture Document presents a comprehensive analysis of the eShop Orders Management Platform, a cloud-powered enterprise solution designed to streamline order processing through modern distributed architecture patterns. The document follows TOGAF's Business Architecture framework (Phase B) and focuses exclusively on the Business Layer components as defined in the BDAT (Business, Data, Application, Technology) model.

The eShop Orders Management Platform is an Azure-native application built with .NET Aspire orchestration, consisting of a RESTful Orders API, a Blazor Server web application, and Azure Logic Apps workflows for event-driven order processing. Analysis of the codebase revealed **43 business components** organized across **10 TOGAF categories**: 4 Business Capabilities, 9 Business Processes, 6 Business Services, 10 Business Functions, 3 Actors, 4 Business Objects, 3 Business Events, 3 Business Goals, and 1 Value Stream. The architecture demonstrates a clean separation of concerns with well-defined service contracts and event-driven messaging patterns.

Key strategic insights include the platform's focus on real-time order tracking, enterprise-grade reliability with 99.9% uptime SLA targets, and seamless integration with Azure services including Service Bus for messaging, Azure SQL for persistence, and Logic Apps for workflow automation. The business architecture supports both individual order processing and batch operations, with comprehensive observability through distributed tracing and structured logging. Areas requiring further definition include formal organizational structure documentation, explicit business rule catalogs, and detailed customer journey mapping.

---

## 2. Business Capabilities

### Overview

Business Capabilities represent the fundamental abilities that an organization possesses to achieve its strategic objectives. In the TOGAF BDAT model, capabilities form the foundational layer that bridges business strategy with operational execution, enabling stakeholders to understand what the organization can do independent of how it is done. Capabilities are typically expressed as nouns and describe stable business functions that change less frequently than the processes that implement them.

Analysis of the eShop Orders Management Platform revealed **4 business capabilities** organized in a hierarchical structure. The primary capability—Order Management—serves as the L1 (Domain-level) capability that encompasses all order-related functions. Three L2 (Functional-level) capabilities support Order Management: Order Processing handles business logic execution, Message Publishing enables event-driven communication, and Order Data Persistence manages data storage operations. This structure demonstrates a cohesive capability model focused on a single business domain.

The capability structure follows a standard decomposition pattern where the parent capability (Order Management) represents the externally visible business function, while child capabilities represent the internal abilities required to deliver that function. This separation enables independent evolution of capabilities while maintaining a stable external interface. Recommendations include expanding the capability model to include supporting capabilities such as Customer Management and Reporting Analytics as the platform evolves.

### Capability Map

[DIAGRAM PLACEHOLDER: block-beta]

- Type: block-beta
- Components: [CAP-001, CAP-002, CAP-003, CAP-004]
- Style: capStrategic, capCore, capSupporting

### Capability Catalog

| Capability ID | Capability Name        | Level | Parent Capability | Description                                                                               | Source File                                                   |
| ------------- | ---------------------- | ----- | ----------------- | ----------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| CAP-001       | Order Management       | L1    | -                 | API controller for managing customer orders including placement, retrieval, and deletion  | `src/eShop.Orders.API/Controllers/OrdersController.cs:13-17`  |
| CAP-002       | Order Processing       | L2    | CAP-001           | Provides business logic for order management including placement, retrieval, and deletion | `src/eShop.Orders.API/Services/OrderService.cs:15-18`         |
| CAP-003       | Message Publishing     | L2    | CAP-001           | Handles publishing order messages to Azure Service Bus                                    | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:24-26` |
| CAP-004       | Order Data Persistence | L2    | CAP-001           | Provides Entity Framework Core-based persistence for order data                           | `src/eShop.Orders.API/Repositories/OrderRepository.cs:15-18`  |

---

## 3. Business Processes

### Overview

Business Processes represent the sequences of activities that transform inputs into valuable outputs for customers and stakeholders. In the TOGAF framework, processes describe "how" work is done within the organization and are characterized by defined triggers, flows, and outcomes. Processes are dynamic elements that can be optimized, automated, or redesigned without necessarily changing the underlying capabilities they implement.

The eShop Orders Management Platform implements **9 business processes** across two distinct execution contexts: synchronous API-driven processes and asynchronous workflow-based processes. The API layer supports 7 processes including Place Order (PROC-001), Place Orders Batch (PROC-002), Get Orders (PROC-004), Get Order By ID (PROC-005), Delete Order (PROC-006), and Delete Orders Batch (PROC-007). Two L1-level workflow processes—Orders Placed Process (PROC-008) and Orders Placed Complete (PROC-009)—handle asynchronous order processing through Azure Logic Apps integration with Service Bus messaging.

The process hierarchy demonstrates a request-response pattern for user-initiated operations and an event-driven pattern for automated processing. Process triggers include User Request (for interactive operations), Message events (for Service Bus-triggered workflows), and Time-based recurrence (for scheduled cleanup tasks). This dual-mode architecture enables real-time responsiveness for user interactions while supporting scalable background processing for high-volume scenarios. Recommendations include documenting explicit error handling processes and defining retry policies for failed operations.

### Process Hierarchy

[DIAGRAM PLACEHOLDER: flowchart TD]

- Type: flowchart TD
- Components: [PROC-001, PROC-002, PROC-003, PROC-004, PROC-005, PROC-006, PROC-007, PROC-008, PROC-009]
- Style: processL0, processL1, processL2, processL3

### Process Interactions

[DIAGRAM PLACEHOLDER: sequenceDiagram]

- Type: sequenceDiagram
- Components: [ACT-002, SVC-006, SVC-004, SVC-005, SVC-001, SVC-002, SVC-003, EVT-001, PROC-008]

### Process Catalog

| Process ID | Process Name           | Level | Parent Process | Triggering Event | Owner   | Source File                                                     |
| ---------- | ---------------------- | ----- | -------------- | ---------------- | ------- | --------------------------------------------------------------- |
| PROC-001   | Place Order            | L1    | -              | User Request     | CAP-001 | `src/eShop.Orders.API/Controllers/OrdersController.cs:40-50`    |
| PROC-002   | Place Orders Batch     | L2    | PROC-001       | User Request     | CAP-001 | `src/eShop.Orders.API/Controllers/OrdersController.cs:126-134`  |
| PROC-003   | Process Order          | L2    | PROC-001       | EVT-001          | CAP-001 | `src/eShop.Orders.API/Controllers/OrdersController.cs:198-208`  |
| PROC-004   | Get Orders             | L2    | -              | User Request     | CAP-001 | `src/eShop.Orders.API/Controllers/OrdersController.cs:218-223`  |
| PROC-005   | Get Order By ID        | L2    | PROC-004       | User Request     | CAP-001 | `src/eShop.Orders.API/Controllers/OrdersController.cs:262-270`  |
| PROC-006   | Delete Order           | L2    | -              | User Request     | CAP-001 | `src/eShop.Orders.API/Controllers/OrdersController.cs:318-327`  |
| PROC-007   | Delete Orders Batch    | L3    | PROC-006       | User Request     | CAP-001 | `src/eShop.Orders.API/Controllers/OrdersController.cs:385-393`  |
| PROC-008   | Orders Placed Process  | L1    | -              | EVT-002          | -       | `workflows/.../OrdersPlacedProcess/workflow.json:1-163`         |
| PROC-009   | Orders Placed Complete | L3    | PROC-008       | EVT-003          | -       | `workflows/.../OrdersPlacedCompleteProcess/workflow.json:1-105` |

---

## 4. Business Services

### Overview

Business Services represent the externally visible behavior offered by an organization or component to its consumers. In TOGAF's business architecture, services encapsulate capability implementations and expose well-defined contracts that specify what is offered without revealing how it is implemented. Services enable loose coupling between providers and consumers, supporting independent evolution and substitutability.

The eShop Orders Management Platform defines **6 business services** categorized as Internal services (consumed within the platform) and External services (consumed by actors outside the platform boundary). Internal services include Order Service (SVC-001), Order Repository (SVC-002), Orders Message Handler (SVC-003), and Orders API Service (SVC-004)—each defined through explicit C# interface contracts. External services include eShop Orders API (SVC-005) exposed as a RESTful HTTP endpoint and eShop Web App (SVC-006) providing the user interface.

The service architecture demonstrates a layered pattern where external services (SVC-005, SVC-006) delegate to internal services which in turn implement capability contracts. Service dependencies flow unidirectionally from consumer-facing services toward infrastructure services, maintaining a clean dependency hierarchy. The Orders API Service (SVC-004) in the web application acts as an anti-corruption layer that translates HTTP operations to typed method calls. Recommendations include documenting explicit service level agreements (SLAs) and versioning strategies for external services.

### Service Map

[DIAGRAM PLACEHOLDER: flowchart LR]

- Type: flowchart LR
- Components: [SVC-001, SVC-002, SVC-003, SVC-004, SVC-005, SVC-006]
- Relationships: [REL-001, REL-002, REL-004, REL-005, REL-018]
- Style: serviceCore, serviceInternal, serviceExternal

### Service Catalog

| Service ID | Service Name           | Type     | Provider | Consumer                  | Source File                                                       |
| ---------- | ---------------------- | -------- | -------- | ------------------------- | ----------------------------------------------------------------- |
| SVC-001    | Order Service          | Internal | CAP-002  | SVC-003                   | `src/eShop.Orders.API/Interfaces/IOrderService.cs:8-15`           |
| SVC-002    | Order Repository       | Internal | CAP-004  | SVC-001                   | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs:8-15`        |
| SVC-003    | Orders Message Handler | Internal | CAP-003  | SVC-001                   | `src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs:8-13`   |
| SVC-004    | Orders API Service     | Internal | SVC-005  | SVC-006                   | `src/eShop.Web.App/Components/Services/OrdersAPIService.cs:13-17` |
| SVC-005    | eShop Orders API       | External | CAP-001  | ACT-001, ACT-002, ACT-003 | `azure.yaml:51-57`                                                |
| SVC-006    | eShop Web App          | External | -        | ACT-002                   | `azure.yaml:51-57`                                                |

---

## 5. Business Functions

### Overview

Business Functions represent discrete units of business behavior that collectively implement business services and realize capabilities. In the TOGAF BDAT model, functions are more granular than processes and describe specific operations that can be composed into larger workflows. Functions typically correspond to individual operations or methods in the implementation.

Analysis revealed **10 business functions** supporting the platform's three core capabilities. Data Persistence functions (FUNC-001 through FUNC-006) include Save Order, Get All Orders, Get Orders Paged, Get Order By Id, Delete Order, and Order Exists—providing complete CRUD operations with pagination support. Order Processing includes the Validate Order function (FUNC-007) for input validation. Message Publishing functions (FUNC-008 through FUNC-010) include Send Order Message, Send Orders Batch Message, and List Messages for Service Bus integration.

The function hierarchy shows L2 functions as primary operations and L3 functions as specialized variants or utility operations. Get Orders Paged (FUNC-003) extends Get All Orders (FUNC-002) with pagination, while Order Exists (FUNC-006) provides an optimized check operation. The batch messaging function (FUNC-009) extends single message sending (FUNC-008). This granular decomposition enables reuse of common operations while supporting specialized requirements. Recommendations include adding transaction management functions and expanding validation functions to support custom business rules.

### Function Hierarchy

[DIAGRAM PLACEHOLDER: flowchart TB]

- Type: flowchart TB
- Components: [FUNC-001, FUNC-002, FUNC-003, FUNC-004, FUNC-005, FUNC-006, FUNC-007, FUNC-008, FUNC-009, FUNC-010]
- Style: capCore, capSupporting

### Function Catalog

| Function ID | Function Name             | Level | Parent   | Capability | Source File                                                      |
| ----------- | ------------------------- | ----- | -------- | ---------- | ---------------------------------------------------------------- |
| FUNC-001    | Save Order                | L2    | -        | CAP-004    | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs:17-22`      |
| FUNC-002    | Get All Orders            | L2    | -        | CAP-004    | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs:24-31`      |
| FUNC-003    | Get Orders Paged          | L2    | FUNC-002 | CAP-004    | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs:33-42`      |
| FUNC-004    | Get Order By Id           | L2    | -        | CAP-004    | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs:44-50`      |
| FUNC-005    | Delete Order              | L2    | -        | CAP-004    | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs:52-58`      |
| FUNC-006    | Order Exists              | L3    | FUNC-004 | CAP-004    | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs:60-68`      |
| FUNC-007    | Validate Order            | L2    | -        | CAP-002    | `src/eShop.Orders.API/Services/OrderService.cs:100`              |
| FUNC-008    | Send Order Message        | L3    | -        | CAP-003    | `src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs:15-21` |
| FUNC-009    | Send Orders Batch Message | L3    | FUNC-008 | CAP-003    | `src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs:23-29` |
| FUNC-010    | List Messages             | L3    | -        | CAP-003    | `src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs:31-37` |

---

## 6. Organizational Structure

### Overview

Organizational Structure defines the formal arrangement of roles, teams, and departments that execute business processes and own business capabilities. In TOGAF's business architecture, the organizational model identifies who is responsible for what within the enterprise, establishing clear accountability and governance boundaries.

**Note**: Organizational Unit information not found in codebase. The eShop Orders Management Platform codebase does not contain explicit organizational structure documentation such as org charts, team definitions, or departmental assignments. The architecture follows a microservices pattern that is organizationally agnostic, suggesting a product-team or capability-aligned organizational model would be appropriate.

Based on the capability structure, a recommended organizational model would include an Order Management team owning CAP-001 through CAP-004, with potential sub-teams for API Development, Data Engineering, and DevOps/Platform. The Logic Apps workflows (PROC-008, PROC-009) may be owned by an Integration team or shared with the core Order Management team. Formal organizational documentation should be created to establish clear ownership and escalation paths.

### Organizational Chart

**Note**: No organizational chart data available in codebase.

### Organizational Unit Catalog

| Org Unit ID | Org Unit Name | Level | Parent | Type | Source File |
| ----------- | ------------- | ----- | ------ | ---- | ----------- |
| -           | -             | -     | -      | -    | Not Found   |

---

## 7. Actors & Stakeholders

### Overview

Actors and Stakeholders represent the individuals, roles, or external systems that interact with the business architecture. In TOGAF's business layer, actors are entities that perform behavior or participate in processes, while stakeholders have an interest in the architecture outcomes. Understanding actors is essential for defining service boundaries, access controls, and user experience requirements.

The eShop Orders Management Platform identifies **3 actor types**: Customer (ACT-001), Web App User (ACT-002), and API Consumer (ACT-003). The Customer represents the business entity who places orders and is referenced through the CustomerId property in order data models. The Web App User interacts with the platform through the Blazor Server web interface (SVC-006), accessing order management features including placing orders, viewing order lists, and tracking order status. The API Consumer represents external systems or integrations that consume the Orders API (SVC-005) directly.

The actor model reflects a multi-channel architecture where the same core services (SVC-005) can be accessed through different interfaces. Web App Users receive a guided UI experience through SVC-006 which internally uses SVC-004 to communicate with the API, while API Consumers interact directly with SVC-005. This separation enables different user experiences while maintaining consistent business logic. Recommendations include defining explicit authentication/authorization requirements for each actor type and documenting API consumer integration patterns.

### Actor Interaction Map

[DIAGRAM PLACEHOLDER: flowchart]

- Type: flowchart
- Components: [ACT-001, ACT-002, ACT-003, SVC-005, SVC-006]
- Style: actorInternal, actorExternal

### Actor Catalog

| Actor ID | Actor Name   | Type     | Org Unit | Interactions     | Source File                                                  |
| -------- | ------------ | -------- | -------- | ---------------- | ------------------------------------------------------------ |
| ACT-001  | Customer     | External | -        | SVC-005          | `app.ServiceDefaults/CommonTypes.cs:78-83`                   |
| ACT-002  | Web App User | External | -        | SVC-006, SVC-005 | `src/eShop.Web.App/Components/Pages/Home.razor:1-50`         |
| ACT-003  | API Consumer | External | -        | SVC-005          | `src/eShop.Orders.API/Controllers/OrdersController.cs:13-17` |

---

## 8. Value Streams

### Overview

Value Streams represent the end-to-end sequences of activities that deliver value to customers or stakeholders. In TOGAF's business architecture, value streams provide a holistic view of how the organization creates, delivers, and captures value, transcending functional boundaries to show the complete customer journey. Value streams are particularly useful for identifying bottlenecks, handoff points, and optimization opportunities.

The eShop Orders Management Platform implements **1 primary value stream**: Order Fulfillment Flow (VS-001). This value stream encompasses the complete lifecycle from order placement by a customer through final processing and cleanup. The flow consists of 4 distinct stages: (1) Order Placement where a customer submits an order through the web application, (2) Message Publishing where the order event is published to Azure Service Bus, (3) Order Processing Workflow where the Logic Apps workflow processes the order and stores results, and (4) Completion/Cleanup where processed orders are archived and temporary artifacts are removed.

The value stream demonstrates an event-driven architecture pattern that decouples order submission from processing, enabling scalability and resilience. The Order Placed event (EVT-001) acts as the handoff point between synchronous (user-facing) and asynchronous (workflow-based) processing. The value stream supports the strategic goal of streamlined order processing (GOAL-001) by automating the end-to-end flow. Recommendations include adding monitoring dashboards to visualize value stream performance, implementing SLA tracking for each stage, and documenting alternative flows for error scenarios.

### Value Stream Map

[DIAGRAM PLACEHOLDER: flowchart LR]

- Type: flowchart LR
- Components: [VS-001, PROC-001, EVT-001, PROC-008, PROC-009]
- Style: valueStream, valueStage

### Customer Journey

[DIAGRAM PLACEHOLDER: journey]

- Type: journey
- Sections: Order Placement, Processing, Completion
- Actors: ACT-001

### Value Stream Catalog

| VS ID  | Value Stream Name      | Stages | Stakeholder | Capabilities | Source File                                             |
| ------ | ---------------------- | ------ | ----------- | ------------ | ------------------------------------------------------- |
| VS-001 | Order Fulfillment Flow | 4      | ACT-001     | CAP-001      | `workflows/.../OrdersPlacedProcess/workflow.json:1-163` |

**Value Stream Stages (VS-001)**:

| Stage | Name               | Process  | Description                                        |
| ----- | ------------------ | -------- | -------------------------------------------------- |
| 1     | Order Placement    | PROC-001 | Customer submits order through web application     |
| 2     | Message Publishing | EVT-001  | Order event published to Service Bus topic         |
| 3     | Order Processing   | PROC-008 | Logic Apps workflow processes and stores order     |
| 4     | Completion         | PROC-009 | Cleanup of processed orders from temporary storage |

---

## 9. Business Objects

### Overview

Business Objects represent the passive structural elements that are created, manipulated, and consumed by business processes. In TOGAF's business architecture, business objects are domain concepts that hold meaning for the business and form the semantic foundation of the information architecture. Business objects typically map to data entities but are defined by their business meaning rather than their technical representation.

The eShop Orders Management Platform defines **4 business objects** in two categories: Domain Models (OBJ-001, OBJ-002) representing the logical business concepts, and Persistence Models (OBJ-003, OBJ-004) representing the database entities. The Order (OBJ-001) is the central business object containing customer information, delivery address, total amount, and a collection of products. OrderProduct (OBJ-002) represents individual line items within an order, including product identification, description, quantity, and price.

The dual-model approach (Domain and Persistence) reflects a clean architecture pattern that separates business logic from data access concerns. Order and OrderProduct are defined as C# record types in the shared ServiceDefaults library, ensuring consistent semantics across all services. OrderEntity and OrderProductEntity are EF Core entity classes with database mapping attributes. This separation enables business rules to operate on domain models while persistence models handle database-specific concerns. Recommendations include adding order status tracking, implementing audit fields (created/modified timestamps), and defining explicit state machine transitions for order lifecycle.

### Business Object Model

[DIAGRAM PLACEHOLDER: erDiagram]

- Type: erDiagram
- Components: [OBJ-001, OBJ-002, OBJ-003, OBJ-004]
- Relationships: [REL-009, REL-010]
- Style: businessObject

### Business Object Catalog

| Object ID | Object Name        | Category    | Processes            | States                      | Source File                                                      |
| --------- | ------------------ | ----------- | -------------------- | --------------------------- | ---------------------------------------------------------------- |
| OBJ-001   | Order              | Domain      | PROC-001 to PROC-007 | Created, Processed, Deleted | `app.ServiceDefaults/CommonTypes.cs:68-113`                      |
| OBJ-002   | OrderProduct       | Domain      | PROC-001, PROC-002   | -                           | `app.ServiceDefaults/CommonTypes.cs:115-154`                     |
| OBJ-003   | OrderEntity        | Persistence | FUNC-001 to FUNC-006 | Persisted                   | `src/eShop.Orders.API/data/Entities/OrderEntity.cs:10-55`        |
| OBJ-004   | OrderProductEntity | Persistence | FUNC-001             | Persisted                   | `src/eShop.Orders.API/data/Entities/OrderProductEntity.cs:11-62` |

**Order (OBJ-001) Attributes**:

| Attribute       | Type               | Description                   | Validation                 |
| --------------- | ------------------ | ----------------------------- | -------------------------- |
| Id              | string             | Unique order identifier       | Required, 1-100 characters |
| CustomerId      | string             | Customer who placed the order | Required, 1-100 characters |
| Date            | DateTime           | Order placement timestamp     | Defaults to UTC now        |
| DeliveryAddress | string             | Shipping destination          | Required, 5-500 characters |
| Total           | decimal            | Order total amount            | Required, > 0              |
| Products        | List<OrderProduct> | Line items in the order       | Required, minimum 1 item   |

---

## 10. Business Goals

### Overview

Business Goals represent the desired end states or outcomes that the organization seeks to achieve through its business architecture. In TOGAF's business layer, goals provide strategic direction and serve as the rationale for capability investments and process improvements. Goals can be hierarchical, with strategic goals decomposing into tactical objectives that guide specific initiatives.

The eShop Orders Management Platform documentation reveals **3 business goals** identified from the user interface content. The primary strategic goal—Streamline Order Processing (GOAL-001)—establishes the platform's core value proposition of simplifying order management through cloud-powered automation. Two tactical goals support this strategy: Real-time Order Tracking (GOAL-002) focuses on instant visibility into order status, while Enterprise-grade Reliability (GOAL-003) targets operational excellence with a specific metric of 99.9% uptime SLA.

The goal hierarchy demonstrates alignment between strategic intent and measurable outcomes. GOAL-003 includes a quantifiable metric (99.9% uptime), providing a basis for architecture decisions around redundancy, failover, and resilience patterns. The goals are currently documented in user-facing content rather than formal strategy documents, suggesting an opportunity to formalize business objectives and establish additional KPIs for order processing throughput, error rates, and customer satisfaction. Recommendations include creating a formal OKR (Objectives and Key Results) framework and establishing goal-capability traceability matrices.

### Goal Hierarchy

[DIAGRAM PLACEHOLDER: mindmap]

- Type: mindmap
- Components: [GOAL-001, GOAL-002, GOAL-003]
- Style: strategic, capCore

### Business Goals Catalog

| Goal ID  | Goal Name                    | Type      | Parent   | Capabilities | Metrics          | Source File                                           |
| -------- | ---------------------------- | --------- | -------- | ------------ | ---------------- | ----------------------------------------------------- |
| GOAL-001 | Streamline Order Processing  | Strategic | -        | CAP-001      | -                | `src/eShop.Web.App/Components/Pages/Home.razor:16-18` |
| GOAL-002 | Real-time Order Tracking     | Tactical  | GOAL-001 | CAP-001      | -                | `src/eShop.Web.App/Components/Pages/Home.razor:66-74` |
| GOAL-003 | Enterprise-grade Reliability | Tactical  | GOAL-001 | CAP-001      | 99.9% Uptime SLA | `src/eShop.Web.App/Components/Pages/Home.razor:84-95` |

---

## 11. Relationships & Dependencies

### Overview

Relationships and Dependencies define how business architecture components interact with, depend upon, or realize each other. In TOGAF's business architecture, relationships provide the connective tissue that transforms isolated components into a coherent system. Understanding dependencies is essential for impact analysis, change management, and identifying critical paths.

The eShop Orders Management Platform exhibits **28 documented relationships** spanning all component categories. The relationship types follow ArchiMate 3.2 notation standards including: Realization (capabilities realizing services, functions realizing services), Triggering (processes triggering events, events triggering processes), Composition (objects containing other objects), Flow (services calling other services), Association (general relationships), Serving (services serving actors), Aggregation (value streams aggregating processes), and Access (services accessing data objects).

The dependency analysis reveals a layered architecture with clear directional flow. External actors depend on external services, which depend on internal services, which depend on capabilities. The event-driven architecture introduces asynchronous dependencies through the EVT-001 (Order Placed) event that decouples PROC-001 (Place Order) from PROC-008 (Orders Placed Process). Critical dependencies include the SVC-001→SVC-002 path for data persistence and the SVC-001→SVC-003 path for message publishing. Recommendations include documenting failure mode impacts for each critical dependency and establishing circuit breaker patterns for resilience.

### Dependency Map

[DIAGRAM PLACEHOLDER: flowchart]

- Type: flowchart
- Components: All component IDs
- Relationships: All relationship IDs
- Style: capCore, processL1, serviceCore

### Relationship Catalog

| Rel ID  | Source   | Relationship | Target   | Type        | Source File                                                     |
| ------- | -------- | ------------ | -------- | ----------- | --------------------------------------------------------------- |
| REL-001 | SVC-001  | Uses         | SVC-002  | Association | `src/eShop.Orders.API/Services/OrderService.cs:21`              |
| REL-002 | SVC-001  | Uses         | SVC-003  | Association | `src/eShop.Orders.API/Services/OrderService.cs:22`              |
| REL-003 | CAP-001  | Realizes     | SVC-001  | Realization | `src/eShop.Orders.API/Controllers/OrdersController.cs:21`       |
| REL-004 | SVC-004  | Calls        | SVC-005  | Flow        | `src/eShop.Web.App/Components/Services/OrdersAPIService.cs:70`  |
| REL-005 | SVC-006  | References   | SVC-005  | Association | `app.AppHost/AppHost.cs:24`                                     |
| REL-006 | PROC-001 | Triggers     | EVT-001  | Triggering  | `src/eShop.Orders.API/Services/OrderService.cs:109`             |
| REL-007 | EVT-001  | Triggers     | PROC-008 | Triggering  | `workflows/.../OrdersPlacedProcess/workflow.json:139-155`       |
| REL-008 | PROC-008 | Calls        | SVC-005  | Flow        | `workflows/.../OrdersPlacedProcess/workflow.json:17-30`         |
| REL-009 | OBJ-001  | Composition  | OBJ-002  | Composition | `app.ServiceDefaults/CommonTypes.cs:109-111`                    |
| REL-010 | OBJ-003  | Composition  | OBJ-004  | Composition | `src/eShop.Orders.API/data/Entities/OrderEntity.cs:51`          |
| REL-011 | ACT-001  | Creates      | OBJ-001  | Assignment  | `app.ServiceDefaults/CommonTypes.cs:78-83`                      |
| REL-012 | ACT-002  | Uses         | SVC-006  | Serving     | `src/eShop.Web.App/Components/Pages/Home.razor:1`               |
| REL-013 | SVC-002  | Accesses     | OBJ-003  | Access      | `src/eShop.Orders.API/Repositories/OrderRepository.cs:82-86`    |
| REL-014 | SVC-003  | Publishes    | EVT-001  | Flow        | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:88-95`   |
| REL-015 | CAP-002  | Realizes     | CAP-001  | Realization | `src/eShop.Orders.API/Services/OrderService.cs`                 |
| REL-016 | CAP-003  | Realizes     | CAP-001  | Realization | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs`         |
| REL-017 | CAP-004  | Realizes     | CAP-001  | Realization | `src/eShop.Orders.API/Repositories/OrderRepository.cs`          |
| REL-018 | SVC-005  | Serves       | SVC-006  | Serving     | `app.AppHost/AppHost.cs:24`                                     |
| REL-019 | SVC-005  | Serves       | PROC-008 | Serving     | `workflows/.../OrdersPlacedProcess/workflow.json:17-30`         |
| REL-020 | VS-001   | Aggregation  | PROC-008 | Aggregation | `workflows/.../OrdersPlacedProcess/workflow.json`               |
| REL-021 | VS-001   | Aggregation  | PROC-009 | Aggregation | `workflows/.../OrdersPlacedCompleteProcess/workflow.json`       |
| REL-022 | GOAL-002 | Supports     | CAP-001  | Association | `src/eShop.Web.App/Components/Pages/Home.razor:66-74`           |
| REL-023 | GOAL-001 | Guides       | VS-001   | Association | `src/eShop.Web.App/Components/Pages/Home.razor:16-18`           |
| REL-024 | FUNC-001 | Realizes     | SVC-002  | Realization | `src/eShop.Orders.API/Interfaces/IOrderRepository.cs`           |
| REL-025 | FUNC-007 | Realizes     | SVC-001  | Realization | `src/eShop.Orders.API/Services/OrderService.cs:100`             |
| REL-026 | FUNC-008 | Realizes     | SVC-003  | Realization | `src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs`      |
| REL-027 | EVT-003  | Triggers     | PROC-009 | Triggering  | `workflows/.../OrdersPlacedCompleteProcess/workflow.json:25-33` |
| REL-028 | ACT-003  | Uses         | SVC-005  | Serving     | `src/eShop.Orders.API/Controllers/OrdersController.cs:13-17`    |

---

## 12. Appendix

### Overview

The Appendix provides supplementary reference material supporting the Business Architecture Document. This section includes a glossary of business terms extracted from the codebase, a complete source file reference index, and additional notes on methodology and constraints. The appendix serves as a lookup reference for readers seeking clarification on terminology or traceability back to source artifacts.

All terms, definitions, and component descriptions in this document are derived directly from the analyzed codebase. No inferred or assumed information has been included, adhering to the documentation guidelines that require explicit source file traceability. Where business concepts are implied but not formally documented in the codebase, this has been noted as a gap requiring future formalization.

The source file references enable stakeholders to navigate directly to the implementation artifacts for detailed technical review. The glossary supports common understanding of business terminology across technical and non-technical audiences. Recommendations for future documentation iterations include expanding the glossary with formal business definitions and adding a change log to track document evolution.

### Glossary

| Term             | Definition                                                             | Context               |
| ---------------- | ---------------------------------------------------------------------- | --------------------- |
| Order            | A customer order with products, delivery information, and total amount | Domain Model          |
| OrderProduct     | A product item within an order including quantity and price            | Domain Model          |
| Customer         | Business entity who places orders, identified by CustomerId            | Actor                 |
| Place Order      | Process of creating and persisting a new order in the system           | Business Process      |
| Orders Placed    | Event published to Service Bus when an order is successfully placed    | Business Event        |
| Order Management | Capability for managing customer orders including CRUD operations      | Business Capability   |
| Order Processing | Business logic layer for order operations                              | Business Capability   |
| Value Stream     | End-to-end flow delivering value from order placement to completion    | Business Architecture |
| API Consumer     | External system or integration consuming the Orders API                | Actor                 |
| Batch Operation  | Processing multiple items in a single transaction for efficiency       | Process Pattern       |

### Source File References

| File Path                                                                                       | Components Documented          | Primary Section                  |
| ----------------------------------------------------------------------------------------------- | ------------------------------ | -------------------------------- |
| `src/eShop.Orders.API/Controllers/OrdersController.cs`                                          | CAP-001, PROC-001-007, ACT-003 | Capabilities, Processes          |
| `src/eShop.Orders.API/Services/OrderService.cs`                                                 | CAP-002, FUNC-007              | Capabilities, Functions          |
| `src/eShop.Orders.API/Repositories/OrderRepository.cs`                                          | CAP-004                        | Capabilities                     |
| `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs`                                         | CAP-003, EVT-001               | Capabilities, Events             |
| `src/eShop.Orders.API/Interfaces/IOrderService.cs`                                              | SVC-001                        | Services                         |
| `src/eShop.Orders.API/Interfaces/IOrderRepository.cs`                                           | SVC-002, FUNC-001-006          | Services, Functions              |
| `src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs`                                      | SVC-003, FUNC-008-010          | Services, Functions              |
| `app.ServiceDefaults/CommonTypes.cs`                                                            | OBJ-001, OBJ-002, ACT-001      | Business Objects, Actors         |
| `src/eShop.Orders.API/data/Entities/OrderEntity.cs`                                             | OBJ-003                        | Business Objects                 |
| `src/eShop.Orders.API/data/Entities/OrderProductEntity.cs`                                      | OBJ-004                        | Business Objects                 |
| `src/eShop.Web.App/Components/Services/OrdersAPIService.cs`                                     | SVC-004                        | Services                         |
| `src/eShop.Web.App/Components/Pages/Home.razor`                                                 | GOAL-001-003, ACT-002          | Goals, Actors                    |
| `app.AppHost/AppHost.cs`                                                                        | SVC-005, SVC-006               | Services                         |
| `azure.yaml`                                                                                    | SVC-005, SVC-006               | Services                         |
| `workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json`         | PROC-008, EVT-002, VS-001      | Processes, Events, Value Streams |
| `workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json` | PROC-009, EVT-003              | Processes, Events                |

### Document Validation

| Check | Criteria                                     | Status |
| ----- | -------------------------------------------- | ------ |
| V3-01 | All 12 sections present                      | ☑ Pass |
| V3-02 | Every section has 2-3 paragraph Overview     | ☑ Pass |
| V3-03 | All catalogs populated from Phase 2 data     | ☑ Pass |
| V3-04 | Diagram placeholders include component lists | ☑ Pass |
| V3-05 | Terminology consistent with source files     | ☑ Pass |
| V3-06 | All IDs match Phase 2 catalog                | ☑ Pass |

---

**Document Status**: Phase 3 Complete - Ready for Phase 4 (Diagram Generation)
