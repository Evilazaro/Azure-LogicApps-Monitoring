---
title: preprovision Script Documentation
description: Pre-provisioning script for Azure Developer CLI (azd) deployment that validates development environment and clears .NET user secrets
name: preprovision
version: 2.3.0
author: Evilazaro | Principal Cloud Solution Architect | Microsoft
date: 2026-01-26
last_modified: 2026-01-06
license: MIT
languages: [PowerShell, Bash]
tags: [azd, provisioning, validation, prerequisites, azure-cli, dotnet]
---

# 🚀 preprovision

> [!NOTE]
> **Target Audience:** DevOps Engineers, Cloud Architects, Developers  
> **Estimated Reading Time:** 12 minutes

<details>
<summary>📍 <strong>Navigation</strong></summary>
<br>

| Previous | Index | Next |
|:---------|:-----:|-----:|
| [README](README.md) | [📑 Index](README.md) | [postprovision](postprovision.md) |

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

Pre-provisioning script for Azure Developer CLI (azd) deployment that validates the development environment and clears .NET user secrets to ensure a clean state before Azure resources are provisioned.

[⬆️ Back to top](#-preprovision)

---

## 📝 Description

This script performs comprehensive pre-provisioning tasks before Azure infrastructure is deployed using Azure Developer CLI (azd). It serves as the first step in the deployment pipeline, ensuring that all prerequisites are met and the environment is properly configured.

The script validates multiple layers of dependencies including PowerShell/Bash version compatibility, .NET SDK availability, Azure Developer CLI (azd), Azure CLI with authentication, and Bicep CLI. It also validates Azure Resource Provider registrations and checks Azure subscription quotas to identify potential deployment blockers early.

When executed without the `--validate-only` flag, the script clears existing .NET user secrets to ensure a clean configuration state. This prevents stale secrets from interfering with the provisioning process. The script provides detailed logging, color-coded output for different message types, and comprehensive error handling with actionable recovery suggestions.

[⬆️ Back to top](#-preprovision)

---

## 📊 Workflow Diagram

```mermaid
---
title: Preprovision Script Execution Flow
---
flowchart TD
    %% ===== INITIALIZATION PHASE =====
    subgraph Initialization["🚀 Initialization"]
        direction TB
        Start(["▶️ Start"]) -->|begins| ParseArgs["Parse Command-Line Arguments"]
        ParseArgs -->|configures| InitLog["Initialize Logging"]
    end
    
    %% ===== VALIDATION PHASE =====
    subgraph Validation["✅ Prerequisites Validation"]
        direction TB
        InitLog -->|triggers| CheckShell{"Validate Shell Version"}
        CheckShell -->|pass| CheckDotNet{"Validate .NET SDK"}
        CheckShell -->|fail| ExitError(["❌ Exit with Error"])
        CheckDotNet -->|pass| CheckAzCLI{"Validate Azure CLI"}
        CheckDotNet -->|fail| ExitError
        CheckAzCLI -->|pass| CheckAuth{"Check Azure Authentication"}
        CheckAzCLI -->|fail| AutoInstall{"Auto-Install Enabled?"}
        AutoInstall -->|yes| InstallCLI["Install Azure CLI"]
        AutoInstall -->|no| ExitError
        InstallCLI -->|retries| CheckAzCLI
        CheckAuth -->|pass| CheckBicep{"Validate Bicep CLI"}
        CheckAuth -->|fail| PromptLogin["Prompt for Azure Login"]
        PromptLogin -->|retries| CheckAuth
        CheckBicep -->|pass| CheckAzd{"Validate azd CLI"}
        CheckBicep -->|fail| ExitError
        CheckAzd -->|pass| ValidateProviders["Validate Resource Providers"]
        CheckAzd -->|fail| ExitError
    end
    
    %% ===== RESOURCE VALIDATION PHASE =====
    subgraph ResourceValidation["🔍 Azure Resource Validation"]
        direction TB
        ValidateProviders -->|checks| CheckQuotas{"Check Subscription Quotas"}
        CheckQuotas -->|sufficient| ValidateMode{"Validate Only Mode?"}
        CheckQuotas -->|insufficient| DisplayWarnings["Display Quota Warnings"]
        DisplayWarnings -->|continues| ValidateMode
    end
    
    %% ===== SECRETS MANAGEMENT PHASE =====
    subgraph SecretsManagement["🔐 Secrets Management"]
        direction TB
        ValidateMode -->|yes| SuccessValidate(["✅ Success - Validation Only"])
        ValidateMode -->|no| SkipSecrets{"Skip Secrets Clear?"}
        SkipSecrets -->|yes| SkipClearing["Skip Clearing Secrets"]
        SkipSecrets -->|no| ClearSecrets["Clear .NET User Secrets"]
        SkipClearing -->|completes| DisplaySummary["Display Summary"]
        ClearSecrets -->|completes| DisplaySummary
    end
    
    %% ===== COMPLETION =====
    DisplaySummary -->|finishes| Success(["✅ Success"])

    %% ===== NODE STYLING =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000
    
    class Start,Success,SuccessValidate trigger
    class ParseArgs,InitLog,ValidateProviders,DisplayWarnings,SkipClearing,ClearSecrets,DisplaySummary,InstallCLI,PromptLogin primary
    class CheckShell,CheckDotNet,CheckAzCLI,CheckAuth,CheckBicep,CheckAzd,CheckQuotas,ValidateMode,SkipSecrets,AutoInstall decision
    class ExitError failed

    %% ===== SUBGRAPH STYLING =====
    style Initialization fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Validation fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style ResourceValidation fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style SecretsManagement fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
```

[⬆️ Back to top](#-preprovision)

---

## ✅ Prerequisites

| Category | Requirement | Version | Verification Command | Required |
|:---------|:------------|:--------|:---------------------|:--------:|
| Runtime | PowerShell Core | >= 7.0 | `$PSVersionTable.PSVersion` | ✅ |
| Runtime | Bash | >= 4.0 | `bash --version` | ✅ |
| SDK | .NET SDK | >= 10.0 | `dotnet --version` | ✅ |
| CLI Tool | Azure CLI | >= 2.60.0 | `az --version` | ✅ |
| CLI Tool | Azure Developer CLI (azd) | Latest | `azd version` | ✅ |
| CLI Tool | Bicep CLI | >= 0.30.0 | `az bicep version` | ✅ |
| Permission | Azure Subscription Access | N/A | `az account show` | ✅ |
| Azure Provider | Microsoft.App | N/A | `az provider show -n Microsoft.App` | ✅ |
| Azure Provider | Microsoft.ServiceBus | N/A | `az provider show -n Microsoft.ServiceBus` | ✅ |
| Azure Provider | Microsoft.Storage | N/A | `az provider show -n Microsoft.Storage` | ✅ |
| Azure Provider | Microsoft.Web | N/A | `az provider show -n Microsoft.Web` | ✅ |
| Azure Provider | Microsoft.ContainerRegistry | N/A | `az provider show -n Microsoft.ContainerRegistry` | ✅ |
| Azure Provider | Microsoft.Insights | N/A | `az provider show -n Microsoft.Insights` | ✅ |
| Azure Provider | Microsoft.OperationalInsights | N/A | `az provider show -n Microsoft.OperationalInsights` | ✅ |
| Azure Provider | Microsoft.ManagedIdentity | N/A | `az provider show -n Microsoft.ManagedIdentity` | ✅ |

### 📦 Installation Commands

```powershell
# Install .NET SDK 10.0+ (Windows/macOS/Linux)
# Visit: https://dotnet.microsoft.com/download/dotnet/10.0

# Install Azure CLI
# Windows: winget install Microsoft.AzureCLI
# macOS: brew install azure-cli
# Linux: curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Azure Developer CLI (azd)
# Windows: winget install Microsoft.Azd
# macOS: brew install azure/tap/azd
# Linux: curl -fsSL https://aka.ms/install-azd.sh | bash

# Install Bicep CLI (included with Azure CLI)
az bicep install
```

[⬆️ Back to top](#-preprovision)

---

## ⚙️ Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:-----|:--------:|:--------|:------------|
| `-Force` | `[switch]` | ❌ | `$false` | Skips confirmation prompts and forces execution of all operations |
| `-SkipSecretsClear` | `[switch]` | ❌ | `$false` | Skips the user secrets clearing step |
| `-ValidateOnly` | `[switch]` | ❌ | `$false` | Only validates prerequisites without making any changes |
| `-UseDeviceCodeLogin` | `[switch]` | ❌ | `$false` | Uses device code flow for Azure authentication (useful for remote/headless sessions) |
| `-AutoInstall` | `[switch]` | ❌ | `$false` | Automatically installs missing prerequisites without prompting |

### Bash Arguments

| Position/Flag | Type | Required | Default | Description |
|:--------------|:-----|:--------:|:--------|:------------|
| `--force` | flag | ❌ | `false` | Skip confirmation prompts and force execution |
| `--skip-secrets-clear` | flag | ❌ | `false` | Skip the user secrets clearing step |
| `--validate-only` | flag | ❌ | `false` | Only validate prerequisites without making changes |
| `--use-device-code-login` | flag | ❌ | `false` | Use device code flow for Azure authentication |
| `--auto-install` | flag | ❌ | `false` | Automatically install missing prerequisites |
| `--verbose` | flag | ❌ | `false` | Enable verbose output |
| `--help` | flag | ❌ | N/A | Display help message |

[⬆️ Back to top](#-preprovision)

---

## 📥 Input/Output Specifications

### Inputs

**Environment Variables Read:**

> [!NOTE]
> None required — script is self-contained for validation.

**Files/Paths Expected:**

- `clean-secrets.ps1` / `clean-secrets.sh` — Must exist in same directory for secrets clearing

### Outputs

**Exit Codes:**

| Exit Code | Meaning |
|:---------:|:--------|
| `0` | Success — All validations passed and operations completed |
| `1` | General error — Unexpected failure during execution |
| `2` | Missing prerequisites — Required tools not installed |
| `3` | Validation failure — Prerequisites check failed |
| `4` | Azure authentication failure — Not logged in or session expired |

**stdout Output:**

- Color-coded progress messages
- Validation results summary
- Prerequisite status indicators (✓/✗)

**Files Modified:**

- .NET user secrets cleared for configured projects (unless `--skip-secrets-clear` or `--validate-only`)

[⬆️ Back to top](#-preprovision)

---

## 💻 Usage Examples

### Basic Usage

```powershell
# PowerShell: Run standard pre-provisioning with confirmation prompts
.\preprovision.ps1
```

```bash
# Bash: Run standard pre-provisioning with confirmation prompts
./preprovision.sh
```

### Advanced Usage

```powershell
# PowerShell: Run validation only without making changes
.\preprovision.ps1 -ValidateOnly -Verbose

# PowerShell: Force execution with auto-install of missing prerequisites
.\preprovision.ps1 -Force -AutoInstall

# PowerShell: Remote session with device code authentication
.\preprovision.ps1 -UseDeviceCodeLogin -SkipSecretsClear
```

```bash
# Bash: Run validation only without making changes
./preprovision.sh --validate-only --verbose

# Bash: Force execution with auto-install of missing prerequisites
./preprovision.sh --force --auto-install

# Bash: Remote session with device code authentication
./preprovision.sh --use-device-code-login --skip-secrets-clear
```

### CI/CD Pipeline Usage

```yaml
# Azure DevOps Pipeline
- task: AzureCLI@2
  displayName: 'Pre-provision validation'
  inputs:
    azureSubscription: 'Azure-Connection'
    scriptType: 'pscore'
    scriptLocation: 'scriptPath'
    scriptPath: '$(System.DefaultWorkingDirectory)/hooks/preprovision.ps1'
    arguments: '-ValidateOnly -Force'

# GitHub Actions
- name: Validate prerequisites
  shell: bash
  run: |
    chmod +x ./hooks/preprovision.sh
    ./hooks/preprovision.sh --validate-only --force
```

[⬆️ Back to top](#-preprovision)

---

## ⚠️ Error Handling and Exit Codes

| Exit Code | Meaning | Recovery Action |
|:---------:|:--------|:----------------|
| `0` | Success | N/A |
| `1` | General error | Check stderr output for details, review logs |
| `2` | Missing prerequisites | Install missing tools using provided commands |
| `3` | Validation failure | Address specific validation failures shown in output |
| `4` | Azure authentication failure | Run `az login` to authenticate |

### Error Handling Approach

**PowerShell:**

- Uses `Set-StrictMode -Version Latest` for strict variable handling
- `$ErrorActionPreference = 'Stop'` for fail-fast behavior
- Try/Catch/Finally blocks for structured error handling
- Original preferences restored in finally block

**Bash:**

- Uses `set -euo pipefail` for strict error handling
- Trap handlers for EXIT, INT, and TERM signals
- Cleanup function ensures resources are released
- Color-coded error messages to stderr

[⬆️ Back to top](#-preprovision)

---

## 🔒 Security Considerations

### 🔑 Credential Handling

- [x] No hardcoded secrets
- [x] Credentials sourced from: Azure CLI session (interactive or service principal)
- [x] Device code flow option for remote/headless authentication
- [x] No sensitive data logged to output

### Required Permissions

| Permission/Role | Scope | Justification |
|:----------------|:------|:--------------|
| Reader | Subscription | Validate resource provider registrations |
| User Access Administrator | Subscription | Check quota availability |
| Contributor | Resource Group | Deploy Azure resources (after validation) |

### 🌐 Network Security

| Property | Value |
|:---------|:------|
| **Endpoints accessed** | Azure Resource Manager (`management.azure.com`), Azure AD (`login.microsoftonline.com`) |
| **TLS requirements** | TLS 1.2+ |
| **Firewall rules needed** | Outbound HTTPS (443) to Azure endpoints |

### 📝 Logging Security

> [!TIP]
> **Security Features:**
>
> - **Sensitive data masking:** Yes — access tokens and secrets are not logged
> - **Audit trail:** Script execution logs with timestamps

[⬆️ Back to top](#-preprovision)

---

## 🚧 Known Limitations

> [!WARNING]
> **Important Notes:**
>
> - Quota checking is informational only and does not block execution
> - Auto-install feature requires elevated permissions on some systems
> - Device code login requires manual browser interaction
> - Resource provider registration may require subscription owner permissions
> - Windows execution policy may require bypass (`-ExecutionPolicy Bypass`)

[⬆️ Back to top](#-preprovision)

---

## 🔗 Related Scripts

| Script | Relationship | Description |
|:-------|:-------------|:------------|
| [clean-secrets.md](clean-secrets.md) | Called by | Clears .NET user secrets for all projects |
| [postprovision.md](postprovision.md) | Follows | Configures secrets after Azure provisioning |
| [check-dev-workstation.md](check-dev-workstation.md) | Wrapper | Developer-friendly validation wrapper |

[⬆️ Back to top](#-preprovision)

---

## 📜 Changelog

| Version | Date | Changes |
|:-------:|:----:|:--------|
| 2.3.0 | 2026-01-06 | Added auto-install feature, improved quota checking |
| 2.0.0 | 2025-12-01 | Added Azure Resource Provider validation |
| 1.0.0 | 2025-01-01 | Initial release |

[⬆️ Back to top](#-preprovision)

---

<div align="center">

**[⬅️ Previous: README](README.md)** · **[📑 Index](README.md)** · **[Next: postprovision ➡️](postprovision.md)**

</div>
