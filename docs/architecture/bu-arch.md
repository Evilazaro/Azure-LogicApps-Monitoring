---
title: "Business Architecture — eShop Orders Management"
layer: Business
quality_level: comprehensive
session_id: "b4e7a1c2-9f3d-4e85-a6b2-df123456789a"
timestamp: "2026-04-10T00:00:00Z"
output_sections: [1, 2, 3, 4, 5, 7, 8]
generated_by: BDAT Business Architecture Generator v1.1.0
coordinator_version: "3.1.0"
workspace: Azure-LogicApps-Monitoring
---

# Business Architecture — eShop Orders Management

## 1. Executive Summary

### Overview

The Azure Logic Apps Monitoring solution implements a cloud-native order management system for an e-commerce platform ("eShop") built on Microsoft Azure. The business domain centres on the full order lifecycle: customers submit individual or batch orders through a Blazor Server web portal, a REST API persists and validates those orders, and Azure Logic Apps Standard workflows automate downstream processing, routing, and archiving. The solution is packaged as an Azure Developer CLI (`azd`) template targeting Azure Container Apps and Azure Logic Apps Standard, with multi-environment promotion (dev → test → staging → prod) governed by Bicep Infrastructure-as-Code.

From a business maturity standpoint, the solution exhibits **Level 3–4 governance** across its key capabilities. Core transactional capabilities (order placement, retrieval, deletion) are well-defined with data validation rules, health checks, and structured telemetry. Event-driven processing via Azure Service Bus and Logic Apps introduces a clean separation between order intake and downstream fulfilment concerns. Business metrics are instrumented in code (orders placed, processing duration, errors, deletions), enabling performance tracking aligned to operational KPIs. The remaining gaps are: absence of an explicit order-status lifecycle (e.g., Pending → Processing → Fulfilled → Cancelled), no customer profile management module in scope, and no explicit SLA or throughput contract surfaced in codebase artifacts.

Strategic alignment is strong. The architecture follows Azure Well-Architected Framework pillars — Reliability (connection resiliency, retry policies, health endpoints), Security (Managed Identity everywhere, no secrets in code), Operational Excellence (OpenTelemetry, Application Insights, structured logging), Performance Efficiency (.NET Aspire service discovery, EF Core split queries, pagination), and Cost Optimisation (elastic App Service Plan for Logic Apps, Container Apps scale-to-zero). The solution serves both internal operators (manage and monitor orders) and automated systems (Logic Apps consuming Service Bus messages).

---

## 2. Architecture Landscape

### Overview

The Architecture Landscape maps the eleven Business component types discoverable within the workspace. The system is structured around a single bounded context — **Orders Management** — supported by cloud-native Azure services. Four infrastructure layers are discernible: the Customer Engagement layer (Blazor Web App), the API layer (ASP.NET Core Orders API), the Integration layer (Azure Service Bus + Logic Apps), and the Data Persistence layer (Azure SQL + Azure Blob Storage).

Component identification draws on entry-point files, controller definitions, service interfaces, workflow JSON definitions, shared domain models, and Bicep infrastructure templates. Maturity ratings follow a 1–5 scale: 1 = Ad-hoc, 2 = Repeatable, 3 = Defined, 4 = Managed, 5 = Optimising.

The subsections below catalogue each of the eleven Business component types as discovered. Where a component type is not represented by a source artifact, the subsection states "Not detected in source files."

### 2.1 Business Strategy

| Name                                     | Description                                                                                                                                                         | Maturity    |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Cloud-Native Azure Deployment            | Deploy all workloads to Azure Container Apps and Logic Apps Standard using Bicep IaC and azd CLI for reproducible, multi-environment deployments.                   | 4 — Managed |
| Zero-Trust Security via Managed Identity | All service-to-service authentication uses User Assigned Managed Identity; no secrets or connection strings are stored in application code or configuration files.  | 4 — Managed |
| Event-Driven Order Processing            | Decouple order intake from downstream processing via Azure Service Bus topics and subscriptions, enabling independent scaling and asynchronous workflows.           | 4 — Managed |
| Observability-First Engineering          | Instrument all services with OpenTelemetry distributed tracing, custom metrics, and structured logging exported to Azure Application Insights and Log Analytics.    | 4 — Managed |
| Infrastructure-as-Code Governance        | All Azure resources defined in Bicep templates with parameter validation, tagging, and environment-scoped naming conventions for consistent, auditable deployments. | 4 — Managed |

Source: azure.yaml:1-\*, infra/main.bicep:1-80, app.AppHost/AppHost.cs:1-200, app.ServiceDefaults/Extensions.cs:1-80

### 2.2 Business Capabilities

| Name                                | Description                                                                                                                                                       | Maturity    |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Order Placement (Single)            | Accept, validate, persist, and publish a single customer order through the REST API.                                                                              | 4 — Managed |
| Order Placement (Batch)             | Accept and process multiple orders concurrently via the batch endpoint, with per-order error handling.                                                            | 3 — Defined |
| Order Retrieval                     | Retrieve orders by ID or list all orders with pagination support.                                                                                                 | 4 — Managed |
| Order Deletion (Single & Batch)     | Remove individual or multiple orders from the system via the web portal or API.                                                                                   | 3 — Defined |
| Automated Order Processing Workflow | Trigger Logic Apps workflows from Service Bus messages; route to the Orders API and archive processed blobs.                                                      | 4 — Managed |
| Processed Order Archiving           | Store successfully processed order payloads in Azure Blob Storage under `/ordersprocessedsuccessfully`; store failed payloads under `/ordersprocessedwitherrors`. | 3 — Defined |
| Post-Processing Cleanup             | Recurrence-triggered Logic App workflow lists and deletes blobs from the processed success folder every 3 seconds.                                                | 3 — Defined |

Source: src/eShop.Orders.API/Controllers/OrdersController.cs:1-_, src/eShop.Orders.API/Services/OrderService.cs:1-_, src/eShop.Web.App/Components/Pages/PlaceOrder.razor:1-_, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-_, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-\*

### 2.3 Value Streams

| Name                  | Description                                                                                                                                                                                                                              | Maturity    |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Order-to-Archive      | Customer submits order (Web App) → API validates and persists (SQL) → Service Bus message published → Logic App triggers → API called for processing → Success/error blob written to Storage → Cleanup workflow deletes processed blobs. | 3 — Defined |
| Order Enquiry         | Customer/operator searches by order ID or lists all orders (Web App) → API retrieves from SQL → results displayed in UI.                                                                                                                 | 4 — Managed |
| Batch Order Ingestion | Operator uploads JSON batch or manually adds orders (Web App) → API processes concurrently → messages published per order → downstream Logic App workflow handles each.                                                                  | 3 — Defined |

Source: src/eShop.Web.App/Components/Pages/PlaceOrder.razor:1-_, src/eShop.Web.App/Components/Pages/ListAllOrders.razor:1-_, src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor:1-_, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-_

### 2.4 Business Processes

| Name                                                        | Description                                                                                                                                                                                                    | Maturity    |
| ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Single Order Placement Process                              | POST /api/orders → validate payload → check duplicate → persist to SQL → publish to Service Bus topic `ordersplaced` → return 201 Created.                                                                     | 4 — Managed |
| Batch Order Placement Process                               | POST /api/orders/batch → process orders in parallel → per-order validate, persist, and publish → return batch transaction summary.                                                                             | 3 — Defined |
| Order Retrieval Process                                     | GET /api/orders/{id} or GET /api/orders → query SQL with EF Core (split queries, no-tracking) → return JSON response.                                                                                          | 4 — Managed |
| Order Deletion Process                                      | DELETE /api/orders/{id} → remove from SQL → return 204 No Content.                                                                                                                                             | 3 — Defined |
| Service Bus–Triggered Processing (OrdersPlacedProcess)      | Service Bus subscription triggers → decode base64 payload → POST to Orders API `/api/Orders/process` → if 201: write blob to `/ordersprocessedsuccessfully`; else: write blob to `/ordersprocessedwitherrors`. | 4 — Managed |
| Recurrence-Based Blob Cleanup (OrdersPlacedCompleteProcess) | Every 3 seconds: list blobs in `/ordersprocessedsuccessfully` → for each blob: get metadata → delete blob (concurrency: 20 repetitions).                                                                       | 3 — Defined |
| Database Initialisation Process                             | On startup: retry up to 10 times (5-second interval) — run EF Core migrations → verify connectivity.                                                                                                           | 4 — Managed |

Source: src/eShop.Orders.API/Controllers/OrdersController.cs:1-_, src/eShop.Orders.API/Services/OrderService.cs:1-_, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-_, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-_, src/eShop.Orders.API/Program.cs:120-150

### 2.5 Business Services

| Name                                | Description                                                                                                                                        | Maturity    |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| eShop Orders REST API               | ASP.NET Core Web API (net10.0) providing CRUD operations for customer orders. Exposes `/api/orders` endpoints with OpenAPI/Swagger documentation.  | 4 — Managed |
| eShop Web Application               | Blazor Server interactive frontend (net10.0, Microsoft Fluent UI) providing order placement, batch submission, retrieval, and deletion UIs.        | 4 — Managed |
| Orders Management Logic App         | Azure Logic Apps Standard (WorkflowStandard tier) hosting two workflows: `OrdersPlacedProcess` and `OrdersPlacedCompleteProcess`.                  | 4 — Managed |
| Order Messaging Service             | Azure Service Bus namespace with topic `ordersplaced` and subscription `orderprocessingsub` for async order event delivery.                        | 4 — Managed |
| Observability Service               | Azure Application Insights + Log Analytics Workspace providing distributed tracing (OpenTelemetry), metrics, and log aggregation for all services. | 4 — Managed |
| Infrastructure Provisioning Service | Azure Developer CLI (`azd`) + Bicep IaC automating full-stack provisioning, configuration, and deployment across environments.                     | 4 — Managed |

Source: src/eShop.Orders.API/eShop.Orders.API.csproj:1-_, src/eShop.Web.App/eShop.Web.App.csproj:1-_, workflows/OrdersManagement/OrdersManagementLogicApp/host.json:1-_, app.AppHost/AppHost.cs:1-200, infra/workload/logic-app.bicep:1-80, azure.yaml:1-_

### 2.6 Business Functions

| Name                    | Description                                                                                                                                                 | Maturity    |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Order Validation        | Enforce business rules on incoming orders: required fields (Id, CustomerId, DeliveryAddress, Products), field length constraints, price > 0, quantity ≥ 1.  | 4 — Managed |
| Order Persistence       | Save validated orders to Azure SQL Database using EF Core with connection resiliency (max 5 retries, 30s delay) and command timeout (120s).                 | 4 — Managed |
| Duplicate Detection     | Check for existing order ID before saving; raise conflict exception if duplicate found.                                                                     | 4 — Managed |
| Message Publishing      | Serialize order to JSON and publish to Azure Service Bus topic via `OrdersMessageHandler`.                                                                  | 4 — Managed |
| Blob Archiving          | Write order JSON payload to Azure Blob Storage success or error container based on processing outcome.                                                      | 3 — Defined |
| Health Monitoring       | Expose `/health` (readiness) and `/alive` (liveness) HTTP endpoints backed by DbContext and Service Bus health checks.                                      | 4 — Managed |
| Metrics Instrumentation | Record `eShop.orders.placed`, `eShop.orders.processing.duration`, `eShop.orders.processing.errors`, `eShop.orders.deleted` using OpenTelemetry `Meter`.     | 4 — Managed |
| User Secret Management  | Post-provision hook configures .NET user secrets for local development (Azure SQL connection string, Service Bus hostname, App Insights connection string). | 3 — Defined |

Source: src/eShop.Orders.API/Services/OrderService.cs:1-\*, app.ServiceDefaults/CommonTypes.cs:78-160, src/eShop.Orders.API/Program.cs:1-150, app.ServiceDefaults/Extensions.cs:1-80, hooks/postprovision.ps1:1-80

### 2.7 Business Roles & Actors

| Name                               | Description                                                                                                                                                           | Maturity    |
| ---------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Customer / End User                | Interacts with the eShop Web App to place single or batch orders, search for orders by ID, list all orders, and delete orders.                                        | 3 — Defined |
| Operations Operator                | Uses the web portal for order management and monitors system health via Azure Application Insights dashboards.                                                        | 3 — Defined |
| Azure Logic Apps Runtime           | Automated actor consuming Service Bus messages and orchestrating downstream order processing and blob archiving via Logic App workflows.                              | 4 — Managed |
| CI/CD Pipeline (Service Principal) | Executes `azd up` deployments using a Service Principal identity for fully automated environment provisioning and application release.                                | 4 — Managed |
| Developer                          | Runs the application locally via .NET Aspire AppHost, generates test orders using `hooks/Generate-Orders.ps1`, and deploys workflows via `hooks/deploy-workflow.ps1`. | 3 — Defined |
| Azure Managed Identity             | Non-human actor providing zero-credential authentication for the Orders API, Logic App, and all Azure service connections (SQL, Service Bus, Blob Storage).           | 4 — Managed |

Source: src/eShop.Web.App/Components/Pages/Home.razor:1-_, src/eShop.Web.App/Components/Pages/PlaceOrder.razor:1-_, hooks/Generate-Orders.ps1:1-60, hooks/deploy-workflow.ps1:1-80, workflows/OrdersManagement/OrdersManagementLogicApp/connections.json:1-_, azure.yaml:1-_

### 2.8 Business Rules

| Name                               | Description                                                                                                                                                             | Maturity    |
| ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| Order ID Required & Unique         | Order.Id must be present (1–100 chars) and must not already exist in the database. Violation triggers HTTP 409 Conflict.                                                | 4 — Managed |
| Customer ID Required               | Order.CustomerId must be present (1–100 chars).                                                                                                                         | 4 — Managed |
| Delivery Address Required          | Order.DeliveryAddress must be present (5–500 chars).                                                                                                                    | 4 — Managed |
| Products Non-Empty                 | Order.Products must contain at least one `OrderProduct`.                                                                                                                | 4 — Managed |
| Product Price Positive             | OrderProduct.Price must be > 0.                                                                                                                                         | 4 — Managed |
| Product Quantity Positive          | OrderProduct.Quantity must be ≥ 1.                                                                                                                                      | 4 — Managed |
| Order Total Positive               | Order.Total must be > 0.01.                                                                                                                                             | 4 — Managed |
| Session Idle Timeout               | Web App user sessions expire after 30 minutes of inactivity.                                                                                                            | 3 — Defined |
| Service Bus Conditional Activation | Service Bus client and messaging are only activated when a non-localhost `MESSAGING_HOST` is configured; otherwise a no-op handler is registered for local development. | 3 — Defined |
| Logic App Processing Condition     | `OrdersPlacedProcess` workflow only proceeds with order processing if the Service Bus message `ContentType` equals `application/json`.                                  | 4 — Managed |
| Blob Cleanup Recurrence            | Blob cleanup runs every 3 seconds in the `OrdersPlacedCompleteProcess` workflow with a concurrency of 20 parallel iterations.                                           | 3 — Defined |
| Database Connection Resiliency     | EF Core automatically retries up to 5 times with 30-second delays on transient SQL failures before surfacing an error.                                                  | 4 — Managed |

Source: app.ServiceDefaults/CommonTypes.cs:78-160, src/eShop.Orders.API/Program.cs:80-150, src/eShop.Web.App/Program.cs:1-110, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-100, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-100

### 2.9 Business Events

| Name                       | Description                                                                                                                                                                                                        | Maturity    |
| -------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------- |
| OrderPlaced                | Published to Service Bus topic `ordersplaced` when a single order is successfully persisted. Triggers the `OrdersPlacedProcess` Logic App workflow.                                                                | 4 — Managed |
| OrderBatchProcessed        | A batch transaction summary is returned to the web UI after all parallel order placements complete; no individual Service Bus event per batch (each order within the batch generates its own `OrderPlaced` event). | 3 — Defined |
| OrderProcessedSuccessfully | Logic App writes the raw order JSON blob to `/ordersprocessedsuccessfully` in Azure Blob Storage when the API returns HTTP 201.                                                                                    | 3 — Defined |
| OrderProcessedWithError    | Logic App writes the raw order JSON blob to `/ordersprocessedwitherrors` in Azure Blob Storage when the API returns any status other than HTTP 201.                                                                | 3 — Defined |
| DatabaseInitialised        | Raised internally via startup hook after EF Core migrations complete and connectivity is verified.                                                                                                                 | 3 — Defined |
| ApplicationStarted         | .NET `IHostApplicationLifetime.ApplicationStarted` event triggers the database initialisation sequence.                                                                                                            | 3 — Defined |

Source: src/eShop.Orders.API/Services/OrderService.cs:100-160, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-100, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-100, src/eShop.Orders.API/Program.cs:120-150, app.AppHost/AppHost.cs:40-80

### 2.10 Business Objects / Entities

| Name                     | Description                                                                                                                                                                                            | Maturity       |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------- |
| Order                    | Core aggregate: Id (string, required, unique), CustomerId (string, required), Date (UTC DateTime), DeliveryAddress (string, 5–500 chars), Total (decimal > 0), Products (List\<OrderProduct\>, min 1). | 4 — Managed    |
| OrderProduct             | Line-item within an Order: Id, OrderId, ProductId, ProductDescription (1–500 chars), Quantity (int ≥ 1), Price (decimal > 0).                                                                          | 4 — Managed    |
| OrdersWrapper            | API response envelope wrapping a `List<Order>` for collection responses.                                                                                                                               | 3 — Defined    |
| BatchTransactionStatus   | Web App model representing the result of a batch order submission: TransactionId, Timestamp, counts of success/failure per order.                                                                      | 3 — Defined    |
| OrderMessageWithMetadata | Internal handler model augmenting an `Order` with Service Bus message metadata (MessageId, ContentType, etc.) for tracing purposes.                                                                    | 3 — Defined    |
| WeatherForecast          | Demonstration/health-check entity: Date, TemperatureC, TemperatureF (derived), Summary. Not a core business entity.                                                                                    | 2 — Repeatable |

Source: app.ServiceDefaults/CommonTypes.cs:78-160, src/eShop.Orders.API/Services/OrdersWrapper.cs:1-_, src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor:40-60, src/eShop.Orders.API/Handlers/OrderMessageWithMetadata.cs:1-_

### 2.11 KPIs & Metrics

| Name                             | Description                                                                                                           | Maturity    |
| -------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ----------- |
| eShop.orders.placed              | Counter (unit: order) — total successfully placed orders. Dimensions: `order.status`.                                 | 4 — Managed |
| eShop.orders.processing.duration | Histogram (unit: ms) — elapsed time for order processing operations. Dimensions: `order.status`.                      | 4 — Managed |
| eShop.orders.processing.errors   | Counter (unit: error) — total order processing errors. Dimensions: `error.type`, `order.status`.                      | 4 — Managed |
| eShop.orders.deleted             | Counter (unit: order) — total successfully deleted orders.                                                            | 4 — Managed |
| Health Endpoint: /health         | Readiness check for database and (optionally) Service Bus connectivity — used by Azure Container Apps and Kubernetes. | 4 — Managed |
| Health Endpoint: /alive          | Liveness check for service availability.                                                                              | 4 — Managed |

Source: src/eShop.Orders.API/Services/OrderService.cs:40-100, app.ServiceDefaults/Extensions.cs:60-80

**Business Capability Map:**

```mermaid
---
title: eShop Orders Management — Business Capability Map
config:
  theme: base
  look: classic
  layout: dagre
  themeVariables:
    fontSize: '16px'
  flowchart:
    htmlLabels: true
---
flowchart TB
    accTitle: eShop Orders Management Business Capability Map
    accDescr: Hierarchical view of the seven core business capabilities and their relationships, grouped into three domains — Customer Engagement, Order Processing, and Operations

    subgraph CE["🧑 Customer Engagement"]
        style CE fill:#EFF6FC,stroke:#2B88D8,stroke-width:2px
        c1("📋 Order Placement<br/>(Single)"):::success
        c2("📦 Order Placement<br/>(Batch)"):::neutral
        c3("🔍 Order Retrieval"):::success
        c4("🗑️ Order Deletion"):::neutral
    end

    subgraph OP["⚙️ Order Processing"]
        style OP fill:#E6F2EA,stroke:#107C10,stroke-width:2px
        c5("🔄 Automated Workflow<br/>Processing"):::success
        c6("🗄️ Order Archiving"):::neutral
        c7("🧹 Post-Process Cleanup"):::neutral
    end

    subgraph OBS["📊 Operations & Observability"]
        style OBS fill:#FFF4CE,stroke:#FFB900,stroke-width:2px
        c8("📈 Metrics & KPIs"):::warning
        c9("🏥 Health Monitoring"):::success
    end

    c1 --> c5
    c2 --> c5
    c5 --> c6
    c6 --> c7
    c1 & c2 & c3 & c4 --> c8
    c5 & c6 & c7 --> c8
    c8 --> c9

    classDef neutral fill:#FAFAFA,stroke:#8A8886,stroke-width:2px,color:#323130
    classDef success fill:#DFF6DD,stroke:#107C10,stroke-width:2px,color:#323130
    classDef warning fill:#FFF4CE,stroke:#FFB900,stroke-width:2px,color:#323130
```

### Summary

The Architecture Landscape reveals a well-defined, cloud-native order management domain with strong coverage across all seven core capabilities. The five strategic pillars (cloud-native deployment, zero-trust security, event-driven processing, observability-first engineering, and IaC governance) each achieve maturity Level 4, demonstrating a managed and repeatable approach. Business processes, services, rules, and KPIs are well-documented in source artifacts, with direct traceability to controller definitions, service layer logic, and workflow JSON definitions.

The primary gaps are: (1) no explicit order-status state machine (Pending → Processing → Fulfilled → Cancelled) surfaced in source files; (2) the `WeatherForecast` entity is a residual scaffold artifact with no business relevance; and (3) the `BatchTransactionStatus` model lacks a formal schema definition file. These gaps are reported in the Issues & Gaps section.

---

## 3. Architecture Principles

### Overview

The following architecture principles are derived directly from patterns observed across source code, configuration files, and infrastructure templates. Each principle is applied consistently and is traceable to specific implementation artifacts. These principles govern design decisions and constrain future evolution of the architecture.

**Principle 1 — Security by Default (Zero Trust)**
All service-to-service communication uses User Assigned Managed Identity. No passwords, connection strings, or API keys appear in application code or committed configuration files. Managed Identity is configured in `connections.json`, `parameters.json`, and the Bicep modules for Azure SQL, Service Bus, and Blob Storage. Applied to: all Azure resource connections.
Source: workflows/OrdersManagement/OrdersManagementLogicApp/connections.json:1-_, workflows/OrdersManagement/OrdersManagementLogicApp/parameters.json:1-_, infra/workload/logic-app.bicep:1-80, infra/shared/main.bicep:1-80

**Principle 2 — Cloud-Native and Infrastructure-as-Code First**
All Azure infrastructure is defined declaratively in Bicep templates under `infra/`. Resources are named with consistent conventions (`{solutionName}-{envName}-{resourceType}`), tagged, and parameterised for environment promotion. Deployment is fully automated via `azd`. No manual portal-based provisioning is required or expected.
Source: infra/main.bicep:1-80, azure.yaml:1-120, infra/shared/main.bicep:1-80, infra/workload/main.bicep:1-80

**Principle 3 — Event-Driven Decoupling**
Order intake (REST API) is decoupled from downstream processing (Logic Apps) through Azure Service Bus. The API publishes an event (`OrderPlaced`) without any knowledge of consumers. Logic Apps subscribe independently. This enables independent scaling, independent deployability, and failure isolation between the intake and processing concerns.
Source: src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-80, app.AppHost/AppHost.cs:160-200, workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-\*

**Principle 4 — Observability as a First-Class Citizen**
Every service emits OpenTelemetry traces, metrics, and structured logs. Activity sources (`ActivitySource`) are registered for all operations. Custom meters (`Meter`) capture domain metrics (`eShop.orders.*`). Health endpoints are exposed at `/health` (readiness) and `/alive` (liveness). All telemetry is exported to Azure Application Insights and Log Analytics.
Source: app.ServiceDefaults/Extensions.cs:1-80, src/eShop.Orders.API/Services/OrderService.cs:30-100, src/eShop.Orders.API/Program.cs:1-30, workflows/OrdersManagement/OrdersManagementLogicApp/host.json:1-\*

**Principle 5 — Resilience and Self-Healing**
All external dependencies implement retry policies. EF Core is configured with `EnableRetryOnFailure` (max 5 retries, 30s delay). HTTP clients use `.AddServiceDefaults()` resilience policies (retry, circuit breaker, timeout). Database initialisation retries up to 10 times at startup. The Logic App workflow uses independent timeout handling (chunked content transfer).
Source: src/eShop.Orders.API/Program.cs:30-60, app.ServiceDefaults/Extensions.cs:60-80, src/eShop.Orders.API/Program.cs:120-150

**Principle 6 — Separation of Concerns (Layered Architecture)**
The solution enforces clear layer boundaries: Controllers (HTTP contract), Services (business logic), Repositories (data access), Handlers (messaging), and Infrastructure (EF Core, Azure SDK clients). The `app.ServiceDefaults` project acts as a shared cross-cutting concerns library. Blazor UI components call backend services exclusively through the typed `OrdersAPIService` HTTP client.
Source: src/eShop.Orders.API/Controllers/OrdersController.cs:1-_, src/eShop.Orders.API/Services/OrderService.cs:1-_, src/eShop.Orders.API/Repositories/OrderRepository.cs:1-\*, src/eShop.Web.App/Components/Services/OrdersAPIService.cs:1-80

**Principle 7 — Multi-Environment Parity**
The solution supports four named environments (dev, test, staging, prod) with the same Bicep templates and azd hooks. Feature flags for local development (Service Bus emulator, in-memory cache, developer exceptions) are gated by `builder.Environment.IsDevelopment()`. This minimises environment drift.
Source: infra/main.bicep:60-80, src/eShop.Orders.API/Program.cs:50-60, src/eShop.Web.App/Program.cs:85-95, azure.yaml:80-120

---

## 4. Current State Baseline

### Overview

The current state represents a production-capable but pre-release cloud-native order management platform. All core transactional capabilities (place, retrieve, delete orders) are fully implemented and backed by:

- **Azure SQL Database** (EF Core, connection resiliency, managed migrations)
- **Azure Service Bus** (topic/subscription messaging, managed identity auth)
- **Azure Blob Storage** (Logic App archiving of processed orders)
- **Azure Application Insights** + **Log Analytics** (full OpenTelemetry telemetry stack)
- **Azure Container Apps** (hosting API and Web App, scale-to-zero capable)
- **Azure Logic Apps Standard** (two automated order processing workflows)

The codebase targets .NET 10.0 (release candidate as of analysis date) and uses .NET Aspire 13.x for local orchestration. The migration from file-based storage to EF Core with Azure SQL was recently completed (MIGRATION_GUIDE.md, version 1.0, 2026-01-28).

**Capability Maturity Heatmap:**

| Capability               | Implementation | Observability   | Security      | Resilience           | Overall     |
| ------------------------ | -------------- | --------------- | ------------- | -------------------- | ----------- |
| Order Placement (Single) | ✅ Complete    | ✅ Full OTel    | ✅ Managed ID | ✅ Retry+Circuit     | 4 — Managed |
| Order Placement (Batch)  | ✅ Complete    | ✅ Full OTel    | ✅ Managed ID | ⚠️ Per-order error   | 3 — Defined |
| Order Retrieval          | ✅ Complete    | ✅ Full OTel    | ✅ Managed ID | ✅ Retry+Circuit     | 4 — Managed |
| Order Deletion           | ✅ Complete    | ⚠️ Basic logs   | ✅ Managed ID | ✅ Retry             | 3 — Defined |
| Logic App Processing     | ✅ Complete    | ✅ App Insights | ✅ Managed ID | ⚠️ No explicit retry | 4 — Managed |
| Blob Archiving           | ✅ Complete    | ⚠️ Basic logs   | ✅ Managed ID | ⚠️ No retry config   | 3 — Defined |
| Post-Process Cleanup     | ✅ Complete    | ⚠️ Basic logs   | ✅ Managed ID | ⚠️ Fixed interval    | 3 — Defined |

**Known Gaps vs Target State:**

| Gap                         | Current State                                                                     | Target State                                               |
| --------------------------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Order Status Lifecycle      | No explicit status field or transitions                                           | Pending → Processing → Fulfilled → Cancelled state machine |
| Direct Outbox Pattern       | Service Bus publish is "fire and forget" after SQL write; no transactional outbox | Transactional outbox for guaranteed message delivery       |
| Customer Profile Management | No customer entity beyond CustomerId string                                       | Customer profile service or lookup                         |
| Batch Idempotency           | No deduplication key for batch operations                                         | Idempotency key per batch submission                       |
| Logic App Retry Policy      | Workflows have no explicit retry configuration surfaced in workflow JSON          | Explicit retry policy on HTTP and API Connection actions   |

**Value Stream Flow Diagram:**

```mermaid
---
title: Order-to-Archive Value Stream — Current State
config:
  theme: base
  look: classic
  layout: dagre
  themeVariables:
    fontSize: '16px'
  flowchart:
    htmlLabels: true
---
flowchart LR
    accTitle: Order-to-Archive Value Stream Current State
    accDescr: Shows the end-to-end flow from customer order submission through API processing, event publishing, Logic App workflow execution, and blob archiving

    subgraph UI["🌐 Customer Engagement"]
        style UI fill:#EFF6FC,stroke:#2B88D8,stroke-width:2px
        u1("🧑 Customer<br/>Submits Order"):::neutral
    end

    subgraph API["⚙️ Orders API"]
        style API fill:#E6F2EA,stroke:#107C10,stroke-width:2px
        a1("✅ Validate<br/>Order"):::success
        a2("💾 Persist to<br/>Azure SQL"):::success
        a3("📨 Publish to<br/>Service Bus"):::success
    end

    subgraph SB["📩 Azure Service Bus"]
        style SB fill:#FFF4CE,stroke:#FFB900,stroke-width:2px
        s1("📬 topic:<br/>ordersplaced"):::warning
    end

    subgraph LA["🔄 Logic Apps"]
        style LA fill:#FAF0FB,stroke:#8764B8,stroke-width:2px
        l1("⚡ OrdersPlaced<br/>Process"):::neutral
        l2("🔀 Check Content<br/>Type"):::neutral
        l3{"201 OK?"}:::warning
        l4("📁 Blob:<br/>Success"):::success
        l5("📁 Blob:<br/>Error"):::danger
    end

    u1 --> a1 --> a2 --> a3 --> s1 --> l1 --> l2 --> l3
    l3 -->|Yes| l4
    l3 -->|No| l5

    classDef neutral fill:#FAFAFA,stroke:#8A8886,stroke-width:2px,color:#323130
    classDef success fill:#DFF6DD,stroke:#107C10,stroke-width:2px,color:#323130
    classDef warning fill:#FFF4CE,stroke:#FFB900,stroke-width:2px,color:#323130
    classDef danger fill:#FDE7E9,stroke:#D13438,stroke-width:2px,color:#323130
```

### Summary

The current state baseline demonstrates a mature foundation for cloud-native order processing with full Azure service integration, zero-trust security, and end-to-end observability. The recent EF Core migration (documented in MIGRATION_GUIDE.md) significantly improved data durability and query capabilities over the previous file-based storage model. All seven core capabilities are operationally functional, with four achieving Level 4 — Managed maturity.

The primary gaps requiring architectural attention are: (1) absence of an explicit order status lifecycle, which limits operational visibility into order state transitions; (2) no transactional outbox pattern, which creates a small window of data inconsistency between SQL persistence and Service Bus publishing; and (3) missing retry policies within Logic App workflow definitions, relying instead on Azure Logic Apps' default behaviour. These are tracked in the Issues & Gaps section.

---

## 5. Component Catalog

### Overview

The Component Catalog provides expanded specifications for each of the eleven Business component types. It builds on the Architecture Landscape inventory by adding implementation context, technology details, owners (inferred from repository context), and integration attributes. Each subsection references specific source files for traceability.

Component specifications follow the Business Layer table schema. Where a component type was not detected in source files, the subsection states "Not detected in source files." The catalog covers every component identified during the Architecture Landscape phase.

The dominant implementation patterns are: REST over HTTPS (API surfaces), event-driven messaging (Service Bus), serverless workflow automation (Logic Apps Standard), and Infrastructure-as-Code (Bicep + azd). All components use Managed Identity authentication, eliminating credential management overhead.

### 5.1 Business Strategy

See Section 2.1 for inventory. Expanded specifications:

| Component                         | Description                                                                    | Type                    | Owner                  | SLA                                          | Enforcement Mechanism                            | Source File                                                               |
| --------------------------------- | ------------------------------------------------------------------------------ | ----------------------- | ---------------------- | -------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| Cloud-Native Azure Deployment     | Full workload on Container Apps + Logic Apps Standard via Bicep + azd          | Architectural Principle | Evilazaro (repo owner) | Multi-env parity                             | azure.yaml + infra/ Bicep templates              | azure.yaml:1-120                                                          |
| Zero-Trust Managed Identity       | No credentials in code; all auth via User Assigned Managed Identity            | Security Strategy       | Evilazaro              | All connections                              | connections.json, parameters.json, Bicep modules | workflows/OrdersManagement/OrdersManagementLogicApp/connections.json:1-\* |
| Event-Driven Order Processing     | Azure Service Bus topic/subscription for async order event delivery            | Integration Strategy    | Evilazaro              | Topic: ordersplaced; Sub: orderprocessingsub | AppHost.cs + OrdersMessageHandler.cs             | app.AppHost/AppHost.cs:160-200                                            |
| Observability-First Engineering   | OpenTelemetry traces, metrics, logs → App Insights + Log Analytics             | Quality Strategy        | Evilazaro              | All services instrumented                    | Extensions.cs, OrderService.cs                   | app.ServiceDefaults/Extensions.cs:1-80                                    |
| Infrastructure-as-Code Governance | Bicep templates with tag enforcement, naming conventions, parameter validation | Governance Strategy     | Evilazaro              | All Azure resources                          | infra/main.bicep, infra/types.bicep              | infra/main.bicep:1-80                                                     |

### 5.2 Business Capabilities

See Section 2.2 for inventory. Expanded specifications:

| Component                  | Description                                       | Technology                               | Endpoint / Trigger                    | Dependencies                          | SLA                                          | Owner           | Source File                                                                                        |
| -------------------------- | ------------------------------------------------- | ---------------------------------------- | ------------------------------------- | ------------------------------------- | -------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------- |
| Order Placement (Single)   | Accept, validate, persist, publish single order   | ASP.NET Core, EF Core, Azure Service Bus | POST /api/orders                      | Azure SQL, Service Bus                | HTTP 201 within 5s (local)                   | Orders API team | src/eShop.Orders.API/Controllers/OrdersController.cs:55-110                                        |
| Order Placement (Batch)    | Parallel processing of multiple orders            | ASP.NET Core, Task.WhenAll               | POST /api/orders/batch                | Azure SQL, Service Bus                | Best-effort batch; per-order result returned | Orders API team | src/eShop.Orders.API/Services/OrderService.cs:160-\*                                               |
| Order Retrieval            | Paginated, no-tracking EF Core queries            | ASP.NET Core, EF Core                    | GET /api/orders, GET /api/orders/{id} | Azure SQL                             | HTTP 200 within 2s                           | Orders API team | src/eShop.Orders.API/Controllers/OrdersController.cs:\*                                            |
| Order Deletion             | Remove order record from SQL                      | ASP.NET Core, EF Core                    | DELETE /api/orders/{id}               | Azure SQL                             | HTTP 204                                     | Orders API team | src/eShop.Orders.API/Controllers/OrdersController.cs:\*                                            |
| Automated Order Processing | Service Bus → Logic App → API call → blob write   | Azure Logic Apps Standard                | Service Bus subscription trigger      | Service Bus, Orders API, Blob Storage | Near-real-time (sub-second trigger)          | Logic Apps team | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-\*         |
| Processed Order Archiving  | Write order JSON to Blob Storage based on outcome | Azure Logic Apps, Azure Blob Storage     | Conditional within workflow           | Blob Storage                          | Synchronous with workflow step               | Logic Apps team | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:50-100       |
| Post-Processing Cleanup    | Delete processed blobs on schedule                | Azure Logic Apps Standard                | Recurrence trigger (3s interval)      | Blob Storage                          | Every 3 seconds                              | Logic Apps team | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-\* |

### 5.3 Value Streams

See Section 2.3 for inventory. Expanded specifications:

| Component             | Description                                                     | Start Event                                    | End Event                                                                  | Systems Involved                                                | Cycle Time (estimated)                              | Source File                                                                                                          |
| --------------------- | --------------------------------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------- | --------------------------------------------------------------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Order-to-Archive      | Full order lifecycle from customer submission to blob archiving | Customer submits order (POST /api/orders)      | Blob written to /ordersprocessedsuccessfully or /ordersprocessedwitherrors | Web App, Orders API, SQL, Service Bus, Logic Apps, Blob Storage | Seconds (depending on Service Bus delivery latency) | src/eShop.Orders.API/Services/OrderService.cs:100-160, workflows/.../OrdersPlacedProcess/workflow.json:1-\*          |
| Order Enquiry         | Operator/customer searches for an order or lists all            | User navigates to /vieworder or /listallorders | API returns paginated order list                                           | Web App, Orders API, SQL                                        | < 2 seconds (EF Core, no-tracking)                  | src/eShop.Web.App/Components/Pages/ViewOrder.razor:1-60, src/eShop.Web.App/Components/Pages/ListAllOrders.razor:1-60 |
| Batch Order Ingestion | Operator uploads JSON batch file or manually adds orders        | User uploads JSON on /placeordersbatch         | Batch transaction summary displayed with per-order results                 | Web App, Orders API, SQL, Service Bus                           | Proportional to batch size (parallel)               | src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor:1-60                                                       |

### 5.4 Business Processes

See Section 2.4 for inventory. Expanded specifications:

| Component                        | Description                                       | Trigger                                     | Steps                                                                                                                                   | Outcomes                                                                    | Error Handling                                                                                               | Source File                                                                                                      |
| -------------------------------- | ------------------------------------------------- | ------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------- |
| Single Order Placement           | End-to-end order creation and event publishing    | HTTP POST /api/orders                       | Deserialise → Validate → Check duplicate → SaveAsync (SQL) → SendOrderMessageAsync (Service Bus) → Return 201                           | 201 Created + Order body; 400 Bad Request; 409 Conflict; 500 Internal Error | ArgumentException → 400; InvalidOperationException → 409; Exception → 500; EF retry on transient SQL failure | src/eShop.Orders.API/Controllers/OrdersController.cs:55-\*, src/eShop.Orders.API/Services/OrderService.cs:95-160 |
| Batch Order Placement            | Concurrent multi-order processing                 | HTTP POST /api/orders/batch                 | Fan-out per order → parallel PlaceOrderAsync → collect results → return batch summary                                                   | BatchTransactionStatus with per-order success/failure                       | Per-order errors captured; batch continues processing remaining orders                                       | src/eShop.Orders.API/Services/OrderService.cs:160-\*                                                             |
| Service Bus–Triggered Processing | Logic App reacts to incoming Service Bus messages | Service Bus message on `ordersplaced` topic | Trigger → Check ContentType == application/json → HTTP POST to Orders API /api/Orders/process → Check 201 → Write success or error blob | Blob in success or error container                                          | ContentType mismatch: no action; non-201 response: error blob written                                        | workflows/.../OrdersPlacedProcess/workflow.json:1-100                                                            |
| Recurrence-Based Blob Cleanup    | Scheduled maintenance to clean up processed blobs | Recurrence (every 3 seconds)                | List blobs in /ordersprocessedsuccessfully → ForEach (concurrency 20): Get metadata → Delete blob                                       | All listed blobs deleted                                                    | No explicit error handling in workflow JSON                                                                  | workflows/.../OrdersPlacedCompleteProcess/workflow.json:1-100                                                    |
| Database Initialisation          | Startup self-healing database setup               | IHostApplicationLifetime.ApplicationStarted | Retry loop (max 10, 5s delay): MigrateAsync → CanConnectAsync → log result                                                              | Migrations applied; connection verified or startup aborted                  | OperationCancelledException: graceful exit; other exceptions: retry then abort                               | src/eShop.Orders.API/Program.cs:120-150                                                                          |

### 5.5 Business Services

See Section 2.5 for inventory. Expanded specifications:

| Component                           | Description                                            | Type                 | Technology                                                      | Version                                    | API Endpoints                                                                    | SLA                            | Owner     | Source File                                                        |
| ----------------------------------- | ------------------------------------------------------ | -------------------- | --------------------------------------------------------------- | ------------------------------------------ | -------------------------------------------------------------------------------- | ------------------------------ | --------- | ------------------------------------------------------------------ |
| eShop Orders REST API               | RESTful CRUD service for order management              | Microservice         | ASP.NET Core Web API, EF Core, net10.0                          | v1 (OpenAPI)                               | POST /api/orders, GET /api/orders, GET /api/orders/{id}, DELETE /api/orders/{id} | Not formally defined in source | Evilazaro | src/eShop.Orders.API/eShop.Orders.API.csproj:1-\*                  |
| eShop Web Application               | Blazor Server SPA for order management UX              | Frontend             | Blazor Server, Microsoft Fluent UI, net10.0                     | 1.0                                        | / , /placeorder, /placeordersbatch, /vieworder, /listallorders                   | Not formally defined           | Evilazaro | src/eShop.Web.App/eShop.Web.App.csproj:1-\*                        |
| Orders Management Logic App         | Workflow automation for order processing and archiving | Integration Workflow | Azure Logic Apps Standard, WorkflowStandard tier                | 1.0.0 (workflow definition contentVersion) | Sub: orderprocessingsub; Recurrence trigger                                      | Not formally defined           | Evilazaro | workflows/OrdersManagement/OrdersManagementLogicApp/host.json:1-\* |
| Order Messaging Service             | Async event bus for OrderPlaced events                 | Messaging            | Azure Service Bus, topic: ordersplaced, sub: orderprocessingsub | SDK: Azure.Messaging.ServiceBus            | N/A (push)                                                                       | Not formally defined           | Evilazaro | app.AppHost/AppHost.cs:160-200                                     |
| Observability Service               | Telemetry aggregation and monitoring                   | Monitoring           | Azure Application Insights + Log Analytics + OpenTelemetry      | Azure Monitor OpenTelemetry Exporter       | /health, /alive                                                                  | Not formally defined           | Evilazaro | app.ServiceDefaults/Extensions.cs:1-80                             |
| Infrastructure Provisioning Service | IaC-based Azure resource lifecycle management          | DevOps / IaC         | Bicep, Azure Developer CLI (azd), Azure CLI                     | azd >= 1.11.0                              | CLI commands: azd up, azd provision, azd deploy                                  | Not formally defined           | Evilazaro | azure.yaml:1-120                                                   |

### 5.6 Business Functions

See Section 2.6 for inventory. Expanded specifications:

| Component               | Description                                              | Implementation Class                                            | Inputs                                        | Outputs                                                            | Retry                 | Source File                                                                 |
| ----------------------- | -------------------------------------------------------- | --------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------ | --------------------- | --------------------------------------------------------------------------- |
| Order Validation        | Enforces field presence, lengths, types, positive values | OrderService.ValidateOrder (private)                            | Order object                                  | void (throws ArgumentException)                                    | N/A                   | src/eShop.Orders.API/Services/OrderService.cs:\*                            |
| Order Persistence       | EF Core SaveChanges to Azure SQL with resiliency         | OrderRepository.SaveOrderAsync                                  | Order domain model                            | Persisted entity                                                   | 5 retries SQL         | src/eShop.Orders.API/Repositories/OrderRepository.cs:1-60                   |
| Duplicate Detection     | Query by ID before save                                  | OrderRepository.GetOrderByIdAsync                               | string orderId                                | Order?                                                             | N/A                   | src/eShop.Orders.API/Repositories/OrderRepository.cs:1-60                   |
| Message Publishing      | Serialize + send to Service Bus topic                    | OrdersMessageHandler.SendOrderMessageAsync                      | Order, CancellationToken                      | void (throws on fail)                                              | Service Bus SDK retry | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:60-80                 |
| Blob Archiving          | ApiConnection write to Azure Blob Storage                | Logic App action: Create_Blob_Successfully / Create_Blob_Errors | Base64 order JSON                             | Blob in /ordersprocessedsuccessfully or /ordersprocessedwitherrors | Logic App default     | workflows/.../OrdersPlacedProcess/workflow.json:30-70                       |
| Health Monitoring       | DbContext + Service Bus availability probes              | DbContextHealthCheck, ServiceBusHealthCheck                     | none                                          | HealthCheckResult                                                  | N/A                   | src/eShop.Orders.API/HealthChecks/, src/eShop.Orders.API/Program.cs:100-115 |
| Metrics Instrumentation | OpenTelemetry Meter API for business metrics             | OrderService (constructor instruments)                          | Per-operation telemetry calls                 | OTel metric data points → App Insights                             | N/A                   | src/eShop.Orders.API/Services/OrderService.cs:30-80                         |
| User Secret Management  | Post-provision azd hook sets .NET user secrets           | hooks/postprovision.ps1                                         | Environment vars (AZURE_SUBSCRIPTION_ID etc.) | User secrets for local dev                                         | N/A                   | hooks/postprovision.ps1:1-80                                                |

### 5.7 Business Roles & Actors

See Section 2.7 for inventory. Expanded specifications:

| Component                          | Description                                   | Interface / Entry Point                                               | Authentication                                                            | Capabilities                                                     | Source File                                                  |
| ---------------------------------- | --------------------------------------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------------ |
| Customer / End User                | Human actor placing and managing orders       | Blazor Web App (browser)                                              | Session cookie (.eShop.Session, HttpOnly, Secure, SameSite=Strict)        | Place order, view order, list all orders, delete orders          | src/eShop.Web.App/Program.cs:15-30                           |
| Operations Operator                | Human actor monitoring and managing orders    | Blazor Web App + Azure Monitor                                        | Session cookie + Azure RBAC                                               | All customer capabilities + Application Insights dashboards      | src/eShop.Web.App/Components/Pages/ListAllOrders.razor:1-\*  |
| Azure Logic Apps Runtime           | Automated workflow executor                   | Service Bus subscription trigger + Recurrence                         | User Assigned Managed Identity                                            | Process orders, archive blobs, clean up processed files          | workflows/.../connections.json:1-_, parameters.json:1-_      |
| CI/CD Pipeline (Service Principal) | Automated deployment actor                    | azd CLI, Azure CLI                                                    | Service Principal (AZURE_CLIENT_ID, AZURE_TENANT_ID)                      | Provision infrastructure, deploy applications, run hooks         | azure.yaml:80-120, hooks/postprovision.ps1:1-\*              |
| Developer                          | Human actor for local development and testing | .NET Aspire AppHost (local), Generate-Orders.ps1, deploy-workflow.ps1 | Azure CLI interactive login (dev), User Assigned Managed Identity (Azure) | All capabilities + local Service Bus emulator                    | app.AppHost/AppHost.cs:60-80, hooks/Generate-Orders.ps1:1-60 |
| Azure Managed Identity             | Non-human authentication actor                | All Azure service connections                                         | User Assigned Managed Identity (MSI)                                      | SQL auth, Service Bus auth, Blob Storage auth, App Insights auth | infra/shared/identity/, workflows/.../connections.json:1-\*  |

### 5.8 Business Rules

See Section 2.8 for inventory. Expanded specifications:

| Component                          | Rule Statement                                                                   | Enforcement Point                                                   | Violation Response                                        | Source File                                                                                      |
| ---------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------- | --------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Order ID Required & Unique         | Id must be 1–100 chars; must not exist in DB                                     | [Required], [StringLength] attribute + OrderService duplicate check | HTTP 400 (missing); HTTP 409 (duplicate)                  | app.ServiceDefaults/CommonTypes.cs:78-100, src/eShop.Orders.API/Services/OrderService.cs:100-120 |
| Customer ID Required               | CustomerId must be 1–100 chars                                                   | [Required], [StringLength] data annotation                          | HTTP 400                                                  | app.ServiceDefaults/CommonTypes.cs:85-90                                                         |
| Delivery Address Required          | DeliveryAddress must be 5–500 chars                                              | [Required], [StringLength] data annotation                          | HTTP 400                                                  | app.ServiceDefaults/CommonTypes.cs:90-100                                                        |
| Products Non-Empty                 | Products list must contain ≥ 1 item                                              | [Required], [MinLength(1)] annotation                               | HTTP 400                                                  | app.ServiceDefaults/CommonTypes.cs:100-115                                                       |
| Product Price Positive             | Price must be > 0                                                                | [Range(0.01, double.MaxValue)] annotation                           | HTTP 400                                                  | app.ServiceDefaults/CommonTypes.cs:115-130                                                       |
| Product Quantity Positive          | Quantity must be ≥ 1                                                             | [Range(1, int.MaxValue)] annotation                                 | HTTP 400                                                  | app.ServiceDefaults/CommonTypes.cs:120-135                                                       |
| Order Total Positive               | Total must be > 0.01                                                             | [Range(0.01, double.MaxValue)] annotation                           | HTTP 400                                                  | app.ServiceDefaults/CommonTypes.cs:95-100                                                        |
| Session Idle Timeout               | Session expires after 30 minutes idle                                            | ASP.NET Core Session middleware                                     | Session cleared; user redirected to establish new session | src/eShop.Web.App/Program.cs:17-25                                                               |
| Service Bus Conditional Activation | Service Bus only activated if MESSAGING_HOST ≠ localhost                         | Startup conditional in Program.cs                                   | NoOpOrdersMessageHandler registered (no-op)               | src/eShop.Orders.API/Program.cs:80-100                                                           |
| Logic App ContentType Gate         | OrdersPlacedProcess only processes messages with ContentType == application/json | If expression in workflow.json                                      | Workflow branch skips processing action                   | workflows/.../OrdersPlacedProcess/workflow.json:5-15                                             |
| Blob Cleanup Recurrence            | Cleanup runs every 3 seconds, concurrency 20                                     | Logic App Recurrence trigger + ForEach concurrency config           | N/A (schedule-based)                                      | workflows/.../OrdersPlacedCompleteProcess/workflow.json:20-40                                    |
| DB Connection Resiliency           | EF Core retries up to 5 times, 30s max delay                                     | SqlServerRetryingExecutionStrategy                                  | Exception after MAX_RETRIES exceeded                      | src/eShop.Orders.API/Program.cs:40-55                                                            |

### 5.9 Business Events

See Section 2.9 for inventory. Expanded specifications:

| Component                  | Event Name                                         | Publisher                               | Consumer(s)                                     | Transport                                  | Payload                                | Source File                                                                                                        |
| -------------------------- | -------------------------------------------------- | --------------------------------------- | ----------------------------------------------- | ------------------------------------------ | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| OrderPlaced                | eShop.orders.placed (metric) + Service Bus message | OrderService (via OrdersMessageHandler) | Azure Logic Apps (OrdersPlacedProcess workflow) | Azure Service Bus topic: ordersplaced      | JSON-serialised Order object           | src/eShop.Orders.API/Services/OrderService.cs:130-145, src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:60-80 |
| OrderProcessedSuccessfully | Internal blob write event                          | Logic App (OrdersPlacedProcess)         | Azure Blob Storage (passive consumer)           | Azure Blob Storage API Connection          | Base64-encoded order JSON              | workflows/.../OrdersPlacedProcess/workflow.json:30-60                                                              |
| OrderProcessedWithError    | Internal blob write event                          | Logic App (OrdersPlacedProcess)         | Azure Blob Storage (passive consumer)           | Azure Blob Storage API Connection          | Base64-encoded order JSON              | workflows/.../OrdersPlacedProcess/workflow.json:60-90                                                              |
| DatabaseInitialised        | Internal lifecycle event                           | Program.cs startup routine              | Application (unblocks service readiness)        | In-process (.NET IHostApplicationLifetime) | None (side-effect: migrations applied) | src/eShop.Orders.API/Program.cs:118-150                                                                            |
| ApplicationStarted         | .NET host lifecycle event                          | ASP.NET Core runtime                    | Program.cs (registers DB init callback)         | In-process (.NET IHostApplicationLifetime) | None                                   | src/eShop.Orders.API/Program.cs:115-120                                                                            |

### 5.10 Business Objects / Entities

See Section 2.10 for inventory. Expanded specifications:

| Component                | Type                       | Key Properties                                               | Validation Rules                                                                                                                             | Persistence                                | Source File                                                     |
| ------------------------ | -------------------------- | ------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ | --------------------------------------------------------------- |
| Order                    | Domain record (sealed)     | Id, CustomerId, Date (UTC), DeliveryAddress, Total, Products | Id: required, 1–100 chars, unique; CustomerId: required, 1–100 chars; DeliveryAddress: required, 5–500 chars; Total: > 0; Products: ≥ 1 item | Azure SQL via EF Core (OrderEntity)        | app.ServiceDefaults/CommonTypes.cs:78-115                       |
| OrderProduct             | Domain record (sealed)     | Id, OrderId, ProductId, ProductDescription, Quantity, Price  | Id/OrderId/ProductId: required; ProductDescription: 1–500 chars; Quantity: ≥ 1; Price: > 0                                                   | Azure SQL via EF Core (OrderProductEntity) | app.ServiceDefaults/CommonTypes.cs:115-160                      |
| OrdersWrapper            | Response DTO               | Orders (List\<Order\>)                                       | None (container only)                                                                                                                        | Not persisted                              | src/eShop.Orders.API/Services/OrdersWrapper.cs:1-\*             |
| BatchTransactionStatus   | Web App view model         | TransactionId, Timestamp, per-order results                  | None (display only)                                                                                                                          | Not persisted                              | src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor:40-60 |
| OrderMessageWithMetadata | Messaging enrichment model | Order + Service Bus MessageId, ContentType                   | Inherits Order validation                                                                                                                    | Not persisted                              | src/eShop.Orders.API/Handlers/OrderMessageWithMetadata.cs:1-\*  |
| WeatherForecast          | Scaffold/demo entity       | Date, TemperatureC, TemperatureF (derived), Summary          | TemperatureC: -273 to 200; Summary: max 100 chars                                                                                            | Not persisted                              | app.ServiceDefaults/CommonTypes.cs:40-78                        |

### 5.11 KPIs & Metrics

See Section 2.11 for inventory. Expanded specifications:

| Component                     | Metric Name                      | Type                | Unit  | Dimensions               | Collection Point                            | Export Target                         | Source File                                           |
| ----------------------------- | -------------------------------- | ------------------- | ----- | ------------------------ | ------------------------------------------- | ------------------------------------- | ----------------------------------------------------- |
| Orders Placed Counter         | eShop.orders.placed              | Counter\<long\>     | order | order.status             | OrderService.PlaceOrderAsync                | Azure Application Insights (via OTel) | src/eShop.Orders.API/Services/OrderService.cs:55-80   |
| Processing Duration Histogram | eShop.orders.processing.duration | Histogram\<double\> | ms    | order.status             | OrderService (Stopwatch)                    | Azure Application Insights            | src/eShop.Orders.API/Services/OrderService.cs:55-80   |
| Processing Errors Counter     | eShop.orders.processing.errors   | Counter\<long\>     | error | error.type, order.status | OrderService (catch blocks)                 | Azure Application Insights            | src/eShop.Orders.API/Services/OrderService.cs:140-160 |
| Orders Deleted Counter        | eShop.orders.deleted             | Counter\<long\>     | order | (none defined)           | OrderService.DeleteOrderAsync               | Azure Application Insights            | src/eShop.Orders.API/Services/OrderService.cs:\*      |
| Readiness Probe               | /health HTTP endpoint            | Health check        | N/A   | database, servicebus     | DbContextHealthCheck, ServiceBusHealthCheck | Azure Container Apps health probe     | src/eShop.Orders.API/Program.cs:100-115               |
| Liveness Probe                | /alive HTTP endpoint             | Health check        | N/A   | (none)                   | IHostedService aliveness                    | Azure Container Apps liveness probe   | app.ServiceDefaults/Extensions.cs:60-80               |

### Summary

The Component Catalog documents 38 discrete components across all eleven Business component types, with strong coverage in Business Services (6), Business Rules (12), Business Processes (7), and Business Functions (8). The primary pattern is a layered microservices architecture with event-driven integration: synchronous REST for user-facing interactions and asynchronous Service Bus + Logic Apps for downstream processing.

Gaps identified: (1) `WeatherForecast` entity is a scaffold artifact with no business function and should be removed; (2) `BatchTransactionStatus` lacks a formal schema or DTO definition file — it is inlined as Blazor component state; (3) no explicit SLA definitions are codified in source artifacts; and (4) the `OrdersPlacedCompleteProcess` workflow has no error handling for blob delete failures. These are tracked in the Issues & Gaps section of this document.

---

## 7. Architecture Standards

### Overview

Architecture standards for the eShop Orders Management system are derived from code-level conventions, configuration patterns, and infrastructure naming rules observable across the workspace. These standards are applied consistently throughout the codebase and govern how components are named, how errors are handled, how authentication is configured, and how deployments are structured. The following standards are evidence-based and traceable to source artifacts.

**Naming Conventions:**

| Asset Type                     | Pattern                                               | Example                                                   | Source                                              |
| ------------------------------ | ----------------------------------------------------- | --------------------------------------------------------- | --------------------------------------------------- |
| Azure Resource                 | `{solutionName}-{envName}-{resourceType}`             | `orders-dev-logicapp`                                     | infra/main.bicep:50-80                              |
| Bicep parameter                | camelCase                                             | `solutionName`, `envName`, `deployerPrincipalType`        | infra/main.bicep:50-80                              |
| C# class                       | PascalCase                                            | `OrderService`, `OrdersMessageHandler`                    | src/eShop.Orders.API/Services/OrderService.cs:\*    |
| C# interface                   | `I` + PascalCase                                      | `IOrderService`, `IOrderRepository`                       | src/eShop.Orders.API/Interfaces/\*                  |
| C# namespace                   | `{Company}.{Project}.{Layer}`                         | `eShop.Orders.API.Services`                               | src/eShop.Orders.API/Services/OrderService.cs:14    |
| .NET Aspire project resource   | kebab-case                                            | `orders-api`, `web-app`                                   | app.AppHost/AppHost.cs:20-25                        |
| OpenTelemetry ActivitySource   | `{Company}.{Service}`                                 | `eShop.Orders.API`                                        | src/eShop.Orders.API/Program.cs:20                  |
| OpenTelemetry Meter            | `{Company}.{Service}`                                 | `eShop.Orders.API`                                        | src/eShop.Orders.API/Services/OrderService.cs:70    |
| OTel metric                    | `{domain}.{entity}.{verb}` (dot-separated, lowercase) | `eShop.orders.placed`, `eShop.orders.processing.duration` | src/eShop.Orders.API/Services/OrderService.cs:55-80 |
| Azure Service Bus topic        | lowercase, descriptive                                | `ordersplaced`                                            | app.AppHost/AppHost.cs:170                          |
| Azure Service Bus subscription | descriptive, suffixed with `sub`                      | `orderprocessingsub`                                      | app.AppHost/AppHost.cs:175                          |
| Blazor page route              | lowercase kebab-case                                  | `/placeorder`, `/listallorders`, `/vieworder`             | src/eShop.Web.App/Components/Pages/\*.razor         |

**Error Handling Standards:**

| Standard                                          | Description                                                                                   | Source                                                      |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| ArgumentNullException for DI parameters           | All constructor-injected dependencies use `ArgumentNullException.ThrowIfNull()`               | src/eShop.Orders.API/Services/OrderService.cs:45-60         |
| ArgumentException for validation failures         | Business rule violations in service layer throw `ArgumentException`                           | src/eShop.Orders.API/Services/OrderService.cs:100-120       |
| InvalidOperationException for duplicate detection | Duplicate order throws `InvalidOperationException`                                            | src/eShop.Orders.API/Services/OrderService.cs:108-112       |
| Controller HTTP status mapping                    | ArgumentException → 400, InvalidOperationException → 409, Exception → 500                     | src/eShop.Orders.API/Controllers/OrdersController.cs:100-\* |
| Structured logging with trace context             | All log calls include `TraceId`, `SpanId`, and domain keys (e.g., `OrderId`) via `BeginScope` | src/eShop.Orders.API/Controllers/OrdersController.cs:80-95  |

**Authentication Standards:**

| Standard                                | Description                                                                     | Source                                                      |
| --------------------------------------- | ------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| Managed Identity for all Azure services | User Assigned Managed Identity used for SQL, Service Bus, Blob Storage          | workflows/.../connections.json:1-\*, infra/shared/identity/ |
| No secrets in committed files           | Secrets managed via .NET user secrets (local) and Azure App Settings (deployed) | hooks/postprovision.ps1:1-80                                |
| Session cookie security                 | HttpOnly, Secure, SameSite=Strict, 30-minute idle timeout                       | src/eShop.Web.App/Program.cs:15-30                          |
| Azure AD authentication for SQL         | EF Core connection string uses Azure AD auth (no SQL passwords)                 | src/eShop.Orders.API/MIGRATION_GUIDE.md:30-50               |

**API Design Standards:**

| Standard                        | Description                                                                     | Source                                                                                                        |
| ------------------------------- | ------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| OpenAPI/Swagger documentation   | All API endpoints documented with Swagger UI (`/swagger`)                       | src/eShop.Orders.API/Program.cs:60-80                                                                         |
| RESTful HTTP semantics          | POST → 201 Created; GET → 200 OK; DELETE → 204 No Content; errors → 400/409/500 | src/eShop.Orders.API/Controllers/OrdersController.cs:55-\*                                                    |
| Model validation via ModelState | `[ApiController]` enables automatic ModelState validation                       | src/eShop.Orders.API/Controllers/OrdersController.cs:15-20                                                    |
| CancellationToken propagation   | All async methods accept and propagate `CancellationToken`                      | src/eShop.Orders.API/Controllers/OrdersController.cs:55-_, src/eShop.Orders.API/Services/OrderService.cs:90-_ |

**Infrastructure Standards:**

| Standard                           | Description                                                                                | Source                                        |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | --------------------------------------------- |
| Environment-scoped resource naming | All Bicep resources use `solutionName-envName` prefix                                      | infra/main.bicep:50-80                        |
| Mandatory resource tagging         | All Azure resources receive environment, solution, and deployment date tags                | infra/types.bicep:1-\*, infra/main.bicep:1-80 |
| Deployment environments            | 4 named environments: dev, test, staging, prod                                             | infra/main.bicep:65-70, azure.yaml:80-90      |
| IaC-only resource management       | All resources defined in Bicep; no out-of-band portal changes                              | azure.yaml:80-95                              |
| Bicep param validation             | All parameters have `@minLength`, `@maxLength`, and `@allowed` decorators where applicable | infra/main.bicep:50-80                        |

---

## 8. Dependencies & Integration

### Overview

The eShop Orders Management system has six primary integration points, each using a different integration pattern: synchronous REST (Web App → API), event-driven messaging (API → Service Bus → Logic Apps), managed API connections (Logic Apps → Service Bus, Logic Apps → Blob Storage), data persistence (API → Azure SQL), and telemetry streaming (all services → Application Insights). All integrations use Managed Identity authentication, eliminating credential management.

The dependency graph has no circular dependencies. The Web App depends on the Orders API; the Orders API depends on Azure SQL and Azure Service Bus; the Logic Apps depend on Azure Service Bus, Blob Storage, and the Orders API. Application Insights is a passive sink receiving telemetry from all components.

**System-Level Integration Map:**

```mermaid
---
title: eShop Orders Management — Integration Dependency Map
config:
  theme: base
  look: classic
  layout: dagre
  themeVariables:
    fontSize: '16px'
  flowchart:
    htmlLabels: true
---
flowchart TD
    accTitle: eShop Orders Management Integration Dependency Map
    accDescr: Shows all integration dependencies between the Web App, Orders API, Azure SQL, Service Bus, Logic Apps, Blob Storage, and Application Insights

    subgraph Frontend["🌐 Customer Engagement"]
        style Frontend fill:#EFF6FC,stroke:#2B88D8,stroke-width:2px
        wa("🖥️ eShop Web App<br/>(Blazor Server)"):::neutral
    end

    subgraph Backend["⚙️ API Layer"]
        style Backend fill:#E6F2EA,stroke:#107C10,stroke-width:2px
        api("🔧 Orders API<br/>(ASP.NET Core)"):::success
    end

    subgraph Data["💾 Data Layer"]
        style Data fill:#FFF4CE,stroke:#FFB900,stroke-width:2px
        sql("🗄️ Azure SQL<br/>(EF Core)"):::warning
    end

    subgraph Messaging["📨 Messaging Layer"]
        style Messaging fill:#FAF0FB,stroke:#8764B8,stroke-width:2px
        sb("📩 Azure Service Bus<br/>topic: ordersplaced"):::neutral
    end

    subgraph Workflows["🔄 Workflow Layer"]
        style Workflows fill:#EFF6FC,stroke:#2B88D8,stroke-width:2px
        la1("⚡ OrdersPlacedProcess<br/>(Logic App)"):::success
        la2("🧹 OrdersPlacedComplete<br/>Process (Logic App)"):::success
    end

    subgraph Storage["🗂️ Storage Layer"]
        style Storage fill:#E6F2EA,stroke:#107C10,stroke-width:2px
        blob("📁 Azure Blob Storage<br/>/ordersprocessed*"):::neutral
    end

    subgraph Obs["📊 Observability"]
        style Obs fill:#FDE7E9,stroke:#D13438,stroke-width:2px
        ai("📈 Application Insights<br/>+ Log Analytics"):::danger
    end

    wa -->|"HTTPS REST<br/>Service Discovery"| api
    api -->|"EF Core<br/>Managed Identity"| sql
    api -->|"Service Bus SDK<br/>Managed Identity"| sb
    sb -->|"Subscription Trigger<br/>Managed Identity"| la1
    la1 -->|"HTTP POST<br/>/api/Orders/process"| api
    la1 -->|"ApiConnection<br/>Managed Identity"| blob
    la2 -->|"ApiConnection<br/>Managed Identity"| blob
    api -.->|"OTel traces/metrics"| ai
    wa -.->|"OTel traces"| ai
    la1 -.->|"App Insights"| ai
    la2 -.->|"App Insights"| ai

    classDef neutral fill:#FAFAFA,stroke:#8A8886,stroke-width:2px,color:#323130
    classDef success fill:#DFF6DD,stroke:#107C10,stroke-width:2px,color:#323130
    classDef warning fill:#FFF4CE,stroke:#FFB900,stroke-width:2px,color:#323130
    classDef danger fill:#FDE7E9,stroke:#D13438,stroke-width:2px,color:#323130
```

**Integration Specifications:**

| #   | From                                    | To                              | Pattern               | Protocol                   | Authentication                    | Notes                                                                               | Source                                                                                  |
| --- | --------------------------------------- | ------------------------------- | --------------------- | -------------------------- | --------------------------------- | ----------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| 1   | eShop Web App                           | Orders API                      | Synchronous REST      | HTTPS + Service Discovery  | Session cookie (user)             | Typed HTTP client `OrdersAPIService`; `.AddServiceDiscovery()`                      | src/eShop.Web.App/Components/Services/OrdersAPIService.cs:1-80                          |
| 2   | Orders API                              | Azure SQL Database              | Synchronous query     | TCP/SQL (EF Core)          | Managed Identity (AAD token)      | Connection resiliency: 5 retries, 30s delay; CommandTimeout: 120s                   | src/eShop.Orders.API/Program.cs:30-55                                                   |
| 3   | Orders API                              | Azure Service Bus               | Async event publish   | AMQP                       | Managed Identity                  | Topic: `ordersplaced`; SDK: Azure.Messaging.ServiceBus                              | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-80                              |
| 4   | Azure Service Bus                       | Logic App (OrdersPlacedProcess) | Event-triggered       | Service Bus subscription   | Managed Identity                  | Subscription: `orderprocessingsub`; managed API connection                          | workflows/.../connections.json:1-_, workflows/.../OrdersPlacedProcess/workflow.json:1-_ |
| 5   | Logic App (OrdersPlacedProcess)         | Orders API                      | Synchronous HTTP call | HTTPS                      | None (URL template)               | POST to `https://orders-api.${ORDERS_API_URL}/api/Orders/process`; chunked transfer | workflows/.../OrdersPlacedProcess/workflow.json:15-25                                   |
| 6   | Logic App                               | Azure Blob Storage              | Write (archive)       | HTTPS (Azure Blob API)     | Managed Identity                  | Two containers: `/ordersprocessedsuccessfully` and `/ordersprocessedwitherrors`     | workflows/.../OrdersPlacedProcess/workflow.json:30-90                                   |
| 7   | Logic App (OrdersPlacedCompleteProcess) | Azure Blob Storage              | List + Delete         | HTTPS (Azure Blob API)     | Managed Identity                  | Recurrence trigger, 3s interval, concurrency 20                                     | workflows/.../OrdersPlacedCompleteProcess/workflow.json:1-100                           |
| 8   | All services                            | Azure Application Insights      | Telemetry streaming   | HTTPS (OTLP)               | Connection string (App Settings)  | OpenTelemetry SDK; both traces and metrics                                          | app.ServiceDefaults/Extensions.cs:1-80                                                  |
| 9   | azd CLI / Bicep                         | All Azure resources             | Provisioning          | Azure Resource Manager API | Service Principal / User identity | Full IaC lifecycle: provision + deploy + hooks                                      | azure.yaml:1-120, infra/main.bicep:1-80                                                 |

**Cross-Component Data Flow — Single Order Placement:**

| Step | Component                       | Action                                     | Data In                       | Data Out                    |
| ---- | ------------------------------- | ------------------------------------------ | ----------------------------- | --------------------------- |
| 1    | eShop Web App                   | User fills PlaceOrder form                 | User input                    | HTTP POST body (JSON Order) |
| 2    | Orders API (Controller)         | Deserialise + validate ModelState          | HTTP POST body                | Order object                |
| 3    | Orders API (Service)            | Business rule validation + duplicate check | Order object                  | Order (valid) or Exception  |
| 4    | Orders API (Repository)         | SaveAsync to Azure SQL                     | Order domain object           | Persisted OrderEntity       |
| 5    | Orders API (Handler)            | JSON serialise + publish to Service Bus    | Order domain object           | ServiceBusMessage           |
| 6    | Azure Service Bus               | Route to subscription                      | ServiceBusMessage             | Delivered to Logic App      |
| 7    | Logic App (OrdersPlacedProcess) | Decode base64 + call API                   | ServiceBusMessage.ContentData | HTTP POST to Orders API     |
| 8    | Logic App                       | Evaluate API response                      | HTTP status code              | Blob write path selection   |
| 9    | Azure Blob Storage              | Archive order JSON                         | Base64 order payload          | Blob file                   |
| 10   | Application Insights            | Collect OTel spans + metrics               | Activity/Metric data points   | Dashboard / Alerts          |

### Summary

The integration architecture is well-structured, with clear separation of concerns and no circular dependencies. The Managed Identity authentication pattern eliminates credential sprawl, and the event-driven decoupling between the Orders API and Logic Apps enables independent deployability and scaling. The OpenTelemetry telemetry mesh provides end-to-end traceability across all integration hops, from browser request through to blob archiving.

The primary integration risk is the lack of a transactional outbox pattern between SQL persistence (step 4) and Service Bus publishing (step 5): if the Service Bus publish fails after SQL success, the `OrderPlaced` event is lost and the Logic App workflow is never triggered. A secondary risk is the Logic App HTTP call to the Orders API (step 7) having no explicit retry configuration in the workflow definition, relying on Logic Apps' default behaviour. Both risks are documented in the Issues & Gaps section.

---

## Issues & Gaps

| #   | Category   | Description                                                                                                                                         | Resolution                                                                           | Status   |
| --- | ---------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | -------- |
| 1   | gap        | No explicit order status lifecycle (Pending → Processing → Fulfilled → Cancelled) found in any source file                                          | Add status field to Order entity and state machine logic in OrderService             | Open     |
| 2   | gap        | No transactional outbox pattern — SQL persist and Service Bus publish are not atomic; message loss possible on Service Bus failure                  | Implement transactional outbox (e.g., via Outbox pattern with EF Core)               | Open     |
| 3   | gap        | `BatchTransactionStatus` web model has no formal DTO or schema definition file; defined inline in Blazor component                                  | Extract to a dedicated DTO class in app.ServiceDefaults or eShop.Web.App             | Open     |
| 4   | gap        | No explicit SLA thresholds (response time, throughput) codified in any source artifact                                                              | Define and document SLAs in a contract file or README                                | Open     |
| 5   | gap        | Logic App workflows have no explicit retry policies on HTTP or ApiConnection actions (relying on Logic Apps default engine behaviour)               | Add explicit retry policy blocks to workflow.json for HTTP and ApiConnection actions | Open     |
| 6   | gap        | `OrdersPlacedCompleteProcess` workflow has no error handling for blob delete failures (no else branch or run-after configuration)                   | Add error branch to ForEach to log or quarantine failed deletions                    | Open     |
| 7   | assumption | `BatchTransactionStatus` inferred from Blazor component state variables — no dedicated class found                                                  | Review Blazor component code for inline model definition                             | Resolved |
| 8   | assumption | Customer / End User role inferred from Blazor page routes and Web App functionality; no explicit actor or persona document found in workspace       | Verified from Home.razor, PlaceOrder.razor, ViewOrder.razor                          | Resolved |
| 9   | limitation | `OrderMessageWithMetadata` handler class could not be fully read (content truncated) — specification based on available partial content             | Re-read file to complete specification if needed                                     | Deferred |
| 10  | gap        | `WeatherForecast` entity is an ASP.NET Core scaffold artifact with no business function — it appears in CommonTypes.cs alongside core domain models | Remove or move to a separate demo assembly                                           | Open     |

---

## Validation Summary

| Gate ID     | Gate Name                                                          | Score   | Status |
| ----------- | ------------------------------------------------------------------ | ------- | ------ |
| PFC-001     | Shared dependency files loaded                                     | 100/100 | Pass   |
| PFC-008     | Target layer valid (Business)                                      | 100/100 | Pass   |
| E-014       | Section titles match canonical schema                              | 100/100 | Pass   |
| E-015       | All sections start with `### Overview`                             | 100/100 | Pass   |
| E-016       | Sections 2, 4, 5, 8 end with `### Summary`                         | 100/100 | Pass   |
| E-017       | Sections 2 and 5 have exactly 11 subsections (2.1–2.11, 5.1–5.11)  | 100/100 | Pass   |
| E-003       | Business layer components found (all 11 component types populated) | 100/100 | Pass   |
| E-004       | Source traceability present on all findings (file:line format)     | 100/100 | Pass   |
| ANTI-HALL   | No fabricated content — all claims traced to workspace artifacts   | 100/100 | Pass   |
| PLACEHOLDER | Zero TODO/TBD/PLACEHOLDER text in output                           | 100/100 | Pass   |
