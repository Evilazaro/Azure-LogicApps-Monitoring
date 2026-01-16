# Azure Logic Apps Monitoring Solution

![License](https://img.shields.io/github/license/Evilazaro/Azure-LogicApps-Monitoring)
![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)
![Azure](https://img.shields.io/badge/Azure-Logic%20Apps-0078D4?logo=microsoftazure)
![azd](https://img.shields.io/badge/azd-compatible-green?logo=microsoft)
![Build](https://img.shields.io/github/actions/workflow/status/Evilazaro/Azure-LogicApps-Monitoring/azure-dev.yml?branch=main)
![Aspire](https://img.shields.io/badge/.NET%20Aspire-13.1.0-512BD4?logo=dotnet)

## Table of Contents

- [Description](#description)
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Services](#services)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)

## Description

The **Azure Logic Apps Monitoring Solution** is a cloud-native reference architecture demonstrating enterprise-grade observability patterns for Azure Logic Apps Standard workflows. Built on **.NET Aspire** orchestration, this solution showcases end-to-end distributed tracing, centralized logging, and comprehensive metrics collection across a microservices-based order management system.

**Key Highlights:**

- **Unified Observability** — OpenTelemetry-based instrumentation with W3C Trace Context propagation
- **Event-Driven Architecture** — Azure Service Bus for reliable, asynchronous order event processing
- **Infrastructure as Code** — Bicep templates with Azure Developer CLI (azd) for repeatable deployments
- **Zero-Secret Authentication** — Managed Identity for all service-to-service communication

## Architecture Overview

```
.NET Aspire AppHost → Azure Container Apps
├── eShop.Orders.API (REST API)
├── eShop.Web.App (Blazor Frontend)
├── Azure SQL Database
├── Azure Service Bus
├── Azure Logic Apps Standard
└── Application Insights
```

The solution follows enterprise architecture principles with clear separation of concerns:

| Layer | Components | Purpose |
|-------|------------|---------|
| **Presentation** | eShop.Web.App (Blazor Server) | User interface |
| **Application** | eShop.Orders.API, Logic Apps | Business logic & workflow orchestration |
| **Platform** | .NET Aspire AppHost | Service orchestration & configuration |
| **Data** | Azure SQL, Service Bus, Storage | Persistence & messaging |
| **Observability** | Application Insights, Log Analytics | Monitoring & telemetry |

For detailed architecture documentation, see [docs/architecture/README.md](docs/architecture/README.md).

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | ≥ 2.60.0 | Azure resource management |
| [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) | ≥ 1.11.0 | Infrastructure provisioning & deployment |
| [.NET SDK](https://dotnet.microsoft.com/download) | 10.0 | Application runtime |
| [Docker](https://www.docker.com/products/docker-desktop) | Latest | Local development & containers |

### Azure Resources

An active Azure subscription with permissions to create:

- Resource Groups
- Azure Container Apps
- Azure SQL Database
- Azure Service Bus
- Azure Logic Apps Standard
- Application Insights & Log Analytics

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

### 2. Authenticate with Azure

```bash
azd auth login
```

### 3. Create a New Environment

```bash
azd env new <environment-name>
```

### 4. Provision and Deploy

```bash
azd up
```

This single command will:

1. Build and test the solution
2. Provision all Azure infrastructure (Bicep)
3. Deploy applications to Azure Container Apps
4. Configure Logic Apps workflows

### Additional Commands

```bash
# Provision infrastructure only
azd provision

# Deploy applications only
azd deploy

# Delete all resources
azd down
```

## Project Structure

```
Azure-LogicApps-Monitoring/
├── app.AppHost/                 # .NET Aspire orchestration host
├── app.ServiceDefaults/         # Cross-cutting concerns (telemetry, health checks)
├── src/
│   ├── eShop.Orders.API/        # REST API for order management
│   ├── eShop.Web.App/           # Blazor Server frontend
│   └── tests/                   # Unit and integration tests
├── infra/                       # Bicep infrastructure templates
│   ├── main.bicep               # Entry point orchestrator
│   ├── shared/                  # Networking, identity, monitoring
│   └── workload/                # Application-specific resources
├── workflows/                   # Logic Apps workflow definitions
│   └── OrdersManagement/        # Order processing workflows
├── hooks/                       # azd lifecycle scripts
├── docs/                        # Comprehensive documentation
└── .github/workflows/           # CI/CD pipelines
```

## Services

| Service | Technology | Description |
|---------|------------|-------------|
| **orders-api** | ASP.NET Core 10.0 | REST API for order CRUD operations |
| **web-app** | Blazor Server | Interactive web frontend |
| **OrdersManagement** | Logic Apps Standard | Workflow automation for order processing |

### Azure Resources Deployed

- **Azure Container Apps** — Hosts .NET applications with auto-scaling
- **Azure SQL Database** — Order data persistence
- **Azure Service Bus** — Asynchronous messaging (`ordersplaced` topic)
- **Azure Logic Apps Standard** — Workflow orchestration
- **Azure Storage** — Workflow state management
- **Application Insights** — Distributed tracing & monitoring
- **Log Analytics Workspace** — Centralized logging

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture Overview](docs/architecture/README.md) | Complete architecture documentation |
| [Business Architecture](docs/architecture/01-business-architecture.md) | Business context & stakeholders |
| [Data Architecture](docs/architecture/02-data-architecture.md) | Data stores & telemetry mapping |
| [Application Architecture](docs/architecture/03-application-architecture.md) | Service catalog & API contracts |
| [Technology Architecture](docs/architecture/04-technology-architecture.md) | Platform services & Azure topology |
| [Observability Architecture](docs/architecture/05-observability-architecture.md) | Distributed tracing & alerting |
| [Security Architecture](docs/architecture/06-security-architecture.md) | Authentication & network security |
| [Deployment Architecture](docs/architecture/07-deployment-architecture.md) | IaC & CI/CD practices |
| [DevOps Practices](docs/devops/README.md) | CI/CD pipeline documentation |
| [Developer Hooks](docs/hooks/README.md) | Automation scripts documentation |
| [ADRs](docs/architecture/adr/README.md) | Architecture Decision Records |

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Setup

```bash
# Restore dependencies
dotnet restore

# Build the solution
dotnet build

# Run tests
dotnet test

# Run locally with Aspire
dotnet run --project app.AppHost
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

**Author:** [Evilazaro](https://github.com/Evilazaro)  
**Repository:** [Azure-LogicApps-Monitoring](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
