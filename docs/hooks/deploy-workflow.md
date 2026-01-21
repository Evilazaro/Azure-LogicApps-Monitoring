---
title: deploy-workflow Hook
description: Deployment script that packages and deploys Logic Apps Standard workflows to Azure using zip deployment.
author: Azure Developer CLI Team
date: 2026-01-06
version: 2.0.1
tags: [azd, deployment, logic-apps, workflows, azure]
---

# 🚀 deploy-workflow

> Deploys Logic Apps Standard workflows to Azure.

> [!NOTE]
> **Target Audience:** DevOps Engineers and Cloud Administrators  
> **Reading Time:** ~8 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                                |         Index          |                                                                  Next |
| :-------------------------------------- | :--------------------: | --------------------------------------------------------------------: |
| [Generate-Orders](./Generate-Orders.md) | [🪝 Hooks](./index.md) | [configure-federated-credential](./configure-federated-credential.md) |

</details>

---

## 📋 Overview

This script deploys workflow definitions from the OrdersManagement Logic App to Azure. It runs as an azd predeploy hook where environment variables are already loaded.

The script performs the following operations:

- Sets up environment variable aliases for connections.json compatibility
- Resolves placeholders in workflow files (`${VARIABLE}` syntax)
- Retrieves connection runtime URLs from Azure
- Creates a deployment package excluding development files
- Deploys workflows to Azure Logic Apps Standard using zip deployment

---

## 📑 Table of Contents

- [📌 Script Metadata](#-script-metadata)
- [🔧 Prerequisites](#-prerequisites)
- [📥 Parameters](#-parameters)
- [🌐 Environment Variables](#-environment-variables)
- [📁 Excluded Files](#-excluded-files)
- [🔄 Execution Flow](#-execution-flow)
- [📝 Usage Examples](#-usage-examples)
- [⚠️ Exit Codes](#%EF%B8%8F-exit-codes)
- [🔧 Placeholder Resolution](#-placeholder-resolution)
- [📚 Related Scripts](#-related-scripts)
- [📜 Version History](#-version-history)

[⬅️ Back to Index](./index.md)

> [!TIP]
> Environment variables are automatically set by `azd` during deployment hooks—no manual configuration needed.

---

## 📌 Script Metadata

| Property          | PowerShell            | Bash                 |
| ----------------- | --------------------- | -------------------- |
| **File Name**     | `deploy-workflow.ps1` | `deploy-workflow.sh` |
| **Version**       | 2.0.1                 | 2.0.1                |
| **Last Modified** | —                     | —                    |
| **Author**        | Azure Developer CLI   | Azure Developer CLI  |

---

## 🔧 Prerequisites

| Requirement     | Minimum Version | Notes                                                   |
| --------------- | --------------- | ------------------------------------------------------- |
| PowerShell Core | 7.0             | Required for `.ps1` script                              |
| Bash            | 4.0             | Required for `.sh` script                               |
| Azure CLI       | 2.50+           | For Azure authentication and deployments                |
| jq              | Any             | Required for Bash script (JSON parsing)                 |
| zip             | Any             | Required for Bash script (creating deployment packages) |

---

## 📥 Parameters

### PowerShell (`deploy-workflow.ps1`)

| Parameter      | Type   | Required | Default                                                  | Description                            |
| -------------- | ------ | -------- | -------------------------------------------------------- | -------------------------------------- |
| `WorkflowPath` | String | No       | `../workflows/OrdersManagement/OrdersManagementLogicApp` | Path to the workflow project directory |

### Bash (`deploy-workflow.sh`)

| Parameter       | Type       | Required | Default                                                  | Description                            |
| --------------- | ---------- | -------- | -------------------------------------------------------- | -------------------------------------- |
| `workflow_path` | Positional | No       | `../workflows/OrdersManagement/OrdersManagementLogicApp` | Path to the workflow project directory |

---

## 🌐 Environment Variables

### Required Variables (Set by azd)

| Variable                | Source      | Description                                  |
| ----------------------- | ----------- | -------------------------------------------- |
| `AZURE_SUBSCRIPTION_ID` | azd outputs | Azure subscription GUID                      |
| `AZURE_RESOURCE_GROUP`  | azd outputs | Resource group containing deployed resources |
| `LOGIC_APP_NAME`        | azd outputs | Name of the Logic App Standard resource      |

### Optional Variables

| Variable                             | Source      | Description                        |
| ------------------------------------ | ----------- | ---------------------------------- |
| `AZURE_LOCATION`                     | azd outputs | Azure region (default: `westus3`)  |
| `SERVICE_BUS_CONNECTION_RUNTIME_URL` | azd outputs | Service Bus connection runtime URL |
| `AZURE_BLOB_CONNECTION_RUNTIME_URL`  | azd outputs | Azure Blob connection runtime URL  |
| `MANAGED_IDENTITY_NAME`              | azd outputs | Managed identity for connections   |

### Environment Variable Aliases

The script automatically maps `AZURE_*` variables to `WORKFLOWS_*` equivalents for connections.json compatibility:

| Source Variable         | Target Variable                 |
| ----------------------- | ------------------------------- |
| `AZURE_SUBSCRIPTION_ID` | `WORKFLOWS_SUBSCRIPTION_ID`     |
| `AZURE_RESOURCE_GROUP`  | `WORKFLOWS_RESOURCE_GROUP_NAME` |
| `AZURE_LOCATION`        | `WORKFLOWS_LOCATION_NAME`       |

---

## 📁 Excluded Files

The following patterns are excluded from deployment (per `.funcignore`):

- `.debug`
- `.git*`
- `.vscode`
- `__azurite*`
- `__blobstorage__`
- `__queuestorage__`
- `local.settings.json`
- `test`
- `workflow-designtime`

---

## 🔄 Execution Flow

```mermaid
---
title: deploy-workflow Execution Flow
---
flowchart LR
    %% ===== STYLE DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5

    %% ===== TRIGGER =====
    subgraph triggers["🚀 Entry Point"]
        direction TB
        A(["🚀 Start deploy-workflow"])
        B["Disable ANSI Colors"]
        C["Set Environment Variable Aliases"]
    end

    %% ===== CONFIGURATION =====
    subgraph config["⚙️ Configuration"]
        direction TB
        D["Load Configuration from Environment"]
        E{"Validate Required Variables"}
        F{"Connection Runtime URLs Set?"}
        G["Retrieve Runtime URLs from Azure"]
        H["Use Existing URLs"]
    end

    %% ===== STAGING =====
    subgraph staging["📁 Staging"]
        direction TB
        I["Create Staging Directory"]
        J["Copy Workflow Files"]
        K["Resolve Placeholders in Files"]
    end

    %% ===== PROCESSING =====
    subgraph processing["🔧 File Processing"]
        direction TB
        L["Process connections.json"]
        M["Process parameters.json"]
        N["Process host.json"]
    end

    %% ===== DEPLOYMENT =====
    subgraph deployment["📦 Deployment"]
        direction TB
        O["Create Deployment ZIP"]
        P["Deploy to Logic App via az webapp deployment"]
        Q{"Deployment Success?"}
    end

    %% ===== RESULTS =====
    subgraph results["📊 Results"]
        direction TB
        R["❌ Log Error"]
        S["✅ Log Success"]
        T["Cleanup Staging Directory"]
        U(["🏁 End"])
    end

    %% ===== FAILURE =====
    subgraph failure["❌ Error Handling"]
        direction TB
        Z["❌ Exit with Error"]
    end

    %% ===== CONNECTIONS =====
    A -->|"disables"| B
    B -->|"sets"| C

    C -->|"loads"| D
    D -->|"validates"| E

    E -->|"Missing"| Z
    E -->|"Valid"| F

    F -->|"No"| G
    F -->|"Yes"| H

    G -->|"uses"| H
    H -->|"creates"| I

    I -->|"copies"| J
    J -->|"resolves"| K

    K -->|"processes"| L
    L -->|"processes"| M
    M -->|"processes"| N

    N -->|"creates"| O
    O -->|"deploys"| P

    P -->|"checks"| Q
    Q -->|"No"| R
    Q -->|"Yes"| S

    R -->|"cleans"| T
    S -->|"cleans"| T

    T -->|"ends"| U

    %% ===== NODE STYLING =====
    class A trigger
    class B,C,D,G,H,I,J,K,L,M,N,O,P primary
    class E,F,Q decision
    class S,T secondary
    class U secondary
    class R,Z failed

    %% ===== SUBGRAPH STYLING =====
    style triggers fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style config fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style staging fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style processing fill:#D1FAE5,stroke:#059669,stroke-width:2px
    style deployment fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style results fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style failure fill:#FEE2E2,stroke:#F44336,stroke-width:2px
```

---

## 📝 Usage Examples

### PowerShell

```powershell
# Deploy workflows using default path and environment variables from azd
./deploy-workflow.ps1

# Deploy workflows from a custom path
./deploy-workflow.ps1 -WorkflowPath "C:\MyWorkflows\LogicApp"
```

### Bash

```bash
# Deploy workflows using default path and environment variables from azd
./deploy-workflow.sh

# Deploy workflows from a custom path
./deploy-workflow.sh "/path/to/my/workflows"
```

---

## ⚠️ Exit Codes

| Code | Meaning                                                                |
| ---- | ---------------------------------------------------------------------- |
| `0`  | Success - workflows deployed successfully                              |
| `1`  | Error - missing required dependencies, variables, or deployment failed |

---

## 🔧 Placeholder Resolution

The script resolves `${VARIABLE}` placeholders in workflow files by replacing them with corresponding environment variable values. If a placeholder cannot be resolved (environment variable not set), a warning is logged.

### Example

**Before:**

```json
{
  "subscriptionId": "${AZURE_SUBSCRIPTION_ID}",
  "resourceGroup": "${AZURE_RESOURCE_GROUP}"
}
```

**After:**

```json
{
  "subscriptionId": "12345678-1234-1234-1234-123456789012",
  "resourceGroup": "rg-logicapps-dev"
}
```

---

## 📚 Related Scripts

| Script                              | Purpose                                        |
| ----------------------------------- | ---------------------------------------------- |
| [postprovision](./postprovision.md) | Sets environment variables used by this script |

---

## 📜 Version History

| Version | Date | Changes                                                                   |
| ------- | ---- | ------------------------------------------------------------------------- |
| 2.0.1   | N/A  | Disabled ANSI colors for CI compatibility, enhanced runtime URL retrieval |
| 2.0.0   | N/A  | Major refactor with placeholder resolution                                |
| 1.0.0   | N/A  | Initial release                                                           |

---

> [!IMPORTANT]
> Ensure all required environment variables are set before deployment. Missing variables will cause placeholder resolution to fail.

## 🔗 Links

- [Repository](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- [Azure Logic Apps Standard Documentation](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview)
- [Azure CLI webapp deployment](https://learn.microsoft.com/cli/azure/webapp/deployment)

---

<div align="center">

**[⬆️ Back to Top](#-deploy-workflow)** · **[← Generate-Orders](./Generate-Orders.md)** · **[configure-federated-credential →](./configure-federated-credential.md)**

</div>
