# TOGAF BDAT Model for Azure Logic Apps Standard Enterprise Monitoring Solution

## Executive Summary

This TOGAF Business-Data-Application-Technology (BDAT) model provides a comprehensive enterprise architecture framework for organizations deploying Azure Logic Apps Standard at scale. The model addresses critical operational challenges faced by enterprises managing thousands of workflows globally, including memory instability, hosting density optimization, and cost management that can reach US$80,000 annually per environment.

The solution implements a production-ready reference architecture aligned with the Azure Well-Architected Framework, providing proven patterns for workflow hosting density (~20 workflows per instance), comprehensive observability through OpenTelemetry and Application Insights, and support for long-running stateful workflows (18-36 months). The architecture leverages Azure Container Apps, Service Bus Premium, and .NET Aspire to deliver enterprise-grade monitoring, scalability, and operational excellence.

This BDAT model follows TOGAF Architecture Development Method (ADM) principles, mapping business capabilities to technology implementations while ensuring alignment with enterprise objectives for cost optimization, operational resilience, and developer productivity.

---

## 1. Business Architecture Layer

### Purpose
The Business Architecture layer defines the organizational capabilities, value streams, and business processes required to operate enterprise-scale Logic Apps deployments. It establishes the strategic foundation for workflow orchestration, order management, and operational monitoring aligned with business objectives.

### Key Capabilities
- **Workflow Orchestration**: Managing 1000+ stateful workflows with optimized hosting density
- **Order Processing**: End-to-end order lifecycle management from creation to fulfillment
- **Operational Monitoring**: Real-time observability and health tracking across distributed systems
- **Cost Governance**: Infrastructure optimization to prevent US$80,000+ annual cost overruns
- **Developer Productivity**: Streamlined local development and deployment workflows
- **Compliance Management**: Audit trails, diagnostic logging, and security controls

### Business Capability Map

```mermaid
graph TB
    subgraph "Strategic Capabilities"
        A1[Enterprise Workflow Management]
        A2[Cost Optimization]
        A3[Operational Excellence]
    end
    
    subgraph "Core Capabilities"
        B1[Order Management]
        B2[Workflow Orchestration]
        B3[Message Processing]
        B4[API Integration]
    end
    
    subgraph "Supporting Capabilities"
        C1[Monitoring & Observability]
        C2[Security & Compliance]
        C3[Developer Experience]
        C4[Scalability Management]
    end
    
    subgraph "Foundational Capabilities"
        D1[Identity Management]
        D2[Resource Provisioning]
        D3[Diagnostic Logging]
        D4[Health Checks]
    end
    
    style A1 fill:#E8F4F8
    style A2 fill:#E8F4F8
    style A3 fill:#E8F4F8
    style B1 fill:#E8F4F8
    style B2 fill:#E8F4F8
    style B3 fill:#E8F4F8
    style B4 fill:#E8F4F8
    style C1 fill:#E8F4F8
    style C2 fill:#E8F4F8
    style C3 fill:#E8F4F8
    style C4 fill:#E8F4F8
    style D1 fill:#E8F4F8
    style D2 fill:#E8F4F8
    style D3 fill:#E8F4F8
    style D4 fill:#E8F4F8
```

### Value Stream Map

```mermaid
graph LR
    A[Business Request] --> B[Order Creation]
    B --> C[Workflow Triggering]
    C --> D[Message Queueing]
    D --> E[Workflow Processing]
    E --> F[State Persistence]
    F --> G[Monitoring & Telemetry]
    G --> H[Order Fulfillment]
    H --> I[Business Value Delivered]
    
    style D fill:#FFE5CC
    style E fill:#FFE5CC
    style G fill:#FFE5CC
    
    classDef critical fill:#FFE5CC
```

**Key Value Steps:**
- **Message Queueing** (Bottleneck): Service Bus Premium ensures reliable message delivery with 16 messaging units
- **Workflow Processing** (Critical Path): Logic Apps Standard executes stateful workflows with optimized memory management
- **Monitoring & Telemetry** (Observability): Application Insights provides distributed tracing with OpenTelemetry

### Process Overview

#### Order Management Process
1. **Order Creation**: REST API receives order requests via `OrdersController`
2. **Validation**: Business logic validates order data with custom activity spans
3. **Message Publication**: Order events published to Service Bus queue (`orders-queue`)
4. **Workflow Triggering**: Logic Apps Standard workflows consume messages
5. **State Management**: Workflow state persisted to dedicated storage account
6. **Fulfillment**: Order processed through ConsosoOrders workflow
7. **Telemetry Collection**: Distributed traces sent to Application Insights

#### Monitoring Process
1. **Telemetry Ingestion**: OpenTelemetry collectors capture metrics, traces, and logs
2. **Data Aggregation**: Log Analytics workspace processes diagnostic data with 30-day retention
3. **Visualization**: Aspire Dashboard (local) or Application Insights (production) displays real-time metrics
4. **Alerting**: Azure Monitor alerts trigger on workflow failures, latency thresholds, or queue depth
5. **Cost Analysis**: Resource tags enable cost tracking by solution, environment, and business unit

---

## 2. Data Architecture Layer

### Purpose
The Data Architecture layer defines data storage strategies, event-driven topologies, and master data management patterns to support stateful workflows, telemetry collection, and operational analytics at enterprise scale.

### Key Capabilities
- **Event Stream Processing**: Asynchronous message handling through Service Bus Premium
- **Workflow State Management**: Persistent storage for long-running workflows (18-36 months)
- **Telemetry Data Lakes**: Centralized logging with Log Analytics workspace
- **Master Data Governance**: Unified order, customer, and workflow metadata
- **Diagnostic Data Retention**: 30-day retention with automated purge policies

### Master Data Management (MDM)

```mermaid
graph LR
    subgraph "Master Data Domains"
        A[Order Master Data]
        B[Customer Master Data]
        C[Workflow Master Data]
        D[Telemetry Master Data]
    end
    
    subgraph "Data Quality Layer"
        E[Validation Rules]
        F[Data Enrichment]
        G[Duplicate Detection]
    end
    
    subgraph "Data Governance"
        H[Access Control]
        I[Audit Trails]
        J[Retention Policies]
    end
    
    A --> E
    B --> E
    C --> E
    D --> E
    
    E --> F
    F --> G
    G --> H
    H --> I
    I --> J
    
    style A fill:#E8F4F8
    style B fill:#E8F4F8
    style C fill:#E8F4F8
    style D fill:#E8F4F8
    style E fill:#E8F4F8
    style F fill:#E8F4F8
    style G fill:#E8F4F8
    style H fill:#E8F4F8
    style I fill:#E8F4F8
    style J fill:#E8F4F8
```

### Event-Driven Data Topology

```mermaid
graph LR
    subgraph "Event Sources"
        A[Orders API]
        B[Blazor Web App]
        C[Logic Apps Workflows]
    end
    
    subgraph "Event Backbone"
        D[Service Bus Premium<br/>orders-queue]
    end
    
    subgraph "Event Consumers"
        E[ConsosoOrders Workflow]
        F[Tax Processing Workflow]
        G[External API Integrations]
    end
    
    subgraph "State Persistence"
        H[Workflow Storage Account<br/>ordersprocessedsuccessfully]
        I[Workflow Storage Account<br/>ordersprocessedwitherrors]
    end
    
    A -->|OrderCreated Event| D
    B -->|OrderUpdated Event| D
    D -->|Message Consumption| E
    D -->|Message Consumption| F
    E --> H
    E --> I
    F --> G
    
    style A fill:#E8F4F8
    style B fill:#E8F4F8
    style C fill:#E8F4F8
    style D fill:#E8F4F8
    style E fill:#E8F4F8
    style F fill:#E8F4F8
    style G fill:#E8F4F8
    style H fill:#E8F4F8
    style I fill:#E8F4F8
```

### Data Lake Architecture

```mermaid
graph LR
    subgraph "Ingestion Layer"
        A[OpenTelemetry Exporters]
        B[Azure Diagnostics]
        C[Application Logs]
    end
    
    subgraph "Processing Layer"
        D[Log Analytics Workspace]
        E[Application Insights]
    end
    
    subgraph "Storage Zones"
        F[Hot Storage<br/>30-day retention]
        G[Linked Storage<br/>Alerts & Query Results]
        H[Archive Storage<br/>Lifecycle Management]
    end
    
    subgraph "Governance Layer"
        I[RBAC Policies]
        J[Diagnostic Settings]
        K[Data Purge Rules]
    end
    
    A -->|Telemetry| D
    B -->|Diagnostics| D
    C -->|Structured Logs| E
    D --> F
    E --> F
    F --> G
    G --> H
    I --> D
    J --> E
    K --> F
    
    style A fill:#ADD8E6
    style B fill:#ADD8E6
    style C fill:#ADD8E6
    style D fill:#90EE90
    style E fill:#90EE90
    style F fill:#FFFACD
    style G fill:#FFFACD
    style H fill:#FFFACD
    style I fill:#D3D3D3
    style J fill:#D3D3D3
    style K fill:#D3D3D3
```

**Storage Accounts:**
- **Workflow Storage** (`messaging/main.bicep`): Standard_LRS for Logic Apps runtime
- **Logs Storage** (log-analytics-workspace.bicep): Diagnostic logs with 30-day lifecycle policy
- **Blob Containers**: Separate containers for successful orders and error handling

---

## 3. Application Architecture Layer

### Purpose
The Application Architecture layer defines the microservices, event-driven patterns, and integration topology that deliver order management, workflow orchestration, and observability capabilities across distributed systems.

### Key Capabilities
- **API Gateway Pattern**: RESTful API for order management with OpenAPI documentation
- **Event-Driven Workflows**: Stateful Logic Apps triggered by Service Bus messages
- **Distributed Tracing**: OpenTelemetry instrumentation with W3C Trace Context propagation
- **Resilience Patterns**: Circuit breakers, retries with exponential backoff, and health checks
- **Container Orchestration**: Serverless container hosting with elastic scaling

### Microservices Architecture

```mermaid
graph LR
    subgraph "Client Layer"
        A[Blazor Web App<br/>orders-webapp]
        B[External Clients]
    end
    
    subgraph "API Gateway"
        C[Orders API<br/>orders-api<br/>ASP.NET Core 10.0]
    end
    
    subgraph "Application Services"
        D[OrdersController<br/>CRUD Operations]
        E[ExternalApiClient<br/>HTTP Integrations]
    end
    
    subgraph "Workflow Services"
        F[Logic Apps Standard<br/>ConsosoOrders]
        G[Tax Processing Workflow]
    end
    
    subgraph "Data Services"
        H[Cosmos DB<br/>Order Persistence]
        I[Service Bus Queue<br/>orders-queue]
        J[Workflow Storage<br/>State Management]
    end
    
    A -->|HTTPS| C
    B -->|HTTPS| C
    C --> D
    D --> E
    D --> I
    I --> F
    I --> G
    F --> J
    D --> H
    
    style A fill:#ADD8E6
    style B fill:#ADD8E6
    style C fill:#DDA0DD
    style D fill:#90EE90
    style E fill:#90EE90
    style F fill:#90EE90
    style G fill:#90EE90
    style H fill:#FFFACD
    style I fill:#FFFACD
    style J fill:#FFFACD
```

**Service Components:**
- **orders-api**: `eShop.Orders.API` - ASP.NET Core API with Swagger/OpenAPI
- **orders-webapp**: `eShop.Orders.App` - Blazor Web UI with server-side rendering
- **ConsosoOrders**: `LogicAppWP/ConsosoOrders` - Stateful workflow orchestration

### Event-Driven Architecture (Flowchart)

```mermaid
graph LR
    subgraph "Event Producers"
        A[Orders API<br/>OrdersController]
        B[Logic Apps Workflows<br/>ConsosoOrders]
    end
    
    subgraph "Event Bus"
        C[Service Bus Premium<br/>orders-queue<br/>16 Messaging Units]
    end
    
    subgraph "Event Consumers"
        D[Workflow Engine<br/>Logic Apps Standard]
        E[Tax Processor<br/>External System]
    end
    
    subgraph "Analytics & Monitoring"
        F[Application Insights<br/>Distributed Tracing]
        G[Log Analytics<br/>Query Analytics]
    end
    
    A -->|OrderCreated| C
    C -->|Message Pull| D
    C -->|Message Pull| E
    D -->|Telemetry| F
    E -->|Telemetry| F
    F --> G
    B -->|OrderProcessed| C
    
    style A fill:#90EE90
    style B fill:#90EE90
    style C fill:#FFA07A
    style D fill:#90EE90
    style E fill:#90EE90
    style F fill:#FFFACD
    style G fill:#FFFACD
```

### Event-Driven Architecture (State Diagram)

```mermaid
stateDiagram-v2
    [*] --> OrderReceived: API Request
    
    OrderReceived --> MessageQueued: Publish to Service Bus
    MessageQueued --> WorkflowTriggered: Message Consumed
    
    WorkflowTriggered --> StateInitialized: Start Workflow Instance
    StateInitialized --> BusinessLogicExecution: Process Order
    
    BusinessLogicExecution --> SuccessfulProcessing: No Errors
    BusinessLogicExecution --> ErrorHandling: Validation Failed
    
    ErrorHandling --> DeadLetterQueue: Max Retries Exceeded
    ErrorHandling --> BusinessLogicExecution: Retry with Backoff
    
    SuccessfulProcessing --> StatePersisted: Write to Storage
    StatePersisted --> TelemetryEmitted: Send to App Insights
    TelemetryEmitted --> [*]: Complete
    
    DeadLetterQueue --> ManualIntervention: Human Review Required
    ManualIntervention --> [*]: Resolved
```

**Workflow Patterns:**
- **Stateful Execution**: Long-running workflows (18-36 months) with checkpointing
- **Error Handling**: Exponential backoff retries with dead-letter queue for failed messages
- **Context Propagation**: W3C Trace Context headers maintain correlation across service boundaries

---

## 4. Technology Architecture Layer

### Purpose
The Technology Architecture layer defines the Azure cloud infrastructure, platform services, and runtime environments that host and operate the enterprise Logic Apps solution with high availability, elastic scaling, and comprehensive monitoring.

### Key Capabilities
- **Infrastructure as Code**: Bicep templates for repeatable deployments across environments
- **Managed Identity**: Passwordless authentication using Azure AD workload identities
- **Elastic Scaling**: Auto-scale from 3-20 instances based on CPU, memory, and queue depth
- **Multi-Region Support**: Zone-redundant Service Bus Premium with geo-replication
- **Observability Stack**: OpenTelemetry exporters with Azure Monitor integration

### Technology Stack

#### Compute Services
- **Azure Container Apps** (`services/main.bicep`)
  - Consumption workload profile for API and Web App
  - Managed environment with Log Analytics integration
  - .NET Aspire dashboard component for observability
  
- **App Service Plan** (logic-app.bicep)
  - WorkflowStandard (WS1) SKU with elastic scaling
  - 3 minimum instances, 20 maximum instances
  - 64-bit worker process for memory-intensive workflows

#### Messaging & Integration
- **Service Bus Premium** (`messaging/main.bicep`)
  - 16 messaging units with 99.95% SLA
  - `orders-queue` with dead-letter queue support
  - Zone redundancy for high availability

#### Storage Services
- **Workflow Storage Account**: Standard_LRS for Logic Apps runtime state
- **Logs Storage Account**: Diagnostic logs with lifecycle management (30-day retention)
- **Blob Containers**: Separate containers for success/error order processing

#### Monitoring & Observability
- **Application Insights** (app-insights.bicep)
  - Workspace-based integration with Log Analytics
  - OpenTelemetry protocol exporters
  - Connection string: `APPLICATIONINSIGHTS_CONNECTION_STRING`

- **Log Analytics Workspace** (log-analytics-workspace.bicep)
  - PerGB2018 pricing tier
  - 30-day retention with immediate purge
  - Linked storage accounts for alerts and query results

- **.NET Aspire Dashboard**
  - Local development observability (https://localhost:7074)
  - Real-time traces, metrics, logs, and health checks

#### Container Services
- **Azure Container Registry** (`services/main.bicep`)
  - Premium SKU for geo-replication
  - Managed identity authentication
  - Diagnostic settings for audit logging

#### Security & Identity
- **User-Assigned Managed Identity** (`identity/main.bicep`)
  - Role assignments: Storage Account Contributor, Monitoring Metrics Publisher, Service Bus Data Owner
  - Passwordless authentication across all services
  - Client ID: `AZURE_CLIENT_ID`

### Deployment Architecture

```mermaid
graph TB
    subgraph "Developer Workstation"
        A[Azure Developer CLI<br/>azd]
        B[Docker Desktop]
        C[.NET 10 SDK]
    end
    
    subgraph "CI/CD Pipeline"
        D[Bicep Compilation]
        E[Container Image Build]
        F[Infrastructure Provisioning]
    end
    
    subgraph "Azure Subscription"
        G[Resource Group<br/>rg-orders-dev-eastus]
    end
    
    subgraph "Monitoring Stack"
        H[Log Analytics Workspace]
        I[Application Insights]
        J[Storage Account<br/>Logs]
    end
    
    subgraph "Compute Layer"
        K[Container Apps Environment]
        L[Container Registry<br/>Premium]
        M[App Service Plan<br/>WS1]
    end
    
    subgraph "Data Layer"
        N[Service Bus Premium<br/>orders-queue]
        O[Workflow Storage<br/>Standard_LRS]
    end
    
    subgraph "Identity Layer"
        P[Managed Identity]
    end
    
    A --> D
    B --> E
    D --> F
    E --> F
    F --> G
    
    G --> H
    G --> I
    G --> J
    G --> K
    G --> L
    G --> M
    G --> N
    G --> O
    G --> P
    
    P --> K
    P --> L
    P --> M
    P --> N
    
    K --> I
    M --> I
    N --> H
    
    style A fill:#E8F4F8
    style B fill:#E8F4F8
    style C fill:#E8F4F8
    style D fill:#90EE90
    style E fill:#90EE90
    style F fill:#90EE90
    style G fill:#FFFACD
    style H fill:#ADD8E6
    style I fill:#ADD8E6
    style J fill:#ADD8E6
    style K fill:#DDA0DD
    style L fill:#DDA0DD
    style M fill:#DDA0DD
    style N fill:#FFA07A
    style O fill:#FFA07A
    style P fill:#D3D3D3
```

### OpenTelemetry Instrumentation

#### Configured Exporters (Extensions.cs)
- **OTLP Exporter**: Aspire Dashboard (development)
- **Azure Monitor Exporter**: Application Insights (production)

#### Instrumented Components
- **ASP.NET Core**: Request duration, active requests, failed requests
- **HTTP Client**: Outbound request duration, failures, retries
- **Runtime Metrics**: GC collections, thread pool queue length, exception counts
- **Service Bus**: Message processing spans with correlation IDs

#### Trace Context Propagation
- **W3C Trace Context**: `traceparent` and `tracestate` headers
- **Activity Source**: `eShop.Orders` (`Extensions.cs:34`)
- **Custom Spans**: Business logic instrumentation in `OrdersController`

---

## 5. Complete TOGAF BDAT Diagram

```mermaid
graph TB
    subgraph "Business Layer"
        B1[Enterprise Workflow Management]
        B2[Order Management]
        B3[Operational Excellence]
        B4[Cost Governance]
    end
    
    subgraph "Data Layer"
        D1[Event Streams<br/>Service Bus]
        D2[Workflow State<br/>Storage Account]
        D3[Telemetry Data Lake<br/>Log Analytics]
        D4[Master Data<br/>Order Metadata]
    end
    
    subgraph "Application Layer"
        A1[Orders API<br/>ASP.NET Core]
        A2[Orders Web App<br/>Blazor]
        A3[Logic Apps Standard<br/>ConsosoOrders]
        A4[External Integrations<br/>HTTP Clients]
    end
    
    subgraph "Technology Layer"
        T1[Container Apps<br/>Consumption Profile]
        T2[App Service Plan<br/>WS1 Elastic]
        T3[Service Bus Premium<br/>16 MU]
        T4[Application Insights<br/>OpenTelemetry]
        T5[Managed Identity<br/>RBAC]
        T6[Container Registry<br/>Premium]
    end
    
    B1 -->|Defines Requirements| D1
    B2 -->|Drives Data Models| D4
    B3 -->|Monitors Through| D3
    B4 -->|Optimizes| T2
    
    D1 -->|Feeds| A3
    D2 -->|Persists| A3
    D3 -->|Analyzes| A1
    D4 -->|Validates| A1
    
    A1 -->|Publishes Events| D1
    A2 -->|Consumes API| A1
    A3 -->|Reads State| D2
    A4 -->|Integrates| A1
    
    T1 -->|Hosts| A1
    T1 -->|Hosts| A2
    T2 -->|Hosts| A3
    T3 -->|Delivers| D1
    T4 -->|Collects| D3
    T5 -->|Authenticates| T1
    T5 -->|Authenticates| T2
    T5 -->|Authenticates| T3
    T6 -->|Stores Images| T1
    
    style B1 fill:#E6F3FF
    style B2 fill:#E6F3FF
    style B3 fill:#E6F3FF
    style B4 fill:#E6F3FF
    style D1 fill:#FFF4E6
    style D2 fill:#FFF4E6
    style D3 fill:#FFF4E6
    style D4 fill:#FFF4E6
    style A1 fill:#E6FFE6
    style A2 fill:#E6FFE6
    style A3 fill:#E6FFE6
    style A4 fill:#E6FFE6
    style T1 fill:#FFE6F0
    style T2 fill:#FFE6F0
    style T3 fill:#FFE6F0
    style T4 fill:#FFE6F0
    style T5 fill:#FFE6F0
    style T6 fill:#FFE6F0
```

---

## 6. Scalability Considerations

### Hosting Density Best Practices
- **Proven Limit**: 20 workflows per Logic App instance for stable operation
- **Maximum Density**: Up to 64 apps per App Service Plan (WS1 tier)
- **Memory Management**: 64-bit worker process to prevent memory spikes exceeding 80%

### Elastic Scaling Configuration
- **App Service Plan** (`logic-app.bicep:96`):
  - Minimum instances: 3 (high availability)
  - Maximum instances: 20 (elastic worker count)
  - Scale triggers: CPU > 70%, Memory > 80%, Queue depth > 1000 messages

- **Container Apps**:
  - Consumption profile for pay-per-use scaling
  - Min replicas: 1, Max replicas: 10
  - Scale on HTTP requests and Service Bus queue length

### Cost Optimization
- **Development**: ~US$777/month (free Logic Apps tier, minimal Service Bus)
- **Production**: ~US$4,531/month (WS1 plan, Premium Service Bus, Container Apps)
- **Savings Strategies**:
  - Auto-scale down during off-hours (50% cost reduction)
  - 30-day log retention (reduced storage costs)
  - Reserved capacity for predictable workloads (30% discount)

---

## 7. Monitoring & Governance

### Observability Strategy
- **Metrics**: ASP.NET Core, HTTP client, runtime, Service Bus message processing
- **Traces**: Distributed tracing with W3C Trace Context across all service boundaries
- **Logs**: Structured logging with OpenTelemetry, 30-day retention in Log Analytics

### Diagnostic Settings (main.bicep)
All resources emit diagnostic logs and metrics:
- **Service Bus**: Operational logs, runtime audit logs
- **Logic Apps**: Workflow runtime, execution history
- **Container Registry**: Repository events, authentication logs
- **Storage Accounts**: Blob operations, transaction metrics

### Health Checks
- **Endpoints** (`Extensions.cs:342`):
  - `/health` - Readiness check for orchestrators
  - `/alive` - Liveness check for container restarts
- **Checks**: Self-health, Service Bus connectivity, storage availability

### Alerting Thresholds
- **Workflow Failures**: > 5% failure rate triggers email alert
- **API Latency**: P95 > 2 seconds triggers investigation
- **Service Bus Dead Letters**: > 100 messages triggers manual review
- **Container Memory**: > 80% usage triggers scale-out

---

## 8. Compliance & Security

### Azure Well-Architected Framework Alignment
- **Reliability**: Zone-redundant Service Bus, multi-instance deployments
- **Security**: Managed identity for passwordless authentication, TLS 1.2+ enforcement
- **Cost Optimization**: Right-sized resources with elastic scaling
- **Operational Excellence**: Infrastructure as Code, diagnostic settings, automated deployments
- **Performance Efficiency**: Premium SKUs for Service Bus and Container Registry

### Role-Based Access Control (`identity/main.bicep:87`)
Managed identity assigned roles:
- Storage Account Contributor (17d1049b-9a84-46fb-8f53-869881c3d3ab)
- Monitoring Metrics Publisher (3913510d-42f4-4e42-8a64-420c390055eb)
- Application Insights Component Contributor (ae349356-3a1b-4a5e-921d-050484c6347e)
- Service Bus Data Owner (090c5cfd-751d-490a-894a-3ce6f1109419)

### Audit & Compliance
- **Resource Tags** (types.bicep):
  - Solution: Orders
  - Environment: dev/staging/prod
  - CostCenter: Engineering
  - Owner: Platform-Team
  - DeploymentDate: UTC timestamp
- **Diagnostic Retention**: 30-day retention with lifecycle management
- **Linked Storage**: Alerts and query results stored for compliance audits

---

## 9. References

### TOGAF Standards
- [TOGAF 10 Enterprise Edition](https://publications.opengroup.org/standards/togaf/c220) - Architecture Development Method
- [TOGAF Content Metamodel](https://publications.opengroup.org/standards/togaf/c228) - BDAT Layer Definitions

### Microsoft Learn Guidance
- [Azure Well-Architected Framework - Instrument Applications](https://learn.microsoft.com/azure/well-architected/operational-excellence/instrument-application)
- [Monitor Logic Apps](https://learn.microsoft.com/azure/logic-apps/monitor-logic-apps)
- [OpenTelemetry with Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-overview)
- [.NET Aspire Dashboard](https://learn.microsoft.com/dotnet/aspire/fundamentals/dashboard/overview)

### Workspace Artifacts
- Infrastructure: main.bicep
- Service Defaults: Extensions.cs
- API Controller: OrderController.cs
- AppHost: AppHost.cs

---

**Document Version**: 1.0.0  
**Last Updated**: 2025-01-XX  
**TOGAF Framework Version**: 10.0  
**Compliance**: Azure Well-Architected Framework aligned