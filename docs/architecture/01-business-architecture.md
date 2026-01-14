# Business Architecture

[← README](README.md) | [Index](README.md) | [Data Architecture →](02-data-architecture.md)

---

## 1. Business Context

### Problem Statement

Organizations deploying Azure Logic Apps Standard workflows face significant challenges in gaining comprehensive visibility into workflow execution, correlating business events across distributed services, and proactively detecting issues before they impact customers. Traditional monitoring approaches often result in fragmented telemetry, making root cause analysis time-consuming and error-prone.

### Solution Value Proposition

The **Azure Logic Apps Monitoring Solution** provides a reference architecture demonstrating how to implement unified observability across Logic Apps workflows and supporting microservices. By leveraging OpenTelemetry, Azure Application Insights, and W3C Trace Context propagation, organizations can:

- **Reduce Mean Time to Detection (MTTD)** through proactive alerting on business-critical metrics
- **Accelerate Root Cause Analysis** with end-to-end distributed tracing across service boundaries
- **Improve Operational Efficiency** via centralized dashboards and automated workflow processing

### Target Users and Personas

| Persona               | Role                         | Goals                                                     |
| --------------------- | ---------------------------- | --------------------------------------------------------- |
| **Platform Engineer** | Infrastructure and DevOps    | Deploy and maintain monitoring infrastructure reliably    |
| **Developer**         | Application Development      | Quickly diagnose and fix issues in order processing flows |
| **SRE/Operations**    | Site Reliability Engineering | Maintain SLOs and respond to incidents effectively        |
| **Business Analyst**  | Order Management             | Track order throughput and identify bottlenecks           |

---

## 2. Business Capabilities

### Capability Map

```mermaid
flowchart TB
    subgraph Core["🎯 Core Capabilities"]
        direction LR
        C1["📦 Order Management<br/><i>Revenue enablement</i>"]
        C2["🔄 Workflow Automation<br/><i>Process efficiency</i>"]
    end

    subgraph Enabling["⚙️ Enabling Capabilities"]
        direction LR
        E1["📊 Observability<br/><i>Operational visibility</i>"]
        E2["📨 Messaging<br/><i>Event distribution</i>"]
        E3["🌐 API Management<br/><i>Service exposure</i>"]
    end

    subgraph Foundation["🏗️ Foundation Capabilities"]
        direction LR
        F1["🔐 Identity Management<br/><i>Authentication/Authorization</i>"]
        F2["🗄️ Data Persistence<br/><i>State management</i>"]
        F3["☁️ Cloud Infrastructure<br/><i>Compute and networking</i>"]
    end

    Core --> Enabling --> Foundation

    C1 -.->|"triggers"| C2
    C1 -.->|"publishes to"| E2
    C2 -.->|"consumes from"| E2
    C1 -.->|"monitored by"| E1
    C2 -.->|"monitored by"| E1

    classDef core fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef enabling fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef foundation fill:#f5f5f5,stroke:#616161,stroke-width:2px

    class C1,C2 core
    class E1,E2,E3 enabling
    class F1,F2,F3 foundation
```

### Capability Descriptions

| Capability               | Description                                                                                   | Type       | Maturity  | Primary Components                                                                         |
| ------------------------ | --------------------------------------------------------------------------------------------- | ---------- | --------- | ------------------------------------------------------------------------------------------ |
| **Order Management**     | End-to-end handling of customer orders including validation, persistence, and status tracking | Core       | Managed   | [eShop.Orders.API](../../src/eShop.Orders.API/), [eShop.Web.App](../../src/eShop.Web.App/) |
| **Workflow Automation**  | Event-driven orchestration of business processes triggered by order events                    | Core       | Defined   | [OrdersManagement Logic App](../../workflows/OrdersManagement/)                            |
| **Observability**        | Comprehensive visibility into system behavior through distributed traces, metrics, and logs   | Enabling   | Optimized | Application Insights, OpenTelemetry                                                        |
| **Messaging**            | Reliable asynchronous communication between services via publish/subscribe patterns           | Enabling   | Managed   | Azure Service Bus                                                                          |
| **API Management**       | Exposure and management of order service capabilities through RESTful interfaces              | Enabling   | Managed   | [OrdersController](../../src/eShop.Orders.API/Controllers/OrdersController.cs)             |
| **Identity Management**  | Authentication and authorization for services using Azure Managed Identity                    | Foundation | Managed   | User-Assigned Managed Identity                                                             |
| **Data Persistence**     | Reliable storage of order data with ACID guarantees                                           | Foundation | Managed   | Azure SQL Database                                                                         |
| **Cloud Infrastructure** | Compute, networking, and platform services hosting all workloads                              | Foundation | Managed   | Azure Container Apps, Logic Apps Standard                                                  |

---

## 3. Stakeholder Analysis

| Stakeholder                   | Concerns                                   | How Architecture Addresses                          |
| ----------------------------- | ------------------------------------------ | --------------------------------------------------- |
| **Cloud Solution Architects** | Reference patterns for Azure observability | Complete TOGAF BDAT documentation with diagrams     |
| **Platform Engineers**        | Infrastructure dependencies and deployment | Bicep IaC with azd lifecycle hooks                  |
| **Development Teams**         | Quick onboarding, clear service boundaries | Clean architecture, comprehensive API documentation |
| **DevOps/SRE Teams**          | Monitoring, alerting, operational runbooks | Application Insights integration, health checks     |
| **Security Teams**            | Authentication, secret management          | Managed Identity, no stored secrets                 |
| **Business Stakeholders**     | Order processing reliability               | SLO definitions, business metrics tracking          |

---

## 4. Value Streams

### Order to Fulfillment Value Stream

```mermaid
flowchart LR
    subgraph Trigger["🎯 Trigger"]
        T1["Customer submits<br/>order"]
    end

    subgraph Engage["📥 Engage"]
        S1["Capture order<br/>via Web UI"]
    end

    subgraph Transact["💳 Transact"]
        S2["Validate &<br/>persist order"]
    end

    subgraph Process["⚙️ Process"]
        S3["Publish event &<br/>trigger workflow"]
    end

    subgraph Fulfill["📦 Fulfill"]
        S4["Execute workflow<br/>automation"]
    end

    subgraph Outcome["✅ Outcome"]
        O1["Order processed<br/>successfully"]
    end

    T1 --> S1 --> S2 --> S3 --> S4 --> O1

    classDef trigger fill:#e3f2fd,stroke:#1565c0
    classDef stage fill:#fff3e0,stroke:#ef6c00
    classDef outcome fill:#e8f5e9,stroke:#2e7d32

    class T1 trigger
    class S1,S2,S3,S4 stage
    class O1 outcome
```

#### Value Stream Details

| #   | Stage        | Description                                                      | Capabilities                       | Cycle Time | Value-Add % |
| --- | ------------ | ---------------------------------------------------------------- | ---------------------------------- | ---------- | ----------- |
| 1   | **Engage**   | Customer interacts with order form via Blazor UI                 | Order Management, API Management   | < 1s       | 80%         |
| 2   | **Transact** | Order validated against business rules and persisted to database | Order Management, Data Persistence | < 500ms    | 90%         |
| 3   | **Process**  | Order event published to Service Bus, triggering workflow        | Messaging, Workflow Automation     | < 100ms    | 70%         |
| 4   | **Fulfill**  | Logic App workflow executes order processing automation          | Workflow Automation, Observability | < 5s       | 85%         |

**Value Stream Metrics:**

- **Total Cycle Time**: < 7 seconds (P95)
- **Value-Add Ratio**: 81% average
- **Throughput Target**: 1000 orders/hour

### Observability Value Stream

```mermaid
flowchart LR
    subgraph Sources["📡 Sources"]
        A1["Service emits<br/>telemetry"]
    end

    subgraph Collect["📥 Collect"]
        B1["OpenTelemetry<br/>captures data"]
    end

    subgraph Store["💾 Store"]
        C1["App Insights<br/>aggregates"]
    end

    subgraph Analyze["🔍 Analyze"]
        D1["KQL queries<br/>& dashboards"]
    end

    subgraph Act["⚡ Act"]
        E1["Alert &<br/>respond"]
    end

    A1 --> B1 --> C1 --> D1 --> E1

    classDef source fill:#fff3e0,stroke:#ef6c00
    classDef process fill:#e3f2fd,stroke:#1565c0
    classDef outcome fill:#e8f5e9,stroke:#2e7d32

    class A1 source
    class B1,C1,D1 process
    class E1 outcome
```

---

## 5. Quality Attribute Requirements

| Attribute           | Requirement                            | Priority | Measurement             | Implementation                                   |
| ------------------- | -------------------------------------- | -------- | ----------------------- | ------------------------------------------------ |
| **Availability**    | 99.9% uptime for order processing      | High     | Azure Monitor SLI       | Container Apps auto-scaling, health checks       |
| **Observability**   | End-to-end tracing across all services | Critical | Trace completion rate   | OpenTelemetry, W3C Trace Context                 |
| **Scalability**     | Handle 1000 orders/minute at peak      | Medium   | Throughput metrics      | Container Apps scaling, Service Bus partitioning |
| **Performance**     | API response time < 500ms P95          | High     | Application Insights    | Connection pooling, caching                      |
| **Reliability**     | Zero message loss for order events     | Critical | Dead letter queue depth | Service Bus with retry policies                  |
| **Security**        | No secrets in code or config           | Critical | Security scan results   | Managed Identity, Key Vault references           |
| **Maintainability** | Deploy changes with zero downtime      | Medium   | Deployment success rate | Blue-green deployments, revision-based           |

---

## 6. Business Process Flows

### Order Lifecycle Process

```mermaid
flowchart TD
    Start([Customer Action]) --> Submit["Submit Order<br/>via Web App"]
    Submit --> Validate{"Validate<br/>Order Data"}

    Validate -->|Invalid| Reject["Return Validation<br/>Errors"]
    Reject --> End1([Customer Corrects])

    Validate -->|Valid| Persist["Persist to<br/>SQL Database"]
    Persist --> Publish["Publish Event<br/>to Service Bus"]
    Publish --> Trigger["Trigger Logic App<br/>Workflow"]

    Trigger --> Process{"Process<br/>Order"}
    Process -->|Success| StoreSuccess["Store in Success<br/>Container"]
    Process -->|Failure| StoreError["Store in Error<br/>Container"]

    StoreSuccess --> Cleanup["Cleanup Workflow<br/>(Every 3 seconds)"]
    Cleanup --> End2([Order Complete])

    StoreError --> Retry["Manual Review<br/>& Retry"]
    Retry --> End3([Resolved])

    classDef start fill:#e3f2fd,stroke:#1565c0
    classDef process fill:#fff3e0,stroke:#ef6c00
    classDef decision fill:#f3e5f5,stroke:#7b1fa2
    classDef success fill:#e8f5e9,stroke:#2e7d32
    classDef error fill:#ffebee,stroke:#c62828

    class Start,End1,End2,End3 start
    class Submit,Persist,Publish,Trigger,Cleanup,Retry process
    class Validate,Process decision
    class StoreSuccess success
    class Reject,StoreError error
```

### Key Process Metrics

| Process Step         | SLI                     | Target  | Alert Threshold |
| -------------------- | ----------------------- | ------- | --------------- |
| Order Validation     | Validation success rate | > 95%   | < 90%           |
| Database Persistence | Write latency P95       | < 100ms | > 500ms         |
| Event Publishing     | Publish success rate    | > 99.9% | < 99%           |
| Workflow Execution   | Workflow success rate   | > 99%   | < 95%           |

---

## Cross-Architecture Relationships

| Related Architecture           | Connection                                      | Reference                                                      |
| ------------------------------ | ----------------------------------------------- | -------------------------------------------------------------- |
| **Data Architecture**          | Order data supports Order Management capability | [Data Architecture](02-data-architecture.md)                   |
| **Application Architecture**   | Services implement business capabilities        | [Application Architecture](03-application-architecture.md)     |
| **Observability Architecture** | Metrics track value stream performance          | [Observability Architecture](05-observability-architecture.md) |

---

[← README](README.md) | [Index](README.md) | [Data Architecture →](02-data-architecture.md)
