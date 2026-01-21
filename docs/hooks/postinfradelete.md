---
title: postinfradelete Hook
description: Post-infrastructure-delete hook that purges soft-deleted Logic Apps Standard resources after running azd down.
author: Evilazaro
date: 2026-01-09
version: 2.0.0
tags: [azd, hooks, cleanup, logic-apps, soft-delete]
---

# 🗑️ postinfradelete

> Post-infrastructure-delete hook for Azure Developer CLI (azd).

> [!NOTE]
> **Target Audience:** DevOps Engineers and Cloud Administrators  
> **Reading Time:** ~6 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                            |          Index          |                                                Next |
| :---------------------------------- | :---------------------: | --------------------------------------------------: |
| [postprovision](./postprovision.md) | [🪝 Hooks](./README.md) | [check-dev-workstation](./check-dev-workstation.md) |

</details>

---

## 📋 Overview

Purges soft-deleted Logic Apps Standard resources after infrastructure deletion. This script is automatically executed by azd after `azd down` completes.

When Azure Logic Apps Standard are deleted, they enter a soft-delete state and must be explicitly purged to fully remove them. This script handles the purge operation to ensure complete cleanup.

The script performs the following operations:

- Validates required environment variables (subscription, location)
- Authenticates to Azure using the current CLI session
- Retrieves the list of soft-deleted Logic Apps in the specified location
- Purges any Logic Apps that match the resource group naming pattern

---

## 📑 Table of Contents

- [📌 Script Metadata](#-script-metadata)
- [🔧 Prerequisites](#-prerequisites)
- [📥 Parameters](#-parameters)
- [🌐 Environment Variables](#-environment-variables)
- [🔄 Execution Flow](#-execution-flow)
- [📝 Usage Examples](#-usage-examples)
- [⚠️ Exit Codes](#%EF%B8%8F-exit-codes)
- [🔧 Azure REST API](#-azure-rest-api)
- [📚 Related Scripts](#-related-scripts)
- [📜 Version History](#-version-history)

[⬅️ Back to Index](./README.md)

> [!WARNING]
> Purging soft-deleted Logic Apps is irreversible. Use `-WhatIf` to preview changes before execution.

---

## 📌 Script Metadata

| Property          | PowerShell                                                   | Bash                                                         |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **File Name**     | `postinfradelete.ps1`                                        | `postinfradelete.sh`                                         |
| **Version**       | 2.0.0                                                        | 2.0.0                                                        |
| **Last Modified** | 2026-01-09                                                   | 2026-01-09                                                   |
| **Author**        | Evilazaro \| Principal Cloud Solution Architect \| Microsoft | Evilazaro \| Principal Cloud Solution Architect \| Microsoft |

---

## 🔧 Prerequisites

| Requirement     | Minimum Version | Notes                                   |
| --------------- | --------------- | --------------------------------------- |
| PowerShell Core | 7.0             | Required for `.ps1` script              |
| Bash            | 4.0             | Required for `.sh` script               |
| Azure CLI       | 2.50+           | For Azure REST API calls                |
| jq              | Any             | Required for Bash script (JSON parsing) |

---

## 📥 Parameters

### PowerShell (`postinfradelete.ps1`)

| Parameter  | Type   | Required | Default  | Description                                         |
| ---------- | ------ | -------- | -------- | --------------------------------------------------- |
| `-Force`   | Switch | No       | `$false` | Skips confirmation prompts and forces execution     |
| `-WhatIf`  | Switch | No       | `$false` | Shows what would be executed without making changes |
| `-Verbose` | Switch | No       | `$false` | Displays detailed diagnostic information            |

### Bash (`postinfradelete.sh`)

| Parameter         | Type | Required | Default | Description               |
| ----------------- | ---- | -------- | ------- | ------------------------- |
| `--force`, `-f`   | Flag | No       | `false` | Skip confirmation prompts |
| `--verbose`, `-v` | Flag | No       | `false` | Enable verbose output     |
| `--help`, `-h`    | Flag | No       | N/A     | Show help message         |

---

## 🌐 Environment Variables

### Required Variables (Set by azd)

| Variable                | Source      | Description                                |
| ----------------------- | ----------- | ------------------------------------------ |
| `AZURE_SUBSCRIPTION_ID` | azd outputs | Azure subscription GUID                    |
| `AZURE_LOCATION`        | azd outputs | Azure region where resources were deployed |

### Optional Variables

| Variable               | Source      | Description                           |
| ---------------------- | ----------- | ------------------------------------- |
| `AZURE_RESOURCE_GROUP` | azd outputs | Filter by resource group name pattern |
| `LOGIC_APP_NAME`       | azd outputs | Filter by Logic App name pattern      |

---

## 🔄 Execution Flow

```mermaid
---
title: postinfradelete Execution Flow
---
flowchart TD
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
        A(["🚀 Start postinfradelete"])
        B["Parse Arguments"]
    end

    %% ===== HELP =====
    subgraph help["📖 Help"]
        direction TB
        C{"Help Requested?"}
        D["Display Help"]
    end

    %% ===== VALIDATION =====
    subgraph validation["🔍 Validation"]
        direction TB
        E{"Validate Required Env Vars"}
        G["Display Configuration"]
    end

    %% ===== DISCOVERY =====
    subgraph discovery["🔎 Resource Discovery"]
        direction TB
        H["Get Soft-Deleted Logic Apps via REST API"]
        I{"Any Deleted Apps Found?"}
        K["Filter by Resource Group Pattern"]
        L{"Any Matching Apps?"}
    end

    %% ===== CONFIRMATION =====
    subgraph confirmation["✋ Confirmation"]
        direction TB
        M{"Force Mode?"}
        N["Prompt for Confirmation"]
        O["Skip Confirmation"]
    end

    %% ===== PURGE =====
    subgraph purge["🗑️ Purge Operations"]
        direction TB
        Q["Loop: Purge Each Logic App"]
        R["Call DELETE REST API"]
        S{"More Apps?"}
    end

    %% ===== RESULTS =====
    subgraph results["📊 Results"]
        direction TB
        J["ℹ️ No Apps to Purge"]
        T["Display Summary"]
        U{"Any Failures?"}
        V["⚠️ Partial Success"]
        W["✅ All Purged Successfully"]
        Z(["🏁 End"])
    end

    %% ===== FAILURE =====
    subgraph failure["❌ Error Handling"]
        direction TB
        F["❌ Exit with Error"]
        P["🚫 Exit Cancelled"]
    end

    %% ===== CONNECTIONS =====
    A -->|"parses"| B
    B -->|"checks"| C

    C -->|"Yes"| D
    D -->|"ends"| Z

    C -->|"No"| E
    E -->|"Missing"| F
    E -->|"Valid"| G

    G -->|"retrieves"| H
    H -->|"checks"| I

    I -->|"No"| J
    J -->|"ends"| Z

    I -->|"Yes"| K
    K -->|"checks"| L

    L -->|"No"| J
    L -->|"Yes"| M

    M -->|"No"| N
    M -->|"Yes"| O

    N -->|"Decline"| P
    N -->|"Accept"| O

    O -->|"iterates"| Q
    Q -->|"calls"| R

    R -->|"checks"| S
    S -->|"Yes"| Q
    S -->|"No"| T

    T -->|"checks"| U
    U -->|"Yes"| V
    U -->|"No"| W

    V -->|"ends"| Z
    W -->|"ends"| Z
    P -->|"ends"| Z

    %% ===== NODE STYLING =====
    class A trigger
    class B,D,G,H,K,N,O,Q,R primary
    class C,E,I,L,M,S,U decision
    class J,T,V,W secondary
    class Z secondary
    class F,P failed

    %% ===== SUBGRAPH STYLING =====
    style triggers fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style help fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
    style validation fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style discovery fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style confirmation fill:#D1FAE5,stroke:#059669,stroke-width:2px
    style purge fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style results fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style failure fill:#FEE2E2,stroke:#F44336,stroke-width:2px
```

---

## 📝 Usage Examples

### PowerShell

```powershell
# Purge soft-deleted Logic Apps with confirmation prompt
.\postinfradelete.ps1

# Purge soft-deleted Logic Apps without confirmation, with verbose output
.\postinfradelete.ps1 -Force -Verbose

# Show which Logic Apps would be purged without making changes
.\postinfradelete.ps1 -WhatIf
```

### Bash

```bash
# Purge soft-deleted Logic Apps with confirmation prompt
./postinfradelete.sh

# Purge soft-deleted Logic Apps without confirmation, with verbose output
./postinfradelete.sh --force --verbose

# Display help message
./postinfradelete.sh --help
```

---

## ⚠️ Exit Codes

| Code | Meaning                                                    |
| ---- | ---------------------------------------------------------- |
| `0`  | Success - all soft-deleted apps purged or no apps to purge |
| `1`  | Error - validation failed or purge operations failed       |

---

## 🔧 Azure REST API

The script uses the Azure REST API to interact with soft-deleted resources:

### List Deleted Sites

```
GET https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Web/locations/{location}/deletedSites?api-version=2023-12-01
```

### Purge Deleted Site

```
DELETE https://management.azure.com/subscriptions/{subscriptionId}/providers/Microsoft.Web/locations/{location}/deletedSites/{deletedSiteId}?api-version=2023-12-01
```

---

## 📚 Related Scripts

| Script                              | Purpose                                 |
| ----------------------------------- | --------------------------------------- |
| [preprovision](./preprovision.md)   | Runs before infrastructure provisioning |
| [postprovision](./postprovision.md) | Runs after infrastructure provisioning  |

---

## 📜 Version History

| Version | Date       | Changes                                                                      |
| ------- | ---------- | ---------------------------------------------------------------------------- |
| 2.0.0   | 2026-01-09 | Major refactor with REST API implementation and comprehensive error handling |
| 1.0.0   | 2025-10-01 | Initial release                                                              |

> [!CAUTION]
> Purged Logic Apps cannot be recovered. Always verify the apps to be deleted with `--verbose` before confirming.

## 🔗 Links

- [Repository](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- [Azure Logic Apps Standard Documentation](https://learn.microsoft.com/azure/logic-apps/logic-apps-overview)
- [Azure REST API Reference](https://learn.microsoft.com/rest/api/azure/)

---

<div align="center">

**[⬆️ Back to Top](#%EF%B8%8F-postinfradelete)** · **[← postprovision](./postprovision.md)** · **[check-dev-workstation →](./check-dev-workstation.md)**

</div>
