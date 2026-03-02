# Application Architecture - Azure-LogicApps-Monitoring (eShop Orders Management)

**Generated**: 2025-07-22T00:00:00Z
**Session ID**: a1b2c3d4-e5f6-7890-abcd-ef1234567890
**Target Layer**: Application
**Quality Level**: Comprehensive
**Repository**: Azure-LogicApps-Monitoring
**Framework**: TOGAF 10 Application Architecture
**Components Found**: 31
**Average Confidence**: 0.85

---

## Section 1: Executive Summary

### Overview

The Azure-LogicApps-Monitoring repository implements a cloud-native **eShop Orders Management** platform built on .NET Aspire, following a distributed microservice architecture pattern. The system comprises two primary deployable applications — an ASP.NET Core Web API (`eShop.Orders.API`) for order management and a Blazor Server frontend (`eShop.Web.App`) — orchestrated through .NET Aspire (`app.AppHost`) with shared cross-cutting concerns in `app.ServiceDefaults`.

The Application layer analysis identified **31 components** across all **11 TOGAF Application Architecture component types**. The component distribution is: Application Services (2), Application Components (7), Application Interfaces (4), Application Collaborations (1), Application Functions (4), Application Interactions (1), Application Events (1), Application Data Objects (7), Integration Patterns (3), Service Contracts (1), and Application Dependencies (13). The average confidence score across all components is **0.85** (HIGH), indicating strong source traceability and pattern alignment.

The architecture demonstrates **Level 3 — Defined** maturity: all services expose OpenAPI specifications, distributed tracing is fully implemented via OpenTelemetry, structured logging with trace context correlation is present in every component, health check endpoints are configured for both liveness and readiness probes, and resilience patterns (circuit breakers, retry policies, exponential backoff) are consistently applied. Key areas for advancement to Level 4 include formalized SLO tracking, chaos engineering practices, and automated canary deployments.

---

## Section 2: Architecture Landscape

### Overview

This section catalogs all Application layer components identified through pattern-based scanning of the repository source code. Components are classified into the 11 TOGAF Application Architecture component types defined in the TOGAF 10 standard: Application Services, Application Components, Application Interfaces, Application Collaborations, Application Functions, Application Interactions, Application Events, Application Data Objects, Integration Patterns, Service Contracts, and Application Dependencies.

Each component includes its source traceability (file path and line range), confidence score (calculated using the weighted formula: 30% filename match + 25% path context + 35% content analysis + 10% cross-reference), and service type classification. Components with confidence scores below 0.50 are excluded from the catalog. All source references use plain text format matching the validation regex `^[a-zA-Z0-9_./-]+:(\d+-\d+|\*)$`.

The following subsections enumerate all 31 components discovered across the 11 component types, with the highest density in Application Data Objects (7 components) and Application Components (7 components), reflecting the domain-rich and modular architecture of the eShop Orders Management platform.

### 2.1 Application Services

| Name             | Description                                                                                                                  | Source                                                          | Confidence | Service Type        |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | ---------- | ------------------- |
| OrderService     | Core business logic orchestrating order persistence, validation, batch processing, metrics collection, and event publishing  | src/eShop.Orders.API/Services/OrderService.cs:1-606             | 0.95       | Application Service |
| OrdersAPIService | Typed HTTP client service providing strongly-typed API communication between the Web App frontend and the Orders API backend | src/eShop.Web.App/Components/Services/OrdersAPIService.cs:1-479 | 0.90       | HTTP Client Service |

### 2.2 Application Components

| Name                     | Description                                                                                                                                          | Source                                                         | Confidence | Service Type     |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------- | ---------- | ---------------- |
| eShop.Orders.API         | ASP.NET Core Web API application for order management with EF Core, Service Bus, and OpenTelemetry                                                   | src/eShop.Orders.API/Program.cs:1-226                          | 0.92       | Web API          |
| eShop.Web.App            | Blazor Server interactive frontend with Microsoft Fluent UI, session management, and SignalR                                                         | src/eShop.Web.App/Program.cs:1-109                             | 0.88       | Blazor Server    |
| OrderRepository          | EF Core data access layer implementing repository pattern with async operations, split queries, and pagination                                       | src/eShop.Orders.API/Repositories/OrderRepository.cs:1-549     | 0.90       | Data Access      |
| OrderDbContext           | Entity Framework Core database context with Fluent API configuration, indexes, and cascade delete rules                                              | src/eShop.Orders.API/data/OrderDbContext.cs:1-136              | 0.85       | Data Context     |
| ServiceDefaults          | Shared cross-cutting concerns providing OpenTelemetry, health checks, service discovery, HTTP resilience, and Azure Service Bus client configuration | app.ServiceDefaults/Extensions.cs:1-347                        | 0.82       | Shared Library   |
| NoOpOrdersMessageHandler | Development fallback implementation of IOrdersMessageHandler that logs intended operations without connecting to Service Bus                         | src/eShop.Orders.API/Handlers/NoOpOrdersMessageHandler.cs:1-65 | 0.75       | Development Stub |
| FluentDesignSystem       | Centralized Fluent UI design tokens providing spacing scales, typography, font weights, layout constraints, and grid templates                       | src/eShop.Web.App/Shared/FluentDesignSystem.cs:1-103           | 0.75       | UI Configuration |

### 2.3 Application Interfaces

| Name                  | Description                                                                                                         | Source                                                        | Confidence | Service Type        |
| --------------------- | ------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- | ---------- | ------------------- |
| OrdersController      | RESTful API controller exposing CRUD endpoints for order management with distributed tracing and structured logging | src/eShop.Orders.API/Controllers/OrdersController.cs:1-501    | 0.95       | REST API Controller |
| IOrderService         | Service contract defining 7 order management operations including batch processing and messaging                    | src/eShop.Orders.API/Interfaces/IOrderService.cs:1-68         | 0.92       | Service Contract    |
| IOrderRepository      | Repository contract defining 6 data access operations with async patterns and pagination                            | src/eShop.Orders.API/Interfaces/IOrderRepository.cs:1-69      | 0.90       | Repository Contract |
| IOrdersMessageHandler | Messaging contract defining 3 message publishing operations for Service Bus integration                             | src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs:1-40 | 0.88       | Messaging Contract  |

### 2.4 Application Collaborations

| Name                  | Description                                                                                                                                                                   | Source                       | Confidence | Service Type |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------- | ---------- | ------------ |
| AppHost (.NET Aspire) | Distributed application orchestrator configuring service dependencies, Azure credentials, Application Insights, SQL Azure, and Service Bus with local/cloud dual-mode support | app.AppHost/AppHost.cs:1-290 | 0.88       | Orchestrator |

### 2.5 Application Functions

| Name                   | Description                                                                                                                                       | Source                                                           | Confidence | Service Type        |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ---------- | ------------------- |
| DbContextHealthCheck   | Database connectivity health monitoring returning Healthy/Unhealthy/Degraded status with response time metrics                                    | src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs:1-102  | 0.85       | Health Check        |
| ServiceBusHealthCheck  | Azure Service Bus connectivity monitoring with sender and batch creation verification                                                             | src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs:1-183 | 0.88       | Health Check        |
| OrderMapper            | Bidirectional mapping between domain models (Order/OrderProduct) and persistence entities (OrderEntity/OrderProductEntity)                        | src/eShop.Orders.API/data/OrderMapper.cs:1-102                   | 0.80       | Data Mapper         |
| ConfigureOpenTelemetry | OpenTelemetry configuration function setting up distributed tracing, custom metrics, and structured logging with OTLP and Azure Monitor exporters | app.ServiceDefaults/Extensions.cs:44-163                         | 0.78       | Observability Setup |

### 2.6 Application Interactions

| Name                          | Description                                                                                                                    | Source                             | Confidence | Service Type     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------- | ---------- | ---------------- |
| Web-to-API HTTP Communication | Service discovery-based HTTP communication between Blazor frontend and Orders API using typed HttpClient with Polly resilience | src/eShop.Web.App/Program.cs:80-92 | 0.82       | Request/Response |

### 2.7 Application Events

| Name              | Description                                                                                                                              | Source                                                      | Confidence | Service Type |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------- | ---------- | ------------ |
| OrderPlaced Event | Domain event published to Azure Service Bus `ordersplaced` topic when orders are created, with trace context propagation and retry logic | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425 | 0.90       | Domain Event |

### 2.8 Application Data Objects

| Name                     | Description                                                                                                                    | Source                                                         | Confidence | Service Type       |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------- | ---------- | ------------------ |
| Order                    | Shared domain record with Id, CustomerId, Date, DeliveryAddress, Total, and Products collection with DataAnnotation validation | app.ServiceDefaults/CommonTypes.cs:77-127                      | 0.92       | Domain Model       |
| OrderProduct             | Shared domain record representing a product line item within an order with validation attributes                               | app.ServiceDefaults/CommonTypes.cs:132-175                     | 0.90       | Domain Model       |
| OrderEntity              | EF Core persistence entity mapping to the Orders table with key, required, and max-length constraints                          | src/eShop.Orders.API/data/Entities/OrderEntity.cs:1-56         | 0.88       | Persistence Entity |
| OrderProductEntity       | EF Core persistence entity mapping to the OrderProducts table with foreign key to OrderEntity                                  | src/eShop.Orders.API/data/Entities/OrderProductEntity.cs:1-65  | 0.88       | Persistence Entity |
| OrderMessageWithMetadata | Service Bus message wrapper containing Order payload with MessageId, SequenceNumber, EnqueuedTime, and ApplicationProperties   | src/eShop.Orders.API/Handlers/OrderMessageWithMetadata.cs:1-49 | 0.82       | Message DTO        |
| OrdersWrapper            | Response wrapper encapsulating a collection of Order objects for API responses                                                 | src/eShop.Orders.API/Services/OrdersWrapper.cs:1-21            | 0.75       | Response DTO       |
| WeatherForecast          | Demo data model with Date, TemperatureC, TemperatureF, and Summary properties used for health verification                     | app.ServiceDefaults/CommonTypes.cs:14-72                       | 0.72       | Demo Model         |

### 2.9 Integration Patterns

| Name                                  | Description                                                                                                                                            | Source                                                                                              | Confidence | Service Type         |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------- | ---------- | -------------------- |
| Azure Service Bus Pub/Sub             | Topic-based publish/subscribe messaging pattern using `ordersplaced` topic with `orderprocessingsub` subscription for decoupled order event processing | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425                                         | 0.92       | Pub/Sub              |
| Logic App OrdersPlacedProcess         | Stateful Logic App workflow triggered by Service Bus messages that processes orders via HTTP callback and stores results in Azure Blob Storage         | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-163         | 0.85       | Workflow Integration |
| Logic App OrdersPlacedCompleteProcess | Recurrence-triggered cleanup workflow that lists and deletes processed order blobs from Azure Blob Storage on a 3-second interval                      | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-105 | 0.80       | Workflow Integration |

### 2.10 Service Contracts

| Name                     | Description                                                                                                                    | Source                                                     | Confidence | Service Type |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------- | ---------- | ------------ |
| Orders REST API Contract | OpenAPI/Swagger-documented REST API with typed request/response models, HTTP status codes, and ProducesResponseType attributes | src/eShop.Orders.API/Controllers/OrdersController.cs:1-501 | 0.88       | OpenAPI      |

### 2.11 Application Dependencies

| Name                                         | Description                                                                                 | Source                                            | Confidence | Service Type  |
| -------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------- | ---------- | ------------- |
| Microsoft.EntityFrameworkCore.SqlServer      | EF Core SQL Server provider for database persistence with retry-on-failure resilience       | src/eShop.Orders.API/eShop.Orders.API.csproj:17   | 0.95       | NuGet Package |
| Azure.Messaging.ServiceBus                   | Azure Service Bus SDK for topic-based pub/sub messaging with managed identity support       | app.ServiceDefaults/app.ServiceDefaults.csproj:13 | 0.95       | NuGet Package |
| Azure.Identity                               | Azure credential management with DefaultAzureCredential for managed identity authentication | app.ServiceDefaults/app.ServiceDefaults.csproj:12 | 0.92       | NuGet Package |
| Azure.Monitor.OpenTelemetry.Exporter         | Azure Monitor exporter for distributed tracing and metrics                                  | app.ServiceDefaults/app.ServiceDefaults.csproj:15 | 0.90       | NuGet Package |
| OpenTelemetry.Exporter.OpenTelemetryProtocol | OTLP exporter for OpenTelemetry traces, metrics, and logs                                   | app.ServiceDefaults/app.ServiceDefaults.csproj:17 | 0.90       | NuGet Package |
| OpenTelemetry.Extensions.Hosting             | OpenTelemetry hosting integration for dependency injection                                  | app.ServiceDefaults/app.ServiceDefaults.csproj:18 | 0.88       | NuGet Package |
| OpenTelemetry.Instrumentation.AspNetCore     | ASP.NET Core auto-instrumentation for HTTP request tracing                                  | app.ServiceDefaults/app.ServiceDefaults.csproj:19 | 0.88       | NuGet Package |
| OpenTelemetry.Instrumentation.Http           | HTTP client auto-instrumentation for outbound request tracing                               | app.ServiceDefaults/app.ServiceDefaults.csproj:20 | 0.88       | NuGet Package |
| OpenTelemetry.Instrumentation.Runtime        | .NET runtime instrumentation for GC, thread pool, and exception metrics                     | app.ServiceDefaults/app.ServiceDefaults.csproj:21 | 0.85       | NuGet Package |
| OpenTelemetry.Instrumentation.SqlClient      | SQL client auto-instrumentation for database query tracing                                  | app.ServiceDefaults/app.ServiceDefaults.csproj:22 | 0.85       | NuGet Package |
| Microsoft.Extensions.Http.Resilience         | Polly-based HTTP resilience with circuit breakers, retries, and timeouts                    | app.ServiceDefaults/app.ServiceDefaults.csproj:16 | 0.90       | NuGet Package |
| Microsoft.Extensions.ServiceDiscovery        | .NET Aspire service discovery for service-to-service endpoint resolution                    | app.ServiceDefaults/app.ServiceDefaults.csproj:17 | 0.88       | NuGet Package |
| Microsoft.FluentUI.AspNetCore.Components     | Microsoft Fluent UI component library for Blazor Server interactive rendering               | src/eShop.Web.App/eShop.Web.App.csproj:11         | 0.92       | NuGet Package |

### Summary

The Architecture Landscape reveals a well-structured distributed application with clear separation of concerns. The Orders API concentrates business logic, data access, and messaging concerns, while the Web App provides a Fluent UI-based presentation layer. Cross-cutting concerns (observability, resilience, service discovery) are centralized in the ServiceDefaults shared project. Integration with Azure Logic Apps provides serverless workflow processing for order events, demonstrating an event-driven architecture pattern extending beyond the core .NET application boundary.

All 11 TOGAF Application component types are represented, with the highest component density in Application Data Objects (7) and Application Components (7), reflecting the domain-rich and modular nature of the solution.

---

## Section 3: Architecture Principles

### Overview

The following architecture principles were identified through systematic analysis of the source code, configuration files, and infrastructure definitions. Each principle is substantiated with specific source evidence, including file paths, line ranges, and compliance assessment. Principles are evaluated against observed implementation patterns rather than documented aspirational goals.

The eShop Orders Management platform demonstrates strong adherence to modern cloud-native architecture principles including separation of concerns, interface-driven design, resilience by design, and observability-first instrumentation. Seven core principles were identified, all showing Full or Partial compliance based on source code analysis.

These principles collectively establish a Level 3 (Defined) maturity baseline with clear pathways to Level 4 (Measured) through formalized SLO tracking, chaos engineering adoption, and event schema contract governance.

### 3.1 Separation of Concerns

| Attribute      | Value                                                                          |
| -------------- | ------------------------------------------------------------------------------ |
| **Principle**  | Separation of Concerns                                                         |
| **Evidence**   | Distinct interface/service/repository/handler layers with DI-based composition |
| **Source**     | src/eShop.Orders.API/Program.cs:50-85                                          |
| **Compliance** | Full                                                                           |

The application enforces clear layer boundaries: Controllers handle HTTP concerns only, Services orchestrate business logic, Repositories manage data persistence, and Handlers manage messaging — connected through interface contracts with constructor-injected dependencies.

### 3.2 Interface-Driven Design

| Attribute      | Value                                                                                |
| -------------- | ------------------------------------------------------------------------------------ |
| **Principle**  | Interface-Driven Design (Dependency Inversion)                                       |
| **Evidence**   | All service, repository, and handler components implement formal interface contracts |
| **Source**     | src/eShop.Orders.API/Interfaces/IOrderService.cs:1-68                                |
| **Compliance** | Full                                                                                 |

Every service implementation is registered against its interface: `IOrderService` → `OrderService`, `IOrderRepository` → `OrderRepository`, `IOrdersMessageHandler` → `OrdersMessageHandler`/`NoOpOrdersMessageHandler`. This enables testability, mock injection, and runtime substitution (as demonstrated by the NoOp fallback handler for environments without Service Bus).

### 3.3 Resilience by Design

| Attribute      | Value                                                                                                                    |
| -------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Principle**  | Resilience by Design                                                                                                     |
| **Evidence**   | Retry policies, circuit breakers, exponential backoff, timeout handling, and health checks across all integration points |
| **Source**     | app.ServiceDefaults/Extensions.cs:1-347                                                                                  |
| **Compliance** | Full                                                                                                                     |

Resilience is implemented at multiple levels: HTTP client resilience via Polly (600s total timeout, 60s per-attempt timeout, 3 retries with exponential backoff, 120s circuit breaker sampling), EF Core retry-on-failure (5 retries, 30s max delay, 120s command timeout), Service Bus retry (3 attempts, exponential backoff), and database migration retry (10 attempts). Health checks monitor both database and Service Bus connectivity with 5-second timeouts.

### 3.4 Observability First

| Attribute      | Value                                                                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Principle**  | Observability First (Distributed Tracing, Metrics, Logging)                                                                                           |
| **Evidence**   | OpenTelemetry integration with ActivitySource tracing, custom Meter metrics, and structured logging with trace context correlation in every component |
| **Source**     | app.ServiceDefaults/Extensions.cs:44-163                                                                                                              |
| **Compliance** | Full                                                                                                                                                  |

Every business operation creates a distributed tracing span via `ActivitySource.StartActivity()`. Custom metrics are defined with `Meter` (counters for orders.placed, processing.errors, orders.deleted; histogram for processing.duration). All log entries include `TraceId` correlation via `ILogger.BeginScope()`. Exporters target both OTLP and Azure Monitor for dual observability.

### 3.5 Dual-Mode Configuration (Local/Cloud)

| Attribute      | Value                                                                                                                                                 |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Principle**  | Environment Portability (Local Development / Azure Cloud)                                                                                             |
| **Evidence**   | .NET Aspire AppHost dynamically configures SQL Server containers or Azure SQL, Service Bus emulator or Azure Service Bus, based on configuration keys |
| **Source**     | app.AppHost/AppHost.cs:1-290                                                                                                                          |
| **Compliance** | Full                                                                                                                                                  |

The AppHost implements a dual-mode strategy: when `Azure:ResourceGroup` is configured, it connects to existing Azure resources (SQL Azure with Entra ID, Service Bus with managed identity, Application Insights); otherwise, it provisions local containers (SQL Server with data volumes, Service Bus emulator). This ensures developer experience parity with production-like infrastructure.

### 3.6 API-First Design

| Attribute      | Value                                                                                                                    |
| -------------- | ------------------------------------------------------------------------------------------------------------------------ |
| **Principle**  | API-First Design with OpenAPI Documentation                                                                              |
| **Evidence**   | Swagger/OpenAPI documentation enabled, typed response attributes on all controller actions, XML documentation generation |
| **Source**     | src/eShop.Orders.API/Program.cs:140-160                                                                                  |
| **Compliance** | Full                                                                                                                     |

The Orders API enables Swagger UI and OpenAPI specification generation. All controller actions are decorated with `[ProducesResponseType]` attributes specifying HTTP status codes and response types. XML documentation is generated from code comments (`GenerateDocumentationFile` in .csproj).

### 3.7 Event-Driven Architecture

| Attribute      | Value                                                                                                            |
| -------------- | ---------------------------------------------------------------------------------------------------------------- |
| **Principle**  | Event-Driven Decoupling via Publish/Subscribe                                                                    |
| **Evidence**   | Order creation events are published to Azure Service Bus topics for downstream processing by Logic App workflows |
| **Source**     | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425                                                      |
| **Compliance** | Partial                                                                                                          |

Order placement triggers asynchronous event publication to the `ordersplaced` Service Bus topic. Downstream Logic App workflows subscribe through `orderprocessingsub` subscription for order processing and blob storage. The pattern is partial because event consumption is handled by Logic Apps outside the .NET application boundary, and no formal event schema versioning contract exists.

---

## Section 4: Current State Baseline

### Overview

The current deployment architecture is a .NET Aspire-orchestrated distributed application targeting .NET 10.0 with Azure PaaS services. The system supports dual-mode operation: local development with containerized services (SQL Server container, Service Bus emulator) and Azure cloud deployment with managed services (Azure SQL, Azure Service Bus, Application Insights).

The production topology comprises six primary service endpoints: two .NET applications (Orders API, Web App), one Azure Logic App Standard instance with two stateful workflows, and three Azure PaaS backing services (Azure SQL, Azure Service Bus, Azure Blob Storage). All services are instrumented with OpenTelemetry for distributed tracing and metrics export to Application Insights.

Health monitoring is implemented at the application level with liveness (/alive) and readiness (/health) probes, aggregating database and Service Bus connectivity checks with 5-second timeouts. The following tables detail the service topology, protocol inventory, versioning status, and health posture of the current state baseline.

### Service Topology

| Service                    | Deployment Target                  | Protocol               | Status | Health Endpoint       |
| -------------------------- | ---------------------------------- | ---------------------- | ------ | --------------------- |
| eShop.Orders.API           | Azure Container Apps / Local       | HTTP/REST              | Active | /health, /alive       |
| eShop.Web.App              | Azure Container Apps / Local       | HTTP/SignalR           | Active | /health, /alive       |
| OrdersManagement Logic App | Azure Logic Apps Standard          | HTTP/Service Bus/Blob  | Active | Platform-managed      |
| Azure SQL Database         | Azure SQL / Local SQL Container    | TDS (SQL)              | Active | DbContextHealthCheck  |
| Azure Service Bus          | Azure Service Bus / Local Emulator | AMQP WebSockets        | Active | ServiceBusHealthCheck |
| Azure Application Insights | Azure Monitor                      | OTLP/Azure Monitor SDK | Active | Platform-managed      |
| Azure Blob Storage         | Azure Storage Account              | REST                   | Active | Platform-managed      |

### Protocol Inventory

| Protocol            | Usage                                                               | Components                                              |
| ------------------- | ------------------------------------------------------------------- | ------------------------------------------------------- |
| HTTP/REST           | API communication, service-to-service calls, Logic App HTTP actions | OrdersController, OrdersAPIService, Logic App workflows |
| AMQP WebSockets     | Service Bus messaging                                               | OrdersMessageHandler, Logic App triggers                |
| TDS (SQL)           | Database connectivity                                               | OrderRepository via EF Core                             |
| SignalR (WebSocket) | Blazor Server interactive rendering                                 | eShop.Web.App                                           |
| OTLP (gRPC/HTTP)    | OpenTelemetry trace/metric export                                   | ServiceDefaults                                         |

### Versioning Status

| Component             | Framework                  | Version   | SDK                                                 |
| --------------------- | -------------------------- | --------- | --------------------------------------------------- |
| .NET Runtime          | .NET                       | 10.0      | Microsoft.NET.Sdk.Web                               |
| Entity Framework Core | EF Core SQL Server         | 10.0.3    | Microsoft.EntityFrameworkCore.SqlServer             |
| Azure Service Bus SDK | Azure.Messaging.ServiceBus | 7.20.1    | Azure.Messaging.ServiceBus                          |
| Azure Identity        | Azure.Identity             | 1.18.0    | Azure.Identity                                      |
| OpenTelemetry         | OpenTelemetry              | 1.15.0    | OpenTelemetry.Extensions.Hosting                    |
| Fluent UI Blazor      | Microsoft.FluentUI         | 4.14.0    | Microsoft.FluentUI.AspNetCore.Components            |
| Logic Apps Extension  | Workflows Bundle           | 1.x-2.0.0 | Microsoft.Azure.Functions.ExtensionBundle.Workflows |

### Health Posture

| Check       | Type      | Timeout | Endpoint | Status Codes               |
| ----------- | --------- | ------- | -------- | -------------------------- |
| Self        | Liveness  | Instant | /alive   | Healthy                    |
| Database    | Readiness | 5s      | /health  | Healthy/Unhealthy/Degraded |
| Service Bus | Readiness | 5s      | /health  | Healthy/Unhealthy          |

### Architecture Diagram — Current State Baseline

```mermaid
---
title: "eShop Orders Management — Current State Architecture"
config:
  theme: base
  look: classic
  layout: dagre
  themeVariables:
    fontSize: "16px"
---
flowchart TB
    accTitle: eShop Orders Management Current State Architecture
    accDescr: Shows the current deployment topology with Web App, Orders API, Azure SQL, Service Bus, Logic Apps, and Blob Storage

    %% ═══════════════════════════════════════════════════════════════════════════
    %% AZURE / FLUENT ARCHITECTURE PATTERN v1.1
    %% (Semantic + Structural + Font + Accessibility Governance)
    %% ═══════════════════════════════════════════════════════════════════════════
    %% PHASE 1 - STRUCTURAL: Direction explicit, flat topology, nesting ≤ 3
    %% PHASE 2 - SEMANTIC: Colors justified, max 5 semantic classes, neutral-first
    %% PHASE 3 - FONT: Dark text on light backgrounds, contrast ≥ 4.5:1
    %% PHASE 4 - ACCESSIBILITY: accTitle/accDescr present, icons on all nodes
    %% PHASE 5 - STANDARD: Governance block present, classDefs centralized
    %% ═══════════════════════════════════════════════════════════════════════════

    subgraph UserLayer["User Layer"]
        User["👤 User"]
    end

    subgraph FrontendLayer["Frontend Layer"]
        WebApp["🌐 eShop.Web.App\n(Blazor Server)"]
    end

    subgraph APILayer["API Layer"]
        OrdersAPI["⚙️ eShop.Orders.API\n(ASP.NET Core Web API)"]
    end

    subgraph DataLayer["Data Layer"]
        SQLAzure["🗄️ Azure SQL Database\n(OrderDb)"]
    end

    subgraph MessagingLayer["Messaging Layer"]
        ServiceBus["📨 Azure Service Bus\n(ordersplaced topic)"]
    end

    subgraph WorkflowLayer["Workflow Layer"]
        LogicApp1["🔄 OrdersPlacedProcess\n(Logic App)"]
        LogicApp2["🧹 OrdersPlacedCompleteProcess\n(Logic App)"]
    end

    subgraph StorageLayer["Storage Layer"]
        BlobStorage["📦 Azure Blob Storage\n(processed orders)"]
    end

    subgraph ObservabilityLayer["Observability Layer"]
        AppInsights["📊 Application Insights\n(OpenTelemetry)"]
    end

    User -->|"HTTPS"| WebApp
    WebApp -->|"HTTP/REST\n(Service Discovery)"| OrdersAPI
    OrdersAPI -->|"EF Core\n(TDS)"| SQLAzure
    OrdersAPI -->|"AMQP\n(Publish)"| ServiceBus
    ServiceBus -->|"Trigger\n(Subscribe)"| LogicApp1
    LogicApp1 -->|"HTTP POST\n(Callback)"| OrdersAPI
    LogicApp1 -->|"REST\n(Write)"| BlobStorage
    LogicApp2 -->|"REST\n(Read/Delete)"| BlobStorage
    OrdersAPI -.->|"OTLP"| AppInsights
    WebApp -.->|"OTLP"| AppInsights

    style UserLayer fill:#f0f0f0,stroke:#666,color:#333
    style FrontendLayer fill:#e1f0ff,stroke:#0078d4,color:#333
    style APILayer fill:#e6f4ea,stroke:#107c10,color:#333
    style DataLayer fill:#fff4e0,stroke:#ffb900,color:#333
    style MessagingLayer fill:#fde7ef,stroke:#e3008c,color:#333
    style WorkflowLayer fill:#f3e8ff,stroke:#8661c5,color:#333
    style StorageLayer fill:#fff0e0,stroke:#ff8c00,color:#333
    style ObservabilityLayer fill:#f0f0f0,stroke:#666,color:#333
```

### Summary

The current state baseline reveals a well-architected distributed system with clear service boundaries, comprehensive observability, and production-ready resilience patterns. All critical integration points (database, Service Bus) are monitored via health checks. The dual-mode configuration (local containers vs. Azure PaaS) ensures developer productivity without compromising production fidelity.

The primary architectural gap is the absence of formalized SLO tracking and a centralized API gateway. The Logic App integration layer operates independently from the .NET Aspire orchestration, creating a bridged architecture pattern where event-driven workflows extend beyond the primary application boundary.

---

## Section 5: Component Catalog

### Overview

This section provides detailed specifications for each of the 31 Application layer components identified in Section 2, organized by the 11 TOGAF Application Architecture component types. Each subsection begins with a consolidated 10-column catalog table followed by expanded per-component specifications.

Each component specification includes six mandatory attributes: API Surface (endpoint types, counts, and protocols), Dependencies (upstream and downstream with protocols), Resilience (retry policies, circuit breakers, timeouts), Scaling (horizontal/vertical strategy), Health (monitoring approach and endpoints), and Source File (with confidence score and line ranges). Components classified as PaaS services include additional platform-specific attributes.

The Component Catalog complements Section 2 (Architecture Landscape) by providing implementation-level detail rather than inventory-level summaries. Where Section 2 answers "what components exist," Section 5 answers "how each component works, what it depends on, and how it handles failure."

### 5.1 Application Services

| Component        | Description                             | Type                | Technology             | Version | Dependencies                            | API Endpoints         | SLA           | Owner        | Source File                                                     |
| ---------------- | --------------------------------------- | ------------------- | ---------------------- | ------- | --------------------------------------- | --------------------- | ------------- | ------------ | --------------------------------------------------------------- |
| OrderService     | Core order management business logic    | Application Service | .NET 10.0 / C#         | 10.0    | IOrderRepository, IOrdersMessageHandler | 7 service methods     | Not specified | Not detected | src/eShop.Orders.API/Services/OrderService.cs:1-606             |
| OrdersAPIService | Typed HTTP client for API communication | HTTP Client Service | .NET 10.0 / HttpClient | 10.0    | eShop.Orders.API (HTTP/REST)            | 7 HTTP client methods | Not specified | Not detected | src/eShop.Web.App/Components/Services/OrdersAPIService.cs:1-479 |

#### 5.1.1 OrderService

| Attribute          | Value                                               |
| ------------------ | --------------------------------------------------- |
| **Component Name** | OrderService                                        |
| **Service Type**   | Application Service                                 |
| **Source**         | src/eShop.Orders.API/Services/OrderService.cs:1-606 |
| **Confidence**     | 0.95                                                |

**API Surface:**

| Endpoint Type   | Count | Protocol        | Description                                                                                                                                      |
| --------------- | ----- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Service Methods | 7     | In-process (DI) | PlaceOrderAsync, PlaceOrdersBatchAsync, GetOrdersAsync, GetOrderByIdAsync, DeleteOrderAsync, DeleteOrdersBatchAsync, ListMessagesFromTopicsAsync |
| Custom Metrics  | 4     | OpenTelemetry   | orders.placed (Counter), processing.duration (Histogram), processing.errors (Counter), orders.deleted (Counter)                                  |

**Dependencies:**

| Dependency            | Direction  | Protocol   | Purpose                                        |
| --------------------- | ---------- | ---------- | ---------------------------------------------- |
| IOrderRepository      | Downstream | In-process | Data persistence for all order CRUD operations |
| IOrdersMessageHandler | Downstream | In-process | Event publishing to Azure Service Bus          |
| ILogger               | Downstream | In-process | Structured logging with trace context          |
| ActivitySource        | Downstream | In-process | Distributed tracing span creation              |
| Meter                 | Downstream | In-process | Custom business metrics collection             |

**Resilience:** Internal error handling with try/catch, structured error logging, trace context correlation. Batch processing uses `SemaphoreSlim(10)` for concurrency throttling with 50-item batch sizing.

**Scaling:** Scales with host application (horizontal, CPU-based). Stateless service — no affinity requirements.

**Health:** Monitored indirectly via upstream controller health and downstream repository/handler health checks.

---

#### 5.1.2 OrdersAPIService

| Attribute          | Value                                                           |
| ------------------ | --------------------------------------------------------------- |
| **Component Name** | OrdersAPIService                                                |
| **Service Type**   | HTTP Client Service                                             |
| **Source**         | src/eShop.Web.App/Components/Services/OrdersAPIService.cs:1-479 |
| **Confidence**     | 0.90                                                            |

**API Surface:**

| Endpoint Type       | Count | Protocol      | Description                                                                                                                           |
| ------------------- | ----- | ------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| HTTP Client Methods | 7     | HTTP/REST     | PlaceOrderAsync, PlaceOrdersBatchAsync, GetOrdersAsync, GetOrderByIdAsync, UpdateOrderAsync, DeleteOrderAsync, DeleteOrdersBatchAsync |
| Tracing Spans       | 7     | OpenTelemetry | One ActivityKind.Client span per operation                                                                                            |

**Dependencies:**

| Dependency       | Direction  | Protocol                      | Purpose                                 |
| ---------------- | ---------- | ----------------------------- | --------------------------------------- |
| eShop.Orders.API | Upstream   | HTTP/REST (Service Discovery) | Backend API for all order operations    |
| HttpClient       | Downstream | HTTP                          | Typed HTTP client with Polly resilience |
| ActivitySource   | Downstream | In-process                    | Client-side distributed tracing         |

**Resilience:** Inherits HTTP resilience from ServiceDefaults: 600s total timeout, 60s per-attempt timeout, 3 retries with exponential backoff, 120s circuit breaker sampling window. Input validation with log-forging prevention (control character sanitization).

**Scaling:** Scales with Blazor Server host. Stateless — HttpClient pooled via IHttpClientFactory.

**Health:** Monitored via host application /health endpoint. Failures surface as HTTP exceptions in Blazor UI.

---

### 5.2 Application Components

| Component                | Description                                 | Type             | Technology         | Version | Dependencies                            | API Endpoints                 | SLA            | Owner        | Source File                                                    |
| ------------------------ | ------------------------------------------- | ---------------- | ------------------ | ------- | --------------------------------------- | ----------------------------- | -------------- | ------------ | -------------------------------------------------------------- |
| eShop.Orders.API         | Order management Web API                    | Web API          | ASP.NET Core 10.0  | 10.0    | Azure SQL, Service Bus, ServiceDefaults | 6 REST + 2 health + 1 OpenAPI | Not specified  | Not detected | src/eShop.Orders.API/Program.cs:1-226                          |
| eShop.Web.App            | Interactive order management frontend       | Blazor Server    | .NET 10.0 / Blazor | 10.0    | eShop.Orders.API, ServiceDefaults       | 7 Razor pages + 2 health      | Not specified  | Not detected | src/eShop.Web.App/Program.cs:1-109                             |
| OrderRepository          | EF Core data access with repository pattern | Data Access      | EF Core 10.0.3     | 10.0.3  | OrderDbContext, Azure SQL               | 6 repository methods          | Not specified  | Not detected | src/eShop.Orders.API/Repositories/OrderRepository.cs:1-549     |
| OrderDbContext           | Database context with Fluent API config     | Data Context     | EF Core 10.0.3     | 10.0.3  | Azure SQL                               | 2 DbSets                      | Not specified  | Not detected | src/eShop.Orders.API/data/OrderDbContext.cs:1-136              |
| ServiceDefaults          | Cross-cutting concerns shared library       | Shared Library   | .NET 10.0          | 10.0    | OpenTelemetry, Azure Identity, Polly    | 5 extension methods           | Not specified  | Not detected | app.ServiceDefaults/Extensions.cs:1-347                        |
| NoOpOrdersMessageHandler | Development fallback message handler        | Development Stub | .NET 10.0          | 10.0    | ILogger                                 | 3 no-op methods               | Not applicable | Not detected | src/eShop.Orders.API/Handlers/NoOpOrdersMessageHandler.cs:1-65 |
| FluentDesignSystem       | UI design tokens and spacing constants      | UI Configuration | .NET 10.0          | 10.0    | None                                    | 6 static constant classes     | Not applicable | Not detected | src/eShop.Web.App/Shared/FluentDesignSystem.cs:1-103           |

#### 5.2.1 eShop.Orders.API

| Attribute          | Value                                 |
| ------------------ | ------------------------------------- |
| **Component Name** | eShop.Orders.API                      |
| **Service Type**   | ASP.NET Core Web API                  |
| **Source**         | src/eShop.Orders.API/Program.cs:1-226 |
| **Confidence**     | 0.92                                  |

**API Surface:**

| Endpoint Type    | Count | Protocol  | Description                                                                                                                             |
| ---------------- | ----- | --------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| REST Endpoints   | 6     | HTTP/JSON | POST /api/orders, POST /api/orders/batch, GET /api/orders, GET /api/orders/{id}, DELETE /api/orders/{id}, POST /api/orders/batch/delete |
| Health Endpoints | 2     | HTTP      | /health (readiness), /alive (liveness)                                                                                                  |
| OpenAPI          | 1     | HTTP      | /swagger (Swagger UI + OpenAPI spec)                                                                                                    |
| Demo Endpoint    | 1     | HTTP      | GET /WeatherForecast                                                                                                                    |

**Dependencies:**

| Dependency           | Direction  | Protocol                 | Purpose                |
| -------------------- | ---------- | ------------------------ | ---------------------- |
| Azure SQL Database   | Downstream | TDS (EF Core)            | Order data persistence |
| Azure Service Bus    | Downstream | AMQP WebSockets          | Order event publishing |
| Application Insights | Downstream | OTLP / Azure Monitor SDK | Telemetry export       |
| ServiceDefaults      | Downstream | In-process               | Cross-cutting concerns |

**Resilience:** EF Core retry-on-failure (5 retries, 30s max delay, 120s command timeout). Database migration auto-retry (10 attempts, 10s delay). Service Bus configured through ServiceDefaults with exponential backoff.

**Scaling:** Horizontal scaling via Azure Container Apps. Stateless API — no session affinity required.

**Health:** /health endpoint aggregates DbContextHealthCheck and ServiceBusHealthCheck. /alive endpoint returns self-check only.

---

#### 5.2.2 eShop.Web.App

| Attribute          | Value                              |
| ------------------ | ---------------------------------- |
| **Component Name** | eShop.Web.App                      |
| **Service Type**   | Blazor Server                      |
| **Source**         | src/eShop.Web.App/Program.cs:1-109 |
| **Confidence**     | 0.88                               |

**API Surface:**

| Endpoint Type    | Count | Protocol     | Description                                                                           |
| ---------------- | ----- | ------------ | ------------------------------------------------------------------------------------- |
| Razor Pages      | 7     | HTTP/SignalR | Home, ListAllOrders, PlaceOrder, PlaceOrdersBatch, ViewOrder, WeatherForecasts, Error |
| Health Endpoints | 2     | HTTP         | /health, /alive                                                                       |

**Dependencies:**

| Dependency           | Direction  | Protocol   | Purpose                                      |
| -------------------- | ---------- | ---------- | -------------------------------------------- |
| eShop.Orders.API     | Upstream   | HTTP/REST  | Order management operations                  |
| ServiceDefaults      | Downstream | In-process | OpenTelemetry, resilience, service discovery |
| Fluent UI Components | Downstream | In-process | UI component library                         |

**Resilience:** HTTP client resilience via ServiceDefaults (Polly). SignalR configuration: 32KB max message size, 2-minute handshake timeout. Session management: 30-minute idle timeout with distributed memory cache.

**Scaling:** Horizontal scaling via Azure Container Apps. Session state in distributed cache — no server affinity required.

**Health:** /health and /alive endpoints from ServiceDefaults.

---

#### 5.2.3 OrderRepository

| Attribute          | Value                                                      |
| ------------------ | ---------------------------------------------------------- |
| **Component Name** | OrderRepository                                            |
| **Service Type**   | Data Access Layer                                          |
| **Source**         | src/eShop.Orders.API/Repositories/OrderRepository.cs:1-549 |
| **Confidence**     | 0.90                                                       |

**API Surface:**

| Endpoint Type      | Count | Protocol             | Description                                                                                                   |
| ------------------ | ----- | -------------------- | ------------------------------------------------------------------------------------------------------------- |
| Repository Methods | 6     | In-process (EF Core) | SaveOrderAsync, GetAllOrdersAsync, GetOrdersPagedAsync, GetOrderByIdAsync, DeleteOrderAsync, OrderExistsAsync |

**Dependencies:**

| Dependency         | Direction  | Protocol   | Purpose                             |
| ------------------ | ---------- | ---------- | ----------------------------------- |
| OrderDbContext     | Downstream | In-process | EF Core database context            |
| Azure SQL Database | Downstream | TDS        | Underlying data store               |
| ActivitySource     | Downstream | In-process | Operation-level distributed tracing |

**Resilience:** Split queries for complex joins, no-tracking reads for performance, duplicate key detection with graceful handling, internal timeout management with cancellation tokens.

**Scaling:** Scales with host application. Connection pooling via EF Core.

**Health:** Monitored via DbContextHealthCheck.

---

#### 5.2.4 OrderDbContext

| Attribute          | Value                                             |
| ------------------ | ------------------------------------------------- |
| **Component Name** | OrderDbContext                                    |
| **Service Type**   | EF Core Database Context                          |
| **Source**         | src/eShop.Orders.API/data/OrderDbContext.cs:1-136 |
| **Confidence**     | 0.85                                              |

**API Surface:**

| Endpoint Type     | Count | Protocol | Description                                              |
| ----------------- | ----- | -------- | -------------------------------------------------------- |
| DbSets            | 2     | EF Core  | Orders (OrderEntity), OrderProducts (OrderProductEntity) |
| Fluent API Config | 1     | EF Core  | OnModelCreating with indexes and cascade delete          |

**Dependencies:**

| Dependency         | Direction  | Protocol   | Purpose                    |
| ------------------ | ---------- | ---------- | -------------------------- |
| Azure SQL Database | Downstream | TDS        | Physical database          |
| OrderEntity        | Downstream | In-process | Order table mapping        |
| OrderProductEntity | Downstream | In-process | OrderProduct table mapping |

**Resilience:** Inherits EF Core SqlServer retry-on-failure execution strategy (5 retries, 30s max delay).

**Scaling:** Connection pooling managed by EF Core. Scoped lifetime per HTTP request.

**Health:** Validated by DbContextHealthCheck via `CanConnectAsync()`.

---

#### 5.2.5 ServiceDefaults

| Attribute          | Value                                   |
| ------------------ | --------------------------------------- |
| **Component Name** | ServiceDefaults (Extensions)            |
| **Service Type**   | Shared Library                          |
| **Source**         | app.ServiceDefaults/Extensions.cs:1-347 |
| **Confidence**     | 0.82                                    |

**API Surface:**

| Endpoint Type     | Count | Protocol   | Description                                                                                                       |
| ----------------- | ----- | ---------- | ----------------------------------------------------------------------------------------------------------------- |
| Extension Methods | 5     | In-process | AddServiceDefaults, ConfigureOpenTelemetry, AddDefaultHealthChecks, AddAzureServiceBusClient, MapDefaultEndpoints |

**Dependencies:**

| Dependency              | Direction  | Protocol          | Purpose                         |
| ----------------------- | ---------- | ----------------- | ------------------------------- |
| OpenTelemetry SDK       | Downstream | OTLP              | Distributed tracing and metrics |
| Azure Monitor Exporter  | Downstream | Azure Monitor SDK | Azure Application Insights      |
| Azure.Identity          | Downstream | In-process        | Managed identity credentials    |
| Polly (Http.Resilience) | Downstream | In-process        | HTTP client resilience          |
| Service Discovery       | Downstream | In-process        | Service endpoint resolution     |

**Resilience:** Provides resilience configuration for all consuming services: standardized retry, circuit breaker, and timeout policies.

**Scaling:** Shared library — no independent scaling. Deployed as part of each consuming project.

**Health:** Provides `AddDefaultHealthChecks()` and `MapDefaultEndpoints()` for /health and /alive.

---

#### 5.2.6 NoOpOrdersMessageHandler

| Attribute          | Value                                                          |
| ------------------ | -------------------------------------------------------------- |
| **Component Name** | NoOpOrdersMessageHandler                                       |
| **Service Type**   | Development Stub                                               |
| **Source**         | src/eShop.Orders.API/Handlers/NoOpOrdersMessageHandler.cs:1-65 |
| **Confidence**     | 0.75                                                           |

**API Surface:**

| Endpoint Type   | Count | Protocol   | Description                                                                                   |
| --------------- | ----- | ---------- | --------------------------------------------------------------------------------------------- |
| Handler Methods | 3     | In-process | SendOrderMessageAsync (no-op), SendOrdersBatchMessageAsync (no-op), ListMessagesAsync (empty) |

**Dependencies:**

| Dependency | Direction  | Protocol   | Purpose                  |
| ---------- | ---------- | ---------- | ------------------------ |
| ILogger    | Downstream | In-process | Logs intended operations |

**Resilience:** Not applicable — stub implementation for development environments.

**Scaling:** Not applicable — development use only.

**Health:** Not applicable — no external dependencies.

---

#### 5.2.7 FluentDesignSystem

| Attribute          | Value                                                |
| ------------------ | ---------------------------------------------------- |
| **Component Name** | FluentDesignSystem                                   |
| **Service Type**   | UI Configuration                                     |
| **Source**         | src/eShop.Web.App/Shared/FluentDesignSystem.cs:1-103 |
| **Confidence**     | 0.75                                                 |

**API Surface:**

| Endpoint Type    | Count     | Protocol   | Description                                                          |
| ---------------- | --------- | ---------- | -------------------------------------------------------------------- |
| Static Constants | 6 classes | In-process | Spacing, FontSizes, FontWeights, MaxWidths, Padding, DataGridColumns |

**Dependencies:**

| Dependency | Direction | Protocol | Purpose                      |
| ---------- | --------- | -------- | ---------------------------- |
| None       | —         | —        | Self-contained design tokens |

**Resilience:** Not applicable — static configuration class.

**Scaling:** Not applicable — compile-time constants.

**Health:** Not applicable — no runtime dependencies.

---

### 5.3 Application Interfaces

| Component             | Description                             | Type                | Technology        | Version | Dependencies     | API Endpoints      | SLA           | Owner        | Source File                                                   |
| --------------------- | --------------------------------------- | ------------------- | ----------------- | ------- | ---------------- | ------------------ | ------------- | ------------ | ------------------------------------------------------------- |
| OrdersController      | RESTful API controller for orders       | REST API Controller | ASP.NET Core 10.0 | 10.0    | IOrderService    | 6 REST endpoints   | Not specified | Not detected | src/eShop.Orders.API/Controllers/OrdersController.cs:1-501    |
| IOrderService         | Service contract for order operations   | Service Contract    | .NET 10.0 / C#    | 10.0    | None (interface) | 7 contract methods | Not specified | Not detected | src/eShop.Orders.API/Interfaces/IOrderService.cs:1-68         |
| IOrderRepository      | Repository contract for data access     | Repository Contract | .NET 10.0 / C#    | 10.0    | None (interface) | 6 contract methods | Not specified | Not detected | src/eShop.Orders.API/Interfaces/IOrderRepository.cs:1-69      |
| IOrdersMessageHandler | Messaging contract for event publishing | Messaging Contract  | .NET 10.0 / C#    | 10.0    | None (interface) | 3 contract methods | Not specified | Not detected | src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs:1-40 |

#### 5.3.1 OrdersController

| Attribute          | Value                                                      |
| ------------------ | ---------------------------------------------------------- |
| **Component Name** | OrdersController                                           |
| **Service Type**   | REST API Controller                                        |
| **Source**         | src/eShop.Orders.API/Controllers/OrdersController.cs:1-501 |
| **Confidence**     | 0.95                                                       |

**API Surface:**

| Endpoint Type                 | Count | Protocol  | Description                     |
| ----------------------------- | ----- | --------- | ------------------------------- |
| POST /api/orders              | 1     | HTTP/JSON | Place a single order            |
| POST /api/orders/batch        | 1     | HTTP/JSON | Place multiple orders in batch  |
| GET /api/orders               | 1     | HTTP/JSON | Retrieve all orders             |
| GET /api/orders/{id}          | 1     | HTTP/JSON | Retrieve order by ID            |
| DELETE /api/orders/{id}       | 1     | HTTP/JSON | Delete a single order           |
| POST /api/orders/batch/delete | 1     | HTTP/JSON | Delete multiple orders in batch |

**Dependencies:**

| Dependency     | Direction  | Protocol   | Purpose                   |
| -------------- | ---------- | ---------- | ------------------------- |
| IOrderService  | Downstream | In-process | Business logic delegation |
| ILogger        | Downstream | In-process | Structured logging        |
| ActivitySource | Downstream | In-process | Distributed tracing       |

**Resilience:** Input validation, null checks, structured error responses with correlation IDs. Each endpoint wrapped in try/catch with trace context propagation.

**Scaling:** Stateless — scales horizontally with host.

**Health:** Monitored via host /health endpoint.

---

#### 5.3.2 IOrderService

| Attribute          | Value                                                 |
| ------------------ | ----------------------------------------------------- |
| **Component Name** | IOrderService                                         |
| **Service Type**   | Service Contract                                      |
| **Source**         | src/eShop.Orders.API/Interfaces/IOrderService.cs:1-68 |
| **Confidence**     | 0.92                                                  |

**Contract Methods:**

| Method                      | Return Type                                     | Description               |
| --------------------------- | ----------------------------------------------- | ------------------------- |
| PlaceOrderAsync             | Task\<Order\>                                   | Create a single order     |
| PlaceOrdersBatchAsync       | Task\<IEnumerable\<Order\>\>                    | Create multiple orders    |
| GetOrdersAsync              | Task\<IEnumerable\<Order\>\>                    | Retrieve all orders       |
| GetOrderByIdAsync           | Task\<Order?\>                                  | Retrieve by ID            |
| DeleteOrderAsync            | Task\<bool\>                                    | Delete single order       |
| DeleteOrdersBatchAsync      | Task\<int\>                                     | Delete multiple orders    |
| ListMessagesFromTopicsAsync | Task\<IEnumerable\<OrderMessageWithMetadata\>\> | List Service Bus messages |

---

#### 5.3.3 IOrderRepository

| Attribute          | Value                                                    |
| ------------------ | -------------------------------------------------------- |
| **Component Name** | IOrderRepository                                         |
| **Service Type**   | Repository Contract                                      |
| **Source**         | src/eShop.Orders.API/Interfaces/IOrderRepository.cs:1-69 |
| **Confidence**     | 0.90                                                     |

**Contract Methods:**

| Method              | Return Type                  | Description               |
| ------------------- | ---------------------------- | ------------------------- |
| SaveOrderAsync      | Task\<Order\>                | Persist order to database |
| GetAllOrdersAsync   | Task\<IEnumerable\<Order\>\> | Retrieve all orders       |
| GetOrdersPagedAsync | Task\<IEnumerable\<Order\>\> | Paginated retrieval       |
| GetOrderByIdAsync   | Task\<Order?\>               | Retrieve by ID            |
| DeleteOrderAsync    | Task\<bool\>                 | Delete order              |
| OrderExistsAsync    | Task\<bool\>                 | Check existence           |

---

#### 5.3.4 IOrdersMessageHandler

| Attribute          | Value                                                         |
| ------------------ | ------------------------------------------------------------- |
| **Component Name** | IOrdersMessageHandler                                         |
| **Service Type**   | Messaging Contract                                            |
| **Source**         | src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs:1-40 |
| **Confidence**     | 0.88                                                          |

**Contract Methods:**

| Method                      | Return Type                                     | Description                |
| --------------------------- | ----------------------------------------------- | -------------------------- |
| SendOrderMessageAsync       | Task                                            | Publish single order event |
| SendOrdersBatchMessageAsync | Task                                            | Publish batch order events |
| ListMessagesAsync           | Task\<IEnumerable\<OrderMessageWithMetadata\>\> | List topic messages        |

---

### 5.4 Application Collaborations

| Component | Description                          | Type         | Technology       | Version | Dependencies                                                          | API Endpoints                          | SLA           | Owner        | Source File                  |
| --------- | ------------------------------------ | ------------ | ---------------- | ------- | --------------------------------------------------------------------- | -------------------------------------- | ------------- | ------------ | ---------------------------- |
| AppHost   | Distributed application orchestrator | Orchestrator | .NET Aspire 10.0 | 10.0    | eShop.Orders.API, eShop.Web.App, Azure SQL, Service Bus, App Insights | 2 project resources, 3 Azure resources | Not specified | Not detected | app.AppHost/AppHost.cs:1-290 |

#### 5.4.1 AppHost (.NET Aspire Orchestrator)

| Attribute          | Value                                |
| ------------------ | ------------------------------------ |
| **Component Name** | AppHost                              |
| **Service Type**   | Distributed Application Orchestrator |
| **Source**         | app.AppHost/AppHost.cs:1-290         |
| **Confidence**     | 0.88                                 |

**API Surface:**

| Endpoint Type           | Count | Protocol    | Description                                                          |
| ----------------------- | ----- | ----------- | -------------------------------------------------------------------- |
| Project Resources       | 2     | .NET Aspire | orders-api, web-app                                                  |
| Azure Resources         | 3     | Azure SDK   | SQL Azure, Service Bus, Application Insights                         |
| Configuration Functions | 3     | In-process  | ConfigureApplicationInsights, ConfigureServiceBus, ConfigureSQLAzure |

**Dependencies:**

| Dependency           | Direction    | Protocol    | Purpose                                            |
| -------------------- | ------------ | ----------- | -------------------------------------------------- |
| eShop.Orders.API     | Orchestrates | .NET Aspire | API project registration                           |
| eShop.Web.App        | Orchestrates | .NET Aspire | Frontend project registration (WaitFor orders-api) |
| Azure SQL            | Provisions   | Azure SDK   | Database resource                                  |
| Azure Service Bus    | Provisions   | Azure SDK   | Messaging resource                                 |
| Application Insights | Configures   | Azure SDK   | Telemetry resource                                 |

**Resilience:** WaitFor dependencies ensure service readiness before startup. Dual-mode provisioning prevents configuration errors.

**Scaling:** Not independently scaled — orchestration-time only.

**Health:** Platform-managed via .NET Aspire dashboard.

---

### 5.5 Application Functions

| Component              | Description                             | Type                | Technology           | Version | Dependencies                 | API Endpoints        | SLA            | Owner        | Source File                                                      |
| ---------------------- | --------------------------------------- | ------------------- | -------------------- | ------- | ---------------------------- | -------------------- | -------------- | ------------ | ---------------------------------------------------------------- |
| DbContextHealthCheck   | Database connectivity health monitor    | Health Check        | ASP.NET Core 10.0    | 10.0    | OrderDbContext               | /health (composite)  | 5s timeout     | Not detected | src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs:1-102  |
| ServiceBusHealthCheck  | Service Bus connectivity health monitor | Health Check        | ASP.NET Core 10.0    | 10.0    | ServiceBusClient             | /health (composite)  | 5s timeout     | Not detected | src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs:1-183 |
| OrderMapper            | Domain-to-entity bidirectional mapper   | Data Mapper         | .NET 10.0 / C#       | 10.0    | Order, OrderEntity           | 2 extension methods  | Not applicable | Not detected | src/eShop.Orders.API/data/OrderMapper.cs:1-102                   |
| ConfigureOpenTelemetry | OpenTelemetry configuration function    | Observability Setup | OpenTelemetry 1.15.0 | 1.15.0  | OTLP Exporter, Azure Monitor | Configuration method | Not applicable | Not detected | app.ServiceDefaults/Extensions.cs:44-163                         |

#### 5.5.1 DbContextHealthCheck

| Attribute          | Value                                                           |
| ------------------ | --------------------------------------------------------------- |
| **Component Name** | DbContextHealthCheck                                            |
| **Service Type**   | Health Check                                                    |
| **Source**         | src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs:1-102 |
| **Confidence**     | 0.85                                                            |

**Behavior:** Executes `OrderDbContext.Database.CanConnectAsync()` with a 5-second timeout. Returns `HealthCheckResult.Healthy` with response time on success, `HealthCheckResult.Unhealthy` on connection failure, and `HealthCheckResult.Degraded` on timeout or slow response.

**Dependencies:**

| Dependency     | Direction  | Protocol | Purpose                    |
| -------------- | ---------- | -------- | -------------------------- |
| OrderDbContext | Downstream | EF Core  | Database connectivity test |

---

#### 5.5.2 ServiceBusHealthCheck

| Attribute          | Value                                                            |
| ------------------ | ---------------------------------------------------------------- |
| **Component Name** | ServiceBusHealthCheck                                            |
| **Service Type**   | Health Check                                                     |
| **Source**         | src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs:1-183 |
| **Confidence**     | 0.88                                                             |

**Behavior:** Creates a `ServiceBusSender` for the configured topic name, then creates a message batch to verify full connectivity. Uses a 5-second timeout via `CancellationTokenSource`. Returns Healthy/Unhealthy based on connection result.

**Dependencies:**

| Dependency       | Direction  | Protocol | Purpose                       |
| ---------------- | ---------- | -------- | ----------------------------- |
| ServiceBusClient | Downstream | AMQP     | Service Bus connectivity test |

---

#### 5.5.3 OrderMapper

| Attribute          | Value                                          |
| ------------------ | ---------------------------------------------- |
| **Component Name** | OrderMapper                                    |
| **Service Type**   | Data Mapper                                    |
| **Source**         | src/eShop.Orders.API/data/OrderMapper.cs:1-102 |
| **Confidence**     | 0.80                                           |

**Behavior:** Provides static extension methods `ToEntity()` and `ToDomainModel()` for bidirectional mapping between `Order`/`OrderProduct` domain models and `OrderEntity`/`OrderProductEntity` persistence entities.

**Dependencies:**

| Dependency                       | Direction | Protocol   | Purpose              |
| -------------------------------- | --------- | ---------- | -------------------- |
| Order / OrderProduct             | Input     | In-process | Domain models        |
| OrderEntity / OrderProductEntity | Output    | In-process | Persistence entities |

---

#### 5.5.4 ConfigureOpenTelemetry

| Attribute          | Value                                    |
| ------------------ | ---------------------------------------- |
| **Component Name** | ConfigureOpenTelemetry                   |
| **Service Type**   | Observability Configuration              |
| **Source**         | app.ServiceDefaults/Extensions.cs:44-163 |
| **Confidence**     | 0.78                                     |

**Behavior:** Configures OpenTelemetry with logging (structured, trace context), tracing (ASP.NET Core, HTTP client, SQL client auto-instrumentation), and metrics (ASP.NET Core, HTTP client, runtime, custom meters). Adds OTLP exporter and conditionally adds Azure Monitor exporter when Application Insights connection string is available.

**Dependencies:**

| Dependency             | Direction  | Protocol  | Purpose                          |
| ---------------------- | ---------- | --------- | -------------------------------- |
| OTLP Exporter          | Downstream | gRPC/HTTP | Trace and metric export          |
| Azure Monitor Exporter | Downstream | Azure SDK | Application Insights integration |

---

### 5.6 Application Interactions

| Component       | Description                                | Type             | Technology             | Version | Dependencies            | API Endpoints                   | SLA           | Owner        | Source File                        |
| --------------- | ------------------------------------------ | ---------------- | ---------------------- | ------- | ----------------------- | ------------------------------- | ------------- | ------------ | ---------------------------------- |
| Web-to-API HTTP | Service discovery-based HTTP communication | Request/Response | .NET 10.0 / HttpClient | 10.0    | eShop.Orders.API, Polly | HTTP/REST via Service Discovery | Not specified | Not detected | src/eShop.Web.App/Program.cs:80-92 |

#### 5.6.1 Web-to-API HTTP Communication

| Attribute          | Value                              |
| ------------------ | ---------------------------------- |
| **Component Name** | Web-to-API HTTP Communication      |
| **Service Type**   | Request/Response                   |
| **Source**         | src/eShop.Web.App/Program.cs:80-92 |
| **Confidence**     | 0.82                               |

**Pattern Type:** Request/Response with service discovery

**Protocol:** HTTP/REST with JSON serialization

**Data Contract:** Shared `Order` and `OrderProduct` records from `app.ServiceDefaults.CommonTypes`. No versioning strategy detected.

**Error Handling:** HTTP client resilience via Polly (retry with exponential backoff, circuit breaker). Client-side exception handling in OrdersAPIService with structured error logging. 404 responses treated as expected (return null) rather than exceptions.

---

### 5.7 Application Events

| Component         | Description                     | Type         | Technology               | Version | Dependencies     | API Endpoints      | SLA           | Owner        | Source File                                                 |
| ----------------- | ------------------------------- | ------------ | ------------------------ | ------- | ---------------- | ------------------ | ------------- | ------------ | ----------------------------------------------------------- |
| OrderPlaced Event | Domain event for order creation | Domain Event | Azure Service Bus 7.20.1 | 7.20.1  | ServiceBusClient | ordersplaced topic | Not specified | Not detected | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425 |

#### 5.7.1 OrderPlaced Event

| Attribute          | Value                                                       |
| ------------------ | ----------------------------------------------------------- |
| **Component Name** | OrderPlaced Event                                           |
| **Service Type**   | Domain Event (Pub/Sub)                                      |
| **Source**         | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425 |
| **Confidence**     | 0.90                                                        |

**Event Schema:** JSON-serialized `Order` record published to Azure Service Bus topic `ordersplaced`.

**Subscription Patterns:**

| Subscriber                    | Subscription       | Pattern                         |
| ----------------------------- | ------------------ | ------------------------------- |
| Logic App OrdersPlacedProcess | orderprocessingsub | Auto-complete, 1-second polling |

**Trace Context Propagation:** Activity `TraceId` and `SpanId` propagated via Service Bus `ApplicationProperties` dictionary. Consumer can correlate distributed traces across service boundaries.

**Retry Policy:** 3 attempts with exponential backoff (1s base delay). Independent timeout handling per message.

**Dead Letter:** Not explicitly configured in application code — relies on Service Bus platform defaults.

---

### 5.8 Application Data Objects

| Component                | Description                                | Type               | Technology            | Version | Dependencies       | API Endpoints        | SLA            | Owner        | Source File                                                    |
| ------------------------ | ------------------------------------------ | ------------------ | --------------------- | ------- | ------------------ | -------------------- | -------------- | ------------ | -------------------------------------------------------------- |
| Order                    | Shared domain record for orders            | Domain Model       | .NET 10.0 / C# record | 10.0    | None               | Not applicable       | Not applicable | Not detected | app.ServiceDefaults/CommonTypes.cs:77-127                      |
| OrderProduct             | Product line item within an order          | Domain Model       | .NET 10.0 / C# record | 10.0    | None               | Not applicable       | Not applicable | Not detected | app.ServiceDefaults/CommonTypes.cs:132-175                     |
| OrderEntity              | EF Core persistence entity for orders      | Persistence Entity | EF Core 10.0.3        | 10.0.3  | OrderProductEntity | DbSet mapping        | Not applicable | Not detected | src/eShop.Orders.API/data/Entities/OrderEntity.cs:1-56         |
| OrderProductEntity       | EF Core persistence entity for line items  | Persistence Entity | EF Core 10.0.3        | 10.0.3  | OrderEntity        | DbSet mapping        | Not applicable | Not detected | src/eShop.Orders.API/data/Entities/OrderProductEntity.cs:1-65  |
| OrderMessageWithMetadata | Service Bus message wrapper DTO            | Message DTO        | .NET 10.0 / C#        | 10.0    | Order              | Not applicable       | Not applicable | Not detected | src/eShop.Orders.API/Handlers/OrderMessageWithMetadata.cs:1-49 |
| OrdersWrapper            | API response wrapper for order collections | Response DTO       | .NET 10.0 / C#        | 10.0    | Order              | Not applicable       | Not applicable | Not detected | src/eShop.Orders.API/Services/OrdersWrapper.cs:1-21            |
| WeatherForecast          | Demo data model for health verification    | Demo Model         | .NET 10.0 / C#        | 10.0    | None               | GET /WeatherForecast | Not applicable | Not detected | app.ServiceDefaults/CommonTypes.cs:14-72                       |

#### 5.8.1 Order (Domain Record)

| Attribute          | Value                                     |
| ------------------ | ----------------------------------------- |
| **Component Name** | Order                                     |
| **Service Type**   | Domain Model (Shared)                     |
| **Source**         | app.ServiceDefaults/CommonTypes.cs:77-127 |
| **Confidence**     | 0.92                                      |

**Properties:**

| Property        | Type                 | Validation               | Description               |
| --------------- | -------------------- | ------------------------ | ------------------------- |
| Id              | string               | Required, MaxLength(100) | Unique order identifier   |
| CustomerId      | string               | Required, MaxLength(100) | Customer reference        |
| Date            | DateTime             | Required                 | Order placement timestamp |
| DeliveryAddress | string               | Required, MaxLength(500) | Delivery location         |
| Total           | decimal              | Required                 | Order total amount        |
| Products        | List\<OrderProduct\> | Required                 | Line items                |

---

#### 5.8.2 OrderProduct (Domain Record)

| Attribute          | Value                                      |
| ------------------ | ------------------------------------------ |
| **Component Name** | OrderProduct                               |
| **Service Type**   | Domain Model (Shared)                      |
| **Source**         | app.ServiceDefaults/CommonTypes.cs:132-175 |
| **Confidence**     | 0.90                                       |

**Properties:**

| Property           | Type    | Validation               | Description               |
| ------------------ | ------- | ------------------------ | ------------------------- |
| Id                 | string  | Required, MaxLength(100) | Line item identifier      |
| OrderId            | string  | Required, MaxLength(100) | Parent order reference    |
| ProductId          | string  | Required, MaxLength(100) | Product catalog reference |
| ProductDescription | string  | MaxLength(500)           | Product description       |
| Quantity           | int     | Required                 | Ordered quantity          |
| Price              | decimal | Required                 | Unit price                |

---

#### 5.8.3 OrderEntity (Persistence)

| Attribute          | Value                                                  |
| ------------------ | ------------------------------------------------------ |
| **Component Name** | OrderEntity                                            |
| **Service Type**   | Persistence Entity                                     |
| **Source**         | src/eShop.Orders.API/data/Entities/OrderEntity.cs:1-56 |
| **Confidence**     | 0.88                                                   |

**Properties:** Mirrors Order domain model with `[Key]`, `[Required]`, `[MaxLength]` data annotations. Contains `ICollection<OrderProductEntity>` navigation property for one-to-many relationship. Indexes configured on CustomerId, Date, OrderId via Fluent API in OrderDbContext.

---

#### 5.8.4 OrderProductEntity (Persistence)

| Attribute          | Value                                                         |
| ------------------ | ------------------------------------------------------------- |
| **Component Name** | OrderProductEntity                                            |
| **Service Type**   | Persistence Entity                                            |
| **Source**         | src/eShop.Orders.API/data/Entities/OrderProductEntity.cs:1-65 |
| **Confidence**     | 0.88                                                          |

**Properties:** Mirrors OrderProduct domain model with `[ForeignKey(nameof(OrderId))]` navigation to `OrderEntity`. Cascade delete configured in OrderDbContext.

---

#### 5.8.5 OrderMessageWithMetadata

| Attribute          | Value                                                          |
| ------------------ | -------------------------------------------------------------- |
| **Component Name** | OrderMessageWithMetadata                                       |
| **Service Type**   | Message DTO                                                    |
| **Source**         | src/eShop.Orders.API/Handlers/OrderMessageWithMetadata.cs:1-49 |
| **Confidence**     | 0.82                                                           |

**Properties:**

| Property              | Type                          | Description                                  |
| --------------------- | ----------------------------- | -------------------------------------------- |
| Order                 | Order                         | The order payload                            |
| MessageId             | string                        | Service Bus message ID                       |
| SequenceNumber        | long                          | Service Bus sequence number                  |
| EnqueuedTime          | DateTimeOffset                | Message enqueue timestamp                    |
| ApplicationProperties | IDictionary\<string, object\> | Custom properties (includes TraceId, SpanId) |

---

#### 5.8.6 OrdersWrapper

| Attribute          | Value                                               |
| ------------------ | --------------------------------------------------- |
| **Component Name** | OrdersWrapper                                       |
| **Service Type**   | Response DTO                                        |
| **Source**         | src/eShop.Orders.API/Services/OrdersWrapper.cs:1-21 |
| **Confidence**     | 0.75                                                |

**Properties:**

| Property | Type          | Description                 |
| -------- | ------------- | --------------------------- |
| Orders   | List\<Order\> | Collection of order objects |

---

#### 5.8.7 WeatherForecast

| Attribute          | Value                                    |
| ------------------ | ---------------------------------------- |
| **Component Name** | WeatherForecast                          |
| **Service Type**   | Demo Model                               |
| **Source**         | app.ServiceDefaults/CommonTypes.cs:14-72 |
| **Confidence**     | 0.72                                     |

**Properties:**

| Property     | Type           | Description                   |
| ------------ | -------------- | ----------------------------- |
| Date         | DateOnly       | Forecast date                 |
| TemperatureC | int            | Temperature in Celsius        |
| TemperatureF | int (computed) | Temperature in Fahrenheit     |
| Summary      | string?        | Weather condition description |

---

### 5.9 Integration Patterns

| Component                             | Description                             | Type                 | Technology                | Version   | Dependencies                          | API Endpoints                                       | SLA           | Owner        | Source File                                                                                         |
| ------------------------------------- | --------------------------------------- | -------------------- | ------------------------- | --------- | ------------------------------------- | --------------------------------------------------- | ------------- | ------------ | --------------------------------------------------------------------------------------------------- |
| Azure Service Bus Pub/Sub             | Topic-based publish/subscribe messaging | Message Broker       | Azure Service Bus 7.20.1  | 7.20.1    | ServiceBusClient                      | ordersplaced topic, orderprocessingsub subscription | Not specified | Not detected | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425                                         |
| Logic App OrdersPlacedProcess         | Event-driven order processing workflow  | Workflow Integration | Azure Logic Apps Standard | 1.x-2.0.0 | Service Bus, Orders API, Blob Storage | SB trigger, HTTP callback, Blob write               | Not specified | Not detected | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-163         |
| Logic App OrdersPlacedCompleteProcess | Scheduled blob cleanup workflow         | Workflow Integration | Azure Logic Apps Standard | 1.x-2.0.0 | Blob Storage                          | Timer trigger, Blob list/delete                     | Not specified | Not detected | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-105 |

#### 5.9.1 Azure Service Bus Pub/Sub

| Attribute          | Value                                                       |
| ------------------ | ----------------------------------------------------------- |
| **Component Name** | Azure Service Bus Pub/Sub                                   |
| **Service Type**   | Message Broker Integration                                  |
| **Source**         | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425 |
| **Confidence**     | 0.92                                                        |

**Pattern Type:** Publish/Subscribe (Topic/Subscription)

**Protocol:** AMQP WebSockets (configurable transport type)

**Topology:**

| Element      | Name               | Purpose               |
| ------------ | ------------------ | --------------------- |
| Topic        | ordersplaced       | Order creation events |
| Subscription | orderprocessingsub | Logic App consumer    |

**Data Contract:** JSON-serialized `Order` record. No formal AsyncAPI specification detected.

**Error Handling:** 3 retries with exponential backoff (1s base, 10s max delay). Message batch support for throughput optimization. Trace context propagation via ApplicationProperties for distributed tracing correlation.

**Authentication:** DefaultAzureCredential with managed identity (Azure mode) or connection string (local emulator mode).

---

#### 5.9.2 Logic App OrdersPlacedProcess

| Attribute          | Value                                                                                       |
| ------------------ | ------------------------------------------------------------------------------------------- |
| **Component Name** | Logic App OrdersPlacedProcess                                                               |
| **Service Type**   | Workflow Integration (Stateful)                                                             |
| **Source**         | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json:1-163 |
| **Confidence**     | 0.85                                                                                        |

**Pattern Type:** Event-Driven Workflow

**Protocol:** Service Bus (trigger) → HTTP (callback) → Blob Storage (persistence)

**Workflow Steps:**

1. **Trigger**: Service Bus topic subscription (`ordersplaced` / `orderprocessingsub`) — 1-second polling
2. **Check Order Placed**: Validates ContentType is `application/json`
3. **HTTP Callback**: POST to Orders API `/api/Orders/process` with decoded message body
4. **Conditional Blob Storage**: On HTTP 201 → write to `/ordersprocessedsuccessfully`; otherwise → write to `/ordersprocessedwitherrors`

**Error Handling:** Conditional branching based on HTTP status code. Error orders stored in separate blob container for manual review.

---

#### 5.9.3 Logic App OrdersPlacedCompleteProcess

| Attribute          | Value                                                                                               |
| ------------------ | --------------------------------------------------------------------------------------------------- |
| **Component Name** | Logic App OrdersPlacedCompleteProcess                                                               |
| **Service Type**   | Workflow Integration (Stateful)                                                                     |
| **Source**         | workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json:1-105 |
| **Confidence**     | 0.80                                                                                                |

**Pattern Type:** Scheduled Cleanup Workflow

**Protocol:** Timer (trigger) → Blob Storage (read/delete)

**Workflow Steps:**

1. **Trigger**: Recurrence every 3 seconds (Central Standard Time)
2. **List Blobs**: Enumerate `/ordersprocessedsuccessfully` container
3. **For Each Blob**: Get metadata → Delete blob (20 concurrent repetitions)

**Error Handling:** Sequential runAfter dependencies ensure order of operations. Concurrent processing of blob cleanup with 20-repetition parallelism.

---

### 5.10 Service Contracts

| Component                | Description                          | Type                  | Technology                  | Version | Dependencies     | API Endpoints               | SLA           | Owner        | Source File                                                |
| ------------------------ | ------------------------------------ | --------------------- | --------------------------- | ------- | ---------------- | --------------------------- | ------------- | ------------ | ---------------------------------------------------------- |
| Orders REST API Contract | OpenAPI-documented REST API contract | OpenAPI Specification | ASP.NET Core 10.0 / Swagger | 10.0    | OrdersController | 6 REST endpoints + /swagger | Not specified | Not detected | src/eShop.Orders.API/Controllers/OrdersController.cs:1-501 |

#### 5.10.1 Orders REST API Contract

| Attribute          | Value                                                      |
| ------------------ | ---------------------------------------------------------- |
| **Component Name** | Orders REST API Contract                                   |
| **Service Type**   | OpenAPI Specification                                      |
| **Source**         | src/eShop.Orders.API/Controllers/OrdersController.cs:1-501 |
| **Confidence**     | 0.88                                                       |

**Contract Definition:**

| Endpoint                 | Method | Request Body          | Response      | Status Codes       |
| ------------------------ | ------ | --------------------- | ------------- | ------------------ |
| /api/orders              | POST   | Order (JSON)          | Order         | 201, 400, 409, 500 |
| /api/orders/batch        | POST   | List\<Order\> (JSON)  | List\<Order\> | 200, 400, 500      |
| /api/orders              | GET    | —                     | List\<Order\> | 200, 500           |
| /api/orders/{id}         | GET    | —                     | Order         | 200, 404, 500      |
| /api/orders/{id}         | DELETE | —                     | —             | 204, 404, 500      |
| /api/orders/batch/delete | POST   | List\<string\> (JSON) | int           | 200, 400, 500      |

**Versioning:** No explicit API versioning detected. Single version exposed.

**Breaking Change Policy:** Not specified in source — requires operational documentation.

---

### 5.11 Application Dependencies

#### External NuGet Package Dependencies

| Package                                      | Version     | Purpose                                           | Project             |
| -------------------------------------------- | ----------- | ------------------------------------------------- | ------------------- |
| Microsoft.EntityFrameworkCore.SqlServer      | 10.0.3      | SQL Server data provider with EF Core ORM         | eShop.Orders.API    |
| Azure.Messaging.ServiceBus                   | 7.20.1      | Azure Service Bus client for pub/sub messaging    | app.ServiceDefaults |
| Azure.Identity                               | 1.18.0      | Azure managed identity and DefaultAzureCredential | app.ServiceDefaults |
| Azure.Monitor.OpenTelemetry.Exporter         | 1.5.0       | Azure Monitor trace and metric export             | app.ServiceDefaults |
| OpenTelemetry.Exporter.OpenTelemetryProtocol | 1.15.0      | OTLP exporter for traces and metrics              | app.ServiceDefaults |
| OpenTelemetry.Extensions.Hosting             | 1.15.0      | OpenTelemetry DI integration                      | app.ServiceDefaults |
| OpenTelemetry.Instrumentation.AspNetCore     | 1.15.0      | ASP.NET Core auto-instrumentation                 | app.ServiceDefaults |
| OpenTelemetry.Instrumentation.Http           | 1.15.0      | HTTP client auto-instrumentation                  | app.ServiceDefaults |
| OpenTelemetry.Instrumentation.Runtime        | 1.15.0      | .NET runtime metrics instrumentation              | app.ServiceDefaults |
| OpenTelemetry.Instrumentation.SqlClient      | 1.14.0-rc.1 | SQL client query tracing                          | app.ServiceDefaults |
| Microsoft.Extensions.Http.Resilience         | 10.3.0      | Polly-based HTTP resilience policies              | app.ServiceDefaults |
| Microsoft.Extensions.ServiceDiscovery        | 10.3.0      | .NET Aspire service discovery                     | app.ServiceDefaults |
| Microsoft.FluentUI.AspNetCore.Components     | 4.14.0      | Fluent UI component library for Blazor            | eShop.Web.App       |

#### Project Dependencies

| Project          | Depends On                      | Relationship                      |
| ---------------- | ------------------------------- | --------------------------------- |
| eShop.Orders.API | app.ServiceDefaults             | ProjectReference (shared library) |
| eShop.Web.App    | app.ServiceDefaults             | ProjectReference (shared library) |
| app.AppHost      | eShop.Orders.API, eShop.Web.App | Orchestration references          |

### Summary

The Component Catalog documents 31 components across all 11 Application Architecture component types, with the highest density in Application Data Objects (7) and Application Components (7). The dominant architectural patterns are interface-driven design with dependency injection, repository-based data access with EF Core, and event-driven messaging with Azure Service Bus. All components demonstrate consistent observability instrumentation through OpenTelemetry with custom metrics, distributed tracing spans, and structured logging with trace context correlation.

Coverage gaps include the absence of formal API versioning (Section 5.10), no dead letter queue configuration for Service Bus messaging (Section 5.7), and limited runtime SLA definitions across all service components. Recommended next steps include implementing API versioning with URL segment or header-based strategies, configuring dead letter queues with automated alerting, and establishing formal SLO targets with automated monitoring for each service endpoint.

---

## Section 6: Architecture Decisions

### Overview

This section documents Architecture Decision Records (ADRs) inferred from the source code, configuration files, and infrastructure definitions. Each ADR captures a significant architectural choice, its context, the decision rationale, and its consequences as observed in the implementation.

Five architecture decisions were identified through source analysis, covering technology stack selection, integration patterns, data access strategy, infrastructure configuration, and observability approach. All decisions reflect an Accepted status based on their consistent implementation across the codebase.

These decisions collectively establish a cloud-native, event-driven architecture with strong observability and developer experience priorities. No rejected or superseded decisions were detected in the current codebase, suggesting a greenfield implementation rather than an evolved system with historical technology pivots.

### ADR Summary

| ADR ID  | Title                                         | Status   | Date         | Source                                                      |
| ------- | --------------------------------------------- | -------- | ------------ | ----------------------------------------------------------- |
| ADR-001 | .NET Aspire for Distributed Orchestration     | Accepted | Not detected | app.AppHost/AppHost.cs:1-290                                |
| ADR-002 | Event-Driven Architecture with Service Bus    | Accepted | Not detected | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425 |
| ADR-003 | Repository Pattern with Entity Framework Core | Accepted | Not detected | src/eShop.Orders.API/Repositories/OrderRepository.cs:1-549  |
| ADR-004 | Dual-Mode Infrastructure (Local/Azure)        | Accepted | Not detected | app.AppHost/AppHost.cs:1-290                                |
| ADR-005 | OpenTelemetry with Dual Export                | Accepted | Not detected | app.ServiceDefaults/Extensions.cs:44-163                    |

### ADR-001: .NET Aspire for Distributed Application Orchestration

| Attribute        | Value                                                                                                                                                                                                                              |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ID**           | ADR-001                                                                                                                                                                                                                            |
| **Title**        | Adopt .NET Aspire for Distributed Application Orchestration                                                                                                                                                                        |
| **Status**       | Accepted                                                                                                                                                                                                                           |
| **Context**      | The platform requires orchestration of multiple services (Web App, Orders API) with shared infrastructure (SQL, Service Bus, Application Insights). Manual configuration creates deployment complexity and developer friction.     |
| **Decision**     | Use .NET Aspire AppHost to declaratively configure all service dependencies, Azure resources, and local development containers in a single orchestration point.                                                                    |
| **Consequences** | Simplified developer experience with one-click F5 debugging, automated dependency resolution via WaitFor, service discovery integration. Introduces coupling to .NET Aspire tooling and requires Aspire-compatible NuGet packages. |
| **Source**       | app.AppHost/AppHost.cs:1-290                                                                                                                                                                                                       |

### ADR-002: Event-Driven Architecture with Azure Service Bus Pub/Sub

| Attribute        | Value                                                                                                                                                                                                                                                    |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ID**           | ADR-002                                                                                                                                                                                                                                                  |
| **Title**        | Adopt Azure Service Bus Topic/Subscription for Order Event Distribution                                                                                                                                                                                  |
| **Status**       | Accepted                                                                                                                                                                                                                                                 |
| **Context**      | Order creation needs to trigger downstream processing (Logic App workflows, blob storage persistence) without tight coupling between the Orders API and workflow services.                                                                               |
| **Decision**     | Use Azure Service Bus topic/subscription (ordersplaced topic, orderprocessingsub subscription) for asynchronous event distribution with trace context propagation via ApplicationProperties.                                                             |
| **Consequences** | Decoupled order processing enables independent scaling and failure isolation. Distributed tracing spans across service boundaries via propagated TraceId/SpanId. No formal event schema contract (AsyncAPI) or dead letter queue configuration detected. |
| **Source**       | src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs:1-425                                                                                                                                                                                              |

### ADR-003: Repository Pattern with Entity Framework Core

| Attribute        | Value                                                                                                                                                                                                                                    |
| ---------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ID**           | ADR-003                                                                                                                                                                                                                                  |
| **Title**        | Implement Repository Pattern with Interface Contracts for Data Access                                                                                                                                                                    |
| **Status**       | Accepted                                                                                                                                                                                                                                 |
| **Context**      | Data access needs abstraction for testability, separation of concerns, and to decouple business logic from Entity Framework Core persistence implementation.                                                                             |
| **Decision**     | Implement the Repository pattern with formal interface contracts (IOrderRepository to OrderRepository) using EF Core with retry-on-failure execution strategy, split query optimization, and no-tracking reads.                          |
| **Consequences** | Clean separation between business logic (OrderService) and data access (OrderRepository). Enables mock injection for unit testing and runtime substitution. Adds an abstraction layer over EF Core built-in patterns (DbContext, DbSet). |
| **Source**       | src/eShop.Orders.API/Repositories/OrderRepository.cs:1-549                                                                                                                                                                               |

### ADR-004: Dual-Mode Infrastructure Configuration (Local/Azure)

| Attribute        | Value                                                                                                                                                                                                                                 |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ID**           | ADR-004                                                                                                                                                                                                                               |
| **Title**        | Support Dual-Mode Infrastructure Provisioning in AppHost                                                                                                                                                                              |
| **Status**       | Accepted                                                                                                                                                                                                                              |
| **Context**      | Development teams need production-like infrastructure locally without requiring Azure subscriptions. Production deployments need Azure PaaS services with managed identity.                                                           |
| **Decision**     | AppHost conditionally provisions local SQL Server containers and Service Bus emulator (when Azure:ResourceGroup is not configured) or connects to Azure SQL with Entra ID authentication and Azure Service Bus with managed identity. |
| **Consequences** | Developer experience parity with production infrastructure. Zero Azure cost during local development. Requires maintaining two provisioning code paths in AppHost with conditional configuration logic.                               |
| **Source**       | app.AppHost/AppHost.cs:1-290                                                                                                                                                                                                          |

### ADR-005: OpenTelemetry with Dual Export (OTLP + Azure Monitor)

| Attribute        | Value                                                                                                                                                                                                                                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **ID**           | ADR-005                                                                                                                                                                                                                                                                                                |
| **Title**        | Adopt OpenTelemetry with OTLP and Azure Monitor Dual Export                                                                                                                                                                                                                                            |
| **Status**       | Accepted                                                                                                                                                                                                                                                                                               |
| **Context**      | Distributed tracing, custom metrics, and structured logging are required across all services. Local development uses the Aspire Dashboard (OTLP) while production uses Application Insights (Azure Monitor).                                                                                           |
| **Decision**     | Configure OpenTelemetry with ASP.NET Core, HTTP client, SQL client, and runtime auto-instrumentation. Export to both OTLP (for Aspire Dashboard and third-party backends) and Azure Monitor (for Application Insights) when available.                                                                 |
| **Consequences** | Full-stack observability with trace correlation across HTTP, SQL, and Service Bus boundaries. Custom business metrics (orders.placed, processing.duration, processing.errors, orders.deleted) tracked alongside infrastructure metrics. Dual export increases telemetry volume and cost in production. |
| **Source**       | app.ServiceDefaults/Extensions.cs:44-163                                                                                                                                                                                                                                                               |

---

## Section 7: Architecture Standards

### Overview

This section documents architecture standards observed in the source code through pattern analysis. Standards are inferred from consistent implementation patterns across multiple components rather than from explicit standards documentation. Each standard includes its description, the components that demonstrate compliance, and the source evidence.

Seven architecture standards were identified across API design, error handling, authentication, data access, dependency management, health monitoring, and observability. All standards show consistent application across the codebase, indicating established engineering practices rather than ad-hoc implementation choices.

These standards collectively define the engineering culture of the eShop Orders Management platform: API-first design with OpenAPI documentation, managed identity for Azure service authentication, structured logging with trace correlation, and resilience-first integration patterns.

### Observed Standards

| Standard ID | Standard Name                   | Category      | Compliance Level | Components Demonstrating                                          |
| ----------- | ------------------------------- | ------------- | ---------------- | ----------------------------------------------------------------- |
| STD-001     | RESTful API Design              | API Design    | Full             | OrdersController                                                  |
| STD-002     | Interface-First Architecture    | Code Design   | Full             | IOrderService, IOrderRepository, IOrdersMessageHandler            |
| STD-003     | Structured Logging with Tracing | Observability | Full             | OrderService, OrderRepository, OrdersController, OrdersAPIService |
| STD-004     | Health Check Implementation     | Operations    | Full             | DbContextHealthCheck, ServiceBusHealthCheck                       |
| STD-005     | Managed Identity Authentication | Security      | Full             | ServiceDefaults, AppHost                                          |
| STD-006     | Code-First Database Management  | Data Access   | Full             | OrderDbContext, OrderRepository                                   |
| STD-007     | Resilience Pattern Application  | Reliability   | Full             | ServiceDefaults (Polly), OrderDbContext (EF Core retry)           |

### STD-001: RESTful API Design

| Attribute      | Value                                                                                                                                     |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| **Standard**   | RESTful API routes follow /api/{resource} convention with HTTP method alignment                                                           |
| **Evidence**   | All endpoints use /api/orders pattern, POST for creation, GET for retrieval, DELETE for removal, with ProducesResponseType on all actions |
| **Source**     | src/eShop.Orders.API/Controllers/OrdersController.cs:1-501                                                                                |
| **Compliance** | Full                                                                                                                                      |

### STD-002: Interface-First Architecture

| Attribute      | Value                                                                                                                                      |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **Standard**   | All service, repository, and handler components implement formal interface contracts registered through dependency injection               |
| **Evidence**   | IOrderService to OrderService, IOrderRepository to OrderRepository, IOrdersMessageHandler to OrdersMessageHandler/NoOpOrdersMessageHandler |
| **Source**     | src/eShop.Orders.API/Interfaces/IOrderService.cs:1-68                                                                                      |
| **Compliance** | Full                                                                                                                                       |

### STD-003: Structured Logging with Trace Context

| Attribute      | Value                                                                                                                           |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| **Standard**   | All components use ILogger with structured properties and include TraceId correlation via ILogger.BeginScope()                  |
| **Evidence**   | Log entries include operation names, entity IDs, timing metrics, and trace context in every service, repository, and controller |
| **Source**     | src/eShop.Orders.API/Services/OrderService.cs:1-606                                                                             |
| **Compliance** | Full                                                                                                                            |

### STD-004: Health Check Implementation Pattern

| Attribute      | Value                                                                                                                                |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| **Standard**   | External dependencies monitored via IHealthCheck implementations with configurable timeouts and Healthy/Unhealthy/Degraded responses |
| **Evidence**   | DbContextHealthCheck (5s timeout, 3 status codes), ServiceBusHealthCheck (5s timeout, sender + batch verification)                   |
| **Source**     | src/eShop.Orders.API/HealthChecks/DbContextHealthCheck.cs:1-102                                                                      |
| **Compliance** | Full                                                                                                                                 |

### STD-005: Managed Identity for Azure Services

| Attribute      | Value                                                                                                                      |
| -------------- | -------------------------------------------------------------------------------------------------------------------------- |
| **Standard**   | Azure services authenticate using DefaultAzureCredential with managed identity, falling back to connection strings locally |
| **Evidence**   | Azure SQL uses Entra ID authentication, Service Bus uses managed identity, Application Insights uses connection string     |
| **Source**     | app.ServiceDefaults/Extensions.cs:1-347                                                                                    |
| **Compliance** | Full                                                                                                                       |

### STD-006: Code-First Database Management

| Attribute      | Value                                                                                                                              |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Standard**   | Database schema managed via EF Core code-first with Fluent API configuration, automatic migrations at startup with retry logic     |
| **Evidence**   | OnModelCreating configures indexes, cascade delete, and column constraints. Startup applies EnsureCreated with 10-retry, 10s delay |
| **Source**     | src/eShop.Orders.API/data/OrderDbContext.cs:1-136                                                                                  |
| **Compliance** | Full                                                                                                                               |

### STD-007: Resilience Pattern Application

| Attribute      | Value                                                                                                                                        |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| **Standard**   | All external integration points protected by configured resilience policies: retry with exponential backoff, circuit breakers, timeouts      |
| **Evidence**   | HTTP: Polly (3 retries, 120s circuit breaker), SQL: EF Core retry (5 retries, 30s max), Service Bus: exponential backoff (3 retries, 1s-10s) |
| **Source**     | app.ServiceDefaults/Extensions.cs:1-347                                                                                                      |
| **Compliance** | Full                                                                                                                                         |

---

## Section 8: Dependencies & Integration

### Overview

This section maps all service-to-service dependencies, data flows, external integrations, and event subscriptions identified across the Application layer. Every dependency referenced in Section 5 component specifications is consolidated here for cross-cutting visibility into the integration architecture.

The eShop Orders Management platform uses four primary integration patterns: synchronous request/response (HTTP/REST for API communication), asynchronous publish/subscribe (Azure Service Bus for event distribution), event-driven workflow orchestration (Azure Logic Apps for order processing), and platform-managed telemetry export (OTLP and Azure Monitor for observability). Each pattern is documented with its protocol, authentication method, resilience configuration, and error handling strategy.

The integration dependency graph reveals a layered flow: User → Blazor Frontend → Orders API → Database/Service Bus, with asynchronous branching via Logic App workflows that re-enter the API layer through HTTP callbacks. All synchronous integration points are protected by resilience policies (Polly retries, circuit breakers, EF Core retry strategies), while asynchronous paths rely on Service Bus platform guarantees and Logic App stateful workflow durability.

### Service-to-Service Call Graph

| Source Service                          | Target Service     | Protocol        | Direction    | Purpose                                                 |
| --------------------------------------- | ------------------ | --------------- | ------------ | ------------------------------------------------------- |
| eShop.Web.App                           | eShop.Orders.API   | HTTP/REST       | Synchronous  | Order CRUD operations via OrdersAPIService typed client |
| eShop.Orders.API                        | Azure SQL Database | TDS (EF Core)   | Synchronous  | Order data persistence via OrderRepository              |
| eShop.Orders.API                        | Azure Service Bus  | AMQP WebSockets | Asynchronous | Order event publishing to `ordersplaced` topic          |
| Logic App (OrdersPlacedProcess)         | eShop.Orders.API   | HTTP/REST       | Synchronous  | Order processing callback (POST /api/Orders/process)    |
| Logic App (OrdersPlacedProcess)         | Azure Blob Storage | REST            | Synchronous  | Store processed/error order results                     |
| Logic App (OrdersPlacedCompleteProcess) | Azure Blob Storage | REST            | Synchronous  | Cleanup processed order blobs                           |

### Database Dependencies

| Service          | Database            | Technology     | Access Pattern                                               | Connection Mode                             |
| ---------------- | ------------------- | -------------- | ------------------------------------------------------------ | ------------------------------------------- |
| eShop.Orders.API | OrderDb (Azure SQL) | EF Core 10.0.3 | Repository pattern (async, split queries, no-tracking reads) | Managed identity (Azure) / SQL auth (local) |

### External Service Integrations

| Service          | External System      | Protocol                 | Authentication                             | Purpose                      |
| ---------------- | -------------------- | ------------------------ | ------------------------------------------ | ---------------------------- |
| eShop.Orders.API | Azure Service Bus    | AMQP WebSockets          | DefaultAzureCredential / Connection string | Order event messaging        |
| eShop.Orders.API | Application Insights | OTLP / Azure Monitor SDK | Connection string                          | Telemetry export             |
| eShop.Web.App    | Application Insights | OTLP / Azure Monitor SDK | Connection string                          | Telemetry export             |
| Logic App        | Azure Service Bus    | Service Bus connector    | Managed connector auth                     | Event trigger (subscription) |
| Logic App        | Azure Blob Storage   | Blob Storage connector   | Managed connector auth                     | Order result persistence     |

### Event Subscription Map

| Event       | Publisher            | Topic/Queue          | Subscriber                    | Subscription       | Delivery                  |
| ----------- | -------------------- | -------------------- | ----------------------------- | ------------------ | ------------------------- |
| OrderPlaced | OrdersMessageHandler | ordersplaced (Topic) | Logic App OrdersPlacedProcess | orderprocessingsub | Auto-complete, 1s polling |

### Resilience Configuration Summary

| Integration         | Retry Policy                    | Circuit Breaker           | Timeout                     | Fallback                            |
| ------------------- | ------------------------------- | ------------------------- | --------------------------- | ----------------------------------- |
| Web → API (HTTP)    | 3 retries, exponential backoff  | 120s sampling, 5 failures | 60s per attempt, 600s total | None (exception propagation)        |
| API → SQL (EF Core) | 5 retries, 30s max delay        | Not configured            | 120s command timeout        | None (exception propagation)        |
| API → Service Bus   | 3 retries, exponential (1s-10s) | Not configured            | Platform defaults           | NoOpOrdersMessageHandler (dev mode) |
| DB Migration        | 10 retries, 10s delay           | Not applicable            | Not specified               | Application startup failure         |

### Integration Architecture Diagram

```mermaid
---
title: "eShop Orders Management — Integration & Data Flow"
config:
  theme: base
  look: classic
  layout: dagre
  themeVariables:
    fontSize: "16px"
---
flowchart LR
    accTitle: eShop Orders Management Integration and Data Flow Diagram
    accDescr: Shows service-to-service dependencies, data flows, and event subscriptions across the eShop Orders Management platform

    %% ═══════════════════════════════════════════════════════════════════════════
    %% AZURE / FLUENT ARCHITECTURE PATTERN v1.1
    %% (Semantic + Structural + Font + Accessibility Governance)
    %% ═══════════════════════════════════════════════════════════════════════════
    %% PHASE 1 - STRUCTURAL: Direction explicit, flat topology, nesting ≤ 3
    %% PHASE 2 - SEMANTIC: Colors justified, max 5 semantic classes, neutral-first
    %% PHASE 3 - FONT: Dark text on light backgrounds, contrast ≥ 4.5:1
    %% PHASE 4 - ACCESSIBILITY: accTitle/accDescr present, icons on all nodes
    %% PHASE 5 - STANDARD: Governance block present, classDefs centralized
    %% ═══════════════════════════════════════════════════════════════════════════

    subgraph Frontend["Frontend (Blazor Server)"]
        WebApp["🌐 eShop.Web.App"]
        OrdersAPIClient["📡 OrdersAPIService\n(Typed HttpClient)"]
    end

    subgraph Backend["Backend (ASP.NET Core API)"]
        Controller["🎯 OrdersController\n(REST API)"]
        Service["⚙️ OrderService\n(Business Logic)"]
        Repository["🗃️ OrderRepository\n(Data Access)"]
        MsgHandler["📨 OrdersMessageHandler\n(Event Publisher)"]
    end

    subgraph Data["Data Layer"]
        SQL["🗄️ Azure SQL\n(OrderDb)"]
    end

    subgraph Messaging["Messaging Layer"]
        SBTopic["📫 Service Bus Topic\n(ordersplaced)"]
        SBSub["📬 Subscription\n(orderprocessingsub)"]
    end

    subgraph Workflows["Logic App Workflows"]
        WF1["🔄 OrdersPlacedProcess"]
        WF2["🧹 OrdersPlacedCompleteProcess"]
    end

    subgraph Storage["Blob Storage"]
        BlobSuccess["✅ /ordersprocessedsuccessfully"]
        BlobError["❌ /ordersprocessedwitherrors"]
    end

    subgraph Observability["Observability"]
        AppInsights["📊 Application Insights"]
    end

    WebApp --> OrdersAPIClient
    OrdersAPIClient -->|"HTTP/REST\n(Polly Resilience)"| Controller
    Controller --> Service
    Service --> Repository
    Service --> MsgHandler
    Repository -->|"EF Core\n(Retry on Failure)"| SQL
    MsgHandler -->|"AMQP\n(3 retries)"| SBTopic
    SBTopic --> SBSub
    SBSub -->|"1s polling"| WF1
    WF1 -->|"HTTP POST"| Controller
    WF1 -->|"Success"| BlobSuccess
    WF1 -->|"Error"| BlobError
    WF2 -->|"3s recurrence"| BlobSuccess
    WebApp -.->|"OTLP"| AppInsights
    Controller -.->|"OTLP"| AppInsights

    style Frontend fill:#e1f0ff,stroke:#0078d4,color:#333
    style Backend fill:#e6f4ea,stroke:#107c10,color:#333
    style Data fill:#fff4e0,stroke:#ffb900,color:#333
    style Messaging fill:#fde7ef,stroke:#e3008c,color:#333
    style Workflows fill:#f3e8ff,stroke:#8661c5,color:#333
    style Storage fill:#fff0e0,stroke:#ff8c00,color:#333
    style Observability fill:#f0f0f0,stroke:#666,color:#333
```

### Summary

The integration architecture follows a layered request flow: User → Blazor Frontend → Orders API → Database/Service Bus, with asynchronous event processing via Logic App workflows. The messaging pattern decouples order creation from downstream processing, enabling independent scaling and failure isolation.

All synchronous integration points (HTTP and database) are protected by resilience policies. The Service Bus integration provides asynchronous decoupling with trace context propagation for end-to-end distributed tracing. Logic App workflows extend the processing pipeline into Azure PaaS territory, handling order result persistence and cleanup without requiring changes to the core application code.

---

## Section 9: Governance & Management

### Overview

This section documents the governance and management structures observed in the source code and project configuration. Governance aspects are inferred from project organization, configuration patterns, dependency management, and operational tooling rather than from explicit governance documentation.

The eShop Orders Management platform demonstrates implicit governance through its project structure (separated concerns across 4 .NET projects), shared configuration (ServiceDefaults enforces cross-cutting standards), and Azure resource management (Bicep infrastructure-as-code with parameterized deployments). No formal architecture governance board, ADR review process, or component lifecycle policy was detected in the source files.

The following subsections document the ownership model, change control approach, monitoring strategy, and lifecycle management practices as inferred from the repository structure and configuration files.

### Ownership Model

| Domain               | Owner (Inferred)     | Scope                                                     | Source                                                  |
| -------------------- | -------------------- | --------------------------------------------------------- | ------------------------------------------------------- |
| Orders API           | API Team             | OrdersController, OrderService, OrderRepository, Handlers | src/eShop.Orders.API/eShop.Orders.API.csproj:\*         |
| Web Frontend         | Frontend Team        | Blazor pages, OrdersAPIService, FluentDesignSystem        | src/eShop.Web.App/eShop.Web.App.csproj:\*               |
| Platform Services    | Platform Team        | ServiceDefaults, OpenTelemetry, resilience, health checks | app.ServiceDefaults/app.ServiceDefaults.csproj:\*       |
| Infrastructure       | DevOps/Platform Team | AppHost orchestration, Bicep templates, deployment hooks  | app.AppHost/AppHost.cs:1-290                            |
| Workflow Integration | Integration Team     | Logic App workflows, Service Bus topology                 | workflows/OrdersManagement/OrdersManagementLogicApp/_:_ |

### Change Control

| Aspect                   | Mechanism                                              | Source                                            |
| ------------------------ | ------------------------------------------------------ | ------------------------------------------------- |
| Version Control          | Git-based repository management                        | Repository root                                   |
| Infrastructure Changes   | Bicep infrastructure-as-code with parameterization     | infra/main.bicep:\*                               |
| Dependency Management    | NuGet package references with explicit versioning      | src/eShop.Orders.API/eShop.Orders.API.csproj:\*   |
| Configuration Management | appsettings.json with environment-specific overrides   | app.AppHost/appsettings.json:\*                   |
| Schema Management        | EF Core code-first with automatic migration at startup | src/eShop.Orders.API/data/OrderDbContext.cs:1-136 |

### Monitoring & Observability Governance

| Aspect                  | Implementation                                                           | Source                                              |
| ----------------------- | ------------------------------------------------------------------------ | --------------------------------------------------- |
| Distributed Tracing     | OpenTelemetry with ActivitySource per component                          | app.ServiceDefaults/Extensions.cs:44-163            |
| Custom Business Metrics | Meter-based counters and histograms (orders.placed, processing.duration) | src/eShop.Orders.API/Services/OrderService.cs:1-606 |
| Health Monitoring       | IHealthCheck implementations for DB and Service Bus (5s timeouts)        | src/eShop.Orders.API/HealthChecks/_:_               |
| Telemetry Export        | Dual export: OTLP (local/Aspire Dashboard) + Azure Monitor (production)  | app.ServiceDefaults/Extensions.cs:44-163            |
| SLO Tracking            | Not formalized — health checks provide basic availability signals        | Not detected                                        |

### Lifecycle Management

| Component             | Current Version | Support Status | Upgrade Path                             | Source                                                           |
| --------------------- | --------------- | -------------- | ---------------------------------------- | ---------------------------------------------------------------- |
| .NET Runtime          | 10.0            | Current (LTS)  | Standard .NET release cadence            | global.json:\*                                                   |
| Entity Framework Core | 10.0.3          | Current        | Aligned with .NET runtime                | src/eShop.Orders.API/eShop.Orders.API.csproj:17                  |
| Azure Service Bus SDK | 7.20.1          | Current        | Azure SDK release cadence                | app.ServiceDefaults/app.ServiceDefaults.csproj:13                |
| OpenTelemetry         | 1.15.0          | Current        | OpenTelemetry .NET release cadence       | app.ServiceDefaults/app.ServiceDefaults.csproj:17                |
| Fluent UI Blazor      | 4.14.0          | Current        | Microsoft FluentUI release cadence       | src/eShop.Web.App/eShop.Web.App.csproj:11                        |
| Logic Apps Runtime    | 1.x-2.0.0       | Current        | Azure Functions Extension Bundle updates | workflows/OrdersManagement/OrdersManagementLogicApp/host.json:\* |

### Deprecation & Feature Toggling

| Pattern                    | Implementation                                                                                        | Source                                                           |
| -------------------------- | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------- |
| Feature Toggle (Messaging) | NoOpOrdersMessageHandler provides development fallback when Service Bus is unavailable                | src/eShop.Orders.API/Handlers/NoOpOrdersMessageHandler.cs:1-65   |
| Environment Switching      | AppHost conditionally provisions local containers or Azure resources based on Azure:ResourceGroup key | app.AppHost/AppHost.cs:1-290                                     |
| Graceful Degradation       | Service Bus health check failure (Unhealthy) does not prevent API from serving read operations        | src/eShop.Orders.API/HealthChecks/ServiceBusHealthCheck.cs:1-183 |
