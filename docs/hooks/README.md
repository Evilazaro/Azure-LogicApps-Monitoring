# 📚 Azure Logic Apps Monitoring - Hooks Documentation

This documentation provides comprehensive details for all Azure Developer CLI (azd) hooks used in the Azure Logic Apps Monitoring solution.

## 📋 Table of Contents

| Hook | Description | Execution Phase |
|------|-------------|-----------------|
| [preprovision](preprovision.md) | Pre-provisioning validation and environment preparation | Before `azd provision` |
| [postprovision](postprovision.md) | Post-provisioning configuration of .NET user secrets | After `azd provision` |
| [postinfradelete](postinfradelete.md) | Cleanup of soft-deleted Logic Apps resources | After `azd down` |
| [check-dev-workstation](check-dev-workstation.md) | Developer workstation prerequisite validation | Manual execution |
| [clean-secrets](clean-secrets.md) | Clear .NET user secrets for all projects | Manual / Pre-provisioning |
| [configure-federated-credential](configure-federated-credential.md) | GitHub Actions OIDC authentication setup | Post-provisioning |
| [deploy-workflow](deploy-workflow.md) | Logic Apps Standard workflow deployment | Pre-deployment |
| [Generate-Orders](Generate-Orders.md) | Sample order data generation for testing | Manual execution |
| [sql-managed-identity-config](sql-managed-identity-config.md) | SQL Database managed identity configuration | Post-provisioning |

## 🔄 Hook Execution Flow

```mermaid
---
title: Azure Developer CLI (azd) Hook Execution Flow
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

    %% ===== PROVISIONING LIFECYCLE =====
    subgraph Lifecycle["Azure Developer CLI Lifecycle"]
        direction TB
        A([azd up / provision]) -->|triggers| B[preprovision hook]
        B -->|validates| C{Prerequisites<br/>Valid?}
        C -->|No| D([Exit - Fix Issues])
        C -->|Yes| E[Azure Resource Provisioning]
        E -->|completes| F[postprovision hook]
        F -->|configures| G[User Secrets & SQL Identity]
        G -->|continues| H[deploy-workflow hook]
        H -->|deploys| I[Logic Apps Workflows]
        I -->|complete| J([Deployment Complete])
    end

    %% ===== TEARDOWN LIFECYCLE =====
    subgraph Teardown["Infrastructure Teardown"]
        direction TB
        K([azd down]) -->|deletes| L[Azure Resources]
        L -->|triggers| M[postinfradelete hook]
        M -->|purges| N[Soft-deleted Logic Apps]
        N -->|complete| O([Cleanup Complete])
    end

    %% ===== UTILITY HOOKS =====
    subgraph Utilities["Utility Hooks"]
        direction TB
        P([Manual]) -->|run| Q[check-dev-workstation]
        P -->|run| R[clean-secrets]
        P -->|run| S[Generate-Orders]
        P -->|run| T[configure-federated-credential]
    end

    %% ===== SUBGRAPH STYLES =====
    style Lifecycle fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Teardown fill:#FEE2E2,stroke:#F44336,stroke-width:2px
    style Utilities fill:#F3F4F6,stroke:#6B7280,stroke-width:2px

    %% ===== NODE CLASS ASSIGNMENTS =====
    class A,J,K,O,P trigger
    class B,E,F,H,L,M,Q,R,S,T primary
    class G,I,N secondary
    class C decision
    class D failed
```

## 🛠️ Quick Reference

### Prerequisites

All hooks require:

- **PowerShell 7.0+** or **Bash 4.0+**
- **.NET SDK 10.0+**
- **Azure CLI 2.60.0+**
- **Azure Developer CLI (azd)**

### Environment Variables

Common environment variables used across hooks:

| Variable | Description | Required By |
|----------|-------------|-------------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription GUID | Most hooks |
| `AZURE_RESOURCE_GROUP` | Resource group name | Most hooks |
| `AZURE_LOCATION` | Azure region | Most hooks |
| `AZURE_TENANT_ID` | Azure AD tenant ID | Authentication hooks |
| `LOGIC_APP_NAME` | Logic App Standard name | deploy-workflow |
| `MANAGED_IDENTITY_NAME` | Managed identity name | sql-managed-identity-config |

### Platform Support

| Platform | Shell | Status |
|----------|-------|--------|
| Windows | PowerShell 7.0+ | ✅ Fully Supported |
| macOS | Bash 4.0+ | ✅ Fully Supported |
| Linux | Bash 4.0+ | ✅ Fully Supported |
| WSL | Bash 4.0+ | ✅ Fully Supported |

## 📖 Usage Patterns

### Running Hooks Manually

```powershell
# PowerShell
.\hooks\preprovision.ps1 -Verbose
.\hooks\check-dev-workstation.ps1
```

```bash
# Bash
./hooks/preprovision.sh --verbose
./hooks/check-dev-workstation.sh
```

### Common Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Force | `-Force` | `--force` | Skip confirmation prompts |
| Verbose | `-Verbose` | `--verbose` | Enable detailed output |
| Help | `-?` | `--help` | Display help message |
| Dry Run | `-WhatIf` | `--dry-run` | Preview changes without executing |

## 🔗 Related Documentation

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Azure Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)
- [.NET User Secrets](https://learn.microsoft.com/aspnet/core/security/app-secrets)

---

**Version:** 2.0.0  
**Last Updated:** 2026-01-26  
**Maintainer:** Azure Logic Apps Monitoring Team
