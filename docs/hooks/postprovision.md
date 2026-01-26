---
title: "postprovision Hook"
description: "Post-provisioning script that configures .NET user secrets with Azure resource information"
author: "Azure DevOps Team"
date: "January 2026"
version: "2.0.1"
tags: ["postprovision", "user-secrets", "configuration", "azd", "sql-database"]
---

# 🚀 postprovision

> [!NOTE]
> **Target Audience**: DevOps Engineers, Backend Developers  
> **Reading Time**: ~10 minutes

<details>
<summary>📖 Navigation</summary>

| Previous | Index | Next |
|:---------|:-----:|-----:|
| [preprovision](preprovision.md) | [📚 Index](README.md) | [postinfradelete](postinfradelete.md) |

</details>

Post-provisioning script for Azure Developer CLI (azd).

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [⚙️ Prerequisites](#️-prerequisites)
- [🎯 Parameters](#-parameters)
- [🌐 Environment Variables](#-environment-variables)
- [⚙️ Functionality](#️-functionality)
- [📖 Usage Examples](#-usage-examples)
- [💻 Platform Differences](#-platform-differences)
- [🚪 Exit Codes](#-exit-codes)
- [🔗 Related Hooks](#-related-hooks)

## 📋 Overview

Configures .NET user secrets with Azure resource information after infrastructure provisioning completes. This script is automatically executed by `azd` after `azd provision` or `azd up`.

### 🔑 Key Operations

- Validates required environment variables from azd
- Authenticates to Azure Container Registry (if configured)
- Clears existing .NET user secrets
- Configures new user secrets with Azure resource information
- Configures SQL Database managed identity access

### 📅 When Executed

- **Automatically**: After `azd provision` or `azd up` completes successfully
- **Manually**: When needing to reconfigure local development secrets

## ⚙️ Prerequisites

### 🔧 Required Tools

| Tool | Minimum Version | Purpose |
|:-----|:---------------:|:--------|
| PowerShell Core | 7.0+ | Script execution (PowerShell version) |
| Bash | 4.0+ | Script execution (Bash version) |
| .NET SDK | 10.0+ | User secrets management |
| Azure CLI (az) | 2.50+ | Azure authentication |
| Azure Developer CLI (azd) | Latest | Environment variable source |

### 🔐 Required Permissions

- **Azure CLI**: Must be authenticated (`az login`)
- **Container Registry**: `AcrPull` role (if ACR is configured)
- **SQL Database**: Entra ID admin on SQL Server (for managed identity config)

## 🎯 Parameters

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:-------:|:------------|
| `-Force` | Switch | No | `$false` | Skip confirmation prompts and force execution |
| `-Verbose` | Switch | No | `$false` | Enable verbose diagnostic output |
| `-WhatIf` | Switch | No | `$false` | Show what would be done without making changes |

### Bash Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:-------:|:------------|
| `--force` | Flag | No | `false` | Skip confirmation prompts and force execution |
| `--verbose` | Flag | No | `false` | Enable verbose diagnostic output |
| `--dry-run` | Flag | No | `false` | Show what would be done without making changes |
| `--help` | Flag | No | N/A | Display help message and exit |

## 🌐 Environment Variables

### Variables Read (Required)

| Variable | Description | Set By |
|:---------|:------------|:------:|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription GUID | azd |
| `AZURE_RESOURCE_GROUP` | Resource group name | azd |
| `AZURE_LOCATION` | Azure region | azd |

### Variables Read (Optional)

| Variable | Description | Default |
|:---------|:------------|:-------:|
| `CONTAINER_REGISTRY_NAME` | ACR name for authentication | None |
| `CONTAINER_REGISTRY_ENDPOINT` | ACR login server URL | None |
| `SQL_SERVER_NAME` | Azure SQL Server name | None |
| `SQL_DATABASE_NAME` | SQL Database name | None |
| `MANAGED_IDENTITY_NAME` | User-assigned managed identity name | None |
| `SERVICE_BUS_NAMESPACE` | Service Bus namespace | None |
| `STORAGE_ACCOUNT_NAME` | Storage account name | None |
| `APP_INSIGHTS_CONNECTION_STRING` | Application Insights connection string | None |
| `KEY_VAULT_URI` | Key Vault URI | None |

### Variables Set

This script configures .NET user secrets (not environment variables):

| Secret Key | Source Variable |
|:-----------|:----------------|
| `Azure:SubscriptionId` | `AZURE_SUBSCRIPTION_ID` |
| `Azure:ResourceGroup` | `AZURE_RESOURCE_GROUP` |
| `Azure:Location` | `AZURE_LOCATION` |
| `ConnectionStrings:SqlDatabase` | Constructed from SQL variables |
| `ConnectionStrings:ServiceBus` | Constructed from Service Bus variables |
| `Azure:ContainerRegistry` | `CONTAINER_REGISTRY_ENDPOINT` |
| (and others based on provisioned resources) |

## ⚙️ Functionality

### 🔄 Execution Flow

```mermaid
---
title: postprovision Execution Flow
---
flowchart TD
    %% ===== CLASS DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== INITIALIZATION =====
    A([Start]) -->|begin| B[Parse Arguments]
    B -->|initialize| C[Record Start Time]
    
    %% ===== ENVIRONMENT VALIDATION =====
    subgraph EnvValidation["Environment Validation"]
        C -->|load| D[Load Required Environment Variables]
        D -->|check| E{AZURE_SUBSCRIPTION_ID<br/>Set?}
        E -->|No| F[Error: Missing Variable]
        F -->|terminate| G([Exit 1])
        E -->|Yes| H{AZURE_RESOURCE_GROUP<br/>Set?}
        H -->|No| F
        H -->|Yes| I{AZURE_LOCATION<br/>Set?}
        I -->|No| F
        I -->|Yes| J[Environment Valid ✓]
    end
    
    %% ===== ACR AUTHENTICATION =====
    subgraph ACRAuth["ACR Authentication"]
        J -->|check| K{ACR Endpoint<br/>Configured?}
        K -->|No| L[Skip ACR Login]
        K -->|Yes| M{Azure CLI<br/>Installed?}
        M -->|No| N[Warning: Skip ACR]
        N -->|skip| L
        M -->|Yes| O[az acr login]
        O -->|verify| P{Login<br/>Successful?}
        P -->|No| Q[Warning: ACR Failed]
        Q -->|continue| L
        P -->|Yes| R[ACR Authenticated ✓]
        R -->|continue| L
    end
    
    %% ===== CLEAR EXISTING SECRETS =====
    subgraph ClearSecrets["Clear Existing Secrets"]
        L -->|check| S{Dry Run<br/>Mode?}
        S -->|Yes| T[Skip Secret Operations]
        S -->|No| U[Clear Existing Secrets]
        U -->|execute| V[dotnet user-secrets clear]
    end
    
    %% ===== CONFIGURE APPHOST SECRETS =====
    subgraph AppHostSecrets["Configure AppHost Secrets"]
        V -->|locate| W[Get AppHost Project Path]
        W -->|configure| X[Set Azure Configuration Secrets]
        X -->|configure| Y[Set Container Registry Secrets]
        Y -->|configure| Z[Set App Insights Secrets]
        Z -->|configure| AA[Set Managed Identity Secrets]
    end
    
    %% ===== CONFIGURE API SECRETS =====
    subgraph APISecrets["Configure API Secrets"]
        AA -->|locate| AB[Get API Project Path]
        AB -->|configure| AC[Set SQL Connection Secrets]
        AC -->|configure| AD[Set Service Bus Secrets]
        AD -->|configure| AE[Set App Insights Secrets]
    end
    
    %% ===== CONFIGURE WEB APP SECRETS =====
    subgraph WebAppSecrets["Configure Web App Secrets"]
        AE -->|locate| AF[Get Web App Project Path]
        AF -->|configure| AG[Set App Insights Secrets]
        AG -->|configure| AH[Set API Endpoint Secrets]
    end
    
    %% ===== SQL CONFIGURATION =====
    subgraph SQLConfig["SQL Configuration"]
        AH -->|check| AI{SQL Server<br/>Deployed?}
        AI -->|No| AJ[Skip SQL Config]
        AI -->|Yes| AK{Managed Identity<br/>Available?}
        AK -->|No| AJ
        AK -->|Yes| AL[Call sql-managed-identity-config]
        AL -->|verify| AM{Config<br/>Successful?}
        AM -->|No| AN[Warning: SQL Config Failed]
        AN -->|continue| AJ
        AM -->|Yes| AO[SQL Configured ✓]
        AO -->|continue| AJ
    end
    
    T -->|summarize| AP[Display Summary]
    AJ -->|summarize| AP
    AP -->|calculate| AQ[Calculate Duration]
    AQ -->|report| AR[Display Statistics]
    AR -->|complete| AS([Exit 0])

    %% ===== SUBGRAPH STYLES =====
    style EnvValidation fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style ACRAuth fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style ClearSecrets fill:#FEE2E2,stroke:#F44336,stroke-width:2px
    style AppHostSecrets fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style APISecrets fill:#D1FAE5,stroke:#10B981,stroke-width:1px
    style WebAppSecrets fill:#D1FAE5,stroke:#059669,stroke-width:1px
    style SQLConfig fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== NODE CLASS ASSIGNMENTS =====
    class A,AS trigger
    class B,C,D,W,X,Y,Z,AA,AB,AC,AD,AE,AF,AG,AH,AP,AQ,AR primary
    class J,R,AO secondary
    class E,H,I,K,M,P,S,AI,AK,AM decision
    class F,N,Q,AN,T input
    class O,U,V,AL external
    class G failed
```

### 📂 Configured Projects

| Project | Path | Description |
|:--------|:-----|:------------|
| `app.AppHost` | `./app.AppHost/` | .NET Aspire AppHost orchestration |
| `eShop.Orders.API` | `./src/eShop.Orders.API/` | Orders REST API |
| `eShop.Web.App` | `./src/eShop.Web.App/` | Blazor web application |

### 🔐 User Secrets Structure

```json
{
  "Azure": {
    "SubscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "ResourceGroup": "rg-logicapps-monitoring-dev",
    "Location": "eastus2"
  },
  "ConnectionStrings": {
    "SqlDatabase": "Server=tcp:sql-xxx.database.windows.net;Database=orders;...",
    "ServiceBus": "Endpoint=sb://sb-xxx.servicebus.windows.net/;..."
  }
}
```

### ⚠️ Error Handling

- **Required Variable Validation**: Fails fast if required environment variables are missing
- **Project Path Validation**: Verifies project directories exist before configuring
- **Secret Set Errors**: Reports failures but continues with remaining secrets
- **Summary Statistics**: Reports total, succeeded, skipped, and failed counts

## 📖 Usage Examples

### PowerShell

```powershell
# Standard post-provisioning (usually run by azd automatically)
.\postprovision.ps1

# Force execution without prompts
.\postprovision.ps1 -Force

# Verbose output for debugging
.\postprovision.ps1 -Verbose

# Show what would be configured without making changes
.\postprovision.ps1 -WhatIf
```

### Bash

```bash
# Standard post-provisioning
./postprovision.sh

# Force execution without prompts
./postprovision.sh --force

# Verbose output for debugging
./postprovision.sh --verbose

# Show what would be configured
./postprovision.sh --dry-run

# Display help
./postprovision.sh --help
```

### 📝 Sample Output

```
═══════════════════════════════════════════════════════════════
  Azure Logic Apps Monitoring - Post-Provisioning
  Version: 2.0.1
═══════════════════════════════════════════════════════════════

───────────────────────────────────────────────────────────────
  Environment Variables
───────────────────────────────────────────────────────────────

✓ AZURE_SUBSCRIPTION_ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
✓ AZURE_RESOURCE_GROUP: rg-logicapps-monitoring-dev
✓ AZURE_LOCATION: eastus2

───────────────────────────────────────────────────────────────
  Azure Container Registry Authentication
───────────────────────────────────────────────────────────────

✓ Authenticated to ACR: crlogicappsdev.azurecr.io

───────────────────────────────────────────────────────────────
  Configuring User Secrets
───────────────────────────────────────────────────────────────

Configuring: app.AppHost
  ✓ Azure:SubscriptionId
  ✓ Azure:ResourceGroup
  ✓ Azure:Location
  ✓ ConnectionStrings:SqlDatabase
  ✓ ConnectionStrings:ServiceBus

Configuring: eShop.Orders.API
  ✓ Azure:SubscriptionId
  ✓ ConnectionStrings:SqlDatabase
  ✓ ConnectionStrings:ServiceBus

Configuring: eShop.Web.App
  ✓ Azure:SubscriptionId
  ✓ Azure:Location

───────────────────────────────────────────────────────────────
  SQL Managed Identity Configuration
───────────────────────────────────────────────────────────────

✓ Configured managed identity access for sql-logicapps-dev/orders

═══════════════════════════════════════════════════════════════
  Post-Provisioning Summary
═══════════════════════════════════════════════════════════════

Total secrets: 15
  ✓ Succeeded: 15
  ○ Skipped: 0
  ✗ Failed: 0

✓ Post-provisioning completed successfully
```

## 💻 Platform Differences

| Aspect | PowerShell | Bash |
|:-------|:-----------|:-----|
| Secrets command | `dotnet user-secrets set` | `dotnet user-secrets set` |
| Dry-run support | `-WhatIf` (native) | `--dry-run` (custom) |
| Color output | `Write-Host -ForegroundColor` | ANSI escape codes |
| JSON parsing | `ConvertFrom-Json` | `jq` |
| Path resolution | `Join-Path` | String concatenation |

## 🚪 Exit Codes

| Code | Meaning |
|:----:|:--------|
| `0` | Success - all secrets configured successfully |
| `1` | General error - missing required environment variables or unexpected failure |
| `130` | Script interrupted by user (SIGINT) |

## 🔗 Related Hooks

| Hook | Relationship |
|:-----|:-------------|
| [preprovision](preprovision.md) | Runs before provisioning; clears secrets that this script will set |
| [sql-managed-identity-config](sql-managed-identity-config.md) | Called by this script for SQL Database configuration |
| [clean-secrets](clean-secrets.md) | Logic shared for clearing secrets |

## 🔧 Troubleshooting

### ⚠️ Common Issues

1. **"Required environment variable not set"**
   - Ensure you're running through `azd provision` or `azd up`
   - If running manually, export the required variables first

2. **"Project file not found"**
   - Verify the project structure matches expected paths
   - Ensure you're running from the repository root

3. **"ACR authentication failed"**
   - Run `az login` to authenticate
   - Verify you have `AcrPull` role on the registry

4. **"SQL managed identity configuration failed"**
   - Ensure you're an Entra ID admin on the SQL Server
   - Check firewall rules allow your IP address

---

<div align="center">

**[← preprovision](preprovision.md)** · **[⬆️ Back to Top](#-postprovision)** · **[postinfradelete →](postinfradelete.md)**

</div>

**Version**: 2.0.1  
**Author**: Azure DevOps Team  
**Last Modified**: January 2026
