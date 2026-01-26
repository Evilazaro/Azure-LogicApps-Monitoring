---
title: postprovision Script Documentation
description: Post-provisioning script for Azure Developer CLI (azd) that configures .NET user secrets with Azure resource information
name: postprovision
version: 2.0.1
author: Azure DevOps Team
date: 2026-01-26
last_modified: 2026-01-06
license: MIT
languages: [PowerShell, Bash]
tags: [azd, provisioning, user-secrets, azure, configuration, dotnet]
---

# ⚙️ postprovision

> [!NOTE]
> **Target Audience:** DevOps Engineers, Cloud Architects, Developers  
> **Estimated Reading Time:** 10 minutes

<details>
<summary>📍 <strong>Navigation</strong></summary>
<br>

| Previous | Index | Next |
|:---------|:-----:|-----:|
| [preprovision](preprovision.md) | [📑 Index](README.md) | [postinfradelete](postinfradelete.md) |

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

Post-provisioning script for Azure Developer CLI (azd) that configures .NET user secrets with Azure resource information after infrastructure provisioning completes.

[⬆️ Back to top](#️-postprovision)

---

## 📝 Description

This script is automatically executed by Azure Developer CLI (azd) after the infrastructure provisioning phase completes successfully. It bridges the gap between Azure resource deployment and local development by configuring .NET user secrets with the connection information for newly provisioned Azure resources.

The script performs several critical operations: validating that required environment variables are set by azd, authenticating to Azure Container Registry if configured, clearing any existing user secrets to prevent conflicts, and configuring new secrets with Azure resource information such as connection strings, endpoints, and credentials.

The configuration enables local development against Azure resources without hardcoding sensitive information in application configuration files. All secrets are stored securely using .NET's built-in user secrets mechanism, which stores data in a protected location outside the project directory.

[⬆️ Back to top](#️-postprovision)

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
        D -->|Set| E{Validate AZURE_RESOURCE_GROUP}
        D -->|Missing| Z([Exit with Error])
        E -->|Set| F{Validate AZURE_LOCATION}
        E -->|Missing| Z
        F -->|Set| G[Environment Valid]
        F -->|Missing| Z
    end
    
    subgraph ACR["Container Registry Auth"]
        G --> H{ACR Configured?}
        H -->|Yes| I[Authenticate to ACR]
        H -->|No| J[Skip ACR Auth]
        I -->|Success| J
        I -->|Fail| K[Log Warning]
        K --> J
    end
    
    subgraph SecretsSetup["User Secrets Configuration"]
        J --> L[Clear Existing Secrets]
        L --> M[Set Azure Subscription Secret]
        M --> N[Set Resource Group Secret]
        N --> O[Set Location Secret]
        O --> P{Additional Resources?}
        P -->|Yes| Q[Configure Resource Secrets]
        P -->|No| R[Generate Summary]
        Q --> R
    end
    
    subgraph SQLConfig["SQL Database Config"]
        R --> S{SQL Database Provisioned?}
        S -->|Yes| T[Configure Managed Identity]
        S -->|No| U[Skip SQL Config]
        T --> U
    end
    
    U --> V([Success])
    
    style Z fill:#f96
    style V fill:#9f9
```

[⬆️ Back to top](#️-postprovision)

---

## ✅ Prerequisites

| Category | Requirement | Version | Verification Command | Required |
|:---------|:------------|:--------|:---------------------|:--------:|
| Runtime | PowerShell Core | >= 7.0 | `$PSVersionTable.PSVersion` | ✅ |
| Runtime | Bash | >= 4.0 | `bash --version` | ✅ |
| SDK | .NET SDK | >= 10.0 | `dotnet --version` | ✅ |
| CLI Tool | Azure CLI | >= 2.50 | `az --version` | ✅ |
| CLI Tool | Azure Developer CLI | Latest | `azd version` | ✅ |
| Environment Variable | AZURE_SUBSCRIPTION_ID | N/A | `echo $AZURE_SUBSCRIPTION_ID` | ✅ |
| Environment Variable | AZURE_RESOURCE_GROUP | N/A | `echo $AZURE_RESOURCE_GROUP` | ✅ |
| Environment Variable | AZURE_LOCATION | N/A | `echo $AZURE_LOCATION` | ✅ |

[⬆️ Back to top](#️-postprovision)

---

## ⚙️ Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:-----|:--------:|:--------|:------------|
| `-Force` | `[switch]` | ❌ | `$false` | Skips confirmation prompts and forces execution |

### Bash Arguments

| Position/Flag | Type | Required | Default | Description |
|:--------------|:-----|:--------:|:--------|:------------|
| `--force` | flag | ❌ | `false` | Skip confirmation prompts and force execution |
| `--verbose` | flag | ❌ | `false` | Enable verbose output for debugging |
| `--dry-run` | flag | ❌ | `false` | Show what would be executed without making changes |
| `--help` | flag | ❌ | N/A | Display help message |

[⬆️ Back to top](#️-postprovision)

---

## 📥 Input/Output Specifications

### Inputs

**Environment Variables Read (set by azd):**

| Variable | Required | Description |
|:---------|:--------:|:------------|
| `AZURE_SUBSCRIPTION_ID` | ✅ | Azure subscription GUID |
| `AZURE_RESOURCE_GROUP` | ✅ | Resource group containing deployed resources |
| `AZURE_LOCATION` | ✅ | Azure region where resources are deployed |
| `AZURE_CONTAINER_REGISTRY_NAME` | ❌ | ACR name for container authentication |
| `AZURE_CONTAINER_REGISTRY_ENDPOINT` | ❌ | ACR endpoint URL |
| `SERVICE_BUS_CONNECTION_STRING` | ❌ | Service Bus connection string |
| `STORAGE_ACCOUNT_NAME` | ❌ | Storage account name |
| `SQL_SERVER_FQDN` | ❌ | SQL Server fully qualified domain name |
| `SQL_DATABASE_NAME` | ❌ | SQL database name |

### Outputs

**Exit Codes:**

| Exit Code | Meaning |
|:---------:|:--------|
| `0` | Success — All secrets configured |
| `1` | General error |
| `2` | Missing required environment variables |
| `3` | Azure CLI not authenticated |

**stdout Output:**

- Progress messages with timestamps
- Configuration summary
- Success/failure indicators

**Secrets Configured:**

- Azure subscription and resource group information
- Connection strings for Azure services
- Storage account credentials
- Service Bus connection information

[⬆️ Back to top](#️-postprovision)

---

## 💻 Usage Examples

### Basic Usage

```powershell
# PowerShell: Run post-provisioning (typically called by azd)
.\postprovision.ps1
```

```bash
# Bash: Run post-provisioning (typically called by azd)
./postprovision.sh
```

### Advanced Usage

```powershell
# PowerShell: Run with verbose output for debugging
.\postprovision.ps1 -Verbose

# PowerShell: Simulate execution without making changes
.\postprovision.ps1 -WhatIf

# PowerShell: Force execution without prompts
.\postprovision.ps1 -Force
```

```bash
# Bash: Run with verbose output for debugging
./postprovision.sh --verbose

# Bash: Simulate execution without making changes
./postprovision.sh --dry-run

# Bash: Force execution without prompts
./postprovision.sh --force
```

### CI/CD Pipeline Usage

```yaml
# Azure DevOps Pipeline - Post-provision hook
- task: AzureCLI@2
  displayName: 'Configure user secrets'
  inputs:
    azureSubscription: 'Azure-Connection'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: '$(System.DefaultWorkingDirectory)/hooks/postprovision.sh'
    arguments: '--force'
  env:
    AZURE_SUBSCRIPTION_ID: $(AZURE_SUBSCRIPTION_ID)
    AZURE_RESOURCE_GROUP: $(AZURE_RESOURCE_GROUP)
    AZURE_LOCATION: $(AZURE_LOCATION)

# GitHub Actions
- name: Post-provision configuration
  shell: pwsh
  run: ./hooks/postprovision.ps1 -Force
  env:
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    AZURE_RESOURCE_GROUP: ${{ vars.AZURE_RESOURCE_GROUP }}
    AZURE_LOCATION: ${{ vars.AZURE_LOCATION }}
```

[⬆️ Back to top](#️-postprovision)

---

## ⚠️ Error Handling and Exit Codes

| Exit Code | Meaning | Recovery Action |
|:---------:|:--------|:----------------|
| `0` | Success | N/A |
| `1` | General error | Check stderr output, review execution logs |
| `2` | Missing environment variables | Ensure azd provisioning completed successfully |
| `3` | Azure CLI authentication failure | Run `az login` to authenticate |

### Error Handling Approach

**PowerShell:**

- `Set-StrictMode -Version Latest` enforces strict variable handling
- `$ErrorActionPreference = 'Stop'` ensures errors halt execution
- Try/Catch/Finally for structured exception handling
- Detailed error messages with recovery suggestions

**Bash:**

- `set -euo pipefail` for strict error handling
- Trap handlers for cleanup on EXIT
- Color-coded error messages
- Execution statistics tracking (success/failure counts)

[⬆️ Back to top](#️-postprovision)

---

## 🔒 Security Considerations

### 🔑 Credential Handling

- [x] No hardcoded secrets
- [x] Credentials sourced from: Azure environment variables (set by azd)
- [x] Secrets stored using .NET user secrets (protected storage)
- [x] ACR authentication uses Azure CLI session

### Required Permissions

| Permission/Role | Scope | Justification |
|:----------------|:------|:--------------|
| Reader | Resource Group | Read provisioned resource information |
| AcrPull | Container Registry | Authenticate and pull container images |
| Contributor | SQL Database | Configure managed identity access |

### 🌐 Network Security

| Property | Value |
|:---------|:------|
| **Endpoints accessed** | Azure Container Registry, Azure SQL Database |
| **TLS requirements** | TLS 1.2+ |
| **Firewall rules needed** | Outbound HTTPS (443) |

### 📝 Logging Security

> [!TIP]
> **Security Features:**
>
> - **Sensitive data masking:** Yes — connection strings and tokens are not logged
> - **Audit trail:** Timestamped execution logs

[⬆️ Back to top](#️-postprovision)

---

## 🚧 Known Limitations

> [!WARNING]
> **Important Notes:**
>
> - Requires azd to have completed provisioning successfully
> - Environment variables must be set before execution
> - ACR authentication may fail if firewall rules are restrictive
> - SQL managed identity configuration requires admin privileges
> - User secrets are stored per-user, not shared across team members

[⬆️ Back to top](#️-postprovision)

---

## 🔗 Related Scripts

| Script | Relationship | Description |
|:-------|:-------------|:------------|
| [preprovision.md](preprovision.md) | Precedes | Validates prerequisites before provisioning |
| [clean-secrets.md](clean-secrets.md) | Called by | Clears existing user secrets |
| [sql-managed-identity-config.md](sql-managed-identity-config.md) | Called by | Configures SQL managed identity |

[⬆️ Back to top](#️-postprovision)

---

## 📜 Changelog

| Version | Date | Changes |
|:-------:|:----:|:--------|
| 2.0.1 | 2026-01-06 | Added SQL managed identity configuration |
| 2.0.0 | 2025-12-01 | Improved secret configuration workflow |
| 1.0.0 | 2025-01-01 | Initial release |

[⬆️ Back to top](#️-postprovision)

---

<div align="center">

**[⬅️ Previous: preprovision](preprovision.md)** · **[📑 Index](README.md)** · **[Next: postinfradelete ➡️](postinfradelete.md)**

</div>
