# Azure Logic Apps Monitoring

This project demonstrates Azure Monitor best practices for Logic Apps through production-ready Infrastructure as Code (IaC) templates. Built for beginner-to-intermediate developers and architects, it provides reusable Bicep modules that deploy Logic Apps with integrated observability, health tracking, and security best practices using Azure Monitor, Application Insights, and Log Analytics.

---

## Badges

![Build Status](https://img.shields.io/badge/build-passing-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)
![Contributions](https://img.shields.io/badge/contributions-welcome-orange)

---

## Prerequisites

- **Azure Subscription**: Active subscription with Contributor or Owner access
- **Azure Developer CLI (azd)**: Version 1.0.0 or higher ([Installation Guide](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd))
- **Azure CLI**: Version 2.50.0 or higher ([Installation Guide](https://learn.microsoft.com/cli/azure/install-azure-cli))
- **Bicep CLI**: Version 0.23.0 or higher (installed with Azure CLI)
- **Permissions**: Ability to create resource groups and assign RBAC (Role-Based Access Control) roles
- **Knowledge**: Basic understanding of Azure Logic Apps, Azure Monitor, and Infrastructure as Code

---

## File Structure

```
Azure-LogicApps-Monitoring/
├── .azure/                          # Azure Developer CLI environments
│   ├── config.json                  # Global azd configuration
│   ├── dev/                         # Development environment
│   ├── prod/                        # Production environment
│   └── uat/                         # UAT environment
├── infra/                           # Infrastructure as Code
│   ├── main.bicep                   # Subscription-level orchestrator
│   └── main.parameters.json         # Deployment parameters
├── src/                             # Bicep modules
│   ├── logic-app.bicep              # Logic App + dashboards
│   ├── monitoring/                  # Monitoring infrastructure
│   │   ├── main.bicep               # Monitoring orchestrator
│   │   ├── app-insights.bicep       # Application Insights
│   │   ├── azure-monitor-health-model.bicep  # Health model
│   │   └── log-analytics-workspace.bicep     # Log Analytics
│   └── shared/                      # Shared resources
│       ├── main.bicep               # Shared orchestrator
│       ├── data/                    # Storage infrastructure
│       │   └── main.bicep           # Storage account + RBAC
│       └── messaging/               # Messaging infrastructure
│           └── main.bicep           # Service Bus (In Development)
├── tax-docs/                        # Sample Logic App workflow
│   └── tax-approval/                # Tax document approval workflow
├── azure.yaml                       # Azure Developer CLI project
├── host.json                        # Functions runtime configuration
├── CODE_OF_CONDUCT.md               # Community guidelines
├── CONTRIBUTING.md                  # Contribution guidelines
├── LICENSE.md                       # MIT License
├── README.md                        # This file
└── SECURITY.md                      # Security policies
```

---

## Architecture

### System Architecture

```mermaid
flowchart TB
    subgraph Subscription["Azure Subscription"]
        subgraph RG["Resource Group: {resourceGroupName}"]
            subgraph MonitoringStack["Monitoring & Observability"]
                LAW["Log Analytics Workspace<br/>30-day retention<br/>PerGB2018 pricing"]
                AI["Application Insights<br/>Workspace-based<br/>Connection string injection"]
                HM["Azure Monitor Health Model<br/>Service Groups<br/>Tenant-level hierarchy"]
            end
            
            subgraph ComputeLayer["Compute Resources"]
                ASP["App Service Plan<br/>WS1 SKU<br/>Elastic scale: 1-20 workers"]
                LA["Logic App<br/>Standard tier<br/>Workflow App<br/>System-assigned identity"]
            end
            
            subgraph DataLayer["Data & Storage"]
                SA["Storage Account<br/>Standard_LRS<br/>Hot tier<br/>HTTPS-only"]
            end
            
            subgraph IdentityLayer["Identity & Access"]
                UMI["User-Assigned<br/>Managed Identity<br/>RBAC: 4 storage roles<br/>+ 1 monitoring role"]
            end
            
            subgraph DashboardLayer["Visualization"]
                DASH1["Service Plan Dashboard<br/>CPU, Memory, Data I/O<br/>HTTP Queue, Workers"]
                DASH2["Workflow Dashboard<br/>Runs, Failures, Duration<br/>Triggers, Action metrics"]
            end
            
            subgraph MessagingLayer["Messaging (In Development)"]
                SB["Service Bus Namespace<br/>Standard tier<br/>Local auth disabled"]
            end
        end
    end
    
    UMI -->|Storage Blob Data Owner| SA
    UMI -->|Storage Queue/Table Data Contributor| SA
    UMI -->|Storage File Data Privileged Contributor| SA
    UMI -->|Monitoring Metrics Publisher| AI
    
    LA -->|Hosted on| ASP
    LA -->|Identity| UMI
    LA -->|State/Data| SA
    LA -->|Diagnostic Settings:<br/>WorkflowRuntime logs| LAW
    LA -->|Telemetry:<br/>APPLICATIONINSIGHTS_CONNECTION_STRING| AI
    
    AI -->|Workspace Integration| LAW
    ASP -->|Platform Metrics| LAW
    HM -->|Health Monitoring| LAW
    
    LAW -->|Data Source| DASH1
    LAW -->|Data Source| DASH2
    
    SB -.->|Future: Managed Identity Auth| LA
    
    style MonitoringStack fill:#1E3A8A,stroke:#3B82F6,stroke-width:2px,color:#FFFFFF
    style ComputeLayer fill:#065F46,stroke:#10B981,stroke-width:2px,color:#FFFFFF
    style DataLayer fill:#7C2D12,stroke:#F97316,stroke-width:2px,color:#FFFFFF
    style IdentityLayer fill:#4C1D95,stroke:#A78BFA,stroke-width:2px,color:#FFFFFF
    style DashboardLayer fill:#831843,stroke:#EC4899,stroke-width:2px,color:#FFFFFF
    style MessagingLayer fill:#374151,stroke:#9CA3AF,stroke-width:2px,stroke-dasharray: 5 5,color:#FFFFFF
    style RG fill:#1F2937,stroke:#6B7280,stroke-width:1px,color:#FFFFFF
```

### Data Flow

```mermaid
sequenceDiagram
    participant User
    participant Portal as Azure Portal<br/>Dashboard
    participant LA as Logic App<br/>(Workflow)
    participant SA as Storage Account
    participant AI as Application<br/>Insights
    participant LAW as Log Analytics<br/>Workspace
    participant SB as Service Bus<br/>(Future)
    
    rect rgba(59, 130, 246, 0.1)
        Note over User,Portal: 1. Monitoring & Visualization
        User->>Portal: View Dashboard
        Portal->>LAW: Query Metrics (KQL)
        LAW-->>Portal: Return Data<br/>(CPU, Memory, Runs)
        Portal-->>User: Display Charts
    end
    
    rect rgba(16, 185, 129, 0.1)
        Note over User,LA: 2. Workflow Execution
        User->>LA: Trigger Workflow<br/>(HTTP, Timer, Event)
        activate LA
        
        LA->>SA: Read/Write Data<br/>(Blobs, Queues, Tables, Files)
        SA-->>LA: Data Response
        
        alt Future: Service Bus Integration
            LA-.->SB: Send/Receive Messages<br/>(Managed Identity Auth)
            SB-.->LA: Message Response
        end
    end
    
    rect rgba(167, 139, 250, 0.1)
        Note over LA,LAW: 3. Telemetry & Logging
        LA->>AI: Send Telemetry<br/>(Connection String:<br/>APPLICATIONINSIGHTS_CONNECTION_STRING)
        LA->>LAW: Stream Logs<br/>(Diagnostic Settings:<br/>WorkflowRuntime category)
        
        AI->>LAW: Forward Telemetry<br/>(Workspace Integration)
    end
    
    rect rgba(236, 72, 153, 0.1)
        Note over LA,User: 4. Workflow Completion
        LA->>LA: Execute Actions
        
        alt Success
            LA-->>User: 200 OK Response
            LA->>LAW: Success Metrics
        else Failure
            LA-->>User: Error Response<br/>(4xx/5xx)
            LA->>LAW: Failure Logs
            LA->>AI: Exception Telemetry
        end
        
        deactivate LA
    end
    
    Note over Portal: Dashboard Auto-refresh:<br/>24-hour window<br/>1-minute granularity
```

### Key Components

| Component | Description | Purpose | Key Features |
|-----------|-------------|---------|--------------|
| **Logic App (Workflow App)** | Standard-tier Logic App hosted on App Service Plan | Execute business workflows with observability | WorkflowRuntime logging, system-assigned identity, App Insights connection string injection |
| **App Service Plan (WS1)** | Workflow Standard SKU with elastic scaling | Provide dedicated compute for Logic App | Elastic scale (1-20 workers), zone-redundancy capable, per-instance monitoring |
| **Application Insights** | APM (Application Performance Management) service | Collect telemetry, traces, and exceptions | Workspace-based resource, instrumentation key, diagnostic settings integration |
| **Log Analytics Workspace** | Centralized log aggregation and analytics | Store and query logs across all resources | 30-day retention, PerGB2018 pricing, system-assigned identity, KQL query engine |
| **Azure Monitor Health Model** | Hierarchical service group structure | Organize monitoring resources into logical groups | Tenant-level service groups, parent-child relationships, health rollup |
| **Storage Account** | Standard LRS, Hot tier storage | Provide durable storage for Logic App state and data | HTTPS-only, managed identity RBAC (4 roles), unique naming with `uniqueString()` |
| **User-Assigned Managed Identity** | Azure AD identity for the workload | Enable credential-free access to Azure resources | RBAC assignments to Storage (4 roles) and Monitoring (1 role) |
| **Azure Portal Dashboards** | Pre-configured metric visualizations | Provide operational visibility for infrastructure and workflows | 2 dashboards: Service Plan metrics (CPU, memory, I/O) + Workflow metrics (runs, failures, latency) |
| **Service Bus Namespace (In Development)** | Standard-tier messaging service | Enable reliable message-based integration | Local auth disabled, managed identity authentication, SAS-free access |

### RBAC Roles

| Role Name | Description | Documentation Link |
|-----------|-------------|-------------------|
| **Storage Blob Data Owner** | Full access to Azure Storage blob containers and data including ACL management | [Microsoft Learn](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-blob-data-owner) |
| **Storage Queue Data Contributor** | Read, write, and delete Azure Storage queues and queue messages | [Microsoft Learn](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-queue-data-contributor) |
| **Storage Table Data Contributor** | Read, write, and delete Azure Storage tables and table entities | [Microsoft Learn](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-table-data-contributor) |
| **Storage File Data Privileged Contributor** | Full access to Azure Storage file shares over SMB and REST with elevated privileges | [Microsoft Learn](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#storage-file-data-privileged-contributor) |
| **Monitoring Metrics Publisher** | Enable publishing metrics against Azure resources | [Microsoft Learn](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles#monitoring-metrics-publisher) |

---

## Features

### Comprehensive Monitoring

This solution implements end-to-end observability for Logic Apps using Azure Monitor, Application Insights, and Log Analytics. All resources deploy with diagnostic settings preconfigured to capture logs and metrics, eliminating manual post-deployment configuration and ensuring consistent monitoring across environments.

**Benefits & Best Practices Applied**:
- **Centralized Logging**: All logs stream to a single Log Analytics Workspace for unified querying via KQL (Kusto Query Language)
- **Automatic Retention Management**: 30-day retention with immediate purge after expiration reduces storage costs while meeting compliance requirements
- **Workspace-Based Application Insights**: Modern workspace-based model enables cross-resource correlation and unified query interface
- **Diagnostic Settings at Deployment**: Configured via Bicep templates—no manual Azure Portal configuration required

| Feature | Description | Implementation | Documentation |
|---------|-------------|----------------|---------------|
| **WorkflowRuntime Logs** | Capture detailed execution logs for workflow runs, actions, and triggers | Diagnostic settings on Logic App resource with `WorkflowRuntime` category | [Monitor Logic Apps](https://learn.microsoft.com/azure/logic-apps/monitor-logic-apps-log-analytics) |
| **Application Insights Integration** | Distributed tracing, dependency tracking, and performance monitoring | Connection string injected via `APPLICATIONINSIGHTS_CONNECTION_STRING` app setting | [Application Insights Overview](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview) |
| **Log Analytics Workspace** | Centralized log storage with KQL query engine for analysis | PerGB2018 pricing tier, 30-day retention, system-assigned managed identity | [Log Analytics Workspace](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview) |
| **Health Model Service Groups** | Hierarchical organization of monitoring resources | Tenant-level service groups linked to root service group for health rollup | [Service Groups Overview](https://learn.microsoft.com/azure/azure-monitor/service-groups/overview) |

---

### Metrics & Telemetry

Pre-configured Azure Portal dashboards provide real-time visibility into infrastructure health and workflow performance. Two dashboards capture 15+ metrics across CPU, memory, network, and workflow execution, enabling proactive issue detection and capacity planning without custom tooling.

**Benefits & Best Practices Applied**:
- **Proactive Monitoring**: Failure rate and latency metrics enable early issue detection before user impact
- **Resource Optimization**: CPU and memory trends inform scaling decisions and cost optimization strategies
- **24-Hour Default Window**: Dashboards focus on operational timeframes with auto-refresh for real-time insights
- **Automatic Time Granularity**: Azure adjusts chart granularity (1-min, 5-min, 1-hour) based on time window for optimal visualization

| Feature | Description | Metrics Captured | Dashboard Location |
|---------|-------------|------------------|-------------------|
| **Service Plan Metrics Dashboard** | Monitor App Service Plan infrastructure health and capacity utilization | CPU Percentage, Memory Percentage, Data In/Out, HTTP Queue Length, App Service Plan Workers | [src/logic-app.bicep](src/logic-app.bicep) (lines 56-301) |
| **Workflow Execution Dashboard** | Track Logic App run success, failures, latency, and throughput | Actions Failure Rate, Job Execution Duration, Runs Completed, Runs Dispatched, Runs Failure Rate, Runs Started, Triggers Completed, Triggers Failure Rate, Triggers Fired | [src/logic-app.bicep](src/logic-app.bicep) (lines 416-715) |
| **AllMetrics Collection** | Stream all available platform metrics to Log Analytics Workspace | CPU, memory, network, storage, workflow metrics (20+ total metrics) | Diagnostic settings in [src/logic-app.bicep](src/logic-app.bicep) (lines 31-54) |
| **Monitoring Metrics Publisher** | Enable managed identity to publish custom metrics to Azure Monitor | Custom application metrics via RBAC-based access | [src/monitoring/app-insights.bicep](src/monitoring/app-insights.bicep) (lines 51-59) |

---

### Security & Compliance

This solution follows Azure security best practices with managed identities, RBAC-based access control, and encryption by default. No credentials are stored in code or configuration files, and all resources enforce HTTPS-only communication with TLS 1.2+ for data in transit.

**Benefits & Best Practices Applied**:
- **Credential-Free Authentication**: Managed identities eliminate secrets management, credential rotation, and exposure risks
- **Least Privilege Access**: RBAC roles grant only necessary permissions for specific resource interactions (no wildcard permissions)
- **Encryption by Default**: HTTPS-only storage, TLS 1.2+ for connections, encryption at rest enabled automatically
- **Audit Trail**: All access logged in Azure Activity Log for compliance audits and security investigations

| Feature | Description | Security Mechanism | Implementation |
|---------|-------------|-------------------|----------------|
| **User-Assigned Managed Identity** | Credential-free authentication for Logic App to access Azure resources | Azure AD-based authentication via managed identity token exchange | [src/shared/main.bicep](src/shared/main.bicep) (lines 10-14) |
| **RBAC Role Assignments** | Granular, least-privilege access control to storage and monitoring services | 4 storage roles (Blob, Queue, Table, File) + 1 monitoring role at resource scope | [src/shared/data/main.bicep](src/shared/data/main.bicep) (lines 40-80) |
| **HTTPS-Only Storage** | Enforce encrypted communication for all storage operations | `supportsHttpsTrafficOnly: true` property on storage account | [src/shared/data/main.bicep](src/shared/data/main.bicep) (line 24) |
| **System-Assigned Identity for Logs** | Secure data access for Log Analytics Workspace operations | System-assigned managed identity on Log Analytics Workspace | [src/monitoring/log-analytics-workspace.bicep](src/monitoring/log-analytics-workspace.bicep) (lines 11-13) |
| **Local Auth Disabled (Service Bus)** | Block connection string/SAS authentication on Service Bus namespace | `disableLocalAuth: true` enforces Azure AD authentication only | [src/shared/messaging/main.bicep](src/shared/messaging/main.bicep) (line 24) |

---

### Infrastructure as Code

All resources deploy via modular Azure Bicep templates using a subscription-level orchestrator pattern. This solution demonstrates IaC best practices with parameterization, consistent tagging, deterministic naming, and explicit dependency management for reliable, repeatable deployments across environments.

**Benefits & Best Practices Applied**:
- **Modular Architecture**: Separate modules for monitoring, storage, compute, and messaging enable independent updates and testing
- **Consistent Tagging**: All resources tagged with 7 standard tags for cost tracking, organization, and automated governance
- **Deterministic Naming**: `uniqueString()` function ensures reproducible, globally unique resource names without manual input
- **Explicit Dependencies**: `dependsOn` clauses prevent race conditions and ensure correct resource provisioning order

| Feature | Description | Implementation | Files |
|---------|-------------|----------------|-------|
| **Modular Bicep Templates** | Reusable, composable infrastructure modules with clear separation of concerns | 8 Bicep modules organized by resource category (monitoring, shared, logic-app) | [infra/main.bicep](infra/main.bicep), [src/shared/main.bicep](src/shared/main.bicep), [src/monitoring/main.bicep](src/monitoring/main.bicep) |
| **Azure Developer CLI Support** | Simplified multi-environment deployment workflow with `azd` commands | `azure.yaml` project definition with 3 environments (dev, uat, prod) | [azure.yaml](azure.yaml) |
| **Parameterization** | Environment-specific configuration without code changes | `main.parameters.json` with token replacement for resource names, SKUs, and tags | [infra/main.parameters.json](infra/main.parameters.json) |
| **Resource Tagging Strategy** | Consistent metadata across all resources for governance and cost management | 7 standard tags: Solution, Environment, Owner, Repository, DeploymentDate, ManagedBy, CostCenter | Applied in [infra/main.bicep](infra/main.bicep) (lines 15-21) |

---

## Installation & Setup

### Step 1: Clone Repository

Clone this repository to your local machine using Git.

```bash
git clone https://github.com/your-org/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

**Expected Output**: Repository files downloaded to current directory.

---

### Step 2: Login to Azure

Authenticate the Azure Developer CLI with your Azure account.

```bash
azd auth login
```

**Expected Output**: Browser opens for Azure authentication. After successful login, you'll see: `Logged in to Azure.`

---

### Step 3: Initialize Environment

Initialize a new `azd` environment or select an existing one (dev, uat, prod).

```bash
azd init
```

**Expected Output**: Prompts for environment name (e.g., `dev`). If `.azure/dev/.env` already exists, this step will use existing configuration.

---

### Step 4: Provision Infrastructure

Deploy all Azure resources defined in the Bicep templates.

```bash
azd provision
```

**Expected Output**:
```
Provisioning Azure resources (azd provision)
Subscription: <Your Subscription Name> (<subscription-id>)
Location: East US

Provisioning resources...
  (✓) Done: Resource group: contoso-tax-docs-dev-rg
  (✓) Done: Log Analytics Workspace: contoso-tax-docs-dev-law
  (✓) Done: Application Insights: contoso-tax-docs-dev-ai
  (✓) Done: Storage Account: contosotaxdocsdevst
  (✓) Done: App Service Plan: contoso-tax-docs-dev-asp
  (✓) Done: Logic App: contoso-tax-docs-dev-la
  (✓) Done: Dashboards: Service Plan + Workflow Metrics

SUCCESS: Your application was provisioned in Azure in X minutes Y seconds.
```

**Note**: Initial deployment takes 3-5 minutes. Subsequent deployments are faster due to incremental updates.

---

## Usage Examples

### A. Viewing Dashboards

#### Azure Portal Navigation

1. Navigate to the [Azure Portal](https://portal.azure.com)
2. In the left menu, select **Dashboard** or search for **"Dashboards"** in the top search bar
3. Click **Browse all dashboards**
4. Filter dashboards by your resource group name (e.g., `contoso-tax-docs-dev-rg`)
5. Open the **Service Plan Metrics** dashboard to view CPU, memory, and I/O metrics
6. Open the **Workflow Metrics** dashboard to view run success/failure rates and latency

#### CLI Command to Open Dashboard

Use the Azure CLI to open a specific dashboard in your browser:

```bash
# List all dashboards in the resource group
az portal dashboard list \
  --resource-group contoso-tax-docs-dev-rg \
  --output table

# Open the Service Plan Metrics dashboard in browser
az portal dashboard show \
  --resource-group contoso-tax-docs-dev-rg \
  --name "contoso-tax-docs-dev-service-plan-dashboard" \
  --query "id" \
  --output tsv | xargs -I {} open "https://portal.azure.com/#@/resource{}/overview"
```

**Expected Output**: Browser opens to the selected dashboard in Azure Portal.

---

### B. Log Analytics Queries

Use these KQL (Kusto Query Language) queries in Log Analytics Workspace to monitor Logic App performance and troubleshoot issues.

#### 1. Track Workflow Run Success and Failure Rates

Query all workflow runs with their status, duration, and trigger information over the past 24 hours.

```kql
// Workflow run success and failure tracking
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where ResourceType == "WORKFLOWS"
| where Category == "WorkflowRuntime"
| where OperationName == "Microsoft.Logic/workflows/workflowRunCompleted"
| project 
    TimeGenerated,
    WorkflowName = resource_workflowName_s,
    RunId = resource_runId_s,
    Status = status_s,
    DurationMs = duration_d,
    TriggerName = resource_triggerName_s,
    ErrorCode = error_code_s,
    ErrorMessage = error_message_s
| order by TimeGenerated desc
| summarize 
    TotalRuns = count(),
    SuccessfulRuns = countif(Status == "Succeeded"),
    FailedRuns = countif(Status == "Failed"),
    AvgDurationMs = avg(DurationMs)
    by WorkflowName
| extend SuccessRate = round(100.0 * SuccessfulRuns / TotalRuns, 2)
| order by FailedRuns desc
```

**Use Case**: Identify workflows with high failure rates or long execution times. This query summarizes run statistics per workflow, enabling quick identification of problematic workflows.

---

#### 2. Analyze Action-Level Failures

Query failed actions within workflows to pinpoint specific steps causing errors.

```kql
// Action-level failure analysis
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where ResourceType == "WORKFLOWS"
| where Category == "WorkflowRuntime"
| where OperationName == "Microsoft.Logic/workflows/workflowActionCompleted"
| where status_s == "Failed"
| project 
    TimeGenerated,
    WorkflowName = resource_workflowName_s,
    RunId = resource_runId_s,
    ActionName = resource_actionName_s,
    ErrorCode = error_code_s,
    ErrorMessage = error_message_s,
    DurationMs = duration_d
| order by TimeGenerated desc
| take 50
```

**Use Case**: Troubleshoot specific action failures. This query lists the 50 most recent failed actions with error details, helping identify integration issues or configuration errors.

---

#### 3. Monitor Trigger Performance

Track trigger execution patterns and identify performance bottlenecks or misfires.

```kql
// Trigger performance monitoring
AzureDiagnostics
| where TimeGenerated > ago(7d)
| where ResourceType == "WORKFLOWS"
| where Category == "WorkflowRuntime"
| where OperationName == "Microsoft.Logic/workflows/workflowTriggerCompleted"
| project 
    TimeGenerated,
    WorkflowName = resource_workflowName_s,
    TriggerName = resource_triggerName_s,
    Status = status_s,
    DurationMs = duration_d
| summarize 
    TriggerCount = count(),
    SuccessfulTriggers = countif(Status == "Succeeded"),
    AvgDurationMs = avg(DurationMs),
    MaxDurationMs = max(DurationMs)
    by WorkflowName, TriggerName, bin(TimeGenerated, 1h)
| order by TimeGenerated desc
```

**Use Case**: Analyze trigger patterns over time. This query aggregates trigger executions by hour, revealing trends in trigger frequency and performance degradation.

---

#### 4. Track Performance Metrics (CPU, Memory, HTTP Queue)

Query App Service Plan metrics to monitor infrastructure health and identify capacity issues.

```kql
// App Service Plan performance metrics
AzureMetrics
| where TimeGenerated > ago(24h)
| where ResourceProvider == "MICROSOFT.WEB"
| where ResourceId contains "serverfarms"
| where MetricName in ("CpuPercentage", "MemoryPercentage", "HttpQueueLength")
| project 
    TimeGenerated,
    MetricName,
    Average,
    Maximum,
    Minimum
| order by TimeGenerated desc
| render timechart
```

**Use Case**: Identify infrastructure bottlenecks. This query visualizes CPU, memory, and HTTP queue length over time, helping determine if scaling is required.

---

#### 5. Correlate Logic App Runs with Application Insights Traces

Join workflow run data with Application Insights distributed traces for end-to-end observability.

```kql
// Correlate Logic App runs with App Insights traces
let WorkflowRuns = AzureDiagnostics
| where TimeGenerated > ago(24h)
| where ResourceType == "WORKFLOWS"
| where Category == "WorkflowRuntime"
| where OperationName == "Microsoft.Logic/workflows/workflowRunCompleted"
| project TimeGenerated, WorkflowName = resource_workflowName_s, RunId = resource_runId_s, Status = status_s;
let AppInsightsTraces = traces
| where timestamp > ago(24h)
| where cloud_RoleName contains "logic-app"
| project timestamp, message, severityLevel, operation_Id;
WorkflowRuns
| join kind=inner (
    AppInsightsTraces
) on $left.RunId == $right.operation_Id
| project TimeGenerated, WorkflowName, RunId, Status, message, severityLevel
| order by TimeGenerated desc
| take 100
```

**Use Case**: Debug complex workflow issues by correlating workflow run status with Application Insights traces, exceptions, and dependency calls.

---

## Additional Resources

- **Azure Logic Apps Documentation**: [https://learn.microsoft.com/azure/logic-apps/](https://learn.microsoft.com/azure/logic-apps/)
- **Monitor Logic Apps with Azure Monitor**: [https://learn.microsoft.com/azure/logic-apps/monitor-logic-apps-log-analytics](https://learn.microsoft.com/azure/logic-apps/monitor-logic-apps-log-analytics)
- **Azure Monitor Best Practices**: [https://learn.microsoft.com/azure/azure-monitor/best-practices](https://learn.microsoft.com/azure/azure-monitor/best-practices)
- **Bicep Documentation**: [https://learn.microsoft.com/azure/azure-resource-manager/bicep/](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- **Azure Developer CLI (azd)**: [https://learn.microsoft.com/azure/developer/azure-developer-cli/](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- **Log Analytics Workspace Overview**: [https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-workspace-overview)
- **Application Insights Overview**: [https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)
- **Azure RBAC Built-in Roles**: [https://learn.microsoft.com/azure/role-based-access-control/built-in-roles](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles)
- **KQL Quick Reference**: [https://learn.microsoft.com/azure/data-explorer/kql-quick-reference](https://learn.microsoft.com/azure/data-explorer/kql-quick-reference)
- **Azure Monitor Service Groups**: [https://learn.microsoft.com/azure/azure-monitor/service-groups/overview](https://learn.microsoft.com/azure/azure-monitor/service-groups/overview)