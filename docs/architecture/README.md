# Architecture Documentation

This folder contains the architectural documentation for the **Azure Logic Apps Monitoring Solution — eShop Orders Management** platform.

---

## Table of Contents

- [Overview](#-overview)
- [Documents](#-documents)
- [Key Topics Covered](#-key-topics-covered)
- [Diagrams Included](#-diagrams-included)
- [Architecture Framework](#-architecture-framework)
- [Technology Stack](#-technology-stack)
- [Related Documentation](#-related-documentation)
- [How to Use This Documentation](#-how-to-use-this-documentation)
- [Document Standards](#-document-standards)

---

## 📋 Overview

The architecture documentation follows the [TOGAF (The Open Group Architecture Framework)](https://www.opengroup.org/togaf) methodology, providing a structured approach to enterprise architecture. This folder contains **Phase C** artifacts covering **Application Architecture** and **Data Architecture** domains within the TOGAF BDAT (Business, Data, Application, Technology) framework.

### Solution Summary

The eShop Orders Management solution implements a distributed web application architecture using:

- **.NET Aspire 13.1.0** for service orchestration
- **Blazor Server** frontend (`eShop.Web.App`)
- **ASP.NET Core Web API** backend (`eShop.Orders.API`)
- **Azure Logic App** workflow for asynchronous order processing
- **Azure SQL Database**, **Azure Service Bus**, and **Azure Blob Storage** for data persistence

---

## 📄 Documents

| Document                                                | TOGAF Phase | Description                                                                              |    Status    |
| :------------------------------------------------------ | :---------- | :--------------------------------------------------------------------------------------- | :----------: |
| [Application Architecture](application-architecture.md) | Phase C     | Services, interfaces, components, data access, integration points, and security patterns | ✅ Validated |
| [Data Architecture](data-architecture.md)               | Phase C     | Data entities, data stores, data flows, state management, security, and IaC definitions  | ✅ Validated |

---

## 🎯 Key Topics Covered

### Application Architecture

| Section                    | Description                                                                                 |
| :------------------------- | :------------------------------------------------------------------------------------------ |
| **Application Overview**   | Executive summary with technology stack (.NET 10, EF Core 10.0.2, Azure Service Bus 7.20.1) |
| **Application Services**   | Service inventory across Orders, Messaging, and Web Client domains                          |
| **Application Interfaces** | REST API endpoints, message handlers, and health endpoints                                  |
| **Application Components** | Utilities, shared libraries, and health checks                                              |
| **Data Access**            | Repository pattern, DbContext configuration, and connection management                      |
| **Integration Points**     | Azure Service Bus messaging, Application Insights telemetry                                 |
| **Security**               | Authentication, authorization patterns, and secure configuration                            |
| **Deployment**             | .NET Aspire orchestration and container configuration                                       |
| **Gaps & Observations**    | Identified gaps and improvement recommendations                                             |

### Data Architecture

| Section                        | Description                                                    |
| :----------------------------- | :------------------------------------------------------------- |
| **Data Overview**              | TOGAF BDAT classification (SoR, SoRef, SoE, SoI) alignment     |
| **Data Entities & Models**     | OrderEntity, OrderProductEntity with relationships and indexes |
| **Data Stores Landscape**      | Azure SQL, Service Bus, Blob Storage, Log Analytics inventory  |
| **Data Flow Architecture**     | Inbound, processing, internal, and outbound flow definitions   |
| **Monitoring Data Flow**       | OpenTelemetry integration and observability patterns           |
| **Data State Management**      | Order lifecycle state transitions                              |
| **Data Security & Governance** | Authentication, encryption, and access control patterns        |
| **Data Infrastructure (IaC)**  | Bicep resource inventory and deployment parameters             |

---

## 📊 Diagrams Included

### Application Architecture Diagrams

| Diagram                | Type              | Purpose                                                              |
| :--------------------- | :---------------- | :------------------------------------------------------------------- |
| Application Landscape  | `flowchart TB`    | Layered view of presentation, business, data, and integration layers |
| Communication Flows    | `sequenceDiagram` | Request/response sequence through application layers                 |
| Application Services   | `block-beta`      | Domain boundaries for Orders, Messaging, Web Client                  |
| Application Interfaces | `flowchart LR`    | REST API endpoints grouped by controller                             |
| Application Components | `classDiagram`    | Component stereotypes and relationships                              |
| Data Access            | `erDiagram`       | Entity relationships and DbContext mapping                           |
| Integration Points     | `sequenceDiagram` | Service Bus publish flow                                             |
| Deployment             | `flowchart TB`    | .NET Aspire orchestration topology                                   |
| Full Dependency Graph  | `flowchart TB`    | Complete component dependency visualization                          |

### Data Architecture Diagrams

| Diagram                    | Type              | Purpose                                      |
| :------------------------- | :---------------- | :------------------------------------------- |
| Data Architecture Overview | `flowchart TB`    | BDAT classification with all data stores     |
| Entity-Relationship        | `erDiagram`       | OrderEntity/OrderProductEntity relationships |
| Data Stores Landscape      | `flowchart TB`    | SoR/SoRef/SoE/SoI store inventory            |
| Data Flow                  | `sequenceDiagram` | End-to-end order data flow                   |
| Monitoring Data Flow       | `flowchart LR`    | Telemetry pipeline visualization             |
| Data State Lifecycle       | `stateDiagram-v2` | Order state transitions                      |

---

## 🏗️ Architecture Framework

### TOGAF BDAT Alignment

| Classification                     | Purpose                     | Implementation                           |
| :--------------------------------- | :-------------------------- | :--------------------------------------- |
| **💾 System of Record (SoR)**      | Authoritative data source   | Azure SQL Database (OrderDb)             |
| **📚 System of Reference (SoRef)** | Archives and state          | Azure Blob Storage, File Share           |
| **⚡ System of Engagement (SoE)**  | Transient interactions      | Azure Service Bus (`ordersplaced` topic) |
| **📊 System of Insight (SoI)**     | Observability and analytics | Application Insights, Log Analytics      |

### Architecture Principles

| Principle                   | Description                                                        |
| :-------------------------- | :----------------------------------------------------------------- |
| **Separation of Concerns**  | Presentation, business, and data layers in separate projects       |
| **Dependency Inversion**    | Interface-based abstractions (`IOrderService`, `IOrderRepository`) |
| **Event-Driven Processing** | Asynchronous messaging via Service Bus pub/sub                     |
| **Observable by Design**    | OpenTelemetry + Application Insights integration                   |
| **Defense in Depth**        | Entra ID auth, TLS 1.2, Private Endpoints                          |

### Document Classification

| Attribute        | Value                                       |
| :--------------- | :------------------------------------------ |
| **TOGAF Phase**  | C (Information Systems Architecture)        |
| **Domains**      | Application Architecture, Data Architecture |
| **Framework**    | .NET Aspire 13.1.0, .NET 10.0               |
| **Version**      | 1.0                                         |
| **Last Updated** | 2026-01-28                                  |

---

## 🔧 Technology Stack

| Layer          | Technology                    | Version  |
| :------------- | :---------------------------- | :------- |
| Orchestration  | .NET Aspire                   | 13.1.0   |
| Runtime        | .NET                          | 10.0     |
| Web Framework  | ASP.NET Core                  | 10.0     |
| UI Framework   | Blazor Server + Fluent UI     | 4.13.2   |
| ORM            | Entity Framework Core         | 10.0.2   |
| Database       | Azure SQL                     | -        |
| Messaging      | Azure Service Bus             | 7.20.1   |
| Telemetry      | OpenTelemetry + Azure Monitor | 1.15.0   |
| Authentication | Azure Identity                | 1.17.1   |
| Workflow       | Azure Logic Apps              | Standard |

---

## 🔗 Related Documentation

| Resource                                       | Description                                          |
| :--------------------------------------------- | :--------------------------------------------------- |
| [DevOps Documentation](../devops/README.md)    | CI/CD pipeline and workflow documentation            |
| [Hooks Documentation](../hooks/README.md)      | Deployment lifecycle hooks and scripts               |
| [Project README](../../README.md)              | Main project documentation and getting started guide |
| [Azure Developer CLI Config](../../azure.yaml) | Infrastructure deployment configuration              |

---

## 📖 How to Use This Documentation

| Role                    | Recommended Starting Point                                                                    |
| :---------------------- | :-------------------------------------------------------------------------------------------- |
| **Solution Architects** | Start with [Application Architecture](application-architecture.md) for system design overview |
| **Backend Developers**  | Review Application Services and Data Access sections                                          |
| **Data Engineers**      | Focus on [Data Architecture](data-architecture.md) entities and data stores                   |
| **DevOps Engineers**    | Reference Deployment and IaC sections for infrastructure setup                                |
| **Security Teams**      | Consult Security sections in both documents                                                   |
| **New Team Members**    | Read Executive Summary sections in both documents                                             |

---

## 🛡️ Document Standards

All architecture documents in this folder adhere to:

- **Mermaid Diagrams**: Material Design color palette with consistent theming
- **TOGAF Compliance**: Phase C validation with BDAT classification
- **Source Citations**: All elements verified against actual codebase
- **Validation Checklists**: Each document includes compliance verification
- **Version Control**: Metadata headers for change tracking

---

**Last Updated**: 2026-01-28  
**Maintainer**: Platform Team  
**Document Version**: 1.0
