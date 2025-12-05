# Azure Logic Apps Monitoring Solution

A comprehensive, production-ready monitoring infrastructure for Azure Logic Apps Standard using Application Insights, Log Analytics, and Azure Monitor. This solution provides end-to-end observability for Logic Apps workflows with automated deployment via Bicep templates.

## 📋 Table of Contents

- Overview
- Features
- Architecture
- Prerequisites
- Installation & Deployment
- Usage
- Project Structure
- Monitoring Components
- Contributing
- License
- References

## Overview

This project delivers a complete monitoring solution for Azure Logic Apps Standard, designed for enterprise-grade observability and operational excellence. It automates the deployment of monitoring infrastructure including Log Analytics workspaces, Application Insights, diagnostic settings, and storage accounts for log retention.

**Target Audience:**
- Platform Engineers managing Logic Apps infrastructure
- DevOps teams implementing observability solutions
- Organizations requiring comprehensive monitoring for workflow automation
- Teams adopting Azure Logic Apps Standard for business-critical processes

## Features

✅ **Complete Monitoring Stack**
- Application Insights for telemetry and performance monitoring
- Log Analytics workspace with 30-day retention
- Diagnostic settings for all Azure resources
- Dedicated storage accounts for long-term log retention

✅ **Infrastructure as Code**
- Fully automated deployment using Bicep templates
- Environment-based configuration (dev/uat/prod)
- Consistent resource naming and tagging strategy
- Modular architecture for easy customization

✅ **Production-Ready Configuration**
- Managed Identity authentication for secure access
- TLS 1.2+ enforcement across all resources
- Network security with Azure Services bypass
- Lifecycle management policies for cost optimization

✅ **Comprehensive Observability**
- Workflow runtime logs and metrics
- Storage queue monitoring for workflow triggers
- Function App telemetry integration
- Health model integration with Azure Monitor

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Subscription                         │
│  ┌───────────────────────────────────────────────────┐ │
│  │            Resource Group                         │ │
│  │  ┌─────────────────────────────────────────────┐ │ │
│  │  │         Monitoring Stack                    │ │ │
│  │  │  • Log Analytics Workspace                  │ │ │
│  │  │  • Application Insights                     │ │ │
│  │  │  • Logs Storage Account                     │ │ │
│  │  │  • Azure Monitor Health Model               │ │ │
│  │  └─────────────────────────────────────────────┘ │ │
│  │  ┌─────────────────────────────────────────────┐ │ │
│  │  │         Workload Stack                      │ │ │
│  │  │  • Logic App (Standard)                     │ │ │
│  │  │  • App Service Plan (WS1)                   │ │ │
│  │  │  • Function App (APIs)                      │ │ │
│  │  │  • Storage Account (Workflows + Queues)     │ │ │
│  │  │  • Managed Identity                         │ │ │
│  │  └─────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Prerequisites

### Required Tools

- **Azure CLI** >= 2.50.0 ([Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- **Azure Developer CLI (azd)** >= 1.5.0 ([Install](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/install-azd))
- **Visual Studio Code** with extensions:
  - Azure Logic Apps (Standard)
  - Azure Functions
  - Bicep
- **Git** for version control

### Azure Requirements

- Active Azure subscription with Owner or Contributor permissions
- Resource Provider registrations:
  - `Microsoft.Logic`
  - `Microsoft.Web`
  - `Microsoft.Storage`
  - `Microsoft.Insights`
  - `Microsoft.OperationalInsights`
  - `Microsoft.Management`

### Local Development (Optional)

- **Azure Functions Core Tools** v4.x ([Install](https://learn.microsoft.com/en-us/azure/azure-functions/functions-run-local))
- **Azurite** for local storage emulation ([Install](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azurite))

## Installation & Deployment

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

### 2. Configure Environment

Create environment-specific configuration files in the .azure directory:

```bash
# For development environment
mkdir -p .azure/dev
cat > .azure/dev/.env << EOF
AZURE_ENV_NAME=dev
AZURE_LOCATION=eastus
EOF
```

### 3. Deploy Infrastructure

#### Option A: Using Azure Developer CLI (Recommended)

```bash
# Login to Azure
azd auth login

# Initialize the environment
azd env new dev

# Set environment variables
azd env set AZURE_LOCATION eastus
azd env set AZURE_ENV_NAME dev

# Deploy all resources
azd up
```

#### Option B: Using Azure CLI with Bicep

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"

# Deploy to a specific environment (dev/uat/prod)
az deployment sub create \
  --name "tax-docs-monitoring-$(date +%Y%m%d-%H%M%S)" \
  --location eastus \
  --template-file ./infra/main.bicep \
  --parameters ./infra/main.parameters.json \
  --parameters envName=dev location=eastus
```

### 4. Retrieve Deployment Outputs

After successful deployment, retrieve important resource information:

```bash
# Get deployment outputs
az deployment sub show \
  --name "your-deployment-name" \
  --query properties.outputs
```

Key outputs include:
- `LOGIC_APP_NAME`: Name of the deployed Logic App
- `AZURE_APPLICATION_INSIGHTS_NAME`: Application Insights instance name
- `AZURE_LOG_ANALYTICS_WORKSPACE_NAME`: Log Analytics workspace name

## Usage

### Accessing Monitoring Data

#### 1. Application Insights

Navigate to the Azure Portal and access your Application Insights instance:

```bash
# Open Application Insights in the browser
az monitor app-insights component show \
  --app <AZURE_APPLICATION_INSIGHTS_NAME> \
  --resource-group <RESOURCE_GROUP_NAME> \
  --query "appId" -o tsv | \
  xargs -I {} open "https://portal.azure.com/#blade/AppInsightsExtension/MetricsExplorerBlade/ComponentId/{}"
```

**Key Metrics to Monitor:**
- Workflow execution duration
- Success/failure rates
- Request throughput
- Dependency calls

#### 2. Log Analytics Queries

Access Log Analytics workspace to query logs:

```kusto
// Query workflow execution logs
WorkflowRuntime
| where TimeGenerated > ago(1h)
| where OperationName contains "workflow"
| project TimeGenerated, WorkflowName, Status, DurationMs
| order by TimeGenerated desc

// Query storage queue operations
StorageQueueLogs
| where TimeGenerated > ago(1h)
| where QueueName == "taxprocessing"
| summarize Count=count() by OperationName, bin(TimeGenerated, 5m)
```

#### 3. Monitoring Workflows

The deployed Logic App (tax-docs/tax-processing/workflow.json) is configured for monitoring. To view runtime data:

1. Navigate to the Logic App in Azure Portal
2. Select **Monitoring** → **Logs**
3. Use the pre-configured queries or create custom KQL queries

### Local Development

To run and test Logic Apps locally:

```bash
cd tax-docs

# Start Azurite storage emulator
azurite --silent --location ./__azurite__ --debug ./__debug__

# Start the Logic App runtime
func start
```

The Logic App designer will be available at: `http://localhost:7071/`

### Deploying Workflow Changes

After modifying workflows in the tax-docs directory:

```bash
# Deploy using VS Code Azure Logic Apps extension
# Right-click on the workflow folder → "Deploy to Logic App..."

# Or use Azure CLI
cd tax-docs
func azure functionapp publish <LOGIC_APP_NAME>
```

## Project Structure

```
.
├── infra/                          # Infrastructure as Code
│   ├── main.bicep                  # Main deployment template
│   └── main.parameters.json        # Deployment parameters
│
├── src/
│   ├── monitoring/                 # Monitoring infrastructure
│   │   ├── main.bicep              # Monitoring orchestration
│   │   ├── log-analytics-workspace.bicep
│   │   ├── app-insights.bicep
│   │   └── azure-monitor-health-model.bicep
│   │
│   └── workload/                   # Application workload
│       ├── main.bicep              # Workload orchestration
│       ├── logic-app.bicep         # Logic App Standard
│       ├── azure-function.bicep    # Function App for APIs
│       └── messaging/
│           └── main.bicep          # Storage queues
│
├── tax-docs/                       # Logic App project
│   ├── host.json                   # Runtime configuration
│   ├── connections.json            # API connections
│   └── tax-processing/             # Workflow definitions
│       └── workflow.json
│
├── .azure/                         # Environment configs
│   ├── dev/
│   │   └── .env
│   ├── uat/
│   └── prod/
│
├── .vscode/                        # VS Code configuration
│   ├── settings.json
│   ├── launch.json
│   └── tasks.json
│
├── azure.yaml                      # Azure Developer CLI config
└── README.md
```

## Monitoring Components

### Log Analytics Workspace

Configured in log-analytics-workspace.bicep:
- **Retention**: 30 days
- **Pricing Tier**: Pay-as-you-go (PerGB2018)
- **Features**: Immediate purge on retention expiration
- **Storage**: Dedicated storage account with lifecycle policies

### Application Insights

Configured in app-insights.bicep:
- **Type**: Workspace-based
- **Sampling**: Enabled (excludes Request telemetry)
- **Integration**: Connected to Log Analytics workspace
- **Access**: Public network access for ingestion and query

### Storage Accounts

Configured in main.bicep:
- **Workflow Storage**: Hosts Logic App runtime data and queues
- **Logs Storage**: Retains diagnostic logs with 30-day lifecycle policy
- **Security**: TLS 1.2+, Azure Services bypass, managed identity access

### Diagnostic Settings

All resources configured with:
- All logs enabled (`categoryGroup: allLogs`)
- All metrics enabled (`categoryGroup: allMetrics`)
- Dual destination: Log Analytics + Storage Account
- Dedicated table format for Log Analytics

## Contributing

We welcome contributions! Please see CONTRIBUTING.md for detailed guidelines.

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes and test thoroughly
4. Commit with clear messages: `git commit -m "Add: description of changes"`
5. Push to your fork: `git push origin feature/your-feature-name`
6. Open a Pull Request

### Development Guidelines

- Follow Bicep best practices and naming conventions
- Add parameter descriptions and validation
- Include output variables for all deployed resources
- Update documentation for new features
- Test deployments in dev environment before submitting PR

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

## References

### Official Documentation

- [Azure Logic Apps Standard](https://learn.microsoft.com/en-us/azure/logic-apps/single-tenant-overview-compare)
- [Application Insights](https://learn.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)
- [Log Analytics Workspaces](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/log-analytics-workspace-overview)
- [Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)

### Related Resources

- [Logic Apps Monitoring Best Practices](https://learn.microsoft.com/en-us/azure/logic-apps/monitor-logic-apps)
- [KQL Query Language](https://learn.microsoft.com/en-us/azure/data-explorer/kusto/query/)
- [Azure Monitor Best Practices](https://learn.microsoft.com/en-us/azure/azure-monitor/best-practices)

### Community

- Report issues: [GitHub Issues](https://github.com/yourusername/Azure-LogicApps-Monitoring/issues)
- Request features: [GitHub Discussions](https://github.com/yourusername/Azure-LogicApps-Monitoring/discussions)
- Security concerns: See SECURITY.md

---

**Maintained by:** Platform Engineering Team  
**Repository:** [Azure-LogicApps-Monitoring](https://github.com/yourusername/Azure-LogicApps-Monitoring)  
**Version:** 1.0.0