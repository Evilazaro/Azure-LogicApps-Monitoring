# Replace-ConnectionPlaceholders Script

![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)
![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)
![Azure Developer CLI](https://img.shields.io/badge/azd-Required-orange.svg)
![Cross-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)

## 📋 Overview

The `Replace-ConnectionPlaceholders` script replaces placeholder tokens in the `connections.json` file with actual environment variable values. This is essential for configuring Azure Logic Apps Standard API connections with the correct subscription, resource group, and runtime URLs.

### Available Implementations

| Platform   | Script                               | Description                                  |
| ---------- | ------------------------------------ | -------------------------------------------- |
| PowerShell | `Replace-ConnectionPlaceholders.ps1` | Full-featured PowerShell 7.0+ implementation |
| Bash       | `replace-connection-placeholders.sh` | Cross-platform Bash 4.0+ implementation      |

---

## 🎯 Purpose

The script performs the following operations:

1. **Loads azd environment variables** from the active Azure Developer CLI environment
2. **Validates required environment variables** are set
3. **Replaces placeholder tokens** in connections.json with actual values
4. **Supports WhatIf mode** for previewing changes without modification

---

## 📦 Placeholders Replaced

| Placeholder                             | Environment Variable                 | Description                             |
| --------------------------------------- | ------------------------------------ | --------------------------------------- |
| `${AZURE_SUBSCRIPTION_ID}`              | `AZURE_SUBSCRIPTION_ID`              | Azure subscription ID                   |
| `${AZURE_RESOURCE_GROUP}`               | `AZURE_RESOURCE_GROUP`               | Azure resource group name               |
| `${MANAGED_IDENTITY_NAME}`              | `MANAGED_IDENTITY_NAME`              | User-assigned managed identity name     |
| `${SERVICE_BUS_CONNECTION_RUNTIME_URL}` | `SERVICE_BUS_CONNECTION_RUNTIME_URL` | Service Bus API connection runtime URL  |
| `${AZURE_BLOB_CONNECTION_RUNTIME_URL}`  | `AZURE_BLOB_CONNECTION_RUNTIME_URL`  | Blob Storage API connection runtime URL |

---

## 🚀 Usage

### PowerShell

```powershell
# Basic usage (uses default connections.json path)
./Replace-ConnectionPlaceholders.ps1

# Specify custom input file
./Replace-ConnectionPlaceholders.ps1 -ConnectionsFilePath "./custom/connections.json"

# Specify custom output file
./Replace-ConnectionPlaceholders.ps1 -OutputFilePath "./output/connections.json"

# Preview changes without modifying files
./Replace-ConnectionPlaceholders.ps1 -WhatIf

# Enable verbose output
./Replace-ConnectionPlaceholders.ps1 -Verbose
```

### Bash

```bash
# Basic usage (uses default connections.json path)
./replace-connection-placeholders.sh

# Specify custom input file
./replace-connection-placeholders.sh -f "./custom/connections.json"

# Specify custom output file
./replace-connection-placeholders.sh -o "./output/connections.json"

# Preview changes without modifying files
./replace-connection-placeholders.sh --dry-run

# Enable verbose output
./replace-connection-placeholders.sh --verbose

# Show help
./replace-connection-placeholders.sh --help
```

---

## 📋 Parameters

### PowerShell Parameters

| Parameter              | Type   | Required | Default                                              | Description                                     |
| ---------------------- | ------ | -------- | ---------------------------------------------------- | ----------------------------------------------- |
| `-ConnectionsFilePath` | String | No       | `../workflows/OrdersManagement/.../connections.json` | Path to the connections.json file               |
| `-OutputFilePath`      | String | No       | Same as input                                        | Output file path (overwrites input if not set)  |
| `-WhatIf`              | Switch | No       | -                                                    | Shows what changes would be made without saving |
| `-Verbose`             | Switch | No       | -                                                    | Enables detailed logging                        |
| `-Confirm`             | Switch | No       | -                                                    | Prompts for confirmation before making changes  |

### Bash Parameters

| Parameter   | Short | Required | Default                                              | Description                                     |
| ----------- | ----- | -------- | ---------------------------------------------------- | ----------------------------------------------- |
| `--file`    | `-f`  | No       | `../workflows/OrdersManagement/.../connections.json` | Path to the connections.json file               |
| `--output`  | `-o`  | No       | Same as input                                        | Output file path (overwrites input if not set)  |
| `--dry-run` | `-n`  | No       | -                                                    | Shows what changes would be made without saving |
| `--verbose` | `-v`  | No       | -                                                    | Enables detailed logging                        |
| `--help`    | `-h`  | No       | -                                                    | Displays help message                           |

---

## 📊 Example Output

```
=== Connection Placeholders Replacement Script ===

Loading azd environment variables...
Loaded 15 environment variables from azd.
Input file: D:\app\workflows\OrdersManagement\OrdersManagementLogicApp\connections.json
Validating required environment variables...
All required environment variables are set.
Reading connections file...
Replacing placeholders with environment variable values...
Writing updated connections file to: D:\app\workflows\OrdersManagement\OrdersManagementLogicApp\connections.json

Successfully replaced all placeholders in connections.json

=== Replacement Summary ===
  AZURE_SUBSCRIPTION_ID: 12345678-1234-1234-1234-123456789012
  AZURE_RESOURCE_GROUP: rg-logicapps-dev
  MANAGED_IDENTITY_NAME: id-logicapps-dev
  SERVICE_BUS_CONNECTION_RUNTIME_URL: https://servicebus-...
  AZURE_BLOB_CONNECTION_RUNTIME_URL: https://blob-...
```

---

## 🔗 Integration with azd

This script integrates with Azure Developer CLI (azd) for environment management:

1. **Automatic variable loading**: The script automatically loads environment variables from the active azd environment
2. **No manual configuration**: Environment variables are provisioned by `azd provision` and loaded automatically
3. **Environment isolation**: Each azd environment (dev, staging, prod) can have different values

### azd Hook Integration

The script can be configured as an azd hook in `azure.yaml`:

```yaml
hooks:
  predeploy:
    shell: pwsh
    run: ./hooks/Replace-ConnectionPlaceholders.ps1
```

---

## ⚠️ Prerequisites

### Required Tools

| Tool                | Version | Purpose                         | Installation                          |
| ------------------- | ------- | ------------------------------- | ------------------------------------- |
| PowerShell Core     | 7.0+    | Script execution (PowerShell)   | `winget install Microsoft.PowerShell` |
| Bash                | 4.0+    | Script execution (Bash)         | Included in Linux/macOS               |
| Azure Developer CLI | Latest  | Environment variable management | `winget install Microsoft.Azd`        |

### Required Environment Variables

Before running the script, ensure either:

- An active azd environment is configured (`azd env select <env-name>`)
- All required environment variables are set manually

---

## 🐛 Troubleshooting

### Common Issues

1. **"Could not load azd environment variables"**

   - Ensure azd is installed: `azd version`
   - Ensure an environment is selected: `azd env list`
   - Initialize environment: `azd env select <env-name>`

2. **"Required environment variables are not set"**

   - Run `azd provision` to create resources and set variables
   - Manually set missing variables: `azd env set <VAR_NAME> <value>`

3. **"Connections file not found"**
   - Verify the file path exists
   - Use `-ConnectionsFilePath` to specify the correct path

---

## 📖 Related Documentation

- [Azure Logic Apps API Connections](https://learn.microsoft.com/azure/logic-apps/logic-apps-azure-resource-manager-templates-overview#api-connections)
- [Azure Developer CLI Hooks](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-extensibility)
- [Managed Identity for Logic Apps](https://learn.microsoft.com/azure/logic-apps/logic-apps-securing-a-logic-app)
