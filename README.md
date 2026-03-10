# Azure Logic Apps Monitoring

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![Azure](https://img.shields.io/badge/Azure-Deployed-0078D4?logo=microsoftazure)](https://azure.microsoft.com/)

## Overview

Azure Logic Apps Monitoring is a distributed microservices solution built with **.NET Aspire** that demonstrates end-to-end order management with **Azure Logic Apps Standard** workflow automation. The application integrates a RESTful Orders API, a Blazor Server frontend, and event-driven Logic Apps workflows orchestrated through **Azure Service Bus** messaging. All components are deployed to **Azure Container Apps** with full observability via **OpenTelemetry** and **Application Insights**.

### Key Highlights

- **Distributed orchestration** with .NET Aspire managing service dependencies, health checks, and configuration
- **Event-driven architecture** using Azure Service Bus topics for decoupled order processing
- **Workflow automation** with Logic Apps Standard processing order events from Service Bus
- **Full observability stack** including distributed tracing, metrics, and structured logging
- **Infrastructure as Code** with Bicep modules and Azure Developer CLI (`azd`) lifecycle management

> [!NOTE]
> This project targets **.NET 10.0** and requires the .NET 10 SDK. See the [Requirements](#requirements) section for all prerequisites.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Deployment](#deployment)
- [Usage](#usage)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [Contributing](#contributing)
- [License](#license)

## Architecture

The solution follows a distributed microservices architecture orchestrated by .NET Aspire with event-driven messaging through Azure Service Bus and workflow automation via Logic Apps Standard.

```mermaid
%% ═══════════════════════════════════════════════════════════════════════════
%% AZURE / FLUENT ARCHITECTURE PATTERN v1.1
%% (Semantic + Structural + Font + Accessibility Governance)
%% ═══════════════════════════════════════════════════════════════════════════
%% PHASE 1 - FLUENT UI: All styling uses approved Fluent UI palette only
%% PHASE 2 - GROUPS: Every subgraph has semantic color via style directive
%% PHASE 3 - COMPONENTS: Every node has semantic classDef + icon prefix
%% PHASE 4 - ACCESSIBILITY: accTitle/accDescr present, WCAG AA contrast
%% PHASE 5 - STANDARD: Governance block present, classDefs centralized
%% ═══════════════════════════════════════════════════════════════════════════

graph LR
    accTitle: Azure Logic Apps Monitoring Architecture
    accDescr: Distributed microservices architecture showing the Blazor frontend, Orders API, Azure Service Bus messaging, Logic Apps workflow processing, and data storage components.

    classDef neutral fill:#FAFAFA,stroke:#8A8886,color:#323130
    classDef core fill:#EFF6FC,stroke:#0078D4,color:#323130
    classDef success fill:#DFF6DD,stroke:#107C10,color:#323130
    classDef warning fill:#FFF4CE,stroke:#FFB900,color:#323130
    classDef data fill:#F0E6FA,stroke:#8764B8,color:#323130
    classDef external fill:#E0F7F7,stroke:#038387,color:#323130

    subgraph Clients["Client Layer"]
        A["🖥️ Blazor Web App"]:::core
    end
    style Clients fill:#F3F2F1,stroke:#8A8886

    subgraph Services["Application Services"]
        B["⚙️ Orders API"]:::core
        C["📋 Order Service"]:::core
        D["🗄️ Order Repository"]:::data
    end
    style Services fill:#F3F2F1,stroke:#8A8886

    subgraph Messaging["Event-Driven Messaging"]
        E["📨 Service Bus Topic"]:::warning
    end
    style Messaging fill:#F3F2F1,stroke:#8A8886

    subgraph Workflows["Workflow Automation"]
        F["⚡ Logic App: OrdersPlacedProcess"]:::success
        G["✅ Logic App: OrdersPlacedComplete"]:::success
    end
    style Workflows fill:#F3F2F1,stroke:#8A8886

    subgraph DataStores["Data Layer"]
        H["🛢️ Azure SQL Database"]:::data
        I["📦 Azure Blob Storage"]:::data
    end
    style DataStores fill:#F3F2F1,stroke:#8A8886

    subgraph Observability["Observability"]
        J["📊 Application Insights"]:::external
        K["📈 Log Analytics"]:::external
    end
    style Observability fill:#F3F2F1,stroke:#8A8886

    A -->|"Sends orders via HTTP"| B
    B -->|"Delegates to"| C
    C -->|"Persists via"| D
    D -->|"Reads/writes"| H
    C -->|"Publishes event"| E
    E -->|"Triggers"| F
    F -->|"Completes via"| G
    G -->|"Stores results"| I
    B -.->|"Emits telemetry"| J
    F -.->|"Emits logs"| K
```

### Architecture Decisions

| Decision           | Choice                       | Rationale                                                          |
| ------------------ | ---------------------------- | ------------------------------------------------------------------ |
| 🏗️ Orchestration   | .NET Aspire                  | Unified service dependencies, health checks, and configuration     |
| 📨 Messaging       | Azure Service Bus            | Enterprise-grade pub/sub with topic-based routing                  |
| ⚡ Workflow Engine | Logic Apps Standard          | Low-code workflow automation with Service Bus triggers             |
| 🗄️ Data Store      | Azure SQL Database           | Relational storage with Entity Framework Core and retry resilience |
| 🖥️ Frontend        | Blazor Server                | Interactive server-side rendering with SignalR and Fluent UI       |
| 📊 Observability   | OpenTelemetry + App Insights | Distributed tracing, metrics, and logging across all services      |

## Features

The solution provides a comprehensive set of capabilities for order management and workflow automation.

| Feature                    | Description                                                                                      |
| -------------------------- | ------------------------------------------------------------------------------------------------ |
| 📋 Order Management        | Full CRUD API for placing, retrieving, and deleting orders with validation                       |
| 🖥️ Blazor Web UI           | Interactive frontend with Microsoft Fluent UI components and real-time updates via SignalR       |
| 📨 Event-Driven Processing | Orders published to Azure Service Bus topics for decoupled downstream processing                 |
| ⚡ Workflow Automation     | Azure Logic Apps Standard workflows triggered by Service Bus messages                            |
| 🔄 Service Discovery       | Automatic service-to-service communication via .NET Aspire service discovery                     |
| 🛡️ Resilience Patterns     | Retry (3x exponential backoff), circuit breaker, and timeout policies on all HTTP clients        |
| 📊 Distributed Tracing     | End-to-end request tracing across API, database, and Service Bus with OpenTelemetry              |
| 📈 Custom Metrics          | Application-specific metrics emitted by the Order Service for monitoring dashboards              |
| 🏥 Health Checks           | Kubernetes-compatible `/health` and `/alive` endpoints including database and Service Bus probes |
| 🔐 Managed Identity        | Passwordless authentication to Azure SQL, Service Bus, and Blob Storage via managed identity     |
| 🏗️ Infrastructure as Code  | Complete Bicep modules for VNet, Container Apps, SQL, Service Bus, Logic Apps, and monitoring    |
| 🚀 Azure Developer CLI     | Full `azd` lifecycle with hooks for provisioning, deployment, and workflow configuration         |

### Overview

Each feature is implemented following Azure best practices with production-ready patterns including structured logging, input validation, and graceful error handling. The architecture supports both local development with emulators and cloud deployment with managed Azure services.

## Requirements

The following tools and services are required to build, run, and deploy this solution.

| Requirement                    | Version             | Purpose                                            |
| ------------------------------ | ------------------- | -------------------------------------------------- |
| 🔧 .NET SDK                    | `10.0.100`          | Build and run all .NET projects                    |
| 📦 .NET Aspire Workload        | Latest              | Orchestrate distributed application                |
| ⚙️ Azure Functions Core Tools  | Latest              | Run Logic Apps workflows locally                   |
| ☁️ Azure Developer CLI (`azd`) | Latest              | Provision and deploy to Azure                      |
| 🗄️ SQL Server or Azure SQL     | Any supported       | Store order data via Entity Framework Core         |
| 📨 Azure Service Bus           | Standard or Premium | Topic-based messaging for order events             |
| 🖥️ Node.js                     | LTS                 | Required by Azure Functions runtime for Logic Apps |

### Overview

All runtime dependencies are managed through NuGet packages restored automatically during build. For local development, the .NET Aspire orchestrator can use built-in emulators for Service Bus and SQL Server, reducing the need for Azure subscriptions during development.

> [!TIP]
> Run `dotnet workload install aspire` to install the .NET Aspire workload required for the orchestration host.

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

Expected output:

```text
Cloning into 'Azure-LogicApps-Monitoring'...
remote: Enumerating objects: done.
Receiving objects: 100%, done.
```

### 2. Restore Dependencies

```bash
dotnet restore app.sln
```

Expected output:

```text
  Determining projects to restore...
  Restored app.AppHost/app.AppHost.csproj
  Restored app.ServiceDefaults/app.ServiceDefaults.csproj
  Restored src/eShop.Orders.API/eShop.Orders.API.csproj
  Restored src/eShop.Web.App/eShop.Web.App.csproj
```

### 3. Run Locally with .NET Aspire

```bash
dotnet run --project app.AppHost/app.AppHost.csproj
```

Expected output:

```text
info: Aspire.Hosting.DistributedApplication[0]
      Distributed application started.
      Dashboard: https://localhost:15178
      orders-api: https://localhost:7xxx
      web-app: https://localhost:7xxx
```

The Aspire dashboard opens at the URL shown in the terminal, providing a unified view of all services, logs, and traces.

### Overview

The quick start runs the full distributed application locally using the .NET Aspire host. In development mode, the application uses local emulators for Azure Service Bus and SQL Server when Azure environment variables are not configured. The Aspire dashboard provides real-time telemetry for all registered services.

## Deployment

Deploy the complete solution to Azure using the Azure Developer CLI (`azd`).

### 1. Authenticate with Azure

```bash
azd auth login
```

Expected output:

```text
Logged in to Azure.
```

### 2. Provision and Deploy

```bash
azd up
```

Expected output:

```text
Packaging services (azd package)
Provisioning Azure resources (azd provision)
Deploying services (azd deploy)

SUCCESS: Your application was provisioned and deployed to Azure.
```

> [!IMPORTANT]
> The `azd up` command executes lifecycle hooks defined in `azure.yaml` including pre-provision validation, post-provision SQL managed identity configuration, and pre-deploy Logic Apps workflow deployment.

### Infrastructure Provisioned

The deployment creates the following Azure resources through Bicep modules:

- **Azure Container Apps Environment** with VNet integration
- **Azure Container Registry** for container images
- **Azure SQL Database** with managed identity access
- **Azure Service Bus** namespace with `ordersplaced` topic and subscription
- **Azure Logic Apps Standard** (App Service Plan) with workflow deployment
- **Application Insights** and **Log Analytics Workspace** for observability
- **User Assigned Managed Identity** for service-to-service authentication
- **Storage Accounts** for Logic Apps and application state

### Overview

The deployment uses Azure Developer CLI with Bicep infrastructure templates organized into shared (networking, identity, monitoring) and workload (services, messaging, logic apps) modules. Post-provisioning hooks automatically configure SQL managed identity access and deploy Logic Apps workflows.

## Usage

### Place an Order via API

```bash
curl -X POST https://localhost:7xxx/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "customerId": "customer-001",
    "date": "2025-01-15",
    "deliveryAddress": "123 Main St",
    "total": 99.99,
    "products": [
      { "name": "Widget", "price": 49.99, "quantity": 2 }
    ]
  }'
```

Expected output:

```json
{
  "id": "generated-guid",
  "customerId": "customer-001",
  "date": "2025-01-15",
  "deliveryAddress": "123 Main St",
  "total": 99.99,
  "products": [{ "name": "Widget", "price": 49.99, "quantity": 2 }]
}
```

### Retrieve All Orders

```bash
curl https://localhost:7xxx/api/orders
```

Expected output:

```json
[
  {
    "id": "generated-guid",
    "customerId": "customer-001",
    "date": "2025-01-15",
    "total": 99.99,
    "products": [...]
  }
]
```

### Generate Sample Orders

Use the provided script to populate test data:

```powershell
./hooks/Generate-Orders.ps1
```

Expected output:

```text
Generating sample orders...
Order 1 created successfully.
Order 2 created successfully.
Sample order generation complete.
```

### Overview

The Orders API exposes RESTful endpoints at `/api/orders` with full Swagger/OpenAPI documentation available at `/swagger`. When an order is placed, the Order Service publishes an event to the Azure Service Bus `ordersplaced` topic, which triggers the Logic Apps workflow for downstream processing.

## Configuration

The application uses a layered configuration approach with environment variables, user secrets, and Aspire service defaults.

| Setting             | Environment Variable                    | Default     | Description                                              |
| ------------------- | --------------------------------------- | ----------- | -------------------------------------------------------- |
| 📊 App Insights     | `APPLICATIONINSIGHTS_CONNECTION_STRING` | None        | Azure Monitor telemetry connection string                |
| 📨 Service Bus Host | `MESSAGING_HOST`                        | `localhost` | Service Bus namespace FQDN or `localhost` for emulator   |
| 🗄️ SQL Connection   | `ConnectionStrings:OrderDb`             | None        | Azure SQL or local SQL Server connection string          |
| ☁️ Azure Tenant     | `AZURE_TENANT_ID`                       | None        | Azure AD tenant for local development authentication     |
| 🔑 Azure Client     | `AZURE_CLIENT_ID`                       | None        | Managed identity client ID for local development         |
| 📊 OTLP Endpoint    | `OTEL_EXPORTER_OTLP_ENDPOINT`           | None        | OpenTelemetry collector endpoint for distributed tracing |
| 📍 Azure Location   | `AZURE_LOCATION`                        | None        | Azure region for resource provisioning via `azd`         |
| 🏷️ Environment Name | `AZURE_ENV_NAME`                        | None        | `azd` environment name for resource naming               |

### Overview

In local development mode, the .NET Aspire host automatically configures Service Bus emulator and SQL Server connections. For Azure deployment, managed identity is used for passwordless authentication to all Azure services. Configuration values are injected through `azd` environment variables and Aspire resource references.

> [!WARNING]
> Never commit connection strings or secrets to source control. Use `dotnet user-secrets` for local development and Azure Key Vault or `azd` environment variables for production.

## Project Structure

```text
├── app.AppHost/                    # .NET Aspire orchestration host
│   ├── AppHost.cs                  # Service registration and Azure resource config
│   └── infra/                      # Container Apps manifest templates
├── app.ServiceDefaults/            # Shared Aspire service configuration
│   ├── Extensions.cs               # OpenTelemetry, health checks, resilience
│   └── CommonTypes.cs              # Shared domain models (Order, OrderProduct)
├── src/
│   ├── eShop.Orders.API/           # RESTful Orders Web API
│   │   ├── Controllers/            # OrdersController (CRUD endpoints)
│   │   ├── Services/               # OrderService (business logic, tracing)
│   │   ├── Repositories/           # OrderRepository (EF Core data access)
│   │   ├── Handlers/               # Service Bus message publishers
│   │   ├── HealthChecks/           # DB and Service Bus health probes
│   │   └── Data/                   # OrderDbContext, entity mappings
│   ├── eShop.Web.App/              # Blazor Server frontend
│   │   ├── Components/             # Razor components and pages
│   │   └── Shared/                 # Layout and navigation
│   └── tests/                      # Test projects for all services
│       ├── app.AppHost.Tests/
│       ├── app.ServiceDefaults.Tests/
│       ├── eShop.Orders.API.Tests/
│       └── eShop.Web.App.Tests/
├── workflows/
│   └── OrdersManagement/           # Logic Apps Standard workflows
│       └── OrdersManagementLogicApp/
│           ├── OrdersPlacedProcess/        # Service Bus trigger workflow
│           └── OrdersPlacedCompleteProcess/ # Completion workflow
├── infra/                          # Bicep infrastructure modules
│   ├── main.bicep                  # Root deployment orchestration
│   ├── shared/                     # VNet, identity, monitoring, data
│   └── workload/                   # Container Apps, Service Bus, Logic Apps
├── hooks/                          # azd lifecycle scripts
│   ├── preprovision.ps1            # Pre-deployment validation
│   ├── postprovision.ps1           # Post-deployment SQL config
│   └── deploy-workflow.ps1         # Logic Apps workflow deployment
└── azure.yaml                      # Azure Developer CLI configuration
```

## Testing

The solution includes test projects for each service:

```bash
dotnet test app.sln
```

Expected output:

```text
  Determining projects to restore...
  All projects are up-to-date for restore.
Test run for app.AppHost.Tests
Test run for app.ServiceDefaults.Tests
Test run for eShop.Orders.API.Tests
Test run for eShop.Web.App.Tests

Passed!  - Total: X, Passed: X, Failed: 0
```

Test projects are located under `src/tests/` with dedicated test projects for the AppHost, ServiceDefaults, Orders API, and Web App.

## Contributing

Contributions are welcome. Please follow these guidelines:

### Overview

This project uses standard .NET development practices with C# coding conventions. All contributions must include appropriate tests and pass the existing test suite before submission.

### Steps

1. Fork the repository
2. Create a feature branch from `main`
3. Make changes following the existing code style and patterns
4. Add or update tests for any new functionality
5. Run `dotnet test app.sln` to verify all tests pass
6. Submit a pull request with a clear description of the changes

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

Copyright (c) 2025 Evilázaro Alves
