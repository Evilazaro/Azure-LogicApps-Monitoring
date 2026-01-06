# sql-managed-identity-config (.ps1 / .sh)

![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)
![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)
![Azure](https://img.shields.io/badge/Azure-CLI-blue.svg)
![Cross-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

## 📋 Overview

The `sql-managed-identity-config` script configures Azure SQL Database users with Managed Identity authentication. It creates contained database users from Microsoft Entra ID (formerly Azure AD) and assigns specified database roles using token-based authentication.

Available in both PowerShell (`.ps1`) and Bash (`.sh`) versions for cross-platform compatibility, this script is designed to be **idempotent** and can be safely re-run. It will skip existing users and role memberships without errors.

The script is typically called by the `postprovision` hook after Azure infrastructure provisioning completes, setting up managed identity access for applications to connect to Azure SQL Database without storing credentials.

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [🎯 Purpose](#-purpose)
- [🏗️ Required Environment Variables](#️-required-environment-variables)
- [🔧 Parameters](#-parameters)
  - [PowerShell Parameters](#powershell-parameters)
  - [Bash Parameters](#bash-parameters)
- [🚀 Usage](#-usage)
  - [PowerShell Examples](#powershell-examples)
  - [Bash Examples](#bash-examples)
- [🔒 Database Roles](#-database-roles)
- [🛠️ How It Works](#️-how-it-works)
  - [📊 Workflow Diagram](#workflow-diagram)
  - [🔗 Technical Details](#technical-details)
- [☁️ Azure Environments](#️-azure-environments)
- [🔐 Security Considerations](#-security-considerations)
- [🔧 Troubleshooting](#-troubleshooting)
  - [Common Errors](#common-errors)
  - [Setting Entra ID Admin](#setting-entra-id-admin)
- [📖 Related Documentation](#-related-documentation)
- [📜 Version History](#-version-history)

## 🎯 Purpose

This script performs the following operations:

- ✅ **Validates Azure CLI authentication** - Ensures user is logged in
- ✅ **Configures firewall rules** - Automatically adds client IP to SQL Server firewall
- ✅ **Acquires access token** - Gets Azure AD token for SQL Database authentication
- ✅ **Creates database user** - Creates contained user from external provider (Entra ID)
- ✅ **Assigns database roles** - Grants specified permissions to the managed identity
- ✅ **Returns structured results** - Provides JSON output for programmatic handling

## 🏗️ Required Environment Variables

| Variable                | Description                              | Required           | Set By |
| ----------------------- | ---------------------------------------- | ------------------ | ------ |
| `AZURE_RESOURCE_GROUP`  | Resource group containing the SQL Server | Yes (for firewall) | azd    |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription GUID                  | Optional           | azd    |

### How Environment Variables Are Set

When running via Azure Developer CLI (`azd`), these variables are automatically set based on:

1. **Bicep outputs** defined in `main.bicep`
2. **Azure resource properties** discovered during provisioning
3. **User's azd environment configuration**

## 🔧 Parameters

### PowerShell Parameters

| Parameter               | Type     | Required | Default                               | Description                                                    |
| ----------------------- | -------- | -------- | ------------------------------------- | -------------------------------------------------------------- |
| `-SqlServerName`        | String   | Yes      | -                                     | Azure SQL Server name (without `.database.windows.net` suffix) |
| `-DatabaseName`         | String   | Yes      | -                                     | Target database name (cannot be 'master')                      |
| `-PrincipalDisplayName` | String   | Yes      | -                                     | Managed identity display name from Entra ID                    |
| `-DatabaseRoles`        | String[] | No       | `@('db_datareader', 'db_datawriter')` | Database roles to assign                                       |
| `-AzureEnvironment`     | String   | No       | `AzureCloud`                          | Azure cloud environment                                        |
| `-CommandTimeout`       | Int      | No       | `120`                                 | SQL command timeout in seconds (30-600)                        |

### Bash Parameters

| Parameter       | Short | Required | Default                       | Description                               |
| --------------- | ----- | -------- | ----------------------------- | ----------------------------------------- |
| `--server`      | `-s`  | Yes      | -                             | Azure SQL Server name (without suffix)    |
| `--database`    | `-d`  | Yes      | -                             | Target database name (cannot be 'master') |
| `--principal`   | `-p`  | Yes      | -                             | Managed identity display name             |
| `--roles`       | `-r`  | No       | `db_datareader,db_datawriter` | Comma-separated database roles            |
| `--environment` | `-e`  | No       | `AzureCloud`                  | Azure cloud environment                   |
| `--timeout`     | `-t`  | No       | `120`                         | SQL command timeout in seconds            |
| `--verbose`     | `-v`  | No       | -                             | Enable verbose output                     |
| `--help`        | `-h`  | No       | -                             | Display help message                      |

## 🚀 Usage

### PowerShell Examples

```powershell
# Basic usage with default roles
.\sql-managed-identity-config.ps1 `
    -SqlServerName "myserver" `
    -DatabaseName "mydb" `
    -PrincipalDisplayName "my-app-identity"

# With custom roles
.\sql-managed-identity-config.ps1 `
    -SqlServerName "myserver" `
    -DatabaseName "mydb" `
    -PrincipalDisplayName "my-app-identity" `
    -DatabaseRoles @("db_datareader", "db_datawriter", "db_ddladmin")

# With verbose output
.\sql-managed-identity-config.ps1 `
    -SqlServerName "myserver" `
    -DatabaseName "mydb" `
    -PrincipalDisplayName "my-app-identity" `
    -Verbose

# Capture result for programmatic handling
$result = .\sql-managed-identity-config.ps1 `
    -SqlServerName "myserver" `
    -DatabaseName "mydb" `
    -PrincipalDisplayName "my-app-identity"

if ($result.Success) {
    Write-Host "Configuration succeeded for $($result.Principal)"
} else {
    Write-Error "Configuration failed: $($result.Error)"
}
```

### Bash Examples

```bash
# Basic usage with default roles
./sql-managed-identity-config.sh \
    --server myserver \
    --database mydb \
    --principal my-app-identity

# With custom roles
./sql-managed-identity-config.sh \
    -s myserver \
    -d mydb \
    -p my-app-identity \
    -r "db_datareader,db_datawriter,db_ddladmin"

# With verbose output
./sql-managed-identity-config.sh \
    --server myserver \
    --database mydb \
    --principal my-app-identity \
    --verbose

# Azure Government cloud
./sql-managed-identity-config.sh \
    -s myserver \
    -d mydb \
    -p my-app-identity \
    -e AzureUSGovernment
```

## 🔒 Database Roles

The following built-in database roles can be assigned:

| Role                | Description                                    |
| ------------------- | ---------------------------------------------- |
| `db_owner`          | Full permissions in the database               |
| `db_datareader`     | Read all data from all user tables             |
| `db_datawriter`     | Add, delete, or modify data in all user tables |
| `db_ddladmin`       | Run DDL commands (CREATE, ALTER, DROP)         |
| `db_backupoperator` | Can back up the database                       |
| `db_securityadmin`  | Modify role membership and manage permissions  |
| `db_accessadmin`    | Add or remove database access                  |
| `db_denydatareader` | Cannot read any data in the database           |
| `db_denydatawriter` | Cannot modify any data in the database         |

**Default Roles:** `db_datareader`, `db_datawriter`

## 🛠️ How It Works

### Workflow Diagram

```mermaid
flowchart TD
    A[Start] --> B[Validate Parameters]
    B --> C[Check Azure CLI Auth]
    C --> D{Authenticated?}
    D -->|No| E[Exit with Error]
    D -->|Yes| F[Configure Firewall]
    F --> G[Acquire Access Token]
    G --> H[Generate SQL Script]
    H --> I[Connect to Database]
    I --> J[Execute SQL Script]
    J --> K{Success?}
    K -->|No| L[Show Troubleshooting]
    L --> M[Return Error Result]
    K -->|Yes| N[Return Success Result]
    M --> O[End]
    N --> O
```

### Technical Details

1. **Authentication Flow:**

   - Uses Azure CLI (`az account get-access-token`) to acquire Azure AD access token
   - Token is scoped to Azure SQL Database resource
   - No SQL passwords are used or stored

2. **SQL Script Generation:**

   - Creates idempotent T-SQL script with IF EXISTS checks
   - Uses `CREATE USER ... FROM EXTERNAL PROVIDER` for Entra ID users
   - Sanitizes input to prevent SQL injection

3. **Connection:**

   - PowerShell uses `Microsoft.Data.SqlClient` for cross-platform support
   - Bash uses `sqlcmd` utility with Azure AD token authentication
   - TLS 1.2+ encryption is enforced

4. **Firewall Configuration:**
   - Automatically detects client public IP
   - Creates temporary firewall rule for script execution
   - Rule name includes timestamp for uniqueness

## ☁️ Azure Environments

The script supports multiple Azure cloud environments:

| Environment         | SQL Endpoint Suffix           | Description            |
| ------------------- | ----------------------------- | ---------------------- |
| `AzureCloud`        | `.database.windows.net`       | Public Azure (default) |
| `AzureUSGovernment` | `.database.usgovcloudapi.net` | Azure Government       |
| `AzureChinaCloud`   | `.database.chinacloudapi.cn`  | Azure China (21Vianet) |
| `AzureGermanCloud`  | `.database.cloudapi.de`       | Azure Germany          |

## 🔐 Security Considerations

### Safe Operations

- ✅ Uses Azure AD token authentication (no SQL passwords)
- ✅ Access tokens are not logged or persisted
- ✅ SQL injection protection via input sanitization
- ✅ Connections use TLS 1.2+ encryption
- ✅ Server certificates are validated

### Required Permissions

- **Azure Resource Manager:** SQL Server Contributor or higher
- **Database:** db_owner or higher in target database
- **Entra ID:** Must authenticate as SQL Server Entra ID administrator

### What the Script Creates

| Resource         | Details                                      |
| ---------------- | -------------------------------------------- |
| Database User    | Contained user from external provider        |
| Role Memberships | Specified database roles assigned to user    |
| Firewall Rule    | Temporary rule for client IP (if configured) |

## 🔧 Troubleshooting

### Common Errors

| Error                            | Cause                               | Solution                             |
| -------------------------------- | ----------------------------------- | ------------------------------------ |
| `18456 - Login failed`           | Not authenticated as Entra ID admin | Set Entra ID admin on SQL Server     |
| `40615 - Firewall rule blocking` | Client IP not allowed               | Add IP to SQL Server firewall        |
| `40613 - Database not available` | Database offline or doesn't exist   | Verify database exists and is online |
| `33134 - User already exists`    | User was previously created         | Safe to ignore (idempotent)          |

### Setting Entra ID Admin

To create database users via Entra ID, you **must** authenticate as an Entra ID administrator of the SQL Server:

```bash
# 1. Get your current user details
az ad signed-in-user show --query '{name:userPrincipalName,id:id}' -o json

# 2. Set yourself as Entra ID admin
az sql server ad-admin create \
    --resource-group <your-resource-group> \
    --server-name <your-sql-server> \
    --display-name <your-user-principal-name> \
    --object-id <your-object-id>

# 3. Verify the admin is set
az sql server ad-admin list \
    --resource-group <your-resource-group> \
    --server-name <your-sql-server>

# 4. Re-run the script
./sql-managed-identity-config.sh -s <server> -d <database> -p <principal>
```

## 📖 Related Documentation

- [Azure SQL Database Microsoft Entra ID Authentication](https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure)
- [Managed Identities for Azure Resources](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)
- [CREATE USER (Transact-SQL)](https://learn.microsoft.com/sql/t-sql/statements/create-user-transact-sql)
- [Database-Level Roles](https://learn.microsoft.com/sql/relational-databases/security/authentication-access/database-level-roles)
- [Azure CLI SQL Commands](https://learn.microsoft.com/cli/azure/sql)
- [postprovision Hook Documentation](./postprovision.md)

## 📜 Version History

| Version | Date       | Changes                                               |
| ------- | ---------- | ----------------------------------------------------- |
| 1.0.0   | 2026-01-06 | Initial release with PowerShell Core and Bash support |

---

<div align="center">

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**

[⬆ Back to Top](#-pre-provisioning-script-documentation)

</div>
