# Azure Logic Apps Standard - Enterprise Monitoring Solution

A comprehensive, production-ready monitoring solution for Azure Logic Apps Standard using Infrastructure as Code (IaC) with Bicep templates. This project demonstrates Azure Monitor best practices, providing deep observability for enterprise workflow orchestration with pre-configured Application Insights, Log Analytics, diagnostic settings, and Azure Monitor health models.

[![License](https://img.shields.io/badge/License-Not%20Specified-lightgrey.svg)](LICENSE.md)
[![Azure](https://img.shields.io/badge/Azure-Logic%20Apps%20Standard-0078D4?logo=microsoft-azure)](https://azure.microsoft.com/services/logic-apps/)
[![IaC](https://img.shields.io/badge/IaC-Bicep-3178C6?logo=azure-devops)](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)

---

## Table of Contents

- [Project Overview](#project-overview)
  - [Purpose](#purpose)
  - [Key Features](#key-features)
  - [Target Audience](#target-audience)
  - [Benefits](#benefits)
- [Architecture](#architecture)
- [What Gets Monitored](#what-gets-monitored)
- [How It Monitors](#how-it-monitors)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Deployment](#deployment)
- [Configuration](#configuration)
- [Monitoring Components](#monitoring-components)
- [Integration Points](#integration-points)
- [Project Structure](#project-structure)
- [Best Practices](#best-practices)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Additional Resources](#additional-resources)

---

## Project Overview

### Purpose

**Why this solution was created:**

Azure Logic Apps Standard offers powerful workflow orchestration capabilities, but out-of-the-box monitoring often falls short for enterprise production environments. Organizations need comprehensive observability to:

- Track workflow execution health, performance, and reliability in real-time
- Diagnose failures quickly with correlated telemetry across distributed systems
- Meet compliance requirements for audit logging and data retention
- Optimize costs by identifying inefficient workflows and resource utilization
- Enable proactive alerting before issues impact business operations

**What problem it solves:**

This solution addresses the observability gap by providing a complete, enterprise-grade monitoring infrastructure that goes beyond default Azure monitoring. It eliminates the manual effort of configuring diagnostic settings, setting up Log Analytics queries, and integrating Application Insights for Logic Apps Standard deployments.

**Target use cases:**

- **Production Logic Apps deployments** requiring comprehensive observability
- **Enterprise workflow orchestration** with multiple integration points
- **Compliance-driven environments** needing audit trails and long-term log retention
- **Multi-environment deployments** (dev, UAT, prod) with consistent monitoring patterns
- **Tax processing workflows** and other mission-critical business processes
- **Microservices architectures** where Logic Apps coordinate between Azure Functions, Storage, and messaging services

### Key Features

#### What It Monitors

This solution provides comprehensive monitoring across your entire Logic Apps ecosystem:

| Component | Monitored Resources | Key Metrics & Logs |
|-----------|-------------------|-------------------|
| **Logic Apps Standard** | Workflow runtime, execution status, App Service Plan | `WorkflowRuntime` logs, workflow success/failure rates, execution duration, trigger latency, action performance |
| **Application Insights** | Telemetry ingestion, query performance | Request traces, dependencies, exceptions, custom events, availability |
| **Azure Functions** | API integration layer, function executions | HTTP logs, console logs, application logs, execution counts, duration, failures |
| **Storage Accounts** | Workflow storage, queue services, message processing | Queue metrics, blob operations, table transactions, file service activity, capacity metrics |
| **App Service Plans** | Compute resources for Logic Apps and Functions | CPU percentage, memory usage, HTTP queue length, worker process counts |
| **Log Analytics Workspace** | Centralized log aggregation and querying | Workspace audit logs, ingestion volume, query performance |

#### How It Monitors

The solution implements Azure monitoring best practices through:

1. **Centralized Log Analytics Workspace**
   - Single source of truth for all diagnostic logs and metrics
   - 30-day retention with immediate purge capability for compliance
   - Workspace-based Application Insights integration
   - System-assigned managed identity for secure access

2. **Comprehensive Diagnostic Settings**
   - **Logic Apps**: Captures `WorkflowRuntime` logs and all metrics
   - **Application Insights**: All logs and metrics with dual destination (Log Analytics + Storage)
   - **Azure Functions**: HTTP logs, console logs, and application logs
   - **Storage Accounts**: Queue service logs, all metrics
   - **App Service Plans**: All compute metrics

3. **Long-Term Storage Strategy**
   - Dedicated storage account for diagnostic log archival
   - Hot tier with LRS redundancy optimized for frequent access
   - TLS 1.2 minimum, HTTPS-only enforcement
   - Azure Services bypass for network security

4. **Application Insights Telemetry**
   - Workspace-based mode for unified query experience
   - Automatic correlation across Logic Apps, Functions, and dependencies
   - Public ingestion and query endpoints for flexible access
   - Connection string and instrumentation key distribution

5. **Azure Monitor Health Model** (Preview Feature)
   - Tenant-scoped service group organization
   - Hierarchical health monitoring structure
   - Integration with Azure Monitor health APIs

6. **Managed Identity Security**
   - User-assigned managed identity for Logic Apps
   - RBAC role assignments for storage access (Contributor, Blob Data Owner, Queue/Table/File Data Contributor)
   - Eliminates connection string management
   - Secure credential-less authentication

#### Integration Points

The solution integrates seamlessly with:

| Integration | Purpose | Implementation |
|------------|---------|---------------|
| **Application Insights → Log Analytics** | Unified query experience across all telemetry | Workspace-based Application Insights with `WorkspaceResourceId` linkage |
| **Logic Apps → Application Insights** | Distributed tracing and correlation | Connection string and instrumentation key via app settings |
| **All Resources → Log Analytics** | Centralized diagnostic logs | Diagnostic settings with `workspaceId` configuration |
| **All Resources → Storage Account** | Long-term log archival | Diagnostic settings with `storageAccountId` for compliance |
| **Logic Apps → Storage Queue** | Workflow trigger and data storage | Managed identity authentication with RBAC role assignments |
| **Logic Apps → Azure Functions** | API integration and compute offloading | App Service Plan dependency and networking |
| **Azure Functions → Application Insights** | Function telemetry and performance monitoring | Application Insights agent extension (v3) |

### Target Audience

This solution is designed for:

- **DevOps Engineers** managing Azure Logic Apps Standard in production environments
- **Azure Architects** designing comprehensive monitoring solutions for enterprise integrations
- **Platform Engineers** standardizing observability patterns across multiple Logic Apps deployments
- **Site Reliability Engineers (SREs)** implementing proactive monitoring and alerting
- **Beginner-to-Intermediate Azure Developers** learning monitoring best practices
- **Compliance Officers** ensuring audit trail and log retention requirements are met

### Benefits

**How this differs from default Azure monitoring:**

| Aspect | Default Azure Monitoring | This Solution |
|--------|------------------------|--------------|
| **Diagnostic Settings** | Manual configuration per resource | Automated via Bicep templates for all resources |
| **Log Analytics Integration** | Optional, requires setup | Pre-configured with workspace-based Application Insights |
| **Long-Term Storage** | Not included by default | Dedicated storage account with 30-day Log Analytics retention |
| **Managed Identity** | Manual RBAC assignment | Automated role assignments for storage access |
| **Multi-Resource Correlation** | Limited out-of-the-box | End-to-end tracing across Logic Apps, Functions, Storage |
| **Infrastructure as Code** | Not provided | Complete Bicep templates with modular architecture |
| **Health Modeling** | Not configured | Azure Monitor health model (preview) included |

**Gaps filled beyond out-of-the-box Application Insights:**

1. **Complete Diagnostic Coverage**: Automatically configures diagnostic settings for Logic Apps, Functions, Storage, and App Service Plans—not just Application Insights
2. **Compliance-Ready Archival**: Dedicated storage account for long-term log retention beyond workspace limits
3. **Secure Credential Management**: Managed identity with RBAC instead of connection strings
4. **Workflow-Specific Logging**: Captures `WorkflowRuntime` category specifically for Logic Apps
5. **Unified Query Experience**: Workspace-based Application Insights enables KQL queries across all resources in one place

**Logic Apps-specific monitoring capabilities:**

- **Workflow Execution Tracking**: Detailed runtime logs showing trigger firing, action execution, and completion status
- **Action-Level Performance**: Individual action duration and failure analysis
- **Trigger Latency Monitoring**: Time between event occurrence and workflow start
- **Managed Identity Audit Trail**: Complete visibility into storage access patterns
- **Queue Processing Metrics**: Storage queue depth and processing throughput for workflow triggers

**Cost and operational advantages:**

- **Reduced Manual Configuration**: Infrastructure as Code eliminates repetitive Azure Portal clicks
- **Predictable Costs**: PerGB2018 pricing tier with 30-day retention provides cost control
- **Faster Troubleshooting**: Correlated telemetry reduces mean time to resolution (MTTR)
- **Reusable Templates**: Modular Bicep files enable consistent monitoring across environments
- **Single Deployment**: One command deploys entire monitoring infrastructure
- **Standard SKU Optimization**: Uses WorkflowStandard (WS1) SKU for cost-effective Logic Apps hosting

**Pre-configured health models and dashboards:**

- **Azure Monitor Health Model**: Tenant-scoped service group for hierarchical health tracking
- **Query-Ready Log Analytics**: Pre-integrated workspace enables immediate KQL query execution
- **Application Insights Correlation**: Automatic dependency mapping and application map visualization
- **Resource-Level Metrics**: All resources configured to send metrics to centralized destinations

---

## Architecture

The solution deploys a complete monitoring infrastructure with the following architecture:

```
┌─────────────────────────────────────────────────────────────────┐
│                    Azure Subscription                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Resource Group                                │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │         MONITORING LAYER                         │    │  │
│  │  │                                                  │    │  │
│  │  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │    │  │
│  │  │  ┃  Log Analytics Workspace               ┃    │    │  │
│  │  │  ┃  - 30-day retention                    ┃    │    │  │
│  │  │  ┃  - PerGB2018 pricing                   ┃    │    │  │
│  │  │  ┃  - System-assigned identity            ┃    │    │  │
│  │  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │    │  │
│  │  │           ↑                                     │    │  │
│  │  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │    │  │
│  │  │  ┃  Application Insights                  ┃    │    │  │
│  │  │  ┃  - Workspace-based mode                ┃    │    │  │
│  │  │  ┃  - Web application type                ┃    │    │  │
│  │  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │    │  │
│  │  │           ↑                                     │    │  │
│  │  │  ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓    │    │  │
│  │  │  ┃  Storage Account (Logs)                ┃    │    │  │
│  │  │  ┃  - Standard_LRS, Hot tier              ┃    │    │  │
│  │  │  ┃  - Long-term log archival              ┃    │    │  │
│  │  │  ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛    │    │  │
│  │  │                                                  │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  │                                                            │  │
│  │  ┌──────────────────────────────────────────────────┐    │  │
│  │  │         WORKLOAD LAYER                           │    │  │
│  │  │                                                  │    │  │
│  │  │  ┌──────────────────────────────────────────┐   │    │  │
│  │  │  │  Logic Apps Standard (WS1 SKU)          │   │    │  │
│  │  │  │  - WorkflowRuntime logs → Log Analytics │   │    │  │
│  │  │  │  - AllMetrics → Log Analytics + Storage │   │    │  │
│  │  │  │  - User-assigned managed identity       │   │    │  │
│  │  │  └──────────────────────────────────────────┘   │    │  │
│  │  │                                                  │    │  │
│  │  │  ┌──────────────────────────────────────────┐   │    │  │
│  │  │  │  Azure Functions (.NET 9, Linux)        │   │    │  │
│  │  │  │  - HTTP/Console/App logs                │   │    │  │
│  │  │  │  - AllMetrics → Log Analytics + Storage │   │    │  │
│  │  │  └──────────────────────────────────────────┘   │    │  │
│  │  │                                                  │    │  │
│  │  │  ┌──────────────────────────────────────────┐   │    │  │
│  │  │  │  Storage Account (Workflow)              │   │    │  │
│  │  │  │  - Queue: taxprocessing                  │   │    │  │
│  │  │  │  - Queue logs → Log Analytics + Storage  │   │    │  │
│  │  │  │  - AllMetrics → Log Analytics + Storage  │   │    │  │
│  │  │  └──────────────────────────────────────────┘   │    │  │
│  │  │                                                  │    │  │
│  │  │  ┌──────────────────────────────────────────┐   │    │  │
│  │  │  │  App Service Plans (2)                   │   │    │  │
│  │  │  │  - WorkflowStandard (WS1) for Logic Apps │   │    │  │
│  │  │  │  - Premium0V3 (P0v3) for Functions       │   │    │  │
│  │  │  │  - AllMetrics → Log Analytics + Storage  │   │    │  │
│  │  │  └──────────────────────────────────────────┘   │    │  │
│  │  └──────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Azure Monitor Health Model (Tenant Scope)         │  │
│  │         - Service Group for hierarchical health           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Data Flow:**

1. **Logic Apps** → Sends WorkflowRuntime logs + metrics → Log Analytics Workspace + Storage Account
2. **Logic Apps** → Sends telemetry via Application Insights SDK → Application Insights → Log Analytics Workspace
3. **Azure Functions** → Sends HTTP/Console/App logs + metrics → Log Analytics Workspace + Storage Account
4. **Azure Functions** → Sends telemetry via Application Insights agent → Application Insights → Log Analytics Workspace
5. **Storage Accounts** → Sends queue logs + all metrics → Log Analytics Workspace + Storage Account
6. **App Service Plans** → Sends all metrics → Log Analytics Workspace + Storage Account
7. **Application Insights** → Sends own diagnostic logs + metrics → Log Analytics Workspace + Storage Account

---

## What Gets Monitored

### Resource Inventory

| Resource Type | Instance | Diagnostic Logs Enabled | Metrics Enabled | Telemetry Destination |
|--------------|----------|-------------------------|----------------|----------------------|
| **Logic Apps Standard** | 1 | ✅ WorkflowRuntime | ✅ AllMetrics | Log Analytics + Storage + App Insights |
| **Azure Functions** | 1 | ✅ HTTP, Console, App Logs | ✅ AllMetrics | Log Analytics + Storage + App Insights |
| **Application Insights** | 1 | ✅ allLogs | ✅ AllMetrics | Log Analytics + Storage |
| **Log Analytics Workspace** | 1 | ✅ (Self-diagnostic) | ❌ | Storage |
| **Storage Account (Workflow)** | 1 | ❌ (account-level), ✅ Queue Service | ✅ AllMetrics | Log Analytics + Storage |
| **Storage Account (Logs)** | 1 | ✅ (Self-diagnostic) | ❌ | Log Analytics |
| **App Service Plan (Logic Apps)** | 1 | ❌ | ✅ AllMetrics | Log Analytics + Storage |
| **App Service Plan (Functions)** | 1 | ❌ | ✅ AllMetrics | Log Analytics + Storage |
| **Managed Identity** | 1 | ❌ | ❌ | N/A |

### Log Categories Captured

| Resource | Log Category | Purpose |
|---------|-------------|---------|
| **Logic Apps** | `WorkflowRuntime` | Workflow execution events, trigger firing, action completion, failures |
| **Azure Functions** | `AppServiceHTTPLogs` | HTTP request logs for API calls |
| **Azure Functions** | `AppServiceConsoleLogs` | Console output from function executions |
| **Azure Functions** | `AppServiceAppLogs` | Application-level logging from function code |
| **Storage Queue Service** | `allLogs` (categoryGroup) | Queue operations: message creation, deletion, retrieval |
| **Application Insights** | `allLogs` (categoryGroup) | Telemetry ingestion logs, query execution logs |

### Metrics Tracked

All resources send **AllMetrics** category, which includes:

- **Logic Apps**: Workflow runs, action runs, trigger latency, billable execution units
- **Azure Functions**: Function execution count, execution units, memory usage
- **Storage Account**: Queue message count, transaction counts, ingress/egress
- **App Service Plans**: CPU percentage, memory percentage, HTTP queue length

---

## How It Monitors

### Monitoring Mechanisms

#### 1. Diagnostic Settings (Resource-Level)

Every Azure resource in the workload layer has diagnostic settings configured to send logs and metrics to:

- **Primary destination**: Log Analytics Workspace (for querying and alerting)
- **Secondary destination**: Storage Account (for long-term archival and compliance)

**Example configuration** (Logic App):

```bicep
resource logicAppDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${logicApp.name}-diag'
  scope: logicApp
  properties: {
    workspaceId: workspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        category: 'WorkflowRuntime'
        enabled: true
      }
    ]
    metrics: [
      {
        enabled: true
        category: 'AllMetrics'
      }
    ]
  }
}
```

#### 2. Application Insights Telemetry

**Logic Apps integration**:
- Connection string and instrumentation key injected as application settings
- Automatic correlation IDs for distributed tracing
- Captures workflow dependencies, exceptions, and custom events

**Azure Functions integration**:
- Application Insights agent extension v3 enabled
- Automatic function execution telemetry
- HTTP request tracing with dependency correlation

#### 3. Log Analytics Workspace

**Central query hub** for all monitoring data:

- **Workspace-based Application Insights**: Unified KQL query experience
- **30-day retention**: Configurable via `retentionInDays` parameter
- **Immediate purge**: GDPR-compliant data deletion with `immediatePurgeDataOn30Days`

**Common KQL queries**:

```kusto
// Logic App workflow failures
AzureDiagnostics
| where Category == "WorkflowRuntime"
| where status_s == "Failed"
| summarize FailureCount = count() by workflowName_s, bin(TimeGenerated, 1h)

// Function execution duration
FunctionAppLogs
| where Category == "FunctionExecutionLogs"
| summarize avg(DurationMs), percentile(DurationMs, 95) by FunctionName

// Storage queue depth
AzureMetrics
| where ResourceProvider == "MICROSOFT.STORAGE"
| where MetricName == "QueueMessageCount"
| summarize avg(Average) by bin(TimeGenerated, 5m)
```

#### 4. Managed Identity Authentication

**Security and auditability**:

- User-assigned managed identity for Logic Apps
- RBAC role assignments automatically provisioned:
  - Storage Account Contributor
  - Storage Blob Data Owner
  - Storage Queue Data Contributor
  - Storage Table Data Contributor
  - Storage File Data Contributor

**Benefits**:
- No connection string rotation required
- Azure AD audit logs track all storage access
- Principle of least privilege via RBAC

#### 5. Azure Monitor Health Model (Preview)

**Hierarchical health tracking**:

```bicep
resource serviceGroup 'Microsoft.Management/serviceGroups@2024-02-01-preview' = {
  name: name
  scope: tenant()
  tags: tags
  kind: 'ServiceGroup'
  properties: {
    displayName: name
    parent: {
      resourceId: rootServiceGroup.id
    }
  }
}
```

Enables organization-wide health monitoring and rollup views.

---

## Prerequisites

Before deploying this solution, ensure you have:

### Required Tools

- **Azure CLI** version 2.50.0 or later ([Install](https://learn.microsoft.com/cli/azure/install-azure-cli))
- **Bicep CLI** version 0.20.0 or later (included with Azure CLI)
- **PowerShell** 7.0+ or **Bash** shell
- **Azure subscription** with Owner or Contributor role
- **Visual Studio Code** (optional, recommended) with Bicep extension

### Azure Permissions

- **Subscription-level access**: Required to create resource groups
- **Microsoft.Management/serviceGroups** permissions: Required for health model deployment (tenant-scoped)

### Azure Quotas

Verify sufficient quota for:
- App Service Plans (WorkflowStandard SKU, Premium V3 SKU)
- Storage Accounts (minimum 3 required)
- Log Analytics Workspaces

### Supported Regions

This solution has been tested in the following Azure regions:
- `eastus`, `eastus2`, `westus`, `westus2`, `westus3`
- `centralus`, `northcentralus`, `southcentralus`
- `westeurope`, `northeurope`
- `uksouth`, `ukwest`
- `australiaeast`, `australiasoutheast`

---

## Quick Start

Deploy the complete monitoring solution in under 10 minutes:

### 1. Clone the Repository

```powershell
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

### 2. Login to Azure

```powershell
az login
az account set --subscription "<Your-Subscription-ID>"
```

### 3. Review Parameters

Edit `infra/main.parameters.json`:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "solutionName": {
      "value": "tax-docs"
    },
    "location": {
      "value": "eastus"
    },
    "envName": {
      "value": "dev"
    }
  }
}
```

### 4. Deploy

```powershell
az deployment sub create \
  --name "logicapps-monitoring-$(Get-Date -Format 'yyyyMMddHHmmss')" \
  --location eastus \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

### 5. Verify Deployment

```powershell
# List deployed resources
az resource list --resource-group "contoso-tax-docs-dev-eastus-rg" --output table

# Get Application Insights connection string
az monitor app-insights component show \
  --resource-group "contoso-tax-docs-dev-eastus-rg" \
  --app "<app-insights-name>" \
  --query "connectionString" -o tsv
```

---

## Deployment

### Deployment Methods

#### Option 1: Azure CLI (Recommended)

```powershell
# Set variables
$subscriptionId = "<Your-Subscription-ID>"
$location = "eastus"
$deploymentName = "logicapps-monitoring-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Login and set subscription
az login
az account set --subscription $subscriptionId

# Validate deployment
az deployment sub validate \
  --location $location \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json

# Deploy
az deployment sub create \
  --name $deploymentName \
  --location $location \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.json
```

#### Option 2: PowerShell (Azure PowerShell)

```powershell
# Login
Connect-AzAccount
Set-AzContext -SubscriptionId "<Your-Subscription-ID>"

# Deploy
New-AzSubscriptionDeployment `
  -Name "logicapps-monitoring-$(Get-Date -Format 'yyyyMMddHHmmss')" `
  -Location "eastus" `
  -TemplateFile "infra/main.bicep" `
  -TemplateParameterFile "infra/main.parameters.json"
```

#### Option 3: Azure Portal

1. Navigate to **Azure Portal** → **Create a resource** → **Template deployment (deploy using custom templates)**
2. Click **Build your own template in the editor**
3. Load `infra/main.bicep` content
4. Click **Save**
5. Fill in parameters:
   - **Subscription**: Your subscription
   - **Location**: e.g., `eastus`
   - **Solution Name**: e.g., `tax-docs`
   - **Env Name**: `dev`, `uat`, or `prod`
6. Click **Review + create** → **Create**

### Deployment Validation

After deployment completes, verify resources:

```powershell
# Get resource group name
$rgName = "contoso-tax-docs-dev-eastus-rg"

# List all resources
az resource list --resource-group $rgName --output table

# Check Log Analytics Workspace
az monitor log-analytics workspace show \
  --resource-group $rgName \
  --workspace-name "<workspace-name>"

# Check Application Insights
az monitor app-insights component show \
  --resource-group $rgName \
  --app "<app-insights-name>"

# Check Logic App
az logicapp show \
  --name "<logic-app-name>" \
  --resource-group $rgName
```

### Deployment Outputs

After successful deployment, capture these outputs:

| Output Name | Description | Usage |
|------------|-------------|-------|
| `RESOURCE_GROUP_NAME` | Name of the deployed resource group | Resource management |
| `RESOURCE_GROUP_ID` | Resource ID of the resource group | ARM template references |
| `AZURE_LOG_ANALYTICS_WORKSPACE_ID` | Log Analytics workspace resource ID | KQL queries, alert rules |
| `AZURE_LOG_ANALYTICS_WORKSPACE_NAME` | Log Analytics workspace name | Portal navigation |
| `AZURE_APPLICATION_INSIGHTS_NAME` | Application Insights instance name | Portal navigation |
| `AZURE_APPLICATION_INSIGHTS_ID` | Application Insights resource ID | ARM template references |
| `AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING` | Application Insights connection string | Application configuration |
| `AZURE_APPLICATION_INSIGHTS_INSTRUMENTATION_KEY` | Application Insights instrumentation key | Legacy SDK configuration |

**Retrieve outputs**:

```powershell
az deployment sub show \
  --name $deploymentName \
  --query "properties.outputs"
```

---

## Configuration

### Customizing Parameters

Edit `infra/main.parameters.json` to customize your deployment:

```json
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "solutionName": {
      "value": "your-solution-name"
    },
    "location": {
      "value": "westus2"
    },
    "envName": {
      "value": "prod"
    }
  }
}
```

### Modifying Log Retention

To change Log Analytics retention period, edit `src/monitoring/log-analytics-workspace.bicep`:

```bicep
properties: {
  sku: {
    name: 'PerGB2018'
  }
  retentionInDays: 90  // Change from 30 to 90 days
  features: {
    immediatePurgeDataOn30Days: false  // Disable immediate purge
  }
}
```

### Adding Additional Resources

To monitor additional resources, create diagnostic settings:

```bicep
resource customResourceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'custom-resource-diag'
  scope: customResource
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    storageAccountId: storageAccountId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}
```

### Environment-Specific Configuration

Use separate parameter files for each environment:

```
infra/
  main.parameters.dev.json
  main.parameters.uat.json
  main.parameters.prod.json
```

Deploy with:

```powershell
az deployment sub create \
  --template-file infra/main.bicep \
  --parameters infra/main.parameters.prod.json
```

---

## Monitoring Components

### 1. Log Analytics Workspace

**Purpose**: Centralized log and metric storage with powerful query capabilities.

**Key configuration**:
- SKU: `PerGB2018` (pay-as-you-go)
- Retention: 30 days (configurable)
- Identity: System-assigned managed identity
- Network: Public access enabled

**Common queries**:

```kusto
// Top 10 most executed workflows
AzureDiagnostics
| where Category == "WorkflowRuntime"
| where OperationName == "Microsoft.Logic/workflows/workflowRunCompleted"
| summarize Count = count() by workflowName_s
| top 10 by Count desc

// Failed workflow runs with error details
AzureDiagnostics
| where Category == "WorkflowRuntime"
| where status_s == "Failed"
| project TimeGenerated, workflowName_s, error_code_s, error_message_s
| order by TimeGenerated desc
```

### 2. Application Insights

**Purpose**: Application performance monitoring and telemetry correlation.

**Key configuration**:
- Type: Workspace-based (unified with Log Analytics)
- Application type: Web
- Network: Public ingestion and query enabled

**Key features**:
- Automatic dependency tracking
- Distributed tracing across Logic Apps → Functions → Storage
- Exception tracking and stack traces
- Custom events and metrics

**Access Application Insights**:
- Azure Portal → Resource Group → Application Insights instance
- Or query via Log Analytics using `requests`, `dependencies`, `exceptions` tables

### 3. Storage Account (Logs)

**Purpose**: Long-term archival of diagnostic logs for compliance and auditing.

**Key configuration**:
- SKU: Standard_LRS
- Access tier: Hot
- TLS: 1.2 minimum
- Public blob access: Disabled

**Retention**: Logs are retained indefinitely in storage (manage via lifecycle policies if needed).

### 4. Diagnostic Settings

**Purpose**: Route logs and metrics from Azure resources to monitoring destinations.

**Configured on**:
- Logic Apps (WorkflowRuntime logs + AllMetrics)
- Azure Functions (HTTP/Console/App logs + AllMetrics)
- Application Insights (allLogs + AllMetrics)
- Storage Accounts (Queue service logs + AllMetrics)
- App Service Plans (AllMetrics)
- Log Analytics Workspace (self-diagnostic)

**Dual destination strategy**:
- **Log Analytics**: For real-time querying, alerting, and dashboards
- **Storage**: For long-term compliance and cost-effective archival

---

## Integration Points

### Logic Apps ↔ Application Insights

**Configuration**:

```bicep
appSettings: [
  {
    name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
    value: appInsightsInstrumentationKey
  }
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
]
```

**Result**: Workflow executions appear in Application Insights with correlation IDs.

### Logic Apps ↔ Storage Queue

**Configuration**:

```bicep
appSettings: [
  {
    name: 'AzureWebJobsStorage__accountName'
    value: workflowStorageAccountName
  }
  {
    name: 'AzureWebJobsStorage__credential'
    value: 'managedidentity'
  }
  {
    name: 'AzureWebJobsStorage__managedIdentityResourceId'
    value: managedIdentity.id
  }
]
```

**Result**: Logic Apps authenticate to storage using managed identity (no connection strings).

### Functions ↔ Application Insights

**Configuration**:

```bicep
appSettings: [
  {
    name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    value: appInsightsConnectionString
  }
  {
    name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
    value: '~3'
  }
]
```

**Result**: Function executions, HTTP requests, and dependencies appear in Application Insights.

### All Resources ↔ Log Analytics

**Configuration**: Diagnostic settings on each resource with `workspaceId` parameter.

**Result**: Unified KQL query experience across all logs and metrics in one workspace.

---

## Project Structure

```
Azure-LogicApps-Monitoring/
├── README.md                          # This file
├── LICENSE.md                         # License information
├── CODE_OF_CONDUCT.md                 # Community guidelines
├── CONTRIBUTING.md                    # Contribution guidelines
├── SECURITY.md                        # Security policies
├── azure.yaml                         # Azure Developer CLI configuration
├── host.json                          # Logic Apps host configuration
│
├── infra/                             # Infrastructure as Code (IaC)
│   ├── main.bicep                     # Subscription-level orchestrator
│   └── main.parameters.json           # Deployment parameters
│
├── src/                               # Modular Bicep templates
│   ├── monitoring/                    # Monitoring infrastructure
│   │   ├── main.bicep                 # Monitoring orchestrator
│   │   ├── log-analytics-workspace.bicep
│   │   ├── app-insights.bicep
│   │   └── azure-monitor-health-model.bicep
│   │
│   └── workload/                      # Application workload
│       ├── main.bicep                 # Workload orchestrator
│       ├── logic-app.bicep            # Logic Apps Standard
│       ├── azure-function.bicep       # Azure Functions
│       └── messaging/
│           └── main.bicep             # Storage account + queues
│
└── tax-docs/                          # Sample Logic App workflow
    ├── connections.json
    ├── host.json
    ├── local.settings.json
    ├── tax-processing/
    │   └── workflow.json
    └── workflow-designtime/
        ├── host.json
        └── local.settings.json
```

### Module Responsibilities

| Module | Purpose | Outputs |
|--------|---------|---------|
| `infra/main.bicep` | Creates resource group, orchestrates monitoring and workload | Resource group ID, workspace ID, App Insights connection string |
| `src/monitoring/main.bicep` | Deploys Log Analytics, Application Insights, storage for logs | Workspace ID, App Insights name/ID/connection string |
| `src/monitoring/log-analytics-workspace.bicep` | Deploys Log Analytics workspace + diagnostic storage | Workspace ID and name, storage account ID |
| `src/monitoring/app-insights.bicep` | Deploys Application Insights with diagnostic settings | App Insights ID, connection string, instrumentation key |
| `src/monitoring/azure-monitor-health-model.bicep` | Deploys tenant-scoped service group for health modeling | Service group ID |
| `src/workload/main.bicep` | Orchestrates Logic Apps, Functions, and messaging | Logic App ID/name, Function App ID/name |
| `src/workload/logic-app.bicep` | Deploys Logic Apps Standard with diagnostic settings | Logic App ID, App Service Plan ID |
| `src/workload/azure-function.bicep` | Deploys Azure Functions with diagnostic settings | Function App ID, default hostname |
| `src/workload/messaging/main.bicep` | Deploys storage account with queue and diagnostic settings | Storage account name and ID |

---

## Best Practices

### 1. Infrastructure as Code

- **Modular design**: Separate monitoring and workload layers for reusability
- **Parameter validation**: Use `@minLength`, `@maxLength`, `@allowed` decorators
- **Descriptive outputs**: Document all outputs with `@description` decorators
- **Idempotent deployments**: Bicep ensures safe re-deployment without resource duplication

### 2. Security

- **Managed identities**: Eliminate connection strings; use RBAC for storage access
- **TLS enforcement**: Minimum TLS 1.2 on all storage accounts and web apps
- **HTTPS-only**: Enforced on all App Services and Functions
- **Public access**: Disabled on storage accounts; enabled on endpoints only where necessary
- **Secrets management**: Use secure outputs (`@secure()`) for connection strings and keys

### 3. Cost Optimization

- **Log Analytics retention**: 30 days balances cost and compliance (adjust per requirements)
- **Storage tier**: Hot tier for frequent log access; consider Cool/Archive for long-term retention
- **Storage redundancy**: LRS for non-critical logs; consider GRS for mission-critical data
- **App Service Plans**: Right-size SKUs (WS1 for Logic Apps, P0v3 for Functions)
- **Immediate purge**: Enable `immediatePurgeDataOn30Days` to reduce storage costs

### 4. Monitoring and Alerting

- **Create alert rules**: Configure alerts on workflow failures, high latency, or resource exhaustion
- **Dashboard creation**: Build Azure Monitor dashboards for at-a-glance health visibility
- **Action groups**: Set up email, SMS, or webhook notifications for critical alerts
- **Runbook automation**: Integrate Azure Automation for auto-remediation

**Example alert rule** (KQL):

```kusto
AzureDiagnostics
| where Category == "WorkflowRuntime"
| where status_s == "Failed"
| summarize FailureCount = count() by bin(TimeGenerated, 5m)
| where FailureCount > 5
```

### 5. Tagging Strategy

All resources inherit tags from `infra/main.bicep`:

```bicep
var tags = {
  Solution: solutionName
  Environment: envName
  ManagedBy: 'Bicep'
  CostCenter: 'Engineering'
  Owner: 'Platform-Team'
  ApplicationName: 'Tax-Docs-Processing'
  BusinessUnit: 'Tax'
  DeploymentDate: deploymentDate
  Repository: 'Azure-LogicApps-Monitoring'
}
```

**Benefits**:
- Cost allocation by `CostCenter` or `BusinessUnit`
- Resource ownership tracking via `Owner`
- Deployment auditability via `DeploymentDate` and `Repository`

### 6. Multi-Environment Strategy

- **Separate parameter files**: `main.parameters.dev.json`, `main.parameters.prod.json`
- **Naming conventions**: Include `envName` in resource names for clear differentiation
- **Subscription isolation**: Consider separate subscriptions for prod vs non-prod environments
- **RBAC boundaries**: Apply stricter RBAC in production environments

---

## Troubleshooting

### Common Issues

#### Issue: Deployment fails with "Resource group already exists"

**Cause**: Re-deploying with the same parameters.

**Solution**: Bicep is idempotent—re-run the deployment. If resources changed, Bicep will update them.

```powershell
az deployment sub create --template-file infra/main.bicep --parameters infra/main.parameters.json
```

#### Issue: "Insufficient quota for App Service Plan"

**Cause**: Azure subscription quota exceeded for WorkflowStandard or Premium V3 SKU.

**Solution**: Request quota increase via Azure Portal → **Quotas** → **New support request**.

#### Issue: "Managed identity does not have permission to access storage"

**Cause**: RBAC role assignments not yet propagated (can take 1-2 minutes).

**Solution**: Wait 5 minutes and retry Logic App workflow execution.

#### Issue: "Application Insights telemetry not appearing"

**Cause**: Connection string not properly configured or Application Insights agent not started.

**Solution**:
1. Verify connection string in App Service configuration:
   ```powershell
   az webapp config appsettings list --name <logic-app-name> --resource-group <rg-name> | grep APPLICATIONINSIGHTS
   ```
2. Restart Logic App:
   ```powershell
   az logicapp restart --name <logic-app-name> --resource-group <rg-name>
   ```

#### Issue: "Diagnostic logs not appearing in Log Analytics"

**Cause**: Diagnostic settings not fully propagated (can take 5-10 minutes).

**Solution**:
1. Verify diagnostic settings exist:
   ```powershell
   az monitor diagnostic-settings list --resource <resource-id>
   ```
2. Wait 10 minutes and re-query Log Analytics:
   ```kusto
   AzureDiagnostics
   | where TimeGenerated > ago(30m)
   | summarize count() by Category
   ```

### Debugging Tips

1. **Check deployment operations**:
   ```powershell
   az deployment sub show --name <deployment-name> --query "properties.outputs"
   az deployment operation list --name <deployment-name> --subscription <subscription-id>
   ```

2. **Validate Bicep syntax**:
   ```powershell
   az bicep build --file infra/main.bicep
   ```

3. **Enable verbose logging**:
   ```powershell
   az deployment sub create --template-file infra/main.bicep --parameters infra/main.parameters.json --debug
   ```

4. **Check resource-level diagnostic settings**:
   ```powershell
   az monitor diagnostic-settings show --name <diag-name> --resource <resource-id>
   ```

---

## Contributing

We welcome contributions from the community! Please review our [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### How to Contribute

1. **Fork the repository**
2. **Create a feature branch**: `git checkout -b feature/your-feature-name`
3. **Make your changes**
4. **Validate Bicep files**: `az bicep build --file infra/main.bicep`
5. **Test deployment** in a dev environment
6. **Commit changes**: `git commit -m "Add feature: description"`
7. **Push to GitHub**: `git push origin feature/your-feature-name`
8. **Open a Pull Request**

### Contribution Ideas

- Add Azure Monitor alert rule templates
- Create sample KQL queries for common scenarios
- Implement Azure Workbooks or Dashboards
- Add support for additional Azure services (e.g., API Management, Event Grid)
- Improve documentation or add tutorials
- Add unit tests for Bicep modules

### Code of Conduct

Please adhere to our [Code of Conduct](CODE_OF_CONDUCT.md) in all interactions.

---

## License

This project is licensed under the terms specified in [LICENSE.md](LICENSE.md).

---

## Additional Resources

### Official Microsoft Documentation

- [Azure Logic Apps Standard Overview](https://learn.microsoft.com/azure/logic-apps/single-tenant-overview-compare)
- [Monitor Logic Apps](https://learn.microsoft.com/azure/logic-apps/monitor-logic-apps-log-analytics)
- [Application Insights for Logic Apps](https://learn.microsoft.com/azure/logic-apps/create-single-tenant-workflows-azure-portal#enable-application-insights)
- [Log Analytics Workspace](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview)
- [Diagnostic Settings](https://learn.microsoft.com/azure/azure-monitor/essentials/diagnostic-settings)
- [Managed Identities with Logic Apps](https://learn.microsoft.com/azure/logic-apps/authenticate-with-managed-identity)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [Azure Monitor Best Practices](https://learn.microsoft.com/azure/azure-monitor/best-practices)

### Bicep Reference

- [Microsoft.Logic/workflows](https://learn.microsoft.com/azure/templates/microsoft.logic/workflows)
- [Microsoft.Insights/components](https://learn.microsoft.com/azure/templates/microsoft.insights/components)
- [Microsoft.OperationalInsights/workspaces](https://learn.microsoft.com/azure/templates/microsoft.operationalinsights/workspaces)
- [Microsoft.Insights/diagnosticSettings](https://learn.microsoft.com/azure/templates/microsoft.insights/diagnosticsettings)

### Related Projects

- [Azure Logic Apps GitHub Repository](https://github.com/Azure/logicapps)
- [Bicep Examples](https://github.com/Azure/bicep/tree/main/docs/examples)
- [Azure Quickstart Templates](https://github.com/Azure/azure-quickstart-templates)

### Community and Support

- **Issues**: [GitHub Issues](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/discussions)
- **Microsoft Q&A**: [Azure Logic Apps Q&A](https://learn.microsoft.com/answers/tags/334/azure-logic-apps)

---

## Acknowledgments

This solution was developed to demonstrate Azure Monitor best practices for Logic Apps Standard deployments. Special thanks to the Azure Logic Apps and Azure Monitor product teams for their excellent documentation and support.

---

**Last Updated**: December 4, 2025  
**Version**: 1.0.0  
**Maintained by**: Platform Engineering Team

---

## Quick Links

- [🚀 Quick Start](#quick-start)
- [📊 Architecture](#architecture)
- [🔍 What Gets Monitored](#what-gets-monitored)
- [⚙️ Deployment](#deployment)
- [🛠️ Configuration](#configuration)
- [🤝 Contributing](#contributing)
- [📚 Documentation](#additional-resources)

---

For questions, issues, or feature requests, please [open an issue](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues) on GitHub.
