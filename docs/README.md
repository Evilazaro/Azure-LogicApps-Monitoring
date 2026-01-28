# Documentation

This folder contains the technical documentation for the **Azure Logic Apps Monitoring Solution — eShop Orders Management** platform.

---

## 📋 Overview

The documentation follows industry-standard frameworks and best practices, providing comprehensive coverage of the solution's architecture, design decisions, and implementation details. All documents are maintained in Markdown format with Mermaid diagrams for visual representations.

### Solution Summary

The eShop Orders Management solution is a cloud-native distributed application built on Microsoft Azure:

| Component         | Technology                           | Purpose                                     |
| :---------------- | :----------------------------------- | :------------------------------------------ |
| **Frontend**      | Blazor Server + Fluent UI            | Interactive web application                 |
| **Backend**       | ASP.NET Core Web API                 | RESTful order management services           |
| **Orchestration** | .NET Aspire 13.1.0                   | Service orchestration and local development |
| **Workflow**      | Azure Logic Apps                     | Asynchronous order processing               |
| **Database**      | Azure SQL Database                   | Order data persistence                      |
| **Messaging**     | Azure Service Bus                    | Event-driven pub/sub messaging              |
| **Observability** | Application Insights + Log Analytics | Distributed tracing and monitoring          |

---

## 📁 Folder Structure

```
docs/
├── README.md                 # This file - Documentation entry point
├── .gitignore                # Git ignore rules for documentation
└── architecture/             # Architecture documentation (TOGAF Phase C)
    ├── README.md             # Architecture folder overview
    ├── application-architecture.md   # Application layer documentation
    └── data-architecture.md          # Data layer documentation
```

---

## 📄 Documentation Index

### Architecture Documentation

| Document                                                             | Description                                                                   | Lines | Status |
| :------------------------------------------------------------------- | :---------------------------------------------------------------------------- | ----: | :----: |
| [Architecture Overview](architecture/README.md)                      | Entry point for architecture documentation with TOGAF framework alignment     |   181 |   ✅   |
| [Application Architecture](architecture/application-architecture.md) | Services, interfaces, components, data access, integration points, deployment |   904 |   ✅   |
| [Data Architecture](architecture/data-architecture.md)               | Data entities, stores, flows, state management, security, IaC definitions     |   931 |   ✅   |

---

## 🏗️ Architecture Framework

The documentation follows the **TOGAF (The Open Group Architecture Framework)** methodology:

| TOGAF Phase | Domain                   | Document                                                                | Coverage                                   |
| :---------- | :----------------------- | :---------------------------------------------------------------------- | :----------------------------------------- |
| Phase C     | Application Architecture | [application-architecture.md](architecture/application-architecture.md) | Services, interfaces, components, security |
| Phase C     | Data Architecture        | [data-architecture.md](architecture/data-architecture.md)               | Entities, data stores, flows, governance   |

### TOGAF BDAT Classification

| Classification                     | Purpose                     | Azure Implementation                     |
| :--------------------------------- | :-------------------------- | :--------------------------------------- |
| 💾 **System of Record (SoR)**      | Authoritative data source   | Azure SQL Database (OrderDb)             |
| 📚 **System of Reference (SoRef)** | Archives and reference data | Azure Blob Storage, File Share           |
| ⚡ **System of Engagement (SoE)**  | Transient interactions      | Azure Service Bus (`ordersplaced` topic) |
| 📊 **System of Insight (SoI)**     | Observability and analytics | Application Insights, Log Analytics      |

---

## 🔧 Technology Stack

| Layer          | Technology                    | Version  |
| :------------- | :---------------------------- | :------- |
| Runtime        | .NET                          | 10.0     |
| Orchestration  | .NET Aspire                   | 13.1.0   |
| Web Framework  | ASP.NET Core                  | 10.0     |
| UI Framework   | Blazor Server + Fluent UI     | 4.13.2   |
| ORM            | Entity Framework Core         | 10.0.2   |
| Database       | Azure SQL                     | —        |
| Messaging      | Azure Service Bus             | 7.20.1   |
| Telemetry      | OpenTelemetry + Azure Monitor | 1.15.0   |
| Authentication | Azure Identity                | 1.17.1   |
| Workflow       | Azure Logic Apps              | Standard |
| Infrastructure | Bicep                         | —        |

---

## 📊 Diagrams

The architecture documentation includes **15+ Mermaid diagrams** with Material Design color theming:

| Category                     | Diagram Types                                                              |
| :--------------------------- | :------------------------------------------------------------------------- |
| **Application Architecture** | Flowcharts, Sequence Diagrams, Class Diagrams, ER Diagrams, Block Diagrams |
| **Data Architecture**        | Flowcharts, ER Diagrams, Sequence Diagrams, State Diagrams                 |

---

## 📖 How to Use This Documentation

| Role                    | Recommended Path                                                                                                                  |
| :---------------------- | :-------------------------------------------------------------------------------------------------------------------------------- |
| **Solution Architects** | Start with [Architecture Overview](architecture/README.md) → [Application Architecture](architecture/application-architecture.md) |
| **Backend Developers**  | [Application Architecture](architecture/application-architecture.md) — Services, Interfaces, Data Access sections                 |
| **Data Engineers**      | [Data Architecture](architecture/data-architecture.md) — Entities, Data Stores, Data Flows                                        |
| **DevOps Engineers**    | [Data Architecture](architecture/data-architecture.md) — IaC section for Bicep resources                                          |
| **Security Teams**      | Security sections in both architecture documents                                                                                  |
| **New Team Members**    | Read Executive Summary sections in each document                                                                                  |

---

## 🛡️ Document Standards

All documentation follows these standards:

| Standard            | Description                                             |
| :------------------ | :------------------------------------------------------ |
| **Format**          | Markdown with GitHub Flavored Markdown (GFM) extensions |
| **Diagrams**        | Mermaid.js with Material Design color palette           |
| **Framework**       | TOGAF ADM Phase C compliance                            |
| **Validation**      | Source citations verified against codebase              |
| **Version Control** | Metadata headers with version and date tracking         |

---

## 🔗 Related Resources

| Resource                                    | Description                                          |
| :------------------------------------------ | :--------------------------------------------------- |
| [Project README](../README.md)              | Main project documentation and getting started guide |
| [Azure Developer CLI Config](../azure.yaml) | Infrastructure deployment configuration              |
| [Infrastructure Code](../infra/)            | Bicep templates for Azure resources                  |
| [Source Code](../src/)                      | Application source code                              |
| [Workflows](../workflows/)                  | Azure Logic App workflow definitions                 |
| [Hooks](../hooks/)                          | Deployment lifecycle scripts                         |

---

## 🚀 Quick Links

- **[Architecture Overview](architecture/README.md)** — Start here for architecture documentation
- **[Application Architecture](architecture/application-architecture.md)** — Application layer details
- **[Data Architecture](architecture/data-architecture.md)** — Data layer details

---

**Last Updated**: 2026-01-28  
**Maintainer**: Platform Team  
**Repository**: [Evilazaro/Azure-LogicApps-Monitoring](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
