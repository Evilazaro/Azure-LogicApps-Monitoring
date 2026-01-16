# Azure Logic Apps Monitoring Solution - Architecture Overview

## 📑 Table of Contents

- [📋 Executive Summary](#-executive-summary)
- [🏗️ High-Level Architecture](#%EF%B8%8F-high-level-architecture)
- [📦 Service Inventory](#-service-inventory)
- [📄 Document Navigation](#-document-navigation)
- [☁️ Key Azure Resources](#%EF%B8%8F-key-azure-resources)
- [📁 Repository Structure](#-repository-structure)
- [🚀 Quick Start](#-quick-start)
- [📚 Related Documentation](#-related-documentation)

---

[Business Architecture →](01-business-architecture.md)

---

## 📋 Executive Summary

The **Azure Logic Apps Monitoring Solution** is a cloud-native distributed application that demonstrates enterprise-grade observability patterns for Azure Logic Apps Standard workflows. Built on **.NET Aspire** orchestration, this reference architecture showcases how to implement end-to-end distributed tracing, centralized logging, and comprehensive metrics collection across a microservices-based order management system.

The solution provides a practical implementation of monitoring patterns that enable organizations to gain full visibility into their Logic Apps workflows, correlate business events across service boundaries, and proactively detect and diagnose issues in production environments.

**Key Architectural Highlights:**

- **Unified Observability**: OpenTelemetry-based instrumentation with W3C Trace Context propagation across all services
- **Event-Driven Architecture**: Azure Service Bus for reliable, asynchronous order event processing
- **Infrastructure as Code**: Bicep templates with Azure Developer CLI (azd) for repeatable deployments
- **Zero-Secret Authentication**: Managed Identity for all service-to-service communication

---

## 🏗️ High-Level Architecture

```mermaid
---
title: Azure Logic Apps Monitoring - High-Level Architecture
---
flowchart TD
    %% ===== STYLE DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== PRESENTATION LAYER =====
    subgraph Presentation["🖥️ Presentation Layer"]
        WebApp["🌐 eShop.Web.App<br/>Blazor Server"]
    end
    style Presentation fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px,color:#312E81

    %% ===== APPLICATION LAYER =====
    subgraph Application["⚙️ Application Layer"]
        API["📡 eShop.Orders.API<br/>ASP.NET Core"]
        LogicApp["🔄 OrdersManagement<br/>Logic Apps Standard"]
    end
    style Application fill:#D1FAE5,stroke:#10B981,stroke-width:2px,color:#065F46

    %% ===== PLATFORM LAYER =====
    subgraph Platform["🏗️ Platform Layer"]
        Aspire["🎯 app.AppHost<br/>.NET Aspire"]
        Defaults["📦 app.ServiceDefaults<br/>Cross-cutting Concerns"]
    end
    style Platform fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#92400E

    %% ===== DATA LAYER =====
    subgraph Data["💾 Data Layer"]
        SQL[("🗄️ Azure SQL<br/>OrderDb")]
        SB["📨 Azure Service Bus<br/>ordersplaced topic"]
        Storage["📁 Azure Storage<br/>Workflow State"]
    end
    style Data fill:#F3E8FF,stroke:#A855F7,stroke-width:2px,color:#581C87

    %% ===== OBSERVABILITY LAYER =====
    subgraph Observability["📊 Observability Layer"]
        AI["📈 Application Insights"]
        LAW["📋 Log Analytics"]
    end
    style Observability fill:#FCE7F3,stroke:#EC4899,stroke-width:2px,color:#9D174D

    %% ===== CONNECTIONS =====
    WebApp -->|"HTTP/REST"| API
    API -->|"EF Core"| SQL
    API -->|"AMQP"| SB
    SB -->|"Trigger"| LogicApp
    LogicApp -->|"HTTP"| API
    LogicApp -->|"State"| Storage

    Aspire -.->|"Orchestrates"| WebApp
    Aspire -.->|"Orchestrates"| API
    Defaults -.->|"Configures"| WebApp
    Defaults -.->|"Configures"| API

    WebApp -.->|"OTLP"| AI
    API -.->|"OTLP"| AI
    LogicApp -.->|"Diagnostics"| LAW
    AI -->|"Stores"| LAW

    %% ===== CLASS ASSIGNMENTS =====
    class WebApp primary
    class API,LogicApp secondary
    class Aspire,Defaults trigger
    class SQL,SB,Storage datastore
    class AI,LAW external
```

---

## 📦 Service Inventory

| Service                 | Type         | Technology               | Responsibility                                 | Port |
| ----------------------- | ------------ | ------------------------ | ---------------------------------------------- | ---- |
| **eShop.Web.App**       | Frontend     | Blazor Server, Fluent UI | Order management UI with real-time updates     | 5000 |
| **eShop.Orders.API**    | REST API     | ASP.NET Core 10          | Order CRUD, batch processing, event publishing | 5001 |
| **OrdersManagement**    | Workflow     | Logic Apps Standard      | Order validation, processing automation        | N/A  |
| **app.AppHost**         | Orchestrator | .NET Aspire              | Service orchestration, configuration           | N/A  |
| **app.ServiceDefaults** | Library      | .NET Class Library       | OpenTelemetry, health checks, resilience       | N/A  |

---

## 📄 Document Navigation

| Document                                                             | TOGAF Layer   | Description                               | Primary Audience           |
| -------------------------------------------------------------------- | ------------- | ----------------------------------------- | -------------------------- |
| [01-business-architecture.md](01-business-architecture.md)           | Business      | Capabilities, value streams, stakeholders | Architects, Product Owners |
| [02-data-architecture.md](02-data-architecture.md)                   | Data          | Data stores, flows, telemetry mapping     | Architects, Data Engineers |
| [03-application-architecture.md](03-application-architecture.md)     | Application   | Services, APIs, integration patterns      | Developers, Tech Leads     |
| [04-technology-architecture.md](04-technology-architecture.md)       | Technology    | Azure resources, infrastructure           | Platform Engineers, DevOps |
| [05-observability-architecture.md](05-observability-architecture.md) | Cross-cutting | Tracing, metrics, logging strategy        | SRE, Developers            |
| [06-security-architecture.md](06-security-architecture.md)           | Cross-cutting | Identity, secrets, network security       | Security Engineers         |
| [07-deployment-architecture.md](07-deployment-architecture.md)       | Cross-cutting | CI/CD, environments, IaC                  | DevOps, Platform Engineers |
| [ADR Index](adr/README.md)                                           | Decisions     | Architecture Decision Records             | All Technical Staff        |

**Recommended Reading Order by Audience:**

- **Cloud Architects**: README → Business → Technology → Observability → ADRs
- **Developers**: README → Application → Data → Observability
- **DevOps/SRE**: README → Deployment → Observability → Technology
- **Platform Engineers**: README → Technology → Security → Deployment

---

## ☁️ Key Azure Resources

| Resource                           | Purpose                     | SKU/Tier        | Location   |
| ---------------------------------- | --------------------------- | --------------- | ---------- |
| **Azure Container Apps**           | API and Web App hosting     | Consumption     | Configured |
| **Azure SQL Database**             | Order data persistence      | General Purpose | Configured |
| **Azure Service Bus**              | Order event messaging       | Standard        | Configured |
| **Logic Apps Standard**            | Workflow automation         | WS1             | Configured |
| **Application Insights**           | APM and distributed tracing | Standard        | Configured |
| **Log Analytics**                  | Centralized logging         | Pay-per-GB      | Configured |
| **User-Assigned Managed Identity** | Service authentication      | N/A             | Configured |

---

## 📁 Repository Structure

```text
📁 Azure-LogicApps-Monitoring/
├── 🎯 app.AppHost/                        # .NET Aspire orchestration
│   ├── 🟣 app.AppHost.csproj
│   ├── 🟢 AppHost.cs
│   └── 📋 appsettings.json
├── 📦 app.ServiceDefaults/                # Shared cross-cutting concerns
│   ├── 🟣 app.ServiceDefaults.csproj
│   ├── 🟢 CommonTypes.cs
│   └── 🟢 Extensions.cs
├── 📁 src/
│   ├── 📡 eShop.Orders.API/               # Orders REST API
│   │   ├── 📁 Controllers/                # API endpoints
│   │   │   ├── 🟢 OrdersController.cs
│   │   │   └── 🟢 WeatherForecastController.cs
│   │   ├── 📁 Services/                   # Business logic
│   │   │   ├── 🟢 OrderService.cs
│   │   │   └── 🟢 OrdersWrapper.cs
│   │   ├── 📁 Repositories/               # Data access
│   │   │   └── 🟢 OrderRepository.cs
│   │   ├── 📁 Handlers/                   # Message handlers
│   │   │   ├── 🟢 OrdersMessageHandler.cs
│   │   │   └── 🟢 NoOpOrdersMessageHandler.cs
│   │   ├── 📁 HealthChecks/               # Custom health checks
│   │   │   ├── 🟢 DbContextHealthCheck.cs
│   │   │   └── 🟢 ServiceBusHealthCheck.cs
│   │   ├── 🟣 eShop.Orders.API.csproj
│   │   └── 🟢 Program.cs
│   ├── 🌐 eShop.Web.App/                  # Blazor Server frontend
│   │   ├── 📁 Components/                 # Razor components
│   │   │   ├── 📁 Layout/
│   │   │   ├── 📁 Pages/
│   │   │   └── 📁 Shared/
│   │   ├── 🟣 eShop.Web.App.csproj
│   │   └── 🟢 Program.cs
│   └── 🧪 tests/                          # Unit and integration tests
│       └── 📁 eShop.Orders.API.Tests/
├── 🔄 workflows/
│   └── 📁 OrdersManagement/               # Logic Apps workflows
│       └── 📁 OrdersManagementLogicApp/
│           ├── 📁 OrdersPlacedProcess/
│           ├── 📁 OrdersPlacedCompleteProcess/
│           ├── 📋 host.json
│           └── 📋 connections.json
├── 🏗️ infra/                              # Bicep IaC templates
│   ├── 🔷 main.bicep
│   ├── 📋 main.parameters.json
│   ├── 🔷 types.bicep
│   ├── 📁 shared/                         # Shared infrastructure
│   │   ├── 📁 identity/                   # Managed identity
│   │   │   └── 🔷 main.bicep
│   │   ├── 📁 monitoring/                 # App Insights, Log Analytics
│   │   │   ├── 🔷 main.bicep
│   │   │   ├── 🔷 app-insights.bicep
│   │   │   └── 🔷 log-analytics-workspace.bicep
│   │   ├── 📁 network/                    # VNet configuration
│   │   │   └── 🔷 main.bicep
│   │   └── 📁 data/
│   │       └── 🔷 main.bicep
│   └── 📁 workload/                       # Workload resources
│       ├── 🔷 main.bicep
│       ├── 🔷 logic-app.bicep
│       ├── 📁 messaging/                  # Service Bus
│       │   └── 🔷 main.bicep
│       └── 📁 services/                   # Container Apps
│           └── 🔷 main.bicep
├── 🪝 hooks/                              # azd lifecycle scripts
│   ├── 🔵 check-dev-workstation.ps1
│   ├── 🐚 check-dev-workstation.sh
│   ├── 🔵 preprovision.ps1
│   ├── 🐚 preprovision.sh
│   ├── 🔵 postprovision.ps1
│   ├── 🐚 postprovision.sh
│   ├── 🔵 deploy-workflow.ps1
│   └── 🐚 deploy-workflow.sh
├── 📚 docs/
│   ├── 📁 architecture/                   # This documentation
│   │   └── 📁 adr/                        # Architecture Decision Records
│   ├── 📁 devops/
│   └── 📁 hooks/
├── 🐙 .github/
│   └── 📁 workflows/                      # CI/CD pipelines
│       ├── 📄 azure-dev.yml
│       ├── 📄 ci-dotnet.yml
│       └── 📄 ci-dotnet-reusable.yml
├── 🟣 app.sln
├── 📄 azure.yaml
├── 📋 global.json
├── 📝 README.MD
└── 📜 LICENSE
```

---

## 🚀 Quick Start

```bash
# Prerequisites: Azure CLI, Azure Developer CLI (azd), .NET 10 SDK

# 1. Clone and navigate
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring

# 2. Authenticate
azd auth login
az login

# 3. Initialize environment
azd env new dev

# 4. Provision and deploy
azd up

# 5. Local development (with emulators)
cd app.AppHost
dotnet run
```

---

## 📚 Related Documentation

- [Azure Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)
- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [OpenTelemetry .NET](https://opentelemetry.io/docs/instrumentation/net/)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)

---

← Previous | **Index** | [Business Architecture →](01-business-architecture.md)
