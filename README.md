# Azure Logic Apps Monitoring Solution

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.MD)
[![Azure](https://img.shields.io/badge/Azure-Logic%20Apps-0089D6?logo=microsoft-azure)](https://azure.microsoft.com/services/logic-apps/)
[![Bicep](https://img.shields.io/badge/IaC-Bicep-00B2FF)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

A comprehensive, production-ready monitoring solution for Azure Logic Apps Standard, featuring Application Insights integration, Log Analytics workspace, Azure Monitor health models, and complete observability infrastructure deployed via Infrastructure as Code (IaC) using Bicep.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation & Deployment](#installation--deployment)
- [Project Structure](#project-structure)
- [Usage Examples](#usage-examples)
- [Configuration](#configuration)
- [Monitoring & Observability](#monitoring--observability)
- [Contributing](#contributing)
- [License](#license)
- [References](#references)

## 🎯 Overview

This project provides an enterprise-grade monitoring infrastructure for Azure Logic Apps Standard workflows. It demonstrates best practices for implementing comprehensive observability, diagnostic logging, and health monitoring for Logic Apps using native Azure services.

**Target Audience:**
- Cloud Architects designing Logic Apps solutions
- DevOps Engineers implementing monitoring infrastructure
- Platform Engineers managing Azure integration services
- Developers building Logic Apps workflows

**Use Cases:**
- Production Logic Apps monitoring and diagnostics
- Compliance and audit logging for business workflows
- Performance optimization and troubleshooting
- Automated health monitoring and alerting

## ✨ Features

### Monitoring Infrastructure
- **Application Insights Integration**: End-to-end telemetry collection and application performance monitoring (APM)
- **Log Analytics Workspace**: Centralized log aggregation and advanced query capabilities with KQL
- **Azure Monitor Health Models**: Proactive health monitoring and alerting
- **Diagnostic Settings**: Comprehensive logging for Logic Apps, Service Bus, Storage, and App Service Plans

### Infrastructure as Code
- **Bicep Templates**: Modular, reusable infrastructure definitions
- **Azure Developer CLI (azd) Support**: Simplified deployment and lifecycle management
- **Environment-based Deployments**: Support for dev, UAT, and production environments
- **Managed Identities**: Secure, passwordless authentication throughout the solution

### Workload Components
- **Logic Apps Standard**: Stateful and stateless workflow execution
- **Azure Functions**: API integration and custom processing
- **Storage Queues**: Reliable message-based workflow triggers
- **Service Bus**: Enterprise messaging capabilities

### Security & Compliance
- **Role-Based Access Control (RBAC)**: Least-privilege access patterns
- **TLS 1.2 Enforcement**: Secure data transmission
- **Diagnostic Logging**: Complete audit trail for compliance
- **Tagging Strategy**: Comprehensive resource organization and cost tracking

## 🏗️ Architecture

The solution deploys a complete monitoring stack with the following components:

```
┌─────────────────────────────────────────────────────────────┐
│                    Subscription Scope                        │
│  ┌───────────────────────────────────────────────────────┐  │
│  │           Resource Group (contoso-*-rg)                │  │
│  │                                                         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │         Monitoring Infrastructure               │  │  │
│  │  │  • Log Analytics Workspace                      │  │  │
│  │  │  • Application Insights                         │  │  │
│  │  │  • Storage Account (Diagnostic Logs)            │  │  │
│  │  │  • Azure Monitor Health Model                   │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │                          ↓                              │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │           Workload Infrastructure               │  │  │
│  │  │  • Logic Apps Standard (Workflows)              │  │  │
│  │  │  • App Service Plan (Workflow Standard)         │  │  │
│  │  │  • Azure Functions (API Integration)            │  │  │
│  │  │  • Storage Account (Workflow State)             │  │  │
│  │  │  • Storage Queues (Messaging)                   │  │  │
│  │  │  • Managed Identity                             │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## 📦 Prerequisites

### Required Tools
- **Azure CLI**: v2.50.0 or higher
  ```powershell
  az --version
  ```
- **Azure Developer CLI (azd)**: v1.5.0 or higher
  ```powershell
  azd version
  ```
- **Bicep CLI**: v0.20.0 or higher (installed automatically with Azure CLI)
  ```powershell
  az bicep version
  ```
- **PowerShell**: v7.0 or higher (for Windows)
- **VS Code** (recommended): With the following extensions:
  - Azure Logic Apps (Standard)
  - Bicep
  - Azure Account

### Azure Requirements
- **Azure Subscription**: Active subscription with appropriate permissions
- **Required Permissions**:
  - Contributor or Owner role at subscription or resource group level
  - Ability to create resource groups
  - Ability to assign managed identities and RBAC roles
- **Resource Providers**: The following must be registered:
  - `Microsoft.Logic`
  - `Microsoft.Web`
  - `Microsoft.Storage`
  - `Microsoft.Insights`
  - `Microsoft.OperationalInsights`
  - `Microsoft.ManagedIdentity`

### Local Development (Optional)
For local Logic Apps development and testing:
- **Azure Functions Core Tools**: v4.x
  ```powershell
  npm install -g azure-functions-core-tools@4
  ```
- **Node.js**: v18.x or higher
- **.NET SDK**: v6.0 or higher

## 🚀 Installation & Deployment

### Option 1: Using Azure Developer CLI (Recommended)

1. **Clone the Repository**
   ```powershell
   git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
   cd Azure-LogicApps-Monitoring
   ```

2. **Login to Azure**
   ```powershell
   azd auth login
   ```

3. **Initialize the Environment**
   ```powershell
   azd init
   ```
   When prompted, provide:
   - Environment name (e.g., `dev`, `uat`, `prod`)

4. **Deploy the Solution**
   ```powershell
   azd up
   ```
   This command will:
   - Provision all Azure resources
   - Configure monitoring and diagnostics
   - Set up managed identities and RBAC
   - Deploy Logic Apps workflows

### Option 2: Using Azure CLI with Bicep

1. **Clone the Repository**
   ```powershell
   git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
   cd Azure-LogicApps-Monitoring
   ```

2. **Login to Azure**
   ```powershell
   az login
   az account set --subscription "<your-subscription-id>"
   ```

3. **Set Deployment Parameters**
   Edit `infra/main.parameters.json` or provide parameters inline:
   ```json
   {
     "solutionName": "tax-docs",
     "location": "eastus",
     "envName": "dev"
   }
   ```

4. **Deploy at Subscription Scope**
   ```powershell
   az deployment sub create `
     --location eastus `
     --template-file infra/main.bicep `
     --parameters infra/main.parameters.json
   ```

5. **Retrieve Deployment Outputs**
   ```powershell
   az deployment sub show `
     --name main `
     --query properties.outputs
   ```

### Deployment Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `solutionName` | string | Yes | `tax-docs` | Base name for all resources (3-20 chars) |
| `location` | string | Yes | - | Azure region (e.g., `eastus`, `westeurope`) |
| `envName` | string | Yes | - | Environment: `dev`, `uat`, or `prod` |
| `deploymentDate` | string | No | `utcNow()` | Deployment timestamp for tracking |

### Validate Deployment

After deployment, verify the resources:

```powershell
# List all resources in the resource group
az resource list --resource-group contoso-tax-docs-dev-eastus-rg --output table

# Check Logic App status
az logicapp show --name <logic-app-name> --resource-group <rg-name>

# Verify Application Insights
az monitor app-insights component show --app <app-insights-name> --resource-group <rg-name>
```

## 📁 Project Structure

```
Azure-LogicApps-Monitoring/
├── infra/                              # Infrastructure as Code
│   ├── main.bicep                      # Main subscription-level deployment
│   └── main.parameters.json            # Deployment parameters
├── src/
│   ├── monitoring/                     # Monitoring infrastructure modules
│   │   ├── main.bicep                  # Monitoring orchestration
│   │   ├── log-analytics-workspace.bicep
│   │   ├── app-insights.bicep
│   │   └── azure-monitor-health-model.bicep
│   └── workload/                       # Application workload modules
│       ├── main.bicep                  # Workload orchestration
│       ├── logic-app.bicep             # Logic Apps Standard
│       ├── azure-function.bicep        # Azure Functions
│       └── messaging/
│           └── main.bicep              # Storage queues and messaging
├── tax-docs/                           # Sample Logic Apps workflow
│   ├── connections.json                # API connections configuration
│   ├── host.json                       # Logic Apps host settings
│   ├── local.settings.json             # Local development settings
│   └── tax-processing/
│       └── workflow.json               # Workflow definition
├── azure.yaml                          # Azure Developer CLI configuration
├── host.json                           # Functions host configuration
├── README.MD                           # This file
├── CONTRIBUTING.md                     # Contribution guidelines
├── LICENSE.MD                          # License information
└── SECURITY.md                         # Security policies
```

## 💡 Usage Examples

### Accessing Application Insights

1. **Navigate to Application Insights** in the Azure Portal
2. **View Live Metrics** for real-time monitoring:
   ```
   Azure Portal → Application Insights → Live Metrics
   ```

3. **Query Telemetry Data** using KQL:
   ```kql
   traces
   | where timestamp > ago(1h)
   | where operation_Name contains "tax-processing"
   | order by timestamp desc
   | project timestamp, message, severityLevel
   ```

### Monitoring Logic Apps Workflows

1. **View Workflow Runs** in the Azure Portal:
   ```
   Azure Portal → Logic Apps → <your-logic-app> → Workflow Runs
   ```

2. **Query Workflow Execution Logs**:
   ```kql
   AzureDiagnostics
   | where ResourceProvider == "MICROSOFT.LOGIC"
   | where Category == "WorkflowRuntime"
   | project TimeGenerated, resource_workflowName_s, status_s, error_s
   ```

3. **Monitor Workflow Performance**:
   ```kql
   requests
   | where cloud_RoleName contains "logic-app"
   | summarize avg(duration), count() by bin(timestamp, 5m)
   | render timechart
   ```

### Setting Up Alerts

Create a metric alert for failed workflow runs:

```powershell
az monitor metrics alert create `
  --name "Logic-App-Failed-Runs" `
  --resource-group contoso-tax-docs-dev-eastus-rg `
  --scopes "/subscriptions/<sub-id>/resourceGroups/<rg-name>/providers/Microsoft.Logic/workflows/<logic-app-name>" `
  --condition "count workflowRunsCompleted where status = 'Failed' > 5" `
  --window-size 5m `
  --evaluation-frequency 1m `
  --action-group <action-group-id>
```

### Accessing Diagnostic Logs

Query diagnostic logs from Log Analytics:

```kql
// Logic App execution details
AzureDiagnostics
| where ResourceType == "WORKFLOWS"
| where Category == "WorkflowRuntime"
| project TimeGenerated, RunId = resource_runId_s, Status = status_s, 
          WorkflowName = resource_workflowName_s, Error = error_s
| order by TimeGenerated desc

// Storage Queue metrics
StorageQueueLogs
| where AccountName contains "taxdocs"
| where OperationName == "GetMessages"
| summarize Count = count() by bin(TimeGenerated, 1h)
| render timechart
```

### Local Development

To run Logic Apps locally for development:

1. **Navigate to the workflow directory**:
   ```powershell
   cd tax-docs
   ```

2. **Update local settings**:
   Edit `local.settings.json` with your connection strings

3. **Start the Logic Apps runtime**:
   ```powershell
   func start
   ```

4. **Access the workflow designer**:
   Open in VS Code with the Azure Logic Apps extension

## ⚙️ Configuration

### Environment Variables

The following settings are configured automatically during deployment:

| Setting | Purpose |
|---------|---------|
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | Application Insights telemetry endpoint |
| `APPINSIGHTS_INSTRUMENTATIONKEY` | Legacy instrumentation key |
| `AzureWebJobsStorage` | Storage account for Logic Apps runtime |
| `WORKFLOWS_STORAGE_ACCOUNT_NAME` | Workflow state storage |

### Tagging Strategy

All resources are tagged for organization and cost management:

```bicep
{
  Solution: "tax-docs"
  Environment: "dev|uat|prod"
  ManagedBy: "Bicep"
  CostCenter: "Engineering"
  Owner: "Platform-Team"
  ApplicationName: "Tax-Docs-Processing"
  BusinessUnit: "Tax"
  DeploymentDate: "YYYY-MM-DD"
  Repository: "Azure-LogicApps-Monitoring"
}
```

### Scaling Configuration

Logic Apps App Service Plan is configured for elastic scaling:

- **SKU**: WS1 (Workflow Standard)
- **Elastic Scale**: Enabled
- **Max Workers**: 20
- **Auto-scale**: Based on workflow execution load

## 📊 Monitoring & Observability

### Key Metrics to Monitor

1. **Workflow Success Rate**
   - Target: > 99%
   - Alert threshold: < 95%

2. **Workflow Duration**
   - P50: < 5 seconds
   - P95: < 30 seconds
   - Alert threshold: P95 > 60 seconds

3. **Failed Runs**
   - Alert threshold: > 5 failures in 5 minutes

4. **Storage Queue Length**
   - Alert threshold: > 1000 messages

### Built-in Dashboards

The solution configures the following monitoring views:

1. **Application Insights Dashboard**
   - Live metrics stream
   - Application map
   - Performance metrics
   - Failure analysis

2. **Log Analytics Workspace**
   - Custom KQL queries
   - Workbooks for workflow analysis
   - Long-term log retention

3. **Azure Monitor Health Model**
   - Resource health tracking
   - Service health integration
   - Proactive alerts

## 🤝 Contributing

We welcome contributions from the community! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for details on:

- Code of conduct
- Development workflow
- Pull request process
- Coding standards
- Testing requirements

### Quick Start for Contributors

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature-name`
3. Make your changes and test thoroughly
4. Commit with descriptive messages: `git commit -m "Add feature: description"`
5. Push to your fork: `git push origin feature/your-feature-name`
6. Open a Pull Request with a clear description

### Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- Include detailed reproduction steps
- Provide Bicep version, Azure CLI version, and environment details

## 📄 License

This project is licensed under the MIT License. See [LICENSE.MD](LICENSE.MD) for details.

## 📚 References

### Official Documentation

- [Azure Logic Apps Standard](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview)
- [Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- [Azure Monitor](https://learn.microsoft.com/azure/azure-monitor/overview)
- [Bicep Language](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview)
- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview)

### Best Practices

- [Logic Apps Best Practices](https://learn.microsoft.com/azure/logic-apps/logic-apps-best-practices-guide)
- [Azure Monitor Best Practices](https://learn.microsoft.com/azure/azure-monitor/best-practices)
- [Infrastructure as Code Best Practices](https://learn.microsoft.com/azure/azure-resource-manager/bicep/best-practices)
- [Security Best Practices for Logic Apps](https://learn.microsoft.com/azure/logic-apps/logic-apps-securing-a-logic-app)

### Related Resources

- [Azure Architecture Center - Integration Patterns](https://learn.microsoft.com/azure/architecture/reference-architectures/enterprise-integration/)
- [KQL Query Examples](https://learn.microsoft.com/azure/data-explorer/kusto/query/)
- [Managed Identity Documentation](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)

### Community & Support

- [GitHub Issues](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues) - Bug reports and feature requests
- [GitHub Discussions](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/discussions) - Questions and community support
- [Azure Community Support](https://azure.microsoft.com/support/community/)
- [Stack Overflow - Azure Logic Apps](https://stackoverflow.com/questions/tagged/azure-logic-apps)

---

**Maintained by**: Platform Team  
**Repository**: [Azure-LogicApps-Monitoring](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)  
**Last Updated**: December 2025

For questions, feedback, or support, please open an issue or start a discussion on GitHub.
