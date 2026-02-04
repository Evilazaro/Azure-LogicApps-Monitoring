# Azure Logic Apps Monitoring

![Build Status](https://img.shields.io/github/actions/workflow/status/Evilazaro/Azure-LogicApps-Monitoring/build.yml?branch=main)
![License](https://img.shields.io/github/license/Evilazaro/Azure-LogicApps-Monitoring)
![.NET](https://img.shields.io/badge/.NET-10.0-512BD4)
![Azure](https://img.shields.io/badge/Azure-0078D4?logo=microsoft-azure)

A comprehensive monitoring solution for Azure Logic Apps Standard built with .NET Aspire orchestration. This solution provides an enterprise-grade eShop reference implementation featuring distributed order management, Azure integration, and production-ready observability patterns.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring

# Authenticate with Azure
azd auth login

# Create a new environment
azd env new <environment-name>

# Deploy infrastructure and applications
azd up
```

> ⚠️ **Prerequisites**: Ensure Azure CLI (≥2.60.0), Azure Developer CLI (azd ≥1.11.0), .NET SDK 10.0, and Docker are installed before running these commands.

## 📦 Installation

### Prerequisites

Verify you have the following tools installed:

- **Azure CLI**: Version 2.60.0 or higher
- **Azure Developer CLI (azd)**: Version 1.11.0 or higher
- **.NET SDK**: Version 10.0.100 (specified in [`global.json`](global.json))
- **Docker Desktop**: Required for local container development
- **Visual Studio 2022** or **VS Code**: Recommended for development

### Local Development Setup

1. **Clone the repository**:

```bash
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

2. **Restore dependencies**:

```bash
dotnet restore app.sln
```

3. **Run the application locally**:

```bash
dotnet run --project app.AppHost/app.AppHost.csproj
```

The .NET Aspire dashboard will launch automatically at `http://localhost:15888`.

> 💡 **Tip**: Use `azd up` for automated infrastructure provisioning and deployment to Azure. This single command handles authentication, resource creation, and application deployment.

### Azure Deployment

Deploy the complete solution to Azure Container Apps:

```bash
# Authenticate with Azure
azd auth login

# Initialize a new environment
azd env new production

# Provision infrastructure and deploy services
azd up
```

The deployment process will:

- Create all required Azure resources (Container Apps, SQL Database, Service Bus, Application Insights)
- Configure managed identity authentication
- Deploy the Orders API and Web App containers
- Set up monitoring and logging

## 💻 Usage

### Running Locally with .NET Aspire

.NET Aspire provides orchestration for the distributed application:

```csharp
// app.AppHost/AppHost.cs
var builder = DistributedApplication.CreateBuilder(args);

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithExternalHttpEndpoints();

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
    .WithExternalHttpEndpoints()
    .WithReference(ordersApi)
    .WaitFor(ordersApi);

builder.Build().Run();
```

Access the application:

- **Aspire Dashboard**: `http://localhost:15888` (observability and service management)
- **Web App**: Check dashboard for dynamically assigned port
- **Orders API**: Check dashboard for dynamically assigned port

### Managing Orders via API

Interact with the Orders API:

```bash
# Create a new order
curl -X POST https://your-api-url/api/orders \
  -H "Content-Type: application/json" \
  -d '{"customerId": "12345", "items": [{"productId": "prod-1", "quantity": 2}]}'

# Get order by ID
curl https://your-api-url/api/orders/{orderId}

# List all orders
curl https://your-api-url/api/orders
```

### Infrastructure Management

Use Azure Developer CLI for infrastructure operations:

```bash
# View environment variables
azd env get-values

# Update infrastructure
azd provision

# Deploy code changes only
azd deploy

# View deployed resources
azd show

# Clean up all resources
azd down
```

## 🏗️ Architecture

The solution follows a microservices architecture orchestrated by .NET Aspire:

**Core Components**:

- **eShop.Orders.API**: RESTful API for order management with Entity Framework Core and Azure SQL
- **eShop.Web.App**: Blazor Server frontend with FluentUI components
- **app.AppHost**: .NET Aspire orchestration host for local development and Azure deployment
- **app.ServiceDefaults**: Shared service configuration (observability, health checks, resilience)

**Azure Resources** (deployed via Bicep IaC):

- **Azure Container Apps**: Scalable container hosting for API and Web App
- **Azure SQL Database**: Relational data storage with managed identity authentication
- **Azure Service Bus**: Asynchronous messaging between services
- **Application Insights**: Distributed tracing, metrics, and logging
- **Log Analytics Workspace**: Centralized log aggregation
- **Azure Key Vault**: Secrets management (optional, configured via hooks)

**Infrastructure as Code**:

The [`infra/`](infra/) directory contains Bicep templates organized by concern:

- [`main.bicep`](infra/main.bicep): Entry point orchestrating all resources
- [`shared/`](infra/shared/): Cross-cutting resources (identity, monitoring, networking)
- [`workload/`](infra/workload/): Application-specific resources (Logic Apps, messaging)

## 🔧 Configuration

### Environment Variables

Configure application behavior via environment variables or [`appsettings.json`](src/eShop.Orders.API/appsettings.json):

```json
{
  "ConnectionStrings": {
    "OrderDb": "Server=tcp:your-server.database.windows.net,1433;Database=orders;Authentication=Active Directory Default;"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  }
}
```

> ℹ️ **Important**: Connection strings use Azure AD managed identity authentication. No passwords or secrets are stored in configuration files.

### Azure Developer CLI Hooks

Lifecycle hooks in [`hooks/`](hooks/) automate deployment tasks:

- **preprovision**: Validates development workstation prerequisites
- **postprovision**: Configures federated credentials and SQL managed identity
- **deploy-workflow**: Deploys Logic Apps workflows
- **postinfradelete**: Cleans up secrets and temporary resources

### Deployment Parameters

Override default parameters in [`infra/main.parameters.json`](infra/main.parameters.json):

```json
{
  "solutionName": "orders",
  "envName": "production",
  "location": "eastus",
  "deployHealthModel": true
}
```

## 🧪 Testing

Run unit and integration tests:

```bash
# Run all tests
dotnet test app.sln

# Run specific test project
dotnet test src/tests/eShop.Orders.API.Tests

# Run with code coverage
dotnet test app.sln --collect:"XPlat Code Coverage"
```

Test projects included:

- [`eShop.Orders.API.Tests`](src/tests/eShop.Orders.API.Tests/): API endpoint and business logic tests
- [`eShop.Web.App.Tests`](src/tests/eShop.Web.App.Tests/): Blazor component tests
- [`app.ServiceDefaults.Tests`](src/tests/app.ServiceDefaults.Tests/): Shared service configuration tests
- [`app.AppHost.Tests`](src/tests/app.AppHost.Tests/): Orchestration and deployment tests

## 🐛 Troubleshooting

### Database Connection Issues

**Problem**: `InvalidOperationException: Connection string 'OrderDb' is not configured`

**Solution**: Ensure the database resource is referenced in [`AppHost.cs`](app.AppHost/AppHost.cs) and Azure AD authentication is configured:

```csharp
var sql = builder.AddSqlServer("sql")
    .PublishAsAzureSqlDatabase()
    .AddDatabase("OrderDb");

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(sql);
```

### Azure Authentication Failures

**Problem**: `Azure.Identity.AuthenticationFailedException` during deployment

**Solution**: Run `azd auth login` and ensure your account has Contributor permissions on the target subscription.

### Aspire Dashboard Not Loading

**Problem**: Dashboard at `http://localhost:15888` returns connection refused

**Solution**: Check that no other process is using port 15888 and verify the AppHost is running:

```bash
# Check running processes
dotnet ps

# Restart AppHost with explicit port
dotnet run --project app.AppHost/app.AppHost.csproj
```

## 🤝 Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure your code:

- Follows existing code style and conventions
- Includes appropriate unit tests
- Updates documentation as needed
- Passes all CI/CD checks

## 📝 License

This project is licensed under the MIT License. See the [`LICENSE`](LICENSE) file for details.

Copyright (c) 2025 Evilázaro Alves
