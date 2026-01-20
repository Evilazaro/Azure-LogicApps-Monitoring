# Technology Architecture

← [Application Architecture](03-application-architecture.md) | **Technology Layer** | [Observability Architecture →](05-observability-architecture.md)

---

## Technology Principles

| #       | Principle                     | Rationale                         | Implications                          |
| ------- | ----------------------------- | --------------------------------- | ------------------------------------- |
| **T-1** | **Azure PaaS First**          | Reduced operational overhead      | Container Apps, SQL PaaS, Service Bus |
| **T-2** | **Infrastructure as Code**    | Repeatable, auditable deployments | All resources defined in Bicep        |
| **T-3** | **Managed Identity**          | Zero stored secrets               | DefaultAzureCredential everywhere     |
| **T-4** | **Local Development Parity**  | Minimize production surprises     | Emulators mirror Azure services       |
| **T-5** | **Single-Command Deployment** | Reduce human error                | `azd up` provisions and deploys       |

---

## Technology Standards Catalog

| Category               | Technology           | Version  | Status   | Rationale                         |
| ---------------------- | -------------------- | -------- | -------- | --------------------------------- |
| **Runtime**            | .NET                 | 10.0     | Approved | LTS, performance, Aspire support  |
| **Container Platform** | Azure Container Apps | Latest   | Approved | Serverless containers, auto-scale |
| **Database**           | Azure SQL Database   | Latest   | Approved | Managed PaaS, EF Core support     |
| **Messaging**          | Azure Service Bus    | Standard | Approved | Enterprise messaging, topics      |
| **Workflow**           | Logic Apps Standard  | Latest   | Approved | Event-driven automation           |
| **APM**                | Application Insights | Latest   | Approved | Distributed tracing, Azure native |
| **IaC**                | Bicep                | 0.30+    | Approved | Azure-native, type-safe           |
| **CLI**                | Azure Developer CLI  | 1.11+    | Approved | E2E deployment orchestration      |

---

## Platform Decomposition

```mermaid
flowchart TB
    subgraph Compute["🖥️ Compute Platform"]
        ACA["Azure Container Apps<br/><i>Serverless containers</i>"]
        LA["Logic Apps Standard<br/><i>Workflow engine</i>"]
        ASP["App Service Plan<br/><i>WS1 - WorkflowStandard</i>"]
    end

    subgraph Data["💾 Data Platform"]
        SQL["Azure SQL Database<br/><i>General Purpose</i>"]
        SB["Azure Service Bus<br/><i>Standard tier</i>"]
        Storage["Azure Storage<br/><i>Standard LRS</i>"]
    end

    subgraph Observability["📊 Observability Platform"]
        AI["Application Insights<br/><i>Workspace-based</i>"]
        LAW["Log Analytics Workspace<br/><i>Centralized logs</i>"]
    end

    subgraph Identity["🔐 Identity Platform"]
        MI["User-Assigned Managed Identity"]
        RBAC["Azure RBAC<br/><i>Role assignments</i>"]
    end

    subgraph Network["🌐 Network Platform"]
        VNet["Virtual Network"]
        Subnets["Subnets<br/><i>API, Logic App</i>"]
    end

    ACA --> MI
    LA --> ASP
    LA --> MI
    SQL --> MI
    SB --> MI
    ACA --> VNet
    LA --> Subnets

    classDef compute fill:#e3f2fd,stroke:#1565c0,stroke-width:2px
    classDef data fill:#e8f5e9,stroke:#2e7d32,stroke-width:2px
    classDef observability fill:#fce4ec,stroke:#c2185b,stroke-width:2px
    classDef identity fill:#fff3e0,stroke:#ef6c00,stroke-width:2px
    classDef network fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px

    class ACA,LA,ASP compute
    class SQL,SB,Storage data
    class AI,LAW observability
    class MI,RBAC identity
    class VNet,Subnets network
```

---

## Environment and Location Strategy

| Environment    | Region       | Purpose             | SLA Target | Infrastructure                         |
| -------------- | ------------ | ------------------- | ---------- | -------------------------------------- |
| **Local**      | N/A          | Development/Debug   | N/A        | Emulators (SQL Container, SB Emulator) |
| **Dev**        | Configurable | Shared development  | 99%        | Azure PaaS (shared)                    |
| **Staging**    | Configurable | Pre-prod validation | 99.5%      | Azure PaaS (dedicated)                 |
| **Production** | Configurable | Live workloads      | 99.9%      | Azure PaaS (dedicated)                 |

---

## Infrastructure Components

### Azure Resource Topology

```mermaid
flowchart TB
    subgraph RG["📦 Resource Group: rg-orders-{env}-{region}"]
        subgraph Identity["🔐 Identity"]
            MI["User-Assigned<br/>Managed Identity"]
        end

        subgraph Compute["🖥️ Compute"]
            CAE["Container Apps<br/>Environment"]
            CA1["Container App:<br/>orders-api"]
            CA2["Container App:<br/>web-app"]
            ACR["Container Registry"]
            ASP["App Service Plan<br/>(WS1)"]
            LogicApp["Logic App:<br/>OrdersManagement"]
        end

        subgraph Data["💾 Data"]
            SQLServer["SQL Server"]
            SQLDb["SQL Database:<br/>OrderDb"]
            SBNamespace["Service Bus<br/>Namespace"]
            SBTopic["Topic:<br/>ordersplaced"]
            SBSub["Subscription:<br/>orderprocessingsub"]
            StorageAcct["Storage Account"]
        end

        subgraph Monitoring["📊 Monitoring"]
            LAW["Log Analytics<br/>Workspace"]
            AppInsights["Application<br/>Insights"]
        end

        subgraph Network["🌐 Network"]
            VNet["Virtual Network"]
            APISubnet["API Subnet"]
            LASubnet["Logic App Subnet"]
        end
    end

    MI --> CA1 & CA2 & LogicApp & SQLDb & SBNamespace
    CA1 & CA2 --> CAE
    CAE --> ACR
    LogicApp --> ASP
    SQLServer --> SQLDb
    SBNamespace --> SBTopic --> SBSub
    AppInsights --> LAW
    CA1 & CA2 -.-> AppInsights
    CAE --> APISubnet
    LogicApp --> LASubnet
    APISubnet & LASubnet --> VNet

    classDef identity fill:#fff3e0,stroke:#ef6c00
    classDef compute fill:#e3f2fd,stroke:#1565c0
    classDef data fill:#e8f5e9,stroke:#2e7d32
    classDef monitoring fill:#fce4ec,stroke:#c2185b
    classDef network fill:#f3e5f5,stroke:#7b1fa2

    class MI identity
    class CAE,CA1,CA2,ACR,ASP,LogicApp compute
    class SQLServer,SQLDb,SBNamespace,SBTopic,SBSub,StorageAcct data
    class LAW,AppInsights monitoring
    class VNet,APISubnet,LASubnet network
```

---

## Technology Portfolio

| Service                        | Tier/SKU        | Scaling       | Cost Model            | Purpose                      |
| ------------------------------ | --------------- | ------------- | --------------------- | ---------------------------- |
| **Container Apps Environment** | Consumption     | 0-10 replicas | Per-request           | Serverless container hosting |
| **Azure SQL Database**         | General Purpose | Manual        | DTU-based             | Relational data persistence  |
| **Service Bus Namespace**      | Standard        | Auto          | Per-operation         | Message brokering            |
| **Logic Apps**                 | Standard (WS1)  | Elastic       | Per-execution         | Workflow automation          |
| **Application Insights**       | Standard        | Auto          | Per-GB ingested       | APM and tracing              |
| **Log Analytics**              | Per-GB          | Auto          | Per-GB ingested       | Log aggregation              |
| **Container Registry**         | Basic           | N/A           | Per-storage           | Container image store        |
| **Storage Account**            | Standard LRS    | Auto          | Per-GB + transactions | Workflow state, blobs        |

---

## Infrastructure as Code

### Bicep Module Structure

```
infra/
├── main.bicep                    # Entry point (subscription scope)
├── main.parameters.json          # Environment parameters
├── types.bicep                   # Shared type definitions
├── shared/
│   ├── main.bicep               # Shared infrastructure orchestrator
│   ├── identity/
│   │   └── main.bicep           # Managed identity + RBAC
│   ├── monitoring/
│   │   ├── main.bicep           # Monitoring orchestrator
│   │   ├── app-insights.bicep   # Application Insights
│   │   └── log-analytics-workspace.bicep
│   ├── network/
│   │   └── main.bicep           # VNet, subnets, NSGs
│   └── data/
│       └── main.bicep           # SQL Server, Storage
└── workload/
    ├── main.bicep               # Workload orchestrator
    ├── logic-app.bicep          # Logic Apps Standard
    ├── messaging/
    │   └── main.bicep           # Service Bus
    └── services/
        └── main.bicep           # Container Apps
```

### Key Bicep Patterns

| Pattern                 | Implementation                                    | Location                                                      |
| ----------------------- | ------------------------------------------------- | ------------------------------------------------------------- |
| **Unique Naming**       | `uniqueString(resourceGroup().id, name, envName)` | All modules                                                   |
| **Tagging**             | Standard tags via `tagsType`                      | [types.bicep](../../infra/types.bicep)                        |
| **Diagnostic Settings** | All resources export to Log Analytics             | Each module                                                   |
| **Managed Identity**    | User-assigned identity shared across resources    | [identity/main.bicep](../../infra/shared/identity/main.bicep) |

---

## Local Development Stack

| Azure Service        | Local Alternative        | Configuration                       |
| -------------------- | ------------------------ | ----------------------------------- |
| Azure SQL Database   | SQL Server Container     | `RunAsContainer()` with data volume |
| Azure Service Bus    | Service Bus Emulator     | `RunAsEmulator()`                   |
| Application Insights | OTLP Exporter / Console  | Environment detection               |
| Container Apps       | Direct project execution | Kestrel servers                     |

### Local Mode Detection

```csharp
// From AppHost.cs
var isLocalMode = sbHostName.Equals("localhost", StringComparison.OrdinalIgnoreCase);

if (isLocalMode)
{
    serviceBusResource = builder.AddAzureServiceBus("messaging").RunAsEmulator();
}
else
{
    serviceBusResource = builder.AddAzureServiceBus("messaging")
        .AsExisting(sbParam, resourceGroupParameter);
}
```

---

## Operational Considerations

### Backup and Recovery

| Resource             | Backup Strategy                  | RPO   | RTO      |
| -------------------- | -------------------------------- | ----- | -------- |
| **Azure SQL**        | Azure-managed backup             | 5 min | < 1 hour |
| **Service Bus**      | Geo-disaster recovery (optional) | 0     | < 1 min  |
| **Storage**          | LRS (3 copies)                   | 0     | N/A      |
| **Container Images** | ACR geo-replication (optional)   | 0     | < 5 min  |

### Maintenance Windows

| Resource           | Update Strategy            | Downtime           |
| ------------------ | -------------------------- | ------------------ |
| **Container Apps** | Rolling updates            | Zero downtime      |
| **Azure SQL**      | Azure-managed patching     | Automatic failover |
| **Logic Apps**     | Slot deployment (optional) | Near-zero          |

---

## Cross-Architecture Relationships

| Related Architecture           | Connection                                    | Reference                                                      |
| ------------------------------ | --------------------------------------------- | -------------------------------------------------------------- |
| **Application Architecture**   | Services deployed to this infrastructure      | [Application Architecture](03-application-architecture.md)     |
| **Observability Architecture** | Monitoring platforms defined here             | [Observability Architecture](05-observability-architecture.md) |
| **Deployment Architecture**    | IaC modules provisioned by CI/CD              | [Deployment Architecture](07-deployment-architecture.md)       |
| **Security Architecture**      | Identity and network security configured here | [Security Architecture](06-security-architecture.md)           |

---

_← [Application Architecture](03-application-architecture.md) | [Observability Architecture →](05-observability-architecture.md)_
