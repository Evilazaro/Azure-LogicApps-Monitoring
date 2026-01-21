# Business Architecture

← [Architecture Overview](README.md) | [Index](README.md) | [Data Architecture →](02-data-architecture.md)

---

## 1. Business Context

### Problem Statement

Organizations deploying event-driven distributed applications on Azure face significant challenges in achieving end-to-end visibility across service boundaries. Traditional monitoring approaches fail to capture the complete transaction flow when orders traverse multiple services, message queues, and automated workflows, resulting in blind spots during troubleshooting and capacity planning.

### Solution Value Proposition

The Azure Logic Apps Monitoring Solution provides a **reference architecture** for implementing comprehensive observability in cloud-native applications. By demonstrating proper instrumentation patterns with OpenTelemetry, W3C Trace Context propagation, and Logic Apps Standard integration, this solution enables organizations to:

- **Reduce mean time to resolution (MTTR)** through correlated distributed traces
- **Proactively identify bottlenecks** with end-to-end latency visibility
- **Automate business processes** with observable, auditable workflows
- **Scale confidently** with baseline metrics and alerting

### Target Users and Personas

| Persona                   | Role                     | Primary Goals                                 |
| ------------------------- | ------------------------ | --------------------------------------------- |
| **Platform Engineer**     | Infrastructure & tooling | Deploy and maintain monitoring infrastructure |
| **Application Developer** | Feature development      | Instrument code, troubleshoot issues          |
| **SRE / DevOps Engineer** | Reliability & operations | Monitor SLOs, respond to incidents            |
| **Solution Architect**    | Technical leadership     | Evaluate patterns, design solutions           |

---

## 2. Business Capabilities

### Capability Map

```mermaid
flowchart TB
    subgraph Core["🎯 Core Capabilities"]
        direction LR
        C1["📦 Order Management<br/><i>Revenue-generating</i>"]
        C2["🔄 Workflow Automation<br/><i>Process efficiency</i>"]
    end

    subgraph Enabling["⚙️ Enabling Capabilities"]
        direction LR
        E1["📊 Observability<br/><i>Operational visibility</i>"]
        E2["📨 Event Messaging<br/><i>Service integration</i>"]
        E3["🔗 API Management<br/><i>Service exposure</i>"]
    end

    subgraph Foundation["🏗️ Foundation Capabilities"]
        direction LR
        F1["🔐 Identity Management<br/><i>Authentication & authorization</i>"]
        F2["🗄️ Data Persistence<br/><i>State management</i>"]
        F3["☁️ Cloud Infrastructure<br/><i>Compute & networking</i>"]
    end

    Core --> Enabling --> Foundation

    C1 -.->|"publishes events"| E2
    C1 -.->|"monitored by"| E1
    C2 -.->|"subscribes to"| E2
    C2 -.->|"calls"| E3
    E1 -.->|"secured by"| F1
    E2 -.->|"runs on"| F3

    classDef core fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef enabling fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef foundation fill:#f5f5f5,stroke:#616161,stroke-width:2px

    class C1,C2 core
    class E1,E2,E3 enabling
    class F1,F2,F3 foundation
```

### Capability Descriptions

| Capability               | Description                                                                                              | Type       | Primary Components                                                                         |
| ------------------------ | -------------------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------------------------------------------ |
| **Order Management**     | End-to-end handling of customer orders including placement, validation, persistence, and status tracking | Core       | [eShop.Orders.API](../../src/eShop.Orders.API/), [eShop.Web.App](../../src/eShop.Web.App/) |
| **Workflow Automation**  | Event-driven orchestration of business processes triggered by order placement events                     | Core       | [OrdersManagement Logic App](../../workflows/OrdersManagement/)                            |
| **Observability**        | Comprehensive visibility into system behavior through distributed traces, metrics, and structured logs   | Enabling   | [app.ServiceDefaults](../../app.ServiceDefaults/), Application Insights                    |
| **Event Messaging**      | Reliable asynchronous communication between services using publish-subscribe patterns                    | Enabling   | Azure Service Bus, [OrdersMessageHandler](../../src/eShop.Orders.API/Handlers/)            |
| **API Management**       | RESTful service interfaces for order operations with OpenAPI documentation                               | Enabling   | [OrdersController](../../src/eShop.Orders.API/Controllers/)                                |
| **Identity Management**  | Managed identity authentication for Azure service-to-service communication                               | Foundation | Azure Managed Identity, Entra ID                                                           |
| **Data Persistence**     | Transactional storage for order entities with Entity Framework Core                                      | Foundation | Azure SQL Database, [OrderDbContext](../../src/eShop.Orders.API/data/)                     |
| **Cloud Infrastructure** | Serverless compute, networking, and storage resources                                                    | Foundation | Azure Container Apps, Virtual Network                                                      |

---

## 3. Stakeholder Analysis

| Stakeholder                | Concerns                              | How Architecture Addresses                       |
| -------------------------- | ------------------------------------- | ------------------------------------------------ |
| **Engineering Leadership** | Technical debt, maintainability       | Clean Architecture patterns, shared libraries    |
| **Operations Team**        | System reliability, incident response | Health checks, structured logging, alerting      |
| **Security Team**          | Data protection, access control       | Managed identity, network isolation, encryption  |
| **Development Team**       | Developer experience, debugging       | Local emulators, distributed tracing, hot reload |
| **Finance/Business**       | Cost optimization, ROI                | Consumption-based pricing, resource rightsizing  |

---

## 4. Value Streams

### Order to Fulfillment Value Stream

```mermaid
flowchart LR
    subgraph Trigger["🎯 Trigger"]
        T1["Customer<br/>Places Order"]
    end

    subgraph VS["📊 Value Stream Stages"]
        S1["1️⃣ Capture<br/><i>Order Submission</i>"]
        S2["2️⃣ Validate<br/><i>Order Verification</i>"]
        S3["3️⃣ Persist<br/><i>Data Storage</i>"]
        S4["4️⃣ Publish<br/><i>Event Emission</i>"]
        S5["5️⃣ Process<br/><i>Workflow Execution</i>"]
    end

    subgraph Outcome["✅ Outcome"]
        O1["Order Processed<br/>& Tracked"]
    end

    T1 --> S1 --> S2 --> S3 --> S4 --> S5 --> O1

    classDef trigger fill:#e3f2fd,stroke:#1565c0
    classDef stage fill:#fff3e0,stroke:#ef6c00
    classDef outcome fill:#e8f5e9,stroke:#2e7d32

    class T1 trigger
    class S1,S2,S3,S4,S5 stage
    class O1 outcome
```

#### Value Stream Stages

| Stage        | Description                                 | Capabilities                     | Cycle Time |
| ------------ | ------------------------------------------- | -------------------------------- | ---------- |
| **Capture**  | User submits order via web interface        | Order Management, API Management | ~500ms     |
| **Validate** | Order data validated against business rules | Order Management                 | ~100ms     |
| **Persist**  | Order saved to SQL database with products   | Data Persistence                 | ~200ms     |
| **Publish**  | OrderPlaced event sent to Service Bus       | Event Messaging                  | ~150ms     |
| **Process**  | Logic App executes automated workflow       | Workflow Automation              | ~2s        |

### Observability Value Stream

```mermaid
flowchart LR
    subgraph Trigger["🎯 Trigger"]
        T1["System<br/>Activity"]
    end

    subgraph VS["📊 Observability Stages"]
        S1["1️⃣ Instrument<br/><i>Capture Telemetry</i>"]
        S2["2️⃣ Collect<br/><i>Aggregate Data</i>"]
        S3["3️⃣ Analyze<br/><i>Query & Correlate</i>"]
        S4["4️⃣ Alert<br/><i>Notify on Anomalies</i>"]
    end

    subgraph Outcome["✅ Outcome"]
        O1["Operational<br/>Insight"]
    end

    T1 --> S1 --> S2 --> S3 --> S4 --> O1

    classDef trigger fill:#e3f2fd,stroke:#1565c0
    classDef stage fill:#fff3e0,stroke:#ef6c00
    classDef outcome fill:#e8f5e9,stroke:#2e7d32

    class T1 trigger
    class S1,S2,S3,S4 stage
    class O1 outcome
```

---

## 5. Quality Attribute Requirements

| Attribute           | Requirement                      | Priority | Measurement                           |
| ------------------- | -------------------------------- | -------- | ------------------------------------- |
| **Availability**    | 99.9% uptime for API endpoints   | High     | Azure Monitor uptime checks           |
| **Observability**   | End-to-end distributed tracing   | Critical | Trace correlation across all services |
| **Performance**     | P95 API latency < 500ms          | High     | Application Insights metrics          |
| **Scalability**     | Handle 1000 orders/minute burst  | Medium   | Load testing validation               |
| **Resilience**      | Graceful degradation on failures | High     | Circuit breaker activation            |
| **Security**        | Zero stored credentials          | Critical | Managed identity audit                |
| **Maintainability** | Clear service boundaries         | Medium   | Cyclomatic complexity metrics         |

---

## 6. Business Process Flows

### Order Lifecycle Process

```mermaid
flowchart TD
    A[📝 Order Submitted] --> B{Validate Order}
    B -->|Valid| C[💾 Save to Database]
    B -->|Invalid| D[❌ Return Error]

    C --> E[📨 Publish to Service Bus]
    E --> F[🔄 Logic App Triggered]

    F --> G{Process Order}
    G -->|Success| H[✅ Store in Success Blob]
    G -->|Failure| I[⚠️ Store in Error Blob]

    H --> J[🗑️ Cleanup Workflow]
    J --> K[Order Complete]

    classDef start fill:#e3f2fd,stroke:#1565c0
    classDef process fill:#fff3e0,stroke:#ef6c00
    classDef decision fill:#fce4ec,stroke:#c2185b
    classDef success fill:#e8f5e9,stroke:#2e7d32
    classDef error fill:#ffebee,stroke:#c62828

    class A start
    class C,E,F,J process
    class B,G decision
    class H,K success
    class D,I error
```

---

## Related Documents

- [Data Architecture](02-data-architecture.md) - Data domains supporting business capabilities
- [Application Architecture](03-application-architecture.md) - Services implementing capabilities
- [Observability Architecture](05-observability-architecture.md) - SLI/SLO definitions

---

_Last Updated: January 2026_
