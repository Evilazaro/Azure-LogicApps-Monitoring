# Discovery Report

**Generated**: 2026-01-29  
**Workspace**: z:\app5  
**Project**: Azure Logic Apps Monitoring Solution (eShop Orders Management)

---

## 1. Workspace Overview

### 1.1 Structure Summary

- **Total Files**: ~150+ (excluding build artifacts)
- **Total Directories**: ~50 (excluding bin/obj)
- **Primary Languages**: C# (.NET 10), Bicep, JSON, Razor
- **Key Patterns Identified**:
  - .NET Aspire distributed application orchestration
  - Clean Architecture (Controllers → Services → Repositories)
  - CQRS-like patterns with message handlers
  - Infrastructure as Code (Bicep)
  - Azure Logic Apps Standard workflows

### 1.2 Directory Map

```
z:\app5\
├── .github/                    # CI/CD workflows, Dependabot
│   ├── workflows/              # GitHub Actions (azure-dev.yml, ci-dotnet.yml)
│   └── appmod/                 # App modernization configs
├── .vscode/                    # VS Code workspace settings
├── app.AppHost/                # .NET Aspire orchestration host
│   ├── AppHost.cs              # Distributed app configuration
│   └── infra/                  # Container deployment templates
├── app.ServiceDefaults/        # Shared service configurations
│   ├── Extensions.cs           # OpenTelemetry, health checks, resilience
│   └── CommonTypes.cs          # Shared domain models
├── docs/                       # Documentation
├── hooks/                      # Azure Developer CLI lifecycle hooks
├── infra/                      # Infrastructure as Code (Bicep)
│   ├── main.bicep              # Root deployment orchestrator
│   ├── shared/                 # Shared infra (identity, monitoring, data)
│   └── workload/               # Workload infra (messaging, services, Logic Apps)
├── prompts/                    # Documentation workflow prompts
├── src/                        # Application source code
│   ├── eShop.Orders.API/       # Orders REST API service
│   │   ├── Controllers/        # API endpoints
│   │   ├── Services/           # Business logic
│   │   ├── Repositories/       # Data access
│   │   ├── Handlers/           # Message handlers
│   │   ├── Interfaces/         # Contracts/abstractions
│   │   ├── HealthChecks/       # Health monitoring
│   │   └── data/               # EF Core context and entities
│   ├── eShop.Web.App/          # Blazor Server web application
│   │   └── Components/         # Razor components and pages
│   └── tests/                  # Unit and integration tests
└── workflows/                  # Azure Logic Apps workflows
    └── OrdersManagement/       # Order processing workflows
```

---

## 2. Business Capabilities Discovered

| ID     | Capability Name              | Source Evidence                                                                              | File Path                                                                                 |
| ------ | ---------------------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| BC-001 | Order Management             | Primary domain namespace `eShop.Orders.API`, OrdersController, OrderService, OrderRepository | src/eShop.Orders.API/                                                                     |
| BC-002 | Order Processing             | OrdersPlacedProcess workflow, ProcessOrder endpoint, message handling                        | workflows/OrdersManagement/, src/eShop.Orders.API/Controllers/OrdersController.cs         |
| BC-003 | Order Tracking               | ViewOrder.razor page, GetOrderById endpoint, order search functionality                      | src/eShop.Web.App/Components/Pages/ViewOrder.razor                                        |
| BC-004 | Customer Order Placement     | PlaceOrder.razor, PlaceOrdersBatch.razor, POST endpoints                                     | src/eShop.Web.App/Components/Pages/, src/eShop.Orders.API/Controllers/OrdersController.cs |
| BC-005 | Messaging & Event Publishing | OrdersMessageHandler, Service Bus integration, topic publishing                              | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs                                     |
| BC-006 | Application Monitoring       | Application Insights, OpenTelemetry, health checks, distributed tracing                      | app.ServiceDefaults/Extensions.cs                                                         |
| BC-007 | Infrastructure Provisioning  | Bicep IaC templates for Azure resources                                                      | infra/                                                                                    |

---

## 3. Business Services Discovered

| ID     | Service Name             | Type     | Source Evidence                                                   | File Path                                                  |
| ------ | ------------------------ | -------- | ----------------------------------------------------------------- | ---------------------------------------------------------- |
| BS-001 | Orders API               | Internal | RESTful API for order CRUD operations, Swagger/OpenAPI            | src/eShop.Orders.API/Program.cs                            |
| BS-002 | Web Application          | Internal | Blazor Server UI for order management                             | src/eShop.Web.App/Program.cs                               |
| BS-003 | Order Service            | Internal | Business logic layer implementing IOrderService                   | src/eShop.Orders.API/Services/OrderService.cs              |
| BS-004 | Order Repository         | Internal | Data access layer implementing IOrderRepository                   | src/eShop.Orders.API/Repositories/OrderRepository.cs       |
| BS-005 | Orders Message Handler   | Internal | Service Bus message publishing implementing IOrdersMessageHandler | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs      |
| BS-006 | Orders API HTTP Client   | Internal | Typed HTTP client for API communication                           | src/eShop.Web.App/Components/Services/OrdersAPIService.cs  |
| BS-007 | Database Health Check    | Internal | SQL Server connectivity monitoring                                | src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs  |
| BS-008 | Service Bus Health Check | Internal | Azure Service Bus connectivity monitoring                         | src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs |

---

## 4. Business Processes Discovered

| ID     | Process Name              | Trigger                        | Outcome                                                                 | File Path                                                                                     |
| ------ | ------------------------- | ------------------------------ | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| BP-001 | Place Order               | HTTP POST /api/orders          | Order persisted to database, message published to Service Bus           | src/eShop.Orders.API/Controllers/OrdersController.cs:PlaceOrder                               |
| BP-002 | Place Orders Batch        | HTTP POST /api/orders/batch    | Multiple orders persisted, batch messages published                     | src/eShop.Orders.API/Controllers/OrdersController.cs:PlaceOrdersBatch                         |
| BP-003 | Get Order By ID           | HTTP GET /api/orders/{id}      | Order details retrieved from database                                   | src/eShop.Orders.API/Controllers/OrdersController.cs:GetOrderById                             |
| BP-004 | Get All Orders            | HTTP GET /api/orders           | All orders retrieved from database                                      | src/eShop.Orders.API/Controllers/OrdersController.cs:GetOrders                                |
| BP-005 | Delete Order              | HTTP DELETE /api/orders/{id}   | Order removed from database                                             | src/eShop.Orders.API/Controllers/OrdersController.cs:DeleteOrder                              |
| BP-006 | Process Order Message     | Service Bus message trigger    | HTTP call to Orders API process endpoint, result stored in Blob Storage | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json         |
| BP-007 | Complete Order Processing | Recurrence trigger (3 seconds) | List and delete processed order blobs                                   | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json |
| BP-008 | Database Initialization   | Application startup            | Database migrations applied, connectivity verified                      | src/eShop.Orders.API/Program.cs:InitializeDatabaseAsync                                       |

---

## 5. Business Actors/Roles Discovered

| ID     | Actor/Role Name            | Type                    | Responsibilities                                              | File Path                                   |
| ------ | -------------------------- | ----------------------- | ------------------------------------------------------------- | ------------------------------------------- |
| BA-001 | Customer                   | External                | Places orders, views order status, manages delivery addresses | Inferred from Order.CustomerId, UI pages    |
| BA-002 | Web Application User       | External                | Interacts with eShop Web App UI to manage orders              | src/eShop.Web.App/Components/Pages/         |
| BA-003 | System Administrator       | External                | Deploys infrastructure, monitors application health           | infra/, hooks/                              |
| BA-004 | Orders API System          | Internal                | Processes API requests, persists data, publishes events       | src/eShop.Orders.API/                       |
| BA-005 | Logic Apps Workflow Engine | Internal                | Orchestrates async order processing workflows                 | workflows/OrdersManagement/                 |
| BA-006 | Azure Service Bus          | External/Infrastructure | Message broker for event-driven communication                 | Configured in AppHost.cs, Extensions.cs     |
| BA-007 | Azure SQL Database         | External/Infrastructure | Persistent data storage for orders                            | Configured in Program.cs, OrderDbContext.cs |

---

## 6. Business Events Discovered

| ID     | Event Name         | Producer             | Consumer(s)                             | File Path                                                                         |
| ------ | ------------------ | -------------------- | --------------------------------------- | --------------------------------------------------------------------------------- |
| BE-001 | OrderPlaced        | OrdersMessageHandler | Logic Apps OrdersPlacedProcess workflow | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs                             |
| BE-002 | OrderBatchPlaced   | OrdersMessageHandler | Logic Apps workflows (batch)            | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:SendOrdersBatchMessageAsync |
| BE-003 | ApplicationStarted | WebApplication       | Database initialization process         | src/eShop.Orders.API/Program.cs:ApplicationStarted.Register                       |

---

## 7. Business Rules Discovered

| ID     | Rule Name                               | Enforcement Point                      | File Path                                                       |
| ------ | --------------------------------------- | -------------------------------------- | --------------------------------------------------------------- |
| BR-001 | Order ID Required                       | Order model validation attribute       | app.ServiceDefaults/CommonTypes.cs:Order.Id                     |
| BR-002 | Customer ID Required                    | Order model validation attribute       | app.ServiceDefaults/CommonTypes.cs:Order.CustomerId             |
| BR-003 | Delivery Address Required (5-500 chars) | Order model validation attribute       | app.ServiceDefaults/CommonTypes.cs:Order.DeliveryAddress        |
| BR-004 | Order Total Must Be Positive            | Range validation attribute             | app.ServiceDefaults/CommonTypes.cs:Order.Total                  |
| BR-005 | Order Must Have At Least One Product    | MinLength validation attribute         | app.ServiceDefaults/CommonTypes.cs:Order.Products               |
| BR-006 | Product Quantity Must Be >= 1           | Range validation attribute             | app.ServiceDefaults/CommonTypes.cs:OrderProduct.Quantity        |
| BR-007 | Product Price Must Be Positive          | Range validation attribute             | app.ServiceDefaults/CommonTypes.cs:OrderProduct.Price           |
| BR-008 | Duplicate Order Prevention              | Repository existence check before save | src/eShop.Orders.API/Services/OrderService.cs:PlaceOrderAsync   |
| BR-009 | Temperature Range Validation            | Range attribute (-273 to 200°C)        | app.ServiceDefaults/CommonTypes.cs:WeatherForecast.TemperatureC |
| BR-010 | Connection String Required              | Runtime validation                     | src/eShop.Orders.API/Program.cs, src/eShop.Web.App/Program.cs   |

---

## 8. Domain Entities Discovered

| ID     | Entity Name        | Key Attributes                                              | Relationships                    | File Path                                                |
| ------ | ------------------ | ----------------------------------------------------------- | -------------------------------- | -------------------------------------------------------- |
| BO-001 | Order              | Id, CustomerId, Date, DeliveryAddress, Total, Products      | Has many OrderProducts           | app.ServiceDefaults/CommonTypes.cs:Order                 |
| BO-002 | OrderProduct       | Id, OrderId, ProductId, ProductDescription, Quantity, Price | Belongs to Order                 | app.ServiceDefaults/CommonTypes.cs:OrderProduct          |
| BO-003 | OrderEntity        | Id, CustomerId, Date, DeliveryAddress, Total, Products      | Has many OrderProductEntity (DB) | src/eShop.Orders.API/data/Entities/OrderEntity.cs        |
| BO-004 | OrderProductEntity | Id, OrderId, ProductId, ProductDescription, Quantity, Price | Belongs to OrderEntity (DB)      | src/eShop.Orders.API/data/Entities/OrderProductEntity.cs |
| BO-005 | WeatherForecast    | Date, TemperatureC, TemperatureF, Summary                   | None                             | app.ServiceDefaults/CommonTypes.cs:WeatherForecast       |

---

## 9. Value Streams (If Identifiable)

| ID     | Value Stream Name | Stages                                                                                                                            | File Path                             |
| ------ | ----------------- | --------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------- |
| VS-001 | Order Fulfillment | Customer places order → Order validated → Order persisted → Message published → Async processing → Order processed → Blob cleanup | End-to-end flow across multiple files |

**Value Stream Stages:**

1. **Order Placement**: Customer submits order via Web App (PlaceOrder.razor)
2. **Order Validation**: Business rules enforced (CommonTypes.cs, OrderService.cs)
3. **Order Persistence**: Order saved to Azure SQL Database (OrderRepository.cs)
4. **Event Publishing**: OrderPlaced message sent to Service Bus (OrdersMessageHandler.cs)
5. **Async Processing**: Logic Apps workflow triggered (OrdersPlacedProcess/workflow.json)
6. **Result Storage**: Processed orders stored in Blob Storage (workflow.json)
7. **Cleanup**: Completed order blobs deleted (OrdersPlacedCompleteProcess/workflow.json)

---

## 10. Organization Units (If Identifiable)

Organization units not explicitly identified in codebase.

_Note: The repository metadata indicates ownership by "Evilazaro" and the solution is labeled as "Azure-LogicApps-Monitoring" with repository attribution to `Azure-LogicApps-Monitoring`. Infrastructure tags reference "Platform-Team" as owner and "Engineering" as cost center._

| ID     | Org Unit Name | Owned Capabilities                   | File Path                         |
| ------ | ------------- | ------------------------------------ | --------------------------------- |
| OU-001 | Platform-Team | Infrastructure Provisioning (BC-007) | infra/main.bicep (tags)           |
| OU-002 | Engineering   | All application capabilities         | infra/main.bicep (CostCenter tag) |

---

## 11. Relationship Map

### 11.1 Actor → Service Relationships

| Actor                 | Service                         | Relationship Type | Evidence                             |
| --------------------- | ------------------------------- | ----------------- | ------------------------------------ |
| BA-001 (Customer)     | BS-002 (Web Application)        | Uses              | UI interactions for order management |
| BA-002 (Web App User) | BS-006 (Orders API HTTP Client) | Uses              | Service injection in Razor pages     |
| BS-006 (HTTP Client)  | BS-001 (Orders API)             | Calls             | HTTP requests to API endpoints       |
| BA-003 (Admin)        | BC-007 (Infrastructure)         | Manages           | Bicep deployments via azd            |
| BA-006 (Service Bus)  | BS-005 (Message Handler)        | Receives from     | Message publishing                   |
| BA-005 (Logic Apps)   | BA-006 (Service Bus)            | Subscribes to     | Topic subscriptions                  |

### 11.2 Service → Capability Relationships

| Service                   | Capability                        | Relationship Type | Evidence                      |
| ------------------------- | --------------------------------- | ----------------- | ----------------------------- |
| BS-001 (Orders API)       | BC-001 (Order Management)         | Realizes          | REST endpoints for CRUD       |
| BS-003 (Order Service)    | BC-001 (Order Management)         | Realizes          | Business logic implementation |
| BS-004 (Order Repository) | BC-001 (Order Management)         | Realizes          | Data persistence              |
| BS-005 (Message Handler)  | BC-005 (Messaging)                | Realizes          | Service Bus integration       |
| BS-002 (Web App)          | BC-003 (Order Tracking)           | Realizes          | ViewOrder page                |
| BS-002 (Web App)          | BC-004 (Customer Order Placement) | Realizes          | PlaceOrder pages              |

### 11.3 Capability → Entity Relationships

| Capability                | Entity                | Relationship Type | Evidence                   |
| ------------------------- | --------------------- | ----------------- | -------------------------- |
| BC-001 (Order Management) | BO-001 (Order)        | Operates on       | OrderService methods       |
| BC-001 (Order Management) | BO-002 (OrderProduct) | Operates on       | Included in Order          |
| BC-001 (Order Management) | BO-003 (OrderEntity)  | Persists          | OrderRepository operations |

### 11.4 Process → Event Relationships

| Process                     | Event                          | Relationship Type | Evidence                         |
| --------------------------- | ------------------------------ | ----------------- | -------------------------------- |
| BP-001 (Place Order)        | BE-001 (OrderPlaced)           | Produces          | SendOrderMessageAsync call       |
| BP-002 (Place Orders Batch) | BE-002 (OrderBatchPlaced)      | Produces          | SendOrdersBatchMessageAsync call |
| BE-001 (OrderPlaced)        | BP-006 (Process Order Message) | Triggers          | Service Bus trigger in workflow  |

---

## 12. Glossary of Terms

| Term               | Definition                                                                   | Source File                                       |
| ------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------- |
| Order              | A customer order containing products, delivery information, and total amount | app.ServiceDefaults/CommonTypes.cs                |
| OrderProduct       | An individual product item within an order with quantity and pricing         | app.ServiceDefaults/CommonTypes.cs                |
| OrderEntity        | Database representation of an Order entity in EF Core                        | src/eShop.Orders.API/data/Entities/OrderEntity.cs |
| OrderDbContext     | Entity Framework Core database context for order management                  | src/eShop.Orders.API/data/OrderDbContext.cs       |
| Service Defaults   | Shared configurations for OpenTelemetry, health checks, and resilience       | app.ServiceDefaults/Extensions.cs                 |
| AppHost            | .NET Aspire distributed application orchestrator                             | app.AppHost/AppHost.cs                            |
| Activity Source    | OpenTelemetry distributed tracing instrumentation                            | Multiple files                                    |
| Managed Identity   | Azure AD identity for service-to-service authentication                      | infra/main.bicep, AppHost.cs                      |
| Service Bus Topic  | Azure Service Bus topic for publish-subscribe messaging                      | Configured as "ordersplaced"                      |
| Logic App Workflow | Azure Logic Apps Standard serverless workflow                                | workflows/OrdersManagement/                       |
| Health Check       | Kubernetes/Container Apps compatible health monitoring endpoint              | src/eShop.Orders.API/HealthChecks/                |
| Resilience Handler | HTTP client retry, timeout, and circuit breaker policies                     | app.ServiceDefaults/Extensions.cs                 |
| Bicep              | Azure Infrastructure as Code declarative language                            | infra/\*.bicep                                    |
| azd                | Azure Developer CLI for deployment orchestration                             | azure.yaml                                        |

---

## 13. Gaps & Limitations

| Gap ID | Category             | Description                                                               | Impact on Documentation                                   |
| ------ | -------------------- | ------------------------------------------------------------------------- | --------------------------------------------------------- |
| G-001  | Authentication       | No explicit user authentication/authorization implementation found in API | Cannot document security roles or access control patterns |
| G-002  | Product Catalog      | No product catalog service or entity—products are embedded in orders      | Limited product management capability documentation       |
| G-003  | Order Status         | No explicit order status/state machine found                              | Cannot document order lifecycle states                    |
| G-004  | Payment Processing   | No payment integration or financial transaction handling                  | Cannot document payment workflow                          |
| G-005  | Inventory Management | No inventory tracking or stock management                                 | Cannot document inventory business capability             |
| G-006  | Customer Entity      | Customer is referenced by ID only, no customer profile entity             | Limited customer management documentation                 |
| G-007  | Notification Service | No email/SMS notification for order updates                               | Cannot document notification processes                    |
| G-008  | Audit Trail          | No explicit audit logging for order changes                               | Cannot document compliance/audit capabilities             |

---

## 14. Source File Index

| File Path                                                                                     | Elements Extracted                            |
| --------------------------------------------------------------------------------------------- | --------------------------------------------- |
| app.AppHost/AppHost.cs                                                                        | BC-006, BS-001, BS-002, BA-006, BA-007        |
| app.ServiceDefaults/Extensions.cs                                                             | BC-006, BS-007, BS-008, BR-010                |
| app.ServiceDefaults/CommonTypes.cs                                                            | BO-001, BO-002, BO-005, BR-001 through BR-009 |
| src/eShop.Orders.API/Program.cs                                                               | BS-001, BP-008, BR-010                        |
| src/eShop.Orders.API/Controllers/OrdersController.cs                                          | BC-001, BP-001 through BP-005                 |
| src/eShop.Orders.API/Services/OrderService.cs                                                 | BS-003, BR-008                                |
| src/eShop.Orders.API/Repositories/OrderRepository.cs                                          | BS-004                                        |
| src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs                                         | BS-005, BC-005, BE-001, BE-002                |
| src/eShop.Orders.API/Handlers/NoOpOrdersMessageHandler.cs                                     | BS-005 (stub)                                 |
| src/eShop.Orders.API/Interfaces/IOrderService.cs                                              | BS-003 (contract)                             |
| src/eShop.Orders.API/Interfaces/IOrderRepository.cs                                           | BS-004 (contract)                             |
| src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs                                      | BS-005 (contract)                             |
| src/eShop.Orders.API/data/OrderDbContext.cs                                                   | BO-003, BO-004                                |
| src/eShop.Orders.API/data/Entities/OrderEntity.cs                                             | BO-003                                        |
| src/eShop.Orders.API/data/Entities/OrderProductEntity.cs                                      | BO-004                                        |
| src/eShop.Orders.API/data/OrderMapper.cs                                                      | BO-001 ↔ BO-003 mapping                       |
| src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs                                     | BS-007                                        |
| src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs                                    | BS-008                                        |
| src/eShop.Web.App/Program.cs                                                                  | BS-002, BS-006                                |
| src/eShop.Web.App/Components/Services/OrdersAPIService.cs                                     | BS-006                                        |
| src/eShop.Web.App/Components/Pages/Home.razor                                                 | BC-003, BC-004 (UI)                           |
| src/eShop.Web.App/Components/Pages/ViewOrder.razor                                            | BC-003 (UI)                                   |
| src/eShop.Web.App/Components/Pages/PlaceOrder.razor                                           | BC-004 (UI)                                   |
| src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor                                     | BC-004 (UI)                                   |
| src/eShop.Web.App/Components/Pages/ListAllOrders.razor                                        | BC-003 (UI)                                   |
| workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json         | BP-006, BA-005                                |
| workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json | BP-007, BA-005                                |
| infra/main.bicep                                                                              | BC-007, OU-001, OU-002                        |
| infra/workload/main.bicep                                                                     | BC-007                                        |
| azure.yaml                                                                                    | BC-007 (deployment config)                    |

---

## 15. Discovery Completion Checklist

```
☑ All workspace directories scanned
☑ All source files read and analyzed
☑ All Business Architecture elements cataloged (7 capabilities, 8 services, 8 processes, 7 actors, 3 events, 10 rules, 5 entities)
☑ All relationships mapped (4 relationship categories)
☑ All terminology extracted (14 glossary terms)
☑ All gaps documented (8 gaps identified)
☑ Source file index complete (28 files indexed)
☑ Discovery report saved to specified location
```

---

_End of Discovery Report_
