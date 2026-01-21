---
title: sql-managed-identity-config Script
description: Configures Azure SQL Database users with Microsoft Entra ID Managed Identity authentication for secure, passwordless access.
author: Evilazaro
date: 2026-01-06
version: 1.0.0
tags: [azure-sql, managed-identity, entra-id, authentication, security]
---

# 🔐 sql-managed-identity-config

> Configures Azure SQL Database user with Managed Identity authentication.

> [!NOTE]
> **Target Audience:** Database Administrators and DevOps Engineers  
> **Reading Time:** ~10 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                                                              |          Index          | Next |
| :-------------------------------------------------------------------- | :---------------------: | ---: |
| [configure-federated-credential](./configure-federated-credential.md) | [🪝 Hooks](./README.md) |    — |

</details>

---

## 📋 Overview

Creates a database user from an external provider (Microsoft Entra ID/Managed Identity) and assigns specified database roles using Azure AD token-based authentication.

The script performs the following operations:

- Validates Azure CLI authentication
- Acquires an access token for Azure SQL Database
- Creates a contained database user from external provider
- Assigns specified database roles to the user
- Returns a structured result object

The script is **idempotent** and can be safely re-run. It will skip existing users and role memberships.

---

## 📑 Table of Contents

- [📌 Script Metadata](#-script-metadata)
- [🔧 Prerequisites](#-prerequisites)
- [📥 Parameters](#-parameters)
- [🌐 Environment Variables](#-environment-variables)
- [🔑 Azure Environments](#-azure-environments)
- [🛡️ Database Roles](#%EF%B8%8F-database-roles)
- [🔄 Execution Flow](#-execution-flow)
- [📝 Usage Examples](#-usage-examples)
- [📄 Output Format](#-output-format)
- [⚠️ Exit Codes](#%EF%B8%8F-exit-codes)
- [🔒 Security Considerations](#-security-considerations)
- [⚠️ Known Limitations](#%EF%B8%8F-known-limitations)
- [📚 Related Scripts](#-related-scripts)
- [📜 Version History](#-version-history)

[⬅️ Back to Index](./README.md)

> [!IMPORTANT]
> This script requires Microsoft Entra ID Administrator privileges on the SQL Server. The script is idempotent and safe to re-run.

---

## 📌 Script Metadata

| Property          | PowerShell                                                   | Bash                                                         |
| ----------------- | ------------------------------------------------------------ | ------------------------------------------------------------ |
| **File Name**     | `sql-managed-identity-config.ps1`                            | `sql-managed-identity-config.sh`                             |
| **Version**       | 1.0.0                                                        | 1.0.0                                                        |
| **Last Modified** | 2026-01-06                                                   | 2026-01-06                                                   |
| **Author**        | Evilazaro \| Principal Cloud Solution Architect \| Microsoft | Evilazaro \| Principal Cloud Solution Architect \| Microsoft |
| **Creation Date** | 2025-12-26                                                   | 2025-12-26                                                   |

---

## 🔧 Prerequisites

| Requirement     | Minimum Version | Notes                                    |
| --------------- | --------------- | ---------------------------------------- |
| PowerShell Core | 7.0             | Required for `.ps1` script               |
| Bash            | 4.0             | Required for `.sh` script                |
| Azure CLI       | 2.60.0          | For token acquisition and authentication |
| sqlcmd          | Any             | Required for Bash script (mssql-tools)   |

### Critical Requirements

- **Entra ID Administrator**: You must authenticate as an Entra ID administrator of the SQL Server
  ```bash
  az sql server ad-admin create --resource-group <rg> --server-name <server> --display-name <name> --object-id <id>
  ```
- **Network Access**: Firewall rules must allow access to Azure SQL Database
- **Environment Variable**: `AZURE_RESOURCE_GROUP` must be set for firewall configuration

---

## 📥 Parameters

### PowerShell (`sql-managed-identity-config.ps1`)

| Parameter               | Type     | Required | Default                               | Description                                                    |
| ----------------------- | -------- | -------- | ------------------------------------- | -------------------------------------------------------------- |
| `-SqlServerName`        | String   | **Yes**  | N/A                                   | Azure SQL Server name (without `.database.windows.net` suffix) |
| `-DatabaseName`         | String   | **Yes**  | N/A                                   | Target database name (cannot be `master`)                      |
| `-PrincipalDisplayName` | String   | **Yes**  | N/A                                   | Managed identity or service principal display name             |
| `-DatabaseRoles`        | String[] | No       | `@("db_datareader", "db_datawriter")` | Array of database roles to assign                              |
| `-AzureEnvironment`     | String   | No       | `AzureCloud`                          | Azure cloud environment                                        |
| `-CommandTimeout`       | Int      | No       | `120`                                 | SQL command timeout (30-600 seconds)                           |

### Bash (`sql-managed-identity-config.sh`)

| Parameter                 | Type   | Required | Default                       | Description                            |
| ------------------------- | ------ | -------- | ----------------------------- | -------------------------------------- |
| `-s`, `--sql-server-name` | String | **Yes**  | N/A                           | Azure SQL Server name (without suffix) |
| `-d`, `--database-name`   | String | **Yes**  | N/A                           | Database name (cannot be `master`)     |
| `-p`, `--principal-name`  | String | **Yes**  | N/A                           | Managed identity display name          |
| `-r`, `--database-roles`  | String | No       | `db_datareader,db_datawriter` | Comma-separated database roles         |
| `-e`, `--environment`     | String | No       | `AzureCloud`                  | Azure environment                      |
| `-t`, `--timeout`         | Int    | No       | `120`                         | SQL command timeout (30-600)           |
| `-v`, `--verbose`         | Flag   | No       | `false`                       | Enable verbose output                  |
| `-h`, `--help`            | Flag   | No       | N/A                           | Display help message                   |

---

## 🌐 Environment Variables

### Required Variables

| Variable               | Source   | Description                                                   |
| ---------------------- | -------- | ------------------------------------------------------------- |
| `AZURE_RESOURCE_GROUP` | User/azd | Resource group containing the SQL Server (for firewall rules) |

---

## 🔑 Azure Environments

The script supports multiple Azure cloud environments:

| Environment         | SQL Endpoint                  |
| ------------------- | ----------------------------- |
| `AzureCloud`        | `.database.windows.net`       |
| `AzureUSGovernment` | `.database.usgovcloudapi.net` |
| `AzureChinaCloud`   | `.database.chinacloudapi.cn`  |
| `AzureGermanCloud`  | `.database.cloudapi.de`       |

---

## 🛡️ Database Roles

Common built-in roles that can be assigned:

| Role                | Description                                    |
| ------------------- | ---------------------------------------------- |
| `db_datareader`     | Read all data from all user tables             |
| `db_datawriter`     | Add, delete, or modify data in all user tables |
| `db_ddladmin`       | Run DDL commands (CREATE, ALTER, DROP)         |
| `db_owner`          | Full permissions in the database               |
| `db_backupoperator` | Can backup the database                        |
| `db_securityadmin`  | Manage role memberships and permissions        |
| `db_accessadmin`    | Add or remove access for users                 |
| `db_denydatareader` | Cannot read any data                           |
| `db_denydatawriter` | Cannot modify any data                         |

---

## 🔄 Execution Flow

```mermaid
---
title: sql-managed-identity-config Execution Flow
---
flowchart TD
    %% ===== STYLE DEFINITIONS =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5
    classDef matrix fill:#D1FAE5,stroke:#10B981,color:#000000

    %% ===== TRIGGER =====
    subgraph triggers["🚀 Entry Point"]
        direction TB
        A(["🚀 Start sql-managed-identity-config"])
        B["Parse Arguments"]
    end

    %% ===== HELP =====
    subgraph help["📖 Help"]
        direction TB
        C{"Help Requested?"}
        D["Display Help"]
    end

    %% ===== VALIDATION =====
    subgraph validation["🔍 Validation"]
        direction TB
        E{"Validate Parameters"}
        G{"Azure CLI Logged In?"}
    end

    %% ===== TOKEN ACQUISITION =====
    subgraph token["🔑 Token Acquisition"]
        direction TB
        I["Acquire Azure AD Token"]
        J{"Token Acquired?"}
    end

    %% ===== DATABASE CONNECTION =====
    subgraph dbconn["🗄️ Database Connection"]
        direction TB
        L["Build SQL Connection"]
        M["Connect to Database"]
        N{"Connection Success?"}
    end

    %% ===== USER CREATION =====
    subgraph usercreate["👤 User Management"]
        direction TB
        P["Check if User Exists"]
        Q{"User Exists?"}
        R["Skip User Creation"]
        S["CREATE USER FROM EXTERNAL PROVIDER"]
    end

    %% ===== ROLE ASSIGNMENT =====
    subgraph roleassign["🛡️ Role Assignment Loop"]
        direction TB
        T["Process Role Assignments"]
        U["Loop: Assign Each Role"]
        V["Check Role Membership"]
        W{"Already Member?"}
        X["Skip Role Assignment"]
        Y["ALTER ROLE ADD MEMBER"]
        AA{"More Roles?"}
    end

    %% ===== RESULTS =====
    subgraph results["📊 Results"]
        direction TB
        AB["Build Success Result"]
        AC["✅ Return Result Object"]
        Z(["🏁 End"])
    end

    %% ===== FAILURE =====
    subgraph failure["❌ Error Handling"]
        direction TB
        F["❌ Return Error Result"]
        H["❌ Return Auth Error"]
        K["❌ Return Token Error"]
        O["❌ Return Connection Error"]
    end

    %% ===== CONNECTIONS =====
    A -->|"parses"| B
    B -->|"checks"| C

    C -->|"Yes"| D
    D -->|"ends"| Z

    C -->|"No"| E
    E -->|"Invalid"| F
    F -->|"ends"| Z

    E -->|"Valid"| G
    G -->|"No"| H
    H -->|"ends"| Z

    G -->|"Yes"| I
    I -->|"checks"| J

    J -->|"No"| K
    K -->|"ends"| Z

    J -->|"Yes"| L
    L -->|"connects"| M

    M -->|"checks"| N
    N -->|"No"| O
    O -->|"ends"| Z

    N -->|"Yes"| P
    P -->|"checks"| Q

    Q -->|"Yes"| R
    Q -->|"No"| S

    R -->|"processes"| T
    S -->|"processes"| T

    T -->|"loops"| U
    U -->|"checks"| V
    V -->|"evaluates"| W

    W -->|"Yes"| X
    W -->|"No"| Y

    X -->|"checks"| AA
    Y -->|"checks"| AA

    AA -->|"Yes"| U
    AA -->|"No"| AB

    AB -->|"returns"| AC
    AC -->|"ends"| Z

    %% ===== NODE STYLING =====
    class A trigger
    class B,D,I,L,M,P,R,S,V,X,Y primary
    class C,E,G,J,N,Q,W,AA decision
    class U,T matrix
    class AB,AC secondary
    class Z secondary
    class F,H,K,O failed

    %% ===== SUBGRAPH STYLING =====
    style triggers fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style help fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
    style validation fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style token fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style dbconn fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style usercreate fill:#D1FAE5,stroke:#059669,stroke-width:2px
    style roleassign fill:#D1FAE5,stroke:#059669,stroke-width:1px
    style results fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
    style failure fill:#FEE2E2,stroke:#F44336,stroke-width:2px
```

---

## 📝 Usage Examples

### PowerShell

```powershell
# Basic usage with default roles
.\sql-managed-identity-config.ps1 -SqlServerName "myserver" -DatabaseName "mydb" -PrincipalDisplayName "my-app-identity"

# With custom roles and verbose output
.\sql-managed-identity-config.ps1 -SqlServerName "myserver" -DatabaseName "mydb" -PrincipalDisplayName "my-app-identity" -DatabaseRoles @("db_datareader", "db_datawriter", "db_ddladmin") -Verbose

# Capture and check result
$result = .\sql-managed-identity-config.ps1 -SqlServerName "myserver" -DatabaseName "mydb" -PrincipalDisplayName "my-app-identity"
if ($result.Success) {
    Write-Host "Configuration succeeded for $($result.Principal)"
} else {
    Write-Error "Configuration failed: $($result.Error)"
}
```

### Bash

```bash
# Basic usage with default roles
./sql-managed-identity-config.sh --sql-server-name myserver --database-name mydb --principal-name my-app-identity

# With custom roles and verbose output
./sql-managed-identity-config.sh -s myserver -d mydb -p my-app-identity -r "db_datareader,db_datawriter,db_ddladmin" -v

# Azure Government cloud
./sql-managed-identity-config.sh -s myserver -d mydb -p my-app-identity -e AzureUSGovernment
```

---

## 📄 Output Format

### PowerShell Result Object

The script returns a `PSCustomObject` with type `SqlManagedIdentityConfiguration.Result`:

**Success Result:**

```powershell
@{
    Success = $true
    Principal = "my-app-identity"
    Server = "myserver.database.windows.net"
    Database = "mydb"
    Roles = @("db_datareader", "db_datawriter")
    RowsAffected = 2
    ExecutionTimeSeconds = 3.45
    Timestamp = "2026-01-21T10:30:00Z"
    Message = "Successfully configured managed identity access"
    ScriptVersion = "1.0.0"
}
```

**Error Result:**

```powershell
@{
    Success = $false
    Principal = "my-app-identity"
    Server = "myserver.database.windows.net"
    Database = "mydb"
    Roles = @("db_datareader", "db_datawriter")
    Timestamp = "2026-01-21T10:30:00Z"
    ScriptVersion = "1.0.0"
    Error = "Login failed for user '<token-identified principal>'"
    ErrorType = "SqlException"
    InnerError = $null
}
```

---

## ⚠️ Exit Codes

| Code | Meaning                                                     |
| ---- | ----------------------------------------------------------- |
| `0`  | Success - user configured with all roles                    |
| `1`  | Error - validation, authentication, or SQL execution failed |

---

## 🔒 Security Considerations

- Uses Azure AD token authentication (no SQL passwords)
- Access tokens are not logged or persisted
- SQL injection protection via parameterized principals
- Connections use encryption (TLS 1.2+)

---

## ⚠️ Known Limitations

- Requires Microsoft Entra ID authentication to be enabled on the SQL Server
- Cannot create users in the `master` database (by design)
- Principal names with special characters should be enclosed in brackets in Entra ID

---

## 📚 Related Scripts

| Script                              | Purpose                                          |
| ----------------------------------- | ------------------------------------------------ |
| [postprovision](./postprovision.md) | Calls this script for SQL managed identity setup |

---

## 📜 Version History

| Version | Date       | Changes                                                       |
| ------- | ---------- | ------------------------------------------------------------- |
| 1.0.0   | 2026-01-06 | Initial release - Entra ID managed identity SQL configuration |

> [!CAUTION]
> Ensure firewall rules allow access to Azure SQL Database from your current IP before running this script.

## 🔗 Links

- [Repository](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- [Azure SQL Authentication with Azure AD](https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure)
- [Managed Identities Overview](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview)

---

<div align="center">

**[⬆️ Back to Top](#-sql-managed-identity-config)** · **[← configure-federated-credential](./configure-federated-credential.md)** · **[🪝 Hooks Index](./README.md)**

## </div>

[⬅️ Back to Index](./README.md)
