---
title: postinfradelete Script Documentation
description: Post-infrastructure-delete hook for Azure Developer CLI (azd) that purges soft-deleted Logic Apps Standard resources
name: postinfradelete
version: 2.0.0
author: Evilazaro | Principal Cloud Solution Architect | Microsoft
date: 2026-01-26
last_modified: 2026-01-09
license: MIT
languages: [PowerShell, Bash]
tags: [azd, cleanup, logic-apps, soft-delete, purge, azure]
---

# 🗑️ postinfradelete

> [!NOTE]
> **Target Audience:** DevOps Engineers, Cloud Architects, Platform Engineers  
> **Estimated Reading Time:** 9 minutes

<details>
<summary>📍 <strong>Navigation</strong></summary>
<br>

| Previous | Index | Next |
|:---------|:-----:|-----:|
| [postprovision](postprovision.md) | [📑 Index](README.md) | [clean-secrets](clean-secrets.md) |

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

Post-infrastructure-delete hook for Azure Developer CLI (azd) that purges soft-deleted Logic Apps Standard resources after infrastructure deletion to ensure complete cleanup.

[⬆️ Back to top](#️-postinfradelete)

---

## 📝 Description

This script is automatically executed by Azure Developer CLI (azd) after the `azd down` command completes. It addresses a specific Azure behavior where Logic Apps Standard resources enter a soft-delete state when deleted rather than being permanently removed.

When Azure Logic Apps Standard are deleted through normal Azure Resource Manager operations, they remain in a recoverable soft-delete state for a retention period. This can cause conflicts when re-provisioning resources with the same names and may incur ongoing costs. This script handles the explicit purge operation to fully remove these soft-deleted resources.

The script queries the Azure REST API to retrieve all soft-deleted Logic Apps in the specified Azure location, filters them based on the resource group naming pattern to identify those belonging to the current azd environment, and then purges each matching Logic App. This ensures a clean slate for future deployments.

[⬆️ Back to top](#️-postinfradelete)

---

## 📊 Workflow Diagram

```mermaid
flowchart TD
    subgraph Initialization
        A([Start - azd hook]) --> B[Parse Arguments]
        B --> C[Initialize Logging]
    end
    
    subgraph Validation["Environment Validation"]
        C --> D{Validate AZURE_SUBSCRIPTION_ID}
        D -->|Set| E{Validate AZURE_LOCATION}
        D -->|Missing| Z([Exit with Error])
        E -->|Set| F[Environment Valid]
        E -->|Missing| Z
    end
    
    subgraph AzureAuth["Azure Authentication"]
        F --> G{Azure CLI Authenticated?}
        G -->|Yes| H[Get Access Token]
        G -->|No| Z
        H --> I[Set Subscription Context]
    end
    
    subgraph Discovery["Soft-Delete Discovery"]
        I --> J[Query Deleted Sites API]
        J --> K{Deleted Apps Found?}
        K -->|No| L([No Apps to Purge])
        K -->|Yes| M[Filter by Location]
        M --> N{Matching Apps?}
        N -->|No| L
        N -->|Yes| O[Display App List]
    end
    
    subgraph Confirmation["User Confirmation"]
        O --> P{Force Mode?}
        P -->|Yes| Q[Skip Confirmation]
        P -->|No| R{User Confirms?}
        R -->|Yes| Q
        R -->|No| S([Cancelled by User])
    end
    
    subgraph Purge["Purge Operations"]
        Q --> T[Begin Purge Loop]
        T --> U[Purge Logic App]
        U --> V{More Apps?}
        V -->|Yes| U
        V -->|No| W[Generate Summary]
    end
    
    W --> X([Success])
    
    style Z fill:#f96
    style S fill:#ff9
    style L fill:#9f9
    style X fill:#9f9
```

[⬆️ Back to top](#️-postinfradelete)

---

## ✅ Prerequisites

| Category | Requirement | Version | Verification Command | Required |
|:---------|:------------|:--------|:---------------------|:--------:|
| Runtime | PowerShell Core | >= 7.0 | `$PSVersionTable.PSVersion` | ✅ |
| Runtime | Bash | >= 4.0 | `bash --version` | ✅ |
| CLI Tool | Azure CLI | >= 2.50 | `az --version` | ✅ |
| CLI Tool | jq (Bash only) | Latest | `jq --version` | ✅ (Bash) |
| Environment Variable | AZURE_SUBSCRIPTION_ID | N/A | `echo $AZURE_SUBSCRIPTION_ID` | ✅ |
| Environment Variable | AZURE_LOCATION | N/A | `echo $AZURE_LOCATION` | ✅ |
| Permission | Azure Subscription Access | N/A | `az account show` | ✅ |

### 📦 Installation Commands (Bash Dependencies)

```bash
# Install jq for JSON parsing
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

[⬆️ Back to top](#️-postinfradelete)

---

## ⚙️ Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:-----|:--------:|:--------|:------------|
| `-Force` | `[switch]` | ❌ | `$false` | Skips confirmation prompts and forces execution |
| `-WhatIf` | `[switch]` | ❌ | `$false` | Shows what would be executed without making changes |

### Bash Arguments

| Position/Flag | Type | Required | Default | Description |
|:--------------|:-----|:--------:|:--------|:------------|
| `--force`, `-f` | flag | ❌ | `false` | Skip confirmation prompts |
| `--verbose`, `-v` | flag | ❌ | `false` | Enable verbose output |
| `--help`, `-h` | flag | ❌ | N/A | Show help message |

[⬆️ Back to top](#️-postinfradelete)

---

## 📥 Input/Output Specifications

### Inputs

**Environment Variables Read (set by azd):**

| Variable | Required | Description |
|:---------|:--------:|:------------|
| `AZURE_SUBSCRIPTION_ID` | ✅ | Azure subscription GUID |
| `AZURE_LOCATION` | ✅ | Azure region where resources were deployed |
| `AZURE_RESOURCE_GROUP` | ❌ | Filter by resource group name pattern |
| `LOGIC_APP_NAME` | ❌ | Filter by Logic App name pattern |

### Outputs

**Exit Codes:**

| Exit Code | Meaning |
|:---------:|:--------|
| `0` | Success — All soft-deleted Logic Apps purged |
| `1` | General error or purge failure |

**stdout Output:**

- Timestamped progress messages
- List of discovered soft-deleted Logic Apps
- Purge operation results

**Azure Resources Modified:**

- Soft-deleted Logic Apps permanently removed

[⬆️ Back to top](#️-postinfradelete)

---

## 💻 Usage Examples

### Basic Usage

```powershell
# PowerShell: Run post-infrastructure-delete (typically called by azd)
.\postinfradelete.ps1
```

```bash
# Bash: Run post-infrastructure-delete (typically called by azd)
./postinfradelete.sh
```

### Advanced Usage

```powershell
# PowerShell: See what would be purged without making changes
.\postinfradelete.ps1 -WhatIf

# PowerShell: Force purge without confirmation
.\postinfradelete.ps1 -Force -Verbose
```

```bash
# Bash: Force purge with verbose output
./postinfradelete.sh --force --verbose

# Bash: Display help
./postinfradelete.sh --help
```

### CI/CD Pipeline Usage

```yaml
# Azure DevOps Pipeline
- task: AzureCLI@2
  displayName: 'Purge soft-deleted Logic Apps'
  inputs:
    azureSubscription: 'Azure-Connection'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: '$(System.DefaultWorkingDirectory)/hooks/postinfradelete.sh'
    arguments: '--force'
  env:
    AZURE_SUBSCRIPTION_ID: $(AZURE_SUBSCRIPTION_ID)
    AZURE_LOCATION: $(AZURE_LOCATION)
  condition: always()

# GitHub Actions
- name: Cleanup soft-deleted Logic Apps
  if: always()
  shell: pwsh
  run: ./hooks/postinfradelete.ps1 -Force
  env:
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    AZURE_LOCATION: ${{ vars.AZURE_LOCATION }}
```

[⬆️ Back to top](#️-postinfradelete)

---

## ⚠️ Error Handling and Exit Codes

| Exit Code | Meaning | Recovery Action |
|:---------:|:--------|:----------------|
| `0` | Success | N/A |
| `1` | General error | Check Azure CLI authentication, verify permissions |

### Error Handling Approach

**PowerShell:**

- `Set-StrictMode -Version Latest` for strict mode
- `$ErrorActionPreference = 'Stop'` for fail-fast
- `SupportsShouldProcess` for WhatIf/Confirm support
- Try/Catch/Finally with preference restoration

**Bash:**

- `set -euo pipefail` for strict error handling
- Cleanup trap for EXIT signal
- Detailed error logging with color coding

[⬆️ Back to top](#️-postinfradelete)

---

## 🔒 Security Considerations

### 🔑 Credential Handling

- [x] No hardcoded secrets
- [x] Uses Azure CLI session for authentication
- [x] Access tokens acquired via `az account get-access-token`

### Required Permissions

| Permission/Role | Scope | Justification |
|:----------------|:------|:--------------|
| Website Contributor | Subscription | Delete soft-deleted Logic Apps |
| Reader | Subscription | List soft-deleted resources |

### 🌐 Network Security

| Property | Value |
|:---------|:------|
| **Endpoints accessed** | Azure Resource Manager (`management.azure.com`) |
| **TLS requirements** | TLS 1.2+ |
| **API Version** | 2023-12-01 |

### 📝 Logging Security

> [!TIP]
> **Security Features:**
>
> - **Sensitive data masking:** Access tokens not logged
> - **Audit trail:** Timestamped operation logs

[⬆️ Back to top](#️-postinfradelete)

---

## 🚧 Known Limitations

> [!CAUTION]
> **Important Notes:**
>
> - Only targets Logic Apps Standard (not Consumption tier)
> - Requires Azure CLI authentication with sufficient permissions
> - Location filtering is case-sensitive
> - **Cannot recover purged Logic Apps after execution**
> - Rate limiting may affect large-scale purge operations

[⬆️ Back to top](#️-postinfradelete)

---

## 🔗 Related Scripts

| Script | Relationship | Description |
|:-------|:-------------|:------------|
| [preprovision.md](preprovision.md) | Related | Pre-provisioning validation |
| [postprovision.md](postprovision.md) | Related | Post-provisioning configuration |

[⬆️ Back to top](#️-postinfradelete)

---

## 📜 Changelog

| Version | Date | Changes |
|:-------:|:----:|:--------|
| 2.0.0 | 2026-01-09 | Complete rewrite with improved error handling |
| 1.0.0 | 2025-06-01 | Initial release |

[⬆️ Back to top](#️-postinfradelete)

---

<div align="center">

**[⬅️ Previous: postprovision](postprovision.md)** · **[📑 Index](README.md)** · **[Next: clean-secrets ➡️](clean-secrets.md)**

</div>
