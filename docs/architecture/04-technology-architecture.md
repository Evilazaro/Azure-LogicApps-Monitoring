# Technology Architecture

← [Application Architecture](03-application-architecture.md) | [Index](README.md) | [Observability Architecture →](05-observability-architecture.md)

---

## 1. Technology Architecture Overview

The technology architecture leverages Azure PaaS services deployed via Infrastructure as Code (Bicep) at **subscription scope**. The modular template structure separates shared infrastructure (identity, monitoring, data) from workload-specific resources (messaging, compute, Logic Apps).

### Design Principles

| Principle | Implementation | Rationale |
|-----------|----------------|-----------|
| **Infrastructure as Code** | Bicep templates | Repeatability, version control |
| **Subscription-Scope Deployment** | Creates resource group | Single deployment entry point |
| **Modular Templates** | shared/, workload/ folders | Separation of concerns |
| **Managed Identity** | User-assigned identity | No secrets management |
| **Cost Optimization** | Basic SKUs, consumption tiers | Development workload |

---

## 2. Azure Resource Topology

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontSize': '14px'}}}%%
flowchart TB
    subgraph Subscription["📋 Azure Subscription"]
        subgraph RG["🗂️ Resource Group: rg-${AZURE_ENV_NAME}"]
            
            subgraph Identity["🔐 Identity"]
                MI["User-Assigned<br/>Managed Identity"]
            end

            subgraph Monitoring["📊 Monitoring"]
                LAW["Log Analytics<br/>Workspace"]
                AI["Application<br/>Insights"]
            end

            subgraph Data["💾 Data Tier"]
                SQL[("Azure SQL<br/>Database")]
                Storage["Azure Storage<br/>Account"]
            end

            subgraph Messaging["📨 Messaging"]
                SB["Service Bus<br/>Namespace (Basic)"]
                Topic["ordersplaced<br/>Topic"]
                Sub["orderprocessingsub<br/>Subscription"]
            end

            subgraph Compute["⚡ Compute"]
                ACR["Azure Container<br/>Registry"]
                CAE["Container Apps<br/>Environment"]
                API["Orders API<br/>Container App"]
                Web["Web App<br/>Container App"]
                LA["Logic Apps<br/>Standard"]
            end
        end
    end

    %% Identity relationships
    MI -->|"Authenticates"| SQL
    MI -->|"Authenticates"| SB
    MI -->|"Authenticates"| Storage
    MI -->|"Authenticates"| AI

    %% Monitoring relationships
    API -.->|"Telemetry"| AI
    Web -.->|"Telemetry"| AI
    LA -.->|"Diagnostics"| LAW
    AI -->|"Stores in"| LAW

    %% Data relationships
    API -->|"TDS"| SQL
    LA -->|"Blob"| Storage

    %% Messaging relationships
    API -->|"AMQP"| Topic
    Topic --> Sub
    Sub -->|"Triggers"| LA

    %% Compute relationships
    ACR -.->|"Images"| API
    ACR -.->|"Images"| Web
    CAE -->|"Hosts"| API
    CAE -->|"Hosts"| Web

    %% Accessible color palette with clear resource grouping
    classDef identity fill:#e8eaf6,stroke:#3f51b5,stroke-width:2px,color:#1a237e
    classDef monitoring fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1
    classDef data fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#1b5e20
    classDef messaging fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#bf360c
    classDef compute fill:#fce4ec,stroke:#c2185b,stroke-width:2px,color:#880e4f

    class MI identity
    class LAW,AI monitoring
    class SQL,Storage data
    class SB,Topic,Sub messaging
    class ACR,CAE,API,Web,LA compute
```

---

## 3. Resource Inventory

### Shared Infrastructure

| Resource | Type | SKU/Tier | Purpose | Bicep Module |
|----------|------|----------|---------|--------------|
| **User-Assigned Identity** | Managed Identity | N/A | Service authentication | `shared/identity/` |
| **Log Analytics Workspace** | Log Analytics | PerGB2018 | Central log storage | `shared/monitoring/` |
| **Application Insights** | Application Insights | Web | APM and telemetry | `shared/monitoring/` |
| **Azure SQL Server** | SQL Server | N/A | Database server | `shared/data/` |
| **Azure SQL Database** | SQL Database | Basic | Order data | `shared/data/` |
| **Storage Account** | Storage v2 | Standard_LRS | Logic App state, blobs | `shared/data/` |

### Workload Infrastructure

| Resource | Type | SKU/Tier | Purpose | Bicep Module |
|----------|------|----------|---------|--------------|
| **Service Bus Namespace** | Service Bus | Basic | Event messaging | `workload/messaging/` |
| **Service Bus Topic** | Topic | N/A | Order events pub/sub | `workload/messaging/` |
| **Topic Subscription** | Subscription | N/A | Logic App trigger | `workload/messaging/` |
| **Container Registry** | ACR | Basic | Docker images | `workload/services/` |
| **Container Apps Environment** | ACA Environment | Consumption | Compute platform | `workload/services/` |
| **Orders API** | Container App | Consumption | REST API | `workload/services/` |
| **Web App** | Container App | Consumption | Blazor frontend | `workload/services/` |
| **Logic App Standard** | Logic Apps | WS1 | Workflow automation | `workload/logic-app.bicep` |

---

## 4. Infrastructure as Code Structure

### Bicep Module Hierarchy

```
infra/
├── main.bicep                    # Root orchestrator (subscription scope)
├── main.parameters.json          # Environment parameters
├── types.bicep                   # Custom type definitions
├── shared/
│   ├── main.bicep               # Shared resources module
│   ├── identity/
│   │   └── main.bicep           # Managed identity module
│   ├── monitoring/
│   │   └── main.bicep           # Log Analytics + App Insights
│   └── data/
│       └── main.bicep           # SQL + Storage module
└── workload/
    ├── main.bicep               # Workload resources module
    ├── logic-app.bicep          # Logic App deployment
    ├── messaging/
    │   └── main.bicep           # Service Bus module
    └── services/
        └── main.bicep           # Container Apps module
```

### Module Deployment Flow

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontSize': '14px'}}}%%
flowchart TB
    subgraph Root["🎯 main.bicep (subscription scope)"]
        Params["Parameters<br/>AZURE_ENV_NAME, AZURE_LOCATION"]
        RG["Create Resource Group<br/>rg-\${AZURE_ENV_NAME}"]
    end

    subgraph Shared["📦 shared/main.bicep"]
        Identity["🔐 identity/main.bicep<br/>User-Assigned Identity"]
        Monitoring["📊 monitoring/main.bicep<br/>LAW + App Insights"]
        Data["💾 data/main.bicep<br/>SQL + Storage"]
    end

    subgraph Workload["⚡ workload/main.bicep"]
        Messaging["📨 messaging/main.bicep<br/>Service Bus"]
        Services["🐳 services/main.bicep<br/>ACR + Container Apps"]
        LogicApp["🔄 logic-app.bicep<br/>Logic Apps Standard"]
    end

    Params --> RG
    RG --> Shared
    Shared --> Identity
    Identity --> Monitoring
    Monitoring --> Data
    
    Shared --> Workload
    Data --> Messaging
    Messaging --> Services
    Services --> LogicApp

    %% Accessible color palette with clear deployment phases
    classDef root fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1
    classDef shared fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#1b5e20
    classDef workload fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#bf360c

    class Params,RG root
    class Identity,Monitoring,Data shared
    class Messaging,Services,LogicApp workload
```

---

## 5. Key Bicep Module Details

### Root Module - main.bicep

**Location:** [infra/main.bicep](../../infra/main.bicep)

**Scope:** Subscription  
**Purpose:** Creates resource group and orchestrates all module deployments

```bicep
// Key structure from main.bicep
targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment')
param name string

// Creates resource group
resource rg 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-${name}'
  location: location
}

// Deploys shared infrastructure
module shared 'shared/main.bicep' = { ... }

// Deploys workload infrastructure
module workload 'workload/main.bicep' = { ... }
```

### Monitoring Module

**Location:** [infra/shared/monitoring/main.bicep](../../infra/shared/monitoring/main.bicep)

```bicep
// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// Application Insights with workspace-based logs
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${abbrs.insightsComponents}${resourceToken}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}
```

### Logic App Module

**Location:** [infra/workload/logic-app.bicep](../../infra/workload/logic-app.bicep)

```bicep
// Logic App Standard (WS1 Plan)
resource logicApp 'Microsoft.Web/sites@2023-12-01' = {
  name: logicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${managedIdentityId}': {} }
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        { name: 'AzureWebJobsStorage', value: storageConnectionString }
        { name: 'FUNCTIONS_WORKER_RUNTIME', value: 'node' }
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '~18' }
        { name: 'serviceBus_connectionString', value: serviceBusConnectionString }
        // Application Insights integration
        { name: 'APPINSIGHTS_INSTRUMENTATIONKEY', value: appInsightsInstrumentationKey }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
      ]
    }
  }
}
```

---

## 6. Azure Developer CLI Configuration

### azure.yaml Structure

**Location:** [azure.yaml](../../azure.yaml)

```yaml
name: app
metadata:
  template: azd-init@1.11.0
hooks:
  preprovision:
    windows:
      shell: pwsh
      run: ./hooks/preprovision.ps1
    posix:
      shell: sh
      run: ./hooks/preprovision.sh
  postprovision:
    windows:
      shell: pwsh
      run: ./hooks/postprovision.ps1
    posix:
      shell: sh
      run: ./hooks/postprovision.sh
services:
  orders-api:
    project: ./src/eShop.Orders.API
    language: dotnet
    host: containerapp
  web-app:
    project: ./src/eShop.Web.App
    language: dotnet
    host: containerapp
```

### azd Lifecycle Hooks

| Hook | Script | Purpose |
|------|--------|---------|
| **preprovision** | `hooks/preprovision.ps1` | Validate prerequisites, clean secrets |
| **postprovision** | `hooks/postprovision.ps1` | Configure .NET user secrets |

---

## 7. Container Apps Configuration

### Container Apps Environment

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontSize': '14px'}}}%%
flowchart TB
    subgraph CAE["Container Apps Environment"]
        subgraph API["orders-api"]
            direction TB
            API_Container["Container<br/>eShop.Orders.API"]
            API_Ingress["Ingress<br/>Port 5001"]
        end
        
        subgraph Web["web-app"]
            direction TB
            Web_Container["Container<br/>eShop.Web.App"]
            Web_Ingress["Ingress<br/>Port 5002"]
        end
    end

    subgraph External["External Resources"]
        ACR["Azure Container Registry"]
        AI["App Insights"]
        VNet["Virtual Network"]
    end

    ACR -->|"Pull Images"| API_Container
    ACR -->|"Pull Images"| Web_Container
    API_Container -.->|"OTLP"| AI
    Web_Container -.->|"OTLP"| AI
    CAE -->|"Integrated"| VNet

    %% Accessible color palette
    classDef container fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1
    classDef external fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#4a148c

    class API_Container,API_Ingress,Web_Container,Web_Ingress container
    class ACR,AI,VNet external
```

### Container App Configuration

| Setting | orders-api | web-app |
|---------|------------|---------|
| **Min Replicas** | 0 | 0 |
| **Max Replicas** | 10 | 10 |
| **CPU** | 0.5 | 0.5 |
| **Memory** | 1.0 Gi | 1.0 Gi |
| **Ingress** | External (API) | External (Web) |
| **Target Port** | 5001 | 5002 |
| **Transport** | HTTP | HTTP |

---

## 8. Network Architecture

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'fontSize': '14px'}}}%%
flowchart TB
    subgraph Internet["🌐 Internet"]
        Users["End Users"]
    end

    subgraph Azure["☁️ Azure"]
        subgraph VNet["Virtual Network (managed)"]
            subgraph CAE["Container Apps Environment"]
                API["Orders API<br/>External Ingress"]
                Web["Web App<br/>External Ingress"]
            end
        end
        
        subgraph PaaS["PaaS Services"]
            SQL["Azure SQL<br/>Public Endpoint"]
            SB["Service Bus<br/>Public Endpoint"]
            LA["Logic Apps<br/>Public Endpoint"]
        end
    end

    Users -->|"HTTPS"| Web
    Users -->|"HTTPS"| API
    API -->|"TDS (1433)"| SQL
    API -->|"AMQP (5671)"| SB
    SB -->|"Trigger"| LA

    %% Accessible color palette for network zones
    classDef internet fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px,color:#1b5e20
    classDef compute fill:#e3f2fd,stroke:#1565c0,stroke-width:2px,color:#0d47a1
    classDef paas fill:#fff3e0,stroke:#e65100,stroke-width:2px,color:#bf360c

    class Users internet
    class API,Web compute
    class SQL,SB,LA paas
```

### Network Configuration

| Resource | Endpoint Type | Access | Protocol |
|----------|---------------|--------|----------|
| **Container Apps** | External Ingress | Public | HTTPS |
| **Azure SQL** | Public | Firewall Rules | TDS (1433) |
| **Service Bus** | Public | Managed Identity | AMQP (5671) |
| **Logic Apps** | Public | Azure Entra ID | HTTPS |
| **Storage** | Public | Managed Identity | HTTPS |

---

## 9. Security Architecture Summary

| Control | Implementation | Configuration |
|---------|----------------|---------------|
| **Identity** | User-Assigned Managed Identity | Single identity for all services |
| **Authentication** | Azure Entra ID (Managed Identity) | Credential-free auth to Azure services |
| **Authorization** | Azure RBAC | Role assignments per service |
| **Network** | Public endpoints + firewall | Development configuration |
| **Secrets** | Azure Key Vault (not deployed) | Future enhancement |
| **TLS** | Azure-managed certificates | Automatic for Container Apps |

---

## Cross-Architecture Relationships

| Related Architecture | Connection | Reference |
|---------------------|------------|-----------|
| **Application Architecture** | Services deployed to Azure resources | [Application Architecture](03-application-architecture.md) |
| **Security Architecture** | Identity and access controls | [Security Architecture](06-security-architecture.md) |
| **Deployment Architecture** | IaC templates and CI/CD | [Deployment Architecture](07-deployment-architecture.md) |
| **Observability Architecture** | Monitoring infrastructure | [Observability Architecture](05-observability-architecture.md) |

---

## Related Documents

- [Security Architecture](06-security-architecture.md) - Identity and access details
- [Deployment Architecture](07-deployment-architecture.md) - CI/CD and deployment flows
- [ADR-001: Aspire Orchestration](adr/ADR-001-aspire-orchestration.md) - Local orchestration decision
