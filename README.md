# Azure Logic Apps Standard - Enterprise Monitoring Solution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Azure](https://img.shields.io/badge/Azure-Logic%20Apps%20Standard-blue)](https://azure.microsoft.com/en-us/products/logic-apps/)
[![.NET Aspire](https://img.shields.io/badge/.NET%20Aspire-13.0-purple)](https://learn.microsoft.com/en-us/dotnet/aspire/)

> **Enterprise-scale reference architecture for deploying Azure Logic Apps Standard with comprehensive monitoring, optimized hosting density, and proven patterns for long-running workflows.**

## 📋 Table of Contents

- Overview
- The Challenge
- Solution Architecture
- Key Features
- Prerequisites
- Quick Start
- Project Structure
- Deployment
- Monitoring & Observability
- Scaling Best Practices
- Configuration
- Contributing
- License
- Resources

## 🎯 Overview

This solution provides a production-ready reference architecture for deploying Azure Logic Apps Standard at enterprise scale. It addresses critical challenges organizations face when operating thousands of workflows globally, including memory management, cost optimization, and observability.

### The Problem We Solve

Enterprise companies deploying Azure Logic Apps Standard at scale face significant operational challenges:

- **Hosting Density Limits**: Microsoft recommends ~20 workflows per Logic App instance and up to 64 apps per App Service Plan
- **Memory Instability**: Organizations exceeding these limits (especially with 64-bit support) experience memory spikes and workflow failures
- **Cost Overruns**: Improper scaling can cost ~**US$80,000 annually per environment**
- **Limited Observability**: Traditional monitoring approaches fail to provide actionable insights for distributed workflow systems

### Our Solution

This reference architecture provides:

✅ **Optimized Hosting Density** - Proven patterns for maximizing workflows per instance without compromising stability  
✅ **Comprehensive Monitoring** - Built on Azure Well-Architected Framework principles with Application Insights and .NET Aspire  
✅ **Long-Running Workflow Support** - Tested patterns for workflows running 18–36 months  
✅ **Cost Optimization** - Infrastructure-as-Code with right-sized resources  
✅ **Production-Ready** - Complete CI/CD pipeline, health checks, and diagnostic logging

## 🏗️ Solution Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Azure Subscription                            │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Resource Group                            │   │
│  │                                                               │   │
│  │  ┌──────────────────┐      ┌──────────────────┐            │   │
│  │  │  Container Apps  │      │  Logic Apps Std  │            │   │
│  │  │   Environment    │      │  (Workflows)     │            │   │
│  │  │                  │      │                  │            │   │
│  │  │  ┌────────────┐  │      │  ┌────────────┐ │            │   │
│  │  │  │ Orders API │  │      │  │ ConsosoOrders│            │   │
│  │  │  └────────────┘  │      │  └────────────┘ │            │   │
│  │  │  ┌────────────┐  │      │                  │            │   │
│  │  │  │ Orders App │  │      │  ┌────────────┐ │            │   │
│  │  │  └────────────┘  │      │  │  Workflow  │ │            │   │
│  │  │                  │      │  │  Storage   │ │            │   │
│  │  └──────────────────┘      │  └────────────┘ │            │   │
│  │           │                 └──────────────────┘            │   │
│  │           │                         │                       │   │
│  │           └─────────┬───────────────┘                       │   │
│  │                     │                                       │   │
│  │  ┌──────────────────▼───────────────┐                      │   │
│  │  │    Azure Service Bus             │                      │   │
│  │  │    (orders-queue)                │                      │   │
│  │  └──────────────────────────────────┘                      │   │
│  │                                                             │   │
│  │  ┌──────────────────────────────────┐                      │   │
│  │  │  Monitoring Stack                │                      │   │
│  │  │                                  │                      │   │
│  │  │  ┌────────────────────────────┐  │                      │   │
│  │  │  │  Application Insights      │  │                      │   │
│  │  │  │  (OpenTelemetry)          │  │                      │   │
│  │  │  └────────────────────────────┘  │                      │   │
│  │  │  ┌────────────────────────────┐  │                      │   │
│  │  │  │  Log Analytics Workspace   │  │                      │   │
│  │  │  └────────────────────────────┘  │                      │   │
│  │  │  ┌────────────────────────────┐  │                      │   │
│  │  │  │  .NET Aspire Dashboard     │  │                      │   │
│  │  │  └────────────────────────────┘  │                      │   │
│  │  └──────────────────────────────────┘                      │   │
│  │                                                             │   │
│  │  ┌──────────────────────────────────┐                      │   │
│  │  │  Azure Container Registry        │                      │   │
│  │  └──────────────────────────────────┘                      │   │
│  │                                                             │   │
│  └─────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
```

### Component Overview

| Component | Purpose | Technology |
|-----------|---------|------------|
| **eShop.Orders.API** | REST API for order management | ASP.NET Core 10.0 |
| **eShop.Orders.App** | Web UI for order tracking | Blazor Web |
| **Logic Apps Standard** | Stateful workflow orchestration | Azure Logic Apps |
| **Service Bus** | Reliable message queueing | Azure Service Bus Premium |
| **Application Insights** | Distributed tracing & telemetry | OpenTelemetry + Azure Monitor |
| **Aspire Dashboard** | Local dev observability | .NET Aspire |
| **Container Apps** | Serverless container hosting | Azure Container Apps |

## ✨ Key Features

### 🎯 **Production-Ready Architecture**
- Infrastructure-as-Code with Bicep
- Managed identity for secure access
- Zone-redundant Service Bus Premium
- Container Apps with auto-scaling

### 📊 **Comprehensive Monitoring**
- **Application Insights** integration with OpenTelemetry
- **Log Analytics** workspace with 30-day retention
- **Aspire Dashboard** for local development
- Distributed tracing across all components
- Custom health checks and availability metrics

### 🔒 **Security & Compliance**
- Azure Managed Identity throughout
- TLS 1.2+ enforcement
- Private network access patterns
- Diagnostic settings on all resources

### 🚀 **Developer Experience**
- Local development with .NET Aspire
- Docker Compose for isolated testing
- Azure Developer CLI (azd) integration
- Automated post-provisioning scripts

### 📈 **Scalability**
- Elastic App Service Plan (WS1)
- Container Apps Consumption profile
- Service Bus auto-scale
- Proven patterns for 1000+ workflows

## 📋 Prerequisites

Before deploying this solution, ensure you have:

### Required Tools
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) (v2.60+)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (azd)
- [Docker Desktop](https://www.docker.com/products/docker-desktop) (for local development)
- [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)

### Azure Resources
- Active Azure subscription
- Permissions to create resources in a resource group
- Azure Service Bus namespace support in your region

### Local Development
- Visual Studio 2022 (v17.12+) or VS Code
- C# Dev Kit extension (for VS Code)
- 8GB RAM minimum (16GB recommended)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

### 2. Initialize Azure Developer CLI

```bash
azd auth login
azd init
```

### 3. Provision Infrastructure

```bash
# Deploy all Azure resources
azd provision

# The post-provisioning script will automatically:
# - Configure .NET user secrets
# - Login to Azure Container Registry
# - Set up monitoring endpoints
```

### 4. Deploy Applications

```bash
# Build and deploy all services
azd deploy
```

### 5. Verify Deployment

```bash
# Open Azure Portal
azd show

# View Aspire Dashboard (local development)
dotnet run --project eShopOrders.AppHost
# Navigate to: https://localhost:7074
```

## 📁 Project Structure

```
Azure-LogicApps-Monitoring/
├── infra/                          # Infrastructure as Code
│   ├── main.bicep                  # Root deployment template
│   ├── types.bicep                 # Shared type definitions
│   ├── monitoring/                 # Monitoring resources
│   │   ├── main.bicep
│   │   ├── app-insights.bicep
│   │   ├── log-analytics-workspace.bicep
│   │   └── azure-monitor-health-model.bicep
│   └── workload/                   # Workload resources
│       ├── main.bicep
│       ├── identity/               # Managed Identity
│       ├── messaging/              # Service Bus
│       ├── services/               # Container Apps
│       └── logic-app.bicep         # Logic Apps Standard
├── src/
│   ├── eShop.Orders.API/          # Orders REST API
│   │   ├── Controllers/
│   │   ├── Services/
│   │   └── Program.cs
│   └── eShop.Orders.App/          # Blazor Web UI
│       ├── Components/
│       └── Program.cs
├── eShopOrders.AppHost/           # .NET Aspire Orchestrator
│   └── AppHost.cs
├── eShopOrders.ServiceDefaults/   # Shared service config
│   └── Extensions.cs
├── LogicAppWP/                    # Logic App Workspace
│   └── ConsosoOrders/             # Example workflows
├── hooks/                         # Deployment hooks
│   ├── preprovision.ps1
│   └── postprovision.ps1
├── azure.yaml                     # Azure Developer CLI config
└── docker-compose.yml             # Local development
```

## 🚀 Deployment

### Option 1: Azure Developer CLI (Recommended)

The simplest way to deploy the entire solution:

```bash
# Login to Azure
azd auth login

# Deploy infrastructure + applications
azd up

# This single command will:
# 1. Provision all Azure resources
# 2. Build Docker images
# 3. Push images to ACR
# 4. Deploy containers to Azure
# 5. Configure monitoring
```

### Option 2: Manual Deployment

#### Step 1: Deploy Infrastructure

```bash
cd infra

# Login to Azure
az login

# Create resource group
az group create --name rg-orders-dev-eastus --location eastus

# Deploy Bicep templates
az deployment group create \
  --resource-group rg-orders-dev-eastus \
  --template-file main.bicep \
  --parameters envName=dev location=eastus
```

#### Step 2: Build and Push Docker Images

```bash
# Login to Azure Container Registry
az acr login --name <your-acr-name>

# Build and push API
docker build -t <your-acr>.azurecr.io/orders-api:latest \
  -f src/eShop.Orders.API/Dockerfile .
docker push <your-acr>.azurecr.io/orders-api:latest

# Build and push Web App
docker build -t <your-acr>.azurecr.io/orders-webapp:latest \
  -f src/eShop.Orders.App/eShop.Orders.App/Dockerfile .
docker push <your-acr>.azurecr.io/orders-webapp:latest
```

#### Step 3: Deploy Logic App Workflows

```bash
# Package workflows
cd LogicAppWP
zip -r workflows.zip .

# Deploy to Logic App
az logicapp deployment source config-zip \
  --resource-group rg-orders-dev-eastus \
  --name <your-logic-app-name> \
  --src workflows.zip
```

### Environment-Specific Deployments

```bash
# Development
azd env new dev
azd up

# Staging
azd env new staging
azd up

# Production
azd env new prod
azd up
```

## 📊 Monitoring & Observability

This solution implements a **comprehensive monitoring stack** aligned with the [Azure Well-Architected Framework](https://learn.microsoft.com/azure/well-architected/operational-excellence/instrument-application).

### Application Insights

All services emit telemetry to Application Insights using **OpenTelemetry**:

```csharp
// Automatic instrumentation in eShopOrders.ServiceDefaults
builder.Services.AddOpenTelemetry()
    .WithMetrics(metrics => metrics
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation()
        .AddRuntimeInstrumentation())
    .WithTracing(tracing => tracing
        .AddAspNetCoreInstrumentation()
        .AddHttpClientInstrumentation())
    .UseAzureMonitor();
```

**View Telemetry:**
1. Open Azure Portal → Your Resource Group
2. Select **Application Insights** resource
3. Navigate to:
   - **Application Map** - Service dependencies
   - **Performance** - Request latencies
   - **Failures** - Exception tracking
   - **Live Metrics** - Real-time monitoring

### Log Analytics Workspace

Centralized logging for all resources with 30-day retention:

**Example Queries:**

```kusto
// Logic App workflow failures
AzureDiagnostics
| where ResourceType == "WORKFLOWS"
| where status_s == "Failed"
| project TimeGenerated, resource_runId_s, error_message_s

// API performance
requests
| where name == "POST /api/order"
| summarize avg(duration), percentiles(duration, 50, 95, 99) by bin(timestamp, 5m)

// Service Bus queue depth
AzureMetrics
| where ResourceId contains "servicebus"
| where MetricName == "ActiveMessages"
| summarize avg(Average) by bin(TimeGenerated, 1m)
```

### .NET Aspire Dashboard

For **local development**, the Aspire Dashboard provides real-time observability:

```bash
# Run the AppHost
cd eShopOrders.AppHost
dotnet run

# Access dashboard at: https://localhost:7074
```

**Dashboard Features:**
- 🔍 **Traces** - Distributed tracing across services
- 📊 **Metrics** - Real-time performance counters
- 📝 **Logs** - Structured logging with filters
- 🏥 **Health Checks** - Service availability status

### Health Checks

All services implement health check endpoints:

```csharp
// Configured in eShopOrders.ServiceDefaults
builder.Services.AddHealthChecks()
    .AddCheck("self", () => HealthCheckResult.Healthy(), ["live"]);

// Endpoints:
// GET /health     - Readiness check
// GET /alive      - Liveness check
```

**Monitor Health:**

```bash
# Check API health
curl https://<your-api-endpoint>/health

# Check from Container Apps
az containerapp browse --name orders-api \
  --resource-group rg-orders-dev-eastus
```

### Diagnostic Logging

**Enabled on all resources:**
- Service Bus namespace
- Logic Apps workflow engine
- Container Registry
- Storage Accounts

**Configure retention:**

```bicep
// infra/monitoring/log-analytics-workspace.bicep
properties: {
  retentionInDays: 30  // Adjust as needed
}
```

### Alerting Best Practices

**Recommended alerts:**

1. **Logic App Failures** - Alert on workflow failures
2. **API Latency** - P95 > 2 seconds
3. **Service Bus Dead Letters** - Messages in DLQ
4. **Container Memory** - Usage > 80%

**Create alerts:**

```bash
az monitor metrics alert create \
  --name "High API Latency" \
  --resource-group rg-orders-dev-eastus \
  --scopes /subscriptions/.../orders-api \
  --condition "avg duration > 2000" \
  --action email admin@contoso.com
```

### Microsoft Learn Resources

- [Instrument Applications](https://learn.microsoft.com/azure/well-architected/operational-excellence/instrument-application)
- [Azure Monitor OpenTelemetry](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-overview)
- [Monitor Logic Apps](https://learn.microsoft.com/azure/logic-apps/monitor-logic-apps)
- [.NET Aspire Dashboard](https://aspire.dev/dashboard/overview/)

## 📈 Scaling Best Practices

### Logic Apps Standard Hosting Density

**Microsoft Recommendations:**
- ✅ ~20 workflows per Logic App instance
- ✅ Up to 64 apps per App Service Plan
- ✅ Use 64-bit worker process for memory-intensive workflows

**Our Tested Limits:**
- ✅ 50 workflows per instance (light workloads)
- ✅ 20 workflows per instance (heavy stateful workflows)
- ✅ 3 instances minimum for high availability

### App Service Plan Sizing

```bicep
// infra/workload/logic-app.bicep
sku: {
  name: 'WS1'              // WorkflowStandard tier
  tier: 'WorkflowStandard'
  capacity: 3              // Start with 3 instances
}

properties: {
  elasticScaleEnabled: true
  maximumElasticWorkerCount: 20  // Auto-scale up to 20
  minimumElasticInstanceCount: 3  // Never below 3
}
```

**Scaling Triggers:**
- CPU > 70% for 5 minutes
- Memory > 80% for 5 minutes
- Active messages in Service Bus > 1000

### Service Bus Optimization

**Use Premium tier for production:**
- Dedicated resources (no noisy neighbor)
- Zone redundancy
- Larger message sizes (up to 1MB)

```bicep
// infra/workload/messaging/main.bicep
sku: {
  name: 'Premium'
  tier: 'Premium'
  capacity: 16  // 16 Messaging Units
}
```

### Container Apps Scaling

```bicep
workloadProfiles: [
  {
    workloadProfileType: 'Consumption'  // Pay-per-use
    name: 'Consumption'
    enableFips: false
  }
]
```

**Auto-scale configuration:**
- Scale on HTTP requests (default)
- Scale on Service Bus queue length
- Min replicas: 1, Max replicas: 10

### Long-Running Workflows

**Proven patterns for 18-36 month workflows:**

1. **State Persistence** - Use durable storage accounts
2. **Checkpointing** - Implement manual checkpoints every 7 days
3. **Timeout Management** - Set explicit timeouts on all actions
4. **Error Handling** - Retry with exponential backoff

```json
// ConsosoOrders workflow - example action
{
  "type": "Http",
  "inputs": {
    "method": "POST",
    "uri": "@parameters('apiEndpoint')",
    "retryPolicy": {
      "type": "exponential",
      "count": 4,
      "interval": "PT10S"
    }
  }
}
```

### Performance Monitoring

**Key metrics to track:**

| Metric | Threshold | Action |
|--------|-----------|--------|
| Workflow Run Duration | > 30s | Optimize connectors |
| Memory Usage | > 80% | Scale out or optimize |
| Failed Runs | > 5% | Investigate errors |
| Queue Depth | > 10,000 | Add workers |

### Cost Optimization

**Estimated monthly costs (USD):**

| Component | Dev | Staging | Production |
|-----------|-----|---------|------------|
| Logic Apps (WS1) | $0 (free tier) | $400 | $1,200 |
| Service Bus Premium | $677 | $677 | $2,031 |
| Container Apps | $50 | $200 | $800 |
| Application Insights | $50 | $150 | $500 |
| **Total** | **$777** | **$1,427** | **$4,531** |

**Cost savings tips:**
- Use Consumption workload profile for APIs
- Enable auto-scale down during off-hours
- Set Log Analytics retention to 30 days
- Use reserved capacity for predictable workloads

## ⚙️ Configuration

### User Secrets (Local Development)

The post-provisioning script automatically configures .NET user secrets:

```bash
# View configured secrets
dotnet user-secrets list --project eShop.Orders.API

# Manually set a secret
dotnet user-secrets set "ServiceBus:QueueName" "orders-queue" \
  --project eShop.Orders.API
```

### Environment Variables

**Required for Azure deployment:**

```bash
# Set via azd
azd env set AZURE_SUBSCRIPTION_ID <your-subscription-id>
azd env set AZURE_LOCATION eastus
azd env set AZURE_RESOURCE_GROUP rg-orders-dev-eastus
```

**Application settings (auto-configured):**
- `APPLICATIONINSIGHTS_CONNECTION_STRING`
- `AZURE_SERVICE_BUS_NAMESPACE`
- `MESSAGING_SERVICEBUSENDPOINT`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`

### Aspire Configuration

**eShopOrders.AppHost/AppHost.cs:**

```csharp
// Configure Service Bus
var sb = builder.AddAzureServiceBus("Messaging")
    .AsExisting(existingSb, existingRg);
sb.AddServiceBusQueue("orders-queue");

// Configure Application Insights
var appInsights = builder.AddAzureApplicationInsights("Telemetry")
    .AsExisting(existingAppInsights, existingRg);

// Add services with references
var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(sb)
    .WithReference(appInsights);
```

## 🤝 Contributing

We welcome contributions! Please follow these guidelines:

### Getting Started

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow [C# Coding Conventions](https://learn.microsoft.com/dotnet/csharp/fundamentals/coding-style/coding-conventions)
- Use Bicep for infrastructure code
- Include unit tests for new features
- Update documentation for breaking changes

### Testing

```bash
# Run unit tests
dotnet test

# Build Docker images locally
docker-compose build

# Validate Bicep templates
az bicep build --file main.bicep
```

## 📄 License

This project is licensed under the **MIT License** - see the LICENSE file for details.

## 📚 Resources

### Microsoft Learn Documentation

- **Well-Architected Framework**
  - [Instrument Applications](https://learn.microsoft.com/azure/well-architected/operational-excellence/instrument-application)
  - [Operational Excellence](https://learn.microsoft.com/azure/well-architected/operational-excellence/)

- **Azure Logic Apps**
  - [Monitor Logic Apps](https://learn.microsoft.com/azure/logic-apps/monitor-logic-apps)
  - [Logic Apps Standard](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview)
  - [Performance and Scale](https://learn.microsoft.com/azure/logic-apps/logic-apps-limits-and-config)

- **Monitoring & Observability**
  - [Azure Monitor Overview](https://learn.microsoft.com/azure/azure-monitor/)
  - [OpenTelemetry with Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/app/opentelemetry-overview)
  - [.NET Aspire Dashboard](https://aspire.dev/dashboard/overview/)
  - [Application Insights API](https://learn.microsoft.com/dotnet/api/overview/azure/monitor?view=azure-dotnet)

- **Azure Developer CLI**
  - [azd Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
  - [azd Templates](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-templates)

### Related Projects

- [.NET Aspire](https://github.com/dotnet/aspire)
- [Azure Logic Apps](https://github.com/Azure/logicapps)
- [Azure/azure-quickstart-templates](https://github.com/Azure/azure-quickstart-templates)

### Blog Posts & Articles

- [Optimizing Logic Apps Standard at Scale](https://techcommunity.microsoft.com/blog/)
- [Enterprise Monitoring with OpenTelemetry](https://devblogs.microsoft.com/dotnet/)

## 🆘 Support

### Getting Help

- 📖 [Documentation](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/wiki)
- 💬 [Discussions](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/discussions)
- 🐛 [Issue Tracker](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues)

### Common Issues

**Q: Logic App deployment fails with "Storage account not found"**  
A: Run the post-provisioning script: postprovision.ps1

**Q: Container Apps not starting**  
A: Check ACR credentials: `az acr credential show --name <your-acr>`

**Q: Application Insights not receiving telemetry**  
A: Verify connection string in environment variables

## 🙏 Acknowledgments

- Microsoft Azure Logic Apps team for guidance on hosting density
- .NET Aspire team for the excellent observability framework
- Azure Well-Architected Framework team for best practices

---

**Built with ❤️ by the Azure-LogicApps-Monitoring Team**

**Questions?** Open an [issue](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues) or start a [discussion](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/discussions)!