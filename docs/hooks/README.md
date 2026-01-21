---
title: Hooks Documentation
description: Comprehensive documentation for Azure Developer CLI (azd) lifecycle hooks and utility scripts used in the Azure Logic Apps Monitoring solution.
author: Evilazaro
date: 2026-01-21
version: 2.0.0
tags: [azd, hooks, azure, devops, lifecycle, automation]
---

# 🪝 Hooks Documentation

> Azure Developer CLI (azd) lifecycle hooks for the Azure Logic Apps Monitoring solution.

> [!NOTE]
> **Target Audience:** DevOps Engineers, Cloud Architects, and Developers  
> **Reading Time:** ~10 minutes

<details>
<summary>📍 Navigation</summary>

| Previous |      Index       |                              Next |
| :------- | :--------------: | --------------------------------: |
| —        | **You are here** | [preprovision](./preprovision.md) |

</details>

---

## 📋 Overview

This directory contains documentation for all hooks scripts used in the Azure Logic Apps Monitoring solution. These hooks are automatically executed by Azure Developer CLI (azd) at specific points in the deployment lifecycle.

---

## 📑 Table of Contents

- [📁 Hook Categories](#-hook-categories)
  - [🔄 Lifecycle Hooks](#-lifecycle-hooks-azd-triggered)
  - [🛠️ Development Tools](#%EF%B8%8F-development-tools)
  - [☁️ Azure Configuration](#%EF%B8%8F-azure-configuration)
- [🔄 Execution Order](#-execution-order)
- [📊 Script Matrix](#-script-matrix)
- [🔧 Common Prerequisites](#-common-prerequisites)
- [🌐 Environment Variables](#-environment-variables)
- [🚀 Quick Start](#-quick-start)
- [📚 Related Documentation](#-related-documentation)

---

## 📁 Hook Categories

### 🔄 Lifecycle Hooks (azd-triggered)

| Hook                                    | Trigger                | Purpose                                           |
| --------------------------------------- | ---------------------- | ------------------------------------------------- |
| [preprovision](./preprovision.md)       | Before `azd provision` | Validates environment and clears secrets          |
| [postprovision](./postprovision.md)     | After `azd provision`  | Configures .NET user secrets with Azure resources |
| [postinfradelete](./postinfradelete.md) | After `azd down`       | Purges soft-deleted Logic Apps                    |

### 🛠️ Development Tools

| Script                                              | Purpose                                       |
| --------------------------------------------------- | --------------------------------------------- |
| [check-dev-workstation](./check-dev-workstation.md) | Validates developer workstation prerequisites |
| [clean-secrets](./clean-secrets.md)                 | Clears .NET user secrets for all projects     |
| [Generate-Orders](./Generate-Orders.md)             | Generates sample order data for testing       |

### ☁️ Azure Configuration

| Script                                                                | Purpose                                         |
| --------------------------------------------------------------------- | ----------------------------------------------- |
| [deploy-workflow](./deploy-workflow.md)                               | Deploys Logic Apps Standard workflows           |
| [configure-federated-credential](./configure-federated-credential.md) | Configures GitHub Actions OIDC federation       |
| [sql-managed-identity-config](./sql-managed-identity-config.md)       | Configures SQL Database managed identity access |

---

## 🔄 Execution Order

The following diagram shows the typical execution flow during `azd up`:

```mermaid
---
title: azd up Execution Flow
---
flowchart TD
    %% ===== STYLE DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000

    %% ===== TRIGGER =====
    subgraph triggers["🚀 Entry Point"]
        direction TB
        A(["🚀 azd up"])
    end

    %% ===== PRE-PROVISIONING =====
    subgraph preprov["🔧 Pre-Provisioning"]
        direction TB
        B["preprovision"]
        C["Validate Prerequisites"]
        D["Clear User Secrets"]
    end

    %% ===== PROVISIONING =====
    subgraph prov["☁️ Azure Provisioning"]
        direction TB
        E["azd provision"]
        F["Bicep Deployment"]
    end

    %% ===== POST-PROVISIONING =====
    subgraph postprov["⚙️ Post-Provisioning"]
        direction TB
        G["postprovision"]
        H["Configure User Secrets"]
        I["SQL Managed Identity Setup"]
    end

    %% ===== DEPLOYMENT =====
    subgraph deploy["📦 Deployment"]
        direction TB
        J["azd deploy"]
        K["deploy-workflow"]
    end

    %% ===== COMPLETION =====
    subgraph complete["✅ Results"]
        direction TB
        L(["✅ Deployment Complete"])
    end

    %% ===== CONNECTIONS =====
    A -->|"initiates"| B
    B -->|"validates"| C
    C -->|"clears"| D
    D -->|"triggers"| E
    E -->|"deploys IaC"| F
    F -->|"triggers"| G
    G -->|"configures"| H
    H -->|"configures"| I
    I -->|"triggers"| J
    J -->|"deploys"| K
    K -->|"completes"| L

    %% ===== NODE STYLING =====
    class A trigger
    class B,C,D,E,F,G,H,I,J,K primary
    class L secondary

    %% ===== SUBGRAPH STYLING =====
    style triggers fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style preprov fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style prov fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style postprov fill:#D1FAE5,stroke:#059669,stroke-width:2px
    style deploy fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style complete fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
```

---

## 📊 Script Matrix

| Script                                                                | PowerShell | Bash | Version | Last Modified |
| --------------------------------------------------------------------- | :--------: | :--: | ------- | ------------- |
| [preprovision](./preprovision.md)                                     |     ✅     |  ✅  | 2.3.0   | 2026-01-06    |
| [postprovision](./postprovision.md)                                   |     ✅     |  ✅  | 2.0.1   | 2026-01-06    |
| [postinfradelete](./postinfradelete.md)                               |     ✅     |  ✅  | 2.0.0   | 2026-01-09    |
| [check-dev-workstation](./check-dev-workstation.md)                   |     ✅     |  ✅  | 1.0.0   | 2026-01-07    |
| [clean-secrets](./clean-secrets.md)                                   |     ✅     |  ✅  | 2.0.1   | 2026-01-06    |
| [deploy-workflow](./deploy-workflow.md)                               |     ✅     |  ✅  | 2.0.1   | —             |
| [configure-federated-credential](./configure-federated-credential.md) |     ✅     |  ✅  | 1.0.0   | —             |
| [Generate-Orders](./Generate-Orders.md)                               |     ✅     |  ✅  | 2.0.1   | 2026-01-06    |
| [sql-managed-identity-config](./sql-managed-identity-config.md)       |     ✅     |  ✅  | 1.0.0   | 2026-01-06    |

---

## 🔧 Common Prerequisites

All scripts require the following minimum versions:

| Tool                | Minimum Version | Purpose                                   |
| ------------------- | --------------- | ----------------------------------------- |
| PowerShell Core     | 7.0             | Script execution (.ps1)                   |
| Bash                | 4.0             | Script execution (.sh)                    |
| .NET SDK            | 10.0            | User secrets management, project building |
| Azure CLI           | 2.60.0          | Azure authentication and operations       |
| Azure Developer CLI | 1.11.0          | Deployment orchestration                  |
| Bicep CLI           | 0.30.0          | Infrastructure as Code                    |

---

## 🌐 Environment Variables

### Core Variables (Set by azd)

| Variable                | Description                           |
| ----------------------- | ------------------------------------- |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription GUID               |
| `AZURE_RESOURCE_GROUP`  | Resource group name                   |
| `AZURE_LOCATION`        | Azure region                          |
| `AZURE_ENV_NAME`        | Environment name (dev, staging, prod) |

### Service-Specific Variables

| Variable                | Description                      |
| ----------------------- | -------------------------------- |
| `LOGIC_APP_NAME`        | Logic App Standard resource name |
| `SERVICE_BUS_NAMESPACE` | Service Bus namespace            |
| `SQL_SERVER_NAME`       | Azure SQL Server name            |
| `SQL_DATABASE_NAME`     | Azure SQL Database name          |
| `MANAGED_IDENTITY_NAME` | Managed identity resource name   |

---

## 🚀 Quick Start

### Validate Development Environment

```powershell
# PowerShell
.\hooks\check-dev-workstation.ps1
```

```bash
# Bash
./hooks/check-dev-workstation.sh
```

### Full Deployment

```bash
# Initialize and deploy
azd auth login
azd init
azd up
```

### Clean Up

```bash
# Tear down resources
azd down
```

---

## 📚 Related Documentation

| Resource                                                                                       | Description                |
| ---------------------------------------------------------------------------------------------- | -------------------------- |
| [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)        | Official azd documentation |
| [azd Hooks](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-extensibility) | Hook extensibility guide   |
| [Project README](../../README.md)                                                              | Main project documentation |

---

> [!TIP]
> For detailed information about each script, click on the links in the tables above to navigate to the individual documentation pages.

## 🔗 Links

- [Repository](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- [Issues](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues)
- [Azure Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)

---

<div align="center">

**[⬆️ Back to Top](#-hooks-documentation)** · **[preprovision →](./preprovision.md)**

</div>
