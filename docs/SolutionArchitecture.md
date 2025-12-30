# Azure Logic Apps Monitoring Solution - Architecture Documentation

**Version:** 1.0.0  
**Last Updated:** December 30, 2025  
**Framework:** TOGAF BDAT (Business, Data, Application, Technology)

---

## 1. Executive Summary

### Purpose and Business Value

The Azure Logic Apps Monitoring Solution is a comprehensive, cloud-native reference architecture demonstrating best practices for **observability, distributed tracing, and monitoring** in modern Azure applications. Built with **.NET 10, .NET Aspire 9.5, Azure Container Apps, and Application Insights**, this solution provides a fully instrumented e-commerce order management system that serves as both a functional application and a learning resource for cloud architects.

The solution addresses three critical enterprise needs: (1) **end-to-end distributed tracing** across microservices and messaging systems, enabling rapid root cause analysis; (2) **production-grade observability** with integrated metrics, logs, and traces flowing to Application Insights; and (3) **dual-mode development** supporting both local containerized development and Azure cloud deployment with zero code changes.

### Key Technology Choices

| Technology | Version | Rationale |
|------------|---------|-----------|
| .NET | 10.0 | Latest LTS framework with enhanced performance and cloud-native features |
| .NET Aspire | 9.5 | Modern orchestration with built-in observability, service discovery, and resilience |
| Azure Container Apps | Latest | Serverless containers with KEDA auto-scaling and Dapr integration |
| Azure Service Bus | Standard | Enterprise messaging with topic-based pub/sub for order events |
| Azure SQL Database | GP_Gen5_2 | Managed relational storage with Entra ID authentication |
| Application Insights | Workspace-based | Unified telemetry platform with Log Analytics integration |
| Blazor Server | .NET 10 | Interactive web UI with Fluent UI components and SignalR |

### Target Deployment Model

The solution deploys to **Azure Container Apps** using a serverless consumption model with automatic scaling from zero. Infrastructure is provisioned via **Azure Developer CLI (azd)** with modular Bicep templates, enabling consistent deployments across development, staging, and production environments.

---

## 2. Architecture Principles & Key Decisions

### Guiding Principles

1. **Observability-First Design**: Every service is instrumented with OpenTelemetry from inception, not retrofitted. Telemetry is a first-class concern implemented in [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs).

2. **Infrastructure as Code**: All Azure resources are defined in Bicep templates under [infra/](infra/), ensuring repeatable, auditable deployments with no manual portal configurations.

3. **Managed Identity Everywhere**: Zero secrets in code or configuration. All Azure service authentication uses User-Assigned Managed Identity configured in [infra/shared/identity/main.bicep](infra/shared/identity/main.bicep).

4. **Local-Cloud Parity**: The same application code runs locally (with emulators/containers) and in Azure through .NET Aspire's configuration abstraction in [app.AppHost/AppHost.cs](app.AppHost/AppHost.cs).

5. **Separation of Concerns**: Clear layering with Controllers → Services → Repositories → Data patterns in [src/eShop.Orders.API/](src/eShop.Orders.API/).

### Key Architectural Decisions

| Decision | Choice | Trade-offs & Rationale |
|----------|--------|------------------------|
| **Orchestration** | .NET Aspire AppHost | Provides unified local dev experience with automatic service discovery, but requires .NET 10+ and Aspire workload installation |
| **Database** | Azure SQL with EF Core | Strong consistency and ACID guarantees for order transactions; higher cost than NoSQL but familiar to enterprise teams |
| **Messaging** | Service Bus Topics | Pub/sub pattern allows multiple subscribers; Standard tier limits throughput to ~1000 msg/sec but sufficient for reference implementation |
| **Authentication** | Entra ID Only | Enhanced security by eliminating SQL authentication; requires post-provisioning identity configuration via [hooks/sql-managed-identity-config.ps1](hooks/sql-managed-identity-config.ps1) |
| **Frontend** | Blazor Server | Rich interactivity with SignalR; server-side rendering avoids WASM download but requires persistent connection |
| **Container Registry** | Premium ACR | Supports geo-replication for production; higher cost justified by enhanced throughput and security features |

---

## 3. Architecture Domains

### 3.1 Business Architecture

The solution implements an **order management capability** demonstrating cloud-native monitoring patterns. Business value is delivered through transparent order processing with full audit trails.

#### Business Capability Map

```mermaid
flowchart TD
    subgraph Enterprise["Monitoring Solution"]
        subgraph L1_OrderMgmt["1. Order Management"]
            L1_Desc["Core business operations:<br/>CRUD for orders"]
            PlaceOrder["Place Order"]
            ViewOrder["View Order"]
            DeleteOrder["Delete Order"]
            BatchProcess["Batch Processing"]
        end
        
        subgraph L2_EventProcessing["2. Event-Driven Processing"]
            L2_Desc["Async communication:<br/>message pub/sub"]
            PublishEvents["Publish Order Events"]
            ConsumeEvents["Consume Events"]
            DeadLetterMgmt["Failed Message Handling"]
        end
        
        subgraph L3_WorkflowAutomation["3. Workflow Automation"]
            L3_Desc["Automated processing:<br/>success/error routing"]
            ProcessOrders["Process Order Workflows"]
            RouteSuccess["Route Successful Orders"]
            RouteErrors["Route Failed Orders"]
        end
        
        subgraph L4_Observability["4. Observability"]
            L4_Desc["Cross-cutting:<br/>monitoring & tracing"]
            DistributedTracing["Distributed Tracing"]
            MetricsCollection["Metrics Collection"]
            LogAggregation["Log Aggregation"]
            HealthMonitoring["Health Monitoring"]
        end
    end
    
    style L1_Desc fill:#e1f5fe,stroke:#01579b,color:#01579b
    style L2_Desc fill:#f3e5f5,stroke:#4a148c,color:#4a148c
    style L3_Desc fill:#e8f5e9,stroke:#1b5e20,color:#1b5e20
    style L4_Desc fill:#fff3e0,stroke:#e65100,color:#e65100
```

#### Capability Domain Mapping

| # | Capability Domain | Description | Key Files |
|---|-------------------|-------------|-----------|
| 1 | **Order Management** | Core business operations - create, read, update, delete orders | [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs) |
| 2 | **Event-Driven Processing** | Asynchronous communication via message publishing and consumption | [src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs](src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs) |
| 3 | **Workflow Automation** | Automated processing with success/error routing | [infra/workload/logic-app.bicep](infra/workload/logic-app.bicep) |
| 4 | **Observability** | Cross-cutting monitoring, tracing, and health checks | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs) |

### 3.2 Application Architecture

The solution follows a **layered microservices architecture** with two primary services orchestrated by .NET Aspire. This section documents the application landscape, service catalog, API contracts, and integration patterns.

#### Application Landscape

```mermaid
flowchart TB
    subgraph Presentation["Presentation Layer"]
        direction LR
        P1["eShop.Web.App"]
        P1_Desc["Blazor Server + Fluent UI<br/>Customer-facing portal"]
    end
    
    subgraph Application["Application Layer"]
        direction LR
        A1["eShop.Orders.API"]
        A1_Desc["ASP.NET Core Web API<br/>RESTful order operations"]
    end
    
    subgraph Domain["Domain Services Layer"]
        direction LR
        D1["OrderService"]
        D1_Desc["Business logic orchestration"]
        D2["OrdersMessageHandler"]
        D2_Desc["Service Bus publisher"]
    end
    
    subgraph Integration["Integration Layer"]
        direction LR
        I1["Azure Service Bus"]
        I1_Desc["Topic: ordersplaced<br/>Async event distribution"]
        I2["Logic Apps Workflow"]
        I2_Desc["Automated order processing"]
    end
    
    subgraph Data["Data Layer"]
        direction LR
        DA1["OrderRepository"]
        DA1_Desc["EF Core Repository Pattern"]
        DA2["OrderDbContext"]
        DA2_Desc["Database abstraction"]
    end
    
    subgraph Platform["Platform Services"]
        direction LR
        PS1["app.ServiceDefaults"]
        PS1_Desc["OpenTelemetry + Resilience"]
        PS2["app.AppHost"]
        PS2_Desc[".NET Aspire Orchestrator"]
    end
    
    %% Layer connections (high-level flow)
    Presentation --> Application
    Application --> Domain
    Domain --> Integration
    Domain --> Data
    Platform -.->|"Cross-Cutting"| Presentation
    Platform -.->|"Cross-Cutting"| Application
    
    %% Styling
    style P1_Desc fill:#e3f2fd,stroke:#1565c0,color:#0d47a1
    style A1_Desc fill:#f3e5f5,stroke:#7b1fa2,color:#4a148c
    style D1_Desc fill:#e8f5e9,stroke:#388e3c,color:#1b5e20
    style D2_Desc fill:#e8f5e9,stroke:#388e3c,color:#1b5e20
    style I1_Desc fill:#fff3e0,stroke:#f57c00,color:#e65100
    style I2_Desc fill:#fff3e0,stroke:#f57c00,color:#e65100
    style DA1_Desc fill:#fce4ec,stroke:#c2185b,color:#880e4f
    style DA2_Desc fill:#fce4ec,stroke:#c2185b,color:#880e4f
    style PS1_Desc fill:#eceff1,stroke:#546e7a,color:#37474f
    style PS2_Desc fill:#eceff1,stroke:#546e7a,color:#37474f
```

#### Service Catalog

| # | Service | Type | Technology Stack | Owner | Status |
|---|---------|------|------------------|-------|--------|
| 1 | **eShop.Web.App** | Frontend | Blazor Server, Fluent UI, .NET 10 | Platform Team | Active |
| 2 | **eShop.Orders.API** | Backend API | ASP.NET Core, EF Core, .NET 10 | Platform Team | Active |
| 3 | **app.AppHost** | Orchestrator | .NET Aspire 9.5 | Platform Team | Active |
| 4 | **app.ServiceDefaults** | Shared Library | OpenTelemetry, Resilience | Platform Team | Active |
| 5 | **OrdersManagementLogicApp** | Workflow | Azure Logic Apps Standard | Platform Team | Active |

#### Service Details

##### eShop.Web.App (Frontend)
- **Purpose**: Customer-facing web portal for order management
- **Key Files**: [src/eShop.Web.App/Program.cs](src/eShop.Web.App/Program.cs), [Components/](src/eShop.Web.App/Components/)
- **Dependencies**: eShop.Orders.API (HTTP), app.ServiceDefaults
- **Deployment**: Azure Container Apps (Consumption)

##### eShop.Orders.API (Backend)
- **Purpose**: RESTful API for order CRUD operations and event publishing
- **Key Files**: [src/eShop.Orders.API/Program.cs](src/eShop.Orders.API/Program.cs), [Controllers/](src/eShop.Orders.API/Controllers/)
- **Dependencies**: Azure SQL Database, Azure Service Bus, app.ServiceDefaults
- **Deployment**: Azure Container Apps (Consumption)

##### app.AppHost (Orchestrator)
- **Purpose**: .NET Aspire orchestrator managing service wiring and resource provisioning
- **Key Files**: [app.AppHost/AppHost.cs](app.AppHost/AppHost.cs)
- **Resources Managed**: orders-api, web-app, sql-database, service-bus
- **Environment**: Local development and cloud deployment coordination

#### API Contracts

The Orders API exposes RESTful endpoints defined in [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs):

| # | Endpoint | Method | Request Body | Response | Purpose |
|---|----------|--------|--------------|----------|---------|
| 1 | `/api/orders` | POST | `Order` JSON | `201 Created` | Place single order |
| 2 | `/api/orders/batch` | POST | `Order[]` JSON | `201 Created` | Place multiple orders |
| 3 | `/api/orders` | GET | — | `Order[]` JSON | List all orders |
| 4 | `/api/orders/{id}` | GET | — | `Order` JSON | Get order by ID |
| 5 | `/api/orders/{id}` | DELETE | — | `204 No Content` | Delete order |
| 6 | `/health` | GET | — | Health status | Health check endpoint |
| 7 | `/alive` | GET | — | `200 OK` | Liveness probe endpoint |

#### Integration Patterns

| # | Pattern | Implementation | Source | Target | Description |
|---|---------|----------------|--------|--------|-------------|
| 1 | **Pub/Sub** | Azure Service Bus Topic | Orders API | Logic Apps | Orders published to `ordersplaced` topic |
| 2 | **Service Discovery** | .NET Aspire | Web App | Orders API | Automatic endpoint resolution via `orders-api` reference |
| 3 | **Repository** | EF Core | OrderService | SQL Database | Data access abstraction via `OrderRepository` |
| 4 | **Health Aggregation** | ASP.NET Core | All Services | Orchestrator | `/health` and `/alive` endpoints for monitoring |

#### Communication Flow

```mermaid
sequenceDiagram
    participant User as Web User
    participant Web as eShop.Web.App
    participant API as eShop.Orders.API
    participant SB as Azure Service Bus
    participant Logic as Logic Apps
    participant DB as Azure SQL
    
    User->>Web: Submit Order
    Web->>API: POST /api/orders
    API->>DB: Save Order
    DB-->>API: Order Saved
    API->>SB: Publish to ordersplaced
    API-->>Web: 201 Created
    Web-->>User: Order Confirmed
    
    SB->>Logic: Trigger Workflow
    Logic->>Logic: Process Order
    Logic-->>SB: Acknowledge
```

### 3.3 Data Architecture

#### Data Stores

| Store | Technology | Purpose | Configuration |
|-------|------------|---------|---------------|
| **OrderDb** | Azure SQL Database | Order and product persistence | GP_Gen5_2, 32GB, Entra-only auth |
| **Service Bus** | Azure Service Bus Standard | Order event messaging | `ordersplaced` topic with `orderprocessingsub` subscription |
| **Workflow Storage** | Azure Storage Account | Logic Apps runtime state | Standard_LRS, Hot tier |
| **Diagnostics Storage** | Azure Storage Account | Log archive and diagnostics | Standard_LRS with lifecycle management |

#### Entity Model

Defined in [src/eShop.Orders.API/data/Entities/](src/eShop.Orders.API/data/Entities/):

- **OrderEntity**: Id, CustomerId, Date, DeliveryAddress, Total, Products[]
- **OrderProductEntity**: Id, OrderId, ProductId, ProductDescription, Quantity, Price

#### Data Landscape

```mermaid
flowchart TD
    subgraph Applications["Applications"]
        WebApp["Web App"]
        OrdersAPI["Orders API"]
        LogicApp["Logic App Workflows"]
    end
    
    subgraph RelationalData["Relational Data"]
        SQLServer["Azure SQL Server<br/>Entra ID Authentication"]
        OrderDB["OrderDb Database<br/>Orders + OrderProducts Tables"]
    end
    
    subgraph MessagingData["Messaging Data"]
        ServiceBus["Azure Service Bus<br/>Standard Tier"]
        OrdersTopic["ordersplaced Topic"]
        OrdersSub["orderprocessingsub<br/>Subscription"]
    end
    
    subgraph StorageData["Storage Data"]
        WorkflowSA["Workflow Storage<br/>Logic App State"]
        DiagSA["Diagnostics Storage<br/>Logs Archive"]
        SuccessBlob["ordersprocessedsuccessfully<br/>Container"]
        ErrorBlob["ordersprocessedwitherrors<br/>Container"]
    end
    
    subgraph MonitoringData["Monitoring Data"]
        AppInsights["Application Insights<br/>Telemetry"]
        LogAnalytics["Log Analytics<br/>Centralized Logs"]
    end
    
    WebApp -->|"HTTP API"| OrdersAPI
    OrdersAPI -->|"EF Core"| SQLServer
    SQLServer --> OrderDB
    OrdersAPI -->|"Publish"| ServiceBus
    ServiceBus --> OrdersTopic
    OrdersTopic --> OrdersSub
    
    LogicApp -->|"Subscribe"| OrdersSub
    LogicApp -->|"Write Success"| SuccessBlob
    LogicApp -->|"Write Errors"| ErrorBlob
    
    OrdersAPI -->|"Traces + Metrics"| AppInsights
    WebApp -->|"Traces + Metrics"| AppInsights
    AppInsights --> LogAnalytics
```

### 3.4 Technology Architecture

#### Runtime Infrastructure

| Component | Azure Service | SKU/Tier | Purpose |
|-----------|--------------|----------|---------|
| Container Hosting | Container Apps Environment | Consumption | Serverless container runtime |
| Container Images | Container Registry | Premium | Image storage with geo-replication |
| Web API Runtime | Container App | Consumption profile | orders-api hosting |
| Frontend Runtime | Container App | Consumption profile | web-app hosting |
| Workflow Engine | Logic Apps Standard | WS1 (WorkflowStandard) | Order processing workflows |

#### Technology Landscape

```mermaid
flowchart TD
    subgraph AzureSubscription["Azure Subscription"]
        subgraph ResourceGroup["Resource Group: rg-orders-{env}-{region}"]
            subgraph Identity["Identity"]
                ManagedIdentity["User-Assigned<br/>Managed Identity"]
            end
            
            subgraph Compute["Compute Services"]
                ContainerEnv["Container Apps<br/>Environment"]
                ACR["Azure Container<br/>Registry Premium"]
                LogicApp["Logic Apps<br/>Standard WS1"]
                AspireDash["Aspire Dashboard<br/>Component"]
            end
            
            subgraph Data["Data Services"]
                SQLServer["Azure SQL Server<br/>GP_Gen5_2"]
                ServiceBus["Service Bus<br/>Standard Tier"]
                StorageAcct["Storage Accounts<br/>Standard_LRS"]
            end
            
            subgraph Monitoring["Monitoring Services"]
                AppInsights["Application Insights<br/>Workspace-based"]
                LogAnalytics["Log Analytics<br/>Workspace"]
            end
        end
    end
    
    ManagedIdentity -->|"Authenticates"| SQLServer
    ManagedIdentity -->|"Authenticates"| ServiceBus
    ManagedIdentity -->|"Authenticates"| StorageAcct
    ManagedIdentity -->|"Authenticates"| ACR
    
    ContainerEnv --> ACR
    ContainerEnv --> AppInsights
    LogicApp --> ServiceBus
    LogicApp --> StorageAcct
    
    SQLServer --> LogAnalytics
    ServiceBus --> LogAnalytics
    AppInsights --> LogAnalytics
```

---

## 4. Architecture Views

### 4.1 Context Diagram

System boundaries showing external actors and integration points.

```mermaid
flowchart TD
    subgraph ExternalActors["External Actors"]
        WebUser["Web Browser User"]
        DevOps["DevOps Engineer"]
        AZD["Azure Developer CLI"]
    end
    
    subgraph AzureLogicAppsMonitoring["Azure Logic Apps Monitoring Solution"]
        WebApp["eShop Web App<br/>Blazor Server"]
        OrdersAPI["Orders API<br/>ASP.NET Core"]
        LogicApps["Logic App Workflows"]
    end
    
    subgraph AzureServices["Azure Platform Services"]
        EntraID["Microsoft Entra ID"]
        AzureMonitor["Azure Monitor"]
        SQLAzure["Azure SQL Database"]
        ServiceBus["Azure Service Bus"]
    end
    
    WebUser -->|"HTTPS"| WebApp
    DevOps -->|"azd provision/deploy"| AZD
    AZD -->|"Bicep Templates"| AzureLogicAppsMonitoring
    
    WebApp -->|"HTTP + Service Discovery"| OrdersAPI
    OrdersAPI -->|"EF Core + Entra Auth"| SQLAzure
    OrdersAPI -->|"Managed Identity"| ServiceBus
    LogicApps -->|"Subscribe"| ServiceBus
    
    WebApp -->|"OpenTelemetry"| AzureMonitor
    OrdersAPI -->|"OpenTelemetry"| AzureMonitor
    
    OrdersAPI -->|"Token Auth"| EntraID
    LogicApps -->|"Token Auth"| EntraID
```

### 4.2 Container Diagram

Runtime deployable units and their interactions.

```mermaid
flowchart TD
    subgraph ContainerAppsEnv["Azure Container Apps Environment"]
        subgraph WebAppContainer["web-app Container"]
            BlazorApp["Blazor Server App<br/>Port 443"]
            FluentUI["Fluent UI Components"]
            SignalR["SignalR Hub"]
            OrdersClient["OrdersAPIService<br/>Typed HTTP Client"]
        end
        
        subgraph OrdersAPIContainer["orders-api Container"]
            WebAPI["ASP.NET Core API<br/>Port 443"]
            Controllers["OrdersController"]
            Services["OrderService"]
            Repository["OrderRepository"]
            MsgHandler["OrdersMessageHandler"]
            HealthEndpoints["Health Endpoints<br/>/health, /alive"]
        end
        
        AspireDashboard["Aspire Dashboard<br/>Observability UI"]
    end
    
    subgraph LogicAppsRuntime["Logic Apps App Service Plan"]
        WorkflowEngine["Logic App Standard<br/>Workflow Engine"]
        ExtensionBundle["Azure Functions<br/>Extension Bundle"]
    end
    
    subgraph DataTier["Data Tier"]
        SQLDB["Azure SQL Database<br/>OrderDb"]
        SBNamespace["Service Bus Namespace"]
        SBTopic["ordersplaced Topic"]
        SBSub["orderprocessingsub"]
    end
    
    subgraph StorageTier["Storage Tier"]
        WorkflowStorage["Workflow Storage<br/>Azure Files"]
        BlobSuccess["Success Orders Blob"]
        BlobError["Error Orders Blob"]
    end
    
    BlazorApp --> OrdersClient
    OrdersClient -->|"HTTP/HTTPS"| WebAPI
    WebAPI --> Controllers
    Controllers --> Services
    Services --> Repository
    Services --> MsgHandler
    Repository -->|"EF Core"| SQLDB
    MsgHandler -->|"AMQP"| SBTopic
    
    SBTopic --> SBSub
    SBSub -->|"Trigger"| WorkflowEngine
    WorkflowEngine --> WorkflowStorage
    WorkflowEngine --> BlobSuccess
    WorkflowEngine --> BlobError
    
    WebAppContainer --> AspireDashboard
    OrdersAPIContainer --> AspireDashboard
```

### 4.3 Component Diagram - Orders API

Internal structure of the Orders API service.

```mermaid
flowchart TD
    subgraph OrdersAPIService["eShop.Orders.API Service"]
        subgraph Presentation["Presentation Layer"]
            OrdersController["OrdersController<br/>REST Endpoints"]
            WeatherController["WeatherForecastController<br/>Sample Endpoint"]
            SwaggerUI["Swagger/OpenAPI<br/>Documentation"]
        end
        
        subgraph Business["Business Logic Layer"]
            IOrderService["IOrderService<br/>Interface"]
            OrderService["OrderService<br/>Implementation"]
            ActivitySource["ActivitySource<br/>Distributed Tracing"]
            Metrics["Custom Metrics<br/>Counters, Histograms"]
        end
        
        subgraph Messaging["Messaging Layer"]
            IMessageHandler["IOrdersMessageHandler<br/>Interface"]
            MessageHandler["OrdersMessageHandler<br/>Service Bus Publisher"]
            NoOpHandler["NoOpOrdersMessageHandler<br/>Dev Fallback"]
        end
        
        subgraph DataAccess["Data Access Layer"]
            IOrderRepo["IOrderRepository<br/>Interface"]
            OrderRepo["OrderRepository<br/>EF Core Implementation"]
            DbContext["OrderDbContext<br/>Entity Framework"]
            OrderMapper["OrderMapper<br/>Entity Mapping"]
        end
        
        subgraph Health["Health & Monitoring"]
            DbHealthCheck["DbContextHealthCheck"]
            SBHealthCheck["ServiceBusHealthCheck"]
        end
        
        subgraph Entities["Domain Entities"]
            OrderEntity["OrderEntity"]
            ProductEntity["OrderProductEntity"]
        end
    end
    
    OrdersController --> IOrderService
    IOrderService --> OrderService
    OrderService --> IMessageHandler
    OrderService --> IOrderRepo
    IMessageHandler --> MessageHandler
    IMessageHandler --> NoOpHandler
    IOrderRepo --> OrderRepo
    OrderRepo --> DbContext
    DbContext --> OrderMapper
    OrderMapper --> OrderEntity
    OrderMapper --> ProductEntity
    
    OrderService --> ActivitySource
    OrderService --> Metrics
    
    DbHealthCheck --> DbContext
    SBHealthCheck --> MessageHandler
```

---

## 5. Key Scenarios

### 5.1 Order Creation Flow

Complete flow from user interaction through persistence and messaging.

```mermaid
flowchart TD
    subgraph UserInteraction["1. User Interaction"]
        User["Web User"]
        PlaceOrderPage["PlaceOrder.razor Page"]
    end
    
    subgraph FrontendProcessing["2. Frontend Processing"]
        OrdersAPIService["OrdersAPIService<br/>HTTP Client"]
        Validation["Client Validation"]
    end
    
    subgraph APIProcessing["3. API Processing"]
        Controller["OrdersController<br/>PlaceOrder Action"]
        Service["OrderService<br/>PlaceOrderAsync"]
        Tracing["Activity Tracing<br/>Start Span"]
    end
    
    subgraph DataPersistence["4. Data Persistence"]
        Repository["OrderRepository<br/>SaveOrderAsync"]
        EFCore["Entity Framework<br/>AddAsync + SaveChangesAsync"]
        SQLDatabase["Azure SQL<br/>Orders Table"]
    end
    
    subgraph EventPublishing["5. Event Publishing"]
        MessageHandler["OrdersMessageHandler<br/>SendOrderMessageAsync"]
        ServiceBusSender["ServiceBusSender"]
        Topic["ordersplaced Topic"]
    end
    
    subgraph Response["6. Response"]
        Created201["HTTP 201 Created"]
        SuccessUI["Success Message UI"]
    end
    
    User -->|"Fill Form"| PlaceOrderPage
    PlaceOrderPage --> Validation
    Validation --> OrdersAPIService
    OrdersAPIService -->|"POST /api/orders"| Controller
    Controller --> Tracing
    Tracing --> Service
    Service --> Repository
    Repository --> EFCore
    EFCore -->|"INSERT"| SQLDatabase
    SQLDatabase -->|"Success"| Service
    Service --> MessageHandler
    MessageHandler --> ServiceBusSender
    ServiceBusSender -->|"Send"| Topic
    Topic -->|"Success"| Service
    Service -->|"Return Order"| Controller
    Controller --> Created201
    Created201 --> OrdersAPIService
    OrdersAPIService --> SuccessUI
    SuccessUI --> User
```

### 5.2 Health Check Flow

Health monitoring and observability data flow.

```mermaid
flowchart TD
    subgraph HealthProbes["Health Probes"]
        ContainerApps["Container Apps<br/>Liveness/Readiness"]
        AspireDash["Aspire Dashboard"]
        AzureMonitor["Azure Monitor"]
    end
    
    subgraph HealthEndpoints["Health Endpoints"]
        HealthPath["/health Endpoint"]
        AlivePath["/alive Endpoint"]
    end
    
    subgraph HealthChecks["Health Check Implementations"]
        SelfCheck["Self Check<br/>Always Healthy"]
        DbCheck["DbContextHealthCheck<br/>CanConnectAsync"]
        SBCheck["ServiceBusHealthCheck<br/>CreateSender Test"]
    end
    
    subgraph Dependencies["Dependency Checks"]
        SQLConnection["SQL Database<br/>Connection Test"]
        SBConnection["Service Bus<br/>Connection Test"]
    end
    
    subgraph Results["Health Results"]
        Healthy["Healthy Response"]
        Degraded["Degraded Response"]
        Unhealthy["Unhealthy Response"]
    end
    
    ContainerApps -->|"HTTP GET"| HealthPath
    ContainerApps -->|"HTTP GET"| AlivePath
    AspireDash -->|"HTTP GET"| HealthPath
    AzureMonitor -->|"HTTP GET"| HealthPath
    
    HealthPath --> SelfCheck
    HealthPath --> DbCheck
    HealthPath --> SBCheck
    AlivePath --> SelfCheck
    
    DbCheck --> SQLConnection
    SBCheck --> SBConnection
    
    SQLConnection -->|"Success"| Healthy
    SQLConnection -->|"Failure"| Unhealthy
    SBConnection -->|"Success"| Healthy
    SBConnection -->|"Failure"| Degraded
```

### 5.3 Deployment Pipeline Flow

Azure Developer CLI deployment automation.

```mermaid
flowchart TD
    subgraph Developer["Developer Actions"]
        DevMachine["Developer Workstation"]
        AZDInit["azd init"]
        AZDProvision["azd provision"]
        AZDDeploy["azd deploy"]
    end
    
    subgraph PreProvision["Pre-Provisioning Hook"]
        CheckWorkstation["check-dev-workstation.ps1"]
        ValidatePrereqs["Validate Prerequisites<br/>Azure CLI, .NET, Docker"]
        PreprovisionScript["preprovision.ps1"]
    end
    
    subgraph Provisioning["Infrastructure Provisioning"]
        BicepDeploy["Deploy Bicep Templates"]
        MainBicep["infra/main.bicep"]
        SharedModule["shared/main.bicep<br/>Identity, Monitoring, Data"]
        WorkloadModule["workload/main.bicep<br/>Messaging, Services"]
    end
    
    subgraph PostProvision["Post-Provisioning Hook"]
        PostprovisionScript["postprovision.ps1"]
        ConfigureSecrets["Configure .NET User Secrets"]
        SQLIdentity["sql-managed-identity-config.ps1"]
        GenerateOrders["Generate-Orders.ps1"]
    end
    
    subgraph Deployment["Application Deployment"]
        BuildContainers["Build Container Images"]
        PushACR["Push to ACR"]
        DeployContainerApps["Deploy to Container Apps"]
    end
    
    DevMachine --> AZDInit
    AZDInit --> AZDProvision
    AZDProvision --> CheckWorkstation
    CheckWorkstation --> ValidatePrereqs
    ValidatePrereqs --> PreprovisionScript
    PreprovisionScript --> BicepDeploy
    BicepDeploy --> MainBicep
    MainBicep --> SharedModule
    MainBicep --> WorkloadModule
    WorkloadModule --> PostprovisionScript
    PostprovisionScript --> ConfigureSecrets
    ConfigureSecrets --> SQLIdentity
    SQLIdentity --> GenerateOrders
    
    GenerateOrders --> AZDDeploy
    AZDDeploy --> BuildContainers
    BuildContainers --> PushACR
    PushACR --> DeployContainerApps
```

---

## 6. Observability Strategy

### Telemetry Collection Approach

The solution implements **comprehensive observability** using OpenTelemetry as the instrumentation standard, configured in [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs).

#### Instrumentation Layers

| Layer | Instrumentation | Configuration |
|-------|-----------------|---------------|
| **HTTP Server** | ASP.NET Core | `AddAspNetCoreInstrumentation()` with request/response enrichment |
| **HTTP Client** | HttpClient | `AddHttpClientInstrumentation()` with exception recording |
| **Database** | SQL Client | `AddSqlClientInstrumentation()` with query recording |
| **Messaging** | Service Bus | Custom `ActivitySource` for message publish/receive |
| **Runtime** | .NET Runtime | `AddRuntimeInstrumentation()` for GC, thread pool metrics |

#### Custom Metrics

Defined in [src/eShop.Orders.API/Services/OrderService.cs](src/eShop.Orders.API/Services/OrderService.cs):

```
eShop.orders.placed          - Counter: Total orders successfully placed
eShop.orders.deleted         - Counter: Total orders deleted
eShop.orders.processing.duration - Histogram: Order processing time (ms)
eShop.orders.processing.errors   - Counter: Processing errors by type
```

### Distributed Tracing Implementation

Trace context propagation follows W3C Trace Context standard:

1. **HTTP Propagation**: Automatic via OpenTelemetry HTTP instrumentation
2. **Service Bus Propagation**: Manual via `ApplicationProperties` in [src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs](src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs):
   - `TraceId`, `SpanId`, `traceparent`, `tracestate` properties added to messages
3. **Activity Sources**: Named sources `eShop.Orders.API`, `eShop.Web.App`, `Azure.Messaging.ServiceBus`

### Log Aggregation

All logs flow to **Log Analytics Workspace** through two paths:

1. **Application Logs**: OpenTelemetry → Application Insights → Log Analytics
2. **Infrastructure Logs**: Diagnostic Settings → Log Analytics

Log enrichment includes:
- Trace correlation IDs
- Structured properties (OrderId, CustomerId, etc.)
- Request/response metadata

### Alerting Configuration

Health check endpoints enable Container Apps probes:

| Probe Type | Endpoint | Behavior |
|------------|----------|----------|
| Liveness | `/alive` | Returns 200 if process is running (tagged: `live`) |
| Readiness | `/health` | Returns 200 if all dependencies healthy (DB, Service Bus) |

---

## 7. Security & Identity Architecture

### Authentication/Authorization Model

The solution uses **Microsoft Entra ID** exclusively for authentication:

| Component | Authentication Method | Configuration |
|-----------|----------------------|---------------|
| Azure SQL | Entra-only (SQL auth disabled) | [infra/shared/data/main.bicep](infra/shared/data/main.bicep) - `azureADOnlyAuthentication: true` |
| Service Bus | Managed Identity | DefaultAzureCredential in [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs) |
| Container Registry | Managed Identity | ACR Pull/Push roles assigned |
| Storage Accounts | Managed Identity | Blob, File, Queue, Table Data Contributor roles |

### Managed Identity Usage

A single **User-Assigned Managed Identity** is provisioned in [infra/shared/identity/main.bicep](infra/shared/identity/main.bicep) with the following role assignments:

| Role | Purpose |
|------|---------|
| Storage Account Contributor | Manage storage resources |
| Storage Blob Data Contributor/Owner | Read/write blob data |
| Storage Table/Queue/File Data Contributor | Access table, queue, file data |
| Monitoring Metrics Publisher | Publish custom metrics |
| Monitoring Contributor | Manage monitoring resources |
| Application Insights Component Contributor | Configure App Insights |
| Azure Service Bus Data Owner/Sender/Receiver | Full Service Bus access |
| ACR Pull/Push | Pull and push container images |

### Network Security Considerations

Current configuration prioritizes **ease of development** with public access enabled:

- SQL Server: `publicNetworkAccess: 'Enabled'` with Azure Services firewall rule
- Storage Accounts: `publicNetworkAccess: 'Enabled'` with `defaultAction: 'Allow'`
- Service Bus: Public network access enabled
- Container Apps: External ingress enabled

<!-- NEEDS VERIFICATION: Production hardening should include Private Endpoints and VNet integration -->

### Secret Management Approach

**Zero secrets in code**: All sensitive values are managed through:

1. **Azure Key Vault Integration**: Connection strings retrieved at runtime via Managed Identity
2. **.NET User Secrets**: Local development secrets configured by [hooks/postprovision.ps1](hooks/postprovision.ps1)
3. **Environment Variables**: Injected by Container Apps from Aspire configuration

Post-provisioning configures local secrets via:
```powershell
dotnet user-secrets set "Azure:ResourceGroup" $env:AZURE_RESOURCE_GROUP
dotnet user-secrets set "Azure:SqlServer:Name" $env:AZURE_SQL_SERVER_NAME
# ... additional secrets
```

---

## 8. Deployment & Operations

### Infrastructure Topology

```mermaid
flowchart TD
    subgraph AZD["Azure Developer CLI"]
        AZDConfig["azure.yaml<br/>Project Configuration"]
        BicepEntry["infra/main.bicep<br/>Entry Point"]
    end
    
    subgraph SharedInfra["Shared Infrastructure Module"]
        Identity["identity/main.bicep<br/>Managed Identity + RBAC"]
        Monitoring["monitoring/main.bicep<br/>Log Analytics + App Insights"]
        Data["data/main.bicep<br/>SQL Server + Storage"]
    end
    
    subgraph WorkloadInfra["Workload Infrastructure Module"]
        Messaging["messaging/main.bicep<br/>Service Bus + Topics"]
        Services["services/main.bicep<br/>ACR + Container Apps Env"]
        LogicApps["logic-app.bicep<br/>Logic Apps Standard"]
    end
    
    subgraph DeployedResources["Deployed Azure Resources"]
        subgraph IdentityResources["Identity"]
            MI["User-Assigned MI"]
            RBAC["Role Assignments"]
        end
        
        subgraph MonitoringResources["Monitoring"]
            LAW["Log Analytics<br/>Workspace"]
            AI["Application<br/>Insights"]
            DiagSA["Diagnostics<br/>Storage"]
        end
        
        subgraph DataResources["Data"]
            SQL["Azure SQL<br/>Server + DB"]
            WorkflowSA["Workflow<br/>Storage"]
        end
        
        subgraph ComputeResources["Compute"]
            ACR["Container<br/>Registry"]
            CAE["Container Apps<br/>Environment"]
            LA["Logic Apps<br/>Standard"]
        end
        
        subgraph MessagingResources["Messaging"]
            SB["Service Bus<br/>Namespace"]
            Topic["ordersplaced<br/>Topic"]
        end
    end
    
    AZDConfig --> BicepEntry
    BicepEntry --> SharedInfra
    BicepEntry --> WorkloadInfra
    
    Identity --> MI
    Identity --> RBAC
    Monitoring --> LAW
    Monitoring --> AI
    Monitoring --> DiagSA
    Data --> SQL
    Data --> WorkflowSA
    
    Messaging --> SB
    Messaging --> Topic
    Services --> ACR
    Services --> CAE
    LogicApps --> LA
```

### Deployment Automation

The `azure.yaml` configuration orchestrates the full deployment lifecycle:

```yaml
hooks:
  preprovision:    # Validate prerequisites
  postprovision:   # Configure secrets, SQL identity, generate test data

services:
  app:
    host: containerapp
    project: ./app.AppHost/app.AppHost.csproj
```

### Operational Runbook

| Operation | Command | Description |
|-----------|---------|-------------|
| Initial Deploy | `azd up` | Full provision + deploy |
| Infrastructure Only | `azd provision` | Deploy Bicep without app |
| Application Only | `azd deploy` | Deploy containers to existing infra |
| Cleanup | `azd down` | Delete all resources |
| Local Development | `dotnet run --project app.AppHost` | Start with Aspire orchestration |

---

## Appendix: File Reference Index

| Category | Key Files |
|----------|-----------|
| **Orchestration** | [app.AppHost/AppHost.cs](app.AppHost/AppHost.cs), [azure.yaml](azure.yaml) |
| **Cross-Cutting** | [app.ServiceDefaults/Extensions.cs](app.ServiceDefaults/Extensions.cs), [app.ServiceDefaults/CommonTypes.cs](app.ServiceDefaults/CommonTypes.cs) |
| **API Implementation** | [src/eShop.Orders.API/Program.cs](src/eShop.Orders.API/Program.cs), [src/eShop.Orders.API/Controllers/OrdersController.cs](src/eShop.Orders.API/Controllers/OrdersController.cs) |
| **Frontend** | [src/eShop.Web.App/Program.cs](src/eShop.Web.App/Program.cs), [src/eShop.Web.App/Components/Services/OrdersAPIService.cs](src/eShop.Web.App/Components/Services/OrdersAPIService.cs) |
| **Infrastructure** | [infra/main.bicep](infra/main.bicep), [infra/shared/main.bicep](infra/shared/main.bicep), [infra/workload/main.bicep](infra/workload/main.bicep) |
| **Deployment Hooks** | [hooks/postprovision.ps1](hooks/postprovision.ps1), [hooks/sql-managed-identity-config.ps1](hooks/sql-managed-identity-config.ps1) |

---

*This document was generated based on analysis of workspace files as of December 30, 2025. All architectural claims are traceable to specific source files referenced throughout the document.*
