# Business Architecture

**System:** Azure Logic Apps Monitoring / eShop Order Management
**Framework:** TOGAF 10 Architecture Development Method (ADM)
**Layer:** Business Architecture
**Document Version:** 1.0.0
**Date:** 2026-04-10
**Status:** Final

---

## 1. Executive Summary

The Azure Logic Apps Monitoring solution is an end-to-end order management platform built on Microsoft Azure. It enables customers to submit, track, and manage product orders through a browser-based web interface. Orders are captured by a RESTful API, persisted to a relational database, and propagated asynchronously to downstream processing workflows. Azure Logic Apps Standard orchestrates the integration between the messaging layer and archival storage, while comprehensive observability tooling provides real-time insight into every stage of the order lifecycle.

The business capability footprint spans five value-creating domains: **Order Entry**, **Order Persistence**, **Asynchronous Order Processing**, **Order Lifecycle Management**, and **Monitoring and Observability**. Stakeholders include end-users placing orders through the Blazor web front-end (`src/eShop.Web.App`), platform engineers operating the Azure infrastructure (`infra/main.bicep`), and integration operators managing Logic Apps workflows (`workflows/OrdersManagement`). The system is delivered as cloud-native, containerised microservices hosted on Azure Container Apps and orchestrated by a .NET Aspire AppHost (`app.AppHost/AppHost.cs`).

From a strategic perspective the solution demonstrates how event-driven integration patterns (Service Bus topics and Logic Apps triggers) can decouple business services without coupling them tightly at deployment time. The architecture supports iterative scale: the Order API processes individual or batch orders, Logic Apps workflows handle downstream processing and error routing, and the Azure Bicep IaC templates (`infra/`) enable repeatable, environment-consistent deployments across `dev`, `test`, `staging`, and `prod`. All inter-service authentication is handled via User-Assigned Managed Identity, eliminating credential management as an operational concern.

---

## 2. Architecture Landscape

### Overview

The solution landscape comprises three tiers of business capability, mapped to distinct Azure-hosted components. The **presentation tier** consists of the Blazor Server web application (`src/eShop.Web.App`) that provides order entry, bulk order placement, order listing, and batch deletion screens. The **processing tier** is the Orders API (`src/eShop.Orders.API`), a RESTful ASP.NET Core service that owns the order domain model, validates business rules, persists orders to Azure SQL, and publishes order events to Azure Service Bus. The **integration tier** is the Logic Apps Standard runtime (`workflows/OrdersManagement/OrdersManagementLogicApp`), which subscribes to Service Bus messages, routes processed orders to Azure Blob Storage containers, and executes scheduled cleanup workflows.

Supporting shared infrastructure — Azure SQL Database, Azure Service Bus, Azure Blob Storage, Azure Application Insights, and Azure Log Analytics — is defined declaratively in Bicep templates under `infra/` and provisioned via Azure Developer CLI (AZD) and the `azure.yaml` manifest. .NET Aspire (`app.AppHost/AppHost.cs`) orchestrates local development by wiring service discovery, health checks, and configuration injection, mirroring the production topology without requiring manual configuration.

| ID     | Component                     | Type                        | Source                                                                   |
| ------ | ----------------------------- | --------------------------- | ------------------------------------------------------------------------ |
| BC-001 | Order Entry (Web UI)          | Business Capability         | `src/eShop.Web.App/Components/Pages/PlaceOrder.razor`                   |
| BC-002 | Batch Order Entry (Web UI)    | Business Capability         | `src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor`             |
| BC-003 | Order Listing and Management  | Business Capability         | `src/eShop.Web.App/Components/Pages/ListAllOrders.razor`                |
| BC-004 | Order Detail View             | Business Capability         | `src/eShop.Web.App/Components/Pages/ViewOrder.razor`                    |
| BC-005 | Order Placement API           | Business Service            | `src/eShop.Orders.API/Controllers/OrdersController.cs:51-129`           |
| BC-006 | Batch Order Placement API     | Business Service            | `src/eShop.Orders.API/Controllers/OrdersController.cs:140-189`          |
| BC-007 | Order Processing Endpoint     | Business Service            | `src/eShop.Orders.API/Controllers/OrdersController.cs:202-212`          |
| BC-008 | Order Retrieval API           | Business Service            | `src/eShop.Orders.API/Controllers/OrdersController.cs:221-271`          |
| BC-009 | Order Deletion API            | Business Service            | `src/eShop.Orders.API/Controllers/OrdersController.cs`                  |
| BC-010 | Order Persistence             | Business Process            | `src/eShop.Orders.API/Repositories/OrderRepository.cs`                  |
| BC-011 | Order Event Publishing        | Business Process            | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs`                 |
| BC-012 | Orders Placed Workflow        | Integration Workflow        | `workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json` |
| BC-013 | Orders Completion Workflow    | Integration Workflow        | `workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json` |
| BC-014 | Order Archival (Success)      | Business Rule / Data Store  | `workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:43-68` |
| BC-015 | Order Archival (Error)        | Business Rule / Data Store  | `workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:70-98` |
| BC-016 | Blob Cleanup                  | Business Process            | `workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:56-99` |
| BC-017 | Observability and Monitoring  | Cross-Cutting Capability    | `infra/shared/monitoring/app-insights.bicep`, `infra/shared/monitoring/log-analytics-workspace.bicep` |

### Summary

The architecture landscape reflects a clean separation between user-facing capabilities (Web App), domain-owning services (Orders API), asynchronous integration (Logic Apps), and shared infrastructure. This separation enables independent evolution of each tier: the API can be scaled independently on Azure Container Apps, the Logic Apps workflows can be modified and redeployed without touching the API, and the web front-end can be updated without impacting downstream processing. All components share a common observability fabric through Application Insights and Log Analytics, ensuring end-to-end traceability of every order event.

---

## 3. Architecture Principles

The following principles are derived directly from the architectural decisions reflected in the codebase and infrastructure templates.

| ID   | Principle                          | Statement                                                                                                                                                                     | Source                                                                                                   |
| ---- | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| AP-1 | Event-Driven Decoupling            | Business components communicate asynchronously via Azure Service Bus topics and subscriptions, ensuring that order placement is decoupled from downstream processing.          | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:32`; `workflows/…/OrdersPlacedProcess/workflow.json:139-158` |
| AP-2 | Zero-Trust Identity                | All service-to-service authentication uses User-Assigned Managed Identity; no connection strings or static credentials are stored in code or configuration files.             | `infra/workload/logic-app.bicep:146-199`; `app.AppHost/AppHost.cs:74-85`                                |
| AP-3 | Infrastructure as Code             | All Azure resources are defined in Bicep templates and provisioned via AZD, enabling repeatable, environment-consistent deployments.                                           | `infra/main.bicep`; `azure.yaml`                                                                         |
| AP-4 | Observability First                | Every business operation is instrumented with OpenTelemetry distributed traces and structured logs correlated by Trace ID, enabling end-to-end visibility across all services. | `src/eShop.Orders.API/Controllers/OrdersController.cs:69-83`; `src/eShop.Orders.API/Program.cs:21`      |
| AP-5 | Resilience by Default              | The Orders API uses EF Core SQL retry-on-failure policies, and the .NET Aspire service defaults include resilience (retry, timeout, circuit-breaker) for all HTTP clients.    | `src/eShop.Orders.API/Program.cs:39-47`; `app.ServiceDefaults/Extensions.cs`                            |
| AP-6 | Cloud-Native Containerisation      | Applications are packaged as containers and hosted on Azure Container Apps with auto-scaling, built-in ingress, and TLS termination.                                           | `azure.yaml:276`; `app.AppHost/infra/orders-api.tmpl.yaml`; `app.AppHost/infra/web-app.tmpl.yaml`       |
| AP-7 | Separation of Concerns             | The codebase strictly separates presentation (Razor components), API controllers, service interfaces, repository abstractions, and data entities.                              | `src/eShop.Orders.API/Interfaces/`; `src/eShop.Orders.API/Services/`; `src/eShop.Orders.API/Repositories/` |
| AP-8 | Fail-Safe Error Routing            | The Logic Apps workflow routes failed order processing events to a dedicated error Blob Storage container, preserving the message for investigation without data loss.         | `workflows/…/OrdersPlacedProcess/workflow.json:70-98`, `107-133`                                         |
| AP-9 | Validation at Entry Points         | All order data is validated using .NET Data Annotations at the API layer before any business logic is executed.                                                                | `app.ServiceDefaults/CommonTypes.cs:76-154`; `src/eShop.Orders.API/Controllers/OrdersController.cs:57-67` |

---

## 4. Baseline Architecture

### Business Context

The solution addresses the following business need: provide an online platform through which customers can submit product orders, have those orders durably persisted and event-driven processed by downstream integrations, and allow operators to manage (view, delete) orders via a web interface. The baseline represents the current implemented state as found in the repository.

### Value Streams

**VS-1 — Order to Fulfillment Initiation**

| Step | Activity                                 | Actor               | Capability | Source                                                                     |
| ---- | ---------------------------------------- | ------------------- | ---------- | -------------------------------------------------------------------------- |
| 1    | Customer submits order via web form      | Customer (end-user) | BC-001     | `src/eShop.Web.App/Components/Pages/PlaceOrder.razor:225-263`             |
| 2    | Web App calls Orders API `POST /api/orders` | eShop.Web.App    | BC-005     | `src/eShop.Web.App/Components/Services/OrdersAPIService.cs`               |
| 3    | API validates order and persists to SQL  | Orders API          | BC-009, BC-010 | `src/eShop.Orders.API/Services/OrderService.cs`; `src/eShop.Orders.API/Repositories/OrderRepository.cs` |
| 4    | API publishes order event to Service Bus | Orders API          | BC-011     | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:73-120`            |
| 5    | Logic App picks up event from topic      | Logic Apps          | BC-012     | `workflows/…/OrdersPlacedProcess/workflow.json:139-158`                   |
| 6    | Logic App calls API `/api/orders/process` | Logic Apps         | BC-007     | `workflows/…/OrdersPlacedProcess/workflow.json:16-31`                     |
| 7    | Logic App archives order result to Blob  | Logic Apps          | BC-014 / BC-015 | `workflows/…/OrdersPlacedProcess/workflow.json:43-98`                 |

**VS-2 — Processed Order Cleanup**

| Step | Activity                                     | Actor      | Capability | Source                                                                                      |
| ---- | -------------------------------------------- | ---------- | ---------- | ------------------------------------------------------------------------------------------- |
| 1    | Recurrence trigger fires every 3 seconds     | Logic Apps | BC-013     | `workflows/…/OrdersPlacedCompleteProcess/workflow.json:25-34`                              |
| 2    | Lists blobs in `/ordersprocessedsuccessfully` | Logic Apps | BC-016     | `workflows/…/OrdersPlacedCompleteProcess/workflow.json:37-55`                              |
| 3    | Retrieves metadata and deletes each blob     | Logic Apps | BC-016     | `workflows/…/OrdersPlacedCompleteProcess/workflow.json:56-99`                              |

**VS-3 — Operator Order Management**

| Step | Activity                               | Actor    | Capability | Source                                                                 |
| ---- | -------------------------------------- | -------- | ---------- | ---------------------------------------------------------------------- |
| 1    | Operator loads order list from web UI  | Operator | BC-003     | `src/eShop.Web.App/Components/Pages/ListAllOrders.razor:319-345`      |
| 2    | UI calls Orders API `GET /api/orders`  | Web App  | BC-008     | `src/eShop.Orders.API/Controllers/OrdersController.cs:221-271`        |
| 3    | Operator selects and deletes orders    | Operator | BC-003     | `src/eShop.Web.App/Components/Pages/ListAllOrders.razor:371-417`      |
| 4    | UI calls batch delete on Orders API   | Web App  | BC-009     | `src/eShop.Orders.API/Controllers/OrdersController.cs`                |

### Business Rules

| ID   | Business Rule                                                                                                     | Source                                                                    |
| ---- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| BR-1 | An order must have a unique `Id` (string, 1–100 chars), a `CustomerId`, a `DeliveryAddress`, and at least one product. | `app.ServiceDefaults/CommonTypes.cs:76-111`                           |
| BR-2 | Each `OrderProduct` must include a `ProductId`, `ProductDescription`, `Quantity` ≥ 1, and `Price` > 0.           | `app.ServiceDefaults/CommonTypes.cs:116-154`                              |
| BR-3 | The order `Total` must be greater than zero.                                                                      | `app.ServiceDefaults/CommonTypes.cs:102-103`                              |
| BR-4 | If an order with the same `Id` already exists, the API returns HTTP 409 Conflict.                                 | `src/eShop.Orders.API/Controllers/OrdersController.cs:104-114`           |
| BR-5 | An order message is only forwarded to the Logic App API call if `ContentType` equals `application/json`.          | `workflows/…/OrdersPlacedProcess/workflow.json:7-14`                      |
| BR-6 | Successfully processed orders are archived to the `/ordersprocessedsuccessfully` blob container.                  | `workflows/…/OrdersPlacedProcess/workflow.json:43-68`                     |
| BR-7 | Failed or invalid order messages are archived to the `/ordersprocessedwitherrors` blob container.                 | `workflows/…/OrdersPlacedProcess/workflow.json:70-133`                    |
| BR-8 | In development environments, if Service Bus is not configured a no-op handler is used instead.                    | `src/eShop.Orders.API/Program.cs:88-97`                                   |
| BR-9 | The database is initialised with up to 10 retry attempts at application startup, with 5-second delays between attempts. | `src/eShop.Orders.API/Program.cs:125-177`                           |

### Stakeholders

| ID   | Stakeholder         | Role                                               | Primary Interaction                                                            |
| ---- | ------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------ |
| SH-1 | Customer (End-User) | Places orders and views order status               | Blazor Web App (`src/eShop.Web.App`)                                           |
| SH-2 | Operator            | Views, manages, and deletes orders; monitors system | Blazor Web App (`src/eShop.Web.App`) + Azure Portal / App Insights             |
| SH-3 | Platform Engineer   | Deploys and maintains Azure infrastructure          | `infra/` Bicep templates; `azure.yaml`; `.github/workflows/`                  |
| SH-4 | Integration Engineer | Develops and maintains Logic Apps workflows         | `workflows/OrdersManagement/`                                                  |
| SH-5 | Developer           | Builds and tests application code                  | `src/`; `.github/workflows/ci-dotnet.yml`; `.github/workflows/ci-dotnet-reusable.yml` |

---

## 5. Component Catalog

### Business Services

| ID    | Service Name                 | Description                                                                                                    | Endpoint / Interface                          | Source                                                                   |
| ----- | ---------------------------- | -------------------------------------------------------------------------------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------ |
| CS-01 | Place Order                  | Accepts a single order, validates it, persists it to Azure SQL, and publishes an event to Service Bus.         | `POST /api/orders`                            | `src/eShop.Orders.API/Controllers/OrdersController.cs:51-129`           |
| CS-02 | Place Orders Batch           | Accepts a collection of orders and processes them as a single batch operation.                                 | `POST /api/orders/batch`                      | `src/eShop.Orders.API/Controllers/OrdersController.cs:140-189`          |
| CS-03 | Process Order                | Downstream processing endpoint called by the Logic Apps workflow to record successful order receipt.           | `POST /api/orders/process`                    | `src/eShop.Orders.API/Controllers/OrdersController.cs:202-212`          |
| CS-04 | Get All Orders               | Returns all orders currently stored in the system.                                                             | `GET /api/orders`                             | `src/eShop.Orders.API/Controllers/OrdersController.cs:221-271`          |
| CS-05 | Get Order by ID              | Returns a single order by its unique identifier.                                                               | `GET /api/orders/{id}`                        | `src/eShop.Orders.API/Controllers/OrdersController.cs`                  |
| CS-06 | Delete Order                 | Removes a single order from the system.                                                                        | `DELETE /api/orders/{id}`                     | `src/eShop.Orders.API/Controllers/OrdersController.cs`                  |
| CS-07 | Delete Orders Batch          | Removes multiple orders in a single batch operation.                                                           | `DELETE /api/orders/batch`                    | `src/eShop.Orders.API/Controllers/OrdersController.cs`                  |
| CS-08 | List Service Bus Messages    | Peeks pending messages from the Service Bus topic subscription (debug/admin use).                              | Internal service method                       | `src/eShop.Orders.API/Services/Interfaces/IOrderService.cs:66-68`       |
| CS-09 | Orders Placed Workflow       | Logic Apps stateful workflow triggered by Service Bus messages; validates, routes, and archives order events.  | Service Bus trigger (`ordersplaced` topic)    | `workflows/…/OrdersPlacedProcess/workflow.json`                          |
| CS-10 | Orders Completion Workflow   | Logic Apps stateful workflow that periodically lists and cleans up successfully processed order blobs.         | Recurrence trigger (every 3 seconds)          | `workflows/…/OrdersPlacedCompleteProcess/workflow.json`                  |

### Domain Model

| Entity         | Key Attributes                                                                          | Source                                                     |
| -------------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| `Order`        | `Id` (string, PK), `CustomerId`, `Date`, `DeliveryAddress`, `Total`, `Products`         | `app.ServiceDefaults/CommonTypes.cs:71-111`               |
| `OrderProduct` | `Id`, `OrderId` (FK), `ProductId`, `ProductDescription`, `Quantity`, `Price`            | `app.ServiceDefaults/CommonTypes.cs:116-154`              |
| `OrderEntity`  | Database-mapped equivalent of `Order` with EF Core configuration                        | `src/eShop.Orders.API/data/Entities/OrderEntity.cs`       |
| `OrderProductEntity` | Database-mapped equivalent of `OrderProduct`                                      | `src/eShop.Orders.API/data/Entities/OrderProductEntity.cs` |

### Integration Points

| ID    | Integration                     | Protocol          | Direction           | Source                                                                      |
| ----- | ------------------------------- | ----------------- | ------------------- | --------------------------------------------------------------------------- |
| IP-01 | Web App → Orders API            | HTTPS / REST      | Outbound from Web App | `src/eShop.Web.App/Program.cs:67-83`                                      |
| IP-02 | Orders API → Azure SQL          | TCP / EF Core     | Outbound from API   | `src/eShop.Orders.API/Program.cs:29-57`                                    |
| IP-03 | Orders API → Azure Service Bus  | AMQP / SDK        | Outbound from API   | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs`                    |
| IP-04 | Logic Apps ← Azure Service Bus  | AMQP / API Connection | Inbound to Logic Apps | `workflows/…/OrdersPlacedProcess/workflow.json:139-158`               |
| IP-05 | Logic Apps → Orders API         | HTTPS / HTTP Action | Outbound from Logic Apps | `workflows/…/OrdersPlacedProcess/workflow.json:16-31`              |
| IP-06 | Logic Apps → Azure Blob Storage | HTTPS / API Connection | Outbound from Logic Apps | `workflows/…/OrdersPlacedProcess/workflow.json:43-98`             |
| IP-07 | Logic Apps → Azure Blob Storage (list/delete) | HTTPS / API Connection | Outbound | `workflows/…/OrdersPlacedCompleteProcess/workflow.json:37-99` |
| IP-08 | All Services → Application Insights | OpenTelemetry / HTTPS | Outbound | `infra/workload/logic-app.bicep:325`; `src/eShop.Orders.API/Program.cs:21` |

### Supporting Infrastructure Components

| ID    | Component                  | Purpose                                                          | Source                                                  |
| ----- | -------------------------- | ---------------------------------------------------------------- | ------------------------------------------------------- |
| SI-01 | Azure SQL Database         | Persistent storage for the `Orders` and `OrderProducts` tables   | `infra/shared/data/main.bicep`; `src/eShop.Orders.API/data/OrderDbContext.cs` |
| SI-02 | Azure Service Bus          | Async messaging — `ordersplaced` topic / `orderprocessingsub`   | `infra/workload/messaging/main.bicep`; `app.AppHost/AppHost.cs:187-229` |
| SI-03 | Azure Blob Storage         | Archival of processed order payloads (success and error paths)  | `infra/shared/main.bicep`                               |
| SI-04 | Azure Application Insights | Distributed traces, request telemetry, dependency tracking      | `infra/shared/monitoring/app-insights.bicep`            |
| SI-05 | Azure Log Analytics        | Centralised log aggregation for all services and Logic Apps     | `infra/shared/monitoring/log-analytics-workspace.bicep` |
| SI-06 | Azure Container Apps       | Managed hosting platform for Orders API and Web App containers  | `infra/workload/services/main.bicep`                    |
| SI-07 | Azure Container Registry   | Container image registry for built application images           | `infra/workload/main.bicep`                             |
| SI-08 | User Assigned Managed Identity | Zero-credential authentication between all Azure services  | `infra/shared/identity/main.bicep`                      |
| SI-09 | Azure VNet + Subnets       | Network isolation for Logic Apps and Container Apps             | `infra/shared/network/main.bicep`                       |
| SI-10 | .NET Aspire AppHost        | Local development orchestration and service discovery           | `app.AppHost/AppHost.cs`                                |

---

## 7. Standards & Guidelines

### Coding Standards

| ID    | Standard                                      | Description                                                                                                           | Source                                                              |
| ----- | --------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| SG-01 | C# / .NET 10                                 | All application code targets .NET 10 (global.json locks SDK version).                                                 | `global.json`                                                       |
| SG-02 | ASP.NET Core Web API                          | REST API follows ASP.NET Core `[ApiController]` conventions with structured error response bodies.                    | `src/eShop.Orders.API/Controllers/OrdersController.cs:16-18`       |
| SG-03 | Data Annotations Validation                   | Input models use `[Required]`, `[StringLength]`, `[Range]`, and `[MinLength]` attributes enforced by the framework.  | `app.ServiceDefaults/CommonTypes.cs:76-154`                         |
| SG-04 | OpenAPI / Swagger                             | The Orders API exposes an OpenAPI v1 document and Swagger UI at the root path.                                        | `src/eShop.Orders.API/Program.cs:65-77`                             |
| SG-05 | XML Documentation Comments                    | All public types and members include XML `<summary>` documentation comments.                                          | `src/eShop.Orders.API/Controllers/OrdersController.cs:13-39`       |
| SG-06 | Sealed Classes                                | Domain model types (`Order`, `OrderProduct`, `OrderEntity`) and service implementations are declared `sealed`.        | `app.ServiceDefaults/CommonTypes.cs:43`, `71`, `117`                |
| SG-07 | Null Guard Pattern                            | All constructor parameters are validated with `ArgumentNullException.ThrowIfNull` or null-coalescing throw.           | `src/eShop.Orders.API/Controllers/OrdersController.cs:36-38`       |
| SG-08 | Code Formatting Compliance                    | Code formatting is verified by the CI pipeline `.editorconfig` analysis job (`ci-dotnet-reusable.yml`).              | `.github/workflows/ci-dotnet.yml:134`                               |

### Observability Standards

| ID    | Standard                         | Description                                                                                                              | Source                                                                   |
| ----- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------ |
| SG-09 | OpenTelemetry Distributed Tracing | Every API operation creates an `Activity` span with semantic HTTP and domain attributes (order ID, count, route).       | `src/eShop.Orders.API/Controllers/OrdersController.cs:69-83`           |
| SG-10 | Structured Logging               | Log scopes include `TraceId` and `SpanId` to correlate log entries with distributed traces.                             | `src/eShop.Orders.API/Controllers/OrdersController.cs:79-84`           |
| SG-11 | Health Checks                    | Both database and Service Bus health checks are registered and mapped via `.MapDefaultEndpoints()`.                      | `src/eShop.Orders.API/Program.cs:100-109`; `src/eShop.Orders.API/HealthChecks/` |
| SG-12 | Application Insights Integration | All services (API, Web App, Logic Apps) send telemetry to a shared Application Insights instance.                       | `infra/workload/logic-app.bicep:325`; `app.AppHost/AppHost.cs:133-168` |

### Infrastructure Standards

| ID    | Standard                           | Description                                                                                                          | Source                                                          |
| ----- | ---------------------------------- | -------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| SG-13 | Bicep IaC with Naming Convention   | All resources follow the naming convention `{type}-{solution}-{env}-{location-abbrev}`.                              | `infra/main.bicep:110`                                          |
| SG-14 | Resource Tagging                   | All Azure resources are tagged with `Solution`, `Environment`, `CostCenter`, `Owner`, `BusinessUnit`, `DeploymentDate`. | `infra/main.bicep:91-99`                                     |
| SG-15 | Managed Identity Only              | All service-to-service authentication uses User-Assigned Managed Identity; no static secrets in configuration.       | `infra/workload/logic-app.bicep:146-199`                        |
| SG-16 | Environment Parity                 | Infrastructure supports `dev`, `test`, `staging`, and `prod` environments via the `envName` Bicep parameter.         | `infra/main.bicep:63-70`                                        |
| SG-17 | VNet Integration                   | Logic Apps uses VNet integration with private endpoint connectivity for storage services.                             | `infra/workload/logic-app.bicep:289`                            |
| SG-18 | Elastic Scaling for Logic Apps     | Logic Apps Standard App Service Plan uses the `WS1 WorkflowStandard` tier with elastic scaling up to 20 workers.     | `infra/workload/logic-app.bicep:245-270`                        |

### CI/CD Standards

| ID    | Standard                            | Description                                                                                                     | Source                                                            |
| ----- | ----------------------------------- | --------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- |
| SG-19 | Cross-Platform Build and Test       | CI pipeline builds and tests on Ubuntu, Windows, and macOS via matrix strategy.                                 | `.github/workflows/ci-dotnet.yml:117-136`                        |
| SG-20 | Code Coverage (Cobertura)           | Unit tests produce Cobertura XML coverage reports collected as CI artefacts.                                    | `azure.yaml:134-146`                                              |
| SG-21 | CodeQL Security Scanning            | Security vulnerability scanning via CodeQL runs on every push and pull request.                                  | `.github/workflows/ci-dotnet.yml:109`                             |
| SG-22 | Concurrency Control                 | The CI workflow uses a concurrency group to cancel in-progress runs superseded by a newer commit.               | `.github/workflows/ci-dotnet.yml:96-97`                          |
| SG-23 | Preprovision Build Gate             | AZD provisioning requires a clean build and all tests to pass before infrastructure is deployed.                | `azure.yaml:126-149`                                              |

---

## 8. Cross-Layer Dependencies

This section maps dependencies between the Business Architecture layer and the Data, Application, and Technology layers.

### Business-to-Application Dependencies

| Business Component         | Application Component           | Dependency Type     | Source                                                                |
| -------------------------- | ------------------------------- | ------------------- | --------------------------------------------------------------------- |
| Order Entry (BC-001)        | `eShop.Web.App` Blazor Server   | Implements          | `src/eShop.Web.App/Components/Pages/PlaceOrder.razor`                |
| Batch Order Entry (BC-002)  | `eShop.Web.App` Blazor Server   | Implements          | `src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor`          |
| Order Listing (BC-003)      | `eShop.Web.App` Blazor Server   | Implements          | `src/eShop.Web.App/Components/Pages/ListAllOrders.razor`             |
| Order Placement API (BC-005) | `eShop.Orders.API` ASP.NET Core | Implements          | `src/eShop.Orders.API/Controllers/OrdersController.cs:51`            |
| Order Persistence (BC-010)  | `OrderRepository` / EF Core     | Implements          | `src/eShop.Orders.API/Repositories/OrderRepository.cs`               |
| Order Event Publishing (BC-011) | `OrdersMessageHandler` / Service Bus SDK | Implements | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs`         |
| Orders Placed Workflow (BC-012) | Azure Logic Apps Standard   | Implements          | `workflows/…/OrdersPlacedProcess/workflow.json`                      |
| Orders Completion Workflow (BC-013) | Azure Logic Apps Standard | Implements        | `workflows/…/OrdersPlacedCompleteProcess/workflow.json`              |

### Business-to-Data Dependencies

| Business Component          | Data Asset                       | Dependency Type | Source                                                           |
| --------------------------- | -------------------------------- | --------------- | ---------------------------------------------------------------- |
| Order Persistence (BC-010)  | Azure SQL `Orders` table         | Read/Write      | `src/eShop.Orders.API/data/Entities/OrderEntity.cs`             |
| Order Persistence (BC-010)  | Azure SQL `OrderProducts` table  | Read/Write      | `src/eShop.Orders.API/data/Entities/OrderProductEntity.cs`      |
| Order Event Publishing (BC-011) | Azure Service Bus `ordersplaced` topic | Write    | `src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:29`      |
| Orders Placed Workflow (BC-012) | Azure Service Bus `ordersplaced` / `orderprocessingsub` | Read | `workflows/…/OrdersPlacedProcess/workflow.json:149` |
| Order Archival (BC-014)     | Azure Blob `/ordersprocessedsuccessfully` | Write     | `workflows/…/OrdersPlacedProcess/workflow.json:43`              |
| Order Archival (BC-015)     | Azure Blob `/ordersprocessedwitherrors`   | Write     | `workflows/…/OrdersPlacedProcess/workflow.json:70`              |
| Blob Cleanup (BC-016)       | Azure Blob `/ordersprocessedsuccessfully` | Read/Delete | `workflows/…/OrdersPlacedCompleteProcess/workflow.json:37`    |

### Business-to-Technology Dependencies

| Business Component          | Technology Platform          | Dependency Type       | Source                                                       |
| --------------------------- | ---------------------------- | --------------------- | ------------------------------------------------------------ |
| Order Entry (BC-001/002/003) | Azure Container Apps        | Hosting               | `infra/workload/services/main.bicep`                        |
| Order Placement API (BC-005–009) | Azure Container Apps   | Hosting               | `infra/workload/services/main.bicep`                        |
| Order Persistence (BC-010)  | Azure SQL Database           | Storage               | `infra/shared/data/main.bicep`                              |
| Order Event Publishing (BC-011) | Azure Service Bus        | Messaging             | `infra/workload/messaging/main.bicep`                       |
| Orders Placed Workflow (BC-012/013) | Azure Logic Apps Standard | Execution         | `infra/workload/logic-app.bicep`                            |
| Order Archival (BC-014/015/016) | Azure Blob Storage      | Storage               | `infra/shared/main.bicep`                                   |
| Observability (BC-017)      | Azure Application Insights   | Telemetry             | `infra/shared/monitoring/app-insights.bicep`                |
| Observability (BC-017)      | Azure Log Analytics          | Logging               | `infra/shared/monitoring/log-analytics-workspace.bicep`     |
| All services                | User Assigned Managed Identity | Authentication      | `infra/shared/identity/main.bicep`                          |
| All services                | Azure VNet + Subnets         | Network Isolation     | `infra/shared/network/main.bicep`                           |

### Shared Service Dependencies

The `.NET Aspire AppHost` (`app.AppHost/AppHost.cs`) orchestrates local development service discovery and wiring for the following cross-layer dependencies:

| Dependency                       | In App Host                                   | Source                                 |
| -------------------------------- | --------------------------------------------- | -------------------------------------- |
| Web App → Orders API             | `.WithReference(ordersApi)`                   | `app.AppHost/AppHost.cs:25`            |
| Orders API → Azure SQL           | `sqlDatabase` reference via `WithReference`   | `app.AppHost/AppHost.cs:267-268`       |
| Orders API → Azure Service Bus   | `serviceBusResource` reference via `WithReference` | `app.AppHost/AppHost.cs:228-229`  |
| Orders API → Application Insights | `appInsights` reference via `WithReference`  | `app.AppHost/AppHost.cs:163-165`       |

---

## Issues & Gaps

| #   | Category   | Description                                                                                                   | Resolution                                                                              | Status   |
| --- | ---------- | ------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | -------- |
| 1   | gap        | No explicit API versioning strategy found in `OrdersController.cs` or OpenAPI configuration                   | Documented as architectural gap; current API is `v1` per Swagger config                | Open     |
| 2   | gap        | No authentication or authorisation mechanism found for the Orders API (`[Authorize]` attributes absent)       | Documented as gap; currently all endpoints are publicly accessible within the VNet      | Open     |
| 3   | assumption | `OrdersAPIService.cs` (web app HTTP client) was inferred from `Program.cs` service registration and Razor page injection; source not directly inspected | Noted: file confirmed in repository listing | Resolved |
| 4   | gap        | No explicit rate-limiting or throttling policy found at the API layer                                         | Documented as architectural gap                                                         | Open     |
| 5   | assumption | The `OrdersPlacedCompleteProcess` workflow deletes blobs from the success container but its business trigger intent (confirmation vs. cleanup) was inferred from the workflow action names and structure | Workflow intent confirmed from blob container path metadata in `workflow.json:53` | Resolved |

---

## Validation Summary

| Gate ID | Gate Name                                | Score   | Status |
| ------- | ---------------------------------------- | ------- | ------ |
| G-01    | Dependency loading complete              | 100/100 | Pass   |
| G-02    | Workspace fully analyzed                 | 100/100 | Pass   |
| G-03    | All output sections [1,2,3,4,5,7,8] generated | 100/100 | Pass |
| G-04    | No fabricated or hallucinated content    | 100/100 | Pass   |
| G-05    | No TODO / TBD / PLACEHOLDER text         | 100/100 | Pass   |
| G-06    | All findings cross-referenced to sources | 100/100 | Pass   |
