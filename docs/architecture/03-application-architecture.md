# Application Architecture

← [Data Architecture](02-data-architecture.md) | [Index](README.md) | [Technology Architecture →](04-technology-architecture.md)

---

## 1. Application Architecture Overview

The application follows an **event-driven microservices** pattern with clear service boundaries aligned to business capabilities. Services communicate through synchronous HTTP/REST for queries and asynchronous Service Bus messaging for commands/events.

### Architectural Style

- **Frontend:** Blazor Server with interactive server-side rendering
- **Backend:** ASP.NET Core Web API with Clean Architecture layers
- **Workflows:** Azure Logic Apps Standard with stateful workflows
- **Integration:** Event-driven via Azure Service Bus pub/sub

### Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Service Communication | HTTP for sync, Service Bus for async | Loose coupling for event-driven flows |
| Data Access | Entity Framework Core | Productivity, migration support |
| Resilience | Polly via ServiceDefaults | Retry, circuit breaker, timeout |
| Observability | OpenTelemetry + Azure Monitor | Vendor-neutral instrumentation |

---

## 2. Application Architecture Principles

| Principle | Statement | Rationale | Implications |
|-----------|-----------|-----------|--------------|
| **Single Responsibility** | Each service has one reason to change | Maintainability, testability | Clear bounded contexts |
| **API-First Design** | All capabilities exposed via APIs | Interoperability, reusability | OpenAPI specifications |
| **Loose Coupling** | Services communicate via events | Independent deployability | Service Bus for async flows |
| **High Cohesion** | Related functionality grouped | Understandability | Domain-aligned services |
| **Observability by Design** | All services instrumented | Operational excellence | OpenTelemetry built-in |

---

## 3. Application Landscape Map

```mermaid
flowchart TB
    subgraph Presentation["🖥️ Presentation Layer"]
        direction LR
        WebApp["🌐 eShop.Web.App<br/>Blazor Server + Fluent UI<br/>Port: 5002"]
    end

    subgraph Application["⚙️ Application Layer"]
        direction LR
        API["📡 eShop.Orders.API<br/>ASP.NET Core Web API<br/>Port: 5001"]
        Workflow["🔄 OrdersManagement<br/>Logic Apps Standard"]
    end

    subgraph Platform["🏗️ Platform Layer"]
        direction LR
        Orchestrator["🎯 app.AppHost<br/>.NET Aspire 9.x"]
        SharedLib["📦 app.ServiceDefaults<br/>Cross-cutting Concerns"]
    end

    subgraph External["☁️ External Services"]
        direction LR
        DB[("🗄️ OrderDb<br/>Azure SQL")]
        Queue["📨 Service Bus<br/>ordersplaced topic"]
        Monitor["📊 App Insights<br/>Telemetry Backend"]
    end

    %% Synchronous flows
    WebApp -->|"HTTP/REST"| API
    API -->|"EF Core/TDS"| DB
    API -->|"AMQP"| Queue

    %% Async/Event flows
    Queue -->|"Trigger"| Workflow

    %% Platform relationships
    Orchestrator -.->|"Orchestrates"| WebApp
    Orchestrator -.->|"Orchestrates"| API
    SharedLib -.->|"Configures"| WebApp
    SharedLib -.->|"Configures"| API

    %% Telemetry flows
    WebApp -.->|"OTLP"| Monitor
    API -.->|"OTLP"| Monitor
    Workflow -.->|"Diagnostics"| Monitor

    %% Styling
    classDef presentation fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef application fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef platform fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef external fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

    class WebApp presentation
    class API,Workflow application
    class Orchestrator,SharedLib platform
    class DB,Queue,Monitor external
```

---

## 4. Service Catalog

| Service | Type | Port | Dependencies | Health Endpoint | Status |
|---------|------|------|--------------|-----------------|--------|
| **eShop.Web.App** | Blazor Server | 5002 | Orders API | `/health`, `/alive` | Active |
| **eShop.Orders.API** | REST API | 5001 | SQL, Service Bus | `/health`, `/alive` | Active |
| **OrdersManagement** | Logic Apps Workflow | N/A | Service Bus, Storage | Azure Portal | Active |
| **app.AppHost** | Orchestrator | N/A | All services | N/A | Active |
| **app.ServiceDefaults** | Class Library | N/A | None | N/A | Active |

---

## 5. Service Details

### eShop.Orders.API

**Location:** [src/eShop.Orders.API/](../../src/eShop.Orders.API/)

**Responsibilities:**
- Order CRUD operations (Create, Read, Update, Delete)
- Order validation and business rules
- Service Bus message publishing for order events
- Database persistence via Entity Framework Core

#### API Endpoints

| Method | Route | Description | Request | Response |
|--------|-------|-------------|---------|----------|
| `POST` | `/api/orders` | Place a new order | `Order` JSON | `201` + `Order` |
| `POST` | `/api/orders/batch` | Place multiple orders | `Order[]` JSON | `200` + `Order[]` |
| `GET` | `/api/orders` | Get all orders | - | `200` + `Order[]` |
| `GET` | `/api/orders/{id}` | Get order by ID | - | `200` + `Order` |
| `DELETE` | `/api/orders/{id}` | Delete order | - | `204` |
| `DELETE` | `/api/orders` | Delete all orders | - | `204` |
| `GET` | `/health` | Health check | - | `200` |
| `GET` | `/alive` | Liveness check | - | `200` |

#### Component Diagram

```mermaid
flowchart TB
    subgraph API["eShop.Orders.API"]
        Controller["OrdersController<br/><i>API Layer</i>"]
        Service["OrderService<br/><i>Business Logic</i>"]
        Repository["OrderRepository<br/><i>Data Access</i>"]
        Handler["OrdersMessageHandler<br/><i>Messaging</i>"]
        HealthChecks["Health Checks<br/><i>DB + ServiceBus</i>"]
    end

    subgraph External["External Dependencies"]
        DB[("SQL Database")]
        SB["Service Bus"]
    end

    Controller --> Service
    Service --> Repository
    Service --> Handler
    Repository --> DB
    Handler --> SB

    classDef internal fill:#e8f5e9,stroke:#2e7d32
    classDef external fill:#f3e5f5,stroke:#7b1fa2

    class Controller,Service,Repository,Handler,HealthChecks internal
    class DB,SB external
```

#### Key Patterns Implemented

| Pattern | Implementation | Location |
|---------|----------------|----------|
| Repository | `IOrderRepository` / `OrderRepository` | [Repositories/](../../src/eShop.Orders.API/Repositories/) |
| Service Layer | `IOrderService` / `OrderService` | [Services/](../../src/eShop.Orders.API/Services/) |
| Dependency Injection | Constructor injection | [Program.cs](../../src/eShop.Orders.API/Program.cs) |
| Health Checks | `IHealthCheck` implementations | [HealthChecks/](../../src/eShop.Orders.API/HealthChecks/) |
| Distributed Tracing | `ActivitySource` spans | Throughout all classes |

---

### eShop.Web.App

**Location:** [src/eShop.Web.App/](../../src/eShop.Web.App/)

**Responsibilities:**
- Interactive order management dashboard
- Order placement and viewing
- Real-time UI updates via SignalR (Blazor Server)

#### UI Components Overview

| Component | Purpose | Location |
|-----------|---------|----------|
| `App.razor` | Root application component | [Components/App.razor](../../src/eShop.Web.App/Components/App.razor) |
| `MainLayout.razor` | Application shell layout | [Components/Layout/](../../src/eShop.Web.App/Components/Layout/) |
| `OrdersAPIService` | Typed HTTP client | [Components/Services/](../../src/eShop.Web.App/Components/Services/) |

#### Component Diagram

```mermaid
flowchart TB
    subgraph WebApp["eShop.Web.App"]
        Pages["Razor Pages<br/><i>UI Components</i>"]
        Layout["MainLayout<br/><i>Shell</i>"]
        APIService["OrdersAPIService<br/><i>HTTP Client</i>"]
    end

    subgraph External["External"]
        API["Orders API"]
    end

    Pages --> Layout
    Pages --> APIService
    APIService -->|"HTTP/REST"| API

    classDef internal fill:#e3f2fd,stroke:#1565c0
    classDef external fill:#e8f5e9,stroke:#2e7d32

    class Pages,Layout,APIService internal
    class API external
```

---

### OrdersManagement Logic App

**Location:** [workflows/OrdersManagement/](../../workflows/OrdersManagement/)

**Responsibilities:**
- Process order events from Service Bus
- Validate message content type
- Forward orders to API for processing
- Store results in Azure Blob Storage

#### Workflow Inventory

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| **ProcessingOrdersPlaced** | Service Bus Topic (ordersplaced) | Process incoming order messages |

#### Workflow Definition

From [workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/ProcessingOrdersPlaced/workflow.json):

```mermaid
flowchart TD
    Trigger["📨 Service Bus Trigger<br/><i>Poll every 1 second</i>"]
    
    Condition1{"Content-Type<br/>= application/json?"}
    
    HTTP["🌐 HTTP POST<br/>/api/Orders/process"]
    
    Condition2{"HTTP Status<br/>= 201?"}
    
    SuccessBlob["✅ Create Blob<br/>/ordersprocessedsuccessfully"]
    ErrorBlob1["❌ Create Blob<br/>/ordersprocessedwitherrors"]
    ErrorBlob2["❌ Create Blob<br/>/ordersprocessedwitherrors"]

    Trigger --> Condition1
    Condition1 -->|Yes| HTTP
    Condition1 -->|No| ErrorBlob2
    HTTP --> Condition2
    Condition2 -->|Yes| SuccessBlob
    Condition2 -->|No| ErrorBlob1

    classDef trigger fill:#e3f2fd,stroke:#1565c0
    classDef condition fill:#fff3e0,stroke:#ef6c00
    classDef success fill:#e8f5e9,stroke:#2e7d32
    classDef error fill:#ffebee,stroke:#c62828

    class Trigger trigger
    class Condition1,Condition2 condition
    class HTTP,SuccessBlob success
    class ErrorBlob1,ErrorBlob2 error
```

---

## 6. Inter-Service Communication

```mermaid
flowchart LR
    subgraph Sync["🔗 Synchronous (HTTP/REST)"]
        Web["Web App"] -->|"GET/POST"| API["Orders API"]
        API -->|"SELECT/INSERT"| DB["SQL Database"]
    end

    subgraph Async["📨 Asynchronous (Service Bus)"]
        API2["Orders API"] -->|"Publish"| Topic["ordersplaced topic"]
        Topic -->|"Subscribe"| Sub["orderprocessingsub"]
        Sub -->|"Trigger"| LA["Logic Apps"]
    end

    classDef sync fill:#e3f2fd,stroke:#1565c0
    classDef async fill:#e8f5e9,stroke:#2e7d32

    class Web,API,DB sync
    class API2,Topic,Sub,LA async
```

### Communication Patterns

| Pattern | Usage | Implementation | Example |
|---------|-------|----------------|---------|
| **Request/Response** | UI to API queries | HTTP REST | `GET /api/orders` |
| **Publish/Subscribe** | Order events | Service Bus Topic | `OrderPlaced` message |
| **Event-Driven** | Workflow triggers | Service Bus Subscription | Logic App activation |

### Service Discovery

| Environment | Mechanism | Configuration |
|-------------|-----------|---------------|
| **Local Development** | .NET Aspire service discovery | `WithReference()` in AppHost |
| **Azure Container Apps** | Internal DNS | `{service-name}.internal.{env}.azurecontainerapps.io` |

---

## 7. Application Integration Points

| Source | Target | Protocol | Contract | Pattern |
|--------|--------|----------|----------|---------|
| Web App | Orders API | HTTPS/REST | OpenAPI 3.0 | Sync Request/Response |
| Orders API | SQL Database | TDS | EF Core Model | Sync CRUD |
| Orders API | Service Bus | AMQP | JSON Message | Async Pub/Sub |
| Service Bus | Logic Apps | Connector | Service Bus Message | Event-Driven |
| All Services | App Insights | HTTPS/OTLP | OpenTelemetry | Continuous Push |

---

## 8. Resilience Patterns

Configured in [app.ServiceDefaults/Extensions.cs](../../app.ServiceDefaults/Extensions.cs):

| Pattern | Implementation | Configuration | Purpose |
|---------|----------------|---------------|---------|
| **Retry** | Polly | 3 attempts, exponential backoff | Transient failure recovery |
| **Circuit Breaker** | Polly | 120s sampling duration | Prevent cascading failures |
| **Timeout** | HttpClient | 60s per attempt, 600s total | Prevent hung requests |
| **Health Checks** | ASP.NET Core | `/health`, `/alive` | Container orchestration probes |

```csharp
// From Extensions.cs
http.AddStandardResilienceHandler(options =>
{
    options.TotalRequestTimeout.Timeout = TimeSpan.FromSeconds(600);
    options.AttemptTimeout.Timeout = TimeSpan.FromSeconds(60);
    options.Retry.MaxRetryAttempts = 3;
    options.Retry.BackoffType = Polly.DelayBackoffType.Exponential;
    options.CircuitBreaker.SamplingDuration = TimeSpan.FromSeconds(120);
});
```

---

## 9. Cross-Cutting Concerns

Provided by [app.ServiceDefaults](../../app.ServiceDefaults/):

| Concern | Implementation | Consumer Services |
|---------|----------------|-------------------|
| **Telemetry** | OpenTelemetry + Azure Monitor Exporter | All services |
| **Health Checks** | ASP.NET Core Health Checks | API, Web App |
| **Service Discovery** | .NET Aspire Service Discovery | All services |
| **HTTP Resilience** | Polly via `AddStandardResilienceHandler` | Web App (to API) |
| **Azure Service Bus Client** | `ServiceBusClient` with Managed Identity | Orders API |

---

## 10. Technology Stack Summary

| Layer | Technology | Version | Purpose |
|-------|------------|---------|---------|
| **Runtime** | .NET | 10.0 | Application runtime |
| **Web Framework** | ASP.NET Core | 10.0 | API and web hosting |
| **Frontend** | Blazor Server | 10.0 | Interactive UI |
| **UI Components** | Fluent UI Blazor | Latest | Design system |
| **ORM** | Entity Framework Core | 10.0 | Data access |
| **Messaging** | Azure.Messaging.ServiceBus | 7.20.1 | Event publishing |
| **Telemetry** | OpenTelemetry | 1.14.0 | Distributed tracing |
| **Orchestration** | .NET Aspire | 9.x | Local development |
| **Workflows** | Logic Apps Standard | Latest | Process automation |

---

## Cross-Architecture Relationships

| Related Architecture | Connection | Reference |
|---------------------|------------|-----------|
| **Business Architecture** | Services implement business capabilities | [Business Architecture](01-business-architecture.md#business-capabilities) |
| **Data Architecture** | Services own data stores per bounded context | [Data Architecture](02-data-architecture.md#data-domain-catalog) |
| **Technology Architecture** | Services deployed to infrastructure | [Technology Architecture](04-technology-architecture.md) |
| **Observability Architecture** | Services emit telemetry | [Observability Architecture](05-observability-architecture.md) |

---

## Related Documents

- [Data Architecture](02-data-architecture.md) - Data flow details
- [Technology Architecture](04-technology-architecture.md) - Infrastructure for services
- [ADR-001: Aspire Orchestration](adr/ADR-001-aspire-orchestration.md) - Why .NET Aspire
