---
title: configure-federated-credential Script Documentation
description: Configures federated identity credentials for GitHub Actions OIDC authentication in Azure AD App Registration
name: configure-federated-credential
version: 1.0.0
author: Azure Developer CLI Hook
date: 2026-01-26
last_modified: 2026-01-06
license: MIT
languages: [PowerShell, Bash]
tags: [oidc, github-actions, federated-identity, azure-ad, entra-id, authentication, security]
---

# 🔐 configure-federated-credential

> [!NOTE]
> **Target Audience:** DevOps Engineers, Security Engineers, Platform Engineers  
> **Estimated Reading Time:** 10 minutes

<details>
<summary>📍 <strong>Navigation</strong></summary>
<br>

| Previous | Index | Next |
|:---------|:-----:|-----:|
| [clean-secrets](clean-secrets.md) | [📑 Index](README.md) | [deploy-workflow](deploy-workflow.md) |

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

Configures federated identity credentials for GitHub Actions OIDC authentication in an Azure AD App Registration, enabling passwordless authentication from GitHub Actions workflows.

[⬆️ Back to top](#-configure-federated-credential)

---

## 📝 Description

This script adds or updates federated identity credentials in an Azure AD (Microsoft Entra ID) App Registration to enable GitHub Actions workflows to authenticate using OpenID Connect (OIDC). OIDC authentication eliminates the need to store long-lived secrets in GitHub, improving security posture significantly.

The script is designed to run as an Azure Developer CLI (azd) hook where environment variables are automatically loaded during the provisioning process. It can also be run manually to configure federated credentials for existing App Registrations.

When executed, the script validates Azure CLI authentication, looks up the App Registration by name or Object ID, checks for existing federated credentials to avoid duplicates, and creates a new federated credential configured for the specified GitHub repository and environment. The credential allows GitHub Actions running in that environment to obtain Azure AD tokens without storing client secrets.

[⬆️ Back to top](#-configure-federated-credential)

---

## 📊 Workflow Diagram

```mermaid
---
title: Configure Federated Credential Execution Flow
---
flowchart TD
    %% ===== INITIALIZATION PHASE =====
    subgraph Initialization["🚀 Initialization"]
        direction TB
        Start(["▶️ Start"]) -->|parses| ParseParams["Parse Parameters"]
        ParseParams -->|validates| ValidateDeps["Validate Dependencies"]
        ValidateDeps -->|checks| JqInstalled{"jq Installed? - Bash"}
        JqInstalled -->|yes| Continue["Continue"]
        JqInstalled -->|no| ExitJq(["❌ Exit - Install jq"])
    end
    
    %% ===== AUTHENTICATION PHASE =====
    subgraph Authentication["🔑 Azure Authentication"]
        direction TB
        Continue -->|validates| AzLoggedIn{"Azure CLI Logged In?"}
        AzLoggedIn -->|yes| DisplayAccount["Display Account Info"]
        AzLoggedIn -->|no| ExitLogin(["❌ Exit - az login required"])
    end
    
    %% ===== APP LOOKUP PHASE =====
    subgraph AppLookup["🔍 App Registration Lookup"]
        direction TB
        DisplayAccount -->|checks| ObjectIdProvided{"AppObjectId Provided?"}
        ObjectIdProvided -->|yes| UseProvidedId["Use Provided ID"]
        ObjectIdProvided -->|no| AppNameProvided{"AppName Provided?"}
        AppNameProvided -->|yes| LookupByName["Lookup by Name"]
        AppNameProvided -->|no| ListApps["List Available Apps"]
        ListApps -->|prompts| PromptSelect["Prompt for Selection"]
        PromptSelect -->|triggers| LookupByName
        LookupByName -->|evaluates| AppFound{"App Found?"}
        AppFound -->|yes| DisplayDetails["Display App Details"]
        AppFound -->|no| ExitNotFound(["❌ Exit - App Not Found"])
        UseProvidedId -->|displays| DisplayDetails
    end
    
    %% ===== CREDENTIAL CHECK PHASE =====
    subgraph CredentialCheck["🔐 Existing Credential Check"]
        direction TB
        DisplayDetails -->|queries| ListCreds["List Federated Credentials"]
        ListCreds -->|evaluates| CredExists{"Credential Exists?"}
        CredExists -->|yes| DisplayExisting["Display Existing Credential"]
        CredExists -->|no| PrepareNew["Prepare New Credential"]
    end
    
    %% ===== CREATION PHASE =====
    subgraph Creation["⚙️ Credential Creation"]
        direction TB
        DisplayExisting -->|checks| UpdateReq{"Update Requested?"}
        UpdateReq -->|yes| UpdateCred["Update Credential"]
        UpdateReq -->|no| SkipExists(["⏭️ Skip - Already Exists"])
        PrepareNew -->|creates| UpdateCred
        UpdateCred -->|evaluates| CreateSuccess{"Creation Successful?"}
        CreateSuccess -->|yes| DisplaySuccess["Display Success"]
        CreateSuccess -->|no| ExitError(["❌ Exit with Error"])
    end
    
    %% ===== COMPLETION =====
    DisplaySuccess -->|finishes| Complete(["✅ Complete"])
    
    %% ===== NODE STYLING =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5
    
    class Start,Complete trigger
    class ParseParams,ValidateDeps,Continue,DisplayAccount,UseProvidedId,LookupByName,ListApps,PromptSelect,DisplayDetails,ListCreds,DisplayExisting,PrepareNew,UpdateCred,DisplaySuccess primary
    class JqInstalled,AzLoggedIn,ObjectIdProvided,AppNameProvided,AppFound,CredExists,UpdateReq,CreateSuccess decision
    class ExitJq,ExitLogin,ExitNotFound,ExitError failed
    class SkipExists external
    
    %% ===== SUBGRAPH STYLING =====
    style Initialization fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Authentication fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style AppLookup fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style CredentialCheck fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style Creation fill:#D1FAE5,stroke:#10B981,stroke-width:2px
```

[⬆️ Back to top](#-configure-federated-credential)

---

## ✅ Prerequisites

| Category | Requirement | Version | Verification Command | Required |
|:---------|:------------|:--------|:---------------------|:--------:|
| Runtime | PowerShell Core | >= 7.0 | `$PSVersionTable.PSVersion` | ✅ |
| Runtime | Bash | >= 4.0 | `bash --version` | ✅ |
| CLI Tool | Azure CLI | >= 2.50 | `az --version` | ✅ |
| CLI Tool | jq (Bash only) | Latest | `jq --version` | ✅ (Bash) |
| Permission | Application.ReadWrite.All | N/A | Microsoft Graph API | ✅ |
| Permission | Directory.Read.All | N/A | Microsoft Graph API | ✅ |

### 📦 Installation Commands

```bash
# Install jq (Bash dependency)
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

[⬆️ Back to top](#-configure-federated-credential)

---

## ⚙️ Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|:----------|:-----|:--------:|:--------|:------------|
| `-AppName` | `[string]` | ❌ | N/A | Display name of the Azure AD App Registration |
| `-AppObjectId` | `[string]` | ❌ | N/A | Object ID of the Azure AD App Registration |
| `-GitHubOrg` | `[string]` | ❌ | `Evilazaro` | GitHub organization or username |
| `-GitHubRepo` | `[string]` | ❌ | `Azure-LogicApps-Monitoring` | GitHub repository name |
| `-Environment` | `[string]` | ❌ | `dev` | GitHub Environment name to configure |

### Bash Arguments

| Position/Flag | Type | Required | Default | Description |
|:--------------|:-----|:--------:|:--------|:------------|
| `--app-name` | string | ❌ | N/A | Display name of the Azure AD App Registration |
| `--app-object-id` | string | ❌ | N/A | Object ID of the Azure AD App Registration |
| `--github-org` | string | ❌ | `Evilazaro` | GitHub organization or username |
| `--github-repo` | string | ❌ | `Azure-LogicApps-Monitoring` | GitHub repository name |
| `--environment` | string | ❌ | `dev` | GitHub Environment name to configure |

[⬆️ Back to top](#-configure-federated-credential)

---

## 📥 Input/Output Specifications

### Inputs

**Environment Variables Read:**

> [!NOTE]
> None required — can be passed as parameters.

**Required API Permissions:**

- Microsoft Graph: `Application.ReadWrite.All`
- Microsoft Graph: `Directory.Read.All`

### Outputs

**Exit Codes:**

| Exit Code | Meaning |
|:---------:|:--------|
| `0` | Success — Credential created or already exists |
| `1` | Error — Azure CLI not authenticated or permission denied |

**stdout Output:**

- Azure account information
- App Registration details
- Federated credential configuration
- Success/failure messages

**Azure Resources Modified:**

- Federated identity credential added to App Registration

[⬆️ Back to top](#-configure-federated-credential)

---

## 💻 Usage Examples

### Basic Usage

```powershell
# PowerShell: Configure with App Registration name
.\configure-federated-credential.ps1 -AppName 'my-app-registration'
```

```bash
# Bash: Configure with App Registration name
./configure-federated-credential.sh --app-name "my-app-registration"
```

### Advanced Usage

```powershell
# PowerShell: Configure for production environment with specific repo
.\configure-federated-credential.ps1 -AppObjectId '00000000-0000-0000-0000-000000000000' -Environment 'prod'

# PowerShell: Configure for custom GitHub organization and repo
.\configure-federated-credential.ps1 -AppName 'my-app' -GitHubOrg 'MyOrg' -GitHubRepo 'MyRepo' -Environment 'staging'
```

```bash
# Bash: Configure for production environment
./configure-federated-credential.sh --app-object-id "00000000-0000-0000-0000-000000000000" --environment "prod"

# Bash: Configure for custom GitHub organization and repo
./configure-federated-credential.sh --app-name "my-app" --github-org "MyOrg" --github-repo "MyRepo" --environment "staging"
```

### CI/CD Pipeline Usage

```yaml
# Azure DevOps Pipeline - Setup federated credential
- task: AzureCLI@2
  displayName: 'Configure OIDC credential'
  inputs:
    azureSubscription: 'Azure-Connection'
    scriptType: 'pscore'
    scriptLocation: 'scriptPath'
    scriptPath: '$(System.DefaultWorkingDirectory)/hooks/configure-federated-credential.ps1'
    arguments: '-AppName "$(APP_REGISTRATION_NAME)" -Environment "$(ENVIRONMENT_NAME)"'

# GitHub Actions - Note: This would typically be run manually or as part of setup
- name: Configure federated credential
  shell: bash
  run: |
    az login --service-principal -u ${{ secrets.AZURE_CLIENT_ID }} -p ${{ secrets.AZURE_CLIENT_SECRET }} --tenant ${{ secrets.AZURE_TENANT_ID }}
    ./hooks/configure-federated-credential.sh --app-name "${{ vars.APP_NAME }}" --environment "prod"
```

[⬆️ Back to top](#-configure-federated-credential)

---

## ⚠️ Error Handling and Exit Codes

| Exit Code | Meaning | Recovery Action |
|:---------:|:--------|:----------------|
| `0` | Success | N/A |
| `1` | Error | Check Azure CLI auth, verify permissions |

### Error Handling Approach

**PowerShell:**

- `Set-StrictMode -Version Latest` for strict mode
- `$ErrorActionPreference = 'Stop'` for fail-fast
- Try/Catch for Azure CLI command errors
- Graceful handling of existing credentials

**Bash:**

- `set -euo pipefail` for strict error handling
- JSON parsing with jq for reliable data extraction
- Temporary file cleanup on exit
- Clear error messages for common failures

[⬆️ Back to top](#-configure-federated-credential)

---

## 🔒 Security Considerations

### 🔑 Credential Handling

- [x] No hardcoded secrets
- [x] OIDC eliminates need for long-lived secrets
- [x] Uses Azure CLI session for authentication
- [x] Federated credentials have limited scope

### Required Permissions

| Permission/Role | Scope | Justification |
|:----------------|:------|:--------------|
| Application.ReadWrite.All | Microsoft Graph | Create federated credentials |
| Directory.Read.All | Microsoft Graph | List App Registrations |
| Application Administrator | Entra ID Role | Alternative to Graph permissions |

### 🌐 Network Security

| Property | Value |
|:---------|:------|
| **Endpoints accessed** | Microsoft Graph API (`graph.microsoft.com`) |
| **TLS requirements** | TLS 1.2+ |
| **OIDC Issuer** | `https://token.actions.githubusercontent.com` |
| **Audience** | `api://AzureADTokenExchange` |

### 📝 Logging Security

> [!TIP]
> **Security Features:**
>
> - **Sensitive data masking:** Object IDs shown, no secrets logged
> - **Audit trail:** Azure AD audit logs capture credential creation

[⬆️ Back to top](#-configure-federated-credential)

---

## 🚧 Known Limitations

> [!WARNING]
> **Important Notes:**
>
> - Only configures environment-scoped credentials (not branch or PR)
> - Interactive prompt required if App name not provided
> - Cannot update existing credentials (must delete and recreate)
> - Requires Application Administrator or equivalent permissions
> - GitHub Enterprise Server may require different OIDC issuer

[⬆️ Back to top](#-configure-federated-credential)

---

## 🔗 Related Scripts

| Script | Relationship | Description |
|:-------|:-------------|:------------|
| [preprovision.md](preprovision.md) | Related | May trigger this as part of setup |
| [postprovision.md](postprovision.md) | Related | May be called after provisioning |

[⬆️ Back to top](#-configure-federated-credential)

---

## 📜 Changelog

| Version | Date | Changes |
|:-------:|:----:|:--------|
| 1.0.0 | 2026-01-06 | Initial release |

[⬆️ Back to top](#-configure-federated-credential)

---

<div align="center">

**[⬅️ Previous: clean-secrets](clean-secrets.md)** · **[📑 Index](README.md)** · **[Next: deploy-workflow ➡️](deploy-workflow.md)**

</div>
