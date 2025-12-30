# Azure Logic Apps Monitoring Solution - Architecture Overview

← [Repository Root](../../README.md) | **Index** | [Business Architecture →](01-business-architecture.md)

## Executive Summary

The **Azure Logic Apps Monitoring Solution** is a comprehensive, cloud-native reference application demonstrating best practices for observability, monitoring, and distributed tracing in Azure Logic Apps Standard workflows. Built on .NET Aspire orchestration, this solution showcases enterprise-grade patterns for building observable distributed systems on Azure.

### Key Architectural Highlights

- **Modern Orchestration**: .NET Aspire AppHost provides unified service orchestration with automatic service discovery, health monitoring, and telemetry correlation
- **Event-Driven Architecture**: Azure Service Bus enables loose coupling between order processing and workflow automation
- **Full-Stack Observability**: Application Insights integration with distributed tracing across all components including Logic Apps workflows
- **Infrastructure as Code**: Modular Bicep templates with Azure Developer CLI (azd) for repeatable deployments
- **Cloud-Native Security**: Managed identities eliminate credential management with zero-trust principles

### Target Deployment Environments

| Environment | Purpose | Configuration |
|-------------|---------|---------------|
| Local Development | Developer inner loop with emulators | Aspire dashboard, SQL container, Service Bus emulator |
| Azure | Production-grade cloud deployment | Container Apps, Logic Apps Standard, Azure SQL |

---

## High-Level Architecture

```mermaid
C4Context
    title Azure Logic Apps Monitoring - System Context

    Person(user, "Business User", "Manages orders via web interface")
    Person(ops, "Operations Team", "Monitors health and responds to alerts")

    System_Boundary(solution, "Azure Logic Apps Monitoring Solution") {
        System(webapp, "eShop Web App", "Blazor Server UI for order management")
        System(api, "Orders API", "RESTful API with distributed tracing")
        System(logicapps, "Logic Apps Workflows", "Order processing automation")
    }

    System_Ext(servicebus, "Azure Service Bus", "Async messaging backbone")
    System_Ext(sql, "Azure SQL Database", "Order data persistence")
    System_Ext(appinsights, "Application Insights", "Observability platform")

    Rel(user, webapp, "Places orders", "HTTPS")
    Rel(ops, appinsights, "Monitors", "Azure Portal")
    Rel(webapp, api, "API calls", "HTTP/REST")
    Rel(api, sql, "Persists data", "EF Core")
    Rel(api, servicebus, "Publishes events", "AMQP")
    Rel(servicebus, logicapps, "Triggers workflows", "Service Bus Connector")
    Rel(webapp, appinsights, "Telemetry")
    Rel(api, appinsights, "Telemetry")
    Rel(logicapps, appinsights, "Telemetry")
```

---

## Service Inventory

| Service | Type | Responsibility | Technology | Source |
|---------|------|----------------|------------|--------|
| **eShop.Web.App** | Frontend | Order management UI with real-time updates | Blazor Server, Fluent UI, SignalR | [src/eShop.Web.App/](../../src/eShop.Web.App/) |
| **eShop.Orders.API** | Backend API | Order CRUD, batch processing, event publishing | ASP.NET Core, EF Core, OpenTelemetry | [src/eShop.Orders.API/](../../src/eShop.Orders.API/) |
| **OrdersManagement** | Workflow | Order processing automation | Logic Apps Standard (Stateful) | [workflows/OrdersManagement/](../../workflows/OrdersManagement/) |
| **app.AppHost** | Orchestrator | Service composition and Azure resource wiring | .NET Aspire | [app.AppHost/](../../app.AppHost/) |
| **app.ServiceDefaults** | Library | Cross-cutting concerns: telemetry, resilience, health | .NET 10, OpenTelemetry, Polly | [app.ServiceDefaults/](../../app.ServiceDefaults/) |

---

## Azure Resources

| Resource | Azure Service | Purpose | Bicep Module |
|----------|---------------|---------|--------------|
| Container Apps Environment | Microsoft.App/managedEnvironments | Hosts containerized services | [services/main.bicep](../../infra/workload/services/) |
| Container Registry | Microsoft.ContainerRegistry/registries | Container image storage | [services/main.bicep](../../infra/workload/services/) |
| Service Bus Namespace | Microsoft.ServiceBus/namespaces | Async message brokering | [messaging/main.bicep](../../infra/workload/messaging/main.bicep) |
| Logic App (Standard) | Microsoft.Web/sites | Workflow automation | [logic-app.bicep](../../infra/workload/logic-app.bicep) |
| SQL Database | Microsoft.Sql/servers/databases | Order data persistence | [data/main.bicep](../../infra/shared/data/) |
| Application Insights | Microsoft.Insights/components | APM and distributed tracing | [app-insights.bicep](../../infra/shared/monitoring/app-insights.bicep) |
| Log Analytics Workspace | Microsoft.OperationalInsights/workspaces | Centralized logging | [log-analytics-workspace.bicep](../../infra/shared/monitoring/log-analytics-workspace.bicep) |
| User-Assigned Managed Identity | Microsoft.ManagedIdentity/userAssignedIdentities | Service authentication | [identity/main.bicep](../../infra/shared/identity/) |

---

## Document Navigation

| Document | Description | Audience |
|----------|-------------|----------|
| [01 - Business Architecture](01-business-architecture.md) | Business context, capabilities, value streams | Architects, Product Owners |
| [02 - Data Architecture](02-data-architecture.md) | Data stores, entities, messaging patterns | Architects, Developers |
| [03 - Application Architecture](03-application-architecture.md) | Service catalog, APIs, resilience patterns | Developers, Tech Leads |
| [04 - Technology Architecture](04-technology-architecture.md) | Azure resources, IaC, network topology | Platform Engineers, DevOps |
| [05 - Observability Architecture](05-observability-architecture.md) | Tracing, metrics, health monitoring | SRE, DevOps, Developers |
| [06 - Security Architecture](06-security-architecture.md) | Identity, secrets, network security | Security Engineers, Architects |
| [07 - Deployment Architecture](07-deployment-architecture.md) | CI/CD, azd workflows, environments | DevOps, Platform Engineers |
| [ADR Index](adr/README.md) | Architecture Decision Records | All technical stakeholders |

### Reading Order by Role

| Role | Recommended Path |
|------|------------------|
| **New Developer** | README → 03 (Application) → 05 (Observability) → 07 (Deployment) |
| **Cloud Architect** | README → 01 (Business) → 04 (Technology) → ADRs |
| **Platform Engineer** | README → 04 (Technology) → 07 (Deployment) → 06 (Security) |
| **SRE/DevOps** | README → 05 (Observability) → 07 (Deployment) → 04 (Technology) |

---

## Repository Structure

```
Azure-LogicApps-Monitoring/
├── app.AppHost/                 # .NET Aspire orchestrator
├── app.ServiceDefaults/         # Shared cross-cutting concerns
├── src/
│   ├── eShop.Orders.API/        # Orders backend API
│   └── eShop.Web.App/           # Blazor frontend
├── workflows/
│   └── OrdersManagement/        # Logic Apps workflows
├── infra/                       # Bicep IaC templates
│   ├── shared/                  # Shared infrastructure (identity, monitoring, data)
│   └── workload/                # Workload infrastructure (messaging, services, Logic Apps)
├── hooks/                       # azd lifecycle scripts
└── docs/architecture/           # This documentation
```

---

## Related Documents

- [CONTRIBUTING.md](../../CONTRIBUTING.md) - Contribution guidelines
- [hooks/README.md](../../hooks/README.md) - Developer workflow documentation
- [src/eShop.Orders.API/MIGRATION_GUIDE.md](../../src/eShop.Orders.API/MIGRATION_GUIDE.md) - Database migration guide

---

> **Note:** This documentation reflects the architecture as of December 2025. For the latest changes, refer to the source code and inline comments.
