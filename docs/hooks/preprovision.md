---
title: preprovision
description: Validates and prepares the development environment before Azure infrastructure provisioning
author: Platform Team
last_updated: 2026-01-27
version: "2.3.0"
---

# preprovision

[Home](../../README.md) > [Docs](..) > [Hooks](README.md) > preprovision

> 🔍 **Summary**: Validates development environment prerequisites and prepares for Azure infrastructure provisioning.

---

## Table of Contents

- [Overview](#overview)
- [Compatibility](#compatibility)
- [Prerequisites](#prerequisites)
- [Parameters](#parameters)
- [Script Flow](#script-flow)
- [Sequence Diagram](#sequence-diagram)
- [Functions](#functions)
- [Usage](#usage)
- [Environment Variables](#environment-variables)
- [Exit Codes](#exit-codes)
- [Error Handling](#error-handling)
- [Validation Checks](#validation-checks)
- [Notes](#notes)
- [See Also](#see-also)

---

## Overview

This script is an Azure Developer CLI (`azd`) hook that runs before `azd provision` to validate the development environment and ensure all required tools, configurations, and permissions are in place for successful infrastructure deployment.

The script performs comprehensive validation of:

- Runtime environment (PowerShell/Bash version)
- Required CLI tools (.NET SDK, Azure CLI, Bicep CLI, azd)
- Azure authentication and subscription access
- Azure resource provider registrations
- Regional quotas for required Azure services
- Optional tool installations (sqlcmd, zip)

**Operations Performed**:

1. Validates shell runtime version (PowerShell 7.0+ or Bash 4.0+)
2. Checks and optionally installs .NET SDK 10.0+
3. Validates Azure Developer CLI installation
4. Validates Azure CLI installation and version
5. Validates Bicep CLI installation and version
6. Checks Azure authentication status
7. Validates Azure resource provider registrations
8. Checks regional quotas for Azure services
9. Validates optional tools (sqlcmd, zip)
10. Clears existing user secrets (unless skipped)

---

## Compatibility

| Platform    | Script              | Status |
|:------------|:--------------------|:------:|
| Windows     | `preprovision.ps1`  |   ✅   |
| Linux/macOS | `preprovision.sh`   |   ✅   |

---

## Prerequisites

| Requirement | Details | Installation Guide |
|:------------|:--------|:-------------------|
| **PowerShell** | Version 7.0 or higher | [Install PowerShell](https://docs.microsoft.com/powershell/scripting/install/installing-powershell) |
| **Bash** | Version 4.0 or higher | Pre-installed on Linux/macOS |

> ℹ️ **Note**: Other dependencies are validated and optionally installed by this script.

---

## Parameters

### PowerShell

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:-------:|:------------|
| `-Force` | Switch | No | `$false` | Bypass confirmation prompts |
| `-SkipSecretsClear` | Switch | No | `$false` | Skip clearing existing user secrets |
| `-ValidateOnly` | Switch | No | `$false` | Only validate, do not install missing tools |
| `-UseDeviceCodeLogin` | Switch | No | `$false` | Use device code flow for Azure authentication |
| `-AutoInstall` | Switch | No | `$false` | Automatically install missing dependencies |
| `-Verbose` | Switch | No | `$false` | Display detailed diagnostic information |

### Bash

| Parameter | Type | Required | Default | Description |
|:----------|:----:|:--------:|:-------:|:------------|
| `-f, --force` | Flag | No | `false` | Bypass confirmation prompts |
| `--skip-secrets-clear` | Flag | No | `false` | Skip clearing existing user secrets |
| `--validate-only` | Flag | No | `false` | Only validate, do not install missing tools |
| `--use-device-code-login` | Flag | No | `false` | Use device code flow for Azure authentication |
| `--auto-install` | Flag | No | `false` | Automatically install missing dependencies |
| `-v, --verbose` | Flag | No | `false` | Display detailed diagnostic information |
| `-h, --help` | Flag | No | N/A | Display help message and exit |

---

## Script Flow

### Execution Flow

```mermaid
%%{init: {'flowchart': {'nodeSpacing': 30, 'rankSpacing': 40, 'curve': 'basis'}}}%%
flowchart TD
    subgraph INIT["🔧 Initialization"]
        direction TB
        A([▶️ Start - azd preprovision hook]):::startNode
        A --> B[🔧 Set Strict Mode]:::config
        B --> C[📋 Parse Arguments]:::data
        C --> D[📋 Initialize Validation Results]:::data
    end

    subgraph VALIDATE["✅ Validation Phase"]
        direction TB
        E{🔍 Shell version OK?}:::validation
        E -->|❌ No| F[❗ Error: Shell version too old]:::error
        E -->|✅ Yes| G[🔍 Validate .NET SDK]:::validation
        G --> H{🔍 .NET 10.0+ installed?}:::validation
        H -->|❌ No| I{🔍 AutoInstall enabled?}:::validation
        I -->|❌ No| J[❗ Error: .NET not found]:::error
        I -->|✅ Yes| K[⚡ Install .NET SDK]:::execution
        H -->|✅ Yes| L[🔍 Validate azd CLI]:::validation
        K --> L
        L --> M{🔍 azd installed?}:::validation
        M -->|❌ No| N[❗ Error: azd not found]:::error
        M -->|✅ Yes| O[🔍 Validate Azure CLI]:::validation
        O --> P{🔍 Azure CLI 2.60.0+?}:::validation
        P -->|❌ No| Q[❗ Error: Azure CLI version]:::error
        P -->|✅ Yes| R[🔍 Validate Bicep CLI]:::validation
        R --> S{🔍 Bicep 0.30.0+?}:::validation
        S -->|❌ No| T[❗ Error: Bicep version]:::error
        S -->|✅ Yes| U[🔍 Validate Azure auth]:::validation
    end

    subgraph EXECUTE["⚡ Execution Phase"]
        direction TB
        V{🔍 Logged in to Azure?}:::validation
        V -->|❌ No| W{🔍 DeviceCode login?}:::validation
        W -->|✅ Yes| X[⚡ az login --use-device-code]:::execution
        W -->|❌ No| Y[⚡ az login]:::execution
        V -->|✅ Yes| Z[🔍 Validate resource providers]:::validation
        X --> Z
        Y --> Z
        Z --> AA[🔍 Check regional quotas]:::validation
        AA --> BB[🔍 Validate optional tools]:::validation
        BB --> CC{🔍 Skip secrets clear?}:::validation
        CC -->|❌ No| DD[⚡ Clear user secrets]:::execution
        CC -->|✅ Yes| EE[ℹ️ Skipping secrets clear]:::logging
    end

    subgraph CLEANUP["🧹 Cleanup Phase"]
        direction TB
        FF[📋 Display validation summary]:::logging
        GG[🧹 Restore preferences]:::cleanup
    end

    subgraph EXIT["🚪 Exit Handling"]
        direction TB
        HH([❌ Exit 1]):::errorExit
        II([✅ Exit 0]):::successExit
    end

    %% Cross-subgraph connections
    D --> E
    F --> HH
    J --> HH
    N --> HH
    Q --> HH
    T --> HH
    U --> V
    DD --> FF
    EE --> FF
    FF --> GG
    GG --> II

    %% Subgraph styles
    style INIT fill:#e8eaf6,stroke:#303f9f,stroke-width:2px,color:#1a237e
    style VALIDATE fill:#fff8e1,stroke:#ffa000,stroke-width:2px,color:#ff6f00
    style EXECUTE fill:#e0f2f1,stroke:#00796b,stroke-width:2px,color:#004d40
    style CLEANUP fill:#ede7f6,stroke:#512da8,stroke-width:2px,color:#311b92
    style EXIT fill:#eceff1,stroke:#455a64,stroke-width:2px,color:#263238

    classDef startNode fill:#b3e5fc,stroke:#0288d1,stroke-width:3px,color:#01579b
    classDef successExit fill:#c8e6c9,stroke:#388e3c,stroke-width:3px,color:#1b5e20
    classDef errorExit fill:#ffcdd2,stroke:#d32f2f,stroke-width:3px,color:#b71c1c
    classDef config fill:#c5cae9,stroke:#3949ab,stroke-width:2px,color:#1a237e
    classDef data fill:#f0f4c3,stroke:#9e9d24,stroke-width:2px,color:#827717
    classDef validation fill:#fff9c4,stroke:#f9a825,stroke-width:2px,color:#f57f17
    classDef execution fill:#b2dfdb,stroke:#00796b,stroke-width:2px,color:#004d40
    classDef error fill:#ffebee,stroke:#e53935,stroke-width:2px,color:#c62828
    classDef cleanup fill:#e1bee7,stroke:#7b1fa2,stroke-width:2px,color:#4a148c
    classDef logging fill:#d7ccc8,stroke:#6d4c41,stroke-width:2px,color:#3e2723
```

---

## Sequence Diagram

```mermaid
sequenceDiagram
    autonumber
    box rgb(232,234,246) Local Environment
        participant AZD as azd provision
        participant Script as preprovision
        participant DotNet as .NET CLI
        participant AzCLI as Azure CLI
        participant Bicep as Bicep CLI
    end

    box rgb(224,242,241) Azure Services
        participant ARM as Azure Resource Manager
        participant Quota as Quota Service
    end

    AZD->>Script: Trigger preprovision hook
    activate Script

    Note over Script: Phase 1: Runtime Validation
    Script->>Script: Check PowerShell/Bash version

    Note over Script: Phase 2: Tool Validation
    Script->>DotNet: dotnet --version
    activate DotNet
    DotNet-->>Script: Version info (or not found)
    deactivate DotNet

    opt .NET not found & AutoInstall
        Script->>Script: Download and install .NET SDK
    end

    Script->>AzCLI: az --version
    activate AzCLI
    AzCLI-->>Script: Version 2.x.x
    deactivate AzCLI

    Script->>Bicep: az bicep version
    activate Bicep
    Bicep-->>Script: Version 0.x.x
    deactivate Bicep

    Note over Script: Phase 3: Azure Validation
    Script->>AzCLI: az account show
    activate AzCLI
    AzCLI->>ARM: Validate authentication
    ARM-->>AzCLI: Account info (or error)
    AzCLI-->>Script: Authentication status
    deactivate AzCLI

    opt Not logged in
        Script->>AzCLI: az login [--use-device-code]
        activate AzCLI
        AzCLI->>ARM: Authenticate user
        ARM-->>AzCLI: Authentication token
        AzCLI-->>Script: Login success
        deactivate AzCLI
    end

    Note over Script: Phase 4: Resource Provider Validation
    loop For each required provider
        Script->>AzCLI: az provider show -n {provider}
        activate AzCLI
        AzCLI->>ARM: Get provider registration state
        ARM-->>AzCLI: Registration status
        AzCLI-->>Script: Provider state
        deactivate AzCLI

        opt Provider not registered
            Script->>AzCLI: az provider register -n {provider}
            activate AzCLI
            AzCLI->>ARM: Register provider
            ARM-->>AzCLI: Registration initiated
            AzCLI-->>Script: Registration pending
            deactivate AzCLI
        end
    end

    Note over Script: Phase 5: Quota Validation
    Script->>AzCLI: az quota usage show
    activate AzCLI
    AzCLI->>Quota: Get quota usage
    Quota-->>AzCLI: Current usage and limits
    AzCLI-->>Script: Quota information
    deactivate AzCLI

    opt Clear secrets not skipped
        Note over Script: Phase 6: Secrets Cleanup
        Script->>DotNet: dotnet user-secrets clear (per project)
        activate DotNet
        DotNet-->>Script: Secrets cleared
        deactivate DotNet
    end

    Script->>Script: Display validation summary
    Script-->>AZD: Exit 0 (or 1 on failure)
    deactivate Script
```

---

## Functions

### PowerShell

| Function | Purpose |
|:---------|:--------|
| `Test-ShellVersion` | Validates PowerShell version >= 7.0 |
| `Test-DotNetSdk` | Validates .NET SDK installation and version |
| `Install-DotNetSdk` | Downloads and installs .NET SDK |
| `Test-AzdCli` | Validates Azure Developer CLI installation |
| `Test-AzureCli` | Validates Azure CLI installation and version |
| `Test-BicepCli` | Validates Bicep CLI installation and version |
| `Test-AzureAuthentication` | Validates Azure login status |
| `Invoke-AzureLogin` | Performs Azure CLI login |
| `Test-ResourceProviders` | Validates Azure resource provider registrations |
| `Register-ResourceProvider` | Registers an Azure resource provider |
| `Test-RegionalQuotas` | Validates Azure regional quotas |
| `Test-OptionalTools` | Validates optional tools (sqlcmd, zip) |
| `Clear-UserSecrets` | Clears .NET user secrets for projects |

### Bash

| Function | Purpose |
|:---------|:--------|
| `cleanup` | Performs cleanup operations on script exit |
| `handle_interrupt` | Handles SIGINT/SIGTERM signals gracefully |
| `log_verbose` | Outputs verbose messages when enabled |
| `log_error` | Outputs error messages to stderr |
| `log_info` | Outputs informational messages |
| `log_success` | Outputs success messages with formatting |
| `log_warning` | Outputs warning messages |
| `show_help` | Displays comprehensive help information |
| `check_shell_version` | Validates Bash version >= 4.0 |
| `check_dotnet_sdk` | Validates .NET SDK installation and version |
| `install_dotnet_sdk` | Downloads and installs .NET SDK |
| `check_azd_cli` | Validates Azure Developer CLI |
| `check_azure_cli` | Validates Azure CLI installation and version |
| `check_bicep_cli` | Validates Bicep CLI installation and version |
| `check_azure_auth` | Validates Azure login status |
| `azure_login` | Performs Azure CLI login |
| `check_resource_providers` | Validates Azure resource provider registrations |
| `check_regional_quotas` | Validates Azure regional quotas |
| `check_optional_tools` | Validates optional tools |
| `clear_user_secrets` | Clears .NET user secrets |
| `main` | Main execution function orchestrating all operations |

---

## Usage

### PowerShell

```powershell
# Standard execution (as azd hook - automatic)
# Runs automatically before `azd provision`

# Manual validation only (no installations)
.\preprovision.ps1 -ValidateOnly

# Manual execution with auto-install
.\preprovision.ps1 -AutoInstall

# Execute without clearing secrets
.\preprovision.ps1 -SkipSecretsClear

# Use device code login for Azure
.\preprovision.ps1 -UseDeviceCodeLogin

# Execute with all options
.\preprovision.ps1 -Force -AutoInstall -Verbose
```

### Bash

```bash
# Standard execution (as azd hook - automatic)
# Runs automatically before `azd provision`

# Manual validation only (no installations)
./preprovision.sh --validate-only

# Manual execution with auto-install
./preprovision.sh --auto-install

# Execute without clearing secrets
./preprovision.sh --skip-secrets-clear

# Use device code login for Azure
./preprovision.sh --use-device-code-login

# Execute with all options
./preprovision.sh --force --auto-install --verbose

# Display help
./preprovision.sh --help
```

---

## Environment Variables

| Variable | Description | Required | Default |
|:---------|:------------|:--------:|:-------:|
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID | No | From `az account show` |
| `AZURE_LOCATION` | Target Azure region | No | `eastus` |

> ℹ️ **Note**: Environment variables are optional; the script will use defaults or prompt for required values.

---

## Exit Codes

| Code | Meaning |
|-----:|:--------|
| 0 | ✅ All validations passed successfully |
| 1 | ❌ Shell version too old (PowerShell < 7.0 or Bash < 4.0) |
| 1 | ❌ .NET SDK not found and AutoInstall not enabled |
| 1 | ❌ Azure Developer CLI not installed |
| 1 | ❌ Azure CLI not installed or version < 2.60.0 |
| 1 | ❌ Bicep CLI not installed or version < 0.30.0 |
| 1 | ❌ Azure authentication failed |
| 1 | ❌ Required resource provider registration failed |
| 1 | ❌ Insufficient Azure quota for deployment |
| 130 | ❌ Script interrupted by user (SIGINT) |

---

## Error Handling

The script implements comprehensive error handling:

- **Strict Mode**: PowerShell uses `Set-StrictMode -Version Latest`; Bash uses `set -euo pipefail`
- **Version Validation**: Semantic version comparison for all CLI tools
- **Retry Logic**: Retries transient Azure API failures
- **Graceful Degradation**: Warns on non-critical failures (optional tools)
- **Validation Summary**: Collects all issues and reports at end
- **Signal Handling**: Bash version handles SIGINT and SIGTERM gracefully

---

## Validation Checks

| Check | Minimum Version | Critical |
|:------|:----------------|:--------:|
| PowerShell | 7.0 | ✅ |
| Bash | 4.0 | ✅ |
| .NET SDK | 10.0 | ✅ |
| Azure Developer CLI | Latest | ✅ |
| Azure CLI | 2.60.0 | ✅ |
| Bicep CLI | 0.30.0 | ✅ |
| sqlcmd | Any | ❌ |
| zip | Any | ❌ |

### Required Resource Providers

| Provider | Service |
|:---------|:--------|
| `Microsoft.App` | Azure Container Apps |
| `Microsoft.ServiceBus` | Azure Service Bus |
| `Microsoft.Storage` | Azure Storage |
| `Microsoft.Web` | Azure App Service / Logic Apps |
| `Microsoft.ContainerRegistry` | Azure Container Registry |
| `Microsoft.Insights` | Application Insights |
| `Microsoft.OperationalInsights` | Log Analytics |
| `Microsoft.ManagedIdentity` | Managed Identities |

---

## Notes

| Item | Details |
|:-----|:--------|
| **Script Version** | 2.3.0 |
| **Author** | Evilazaro \| Principal Cloud Solution Architect \| Microsoft |
| **Last Modified** | 2025-01-07 |
| **Hook Type** | `azd` preprovision hook |

> ℹ️ **Note**: This script runs automatically before `azd provision` as part of the Azure Developer CLI lifecycle hooks.

> 💡 **Tip**: Use `-ValidateOnly` to check environment readiness without making any changes.

> ⚠️ **Important**: Resource provider registration may take several minutes. The script will wait for registration to complete.

> 🔒 **Security**: The script requires Azure authentication to validate subscriptions and quotas.

---

## See Also

- [check-dev-workstation.md](check-dev-workstation.md) — Developer workstation validation wrapper
- [postprovision.md](postprovision.md) — Post-provisioning configuration
- [clean-secrets.md](clean-secrets.md) — User secrets management
- [Azure Developer CLI Hooks](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-extensibility)
- [README.md](README.md) — Hooks documentation overview

---

[← Back to Hooks Documentation](README.md) | [↑ Back to Top](#preprovision)
