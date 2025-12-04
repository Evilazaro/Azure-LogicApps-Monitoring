# Azure Logic Apps Monitoring Open Source Project

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE.md)
[![Azure](https://img.shields.io/badge/Azure-Logic%20Apps-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/en-us/services/logic-apps/)
[![Bicep](https://img.shields.io/badge/IaC-Bicep-blue)](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)

A comprehensive monitoring and observability solution for Azure Logic Apps Standard using Azure Monitor, Application Insights, and Log Analytics. This project demonstrates enterprise-grade best practices for workflow orchestration observability using Infrastructure as Code (IaC) with Bicep templates.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Deployment](#deployment)
- [Project Structure](#project-structure)
- [Monitoring Components](#monitoring-components)
- [Usage Examples](#usage-examples)
- [Configuration](#configuration)
- [Best Practices](#best-practices)
- [Contributing](#contributing)
- [Security](#security)
- [License](#license)
- [Resources](#resources)

## 🎯 Overview

This project provides a production-ready monitoring solution for Azure Logic Apps Standard, designed for beginner-to-intermediate developers and architects who want to implement comprehensive observability for their workflow orchestration solutions.

### Key Benefits

- **Enterprise-Ready Monitoring**: Pre-configured Azure Monitor health models and alerts
- **Infrastructure as Code**: Fully automated deployment using Bicep templates
- **Cost-Effective**: Optimized Log Analytics workspace configuration
- **Scalable**: Designed for multi-environment deployments
- **Best Practices**: Follows Microsoft Azure Well-Architected Framework principles

## ✨ Features

- 🔍 **Comprehensive Observability**: Application Insights integration for end-to-end workflow tracking
- 📊 **Custom Health Models**: Azure Monitor health models specifically designed for Logic Apps
- 📈 **Log Analytics Integration**: Centralized logging and advanced query capabilities
- 🚨 **Proactive Alerting**: Pre-configured alert rules for common failure scenarios
- 🔄 **Automated Deployment**: One-command infrastructure provisioning
- 🏗️ **Modular Architecture**: Reusable Bicep modules for flexible deployment
- 📝 **Example Workflows**: Tax document processing sample Logic App

## 🏛️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Azure Subscription                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Resource Group                          │   │
│  │                                                      │   │
│  │  ┌──────────────────┐      ┌──────────────────┐   │   │
│  │  │  Logic Apps      │─────▶│  Application     │   │   │
│  │  │  Standard        │      │  Insights        │   │   │
│  │  └──────────────────┘      └──────────────────┘   │   │
│  │           │                          │             │   │
│  │           │                          │             │   │
│  │           ▼                          ▼             │   │
│  │  ┌──────────────────┐      ┌──────────────────┐   │   │
│  │  │  Azure Monitor   │      │  Log Analytics   │   │   │
│  │  │  Health Model    │      │  Workspace       │   │   │
│  │  └──────────────────┘      └──────────────────┘   │   │
│  │                                                      │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

Before deploying this solution, ensure you have:

### Required Tools

- **Azure CLI** (version 2.50.0 or later)
  ```bash
  az --version
  ```
- **Bicep CLI** (version 0.20.0 or later)
  ```bash
  az bicep version
  ```
- **Azure Developer CLI (azd)** - for simplified deployment
  ```bash
  azd version
  ```

### Azure Requirements

- Active Azure subscription
- Contributor or Owner role on the subscription or resource group
- Resource providers registered:
  - `Microsoft.Web`
  - `Microsoft.Insights`
  - `Microsoft.OperationalInsights`
  - `Microsoft.Logic`

### Development Tools (Optional)

- Visual Studio Code with extensions:
  - Bicep
  - Azure Logic Apps (Standard)
  - Azure Account

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

### 2. Review Configuration

Examine the configuration files:

- [`azure.yaml`](azure.yaml) - Azure Developer CLI configuration
- [`infra/main.parameters.json`](infra/main.parameters.json) - Bicep deployment parameters

### 3. Customize Parameters

Update [`infra/main.parameters.json`](infra/main.parameters.json) with your environment-specific values:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "environmentName": {
      "value": "dev"
    },
    "location": {
      "value": "eastus"
    },
    "projectName": {
      "value": "logicapps-monitoring"
    }
  }
}
```

## 🔧 Deployment

### Option 1: Deploy with Azure Developer CLI (Recommended)

```bash
# Login to Azure
azd auth login

# Initialize the environment
azd init

# Provision infrastructure and deploy
azd up
```

### Option 2: Deploy with Azure CLI

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "<your-subscription-id>"

# Create resource group
az group create --name "rg-logicapps-monitoring" --location "eastus"

# Deploy Bicep template
az deployment group create \
  --resource-group "rg-logicapps-monitoring" \
  --template-file "infra/main.bicep" \
  --parameters "@infra/main.parameters.json"
```

### Option 3: Deploy Monitoring Components Only

If you already have Logic Apps deployed:

```bash
az deployment group create \
  --resource-group "<your-resource-group>" \
  --template-file "src/monitoring/main.bicep" \
  --parameters logicAppName="<your-logic-app-name>"
```

## 📁 Project Structure

```
Azure-LogicApps-Monitoring/
├── .vscode/                          # VS Code workspace settings
│   ├── launch.json                   # Debug configurations
│   ├── settings.json                 # Editor settings
│   └── tasks.json                    # Build tasks
├── infra/                            # Infrastructure as Code
│   ├── main.bicep                    # Main Bicep template
│   └── main.parameters.json          # Deployment parameters
├── src/
│   ├── monitoring/                   # Monitoring infrastructure modules
│   │   ├── app-insights.bicep        # Application Insights configuration
│   │   ├── azure-monitor-health-model.bicep  # Health model definitions
│   │   ├── log-analytics-workspace.bicep     # Log Analytics setup
│   │   └── main.bicep                # Monitoring orchestration
│   └── workload/                     # Logic Apps workload components
├── tax-docs/                         # Sample Logic App (Tax Processing)
│   ├── connections.json              # API connections configuration
│   ├── host.json                     # Host configuration
│   ├── local.settings.json           # Local development settings
│   └── tax-processing/               # Workflow definitions
├── azure.yaml                        # Azure Developer CLI configuration
├── host.json                         # Global host settings
├── CODE_OF_CONDUCT.md               # Community guidelines
├── CONTRIBUTING.md                   # Contribution guidelines
├── LICENSE.md                        # MIT License
├── SECURITY.md                       # Security policy
└── README.md                         # This file
```

## 📊 Monitoring Components

### Application Insights

Located in [`src/monitoring/app-insights.bicep`](src/monitoring/app-insights.bicep), this module provides:

- Distributed tracing for workflow execution
- Performance metrics and telemetry
- Real-time monitoring dashboards
- Integration with Logic Apps diagnostic settings

### Log Analytics Workspace

Defined in [`src/monitoring/log-analytics-workspace.bicep`](src/monitoring/log-analytics-workspace.bicep):

- Centralized log aggregation
- Custom query capabilities (KQL)
- 30-day retention by default
- Integration with Azure Monitor

### Azure Monitor Health Model

Implemented in [`src/monitoring/azure-monitor-health-model.bicep`](src/monitoring/azure-monitor-health-model.bicep):

- Custom health criteria for Logic Apps
- Workflow-specific alert rules
- Automated incident management
- Performance baseline tracking

## 💡 Usage Examples

### Query Workflow Execution History

```kusto
// Navigate to Log Analytics Workspace in Azure Portal
// Run this KQL query

AzureDiagnostics
| where ResourceType == "WORKFLOWS"
| where Category == "WorkflowRuntime"
| where status_s == "Failed"
| project TimeGenerated, resource_workflowName_s, status_s, error_message_s
| order by TimeGenerated desc
```

### Monitor Workflow Performance

```kusto
requests
| where cloud_RoleName contains "logic-app"
| summarize 
    AvgDuration = avg(duration),
    P95Duration = percentile(duration, 95),
    Count = count()
    by bin(timestamp, 1h)
| render timechart
```

### View Failed Workflow Runs

Access the Azure Portal → your Logic App → Workflow runs, or query via CLI:

```bash
az logicapp workflow show \
  --resource-group "rg-logicapps-monitoring" \
  --name "tax-processing" \
  --query "state"
```

## ⚙️ Configuration

### Environment Variables

For local development, configure [`tax-docs/local.settings.json`](tax-docs/local.settings.json):

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "node",
    "WORKFLOWS_SUBSCRIPTION_ID": "<your-subscription-id>",
    "WORKFLOWS_RESOURCE_GROUP_NAME": "<your-resource-group>"
  }
}
```

### Monitoring Configuration

Adjust monitoring settings in [`src/monitoring/main.bicep`](src/monitoring/main.bicep):

- Log retention periods
- Alert thresholds
- Diagnostic settings
- Sampling rates

## 🎯 Best Practices

This solution implements Azure Well-Architected Framework principles:

### Reliability

- Health probes and monitoring
- Automated alerting and incident response
- Retry policies and error handling

### Security

- Managed identities for authentication
- Key Vault integration for secrets
- Network isolation options
- See [SECURITY.md](SECURITY.md) for more details

### Cost Optimization

- Appropriate Log Analytics retention
- Sampling strategies for Application Insights
- Resource tagging for cost allocation

### Operational Excellence

- Infrastructure as Code (IaC)
- Automated deployments
- Comprehensive monitoring and alerting
- Documentation and runbooks

### Performance Efficiency

- Optimized query patterns
- Efficient log ingestion
- Performance baselines and SLOs

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details on:

- Code of Conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- How to submit pull requests
- Coding standards and conventions
- Testing requirements

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 🔒 Security

Security is a top priority. Please review our [Security Policy](SECURITY.md) for:

- Reporting security vulnerabilities
- Security best practices
- Supported versions

**⚠️ Do NOT commit sensitive information such as connection strings, secrets, or credentials.**

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.

## 📚 Resources

### Official Documentation

- [Azure Logic Apps Documentation](https://docs.microsoft.com/en-us/azure/logic-apps/)
- [Azure Monitor Documentation](https://docs.microsoft.com/en-us/azure/azure-monitor/)
- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Application Insights](https://docs.microsoft.com/en-us/azure/azure-monitor/app/app-insights-overview)

### Related Projects

- [Azure Logic Apps Samples](https://github.com/Azure/logicapps)
- [Azure Monitoring Baseline](https://github.com/Azure/azure-monitor-baseline-alerts)

### Learning Resources

- [Microsoft Learn - Logic Apps](https://learn.microsoft.com/en-us/training/paths/build-workflows-with-logic-apps/)
- [Microsoft Learn - Azure Monitor](https://learn.microsoft.com/en-us/training/modules/intro-to-azure-monitor/)

---

## 🙋 Support

If you encounter issues or have questions:

1. Check existing [Issues](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues)
2. Create a new issue with detailed information
3. Review the [Contributing Guide](CONTRIBUTING.md)

## 🌟 Acknowledgments

This project demonstrates best practices recommended by Microsoft Azure and the community. Special thanks to all contributors who help improve this solution.

---

**Made with ❤️ for the Azure community**