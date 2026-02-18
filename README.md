# Azure Logic Apps Monitoring Solution

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![.NET Aspire](https://img.shields.io/badge/.NET_Aspire-13.1-7B2FBE?logo=dotnet)](https://learn.microsoft.com/dotnet/aspire/)
[![Azure Logic Apps Standard](https://img.shields.io/badge/Azure_Logic_Apps-Standard-0078D4?logo=microsoftazure)](https://learn.microsoft.com/azure/logic-apps/)
[![Azure Container Apps](https://img.shields.io/badge/Azure_Container_Apps-enabled-0078D4?logo=microsoftazure)](https://learn.microsoft.com/azure/container-apps/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](./LICENSE)
[![azd](https://img.shields.io/badge/azd-ready-0078D4?logo=microsoftazure)](https://learn.microsoft.com/azure/developer/azure-developer-cli/)

A production-ready reference implementation for monitoring Azure Logic Apps Standard workflows using .NET Aspire orchestration, Application Insights, and an end-to-end eShop Orders domain — spanning a REST API, a Blazor web frontend, and event-driven Logic Apps workflows — all deployable to Azure with a single `azd up`.

## Features

**Overview**

This solution provides a complete blueprint for building observable, event-driven systems on Azure — from local development through to production. It demonstrates how to combine .NET Aspire, Azure Logic Apps Standard, and Azure Container Apps with enterprise-grade monitoring backed by Application Insights and Log Analytics.

> 💡 **Why This Matters**: Reduces the time to build a production-ready, monitored Azure solution from weeks to hours by providing a fully wired, one-command deployment template — with zero manual credential management.

> 📌 **How It Works**: .NET Aspire orchestrates all local development resources (Service Bus emulator, SQL Server container, Aspire Dashboard), while `azd` provisions the identical topology to Azure Container Apps and Logic Apps Standard using Bicep Infrastructure-as-Code.

| Feature                         | Description                                                               | Status    |
| ------------------------------- | ------------------------------------------------------------------------- | --------- |
| ⚙️ .NET Aspire Orchestration    | Full local development loop with emulated Service Bus and SQL Server      | ✅ Stable |
| 🚀 One-Command Azure Deployment | `azd up` provisions all infrastructure and deploys all services           | ✅ Stable |
| 📊 End-to-End Observability     | OpenTelemetry traces across API, Web App, and Logic Apps via App Insights | ✅ Stable |
| 📨 Event-Driven Order Pipeline  | Service Bus topics trigger Logic Apps Standard workflows automatically    | ✅ Stable |
| 🔐 Managed Identity Auth        | Zero-credential architecture — all Azure resources use User-Assigned MI   | ✅ Stable |
| 🗄️ Azure SQL with EF Core       | Orders persistence with retry-on-failure, migrations, and resilience      | ✅ Stable |
| 🌐 Blazor Server Frontend       | Fluent UI–based order management UI with SignalR circuit management       | ✅ Stable |
| 🔒 VNet Integration             | Container Apps and Logic Apps isolated in dedicated subnets               | ✅ Stable |
| 🧪 Test Suites                  | Unit and integration test projects for all four components                | ✅ Stable |

## Architecture

**Overview**

The solution follows a top-down, event-driven architecture across four execution layers: user traffic enters through the Blazor Server frontend, flows through the Orders API (hosted in Azure Container Apps), is persisted to Azure SQL and published as an event to Azure Service Bus, which triggers the Logic Apps Standard workflow pipeline. Application Insights and Log Analytics provide a unified observability plane across all layers.

```mermaid
---
title: "Azure Logic Apps Monitoring — System Architecture"
config:
  theme: base
  flowchart:
    htmlLabels: false
---
flowchart TD
    accTitle: Azure Logic Apps Monitoring System Architecture
    accDescr: Top-down architecture showing user traffic flowing from Blazor frontend through Orders API hosted in Azure Container Apps, persisting to Azure SQL, publishing OrderPlaced events to Azure Service Bus which triggers Logic Apps Standard workflows, with Application Insights and Log Analytics providing unified observability

    %% ═══════════════════════════════════════════════════════════════════════════
    %% AZURE / FLUENT ARCHITECTURE PATTERN v1.1
    %% (Semantic + Structural + Font + Accessibility Governance)
    %% ═══════════════════════════════════════════════════════════════════════════
    %% PHASE 1 - STRUCTURAL: TD direction, layered topology, nesting ≤ 2
    %% PHASE 2 - SEMANTIC: 4 classes (azureBlue=HTTP, azureTeal=data,
    %%           azureGreen=async/events, azureYellow=observability)
    %% PHASE 3 - FONT: Dark text (#323130 / #3B2C00) on light fills (WCAG AA ≥4.5:1)
    %% PHASE 4 - ACCESSIBILITY: accTitle + accDescr present; icons on ALL nodes
    %% PHASE 5 - STANDARD: governance block present; classDefs centralized;
    %%           style directives (NOT class) for all subgraph containers
    %% ═══════════════════════════════════════════════════════════════════════════

    classDef azureBlue   fill:#DEECF9,stroke:#004578,stroke-width:2px,color:#323130
    classDef azureTeal   fill:#C8F0E7,stroke:#00666B,stroke-width:2px,color:#323130
    classDef azureGreen  fill:#DFF6DD,stroke:#0B6A0B,stroke-width:2px,color:#323130
    classDef azureYellow fill:#FFF4CE,stroke:#986F0B,stroke-width:2px,color:#3B2C00

    User["👤 End User"]:::azureBlue

    subgraph aca["☁️ Azure Container Apps"]
        direction LR
        WebApp["🌐 eShop Web App\nBlazor Server · Fluent UI"]:::azureBlue
        API["⚙️ Orders API\nASP.NET Core · Swagger"]:::azureBlue
        WebApp -->|"calls REST API"| API
    end

    subgraph persistence["🗄️ Data Layer"]
        SQL[("🗄️ Azure SQL\nOrders DB · EF Core")]:::azureTeal
    end

    subgraph eventing["📨 Azure Service Bus"]
        SBT["📨 orders-placed\nTopic · Subscriptions"]:::azureGreen
    end

    subgraph workflows["⚡ Azure Logic Apps Standard"]
        direction LR
        WF1["⚡ OrdersPlacedProcess"]:::azureGreen
        WF2["⚡ OrdersPlacedCompleteProcess"]:::azureGreen
        WF1 -->|"chains into"| WF2
    end

    subgraph observability["📊 Azure Monitor"]
        direction LR
        AppInsights["📊 Application Insights\nDistributed Tracing"]:::azureYellow
        LogAnalytics["📋 Log Analytics\nCentralized Logs"]:::azureYellow
        AppInsights -->|"exports to"| LogAnalytics
    end

    User      -->|"browses orders"| WebApp
    API       -->|"persists orders"| SQL
    API       -->|"publishes OrderPlaced event"| SBT
    SBT       -->|"triggers"| WF1
    API       -->|"streams telemetry"| AppInsights
    WebApp    -->|"streams telemetry"| AppInsights
    WF1       -->|"streams workflow logs"| LogAnalytics

    style aca          fill:#EFF6FC,stroke:#004578,stroke-width:2px,color:#323130
    style persistence  fill:#F0FBF8,stroke:#00666B,stroke-width:2px,color:#323130
    style eventing     fill:#F3FBF3,stroke:#0B6A0B,stroke-width:2px,color:#323130
    style workflows    fill:#F3FBF3,stroke:#0B6A0B,stroke-width:2px,color:#323130
    style observability fill:#FFFBEE,stroke:#986F0B,stroke-width:2px,color:#3B2C00
```

**Component Roles:**

| Component               | Layer         | Description                                                                                                     |
| ----------------------- | ------------- | --------------------------------------------------------------------------------------------------------------- |
| 🌐 eShop Web App        | Presentation  | Blazor Server with Fluent UI; service discovery via .NET Aspire (`src/eShop.Web.App/`)                          |
| ⚙️ Orders API           | Application   | ASP.NET Core REST API with EF Core, OpenAPI/Swagger, and Service Bus publishing (`src/eShop.Orders.API/`)       |
| 🗄️ Azure SQL            | Data          | Orders persistence with 5-retry resilience, 120 s command timeout, and managed identity auth                    |
| 📨 Azure Service Bus    | Eventing      | `orders-placed` topic decouples the API from Logic Apps; emulated locally by Aspire                             |
| ⚡ Logic Apps Standard  | Workflow      | `OrdersPlacedProcess` → `OrdersPlacedCompleteProcess` async fulfilment pipeline (`workflows/OrdersManagement/`) |
| 📊 Application Insights | Observability | Distributed tracing via OpenTelemetry across all components                                                     |
| 📋 Log Analytics        | Observability | Centralized log aggregation for all Azure resources and workflow run history                                    |

## Quick Start

**Local development** — run the full stack with emulators in under 5 minutes:

```bash
# 1. Clone the repository
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring

# 2. Start the .NET Aspire AppHost
#    (launches API, Web App, Service Bus emulator, SQL Server container)
dotnet run --project app.AppHost/app.AppHost.csproj
```

Open the **Aspire Dashboard** URL printed in the terminal to inspect all running services, structured logs, and distributed traces.

**Deploy to Azure** with a single command:

```bash
# 1. Authenticate with Azure
azd auth login

# 2. Create a new environment
azd env new my-env

# 3. Provision all infrastructure and deploy all services (~15 minutes)
azd up
```

> 💡 **Tip**: `azd up` automatically runs `hooks/preprovision.ps1` to validate prerequisites and `hooks/postprovision.ps1` to configure managed identity SQL access and `.NET` User Secrets — no manual setup required.

## Requirements

**Overview**

The solution targets `.NET 10` and requires the Azure Developer CLI for cloud deployments. All local infrastructure dependencies — SQL Server and Azure Service Bus — are managed automatically by `.NET Aspire` using Docker-based emulators and containers, so no manual Azure resource setup is needed for local development.

> ⚠️ **Note**: Docker Desktop (or an equivalent OCI-compliant runtime) is required for local development. `.NET Aspire` spins up the Azure Service Bus emulator and SQL Server as containers automatically on `dotnet run`.

| Prerequisite                   | Minimum Version | Purpose                                          | Install                                                                    |
| ------------------------------ | --------------- | ------------------------------------------------ | -------------------------------------------------------------------------- |
| 🟣 .NET SDK                    | 10.0.100        | Build and run all projects                       | [dotnet.microsoft.com](https://dotnet.microsoft.com/download)              |
| 🔵 Azure Developer CLI (`azd`) | 1.11.0          | Provision and deploy to Azure                    | [aka.ms/azd](https://aka.ms/azd)                                           |
| 🔵 Azure CLI                   | 2.60.0          | Azure authentication and resource management     | [aka.ms/azure-cli](https://aka.ms/azure-cli)                               |
| 🐳 Docker Desktop              | Latest          | Container runtime for local Aspire orchestration | [docker.com](https://www.docker.com/products/docker-desktop/)              |
| ☁️ Azure Subscription          | —               | Target subscription for `azd up`                 | [portal.azure.com](https://portal.azure.com)                               |
| 💻 PowerShell                  | 7.0+            | Pre/post-provisioning lifecycle hooks            | [github.com/PowerShell](https://github.com/PowerShell/PowerShell/releases) |

## Deployment

**Overview**

The deployment pipeline uses the Azure Developer CLI (`azd`) backed by subscription-scoped Bicep Infrastructure-as-Code. All resources land in a single resource group with deterministic naming (`rg-{solution}-{env}-{location}`). The `hooks/preprovision.ps1` script validates all prerequisites before provisioning begins — and can auto-install missing tools with `-AutoInstall`.

> ⚠️ **Note**: Run `./hooks/preprovision.ps1 -ValidateOnly` before your first `azd up` to check all prerequisites without making any changes.

### Step-by-Step Deployment

```bash
# Step 1: Validate prerequisites (dry run — no changes made)
./hooks/preprovision.ps1 -ValidateOnly

# Step 2: Authenticate with Azure
azd auth login

# Step 3: Create environment and target region
azd env new production
azd env set AZURE_LOCATION eastus2

# Step 4: Provision infrastructure + build and deploy all container apps
azd up

# Step 5: Generate sample orders (optional end-to-end smoke test)
./hooks/Generate-Orders.ps1
```

### Deployed Azure Resources

| Resource                          | Type                     | Purpose                                                            |
| --------------------------------- | ------------------------ | ------------------------------------------------------------------ |
| 🏗️ Container Apps Environment     | Azure Container Apps     | Hosts Orders API and Web App containers                            |
| 📦 Container Registry             | Azure Container Registry | Stores built container images                                      |
| ⚙️ Logic App Standard             | Azure Logic Apps         | Runs OrdersPlacedProcess and OrdersPlacedCompleteProcess workflows |
| 📨 Service Bus Namespace          | Azure Service Bus        | Event backbone with `orders-placed` topic and subscriptions        |
| 🗄️ Azure SQL Database             | Azure SQL                | Orders persistence with EF Core-managed schema                     |
| 📊 Application Insights           | Azure Monitor            | Distributed tracing and performance monitoring                     |
| 📋 Log Analytics Workspace        | Azure Monitor            | Centralized log aggregation for all components                     |
| 🔐 User-Assigned Managed Identity | Azure Identity           | Zero-credential access to all Azure resources                      |
| 🌐 Virtual Network                | Azure Networking         | Subnet isolation for Container Apps, Logic Apps, and data services |

### Supported Environments

```bash
# Valid environment names (enforced via Bicep @allowed parameter)
dev | test | staging | prod
```

## Configuration

**Overview**

Configuration follows a layered model: `appsettings.json` provides shared defaults, `appsettings.Development.json` overrides for local Aspire development, and `hooks/postprovision.ps1` automatically writes all Azure-specific values (connection strings, endpoints, Application Insights keys) into `.NET` User Secrets after `azd up` completes.

> 📌 **How It Works**: After provisioning, `postprovision.ps1` reads `azd` output variables such as `AZURE_SERVICE_BUS_NAMESPACE` and `APPLICATIONINSIGHTS_CONNECTION_STRING` and writes them to User Secrets for `app.AppHost`, `eShop.Orders.API`, and `eShop.Web.App` — making local development against live Azure resources seamless with no manual secret copying.

### Key Configuration Values

| ⚙️ Key                                  | 📁 Project   | 📝 Description                                    | 🔑 Source                                |
| --------------------------------------- | ------------ | ------------------------------------------------- | ---------------------------------------- |
| `ConnectionStrings:OrderDb`             | Orders API   | Azure SQL connection string with managed identity | `azd` output / Aspire resource reference |
| `Azure:ServiceBus:HostName`             | Orders API   | Service Bus namespace FQDN                        | `azd` output                             |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | All projects | Application Insights telemetry ingestion endpoint | `azd` output                             |
| `Azure:TenantId`                        | AppHost      | Azure AD tenant for local dev authentication      | User Secrets                             |
| `Azure:ClientId`                        | AppHost      | Service principal client ID for local dev auth    | User Secrets                             |
| `Azure:ResourceGroup`                   | AppHost      | Resource group name for existing Azure resources  | User Secrets                             |

### AppHost User Secrets (Local Development Only)

Set these in the `app.AppHost/` directory using `dotnet user-secrets set`:

```bash
dotnet user-secrets set "Azure:TenantId"      "<your-tenant-id>"      --project app.AppHost/app.AppHost.csproj
dotnet user-secrets set "Azure:ClientId"      "<your-client-id>"      --project app.AppHost/app.AppHost.csproj
dotnet user-secrets set "Azure:ResourceGroup" "<your-resource-group>" --project app.AppHost/app.AppHost.csproj
```

### HTTP Client Resilience (Orders API)

Configurable in `src/eShop.Orders.API/appsettings.json` via `.NET` Aspire service defaults:

```json
{
  "HttpClient": {
    "OrdersAPIService": {
      "Timeout": "00:02:00",
      "Resilience": {
        "AttemptTimeout": "00:00:30",
        "TotalRequestTimeout": "00:01:30",
        "Retry": { "MaxRetryAttempts": 2 }
      }
    }
  }
}
```

## Usage

**Overview**

Once deployed (or running locally via Aspire), the solution exposes three interaction surfaces: the Blazor Web UI for visual order management, the Orders REST API for programmatic operations, and the Logic Apps workflows that automatically react to every order event published to Service Bus.

### Place an Order via the REST API

```bash
curl -X POST https://<orders-api-url>/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "id": "order-001",
    "customerId": "customer-123",
    "total": 99.99,
    "products": [
      { "sku": "PROD-001", "quantity": 2, "price": 49.99 }
    ]
  }'
```

Expected response (`201 Created`):

```json
{
  "id": "order-001",
  "customerId": "customer-123",
  "status": "Placed",
  "total": 99.99
}
```

### Retrieve Orders

```bash
# Get all orders
curl https://<orders-api-url>/api/orders

# Get a specific order by ID
curl https://<orders-api-url>/api/orders/order-001
```

### Generate Bulk Orders (Smoke Test)

```bash
# Generate sample orders to trigger the end-to-end Logic Apps pipeline
./hooks/Generate-Orders.ps1
```

### OpenAPI / Swagger UI

The Orders API exposes Swagger UI at `/swagger` in Development mode. In Azure, the OpenAPI spec is available at `/openapi/v1.json`.

### Monitor Workflows

After orders are placed, the Logic Apps workflows (`OrdersPlacedProcess` → `OrdersPlacedCompleteProcess`) are triggered automatically via the Service Bus `orders-placed` topic. Monitor execution in:

- **Azure Portal** → Logic App → **Workflow runs** blade
- **Application Insights** → **Transaction search** — filter by `order.id` custom dimension
- **Log Analytics** — query the `AppDependencies` and `AppRequests` tables

## Contributing

**Overview**

Contributions are welcome. This project uses standard GitHub flow — feature branches off `main`, pull requests, and automated validation. The full `.NET` solution builds and tests cleanly with `dotnet build app.sln` and `dotnet test app.sln`.

> 📌 **How It Works**: Fork the repository, create a feature branch, implement changes with tests, then open a pull request against `main`. Validate Bicep infrastructure locally with `az bicep build` before submitting infrastructure changes.

### Development Workflow

```bash
# 1. Fork on GitHub, then clone your fork
git clone https://github.com/<your-fork>/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring

# 2. Create a feature branch
git checkout -b feature/my-improvement

# 3. Build the full solution
dotnet build app.sln

# 4. Run all tests
dotnet test app.sln

# 5. Validate Bicep infrastructure locally (requires Azure CLI with Bicep extension)
az bicep build --file infra/main.bicep

# 6. Push and open a pull request
git push origin feature/my-improvement
```

### Project Structure

| Path                             | Description                                                                       |
| -------------------------------- | --------------------------------------------------------------------------------- |
| 📁 `app.AppHost/`                | .NET Aspire orchestration host — wires all services locally and for Azure         |
| 📁 `app.ServiceDefaults/`        | Shared OpenTelemetry, health checks, and resilience configuration                 |
| 📁 `src/eShop.Orders.API/`       | ASP.NET Core REST API — orders CRUD, Service Bus publishing, EF Core              |
| 📁 `src/eShop.Web.App/`          | Blazor Server web frontend with Fluent UI components                              |
| 📁 `src/tests/`                  | Unit and integration test projects for all four components                        |
| 📁 `workflows/OrdersManagement/` | Azure Logic Apps Standard workflow definitions (JSON)                             |
| 📁 `infra/`                      | Bicep Infrastructure-as-Code — shared, workload, and Logic Apps modules           |
| 📁 `hooks/`                      | `azd` lifecycle PowerShell scripts (preprovision, postprovision, generate-orders) |
| 📁 `prompts/`                    | AI prompt templates for documentation and architecture diagramming                |

## License

This project is licensed under the **MIT License** — see the [`LICENSE`](./LICENSE) file for details.

---

> 💡 **Resources**: [Azure Logic Apps Standard Docs](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview) · [.NET Aspire Docs](https://learn.microsoft.com/dotnet/aspire/) · [Azure Developer CLI Docs](https://learn.microsoft.com/azure/developer/azure-developer-cli/) · [Azure Container Apps Docs](https://learn.microsoft.com/azure/container-apps/)
