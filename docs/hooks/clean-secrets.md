---
title: "clean-secrets Hook"
description: "Clears .NET user secrets for all projects in the solution for a clean state"
author: "Evilazaro | Principal Cloud Solution Architect | Microsoft"
date: "January 2026"
version: "2.0.1"
tags: ["clean-secrets", "user-secrets", "dotnet", "configuration", "utility"]
---

# 🧹 clean-secrets

> [!NOTE]
> **Target Audience**: Developers, DevOps Engineers  
> **Reading Time**: ~8 minutes

<details>
<summary>📖 Navigation</summary>

| Previous | Index | Next |
|:---------|:-----:|-----:|
| [deploy-workflow](deploy-workflow.md) | [📚 Index](README.md) | [configure-federated-credential](configure-federated-credential.md) |

</details>

Clears .NET user secrets for all projects in the solution.

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

This script clears all .NET user secrets from the configured projects to ensure a clean state. This is useful before re-provisioning or when troubleshooting configuration issues.

### 🔑 Key Operations

- Validates .NET SDK availability and version
- Validates project paths and structure
- Clears user secrets for `app.AppHost` project
- Clears user secrets for `eShop.Orders.API` project
- Clears user secrets for `eShop.Web.App` project
- Provides comprehensive logging and execution statistics

### 📅 When to Use

- Before re-provisioning to ensure clean secret state
- When troubleshooting authentication/configuration issues
- When rotating credentials or connection strings
- As part of environment reset procedures

## ⚙️ Prerequisites

### 🔧 Required Tools

| Tool | Minimum Version | Purpose |
|:-----|:---------------:|:--------|
| PowerShell Core | 7.0+ | Script execution (PowerShell version) |
| Bash | 4.0+ | Script execution (Bash version) |
| .NET SDK | 10.0+ | User secrets management |

### 📂 Required Files

Projects must exist at expected paths relative to the script directory:

| Project | Relative Path |
|:--------|:--------------|
| `app.AppHost` | `../app.AppHost/` |
| `eShop.Orders.API` | `../src/eShop.Orders.API/` |
| `eShop.Web.App` | `../src/eShop.Web.App/` |

## 🎯 Parameters

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:-------:|:------------|
| `-Force` | Switch | No | `$false` | Skip confirmation prompts and force execution |
| `-Verbose` | Switch | No | `$false` | Display detailed diagnostic information |
| `-WhatIf` | Switch | No | `$false` | Show what would be cleared without making changes |

### Bash Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:-------:|:------------|
| `-f`, `--force` | Flag | No | `false` | Skip confirmation prompts and force execution |
| `-n`, `--dry-run` | Flag | No | `false` | Show what would be cleared without making changes |
| `-v`, `--verbose` | Flag | No | `false` | Display detailed diagnostic information |
| `-h`, `--help` | Flag | No | N/A | Display help message and exit |

## 🌐 Environment Variables

### Variables Read

This script does not require any environment variables.

### Variables Set

This script does not set any environment variables.

## ⚙️ Functionality

### 🔄 Execution Flow

```mermaid
---
title: clean-secrets Execution Flow
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
    B -->|setup| C[Initialize Statistics]
    
    %% ===== VALIDATION =====
    subgraph Validation["Validation"]
        C -->|check| D{.NET SDK<br/>Installed?}
        D -->|No| E[Error: .NET Not Found]
        E -->|terminate| F([Exit 1])
        D -->|Yes| G{.NET Version<br/>>= 10.0?}
        G -->|No| H[Error: Version Too Low]
        H -->|terminate| F
        G -->|Yes| I[.NET Validated ✓]
    end
    
    %% ===== PROJECT DISCOVERY =====
    subgraph ProjectDiscovery["Project Discovery"]
        I -->|build| J[Build Project Paths]
        J -->|resolve| K[app.AppHost Path]
        K -->|resolve| L[eShop.Orders.API Path]
        L -->|resolve| M[eShop.Web.App Path]
        M -->|collect| N[Create Project List]
    end
    
    %% ===== CONFIRMATION =====
    subgraph Confirmation["Confirmation"]
        N -->|check| O{Force Mode<br/>or Dry Run?}
        O -->|No| P[Display Projects to Clear]
        P -->|prompt| Q[Prompt for Confirmation]
        Q -->|verify| R{User<br/>Confirmed?}
        R -->|No| S[Operation Cancelled]
        S -->|exit| T([Exit 0])
        R -->|Yes| U[Proceed with Clear]
        O -->|Yes| U
    end
    
    %% ===== CLEAR SECRETS LOOP =====
    subgraph ClearSecretsLoop["Clear Secrets Loop"]
        U -->|iterate| V[For Each Project]
        V -->|check| W{Project Path<br/>Exists?}
        W -->|No| X[Log: Project Not Found]
        X -->|increment| Y[Increment Failure Count]
        Y -->|check| Z{More<br/>Projects?}
        
        W -->|Yes| AA{Dry Run<br/>Mode?}
        AA -->|Yes| AB[Log: Would Clear]
        AB -->|check| Z
        
        AA -->|No| AC[Execute dotnet user-secrets clear]
        AC -->|verify| AD{Clear<br/>Successful?}
        AD -->|No| AE[Log Error]
        AE -->|increment| Y
        AD -->|Yes| AF[Log Success]
        AF -->|increment| AG[Increment Success Count]
        AG -->|check| Z
        
        Z -->|Yes| V
        Z -->|No| AH[Generate Summary]
    end
    
    %% ===== SUMMARY =====
    subgraph Summary["Summary"]
        AH -->|display| AI[Display Statistics]
        AI -->|evaluate| AJ{Any<br/>Failures?}
        AJ -->|Yes| AK[Exit with Warning]
        AK -->|exit| AL([Exit 0 with warnings])
        AJ -->|No| AM[All Successful]
        AM -->|complete| AN([Exit 0])
    end

    %% ===== SUBGRAPH STYLES =====
    style Validation fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style ProjectDiscovery fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style Confirmation fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style ClearSecretsLoop fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style Summary fill:#F3F4F6,stroke:#6B7280,stroke-width:2px

    %% ===== NODE CLASS ASSIGNMENTS =====
    class A,AN,T trigger
    class B,C,J,K,L,M,N,P,Q,V,AC,AH,AI primary
    class I,AF,AG,AM secondary
    class D,G,O,R,W,AA,AD,AJ,Z decision
    class E,H,S,X,AE,AK,AB input
    class U external
    class AL datastore
    class F failed
```

### 💻 Clear Command

For each project, the script executes:

```bash
dotnet user-secrets clear --project <project-path>
```

This removes all secrets stored in the user secrets store for that project.

### 📂 User Secrets Storage Location

| Platform | Location |
|:---------|:---------|
| Windows | `%APPDATA%\Microsoft\UserSecrets\<user_secrets_id>\secrets.json` |
| Linux/macOS | `~/.microsoft/usersecrets/<user_secrets_id>/secrets.json` |

The `user_secrets_id` is defined in each project's `.csproj` file.

## 📖 Usage Examples

### PowerShell

```powershell
# Clear secrets with confirmation prompt
.\clean-secrets.ps1

# Clear secrets without confirmation
.\clean-secrets.ps1 -Force

# Show what would be cleared without making changes
.\clean-secrets.ps1 -WhatIf -Verbose

# Verbose output for troubleshooting
.\clean-secrets.ps1 -Verbose
```

### Bash

```bash
# Clear secrets with confirmation prompt
./clean-secrets.sh

# Clear secrets without confirmation
./clean-secrets.sh --force

# Show what would be cleared without making changes
./clean-secrets.sh --dry-run --verbose

# Display help
./clean-secrets.sh --help
```

### 📝 Sample Output

```
═══════════════════════════════════════════════════════════════
  Azure Logic Apps Monitoring - Clean User Secrets
  Version: 2.0.1
═══════════════════════════════════════════════════════════════

───────────────────────────────────────────────────────────────
  Prerequisites Validation
───────────────────────────────────────────────────────────────

✓ .NET SDK version 10.0.100 is installed

───────────────────────────────────────────────────────────────
  Project Validation
───────────────────────────────────────────────────────────────

✓ app.AppHost: ../app.AppHost/
✓ eShop.Orders.API: ../src/eShop.Orders.API/
✓ eShop.Web.App: ../src/eShop.Web.App/

───────────────────────────────────────────────────────────────
  Confirmation
───────────────────────────────────────────────────────────────

The following projects will have their user secrets cleared:
  • app.AppHost
  • eShop.Orders.API
  • eShop.Web.App

Are you sure you want to continue? [y/N]: y

───────────────────────────────────────────────────────────────
  Clearing User Secrets
───────────────────────────────────────────────────────────────

✓ Cleared user secrets for app.AppHost
✓ Cleared user secrets for eShop.Orders.API
✓ Cleared user secrets for eShop.Web.App

═══════════════════════════════════════════════════════════════
  Summary
═══════════════════════════════════════════════════════════════

Total projects: 3
  ✓ Succeeded: 3
  ✗ Failed: 0

Execution time: 2.3 seconds

✓ All user secrets cleared successfully
```

## 💻 Platform Differences

| Aspect | PowerShell | Bash |
|:-------|:-----------|:-----|
| Confirmation | `SupportsShouldProcess` | Interactive `read` prompt |
| WhatIf | Native `-WhatIf` | `--dry-run` flag |
| Path joining | `Join-Path` | String concatenation |
| Process execution | `&` operator | Direct command |

## 🚪 Exit Codes

| Code | Meaning |
|:----:|:--------|
| `0` | Success - all secrets cleared |
| `1` | Error - validation failed or secrets clear failed |
| `130` | Script interrupted by user (SIGINT) |

## 🔗 Related Hooks

| Hook | Relationship |
|:-----|:-------------|
| [preprovision](preprovision.md) | Calls this script to clear secrets before provisioning |
| [postprovision](postprovision.md) | Sets new secrets after this script clears them |

## 🔧 Troubleshooting

### ⚠️ Common Issues

1. **".NET SDK not found"**
   - Install .NET SDK 10.0+ from <https://dot.net>
   - Ensure `dotnet` is in your PATH

2. **"Project path not found"**
   - Verify the script is run from the repository root
   - Check that project directories exist at expected locations

3. **"User secrets clear failed"**
   - Verify the project has a valid `UserSecretsId` in its `.csproj`
   - Check file permissions on the secrets directory

### ✅ Verifying Secrets Are Cleared

After running the script, verify secrets are cleared:

```bash
# List secrets for a project (should show empty or error)
dotnet user-secrets list --project ./app.AppHost
```

---

<div align="center">

**[← deploy-workflow](deploy-workflow.md)** · **[⬆️ Back to Top](#-clean-secrets)** · **[configure-federated-credential →](configure-federated-credential.md)**

</div>

**Version**: 2.0.1  
**Author**: Evilazaro | Principal Cloud Solution Architect | Microsoft  
**Last Modified**: January 2026
