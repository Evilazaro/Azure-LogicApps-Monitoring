---
title: clean-secrets Script Documentation
description: Clears .NET user secrets for all projects in the Azure Logic Apps Monitoring solution to ensure clean configuration state
name: clean-secrets
version: 2.0.1
author: Evilazaro | Principal Cloud Solution Architect | Microsoft
date: 2026-01-26
last_modified: 2026-01-06
license: MIT
languages: [PowerShell, Bash]
tags: [secrets, dotnet, user-secrets, cleanup, configuration, security]
---

# 🧹 clean-secrets

> [!NOTE]
> **Target Audience:** Developers, DevOps Engineers  
> **Estimated Reading Time:** 7 minutes

<details>
<summary>📍 <strong>Navigation</strong></summary>
<br>

| Previous | Index | Next |
|:---------|:-----:|-----:|
| [postinfradelete](postinfradelete.md) | [📑 Index](README.md) | [configure-federated-credential](configure-federated-credential.md) |

</details>

---

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [📝 Description](#-description)
- [📊 Workflow Diagram](#-workflow-diagram)
- [✅ Prerequisites](#-prerequisites)
- [⚙️ Parameters/Arguments](#️-parametersarguments)
- [📥 Input/Output Specifications](#-inputoutput-specifications)
- [💻 Usage Examples](#-usage-examples)
- [⚠️ Error Handling and Exit Codes](#️-error-handling-and-exit-codes)
- [🔒 Security Considerations](#-security-considerations)
- [🚧 Known Limitations](#-known-limitations)
- [🔗 Related Scripts](#-related-scripts)
- [📜 Changelog](#-changelog)

---

## 📋 Overview

Clears .NET user secrets for all projects in the Azure Logic Apps Monitoring solution to ensure a clean configuration state before re-provisioning or troubleshooting.

[⬆️ Back to top](#-clean-secrets)

---

## 📝 Description

This utility script clears all .NET user secrets from the configured projects in the solution. User secrets in .NET provide a way to store sensitive configuration data outside of the project tree, but these secrets can become stale or misconfigured over time, leading to application issues.

The script targets three specific projects: `app.AppHost` (the Aspire application host), `eShop.Orders.API` (the orders REST API), and `eShop.Web.App` (the web frontend). For each project, it validates that the project path exists, then executes `dotnet user-secrets clear` to remove all stored secrets.

This script is typically called by the preprovision script but can also be run standalone when troubleshooting configuration issues or preparing for a fresh deployment. The script includes comprehensive validation, detailed logging, and execution statistics to provide visibility into the cleanup operation.

[⬆️ Back to top](#-clean-secrets)

---

## 📊 Workflow Diagram

```mermaid
---
title: Clean Secrets Script Execution Flow
---
flowchart TD
    %% ===== INITIALIZATION PHASE =====
    subgraph Initialization["🚀 Initialization"]
        direction TB
        Start(["▶️ Start"]) -->|parses| ParseArgs["Parse Arguments"]
        ParseArgs -->|validates| ValidateDotNet["Validate .NET SDK"]
        ValidateDotNet -->|checks| DotNetAvail{"NET Available?"}
        DotNetAvail -->|yes| LoadConfig["Load Project Config"]
        DotNetAvail -->|no| ExitError(["❌ Exit with Error"])
    end
    
    %% ===== CONFIRMATION PHASE =====
    subgraph Confirmation["⚠️ User Confirmation"]
        direction TB
        LoadConfig -->|checks| ForceMode{"Force Mode?"}
        ForceMode -->|yes| SkipConfirm["Skip Confirmation"]
        ForceMode -->|no| DryRun{"Dry Run Mode?"}
        DryRun -->|yes| SkipConfirm
        DryRun -->|no| UserConfirm{"User Confirms?"}
        UserConfirm -->|yes| SkipConfirm
        UserConfirm -->|no| Cancelled(["⏹️ Cancelled"])
    end
    
    %% ===== PROCESSING PHASE =====
    subgraph Processing["⚡ Project Processing"]
        direction TB
        SkipConfirm -->|begins| BeginLoop["Begin Project Loop"]
        BeginLoop -->|validates| ValidatePath{"Validate Project Path"}
        ValidatePath -->|valid| CheckDry{"Dry Run?"}
        ValidatePath -->|invalid| LogWarn["Log Warning"]
        CheckDry -->|yes| DisplayWould["Display Would Clear"]
        CheckDry -->|no| ClearSecrets["Clear User Secrets"]
        ClearSecrets -->|evaluates| ClearSuccess{"Clear Successful?"}
        ClearSuccess -->|yes| IncSuccess["Increment Success"]
        ClearSuccess -->|no| IncFailure["Increment Failure"]
        LogWarn -->|checks| MoreProjects{"More Projects?"}
        DisplayWould -->|checks| MoreProjects
        IncSuccess -->|checks| MoreProjects
        IncFailure -->|checks| MoreProjects
        MoreProjects -->|yes| BeginLoop
        MoreProjects -->|no| GenSummary["Generate Summary"]
    end
    
    %% ===== COMPLETION =====
    GenSummary -->|finishes| Complete(["✅ Complete"])
    
    %% ===== NODE STYLING =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5
    
    class Start,Complete trigger
    class ParseArgs,ValidateDotNet,LoadConfig,SkipConfirm,BeginLoop,DisplayWould,ClearSecrets,IncSuccess,GenSummary primary
    class DotNetAvail,ForceMode,DryRun,UserConfirm,ValidatePath,CheckDry,ClearSuccess,MoreProjects decision
    class ExitError,IncFailure failed
    class LogWarn,Cancelled external
    
    %% ===== SUBGRAPH STYLING =====
    style Initialization fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Confirmation fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
    style Processing fill:#ECFDF5,stroke:#10B981,stroke-width:2px
```

[⬆️ Back to top](#-clean-secrets)

---

## ✅ Prerequisites

| Category | Requirement | Version | Verification Command | Required |
|:---------|:------------|:--------|:---------------------|:--------:|
| Runtime | PowerShell Core | >= 7.0 | `$PSVersionTable.PSVersion` | ✅ |
| Runtime | Bash | >= 4.0 | `bash --version` | ✅ |
| SDK | .NET SDK | >= 10.0 | `dotnet --version` | ✅ |

[⬆️ Back to top](#-clean-secrets)

---

## ⚙️ Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:-----|:--------:|:--------|:------------|
| `-Force` | `[switch]` | ❌ | `$false` | Skips confirmation prompts |
| `-WhatIf` | `[switch]` | ❌ | `$false` | Shows what would be cleared without making changes |
| `-Verbose` | `[switch]` | ❌ | `$false` | Displays detailed diagnostic information |

### Bash Arguments

| Position/Flag | Type | Required | Default | Description |
|:--------------|:-----|:--------:|:--------|:------------|
| `-f`, `--force` | flag | ❌ | `false` | Skip confirmation prompts and force execution |
| `-n`, `--dry-run` | flag | ❌ | `false` | Show what would be executed without making changes |
| `-v`, `--verbose` | flag | ❌ | `false` | Display detailed diagnostic information |
| `-h`, `--help` | flag | ❌ | N/A | Display help message and exit |

[⬆️ Back to top](#-clean-secrets)

---

## 📥 Input/Output Specifications

### Inputs

**Environment Variables Read:**

> [!NOTE]
> None required.

**Files/Paths Expected:**

- `../app.AppHost/` — AppHost project directory (relative to script)
- `../src/eShop.Orders.API/` — Orders API project directory
- `../src/eShop.Web.App/` — Web App project directory

### Outputs

**Exit Codes:**

| Exit Code | Meaning |
|:---------:|:--------|
| `0` | Success — All secrets cleared |
| `1` | Error — One or more operations failed |

**stdout Output:**

- Progress messages with timestamps
- Project validation status
- Clear operation results
- Execution summary with statistics

**Files Modified:**

- User secrets removed from `%APPDATA%\Microsoft\UserSecrets\` (Windows)
- User secrets removed from `~/.microsoft/usersecrets/` (macOS/Linux)

[⬆️ Back to top](#-clean-secrets)

---

## 💻 Usage Examples

### Basic Usage

```powershell
# PowerShell: Clear all user secrets with confirmation prompt
.\clean-secrets.ps1
```

```bash
# Bash: Clear all user secrets with confirmation prompt
./clean-secrets.sh
```

### Advanced Usage

```powershell
# PowerShell: Preview what would be cleared without making changes
.\clean-secrets.ps1 -WhatIf -Verbose

# PowerShell: Force clear without confirmation
.\clean-secrets.ps1 -Force
```

```bash
# Bash: Preview what would be cleared without making changes
./clean-secrets.sh --dry-run --verbose

# Bash: Force clear without confirmation
./clean-secrets.sh --force
```

### CI/CD Pipeline Usage

```yaml
# Azure DevOps Pipeline
- task: PowerShell@2
  displayName: 'Clear user secrets'
  inputs:
    targetType: 'filePath'
    filePath: '$(System.DefaultWorkingDirectory)/hooks/clean-secrets.ps1'
    arguments: '-Force'
    pwsh: true

# GitHub Actions
- name: Clear user secrets
  shell: bash
  run: |
    chmod +x ./hooks/clean-secrets.sh
    ./hooks/clean-secrets.sh --force
```

[⬆️ Back to top](#-clean-secrets)

---

## ⚠️ Error Handling and Exit Codes

| Exit Code | Meaning | Recovery Action |
|:---------:|:--------|:----------------|
| `0` | Success | N/A |
| `1` | Error | Check project paths exist, verify .NET SDK |

### Error Handling Approach

**PowerShell:**

- `Set-StrictMode -Version Latest` for strict mode
- `$ErrorActionPreference = 'Stop'` for fail-fast
- `SupportsShouldProcess` for WhatIf support
- Continues processing remaining projects on individual failures

**Bash:**

- `set -euo pipefail` for strict error handling
- Trap handlers for cleanup and interrupt
- Success/failure counters for reporting
- Non-fatal errors logged but execution continues

[⬆️ Back to top](#-clean-secrets)

---

## 🔒 Security Considerations

### 🔑 Credential Handling

- [x] No hardcoded secrets
- [x] Removes stored credentials (intentional operation)
- [x] No network access required

### Required Permissions

| Permission/Role | Scope | Justification |
|:----------------|:------|:--------------|
| File System Write | User secrets directory | Remove secret files |

### 🌐 Network Security

| Property | Value |
|:---------|:------|
| **Endpoints accessed** | None |
| **TLS requirements** | N/A |
| **Firewall rules needed** | None |

### 📝 Logging Security

> [!TIP]
> **Security Features:**
>
> - **Sensitive data masking:** Secret values never logged (only cleared)
> - **Audit trail:** Timestamped operation logs

[⬆️ Back to top](#-clean-secrets)

---

## 🚧 Known Limitations

> [!WARNING]
> **Important Notes:**
>
> - Only clears secrets for predefined projects (not configurable)
> - Requires projects to have been initialized with user secrets
> - Cannot selectively clear individual secrets
> - Project paths are relative to script location
> - Does not validate secret content before clearing

[⬆️ Back to top](#-clean-secrets)

---

## 🔗 Related Scripts

| Script | Relationship | Description |
|:-------|:-------------|:------------|
| [preprovision.md](preprovision.md) | Called by | Pre-provisioning validation and setup |
| [postprovision.md](postprovision.md) | Related | Configures secrets after provisioning |
| [check-dev-workstation.md](check-dev-workstation.md) | Related | Workstation validation |

[⬆️ Back to top](#-clean-secrets)

---

## 📜 Changelog

| Version | Date | Changes |
|:-------:|:----:|:--------|
| 2.0.1 | 2026-01-06 | Improved error handling, added execution statistics |
| 2.0.0 | 2025-12-01 | Added dry-run support, enhanced logging |
| 1.0.0 | 2025-01-01 | Initial release |

[⬆️ Back to top](#-clean-secrets)

---

<div align="center">

**[⬅️ Previous: postinfradelete](postinfradelete.md)** · **[📑 Index](README.md)** · **[Next: configure-federated-credential ➡️](configure-federated-credential.md)**

</div>
