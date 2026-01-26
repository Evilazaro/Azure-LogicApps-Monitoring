# 📋 clean-secrets Hook

Clears .NET user secrets for all projects in the solution to ensure a clean configuration state.

---

## 📖 Overview

| Property | Value |
|----------|-------|
| **Hook Name** | clean-secrets |
| **Version** | 2.0.1 |
| **Execution Phase** | Manual / Called by preprovision |
| **Author** | Evilazaro \| Principal Cloud Solution Architect \| Microsoft |

The `clean-secrets` hook clears all .NET user secrets from configured projects to ensure a clean state. This is useful before re-provisioning or when troubleshooting configuration issues.

---

## ⚙️ Prerequisites

### Required Tools

| Tool | Minimum Version | Purpose |
|------|-----------------|---------|
| PowerShell | 7.0+ | Script execution (Windows/cross-platform) |
| Bash | 4.0+ | Script execution (Linux/macOS) |
| .NET SDK | 10.0+ | User secrets management |

### Required Permissions

- Write access to user profile directory (for user secrets storage)

---

## 🔧 Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Force` | Switch | No | `$false` | Skip confirmation prompts |
| `-WhatIf` | Switch | No | `$false` | Preview changes without executing |
| `-Verbose` | Switch | No | `$false` | Enable detailed output |

### Bash Arguments

| Argument | Required | Default | Description |
|----------|----------|---------|-------------|
| `-f`, `--force` | No | `false` | Skip confirmation prompts |
| `-n`, `--dry-run` | No | `false` | Preview changes without executing |
| `-v`, `--verbose` | No | `false` | Enable verbose output |
| `-h`, `--help` | No | - | Display help message |

---

## 🌍 Environment Variables

### Variables Read

This hook does not read environment variables.

### Variables Set

This hook does not set environment variables.

---

## 📝 Functionality

The clean-secrets script performs these operations:

1. **.NET SDK Validation**
   - Verifies .NET SDK is installed and accessible
   - Validates SDK version meets minimum requirements (10.0+)
   - Exits with error if SDK is not available

2. **Project Path Resolution**
   - Resolves paths to configured projects relative to script location
   - Validates each project directory exists

3. **User Secrets Clearing**
   - Clears secrets for each configured project:
     - `app.AppHost`
     - `eShop.Orders.API`
     - `eShop.Web.App`
   - Uses `dotnet user-secrets clear` command
   - Tracks success/failure for each project

4. **Summary Report**
   - Displays count of successful operations
   - Reports any failures encountered
   - Shows execution duration

### Projects Configured

| Project | Path | Description |
|---------|------|-------------|
| app.AppHost | `../app.AppHost/` | .NET Aspire AppHost project |
| eShop.Orders.API | `../src/eShop.Orders.API/` | Orders API service |
| eShop.Web.App | `../src/eShop.Web.App/` | Web application frontend |

---

## 🔄 Execution Flow

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

    A([Start clean-secrets]) -->|begin| B[Parse Arguments]
    B -->|setup| C[Initialize Counters]
    C -->|setup| D[Set Strict Mode]

    %% ===== SDK VALIDATION =====
    subgraph SdkValidation[".NET SDK Validation"]
        direction TB
        D -->|check| E{dotnet Command<br/>Available?}
        E -->|No| F[Display SDK Not Found]
        F -->|exit| G([Exit 1])
        E -->|Yes| H[Get SDK Version]
        H -->|validate| I{Version >= 10.0?}
        I -->|No| J[Display Version Error]
        J -->|exit| G
        I -->|Yes| K[SDK Valid ✓]
    end

    %% ===== CONFIRMATION =====
    subgraph Confirmation["User Confirmation"]
        direction TB
        K -->|check| L{Force Mode<br/>Enabled?}
        L -->|No| M{Dry Run<br/>Mode?}
        M -->|No| N[Display Warning]
        N -->|prompt| O{User<br/>Confirms?}
        O -->|No| P[Operation Cancelled]
        P -->|exit| Q([Exit 0])
        O -->|Yes| R[Proceed with Clear]
        L -->|Yes| R
        M -->|Yes| S[Dry Run Mode Active]
    end

    %% ===== PROJECT PROCESSING =====
    subgraph ProjectLoop["Project Processing Loop"]
        direction TB
        R -->|start| T[Get Project List]
        S -->|start| T
        T -->|iterate| U[Get Next Project]
        U -->|resolve| V[Resolve Project Path]
        V -->|validate| W{Project Path<br/>Exists?}
        W -->|No| X[Log Path Not Found]
        X -->|increment| Y[Increment Failure Count]
        W -->|Yes| Z{Dry Run<br/>Mode?}
        Z -->|Yes| AA[Display Would Clear]
        Z -->|No| AB[[dotnet user-secrets clear]]
        AB -->|result| AC{Clear<br/>Successful?}
        AC -->|No| AD[Log Clear Error]
        AD -->|increment| Y
        AC -->|Yes| AE[Log Success]
        AE -->|increment| AF[Increment Success Count]
        Y -->|check| AG{More<br/>Projects?}
        AF -->|check| AG
        AA -->|check| AG
        AG -->|Yes| U
        AG -->|No| AH[Processing Complete]
    end

    %% ===== SUMMARY =====
    subgraph Summary["Completion Summary"]
        direction TB
        AH -->|summarize| AI[Calculate Duration]
        AI -->|display| AJ[Show Success Count]
        AJ -->|display| AK[Show Failure Count]
        AK -->|check| AL{Any<br/>Failures?}
        AL -->|Yes| AM([Exit 1])
        AL -->|No| AN([Exit 0])
    end

    %% ===== SUBGRAPH STYLES =====
    style SdkValidation fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Confirmation fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
    style ProjectLoop fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style Summary fill:#ECFDF5,stroke:#10B981,stroke-width:2px

    %% ===== NODE CLASS ASSIGNMENTS =====
    class A,Q,AN trigger
    class B,C,D,H,N,T,U,V,AA,AI,AJ,AK primary
    class K,R,AE,AF,AH secondary
    class E,I,L,M,O,W,Z,AC,AG,AL decision
    class F,J,X,AD,Y input
    class G,AM failed
    class AB external
```

---

## 💻 Usage Examples

### PowerShell

```powershell
# Standard execution with confirmation
.\hooks\clean-secrets.ps1

# Force execution without confirmation
.\hooks\clean-secrets.ps1 -Force

# Preview what would be cleared
.\hooks\clean-secrets.ps1 -WhatIf

# Verbose output with force
.\hooks\clean-secrets.ps1 -Force -Verbose
```

### Bash

```bash
# Standard execution with confirmation
./hooks/clean-secrets.sh

# Force execution without confirmation
./hooks/clean-secrets.sh --force

# Preview what would be cleared
./hooks/clean-secrets.sh --dry-run

# Verbose output with force
./hooks/clean-secrets.sh --force --verbose
```

---

## 🔀 Platform Differences

| Feature | PowerShell | Bash |
|---------|------------|------|
| Confirmation | `ShouldProcess` with `ConfirmImpact='High'` | Interactive prompt |
| Dry run | `-WhatIf` common parameter | `--dry-run` flag |
| Project config | `$script:Projects` hashtable array | Associative array `PROJECTS` |
| Path resolution | `Join-Path` + `GetFullPath` | `cd` + `pwd` |

---

## 🚪 Exit Codes

| Code | Description |
|------|-------------|
| `0` | Success - All secrets cleared or dry run completed |
| `1` | Error - SDK validation failed or clear operation failed |
| `130` | Script interrupted by user (Ctrl+C) |

---

## 🔗 Related Hooks

- [preprovision](preprovision.md) - Calls clean-secrets during pre-provisioning
- [postprovision](postprovision.md) - Calls clean-secrets before configuring new secrets

---

## 📋 Typical Output

### Successful Execution

```
═══════════════════════════════════════════════════════════
  Clean User Secrets v2.0.1
═══════════════════════════════════════════════════════════

Validating .NET SDK...
  ✓ .NET SDK 10.0.100 detected

Clearing user secrets for 3 projects...

[1/3] app.AppHost
  Path: /app/app.AppHost/
  ✓ User secrets cleared

[2/3] eShop.Orders.API
  Path: /app/src/eShop.Orders.API/
  ✓ User secrets cleared

[3/3] eShop.Web.App
  Path: /app/src/eShop.Web.App/
  ✓ User secrets cleared

═══════════════════════════════════════════════════════════
  Summary
═══════════════════════════════════════════════════════════
  Total projects:  3
  Successful:      3
  Failed:          0
  Duration:        1.2 seconds
═══════════════════════════════════════════════════════════
```

### Dry Run Output

```
═══════════════════════════════════════════════════════════
  Clean User Secrets v2.0.1 (DRY RUN)
═══════════════════════════════════════════════════════════

The following operations would be performed:

[1/3] Would clear secrets for: app.AppHost
      Path: /app/app.AppHost/

[2/3] Would clear secrets for: eShop.Orders.API
      Path: /app/src/eShop.Orders.API/

[3/3] Would clear secrets for: eShop.Web.App
      Path: /app/src/eShop.Web.App/

═══════════════════════════════════════════════════════════
  No changes made (dry run mode)
═══════════════════════════════════════════════════════════
```

---

**Last Modified:** 2026-01-26
