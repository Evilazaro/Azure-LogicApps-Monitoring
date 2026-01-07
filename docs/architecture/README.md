# Architecture Overview

## 1. Executive Summary

The Azure Logic Apps Monitoring Solution demonstrates comprehensive observability patterns for event-driven distributed applications. This reference architecture addresses operational visibility challenges across microservices, message-driven workflows, and serverless compute while using an eShop order management domain as the business context.

The solution delivers measurable operational value by reducing mean time to resolution through W3C-standard distributed tracing, enabling proactive failure detection through integrated health monitoring, and eliminating secrets management through Azure Managed Identity. OpenTelemetry provides vendor-neutral instrumentation, while .NET Aspire enables local development without cloud dependencies.

**Key Architectural Decisions:**

1. **.NET Aspire Orchestration**: Dual-mode operation supporting local emulators for development and Azure services for production without code changes
2. **Zero-Secrets Architecture**: User-Assigned Managed Identity for all service-to-service authentication eliminates connection strings from code and configuration
3. **Event-Driven Decoupling**: Service Bus topics enable asynchronous communication between Orders API and Logic Apps workflows
4. **Modular Infrastructure**: Subscription-scoped Bicep templates separate shared infrastructure (identity, monitoring, data) from workload resources (messaging, compute, workflows)
5. **Observability First**: OpenTelemetry SDK with W3C Trace Context propagation across HTTP, SQL, and Service Bus boundaries

**Target Deployment Environments:**  
Azure regions worldwide with single-region deployment in reference implementation, extensible to multi-region active-active topologies.

## 2. High-Level Architecture Diagram

```mermaid
flowchart TD
    subgraph Actors["User Layer"]
        WebUser[Web User]
        APIUser[API Consumer]
    end

    subgraph CoreServices["Core Business Services"]
        WebApp[Web Application]
        OrdersAPI[Orders API]
        LogicWorkflow[Logic Apps Workflows]
    end

    subgraph SupportServices["Supporting Services"]
        SQL[(SQL Database)]
        ServiceBus[Service Bus]
        BlobStorage[Blob Storage]
    end

    subgraph Observability["Observability Services"]
        AppInsights[Application Insights]
        LogAnalytics[Log Analytics]
    end

    WebUser --> WebApp
    APIUser --> OrdersAPI
    WebApp --> OrdersAPI
    OrdersAPI --> SQL
    OrdersAPI --> ServiceBus
    ServiceBus --> LogicWorkflow
    LogicWorkflow --> OrdersAPI
    LogicWorkflow --> BlobStorage

    WebApp -.telemetry.-> AppInsights
    OrdersAPI -.telemetry.-> AppInsights
    LogicWorkflow -.telemetry.-> AppInsights
    AppInsights --> LogAnalytics

    classDef actorStyle fill:#E8EAF6,stroke:#3F51B5,stroke-width:2px,color:#000
    classDef coreStyle fill:#E1F5FF,stroke:#0277BD,stroke-width:2px,color:#000
    classDef supportStyle fill:#F1F8E9,stroke:#558B2F,stroke-width:2px,color:#000
    classDef observeStyle fill:#FFF9C4,stroke:#F57F17,stroke-width:2px,color:#000

    class WebUser,APIUser actorStyle
    class WebApp,OrdersAPI,LogicWorkflow coreStyle
    class SQL,ServiceBus,BlobStorage supportStyle
    class AppInsights,LogAnalytics observeStyle
| Component | Type | Key Responsibilities | Technology Stack |
|-----------|------|---------------------|------------------|
| **Orders API** | REST API | Order CRUD, validation, Service Bus publishing | ASP.NET Core 10, EF Core, OpenTelemetry |
| **Web App** | User Interface | Customer order management, real-time updates | Blazor Server, SignalR, Fluent UI |
| **Logic Apps Workflows** | Workflow Engine | Event-driven order processing, enrichment | Logic Apps Standard (App Service Plan) |
| **SQL Database** | Relational Database | Order persistence, ACID transactions | Azure SQL Database (serverless) |
| **Service Bus** | Message Broker | Async messaging, pub/sub topics | Azure Service Bus (Standard tier) |
| **Application Insights** | APM | Distributed tracing, metrics, logs | OpenTelemetry Protocol receiver |
| **Managed Identity** | Identity Provider | Zero-secrets authentication | User-Assigned Managed Identity |
| **Container Apps** | Compute | Serverless container hosting | Azure Container Apps |
| **.NET Aspire** | Orchestration | Local development, service discovery | .NET Aspire 9.x |

## 4. Document Navigation

This architecture documentation follows the TOGAF Building Blocks for Distributed Applications (BDAT) framework, organizing content into four logical layers with supporting cross-cutting documents.

### Recommended Reading Order

**For Executives and Enterprise Architects:**

1. README.md (this document) - Executive summary and system context
2. [Business Architecture](01-business-architecture.md) - Business capabilities and value streams
3. [Security Architecture](06-security-architecture.md) - Security controls and compliance

**For Solution Architects:**

1. README.md - System context and high-level design
2. [Business Architecture](01-business-architecture.md) - Requirements and quality attributes
3. [Application Architecture](03-application-architecture.md) - Service design and integration patterns
4. [Data Architecture](02-data-architecture.md) - Data flows and persistence patterns
5. [Technology Architecture](04-technology-architecture.md) - Technology stack and deployment topology

**For Platform Engineers and DevOps:**

1. [Technology Architecture](04-technology-architecture.md) - Infrastructure components
2. [Deployment Architecture](07-deployment-architecture.md) - CI/CD pipelines and deployment patterns
3. [Security Architecture](06-security-architecture.md) - Security tooling and practices

**For Application Developers:**

1. [Application Architecture](03-application-architecture.md) - Service contracts and APIs
2. [Data Architecture](02-data-architecture.md) - Data models and access patterns
3. [Observability Architecture](05-observability-architecture.md) - Instrumentation and monitoring

### BDAT Layer Documents

| Layer           | Document                                                         | Focus Areas                                                                         |
| --------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| **Business**    | [01-business-architecture.md](01-business-architecture.md)       | Business capabilities, stakeholder concerns, value streams, quality attributes      |
| **Data**        | [02-data-architecture.md](02-data-architecture.md)               | Data domains, ownership, flows, telemetry mapping, persistence patterns             |
| **Application** | [03-application-architecture.md](03-application-architecture.md) | Service boundaries, integration patterns, API contracts, workflow design            |
| **Technology**  | [04-technology-architecture.md](04-technology-architecture.md)   | Technology stack, infrastructure components, deployment topology, capacity planning |

### Cross-Cutting Concern Documents

| Concern           | Document                                                             | Scope                                                                                  |
| ----------------- | -------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| **Observability** | [05-observability-architecture.md](05-observability-architecture.md) | Telemetry instrumentation, trace propagation, metrics, logging, alerting               |
| **Security**      | [06-security-architecture.md](06-security-architecture.md)           | Identity management, secrets handling, network security, compliance                    |
| **Deployment**    | [07-deployment-architecture.md](07-deployment-architecture.md)       | CI/CD pipelines, infrastructure automation, environment promotion, rollback strategies |

## 5. Quick Reference

### Key Platform Resources

| Resource Category | Primary Services                                                 | Purpose                                    |
| ----------------- | ---------------------------------------------------------------- | ------------------------------------------ |
| **Compute**       | Azure Container Apps, Logic Apps Standard (App Service Plan WS1) | Application hosting and workflow execution |
| **Data**          | Azure SQL Database (serverless tier), Blob Storage               | Transactional data and artifact storage    |
| **Messaging**     | Azure Service Bus (Standard tier with topics)                    | Asynchronous event-driven communication    |
| **Observability** | Application Insights, Log Analytics Workspace                    | Telemetry collection and analysis          |
| **Identity**      | User-Assigned Managed Identity                                   | Service authentication without secrets     |
| **Networking**    | Virtual Network integration, Private Endpoints (optional)        | Network isolation and secure communication |
| **Development**   | Azure Container Registry, .NET Aspire orchestration              | Container management and local development |

### Repository Structure

```

├── app.AppHost/ # .NET Aspire orchestration host
│ └── AppHost.cs # Service configuration and dependency orchestration
├── app.ServiceDefaults/ # Shared cross-cutting concerns library
│ ├── Extensions.cs # OpenTelemetry, health checks, resilience
│ └── CommonTypes.cs # Shared domain models (Order, OrderProduct)
├── src/
│ ├── eShop.Orders.API/ # Order management REST API
│ │ ├── Controllers/ # API endpoints (CRUD operations)
│ │ ├── Services/ # Business logic with observability
│ │ ├── Repositories/ # EF Core data access layer
│ │ ├── Data/ # DbContext and entity configurations
│ │ ├── Handlers/ # Service Bus message publishing
│ │ └── HealthChecks/ # Custom health check implementations
│ └── eShop.Web.App/ # Blazor Server frontend
│ ├── Components/ # Razor components and pages
│ │ ├── Pages/ # Routable UI pages
│ │ └── Services/ # HTTP client services with Polly
│ └── Shared/ # Shared UI components
├── workflows/
│ └── OrdersManagement/
│ └── OrdersManagementLogicApp/
│ ├── OrdersPlacedProcess/ # Service Bus trigger workflow
│ │ └── workflow.json # Workflow definition
│ ├── OrdersPlacedCompleteProcess/ # Completion workflow
│ │ └── workflow.json
│ └── connections.json # Managed Identity API connections
├── infra/ # Infrastructure as Code (Bicep)
│ ├── main.bicep # Subscription-scope orchestrator
│ ├── types.bicep # Shared type definitions
│ ├── shared/ # Shared infrastructure
│ │ ├── identity/ # Managed Identity and role assignments
│ │ ├── monitoring/ # Log Analytics, Application Insights
│ │ └── data/ # Storage accounts, SQL Server
│ └── workload/ # Workload infrastructure
│ ├── messaging/ # Service Bus namespace and topics
│ ├── services/ # Container Registry, Container Apps Environment
│ └── logic-app.bicep # Logic Apps Standard deployment
├── hooks/ # azd lifecycle automation scripts
│ ├── preprovision.ps1 # Pre-deployment validation
│ ├── postprovision.ps1 # Secret configuration
│ ├── sql-managed-identity-config.ps1 # Database Entra ID setup
│ ├── deploy-workflow.ps1 # Logic Apps deployment
│ └── Generate-Orders.ps1 # Test data generation
├── docs/
│ ├── architecture/ # This directory - TOGAF BDAT documentation
│ └── hooks/ # Developer workflow guides
└── azure.yaml # Azure Developer CLI configuration

```

### Folder Descriptions

| Folder                   | Contents                           | Purpose                                                                                                |
| ------------------------ | ---------------------------------- | ------------------------------------------------------------------------------------------------------ |
| **app.AppHost**          | Aspire orchestration configuration | Defines service dependencies, Azure resource connections, and local/Azure deployment modes             |
| **app.ServiceDefaults**  | Cross-cutting concern library      | OpenTelemetry instrumentation, health checks, HTTP resilience, Service Bus client factory              |
| **src/eShop.Orders.API** | Order management microservice      | REST API for CRUD operations, EF Core persistence, Service Bus publishing, comprehensive observability |
| **src/eShop.Web.App**    | Customer-facing UI                 | Blazor Server with SignalR, Fluent UI components, typed HTTP clients with Polly resilience             |
| **workflows**            | Logic Apps Standard definitions    | Stateful workflows with Service Bus triggers, HTTP actions, Blob storage output                        |
| **infra/shared**         | Foundational infrastructure        | Identity, monitoring, and data resources shared across workloads                                       |
| **infra/workload**       | Application-specific resources     | Messaging, container services, and Logic Apps specific to this solution                                |
| **hooks**                | Deployment automation              | Cross-platform scripts for validation, configuration, and data seeding                                 |
| **docs**                 | Comprehensive documentation        | Architecture guides, developer workflows, script references, deployment procedures                     |

---

**Document Version:** 1.0.0
**Last Updated:** 2026-01-07
**Maintained By:** Platform Engineering Team
**Review Cycle:** Quarterly or upon significant architectural changes
```
