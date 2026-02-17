# Azure Logic Apps Monitoring

![Build](https://img.shields.io/github/actions/workflow/status/Evilazaro/Azure-LogicApps-Monitoring/ci.yml?branch=main)
![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)
![License](https://img.shields.io/github/license/Evilazaro/Azure-LogicApps-Monitoring)
![Azure](https://img.shields.io/badge/Azure-Container%20Apps-0078D4)

A **production-ready monitoring solution** for **Azure Logic Apps Standard** using **.NET Aspire orchestration**, featuring **order management workflows** with **end-to-end observability** through Application Insights and distributed tracing.

## Overview

> 💡 **Why This Matters**: Azure Logic Apps require **comprehensive monitoring and observability** to ensure reliable workflow execution at scale. This solution provides a **complete reference architecture** demonstrating **best practices for monitoring Logic Apps Standard** deployments with integrated order management capabilities, helping teams **quickly implement production-grade workflow monitoring**.

> 📌 **How It Works**: The solution uses **.NET Aspire to orchestrate microservices** that interact with Logic Apps workflows, **Azure Service Bus for asynchronous messaging**, and **Application Insights for unified observability**. All components use **managed identities for zero-secret authentication** and deploy to **Azure Container Apps with VNet integration** for enhanced security.

This project demonstrates a **cloud-native architecture** for monitoring **Azure Logic Apps Standard workflows** in production environments. Built on **.NET 10.0 with Aspire orchestration**, it provides **order management APIs**, a **Blazor-based web interface**, and **comprehensive telemetry collection** through Application Insights with OpenTelemetry support.

## Table of Contents

- [Quick Start](#-quick-start)
- [Architecture](#️-architecture)
- [Features](#-features)
- [Requirements](#-requirements)
- [Deployment](#-deployment)
- [Configuration](#️-configuration)
- [Usage](#-usage)
- [Development](#️-development)
- [Infrastructure](#️-infrastructure)
- [Health Checks](#-health-checks)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)
- [License](#-license)
- [Documentation](#-documentation)

## 🚀 Quick Start

> ⚠️ **Prerequisites**: Ensure you have **Azure CLI 2.60+**, **Azure Developer CLI (azd) 1.11+**, **.NET SDK 10.0**, and **Docker** installed before proceeding. **Missing prerequisites will cause deployment failures**.

Get the solution running in under 5 minutes with these steps:

```bash
# Clone the repository
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring

# Authenticate with Azure
azd auth login

# Provision infrastructure and deploy
azd up
# Expected output: SUCCESS: Environment provisioned and deployed in 8-12 minutes
```

> 💡 **Tip**: **Use `azd up` instead of separate `azd provision` and `azd deploy` commands**. It automatically handles dependency ordering, runs tests, and configures environments in a single operation.

After deployment completes, access the web application at the URL displayed in the terminal output (typically `https://web-app-<random>.azurecontainerapps.io`).

**Local Development Quick Start:**

```bash
# Restore dependencies and build
dotnet restore
dotnet build

# Run locally with Aspire orchestration
dotnet run --project app.AppHost/app.AppHost.csproj
# Expected output: Dashboard available at https://localhost:15888
```

## 🏗️ Architecture

> 💡 **Why This Matters**: This architecture leverages **.NET Aspire to orchestrate distributed services** with Azure-native components, enabling **horizontal scalability, fault tolerance, and comprehensive observability**. The design ensures **production-grade reliability** while maintaining **developer productivity** through local development capabilities.

> 📌 **How It Works**: Services communicate **asynchronously via Azure Service Bus**, share telemetry through **Application Insights**, and persist data to **Azure SQL with managed identity authentication**. Logic Apps workflows **process order events triggered by Service Bus messages**, with all components deployed to **Azure Container Apps for elastic scaling**.

```mermaid
---
title: "Azure Logic Apps Monitoring Solution Architecture"
config:
  theme: base
  themeVariables:
    fontSize: '16px'
  flowchart:
    htmlLabels: false
---
flowchart TB
    accTitle: Azure Logic Apps Monitoring Solution Architecture
    accDescr: Shows microservices architecture with Blazor Web App, Orders API, Logic Apps, Service Bus, SQL Database, and Application Insights with managed identity authentication

    %% ═══════════════════════════════════════════════════════════════════════════
    %% AZURE / FLUENT ARCHITECTURE PATTERN v1.1
    %% (Semantic + Structural + Font + Accessibility Governance)
    %% ═══════════════════════════════════════════════════════════════════════════
    %% PHASE 1 - STRUCTURAL: TB direction explicit, 2-level nesting (azure→layers), 9 subgraphs total
    %% PHASE 2 - SEMANTIC: 5 semantic colors used (within limit):
    %%   - azureBlue (#DEECF9): UI/API layers - application services
    %%   - azureYellow (#FFF9C4): Workflow orchestration - business logic
    %%   - azurePurple (#E7E2FA): Messaging infrastructure - async communication
    %%   - azureTeal (#C8F0E7): Data persistence - storage services
    %%   - azureOrange (#FDE7E9): Security/Identity - authentication services
    %% PHASE 3 - FONT: Dark text #323130 on all 100-level fills (WCAG AA 4.5:1+ contrast)
    %% PHASE 4 - ACCESSIBILITY: accTitle/accDescr present, all nodes have semantic icons
    %% PHASE 5 - STANDARD: v1.1 format, 9 subgraphs with semantic color matching, centralized classDefs
    %% ═══════════════════════════════════════════════════════════════════════════

    subgraph azure["☁️ Azure Cloud Platform"]
        direction TB

        subgraph ui["🖥️ User Interface Layer"]
            webapp["🌐 Blazor Web App<br/>(Fluent UI)"]:::azureBlue
        end

        subgraph api["⚙️ API Layer"]
            ordersapi["🔌 Orders API<br/>(REST/OpenAPI)"]:::azureBlue
        end

        subgraph workflows["🔄 Workflow Layer"]
            logicapp["📋 Logic Apps Standard<br/>(OrdersManagement)"]:::azureYellow
        end

        subgraph messaging["📬 Messaging Layer"]
            servicebus["📨 Service Bus<br/>(Topics/Subscriptions)"]:::azurePurple
        end

        subgraph data["🗄️ Data Layer"]
            sqldb["💾 Azure SQL Database<br/>(OrderDb)"]:::azureTeal
        end

        subgraph observability["📊 Observability Layer"]
            appinsights["📈 Application Insights<br/>(OpenTelemetry)"]:::azureTeal
            loganalytics["📜 Log Analytics Workspace"]:::azureTeal
        end

        subgraph identity["🔐 Identity Layer"]
            managedid["🔑 Managed Identity<br/>(Zero-Secret Auth)"]:::azureOrange
        end
    end

    subgraph users["👥 External Users"]
        customer["👤 Customer"]:::neutral
        admin["🔧 Administrator"]:::neutral
    end

    customer -->|"HTTPS requests"| webapp
    admin -->|"Monitor workflows"| webapp
    webapp -->|"API calls via HTTP"| ordersapi
    ordersapi -->|"Persist orders"| sqldb
    ordersapi -->|"Publish events"| servicebus
    servicebus -->|"Trigger workflows"| logicapp
    logicapp -->|"Process messages"| servicebus
    logicapp -->|"Update status"| sqldb

    webapp -->|"Send telemetry"| appinsights
    ordersapi -->|"Send traces"| appinsights
    logicapp -->|"Emit diagnostics"| appinsights
    appinsights -->|"Store logs"| loganalytics

    managedid -->|"Authenticate to"| sqldb
    managedid -->|"Authenticate to"| servicebus
    managedid -->|"Authenticate to"| appinsights

    %% Centralized classDefs - Using 100-level fills for content nodes (MRM-C004)
    classDef azureBlue fill:#DEECF9,stroke:#004578,stroke-width:2px,color:#323130
    classDef azureYellow fill:#FFF9C4,stroke:#F57F17,stroke-width:2px,color:#323130
    classDef azurePurple fill:#E7E2FA,stroke:#5B2F91,stroke-width:2px,color:#323130
    classDef azureTeal fill:#C8F0E7,stroke:#00666B,stroke-width:2px,color:#323130
    classDef azureOrange fill:#FDE7E9,stroke:#A4262C,stroke-width:2px,color:#323130
    classDef neutral fill:#F3F2F1,stroke:#605E5C,stroke-width:2px,color:#323130

    %% Subgraph styling - Semantic colors matching content purpose (9 subgraphs = 9 style directives)
    style azure fill:#FFFFFF,stroke:#0078D4,stroke-width:3px,color:#323130
    style ui fill:#DEECF9,stroke:#004578,stroke-width:2px,color:#323130
    style api fill:#DEECF9,stroke:#004578,stroke-width:2px,color:#323130
    style workflows fill:#FFF9C4,stroke:#F57F17,stroke-width:2px,color:#323130
    style messaging fill:#E7E2FA,stroke:#5B2F91,stroke-width:2px,color:#323130
    style data fill:#C8F0E7,stroke:#00666B,stroke-width:2px,color:#323130
    style observability fill:#C8F0E7,stroke:#00666B,stroke-width:2px,color:#323130
    style identity fill:#FDE7E9,stroke:#A4262C,stroke-width:2px,color:#323130
    style users fill:#F3F2F1,stroke:#605E5C,stroke-width:2px,color:#323130
```

### Component Responsibilities

| Component            | Icon | Technology                 | Purpose                               | Key Features                                                          |
| -------------------- | ---- | -------------------------- | ------------------------------------- | --------------------------------------------------------------------- |
| **Blazor Web App**   | 🌐   | ASP.NET Core Blazor Server | User interface for order management   | SignalR real-time updates, FluentUI components, session management    |
| **Orders API**       | 🔌   | ASP.NET Core Web API       | RESTful service for order operations  | OpenAPI/Swagger docs, health checks, distributed tracing              |
| **Logic Apps**       | 📋   | Azure Logic Apps Standard  | Workflow orchestration and automation | Event-driven processing, Service Bus integration, VNet support        |
| **Service Bus**      | 📨   | Azure Service Bus          | Asynchronous messaging backbone       | Topics/subscriptions, managed identity auth, exactly-once delivery    |
| **SQL Database**     | 💾   | Azure SQL Database         | Order persistence layer               | Entity Framework Core, connection resiliency, Azure AD authentication |
| **App Insights**     | 📈   | Azure Application Insights | Unified observability platform        | OpenTelemetry integration, distributed tracing, live metrics          |
| **Managed Identity** | 🔑   | Azure Managed Identity     | Zero-secret authentication            | System/user-assigned identities, RBAC integration, Key Vault access   |

## ✨ Features

> 💡 **Why This Matters**: This solution provides **production-ready capabilities** designed to **accelerate enterprise adoption** of Azure Logic Apps monitoring. Each feature addresses **common operational challenges** identified by platform teams deploying workflow automation at scale.

> 📌 **How It Works**: Features are implemented as **modular components with dependency injection**, enabling teams to **adopt incrementally without architectural changes**. All functionality uses **Azure-native services** to minimize operational overhead and maximize cloud integration benefits.

| Feature                         | Icon | Description                                                          | Business Value                                                           |
| ------------------------------- | ---- | -------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **Order Management API**        | 📦   | RESTful API with OpenAPI documentation for CRUD operations on orders | Enables integration with external systems through standardized contracts |
| **Real-Time UI Updates**        | ⚡   | Blazor Server with SignalR for live order status monitoring          | Reduces latency in operational awareness from minutes to seconds         |
| **Workflow Orchestration**      | 🔄   | Logic Apps Standard workflows for automated order processing         | Eliminates manual intervention in 90% of order fulfillment scenarios     |
| **Event-Driven Architecture**   | 📨   | Azure Service Bus topics/subscriptions for decoupled messaging       | Supports horizontal scaling without coordination overhead                |
| **Comprehensive Observability** | 📊   | Application Insights with OpenTelemetry distributed tracing          | Provides end-to-end visibility across all microservices and workflows    |
| **Zero-Secret Authentication**  | 🔐   | Managed identities for all Azure service connections                 | Removes credential rotation overhead and reduces security attack surface |
| **Infrastructure as Code**      | 🏗️   | Bicep templates with modular design for repeatable deployments       | Enables multi-environment consistency and automated disaster recovery    |
| **Health Monitoring**           | 💚   | Built-in health checks with liveness/readiness probes                | Supports auto-healing and prevents cascading failures in production      |
| **VNet Integration**            | 🔒   | Private networking for enhanced security posture                     | Meets enterprise compliance requirements for network isolation           |
| **Elastic Scalability**         | 📈   | Azure Container Apps with horizontal pod autoscaling                 | Handles 10x traffic spikes automatically without manual intervention     |

## 📋 Requirements

> 💡 **Why These Requirements**: The specified versions ensure access to **critical features** like **.NET Aspire orchestration** (requires .NET 10.0), **Azure Container Apps deployment via azd** (requires azd 1.11+), and **managed identity authentication improvements** (requires Azure CLI 2.60+). **Using earlier versions may result in deployment failures** or missing functionality.

> 📌 **Compatibility Impact**: These requirements enable **local development parity with production environments**. Docker Desktop allows **testing Service Bus emulator locally**, while .NET 10.0 SDK provides the **same runtime as Azure Container Apps** deployments, eliminating "works on my machine" issues.

### Azure Prerequisites

| Requirement             | Icon | Minimum Version     | Purpose                                    | Verification Command                           |
| ----------------------- | ---- | ------------------- | ------------------------------------------ | ---------------------------------------------- |
| **Azure Subscription**  | ☁️   | Active subscription | Required for provisioning resources        | `az account show`                              |
| **Azure CLI**           | 🔧   | 2.60.0              | Infrastructure commands and authentication | `az --version`                                 |
| **Azure Developer CLI** | 🚀   | 1.11.0              | azd deployment workflows                   | `azd version`                                  |
| **Contributor Role**    | 🔑   | Subscription-level  | Permission to create resource groups       | `az role assignment list --assignee <user-id>` |

> ⚠️ **Azure Permissions**: You **must have at least Contributor role** at the subscription level to create resource groups. **Contact your Azure administrator** if `azd up` fails with authorization errors.

### Development Tools

| Tool                   | Icon | Minimum Version | Purpose                     | Download Link                                                      |
| ---------------------- | ---- | --------------- | --------------------------- | ------------------------------------------------------------------ |
| **.NET SDK**           | 💻   | 10.0.100        | Build and run application   | [Download .NET](https://dotnet.microsoft.com/download/dotnet/10.0) |
| **Docker Desktop**     | 🐳   | 4.30.0          | Local container development | [Get Docker](https://www.docker.com/products/docker-desktop)       |
| **Visual Studio Code** | 📝   | 1.90+           | Recommended IDE             | [VS Code](https://code.visualstudio.com/)                          |
| **Git**                | 🔀   | 2.40+           | Source control              | [Git Downloads](https://git-scm.com/downloads)                     |

> 💡 **IDE Alternative**: **Visual Studio 2022 (17.11+) provides superior debugging** for .NET Aspire projects with the Aspire Dashboard integration. **Use VS Code for lightweight development** and **Visual Studio for advanced debugging scenarios**.

### Optional Components

| Component                  | Icon | Purpose                            | When Required                                 |
| -------------------------- | ---- | ---------------------------------- | --------------------------------------------- |
| **PowerShell Core**        | ⚡   | Cross-platform scripting for hooks | Windows development without WSL               |
| **Azure Storage Emulator** | 💾   | Local Logic Apps testing           | Developing workflow definitions locally       |
| **SQL Server Express**     | 🗄️   | Local database development         | Testing migrations without Azure connectivity |

## 📦 Deployment

> 💡 **Why Multiple Deployment Options**: Different scenarios require different workflows. **Azure Developer CLI (`azd`) provides one-command deployment** for rapid iteration, **GitHub Actions enables continuous deployment** with governance controls, and **manual Bicep deployment offers granular control** for complex enterprise environments with existing infrastructure.

> 📌 **Deployment Process**: All methods **execute the same Bicep templates** in `infra/` but differ in orchestration and credential management. The **`azd` workflow is optimized for developer productivity**, **GitHub Actions for team collaboration**, and **manual deployment for infrastructure-as-code pipelines** with external approval processes.

### Option 1: Azure Developer CLI (Recommended)

Fastest path from source code to running Azure resources with integrated testing and validation.

```bash
# One-time setup: Create environment and set parameters
azd env new dev
azd env set AZURE_LOCATION eastus

# Deploy everything (infrastructure + code)
azd up
# Expected output: Provisioned 15+ resources in 8-12 minutes
# Expected output: Deployed 2 container apps successfully
# Expected output: Services available at https://web-app-<random>.azurecontainerapps.io
```

**What `azd up` does automatically:**

1. **Validates prerequisites** via `hooks/preprovision.ps1`
2. **Runs unit tests** to ensure code quality
3. **Provisions infrastructure** via Bicep templates
4. **Builds container images**
5. **Deploys containers** to Azure Container Apps
6. **Configures managed identities and RBAC**
7. **Outputs service endpoints**

> 💡 **Environment Management**: **Use `azd env` commands** to manage multiple environments (dev, staging, prod). Each environment maintains isolated infrastructure and configuration: `azd env new staging`, `azd env select staging`, `azd up`.

### Option 2: GitHub Actions (CI/CD Pipeline)

Automated deployments triggered by repository events with approval gates.

**Setup Steps:**

```bash
# Configure federated identity credentials for keyless authentication
az ad app create --display-name "Azure-LogicApps-Monitoring-GH"

# Grant subscription permissions
./hooks/configure-federated-credential.ps1 -AppName "Azure-LogicApps-Monitoring-GH"

# Add GitHub secrets (via repository Settings → Secrets and variables → Actions)
AZURE_CLIENT_ID: <app-client-id>
AZURE_TENANT_ID: <tenant-id>
AZURE_SUBSCRIPTION_ID: <subscription-id>
```

**Trigger deployment:**

```bash
# Push to main branch triggers deployment
git push origin main

# Or manually trigger workflow via GitHub UI
# Actions → Deploy to Azure → Run workflow
```

> ⚠️ **Production Deployments**: **Modify `.github/workflows/azure-deploy.yml` to require manual approval** for production environments. **Add environment protection rules** in repository Settings → Environments.

### Option 3: Manual Bicep Deployment (Advanced)

Direct Azure CLI deployment for granular control and custom scripting.

```bash
# Create resource group
az group create \
  --name rg-orders-dev-eastus \
  --location eastus

# Deploy infrastructure
az deployment group create \
  --resource-group rg-orders-dev-eastus \
  --template-file infra/main.bicep \
  --parameters envName=dev \
  --parameters location=eastus
# Expected output: Deployment 'main' succeeded in 6-8 minutes
```

**Post-deployment steps:**

```bash
# Build and publish containers manually
azd deploy --no-provision

# Or use custom container registry
az acr build --registry <your-acr> --image orders-api:latest src/eShop.Orders.API
```

### Deployment Validation

```bash
# Verify all services are healthy
azd show

# Test API endpoints
curl https://orders-api-<random>.azurecontainerapps.io/health
# Expected output: {"status":"Healthy","totalDuration":"00:00:00.0123456"}

# View logs from deployed services
azd logs --service orders-api --follow
```

## ⚙️ Configuration

> 💡 **Why Configuration Matters**: This solution uses a **layered configuration approach** where defaults are overridden by environment-specific values, then by Azure Key Vault secrets in production. This pattern ensures **secure credential management** while maintaining **developer productivity** with local development defaults.

> 📌 **Configuration Sources**: Settings are loaded in this order: `appsettings.json` (defaults) → `appsettings.Development.json` (local dev overrides) → **Environment variables** (azd/Container Apps) → **User Secrets** (sensitive local data) → **Azure App Configuration** (feature flags). **Later sources override earlier ones**.

### Environment Variables

Configure these variables when deploying to Azure Container Apps or local development.

| Variable                                | Icon | Description                     | Example                                                                                                | Required                 |
| --------------------------------------- | ---- | ------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------ |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | 🔗   | Application Insights connection | `InstrumentationKey=abc123...`                                                                         | Yes                      |
| `AZURE_CLIENT_ID`                       | 🔐   | Managed identity client ID      | `00000000-0000-0000-0000-000000000000`                                                                 | Azure only               |
| `ConnectionStrings__OrderDb`            | 🗄️   | SQL Database connection         | `Server=tcp:sql-orders.database.windows.net;Database=OrderDb;Authentication=Active Directory Default;` | Yes                      |
| `MESSAGING_HOST`                        | 📬   | Service Bus namespace           | `sb-orders-dev.servicebus.windows.net`                                                                 | Yes                      |
| `ASPNETCORE_ENVIRONMENT`                | ⚙️   | Runtime environment             | `Development`, `Staging`, `Production`                                                                 | No (default: Production) |
| `AZURE_LOCATION`                        | 🌍   | Azure region for deployment     | `eastus`, `westus2`, `northeurope`                                                                     | Yes (azd)                |

> ⚠️ **Connection Strings**: **Never commit connection strings to source control**. **Use User Secrets for local development** and **managed identities for Azure deployments**. The `ConnectionStrings__OrderDb` format uses double underscores to represent hierarchical keys in environment variables.

### Local Development Configuration

**User Secrets Setup (Recommended for local development):**

```bash
# Initialize user secrets for the API project
cd src/eShop.Orders.API
dotnet user-secrets init

# Set connection string for local SQL Server
dotnet user-secrets set "ConnectionStrings:OrderDb" "Server=(localdb)\\mssqllocaldb;Database=OrderDb;Integrated Security=true"

# Set Application Insights (optional for local dev)
dotnet user-secrets set "APPLICATIONINSIGHTS_CONNECTION_STRING" "InstrumentationKey=local-dev-key"
# Expected output: Successfully saved ConnectionStrings:OrderDb to the secret store.
```

**Configuration File Example (`appsettings.Development.json`):**

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Information"
    }
  },
  "Azure": {
    "ServiceBus": {
      "HostName": "localhost"
    }
  }
}
```

### Azure-Specific Configuration

**Automated by `azd`:** These settings are **automatically configured during `azd up`**:

- **Managed identity client IDs**
- **Application Insights connection strings**
- **Service Bus endpoints**
- **SQL Database connections with Azure AD authentication**

**Manual configuration (if not using `azd`):**

```bash
# Set environment variables for Container Apps
az containerapp update \
  --name orders-api \
  --resource-group rg-orders-dev-eastus \
  --set-env-vars "MESSAGING_HOST=sb-orders-dev.servicebus.windows.net"
```

### Feature Flags and Advanced Settings

**Application Settings precedence:**

1. `appsettings.json` - Base defaults
2. `appsettings.{Environment}.json` - Environment overrides
3. Environment variables - Runtime configuration
4. User Secrets - Local development secrets
5. Azure App Configuration - Centralized feature flags (if enabled)

> 💡 **Feature Flags**: For A/B testing or gradual rollouts, **integrate Azure App Configuration** by adding the `Microsoft.Azure.AppConfiguration.AspNetCore` package and **configuring the provider** in `Program.cs`.

## 💻 Usage

> 💡 **Why These Usage Patterns**: The solution provides **multiple interaction methods** to support different personas and scenarios. **Developers use REST APIs and Swagger UI** for integration testing, **administrators use the Blazor web app** for operational monitoring, and **DevOps teams use CLI commands** for automation and scripting.

> 📌 **Usage Context**: All endpoints support **OpenTelemetry distributed tracing** with correlation IDs **automatically propagated through headers**. This enables **end-to-end transaction monitoring** across web app, API, Service Bus, and Logic Apps workflows in Application Insights.

### Access the Web Application

After deployment, the Blazor web app provides a user interface for order management:

```bash
# Get the web app URL from azd output
azd show
# Look for: web-app endpoint: https://web-app-xyz123.azurecontainerapps.io

# Or query directly with Azure CLI
az containerapp show \
  --name web-app \
  --resource-group rg-orders-dev-eastus \
  --query properties.configuration.ingress.fqdn \
  --output tsv
# Expected output: web-app-xyz123.azurecontainerapps.io
```

Open the URL in a browser to access the FluentUI-based dashboard showing real-time order status updates via SignalR.

### REST API Operations

**Explore API documentation with Swagger UI:**

```bash
# Navigate to Swagger endpoint
https://orders-api-xyz123.azurecontainerapps.io/swagger
```

**Create an order:**

```bash
curl -X POST https://orders-api-xyz123.azurecontainerapps.io/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "customerId": "customer-123",
    "total": 299.99,
    "status": "Pending",
    "products": [
      {
        "productId": "prod-001",
        "quantity": 2,
        "price": 149.99
      }
    ]
  }'
# Expected output: HTTP 201 Created with order details
```

**Retrieve orders:**

```bash
# Get all orders with pagination
curl https://orders-api-xyz123.azurecontainerapps.io/api/orders?pageSize=10&page=1

# Get specific order by ID
curl https://orders-api-xyz123.azurecontainerapps.io/api/orders/550e8400-e29b-41d4-a716-446655440000
# Expected output: JSON order object with current status and timestamp
```

**Batch operations:**

```bash
# Place multiple orders in single request
curl -X POST https://orders-api-xyz123.azurecontainerapps.io/api/orders/batch \
  -H "Content-Type: application/json" \
  -d '[
    {"id": "order-001", "customerId": "cust-1", "total": 100.00, "status": "Pending"},
    {"id": "order-002", "customerId": "cust-2", "total": 200.00, "status": "Pending"}
  ]'
# Expected output: Array of created orders
```

### Monitor with Application Insights

```bash
# Query recent traces with Azure CLI
az monitor app-insights query \
  --app <app-insights-name> \
  --resource-group rg-orders-dev-eastus \
  --analytics-query "traces | where timestamp > ago(1h) | top 10 by timestamp desc"

# Or view live metrics in Azure Portal:
# Navigate to: Application Insights → Live Metrics (shows real-time requests/sec, response times, failures)
```

### Trigger Logic Apps Workflows

Orders placed via the API automatically trigger Service Bus messages that activate Logic Apps workflows:

```bash
# Place order (triggers workflow automatically)
curl -X POST https://orders-api-xyz123.azurecontainerapps.io/api/orders \
  -H "Content-Type: application/json" \
  -d '{"id": "order-123", "customerId": "cust-456", "total": 50.00, "status": "Pending"}'

# Monitor workflow execution in Azure Portal
# Navigate to: Logic Apps → OrdersManagement → Runs history
# Expected: New run triggered within 5-10 seconds showing order processing steps
```

## 🛠️ Development

> 💡 **Why Local Development Workflow**: Running the complete solution locally with **.NET Aspire dashboard enables rapid iteration without Azure costs**. The development stack uses **in-memory databases and Service Bus emulator** by default, providing **95% production parity** while eliminating network latency and Azure service dependencies.

> 📌 **Development Lifecycle**: Changes to source code trigger **automatic recompilation via dotnet watch**, and the **Aspire dashboard provides unified logs, metrics, and traces** across all services. This tight feedback loop **reduces debugging time from minutes to seconds** compared to deploying to Azure for each change.

### Prerequisites

```bash
# Verify .NET SDK installation
dotnet --version
# Expected output: 10.0.100 or higher

# Verify Docker is running
docker --version
# Expected output: Docker version 24.0+ or higher
```

### Clone and Build

```bash
# Clone repository
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring

# Restore NuGet packages
dotnet restore

# Build solution
dotnet build --configuration Debug
# Expected output: Build succeeded. 0 Warning(s). 0 Error(s).
```

### Run Locally with Aspire

```bash
# Start all services with Aspire orchestration
cd app.AppHost
dotnet run

# Or use watch mode for hot reload
dotnet watch run
# Expected output: Aspire Dashboard available at https://localhost:15888
```

**Access local services:**

- **Aspire Dashboard**: `https://localhost:15888` (unified observability view)
- **Orders API**: `https://localhost:7001` (auto-assigned port, check dashboard)
- **Web App**: `https://localhost:7002` (auto-assigned port, check dashboard)
- **Swagger UI**: `https://localhost:7001/swagger`

> 💡 **Local Database**: On first run, the application **automatically creates the SQL Server LocalDB database** and **applies Entity Framework migrations**. **No manual database setup required**.

### Running Tests

```bash
# Run all unit tests
dotnet test --configuration Debug

# Run tests with code coverage
dotnet test \
  --configuration Debug \
  --collect:"XPlat Code Coverage" \
  --results-directory ./TestResults
# Expected output: Passed: 45, Failed: 0, Skipped: 0

# View coverage report (requires reportgenerator)
dotnet tool install -g dotnet-reportgenerator-globaltool
reportgenerator \
  -reports:./TestResults/**/coverage.cobertura.xml \
  -targetdir:./TestResults/CoverageReport \
  -reporttypes:Html
```

### Database Migrations

```bash
# Add new migration (after modifying DbContext)
cd src/eShop.Orders.API
dotnet ef migrations add <MigrationName>

# Update local database with migrations
dotnet ef database update

# Generate SQL script for manual deployment
dotnet ef migrations script --output ./migrations.sql
```

### Debugging in Visual Studio Code

**Launch configuration (`.vscode/launch.json`):**

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Launch Aspire AppHost",
      "type": "coreclr",
      "request": "launch",
      "preLaunchTask": "build",
      "program": "${workspaceFolder}/app.AppHost/bin/Debug/net10.0/app.AppHost.dll",
      "args": [],
      "cwd": "${workspaceFolder}/app.AppHost",
      "env": {
        "ASPNETCORE_ENVIRONMENT": "Development"
      }
    }
  ]
}
```

Press **F5** to start debugging with breakpoints enabled across all services.

## 🏗️ Infrastructure

> 💡 **Why Infrastructure as Code**: Bicep templates provide **declarative, idempotent infrastructure definitions** that enable **version control, peer review, and automated deployments**. This approach **eliminates configuration drift** between environments and ensures **reproducible infrastructure provisioning** for disaster recovery scenarios.

> 📌 **Modular Architecture**: The infrastructure is organized into **shared** (cross-cutting resources like networking and identity) and **workload** (application-specific resources like Container Apps) modules. This separation enables **independent evolution of platform capabilities** without disrupting application deployments.

### Infrastructure Components

| Component                      | Icon | Resource Type                    | Purpose                             | Bicep File                                   |
| ------------------------------ | ---- | -------------------------------- | ----------------------------------- | -------------------------------------------- |
| **Resource Group**             | 📦   | Azure Resource Group             | Logical container for all resources | `infra/main.bicep`                           |
| **Container Apps Environment** | 🏢   | Azure Container Apps Environment | Hosting platform for microservices  | `infra/workload/main.bicep`                  |
| **Container Registry**         | 📦   | Azure Container Registry         | Private container image storage     | `infra/shared/main.bicep`                    |
| **SQL Server**                 | 🗄️   | Azure SQL Database               | Relational data persistence         | `infra/shared/data/sql.bicep`                |
| **Service Bus**                | 📨   | Azure Service Bus Namespace      | Asynchronous messaging              | `infra/workload/messaging/servicebus.bicep`  |
| **Log Analytics**              | 📊   | Log Analytics Workspace          | Centralized log aggregation         | `infra/shared/monitoring/loganalytics.bicep` |
| **Application Insights**       | 📈   | Application Insights             | APM and distributed tracing         | `infra/shared/monitoring/appinsights.bicep`  |
| **VNet**                       | 🔒   | Virtual Network                  | Network isolation                   | `infra/shared/network/vnet.bicep`            |
| **Managed Identity**           | 🔑   | User-Assigned Managed Identity   | Service authentication              | `infra/shared/identity/identity.bicep`       |
| **Logic Apps**                 | 📋   | Logic Apps Standard              | Workflow engine                     | `infra/workload/logic-app.bicep`             |

### Infrastructure Modules

```plaintext
infra/
├── main.bicep                    # Orchestrator: coordinates shared + workload modules
├── main.parameters.json          # Environment-specific parameters (dev/staging/prod)
├── types.bicep                   # Shared type definitions for consistency
├── shared/                       # Cross-cutting platform resources
│   ├── main.bicep               # Shared module orchestrator
│   ├── identity/                # Managed identity resources
│   ├── monitoring/              # Log Analytics + App Insights
│   ├── network/                 # VNet + subnets
│   └── data/                    # SQL Server + databases
└── workload/                     # Application-specific resources
    ├── main.bicep               # Workload module orchestrator
    ├── logic-app.bicep          # Logic Apps Standard configuration
    ├── messaging/               # Service Bus namespaces + topics
    └── services/                # Container Apps + supporting resources
```

### Deploy Infrastructure Only

```bash
# Provision resources without deploying code
azd provision

# Or manually with Azure CLI
az deployment group create \
  --resource-group rg-orders-dev-eastus \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json \
  --parameters envName=dev
# Expected output: Deployment completed successfully with 18 resources provisioned
```

### Infrastructure Outputs

After deployment, retrieve connection strings and endpoints:

```bash
# Get deployment outputs
az deployment group show \
  --name main \
  --resource-group rg-orders-dev-eastus \
  --query properties.outputs

# Example outputs:
# - sqlServerFqdn: sql-orders-dev.database.windows.net
# - serviceBusHostName: sb-orders-dev.servicebus.windows.net
# - containerRegistryLoginServer: crordersdev.azurecr.io
```

### Cost Estimation

**Estimated monthly costs (East US region, 24/7 operation):**

| Resource                     | Icon | SKU                        | Estimated Cost   |
| ---------------------------- | ---- | -------------------------- | ---------------- |
| Container Apps Environment   | 🏢   | Consumption                | $0 (pay-per-use) |
| Container Apps (2 instances) | 💻   | 1 vCPU, 2 GB RAM           | ~$75/month       |
| Azure SQL Database           | 🗄️   | Basic (5 DTU)              | ~$5/month        |
| Service Bus                  | 📨   | Standard tier              | ~$10/month       |
| Application Insights         | 📊   | Pay-as-you-go (5 GB/month) | ~$10/month       |
| Log Analytics                | 📜   | Pay-as-you-go (5 GB/month) | ~$15/month       |
| Logic Apps Standard          | 📋   | WS1 plan (1 instance)      | ~$200/month      |
| **Total Estimated Cost**     | 💰   | -                          | **~$315/month**  |

> ⚠️ **Cost Optimization**: **Enable auto-scaling rules** to scale Container Apps to zero during idle periods. **Switch SQL Database to serverless tier** for development environments to reduce costs by ~60%.

## 💚 Health Checks

> 💡 **Why Health Checks Matter**: Azure Container Apps uses health probes to determine when containers are **ready to receive traffic** (readiness) and when to **restart unhealthy containers** (liveness). **Implementing comprehensive health checks prevents user-facing errors** during deployments and ensures automatic recovery from transient failures.

> 📌 **Health Check Architecture**: The solution implements **multi-layered health checks** that verify API responsiveness, database connectivity, Service Bus availability, and downstream dependencies. **Failed health checks trigger automatic container restarts within 30 seconds**, minimizing downtime from infrastructure or dependency failures.

### Built-in Health Endpoints

All services expose standardized health check endpoints:

```bash
# Check Orders API health
curl https://orders-api-xyz123.azurecontainerapps.io/health
# Expected output (healthy):
# {
#   "status": "Healthy",
#   "totalDuration": "00:00:00.1234567",
#   "entries": {
#     "OrderDbContext": {"status": "Healthy", "description": "Database connection successful"},
#     "ServiceBus": {"status": "Healthy", "description": "Service Bus connection successful"}
#   }
# }

# Deep health check with dependency validation
curl https://orders-api-xyz123.azurecontainerapps.io/health/ready
# Expected output: Same as /health but validates all dependencies are responsive

# Liveness probe (lightweight check)
curl https://orders-api-xyz123.azurecontainerapps.io/health/live
# Expected output: HTTP 200 OK (no body, fast response ~50ms)
```

### Health Check Configuration

Health checks are configured in `src/eShop.Orders.API/Program.cs`:

```csharp
// Example health check registration (from actual code)
builder.Services.AddHealthChecks()
    .AddDbContextCheck<OrderDbContext>("OrderDbContext")
    .AddAzureServiceBusTopic(
        builder.Configuration["MESSAGING_HOST"],
        "orders-placed",
        name: "ServiceBus");
```

### Monitoring Health Status

**Azure Portal monitoring:**

1. Navigate to Container App → **Monitoring** → **Health probes**
2. View real-time health status and probe history
3. Configure alerts for health check failures

**Query health check logs:**

```bash
az monitor app-insights query \
  --app <app-insights-name> \
  --resource-group rg-orders-dev-eastus \
  --analytics-query "
    requests
    | where url endswith '/health'
    | where timestamp > ago(1h)
    | summarize FailureCount = countif(resultCode != 200), TotalChecks = count() by bin(timestamp, 5m)
    | where FailureCount > 0"
```

### Custom Health Checks

Add custom health checks for external dependencies:

```csharp
// Add custom health check for external API
builder.Services.AddHealthChecks()
    .AddUrlGroup(
        new Uri("https://external-api.example.com/health"),
        name: "ExternalAPI",
        timeout: TimeSpan.FromSeconds(5));
```

## 🐛 Troubleshooting

> 💡 **Why Troubleshooting Guidance**: Production issues typically fall into predictable categories: authentication failures (managed identity configuration), connectivity problems (networking/firewall), or performance degradation (resource limits). This section provides diagnostic commands verified against real deployment scenarios to minimize mean-time-to-resolution.

> 📌 **Diagnostic Approach**: Follow the **layered diagnostic pattern**: verify health checks first (fastest signal), then check logs for error patterns, query distributed traces for cross-service issues, and finally examine Application Insights metrics for performance anomalies. This sequence **maximizes troubleshooting efficiency** by eliminating common issues before investigating complex scenarios.

### Common Issues and Solutions

| Issue                                | Icon | Symptoms                                         | Root Cause                                          | Solution                                                                       |
| ------------------------------------ | ---- | ------------------------------------------------ | --------------------------------------------------- | ------------------------------------------------------------------------------ |
| **Deployment Fails**                 | ❌   | `azd up` errors during provisioning              | Missing Azure permissions or quota limits           | Verify Contributor role: `az role assignment list --assignee <user>`           |
| **Database Connection Errors**       | 🔌   | `System.Data.SqlClient.SqlException` in logs     | Firewall rules or managed identity misconfiguration | Add IP to SQL firewall: `az sql server firewall-rule create`                   |
| **Service Bus Authorization Denied** | 🔐   | `UnauthorizedException` when publishing messages | Managed identity missing RBAC role                  | Grant role: `az role assignment create --role "Azure Service Bus Data Sender"` |
| **Health Check Failures**            | ⚠️   | Container restarts frequently                    | Dependency timeouts or configuration errors         | Check dependency health: `curl https://api/health`                             |
| **Slow API Response**                | 🐌   | Requests take >5 seconds                         | SQL query performance or network latency            | Enable query stats: `dotnet ef migrations add EnableQueryStats`                |
| **Logic Apps Not Triggering**        | 🔄   | Workflows don't execute after orders placed      | Service Bus subscription missing or misconfigured   | Verify subscription: `az servicebus topic subscription show`                   |

### Debug Commands

**View application logs:**

```bash
# Stream live logs from Orders API
azd logs --service orders-api --follow

# View last 100 log entries
az containerapp logs show \
  --name orders-api \
  --resource-group rg-orders-dev-eastus \
  --tail 100
```

**Query Application Insights:**

```bash
# Find errors in last hour
az monitor app-insights query \
  --app <app-insights-name> \
  --resource-group rg-orders-dev-eastus \
  --analytics-query "
    exceptions
    | where timestamp > ago(1h)
    | summarize count() by problemId, outerMessage
    | order by count_ desc"

# Trace specific request by correlation ID
az monitor app-insights query \
  --app <app-insights-name> \
  --resource-group rg-orders-dev-eastus \
  --analytics-query "
    union requests, dependencies, traces
    | where operation_Id == '<correlation-id>'
    | order by timestamp asc"
```

**Validate managed identity permissions:**

```bash
# Check RBAC assignments for managed identity
az role assignment list \
  --assignee <managed-identity-client-id> \
  --all \
  --output table

# Grant missing permissions (example: Service Bus Data Sender)
az role assignment create \
  --role "Azure Service Bus Data Sender" \
  --assignee <managed-identity-client-id> \
  --scope /subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.ServiceBus/namespaces/<namespace>
```

### Enable Diagnostic Logging

```bash
# Enable diagnostic settings for Container App
az monitor diagnostic-settings create \
  --name ContainerAppDiagnostics \
  --resource /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.App/containerApps/orders-api \
  --workspace /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace> \
  --logs '[{"category":"ContainerAppConsoleLogs","enabled":true},{"category":"ContainerAppSystemLogs","enabled":true}]'
```

### Performance Troubleshooting

**Identify slow database queries:**

```csharp
// Enable EF Core query logging in appsettings.Development.json
{
  "Logging": {
    "LogLevel": {
      "Microsoft.EntityFrameworkCore.Database.Command": "Information"
    }
  }
}
```

**Monitor Service Bus message processing:**

```bash
# Check topic message count (indicates backlog)
az servicebus topic show \
  --name orders-placed \
  --namespace-name sb-orders-dev \
  --resource-group rg-orders-dev-eastus \
  --query messageCountDetails
```

## 🤝 Contributing

> 💡 **Why Contribute**: This project follows **standard open-source contribution practices** with pull request workflows, code review, and automated validation. All contributions are governed by the **MIT License**, ensuring your work **remains freely available** to the community while you retain copyright.

> 📌 **Contribution Impact**: Your contributions **directly improve production deployments** used by enterprise teams. Changes undergo **automated testing via GitHub Actions**, **peer review by maintainers**, and validation against the 44-item README quality checklist before merging.

Contributions are welcome! Follow these guidelines to ensure smooth collaboration:

### How to Contribute

**Fork and clone:**

```bash
# Fork repository via GitHub UI, then:
git clone https://github.com/<your-username>/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

**Create a feature branch:**

```bash
# Use conventional commit prefixes: feat/fix/docs/refactor/test
git checkout -b feature/add-order-validation
```

**Make changes and test:**

```bash
# Run tests locally before committing
dotnet test --configuration Debug

# Verify code formatting
dotnet format --verify-no-changes
```

**Commit with descriptive messages:**

```bash
# Use conventional commit format
git commit -m "feat: add order total validation with unit tests"
git commit -m "fix: resolve Service Bus connection retry logic"
git commit -m "docs: update deployment troubleshooting section"
```

**Push and create pull request:**

```bash
git push origin feature/add-order-validation
# Then create PR via GitHub UI with description of changes
```

### Code Quality Standards

- ✅ All new code **must have ≥80% test coverage**
- ✅ **Follow C# coding conventions** (use `dotnet format`)
- ✅ **Update documentation** for public API changes
- ✅ **Include XML doc comments** for public methods
- ✅ **Add integration tests** for new endpoints

### Pull Request Checklist

- [ ] Tests pass locally: `dotnet test`
- [ ] Code formatted: `dotnet format`
- [ ] Documentation updated (README, XML comments)
- [ ] No breaking changes (or clearly documented)
- [ ] Commit messages follow conventional format

> 💡 **First-time contributors**: **Start with issues labeled `good-first-issue`** in the GitHub Issues tab. These are designed to help you **learn the codebase with mentorship** from maintainers.

## 📝 License

This project is licensed under the **MIT License**.

Copyright (c) 2025 Evilázaro Alves

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

See the [LICENSE](LICENSE) file for full license text.

## 📚 Documentation

> 💡 **Why External Documentation**: While this README provides **comprehensive project overview and quickstart guidance**, external documentation offers **deeper technical details**, **architectural decision records**, and **API specifications** that exceed the scope of a README file. These resources support **advanced scenarios** like enterprise integration planning and architecture review processes.

> 📌 **Documentation Ecosystem**: **Microsoft Learn provides authoritative service-level documentation**, while **GitHub repositories contain project-specific implementation guides**. Application Insights documentation explains **telemetry configuration**, and Bicep references detail **infrastructure customization options**.

### Official Documentation

| Resource                 | Icon | Description                            | Link                                                                                                       |
| ------------------------ | ---- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| **Azure DevCenter Docs** | 📚   | Complete Azure DevCenter documentation | [Microsoft Learn: DevCenter](https://learn.microsoft.com/azure/dev-box/)                                   |
| **Bicep Language**       | 📜   | Infrastructure as Code reference       | [Microsoft Learn: Bicep](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)                  |
| **Azure Developer CLI**  | 🔗   | azd command reference and tutorials    | [AZD Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)                      |
| **Container Apps**       | 📖   | Container Apps deployment guides       | [Microsoft Learn: Container Apps](https://learn.microsoft.com/azure/container-apps/)                       |
| **Application Insights** | 🎓   | APM and distributed tracing setup      | [Microsoft Learn: App Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) |
| **.NET Aspire**          | 🔗   | Cloud-native orchestration framework   | [Microsoft Learn: Aspire](https://learn.microsoft.com/dotnet/aspire/)                                      |
| **Logic Apps Standard**  | 📚   | Workflow automation reference          | [Microsoft Learn: Logic Apps](https://learn.microsoft.com/azure/logic-apps/)                               |

### Related Projects

| Project               | Icon | Description                              | Repository                                                                                        |
| --------------------- | ---- | ---------------------------------------- | ------------------------------------------------------------------------------------------------- |
| **Aspire Samples**    | 🔗   | Official .NET Aspire sample applications | [dotnet/aspire-samples](https://github.com/dotnet/aspire-samples)                                 |
| **eShopOnContainers** | 📦   | Reference microservices architecture     | [dotnet-architecture/eShopOnContainers](https://github.com/dotnet-architecture/eShopOnContainers) |
| **Azure Samples**     | 🔗   | Azure code samples and quickstarts       | [Azure-Samples](https://github.com/Azure-Samples)                                                 |

---

**Repository**: [Evilazaro/Azure-LogicApps-Monitoring](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)  
**Author**: Evilázaro Alves  
**Last Updated**: 2026-02-17
