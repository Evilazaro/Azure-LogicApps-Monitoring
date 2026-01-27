# Azure Developer CLI Hooks Documentation

This folder contains documentation for the automation scripts used in the Azure Logic Apps Monitoring solution. These scripts support the Azure Developer CLI (azd) lifecycle and provide utilities for development environment management.

## Contents

### azd Lifecycle Hooks

Scripts that integrate with Azure Developer CLI commands:

| Document | Hook | Description |
|----------|------|-------------|
| [preprovision.md](preprovision.md) | `preprovision` | Validates prerequisites and prepares environment before provisioning |
| [postprovision.md](postprovision.md) | `postprovision` | Configures secrets and managed identity after provisioning |
| [deploy-workflow.md](deploy-workflow.md) | `predeploy` | Deploys Logic Apps workflows to Azure |
| [postinfradelete.md](postinfradelete.md) | `postdown` | Purges soft-deleted Logic Apps after infrastructure deletion |

### Utility Scripts

Standalone scripts for development and testing:

| Document | Description |
|----------|-------------|
| [check-dev-workstation.md](check-dev-workstation.md) | Validates developer workstation prerequisites |
| [clean-secrets.md](clean-secrets.md) | Clears .NET user secrets for all projects |
| [configure-federated-credential.md](configure-federated-credential.md) | Configures GitHub Actions OIDC federation |
| [Generate-Orders.md](Generate-Orders.md) | Generates sample order data for testing |
| [sql-managed-identity-config.md](sql-managed-identity-config.md) | Configures Azure SQL Database managed identity access |

## Script Implementations

All scripts are implemented in both **PowerShell** and **Bash** to support cross-platform development:

- PowerShell scripts (`.ps1`) require PowerShell 7.0+
- Bash scripts (`.sh`) require Bash 4.0+

## Quick Reference

### Run Pre-Provisioning Validation

```bash
# PowerShell
./hooks/preprovision.ps1 -ValidateOnly

# Bash
./hooks/preprovision.sh --validate-only
```

### Check Workstation Prerequisites

```bash
# PowerShell
./hooks/check-dev-workstation.ps1

# Bash
./hooks/check-dev-workstation.sh
```

### Generate Test Data

```bash
# PowerShell
./hooks/Generate-Orders.ps1 -OrderCount 100

# Bash
./hooks/Generate-Orders.sh --count 100
```

## Related Links

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [Azure Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)
- [Repository Root](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
