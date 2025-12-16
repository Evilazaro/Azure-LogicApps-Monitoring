# TOGAF BDAT Model: Azure Logic Apps Monitoring Solution

## Executive Summary

### Project Overview

Enterprise organizations deploying Azure Logic Apps Standard at scale face critical challenges related to workflow density, resource optimization, and operational cost management. Current deployments have demonstrated annual operational costs approaching US$80,000 per environment, driven by suboptimal hosting patterns, inefficient resource allocation, and inadequate monitoring infrastructure. The primary technical challenges include managing workflow density without triggering memory saturation, implementing effective observability across distributed workflows, and maintaining system stability for long-running business processes spanning 18-36 months.

This solution addresses these enterprise-scale challenges through a comprehensive monitoring and orchestration architecture built on .NET Aspire, Azure Container Apps, and Azure Logic Apps Standard. The architecture implements TOGAF principles across Business, Data, Application, and Technology layers to deliver optimal hosting density, comprehensive distributed tracing with OpenTelemetry, and cost-effective resource utilization patterns aligned with the Azure Well-Architected Framework.

The solution demonstrates a reference implementation for orders processing workflows, incorporating Service Bus messaging, Application Insights telemetry, Container Apps hosting infrastructure, and a Blazor-based management interface. This implementation serves as a template for enterprise organizations seeking to optimize Logic Apps deployments while maintaining operational excellence, security, and cost efficiency at scale.

---

## 1. Business Architecture

### Purpose
The Business Architecture layer defines the organizational capabilities, business processes, and value streams required to deliver reliable, scalable, and cost-effective workflow orchestration for enterprise operations. This layer establishes the strategic context for Logic Apps deployment patterns, monitoring strategies, and operational cost optimization.

### Key Capabilities
- **Workflow Orchestration Management**: Coordinate and execute long-running business processes (18-36 months) with reliability guarantees
- **Order Processing Operations**: Handle end-to-end order lifecycle from creation through fulfillment with distributed tracing
- **Message-Driven Integration**: Enable asynchronous communication patterns across enterprise systems using Service Bus
- **Operational Monitoring**: Provide real-time visibility into workflow execution, resource utilization, and system health
- **Cost Optimization**: Implement resource efficiency patterns to reduce operational expenses while maintaining service levels
- **Developer Productivity**: Accelerate development cycles through standardized service defaults and tooling integration

### Business Capability Map

```mermaid
flowchart LR
    BC[Business Capabilities]
    
    BC --> WM[Workflow Management]
    BC --> OM[Order Management]
    BC --> IM[Integration Management]
    BC --> MM[Monitoring Management]
    BC --> CM[Cost Management]
    BC --> DM[Development Management]
    
    WM --> WO[Workflow Orchestration]
    WM --> WE[Workflow Execution]
    WM --> WL[Workflow Lifecycle]
    
    OM --> OC[Order Creation]
    OM --> OP[Order Processing]
    OM --> OT[Order Tracking]
    
    IM --> MI[Message Integration]
    IM --> EI[Event Integration]
    IM --> AI[API Integration]
    
    MM --> OB[Observability]
    MM --> TR[Tracing]
    MM --> AL[Alerting]
    
    CM --> RO[Resource Optimization]
    CM --> CO[Cost Optimization]
    CM --> SC[Scaling]
    
    DM --> SD[Service Defaults]
    DM --> TE[Tooling]
    DM --> CI[CI/CD]
    
    style BC fill:#87CEEB
    style WM fill:#87CEEB
    style OM fill:#87CEEB
    style IM fill:#87CEEB
    style MM fill:#87CEEB
    style CM fill:#87CEEB
    style DM fill:#87CEEB
    style WO fill:#87CEEB
    style WE fill:#87CEEB
    style WL fill:#87CEEB
    style OC fill:#87CEEB
    style OP fill:#87CEEB
    style OT fill:#87CEEB
    style MI fill:#87CEEB
    style EI fill:#87CEEB
    style AI fill:#87CEEB
    style OB fill:#87CEEB
    style TR fill:#87CEEB
    style AL fill:#87CEEB
    style RO fill:#87CEEB
    style CO fill:#87CEEB
    style SC fill:#87CEEB
    style SD fill:#87CEEB
    style TE fill:#87CEEB
    style CI fill:#87CEEB
```

### Value Stream Map

```mermaid
flowchart LR
    VS[Order Value Stream]
    
    VS --> S1[Order Request]
    S1 --> S2[API Ingestion]
    S2 --> S3[Message Queuing]
    S3 --> S4[Workflow Processing]
    S4 --> S5[State Persistence]
    S5 --> S6[Event Publishing]
    S6 --> S7[Order Fulfillment]
    
    S2 -.->|Telemetry| MON[Monitoring]
    S3 -.->|Tracing| MON
    S4 -.->|Metrics| MON
    S5 -.->|Logs| MON
    
    style VS fill:#D3D3D3
    style S1 fill:#D3D3D3
    style S2 fill:#D3D3D3
    style S3 fill:#D3D3D3
    style S4 fill:#FFD700
    style S5 fill:#D3D3D3
    style S6 fill:#D3D3D3
    style S7 fill:#D3D3D3
    style MON fill:#FFD700
```

**Note**: Step S4 (Workflow Processing) and MON (Monitoring) are highlighted as key value-creation steps where optimization directly impacts business outcomes and operational costs.

### Process Architecture

**Primary Business Processes:**

1. **Order Lifecycle Management**
   - Order creation via API endpoint
   - Message-based workflow triggering through Service Bus
   - Distributed order processing with state management
   - Order status tracking and customer notification
   - Error handling and retry policies

2. **Monitoring and Observability**
   - Distributed trace collection via OpenTelemetry
   - Metrics aggregation in Application Insights
   - Log centralization in Log Analytics workspace
   - Health check monitoring for service availability
   - Alert generation for SLA violations

3. **Infrastructure Operations**
   - Container deployment to Azure Container Apps
   - Elastic scaling based on workload demands
   - Service discovery and resilience patterns
   - Managed identity authentication
   - Resource lifecycle management

---

## 2. Data Architecture

### Purpose
The Data Architecture layer defines data structures, data flows, master data management patterns, and event-driven data integration required to support workflow orchestration, telemetry collection, and operational analytics. This layer ensures data consistency, traceability, and compliance across distributed systems.

### Key Capabilities
- **Telemetry Data Management**: Collect, aggregate, and store distributed traces, metrics, and logs from all application components
- **Message Data Persistence**: Maintain message payloads and metadata in Service Bus queues with reliability guarantees
- **Workflow State Management**: Track workflow execution state across long-running processes with durability
- **Master Data Synchronization**: [MISSING COMPONENT - No explicit master data hub identified in workspace]
- **Event Data Streaming**: Propagate order events and system events through message-based topology
- **Diagnostic Data Storage**: Archive logs and metrics in storage accounts with lifecycle policies

### Master Data Management (MDM)

**Note**: The current workspace does not implement an explicit Master Data Management hub. Order data is managed within individual services without a central mastering authority. This represents a potential architecture gap for enterprise-scale deployments requiring canonical data models.

```mermaid
flowchart LR
    subgraph MDM["[MISSING COMPONENT] Master Data Hub"]
        MDH[Master Data Registry]
    end
    
    API[Orders API]
    DB[(In-Memory Order Store)]
    SB[Service Bus]
    
    API -->|Publish| SB
    SB -->|Consume| WF[Workflow Handler]
    WF -->|Update| DB
    
    MDH -.->|"[Future] Sync"| API
    MDH -.->|"[Future] Sync"| WF
    
    style MDM fill:#FFB6C1,stroke-dasharray: 5 5
    style MDH fill:#FFB6C1,stroke-dasharray: 5 5
```

**Gap Analysis**: The workspace implements a distributed data model without centralized master data governance. Future enhancements should consider implementing a canonical order model with bi-directional synchronization patterns.

### Event-Driven Data Topology

```mermaid
flowchart LR
    subgraph Producers
        API[Orders API]
        WF[Workflow Engine]
    end
    
    subgraph Event Bus
        SB[Service Bus Queue: orders-queue]
    end
    
    subgraph Consumers
        MH[Message Handler]
        LA[Logic App]
    end
    
    subgraph Storage
        BS[Blob: ordersprocessedsuccessfully]
        BF[Blob: ordersprocessedwitherrors]
        QS[Queue Storage]
    end
    
    API -->|OrderCreated| SB
    SB -->|Process| MH
    SB -->|Process| LA
    MH -->|Success| BS
    MH -->|Failure| BF
    LA -->|Task Queue| QS
    
    style API fill:#90EE90
    style WF fill:#90EE90
    style SB fill:#FFA500
    style MH fill:#90EE90
    style LA fill:#90EE90
    style BS fill:#F0E68C
    style BF fill:#F0E68C
    style QS fill:#F0E68C
```

### Monitoring Data Flow

```mermaid
flowchart LR
    subgraph Sources["Data Sources"]
        API[Orders API]
        APP[Orders App]
        LA[Logic App]
        SB[Service Bus]
    end
    
    subgraph Ingestion["Telemetry Ingestion"]
        OTEL[OpenTelemetry SDK]
        OTLP[OTLP Exporter]
        AZM[Azure Monitor Exporter]
    end
    
    subgraph Processing["Processing & Enrichment"]
        BATCH[Batch Processor]
    end
    
    subgraph Storage["Storage Zones"]
        AI[Application Insights]
        LAW[Log Analytics Workspace]
        SA[Storage Account: logs]
    end
    
    subgraph Governance["Data Governance"]
        RET[30-day Retention]
        LCM[Lifecycle Management]
    end
    
    API --> OTEL
    APP --> OTEL
    LA --> OTEL
    SB --> OTEL
    
    OTEL --> BATCH
    BATCH --> OTLP
    BATCH --> AZM
    
    OTLP --> AI
    AZM --> AI
    AZM --> LAW
    LAW --> SA
    
    SA --> RET
    SA --> LCM
    
    style OTEL fill:#87CEEB
    style OTLP fill:#87CEEB
    style AZM fill:#87CEEB
    style BATCH fill:#90EE90
    style AI fill:#F0E68C
    style LAW fill:#F0E68C
    style SA fill:#F0E68C
    style RET fill:#D3D3D3
    style LCM fill:#D3D3D3
```

### Data Models

**Core Data Entities:**

1. **Order Entity** (as defined in OrderController.cs):
   - `Id` (string)
   - `CustomerId` (string)
   - `OrderDate` (DateTime)
   - `TotalAmount` (decimal)
   - `Status` (string)

2. **Service Bus Message** (as referenced in OrderMessageHandler.cs):
   - Message Body (byte array)
   - Application Properties (Dictionary)
   - `Diagnostic-Id` (string, for trace context)
   - `traceparent` (string, W3C Trace Context)

3. **Telemetry Data** (as configured in Extensions.cs):
   - Activity/Span data (OpenTelemetry format)
   - Metrics (OpenTelemetry format)
   - Structured logs (OpenTelemetry format)

---

## 3. Application Architecture

### Purpose
The Application Architecture layer defines the logical application components, their interactions, and integration patterns required to deliver workflow orchestration, monitoring, and operational management capabilities. This layer implements microservices patterns, event-driven architecture, and distributed tracing standards.

### Key Capabilities
- **RESTful API Services**: Expose order management operations through HTTP endpoints with OpenAPI documentation
- **Background Message Processing**: Consume and process Service Bus messages asynchronously with distributed tracing
- **Web Application Delivery**: Provide Blazor-based user interface with WebAssembly interactivity
- **Service Orchestration**: Coordinate application services using .NET Aspire with service discovery
- **Distributed Tracing**: Implement W3C Trace Context propagation across all service boundaries
- **Health Monitoring**: Report service health status for container orchestration and load balancing

### Microservices Architecture

```mermaid
flowchart LR
    subgraph Clients
        WEB[Orders Web App<br/>Blazor WebAssembly]
        EXT[External Clients]
    end
    
    subgraph Gateway
        HTTPS[HTTPS Endpoint]
    end
    
    subgraph Services
        API[Orders API<br/>ASP.NET Core]
        MH[Message Handler<br/>Background Service]
        LA[Logic App<br/>Workflow Engine]
    end
    
    subgraph Messaging
        SB[Service Bus<br/>orders-queue]
    end
    
    subgraph Data
        MEM[(In-Memory Store)]
        BLOB[(Blob Storage)]
        QUE[(Queue Storage)]
    end
    
    WEB -->|HTTP/HTTPS| HTTPS
    EXT -->|HTTP/HTTPS| HTTPS
    HTTPS --> API
    
    API -->|Publish| SB
    SB -->|Consume| MH
    SB -->|Trigger| LA
    
    API <-->|Read/Write| MEM
    MH -->|Write| BLOB
    LA -->|Queue| QUE
    
    style WEB fill:#87CEEB
    style EXT fill:#87CEEB
    style HTTPS fill:#DDA0DD
    style API fill:#90EE90
    style MH fill:#90EE90
    style LA fill:#90EE90
    style SB fill:#FFA500
    style MEM fill:#F0E68C
    style BLOB fill:#F0E68C
    style QUE fill:#F0E68C
```

### Event-Driven Architecture (Topology)

```mermaid
flowchart LR
    subgraph Producers
        API[Orders API<br/>HTTP Controller]
    end
    
    subgraph Event Bus
        SB[Service Bus<br/>Premium Namespace]
        Q[Queue: orders-queue]
    end
    
    subgraph Consumers
        MH[Message Handler<br/>BackgroundService]
        LA[Logic App<br/>ConsosoOrders]
    end
    
    subgraph Analytics
        AI[Application Insights<br/>Telemetry]
        LAW[Log Analytics<br/>Workspace]
    end
    
    API -->|OrderCreated Event| Q
    Q -->|Message| MH
    Q -->|Trigger| LA
    
    SB --> Q
    
    API -.->|Traces| AI
    MH -.->|Traces| AI
    LA -.->|Telemetry| AI
    AI --> LAW
    
    style API fill:#90EE90
    style MH fill:#90EE90
    style LA fill:#90EE90
    style SB fill:#FFA500
    style Q fill:#FFA500
    style AI fill:#F0E68C
    style LAW fill:#F0E68C
```

### Event-Driven Architecture (State Transitions)

```mermaid
stateDiagram-v2
    [*] --> OrderReceived: API Request
    OrderReceived --> MessageQueued: Publish to Service Bus
    MessageQueued --> MessageProcessing: Consumer Receives
    
    MessageProcessing --> OrderProcessed: Success
    MessageProcessing --> OrderFailed: Exception
    
    OrderProcessed --> [*]: Complete Message
    OrderFailed --> MessageQueued: Retry (if attempts remaining)
    OrderFailed --> DeadLetter: Max Retries Exceeded
    DeadLetter --> [*]
    
    note right of MessageQueued
        Service Bus Queue
        orders-queue
    end note
    
    note right of MessageProcessing
        Distributed Tracing Active
        Trace Context Propagated
    end note
```

### Application Components

**As explicitly defined in workspace:**

1. **eShop.Orders.API** (eShop.Orders.API):
   - ASP.NET Core 9.0 RESTful API
   - Controllers: `OrdersController`
   - Services: `OrderService`, `OrderMessageHandler`
   - Middleware: `CorrelationIdMiddleware`

2. **eShop.Orders.App** (eShop.Orders.App):
   - Blazor WebAssembly application
   - Server: Program.cs
   - Client: Program.cs

3. **eShopOrders.ServiceDefaults** (eShopOrders.ServiceDefaults):
   - OpenTelemetry configuration: Extensions.cs
   - Health checks implementation
   - Service discovery setup

4. **Logic Apps Workflow** (`LogicAppWP/ConsosoOrders`):
   - Workflow: ConsosoOrders
   - Runtime: Logic Apps Standard on Azure Functions v4

### Integration Patterns

**Service Bus Integration** (as implemented in OrderService.cs):
- Publisher: Orders API publishes messages with trace context
- Consumer: Background service processes messages with context extraction
- Trace Context Propagation: W3C Trace Context via message properties

**HTTP Client Integration** (as configured in Extensions.cs):
- Automatic distributed tracing via `AddHttpClientInstrumentation`
- Standard resilience handler with circuit breaker, retry, timeout policies
- Service discovery integration

---

## 4. Technology Architecture

### Purpose
The Technology Architecture layer defines the infrastructure platforms, deployment models, runtime environments, and operational tooling required to host, operate, and monitor the application architecture. This layer implements cloud-native patterns, container orchestration, serverless computing, and platform engineering practices.

### Key Capabilities
- **Container Hosting**: Deploy and orchestrate containerized services on Azure Container Apps with elastic scaling
- **Serverless Workflow Execution**: Run Logic Apps Standard workflows on Azure Functions v4 runtime
- **Managed Identity Authentication**: Eliminate credential management using Azure AD identity federation
- **Infrastructure as Code**: Provision all Azure resources using Bicep templates with parameterization
- **Observability Platform**: Collect and analyze telemetry using Application Insights and Log Analytics
- **Developer Inner Loop**: Accelerate development with .NET Aspire orchestration and local emulators

### Cloud-Native Architecture

```mermaid
flowchart LR
    subgraph Clients
        WEB[Web Clients]
        MOB[Mobile Clients]
    end
    
    subgraph Edge
        CDN[Content Delivery]
        GW[HTTPS Gateway]
    end
    
    subgraph Container Platform
        ACR[Azure Container Registry<br/>Premium Tier]
        CAE[Container Apps Environment<br/>Consumption Profile]
        API_APP[Orders API<br/>Container App]
        WEB_APP[Orders Web App<br/>Container App]
    end
    
    subgraph Serverless
        LA[Logic App Standard<br/>WorkflowStandard Plan]
    end
    
    subgraph Messaging
        SB[Service Bus<br/>Premium Namespace]
    end
    
    subgraph Data
        SA[Storage Account<br/>Standard_LRS]
    end
    
    subgraph Observability
        AI[Application Insights<br/>Workspace-based]
        LAW[Log Analytics<br/>30-day Retention]
        ASP[Aspire Dashboard<br/>.NET Component]
    end
    
    subgraph Security
        MI[Managed Identity<br/>User-Assigned]
        RBAC[Role Assignments<br/>Least Privilege]
    end
    
    WEB --> CDN
    MOB --> CDN
    CDN --> GW
    GW --> API_APP
    GW --> WEB_APP
    
    ACR --> API_APP
    ACR --> WEB_APP
    API_APP --> SB
    WEB_APP --> API_APP
    SB --> LA
    LA --> SA
    
    API_APP -.->|Telemetry| AI
    WEB_APP -.->|Telemetry| AI
    LA -.->|Telemetry| AI
    AI --> LAW
    
    CAE --> ASP
    
    MI --> API_APP
    MI --> WEB_APP
    MI --> LA
    MI --> RBAC
    
    style WEB fill:#87CEEB
    style MOB fill:#87CEEB
    style CDN fill:#DDA0DD
    style GW fill:#DDA0DD
    style API_APP fill:#90EE90
    style WEB_APP fill:#90EE90
    style LA fill:#90EE90
    style SB fill:#FFA500
    style ACR fill:#F0E68C
    style SA fill:#F0E68C
    style AI fill:#D3D3D3
    style LAW fill:#D3D3D3
    style ASP fill:#D3D3D3
    style MI fill:#D3D3D3
    style RBAC fill:#D3D3D3
```

### Container-Based Architecture

```mermaid
flowchart TB
    subgraph LB["Load Balancer / Ingress"]
        HTTPS[HTTPS Endpoints<br/>Auto-assigned]
    end
    
    subgraph CAE["Container Apps Environment"]
        subgraph Workloads
            API[Orders API<br/>Deployment]
            APP[Orders Web App<br/>Deployment]
            DASH[Aspire Dashboard<br/>Component]
        end
        
        subgraph Config
            ENV[Environment Variables]
            SEC[Secrets]
        end
    end
    
    subgraph Storage
        ACR[Azure Container Registry<br/>Image Repository]
        SA[Storage Account<br/>Diagnostic Logs]
    end
    
    subgraph Observability
        LAW[Log Analytics<br/>Workspace]
        AI[Application Insights<br/>Telemetry]
    end
    
    HTTPS --> API
    HTTPS --> APP
    
    ACR -.->|Pull Images| API
    ACR -.->|Pull Images| APP
    
    ENV --> API
    ENV --> APP
    SEC --> API
    SEC --> APP
    
    API -.->|Logs| LAW
    APP -.->|Logs| LAW
    API -.->|Metrics/Traces| AI
    APP -.->|Metrics/Traces| AI
    
    LAW --> SA
    
    DASH -.->|Observability| AI
    
    style HTTPS fill:#DDA0DD
    style API fill:#90EE90
    style APP fill:#90EE90
    style DASH fill:#90EE90
    style ENV fill:#90EE90
    style SEC fill:#90EE90
    style ACR fill:#F0E68C
    style SA fill:#F0E68C
    style LAW fill:#D3D3D3
    style AI fill:#D3D3D3
```

### Serverless Architecture

```mermaid
flowchart LR
    subgraph Trigger
        SB_TRIG[Service Bus Trigger<br/>orders-queue]
    end
    
    subgraph Functions
        LA[Logic App Standard<br/>ConsosoOrders Workflow]
        FX[Azure Functions v4<br/>Runtime]
    end
    
    subgraph Queues
        SB[Service Bus<br/>orders-queue]
        QS[Queue Storage<br/>Task Queue]
    end
    
    subgraph Storage
        BLOB[Blob Storage<br/>Success/Error Containers]
        SA[Storage Account<br/>Workflow State]
    end
    
    subgraph Monitoring
        AI[Application Insights<br/>Telemetry]
        LAW[Log Analytics<br/>Logs]
    end
    
    SB --> SB_TRIG
    SB_TRIG --> LA
    LA --> FX
    FX --> QS
    FX --> BLOB
    FX <-->|State| SA
    
    LA -.->|Diagnostics| AI
    FX -.->|Logs| LAW
    
    style SB_TRIG fill:#DDA0DD
    style LA fill:#90EE90
    style FX fill:#90EE90
    style SB fill:#FFA500
    style QS fill:#FFA500
    style BLOB fill:#F0E68C
    style SA fill:#F0E68C
    style AI fill:#D3D3D3
    style LAW fill:#D3D3D3
```

### Platform Engineering Architecture

```mermaid
flowchart TB
    subgraph Developers["Developer Experience"]
        VS[Visual Studio Code<br/>Extensions]
        SDK[.NET 9 SDK]
        ASPIRE[.NET Aspire<br/>Orchestration]
    end
    
    subgraph IDP["Internal Developer Platform"]
        APPHOST[AppHost<br/>Service Configuration]
        DEFAULTS[ServiceDefaults<br/>Shared Patterns]
    end
    
    subgraph CICD["CI/CD & Policies"]
        GHA[GitHub Actions<br/>Workflows]
        AZD[Azure Developer CLI<br/>azd up]
        HOOKS[Deployment Hooks<br/>Pre/Post Provision]
    end
    
    subgraph Runtime["Runtime Platforms"]
        CAE[Container Apps<br/>Environment]
        ASP_PLAN[App Service Plan<br/>WorkflowStandard]
    end
    
    subgraph Shared["Shared Services"]
        MI[Managed Identity<br/>User-Assigned]
        SB[Service Bus<br/>Premium]
        ACR[Container Registry<br/>Premium]
    end
    
    subgraph Data["Data Services"]
        SA[Storage Accounts<br/>Logs/Workflow]
        LAW[Log Analytics<br/>Workspace]
        AI[Application Insights<br/>Telemetry]
    end
    
    VS --> ASPIRE
    SDK --> ASPIRE
    ASPIRE --> APPHOST
    APPHOST --> DEFAULTS
    
    DEFAULTS --> GHA
    GHA --> AZD
    AZD --> HOOKS
    
    HOOKS --> CAE
    HOOKS --> ASP_PLAN
    
    CAE --> MI
    ASP_PLAN --> MI
    
    MI --> SB
    MI --> ACR
    
    CAE --> SA
    ASP_PLAN --> SA
    SA --> LAW
    LAW --> AI
    
    style VS fill:#87CEEB
    style SDK fill:#87CEEB
    style ASPIRE fill:#87CEEB
    style APPHOST fill:#90EE90
    style DEFAULTS fill:#90EE90
    style GHA fill:#90EE90
    style AZD fill:#90EE90
    style HOOKS fill:#90EE90
    style CAE fill:#DDA0DD
    style ASP_PLAN fill:#DDA0DD
    style MI fill:#D3D3D3
    style SB fill:#D3D3D3
    style ACR fill:#D3D3D3
    style SA fill:#F0E68C
    style LAW fill:#F0E68C
    style AI fill:#F0E68C
```

### Infrastructure Components

**As explicitly defined in infra Bicep modules:**

1. **Monitoring Infrastructure** (monitoring):
   - Log Analytics Workspace: 30-day retention, PerGB2018 pricing tier
   - Application Insights: Workspace-based, web application type
   - Storage Account: Diagnostic logs with 30-day lifecycle policy
   - Azure Monitor Health Model: Service group hierarchy

2. **Identity Management** (identity):
   - User-Assigned Managed Identity
   - Role Assignments: Storage Contributor, Metrics Publisher, Service Bus Data Owner, ACR Pull/Push

3. **Messaging Infrastructure** (messaging):
   - Service Bus Premium Namespace: 16 messaging units capacity
   - Queue: `orders-queue`
   - Workflow Storage Account: Standard_LRS with blob containers

4. **Container Services** (services):
   - Azure Container Registry: Premium tier
   - Container Apps Environment: Consumption workload profile
   - Aspire Dashboard: .NET component for observability

5. **Logic Apps** (logic-app.bicep):
   - App Service Plan: WorkflowStandard WS1, 3-20 instances elastic scaling
   - Logic App: Functions v4 runtime, extension bundle v1.x

### Deployment Model

**Infrastructure Provisioning** (as defined in postprovision.ps1):
1. Azure resource deployment via Bicep templates
2. Container Registry authentication
3. Docker image build and push
4. Container Apps deployment
5. Configuration validation

**Application Deployment**:
- Container images built from Dockerfiles in Dockerfile and Dockerfile
- Pushed to Azure Container Registry
- Deployed to Container Apps via Azure Developer CLI

---

## Compliance and Governance

### TOGAF Compliance
This BDAT model adheres to TOGAF 10 Architecture Development Method (ADM) principles:
- **Phase A (Architecture Vision)**: Defined in Business Architecture project overview
- **Phase B (Business Architecture)**: Capability map and value streams documented
- **Phase C (Information Systems Architectures)**: Data and Application architectures detailed with explicit component mapping
- **Phase D (Technology Architecture)**: Cloud-native, container, serverless, and platform patterns implemented
- **Phase E-H**: Implementation governance through IaC, CI/CD, and monitoring

### Architecture Patterns
- **Microservices**: RESTful APIs with independent deployment and scaling
- **Event-Driven**: Asynchronous message processing with Service Bus
- **CQRS**: [MISSING COMPONENT - No explicit command/query separation implemented]
- **Distributed Tracing**: W3C Trace Context propagation across all boundaries
- **Cloud-Native**: Container Apps, Serverless Functions, Managed Services
- **Platform Engineering**: .NET Aspire for developer productivity and golden paths

### Gap Analysis

**Identified Gaps:**
1. **Master Data Management**: No centralized data hub for canonical order models
2. **CQRS Implementation**: Read and write operations use same in-memory store
3. **Event Sourcing**: No append-only event log for state reconstruction
4. **API Gateway**: Direct service exposure without centralized gateway (relying on Container Apps ingress)
5. **Service Mesh**: No explicit service mesh implementation (Container Apps handles service-to-service)

**Recommendations:**
1. Implement canonical data model with Azure SQL Database or Cosmos DB for order persistence
2. Separate read and query models using event sourcing patterns
3. Consider Azure API Management for enterprise API governance
4. Evaluate Dapr integration within Container Apps Environment for service mesh capabilities

---

## Appendix: Technology Stack Reference

**Explicitly Used Technologies (from workspace):**

| Category | Technology | Version | Source |
|----------|-----------|---------|--------|
| Runtime | .NET | 9.0 | eShop.Orders.API.csproj |
| Orchestration | .NET Aspire | Latest | eShopOrders.AppHost.csproj |
| Observability | OpenTelemetry | Latest | Extensions.cs |
| Messaging | Azure Service Bus | Premium | main.bicep |
| Monitoring | Application Insights | Workspace-based | app-insights.bicep |
| Hosting | Azure Container Apps | Consumption | main.bicep |
| Workflows | Logic Apps Standard | Functions v4 | logic-app.bicep |
| Storage | Azure Storage | Standard_LRS | main.bicep |
| IaC | Bicep | Latest | main.bicep |

---

**Document Metadata:**
- **TOGAF Version**: 10
- **Architecture Framework**: TOGAF BDAT Model
- **Solution Version**: 1.0.0
- **Last Updated**: 2025-06-01 (deployment date from Bicep parameters)
- **Architecture Maturity Level**: Level 3 (Defined - standardized processes, reusable components)