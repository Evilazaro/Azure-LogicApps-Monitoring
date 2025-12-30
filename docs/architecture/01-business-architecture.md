# Business Architecture

← [Architecture Overview](README.md) | [Index](README.md) | [Data Architecture →](02-data-architecture.md)

---

## 1. Business Context

### Problem Statement

Modern distributed cloud applications require comprehensive observability to ensure operational excellence. Organizations struggle with:
- Correlating events across multiple services and asynchronous workflows
- Understanding the health and performance of event-driven architectures
- Achieving visibility into Logic Apps workflow executions within broader application context
- Maintaining operational awareness across hybrid local development and cloud environments

### Solution Value Proposition

The **Azure Logic Apps Monitoring Solution** provides a reference implementation demonstrating:
- **End-to-end distributed tracing** across REST APIs, messaging, and workflow automation
- **Unified observability** combining Application Insights, OpenTelemetry, and Azure Monitor
- **Production-ready patterns** for event-driven microservices with comprehensive instrumentation
- **Developer experience parity** between local development (emulators) and Azure deployment

### Target Users and Personas

| Persona | Role | Primary Needs |
|---------|------|---------------|
| **Platform Architect** | Designs cloud-native solutions | Reference patterns for observability, event-driven design |
| **Application Developer** | Builds and maintains services | Clear service boundaries, easy debugging, local dev tooling |
| **Site Reliability Engineer** | Ensures system reliability | Health monitoring, alerting, incident investigation |
| **DevOps Engineer** | Manages deployments | Infrastructure automation, CI/CD, environment management |

---

## 2. Business Capabilities

### Capability Map

```mermaid
flowchart TB
    subgraph Core["🎯 Core Capabilities"]
        direction LR
        OrderMgmt["Order Management<br/><i>Revenue enablement through<br/>customer order processing</i>"]
        WorkflowAuto["Workflow Automation<br/><i>Event-driven orchestration<br/>of business processes</i>"]
    end

    subgraph Enabling["⚙️ Enabling Capabilities"]
        direction LR
        Observability["Observability<br/><i>System visibility through<br/>traces, metrics, logs</i>"]
        Resilience["Resilience<br/><i>Fault tolerance through<br/>retry and circuit breakers</i>"]
    end

    subgraph Foundation["🏗️ Foundation Capabilities"]
        direction LR
        Identity["Identity Management<br/><i>Authentication via<br/>managed identity</i>"]
        Messaging["Event Messaging<br/><i>Reliable async communication<br/>via Service Bus</i>"]
        DataPersistence["Data Persistence<br/><i>Transactional storage<br/>via Azure SQL</i>"]
    end

    Core --> Enabling --> Foundation
    OrderMgmt -.->|"triggers"| WorkflowAuto
    OrderMgmt -.->|"monitored by"| Observability
    WorkflowAuto -.->|"monitored by"| Observability
    OrderMgmt -.->|"uses"| Resilience
    WorkflowAuto -.->|"publishes to"| Messaging
    OrderMgmt -.->|"persists to"| DataPersistence
    OrderMgmt -.->|"authenticates via"| Identity

    classDef core fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef enabling fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef foundation fill:#f5f5f5,stroke:#616161,stroke-width:2px

    class OrderMgmt,WorkflowAuto core
    class Observability,Resilience enabling
    class Identity,Messaging,DataPersistence foundation
```

### Capability Descriptions

| Capability | Description | Type | Primary Components |
|------------|-------------|------|-------------------|
| **Order Management** | End-to-end handling of customer orders including validation, persistence, and status tracking | Core | eShop.Orders.API, eShop.Web.App |
| **Workflow Automation** | Event-driven orchestration of business processes triggered by domain events | Core | OrdersManagement Logic App, Service Bus |
| **Observability** | Comprehensive visibility into system behavior through distributed traces, metrics, and structured logs | Enabling | Application Insights, OpenTelemetry, Log Analytics |
| **Resilience** | Fault tolerance through retry policies, circuit breakers, and timeout handling | Enabling | Polly, ServiceDefaults |
| **Identity Management** | Zero-secret authentication for services using Azure Managed Identity | Foundation | User Assigned Managed Identity, Entra ID |
| **Event Messaging** | Reliable asynchronous communication between services via publish-subscribe patterns | Foundation | Azure Service Bus, Topics, Subscriptions |
| **Data Persistence** | ACID-compliant transactional storage for order entities | Foundation | Azure SQL Database, Entity Framework Core |

---

## 3. Stakeholder Analysis

| Stakeholder | Concerns | How Architecture Addresses |
|-------------|----------|---------------------------|
| **Business Sponsors** | Solution demonstrates Azure best practices for customer adoption | Reference architecture with production-ready patterns |
| **Cloud Architects** | Reusable patterns for observability in event-driven systems | Modular design, comprehensive documentation, ADRs |
| **Development Teams** | Onboarding complexity, debugging difficulty | ServiceDefaults library, local emulators, distributed tracing |
| **Operations Teams** | Incident response time, root cause analysis | End-to-end correlation, health checks, structured logging |
| **Security Teams** | Secret management, authentication patterns | Managed identity, no hardcoded secrets, RBAC |
| **Platform Teams** | Infrastructure consistency, deployment automation | Bicep IaC, azd integration, environment parity |

---

## 4. Value Streams

### Order Fulfillment Value Stream

```mermaid
flowchart LR
    subgraph Acquire["📥 Acquire"]
        Submit["Customer<br/>Submits Order"]
    end

    subgraph Process["⚙️ Process"]
        Validate["Validate<br/>Order Data"]
        Persist["Persist<br/>to Database"]
        Publish["Publish<br/>OrderPlaced Event"]
    end

    subgraph Automate["🔄 Automate"]
        Trigger["Trigger<br/>Workflow"]
        Execute["Execute<br/>Business Logic"]
    end

    subgraph Monitor["📊 Monitor"]
        Trace["Capture<br/>Distributed Trace"]
        Alert["Alert on<br/>Anomalies"]
    end

    Submit --> Validate --> Persist --> Publish --> Trigger --> Execute
    Validate -.-> Trace
    Persist -.-> Trace
    Publish -.-> Trace
    Execute -.-> Trace
    Trace --> Alert

    classDef acquire fill:#e3f2fd,stroke:#1565c0
    classDef process fill:#e8f5e9,stroke:#2e7d32
    classDef automate fill:#fff3e0,stroke:#ef6c00
    classDef monitor fill:#f3e5f5,stroke:#7b1fa2

    class Submit acquire
    class Validate,Persist,Publish process
    class Trigger,Execute automate
    class Trace,Alert monitor
```

### Observability Value Stream

| Stage | Activity | Value Delivered |
|-------|----------|-----------------|
| **Instrument** | Add OpenTelemetry SDK, configure exporters | Automatic trace/metric capture |
| **Collect** | Export to Application Insights | Centralized telemetry storage |
| **Correlate** | W3C Trace Context propagation | End-to-end transaction visibility |
| **Visualize** | Application Map, Transaction Search | Intuitive dependency understanding |
| **Alert** | Define alert rules on metrics/logs | Proactive issue detection |
| **Investigate** | KQL queries, trace analysis | Rapid root cause identification |

---

## 5. Quality Attribute Requirements

| Attribute | Requirement | Priority | Implementation |
|-----------|-------------|----------|----------------|
| **Availability** | 99.9% uptime for API and Web services | High | Azure Container Apps with health probes |
| **Observability** | End-to-end trace correlation across all services | Critical | OpenTelemetry + Application Insights |
| **Scalability** | Handle 1000+ orders/minute during peak | Medium | Container Apps auto-scaling, Service Bus batching |
| **Resilience** | Graceful degradation on dependency failures | High | Polly retry/circuit breaker policies |
| **Security** | Zero hardcoded secrets in codebase | Critical | Azure Managed Identity throughout |
| **Maintainability** | New developers productive within 1 day | Medium | ServiceDefaults library, comprehensive docs |
| **Deployability** | Single-command deployment to Azure | High | azd workflow with Bicep IaC |

---

## 6. Business Process Flows

### Order Lifecycle Process

```mermaid
flowchart TD
    Start([Customer Action]) --> SubmitUI["Submit Order<br/>via Web App"]
    SubmitUI --> APIReceive["API Receives<br/>POST /api/orders"]
    APIReceive --> Validate{Validate<br/>Order Data}
    
    Validate -->|Invalid| ReturnError["Return 400<br/>Bad Request"]
    Validate -->|Valid| CheckDuplicate{Check<br/>Duplicate?}
    
    CheckDuplicate -->|Exists| ReturnConflict["Return 409<br/>Conflict"]
    CheckDuplicate -->|New| PersistDB["Persist to<br/>SQL Database"]
    
    PersistDB --> PublishEvent["Publish OrderPlaced<br/>to Service Bus"]
    PublishEvent --> ReturnSuccess["Return 201<br/>Created"]
    ReturnSuccess --> End1([Order Placed])
    
    PublishEvent -.->|"Async"| SBTrigger["Service Bus<br/>Subscription Trigger"]
    SBTrigger --> LogicApp["Logic App<br/>Workflow Starts"]
    LogicApp --> ProcessOrder["Execute Order<br/>Processing Steps"]
    ProcessOrder --> End2([Workflow Complete])

    ReturnError --> End3([Request Failed])
    ReturnConflict --> End4([Duplicate Rejected])

    classDef success fill:#e8f5e9,stroke:#2e7d32
    classDef error fill:#ffebee,stroke:#c62828
    classDef async fill:#fff3e0,stroke:#ef6c00

    class End1,End2 success
    class End3,End4 error
    class SBTrigger,LogicApp,ProcessOrder async
```

---

## Related Documents

- [Data Architecture](02-data-architecture.md) - Data domains supporting business capabilities
- [Application Architecture](03-application-architecture.md) - Services implementing capabilities
- [Observability Architecture](05-observability-architecture.md) - Monitoring the order value stream

---

> 💡 **Tip:** Use the capability map to understand which components implement each business function when onboarding to this solution.
