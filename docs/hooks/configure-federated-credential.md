---
title: configure-federated-credential Script
description: Configures federated identity credentials for passwordless GitHub Actions OIDC authentication with Azure AD.
author: Azure Developer CLI Team
date: 2026-01-06
version: 1.0.0
tags: [azure-ad, oidc, github-actions, authentication, security]
---

# 🔐 configure-federated-credential

> Configures federated identity credentials for GitHub Actions OIDC authentication.

> [!NOTE]
> **Target Audience:** DevOps Engineers and Security Administrators  
> **Reading Time:** ~6 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                                |         Index          |                                                            Next |
| :-------------------------------------- | :--------------------: | --------------------------------------------------------------: |
| [deploy-workflow](./deploy-workflow.md) | [🪝 Hooks](./index.md) | [sql-managed-identity-config](./sql-managed-identity-config.md) |

</details>

---

## 📋 Overview

This script adds or updates federated identity credentials in an Azure AD App Registration to enable GitHub Actions workflows to authenticate using OIDC (OpenID Connect).

This script is designed to be run as an Azure Developer CLI (azd) hook, where environment variables are automatically loaded during the provisioning process.

The script performs the following operations:

- Verifies Azure CLI login status
- Looks up App Registration by name or Object ID
- Lists existing federated credentials
- Creates or updates federated credentials for GitHub Actions
- Supports multiple GitHub environments (dev, staging, prod)

---

## 📑 Table of Contents

- [📌 Script Metadata](#-script-metadata)
- [🔧 Prerequisites](#-prerequisites)
- [📥 Parameters](#-parameters)
- [🔑 OIDC Configuration](#-oidc-configuration)
- [🔄 Execution Flow](#-execution-flow)
- [📝 Usage Examples](#-usage-examples)
- [⚠️ Exit Codes](#%EF%B8%8F-exit-codes)
- [🔒 Security Considerations](#-security-considerations)
- [📚 Related Documentation](#-related-documentation)

[⬅️ Back to Index](./index.md)

> [!IMPORTANT]
> Federated credentials enable passwordless authentication—no secrets need to be stored in GitHub.

---

## 📌 Script Metadata

| Property          | PowerShell                           | Bash                                |
| ----------------- | ------------------------------------ | ----------------------------------- |
| **File Name**     | `configure-federated-credential.ps1` | `configure-federated-credential.sh` |
| **Version**       | 1.0.0                                | 1.0.0                               |
| **Last Modified** | —                                    | —                                   |
| **Author**        | Azure Developer CLI Hook             | Azure Developer CLI Hook            |

---

## 🔧 Prerequisites

| Requirement     | Minimum Version | Notes                                   |
| --------------- | --------------- | --------------------------------------- |
| PowerShell Core | 7.0             | Required for `.ps1` script              |
| Bash            | 4.0             | Required for `.sh` script               |
| Azure CLI       | 2.50+           | For Azure AD operations                 |
| jq              | Any             | Required for Bash script (JSON parsing) |

---

## 📥 Parameters

### PowerShell (`configure-federated-credential.ps1`)

| Parameter      | Type   | Required | Default                      | Description                                   |
| -------------- | ------ | -------- | ---------------------------- | --------------------------------------------- |
| `-AppName`     | String | No\*     | N/A                          | Display name of the Azure AD App Registration |
| `-AppObjectId` | String | No\*     | N/A                          | Object ID of the Azure AD App Registration    |
| `-GitHubOrg`   | String | No       | `Evilazaro`                  | GitHub organization or username               |
| `-GitHubRepo`  | String | No       | `Azure-LogicApps-Monitoring` | GitHub repository name                        |
| `-Environment` | String | No       | `dev`                        | GitHub Environment name to configure          |

\*Either `-AppName` or `-AppObjectId` should be provided. If neither is specified, the script will list available App Registrations and prompt for selection.

### Bash (`configure-federated-credential.sh`)

| Parameter         | Type   | Required | Default                      | Description                                   |
| ----------------- | ------ | -------- | ---------------------------- | --------------------------------------------- |
| `--app-name`      | String | No\*     | N/A                          | Display name of the Azure AD App Registration |
| `--app-object-id` | String | No\*     | N/A                          | Object ID of the Azure AD App Registration    |
| `--github-org`    | String | No       | `Evilazaro`                  | GitHub organization or username               |
| `--github-repo`   | String | No       | `Azure-LogicApps-Monitoring` | GitHub repository name                        |
| `--environment`   | String | No       | `dev`                        | GitHub Environment name to configure          |

\*Either `--app-name` or `--app-object-id` should be provided. If neither is specified, the script will list available App Registrations and prompt for selection.

---

## 🔑 OIDC Configuration

### Constants

| Constant           | Value                                         | Description                     |
| ------------------ | --------------------------------------------- | ------------------------------- |
| GitHub OIDC Issuer | `https://token.actions.githubusercontent.com` | Token issuer for GitHub Actions |
| Azure AD Audience  | `api://AzureADTokenExchange`                  | Token audience for Azure AD     |

### Subject Format

The federated credential subject is formatted as:

```
repo:{org}/{repo}:environment:{environment}
```

Example: `repo:Evilazaro/Azure-LogicApps-Monitoring:environment:dev`

---

## 🔄 Execution Flow

```mermaid
flowchart TD
    A[🚀 Start configure-federated-credential] --> B{Azure CLI Logged In?}
    B -->|No| Z[❌ Exit - Login Required]
    B -->|Yes| C{AppObjectId Provided?}

    C -->|Yes| D[Use Provided Object ID]
    C -->|No| E{AppName Provided?}

    E -->|Yes| F[Lookup App by Name]
    E -->|No| G[List All App Registrations]

    G --> H[Prompt User for Selection]
    H --> F

    F --> I{App Found?}
    I -->|No| Y[❌ Exit - App Not Found]
    I -->|Yes| D

    D --> J[Display App Details]
    J --> K[Get Existing Federated Credentials]

    K --> L[Generate Credential Name]
    L --> M{Credential Exists?}

    M -->|Yes| N[Update Existing Credential]
    M -->|No| O[Create New Credential]

    N --> P[✅ Display Success]
    O --> P

    P --> Q[Display Next Steps]
    Q --> R[🏁 End]
```

---

## 📝 Usage Examples

### PowerShell

```powershell
# Configure using App Registration name (will be looked up)
./configure-federated-credential.ps1 -AppName 'my-app-registration'

# Configure using Object ID directly with production environment
./configure-federated-credential.ps1 -AppObjectId '00000000-0000-0000-0000-000000000000' -Environment 'prod'

# Configure for a different GitHub repository
./configure-federated-credential.ps1 -AppName 'my-app' -GitHubOrg 'MyOrg' -GitHubRepo 'MyRepo'
```

### Bash

```bash
# Configure using App Registration name (will be looked up)
./configure-federated-credential.sh --app-name "my-app-registration"

# Configure using Object ID directly with production environment
./configure-federated-credential.sh --app-object-id "00000000-0000-0000-0000-000000000000" --environment "prod"

# Configure for a different GitHub repository
./configure-federated-credential.sh --app-name "my-app" --github-org "MyOrg" --github-repo "MyRepo"
```

---

## ⚠️ Exit Codes

| Code | Meaning                                                       |
| ---- | ------------------------------------------------------------- |
| `0`  | Success - federated credential configured successfully        |
| `1`  | Error - not logged in, app not found, or configuration failed |

---

## 🔒 Security Considerations

- Federated credentials enable passwordless authentication from GitHub Actions
- Only workflows running in the specified GitHub repository and environment can authenticate
- No secrets need to be stored in GitHub Secrets
- Token exchange happens securely between GitHub and Azure AD

---

## 📚 Related Documentation

| Resource                                                                                                                                              | Description                        |
| ----------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------- |
| [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect) | GitHub's OIDC documentation        |
| [Azure Workload Identity](https://learn.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation)                        | Azure workload identity federation |

---

## 📜 Version History

| Version | Date | Changes                                                  |
| ------- | ---- | -------------------------------------------------------- |
| 1.0.0   | N/A  | Initial release - GitHub Actions OIDC federation support |

---

> [!WARNING]
> Ensure you have the necessary Azure AD permissions (Application.ReadWrite.All or owner role) before running this script.

## 🔗 Links

- [Repository](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Azure AD Workload Identity Federation](https://learn.microsoft.com/azure/active-directory/workload-identities/workload-identity-federation)

---

<div align="center">

**[⬆️ Back to Top](#-configure-federated-credential)** · **[← deploy-workflow](./deploy-workflow.md)** · **[sql-managed-identity-config →](./sql-managed-identity-config.md)**

</div>
