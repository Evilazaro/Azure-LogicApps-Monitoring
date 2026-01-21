---
title: postprovision Hook
description: Post-provisioning script that configures .NET user secrets with Azure resource information after infrastructure deployment.
author: Evilazaro
date: 2026-01-06
version: 2.0.1
tags: [azd, hooks, postprovision, secrets, configuration]
---

# ⚙️ postprovision

> Post-provisioning script for Azure Developer CLI (azd).

> [!NOTE]
> **Target Audience:** DevOps Engineers and Developers  
> **Reading Time:** ~7 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                          |         Index          |                                    Next |
| :-------------------------------- | :--------------------: | --------------------------------------: |
| [preprovision](./preprovision.md) | [🪝 Hooks](./index.md) | [postinfradelete](./postinfradelete.md) |

</details>

---

## 📋 Overview

Configures .NET user secrets with Azure resource information after provisioning. This script is automatically executed by azd after infrastructure provisioning completes.

The script performs the following operations:

- Validates required environment variables
- Authenticates to Azure Container Registry (if configured)
- Clears existing .NET user secrets
- Configures new user secrets with Azure resource information
- Configures SQL Database managed identity access

---

## 📑 Table of Contents

- [📌 Script Metadata](#-script-metadata)
- [🔧 Prerequisites](#-prerequisites)
- [📥 Parameters](#-parameters)
- [🌐 Environment Variables](#-environment-variables)
- [🔄 Execution Flow](#-execution-flow)
- [📝 Usage Examples](#-usage-examples)
- [⚠️ Exit Codes](#%EF%B8%8F-exit-codes)
- [📊 Output Statistics](#-output-statistics)
- [📚 Related Scripts](#-related-scripts)
- [📜 Version History](#-version-history)

[⬅️ Back to Index](./index.md)

> [!TIP]
> Run with `--verbose` flag to see detailed configuration output.

---

## 📌 Script Metadata

| Property          | PowerShell          | Bash               |
| ----------------- | ------------------- | ------------------ |
| **File Name**     | `postprovision.ps1` | `postprovision.sh` |
| **Version**       | 2.0.1               | 2.0.1              |
| **Last Modified** | 2026-01-06          | 2026-01-06         |
| **Author**        | Azure DevOps Team   | Azure DevOps Team  |

---

## 🔧 Prerequisites

| Requirement         | Minimum Version | Notes                       |
| ------------------- | --------------- | --------------------------- |
| PowerShell Core     | 7.0             | Required for `.ps1` script  |
| Bash                | 4.0             | Required for `.sh` script   |
| .NET SDK            | 10.0            | For user secrets management |
| Azure CLI           | 2.50+           | For Azure authentication    |
| Azure Developer CLI | Any             | Sets environment variables  |

---

## 📥 Parameters

### PowerShell (`postprovision.ps1`)

| Parameter | Type   | Required | Default  | Description                                     |
| --------- | ------ | -------- | -------- | ----------------------------------------------- |
| `-Force`  | Switch | No       | `$false` | Skips confirmation prompts and forces execution |

### Bash (`postprovision.sh`)

| Parameter   | Type | Required | Default | Description                                          |
| ----------- | ---- | -------- | ------- | ---------------------------------------------------- |
| `--force`   | Flag | No       | `false` | Skip confirmation prompts and force execution        |
| `--verbose` | Flag | No       | `false` | Enable verbose output for debugging                  |
| `--dry-run` | Flag | No       | `false` | Show what the script would do without making changes |
| `--help`    | Flag | No       | N/A     | Display help message                                 |

---

## 🌐 Environment Variables

### Required Variables (Set by azd)

| Variable                | Source      | Description                                  |
| ----------------------- | ----------- | -------------------------------------------- |
| `AZURE_SUBSCRIPTION_ID` | azd outputs | Azure subscription GUID                      |
| `AZURE_RESOURCE_GROUP`  | azd outputs | Resource group containing deployed resources |
| `AZURE_LOCATION`        | azd outputs | Azure region where resources are deployed    |

### Optional Variables (Set by azd outputs)

| Variable                            | Source      | Description                            |
| ----------------------------------- | ----------- | -------------------------------------- |
| `AZURE_CONTAINER_REGISTRY_NAME`     | azd outputs | ACR name for container authentication  |
| `AZURE_CONTAINER_REGISTRY_ENDPOINT` | azd outputs | ACR endpoint URL                       |
| `SERVICE_BUS_NAMESPACE`             | azd outputs | Service Bus namespace name             |
| `SERVICE_BUS_CONNECTION_STRING`     | azd outputs | Service Bus connection string          |
| `SQL_SERVER_NAME`                   | azd outputs | Azure SQL Server name                  |
| `SQL_DATABASE_NAME`                 | azd outputs | Azure SQL Database name                |
| `MANAGED_IDENTITY_NAME`             | azd outputs | Managed identity name for SQL access   |
| `APP_INSIGHTS_CONNECTION_STRING`    | azd outputs | Application Insights connection string |

---

## 🔄 Execution Flow

```mermaid
flowchart TD
    A[🚀 Start postprovision] --> B[Initialize Execution Timer]
    B --> C{Validate Required Env Vars}

    C -->|Missing| Z[❌ Exit with Error]
    C -->|Valid| D[Display Configuration Summary]

    D --> E{ACR Configured?}
    E -->|Yes| F[Authenticate to ACR]
    E -->|No| G[Skip ACR Auth]

    F --> H[Clear Existing User Secrets]
    G --> H

    H --> I[Configure User Secrets]

    I --> J[Set AZURE_SUBSCRIPTION_ID]
    J --> K[Set AZURE_RESOURCE_GROUP]
    K --> L[Set AZURE_LOCATION]
    L --> M[Set Service Connection Strings]

    M --> N{SQL Server Configured?}
    N -->|Yes| O[Configure SQL Managed Identity]
    N -->|No| P[Skip SQL Config]

    O --> Q[Display Success Summary]
    P --> Q

    Q --> R[Report Execution Statistics]
    R --> S[✅ Post-provisioning Complete]
    S --> T[🏁 End]
```

---

## 📝 Usage Examples

### PowerShell

```powershell
# Standard post-provisioning with default settings
.\postprovision.ps1

# Post-provisioning with verbose output for debugging
.\postprovision.ps1 -Verbose

# Show what the script would do without making changes
.\postprovision.ps1 -WhatIf
```

### Bash

```bash
# Standard post-provisioning with default settings
./postprovision.sh

# Post-provisioning with verbose output for debugging
./postprovision.sh --verbose

# Show what the script would do without making changes
./postprovision.sh --dry-run
```

---

## ⚠️ Exit Codes

| Code | Meaning                                                                  |
| ---- | ------------------------------------------------------------------------ |
| `0`  | Success - all secrets configured successfully                            |
| `1`  | Failure - missing required environment variables or configuration errors |

---

## 📊 Output Statistics

The script tracks and reports:

- Total number of secrets to configure
- Successfully configured secrets count
- Skipped secrets count (empty values)
- Failed secret configuration attempts
- Total execution time

---

## 📚 Related Scripts

| Script                                                          | Purpose                                      |
| --------------------------------------------------------------- | -------------------------------------------- |
| [preprovision](./preprovision.md)                               | Runs before infrastructure provisioning      |
| [clean-secrets](./clean-secrets.md)                             | Called to clear existing secrets             |
| [sql-managed-identity-config](./sql-managed-identity-config.md) | Called for SQL database access configuration |

---

## 📜 Version History

| Version | Date       | Changes                                          |
| ------- | ---------- | ------------------------------------------------ |
| 2.0.1   | 2026-01-06 | Enhanced error handling and execution statistics |
| 2.0.0   | 2025-11-01 | Added SQL managed identity configuration         |
| 1.5.0   | 2025-09-15 | Added ACR authentication support                 |
| 1.0.0   | 2025-08-15 | Initial release                                  |

> [!IMPORTANT]
> Ensure all required environment variables are set by `azd provision` before running this script.

## 🔗 Links

- [Repository](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [.NET User Secrets Documentation](https://learn.microsoft.com/aspnet/core/security/app-secrets)

---

<div align="center">

**[⬆️ Back to Top](#%EF%B8%8F-postprovision)** · **[← preprovision](./preprovision.md)** · **[postinfradelete →](./postinfradelete.md)**

## </div>

[⬅️ Back to Index](./index.md)
