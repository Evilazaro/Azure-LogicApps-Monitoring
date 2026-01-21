# Application Architecture

← [Data Architecture](02-data-architecture.md) | [Index](README.md) | [Technology Architecture →](04-technology-architecture.md)

---

## 1. Application Architecture Overview

The Azure Logic Apps Monitoring Solution follows an **event-driven, modular architecture** with clear service boundaries. Each service has a single responsibility, communicates via well-defined APIs or events, and can be deployed independently.

### Architectural Style

- **Event-Driven**: Asynchronous communication via Azure Service Bus
- **Modular Monolith** (per service): Clean Architecture layers within each service
- **API-First**: RESTful endpoints with OpenAPI documentation
- **Platform-Orchestrated**: .NET Aspire for local development and Azure deployment

### Key Design Decisions

| Decision                 | Rationale                                  | Trade-off             |
| ------------------------ | ------------------------------------------ | --------------------- |
| Blazor Server (not WASM) | Server-side rendering, SignalR real-time   | Server resource usage |
| Service Bus Topics       | Fan-out capability, subscription filtering | Additional complexity |
| Logic Apps Standard      | Azure-native, low-code automation          | Vendor lock-in        |
| EF Core with SQL         | Strong typing, migrations, LINQ            | ORM overhead          |

---

## 2. Application Architecture Principles

| Principle                   | Statement                             | Rationale                     | Implications                    |
| --------------------------- | ------------------------------------- | ----------------------------- | ------------------------------- |
| **Single Responsibility**   | Each service has one reason to change | Maintainability, testability  | Clear bounded contexts          |
| **API-First Design**        | All capabilities exposed via APIs     | Interoperability, reusability | OpenAPI specifications required |
| **Loose Coupling**          | Services communicate via events       | Independent deployability     | Service Bus for async           |
| **High Cohesion**           | Related functionality grouped         | Understandability             | Domain-aligned services         |
| **Observability by Design** | All services instrumented             | Operational excellence        | OpenTelemetry built-in          |

---

## 3. Application Landscape Map

```mermaid
flowchart TB
    subgraph Presentation["🖥️ Presentation Layer"]
        direction LR
        WebApp["🌐 eShop.Web.App<br/>Blazor Server<br/>:5002"]
    end

    subgraph Application["⚙️ Application Layer"]
        direction LR
        API["📡 eShop.Orders.API<br/>ASP.NET Core<br/>:5001"]
        Workflow["🔄 OrdersManagement<br/>Logic Apps Standard"]
    end

    subgraph Platform["🏗️ Platform Layer"]
        direction LR
        Orchestrator["🎯 app.AppHost<br/>.NET Aspire"]
        SharedLib["📦 app.ServiceDefaults<br/>Cross-cutting Concerns"]
    end

    subgraph External["☁️ External Services"]
        direction LR
        DB[("🗄️ Azure SQL<br/>OrderDb")]
        Queue["📨 Service Bus<br/>ordersplaced"]
        Monitor["📊 App Insights"]
        Storage["📁 Azure Storage"]
    end

    %% Synchronous flows
    WebApp -->|"HTTP/REST"| API
    API -->|"EF Core/TDS"| DB
    API -->|"AMQP"| Queue
    Workflow -->|"HTTP"| API

    %% Async/Event flows
    Queue -->|"Trigger"| Workflow
    Workflow --> Storage

    %% Platform relationships
    Orchestrator -.->|"Orchestrates"| WebApp
    Orchestrator -.->|"Orchestrates"| API
    SharedLib -.->|"Configures"| WebApp
    SharedLib -.->|"Configures"| API

    %% Telemetry flows
    WebApp -.->|"OTLP"| Monitor
    API -.->|"OTLP"| Monitor
    Workflow -.->|"Diagnostics"| Monitor

    classDef presentation fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef application fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef platform fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef external fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

    class WebApp presentation
    class API,Workflow application
    class Orchestrator,SharedLib platform
    class DB,Queue,Monitor,Storage external
```

### Application Inventory

| Application         | Layer        | Type         | Technology               | Owner         | Status |
| ------------------- | ------------ | ------------ | ------------------------ | ------------- | ------ |
| eShop.Web.App       | Presentation | Web UI       | Blazor Server, Fluent UI | Frontend Team | Active |
| eShop.Orders.API    | Application  | REST API     | ASP.NET Core 10, EF Core | Orders Team   | Active |
| OrdersManagement    | Application  | Workflow     | Logic Apps Standard      | Platform Team | Active |
| app.AppHost         | Platform     | Orchestrator | .NET Aspire 13.1         | Platform Team | Active |
| app.ServiceDefaults | Platform     | Library      | .NET Class Library       | Platform Team | Active |

### Application Relationship Matrix

| From         | To           | Relationship | Protocol    | Direction |
| ------------ | ------------ | ------------ | ----------- | --------- |
| Web App      | Orders API   | Consumes     | HTTP/REST   | Sync      |
| Orders API   | SQL Database | Persists     | TDS/EF Core | Sync      |
| Orders API   | Service Bus  | Publishes    | AMQP        | Async     |
| Service Bus  | Logic Apps   | Triggers     | Connector   | Async     |
| Logic Apps   | Orders API   | Calls        | HTTP/REST   | Sync      |
| Logic Apps   | Blob Storage | Writes       | REST        | Sync      |
| All Services | App Insights | Reports      | OTLP        | Push      |

---

## 4. Service Catalog

| Service              | Type          | Port | Dependencies              | Health Endpoint     |
| -------------------- | ------------- | ---- | ------------------------- | ------------------- |
| **eShop.Web.App**    | Blazor Server | 5002 | Orders API                | `/health`, `/alive` |
| **eShop.Orders.API** | REST API      | 5001 | SQL, Service Bus          | `/health`, `/alive` |
| **OrdersManagement** | Logic App     | N/A  | Service Bus, Storage, API | Azure Portal        |

---

## 5. Service Details

### eShop.Orders.API

**Responsibilities:**

- Order CRUD operations (create, read, update, delete)
- Order validation and business rules
- Batch order processing
- Event publishing to Service Bus
- Database persistence via EF Core

**Source:** [src/eShop.Orders.API/](../../src/eShop.Orders.API/)

#### API Endpoints

| Method | Route                 | Description               | Request      | Response      |
| ------ | --------------------- | ------------------------- | ------------ | ------------- |
| POST   | `/api/orders`         | Create single order       | Order JSON   | 201 + Order   |
| POST   | `/api/orders/batch`   | Create multiple orders    | Order[] JSON | 200 + Order[] |
| POST   | `/api/orders/process` | Process order (Logic App) | Order JSON   | 201 + Order   |
| GET    | `/api/orders`         | List all orders           | -            | 200 + Order[] |
| GET    | `/api/orders/{id}`    | Get order by ID           | -            | 200 + Order   |
| DELETE | `/api/orders/{id}`    | Delete order              | -            | 204           |

#### Component Diagram

```mermaid
flowchart TB
    subgraph API["eShop.Orders.API"]
        subgraph Controllers["Controllers"]
            OC["OrdersController"]
        end

        subgraph Services["Services"]
            OS["OrderService"]
        end

        subgraph Repositories["Repositories"]
            OR["OrderRepository"]
        end

        subgraph Handlers["Handlers"]
            MH["OrdersMessageHandler"]
            NoOp["NoOpOrdersMessageHandler"]
        end

        subgraph Data["Data"]
            DbCtx["OrderDbContext"]
        end

        subgraph HealthChecks["Health Checks"]
            DbHC["DbContextHealthCheck"]
            SbHC["ServiceBusHealthCheck"]
        end
    end

    OC --> OS
    OS --> OR
    OS --> MH
    OR --> DbCtx
    MH -->|"Service Bus"| External["📨 Service Bus"]
    DbCtx -->|"EF Core"| DB[("🗄️ SQL")]

    classDef controller fill:#e3f2fd,stroke:#1565c0
    classDef service fill:#e8f5e9,stroke:#2e7d32
    classDef data fill:#fff3e0,stroke:#ef6c00

    class OC controller
    class OS,MH,NoOp service
    class OR,DbCtx data
```

#### Key Patterns Implemented

| Pattern              | Implementation        | Purpose              |
| -------------------- | --------------------- | -------------------- |
| Repository           | `OrderRepository`     | Abstract data access |
| Dependency Injection | Constructor injection | Loose coupling       |
| Distributed Tracing  | `ActivitySource`      | Observability        |
| Health Checks        | Custom `IHealthCheck` | Readiness probes     |

---

### eShop.Web.App

**Responsibilities:**

- Order management user interface
- Real-time updates via SignalR
- Typed HTTP client for API communication
- Session management

**Source:** [src/eShop.Web.App/](../../src/eShop.Web.App/)

#### Component Diagram

```mermaid
flowchart TB
    subgraph WebApp["eShop.Web.App"]
        subgraph Components["Components"]
            App["App.razor"]
            Routes["Routes.razor"]
            Pages["Pages/"]
            Layout["Layout/"]
        end

        subgraph Services["Services"]
            APIService["OrdersAPIService"]
        end

        subgraph Shared["Shared"]
            Fluent["FluentDesignSystem"]
        end
    end

    Pages --> APIService
    APIService -->|"HTTP"| External["📡 Orders API"]
    App --> Routes --> Pages
    Pages --> Layout

    classDef component fill:#e3f2fd,stroke:#1565c0
    classDef service fill:#e8f5e9,stroke:#2e7d32

    class App,Routes,Pages,Layout component
    class APIService service
```

#### UI Components Overview

| Component    | Purpose                   | Location           |
| ------------ | ------------------------- | ------------------ |
| App.razor    | Application root          | Components/        |
| Routes.razor | Routing configuration     | Components/        |
| Layout/      | Page structure components | Components/Layout/ |
| Pages/       | Routable page components  | Components/Pages/  |

---

### Logic Apps Workflows

**Source:** [workflows/OrdersManagement/](../../workflows/OrdersManagement/)

#### Workflow Inventory

| Workflow                        | Trigger             | Purpose                       | Output               |
| ------------------------------- | ------------------- | ----------------------------- | -------------------- |
| **OrdersPlacedProcess**         | Service Bus message | Validate and process orders   | Blob (success/error) |
| **OrdersPlacedCompleteProcess** | Recurrence (3s)     | Cleanup processed order blobs | Deleted blobs        |

#### OrdersPlacedProcess Flow

```mermaid
flowchart TD
    A[📨 Service Bus Trigger] --> B{Content Type = JSON?}
    B -->|Yes| C[🌐 HTTP POST to API]
    B -->|No| D[⏭️ Skip Processing]

    C --> E{Status = 201?}
    E -->|Yes| F[✅ Store in Success Blob]
    E -->|No| G[⚠️ Store in Error Blob]

    F --> H[✔️ Complete]
    G --> H
    D --> H
```

#### Integration Points

| Integration  | Connector  | Authentication   |
| ------------ | ---------- | ---------------- |
| Service Bus  | Built-in   | Managed Identity |
| HTTP (API)   | Built-in   | None (internal)  |
| Blob Storage | Azure Blob | Managed Identity |

---

## 6. Inter-Service Communication

### Communication Patterns

```mermaid
flowchart LR
    subgraph Sync["🔄 Synchronous"]
        Web["Web App"]
        API["Orders API"]
        Web -->|"HTTP/REST"| API
    end

    subgraph Async["⚡ Asynchronous"]
        API2["Orders API"]
        SB["Service Bus"]
        LA["Logic Apps"]
        API2 -->|"Publish"| SB
        SB -->|"Subscribe"| LA
    end
```

| Pattern               | Usage                 | Implementation    | Example           |
| --------------------- | --------------------- | ----------------- | ----------------- |
| **Request/Response**  | UI to API calls       | HTTP REST         | GET /api/orders   |
| **Publish/Subscribe** | Event notification    | Service Bus Topic | OrderPlaced event |
| **Fire-and-Forget**   | Background processing | Service Bus Queue | Order processing  |

### Service Discovery

| Environment | Mechanism          | Configuration                |
| ----------- | ------------------ | ---------------------------- |
| **Local**   | .NET Aspire        | `WithReference()` in AppHost |
| **Azure**   | Container Apps DNS | Automatic service discovery  |

---

## 7. Application Integration Points

| Source      | Target       | Protocol  | Contract            | Pattern               |
| ----------- | ------------ | --------- | ------------------- | --------------------- |
| Web App     | Orders API   | HTTP/REST | OpenAPI 3.0         | Sync Request/Response |
| Orders API  | Service Bus  | AMQP      | JSON (Order schema) | Async Pub/Sub         |
| Service Bus | Logic Apps   | Connector | Service Bus Message | Event-driven          |
| Logic Apps  | Orders API   | HTTP/REST | OpenAPI 3.0         | Sync Request/Response |
| Logic Apps  | Blob Storage | REST      | Azure Blob API      | Fire-and-Forget       |

---

## 8. Resilience Patterns

From [app.ServiceDefaults/Extensions.cs](../../app.ServiceDefaults/Extensions.cs):

| Pattern             | Implementation | Configuration                   | Purpose                    |
| ------------------- | -------------- | ------------------------------- | -------------------------- |
| **Retry**           | Polly          | 3 attempts, exponential backoff | Transient failure recovery |
| **Circuit Breaker** | Polly          | 120s sampling duration          | Prevent cascading failures |
| **Timeout**         | HttpClient     | 60s per attempt, 600s total     | Prevent hung requests      |
| **Bulkhead**        | Service Bus    | Independent send timeout (30s)  | Isolate message delivery   |

### Resilience Configuration

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

The `app.ServiceDefaults` library provides shared functionality consumed by all services:

| Concern                | Implementation                       | Source                                                                            |
| ---------------------- | ------------------------------------ | --------------------------------------------------------------------------------- |
| **Telemetry**          | OpenTelemetry with Azure Monitor     | [Extensions.cs#ConfigureOpenTelemetry](../../app.ServiceDefaults/Extensions.cs)   |
| **Health Checks**      | ASP.NET Core Health Checks           | [Extensions.cs#AddDefaultHealthChecks](../../app.ServiceDefaults/Extensions.cs)   |
| **Resilience**         | Polly policies via HttpClientFactory | [Extensions.cs#AddServiceDefaults](../../app.ServiceDefaults/Extensions.cs)       |
| **Service Discovery**  | .NET Aspire service discovery        | [Extensions.cs#AddServiceDefaults](../../app.ServiceDefaults/Extensions.cs)       |
| **Service Bus Client** | Azure.Messaging.ServiceBus           | [Extensions.cs#AddAzureServiceBusClient](../../app.ServiceDefaults/Extensions.cs) |

---

## 10. Technology Stack Summary

| Layer         | Technology                 | Version | Purpose             |
| ------------- | -------------------------- | ------- | ------------------- |
| Runtime       | .NET                       | 10.0    | Application runtime |
| Web Framework | ASP.NET Core               | 10.0    | API and web hosting |
| Frontend      | Blazor Server              | 10.0    | Interactive UI      |
| UI Components | Fluent UI Blazor           | Latest  | Design system       |
| ORM           | Entity Framework Core      | 10.0    | Data access         |
| Messaging     | Azure.Messaging.ServiceBus | Latest  | Event publishing    |
| Telemetry     | OpenTelemetry              | Latest  | Observability       |
| Orchestration | .NET Aspire                | 13.1.0  | Local development   |
| Resilience    | Polly                      | Latest  | Fault tolerance     |

---

## 11. Cross-Architecture Relationships

| Related Architecture           | Connection                                   | Reference                                                                           |
| ------------------------------ | -------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Business Architecture**      | Services implement business capabilities     | [Business Capabilities](01-business-architecture.md#2-business-capabilities)        |
| **Data Architecture**          | Services own data stores per bounded context | [Data Domain Catalog](02-data-architecture.md#4-data-domain-catalog)                |
| **Technology Architecture**    | Services deployed to Azure infrastructure    | [Platform Services](04-technology-architecture.md#3-platform-services)              |
| **Observability Architecture** | Services emit telemetry via OpenTelemetry    | [Telemetry Architecture](05-observability-architecture.md#3-telemetry-architecture) |

---

_Last Updated: January 2026_
