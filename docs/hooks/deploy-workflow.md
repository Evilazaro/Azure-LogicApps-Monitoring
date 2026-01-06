# deploy-workflow (.ps1)

![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)
![Azure CLI](https://img.shields.io/badge/Azure%20CLI-2.60+-blue.svg)
![Azure Developer CLI](https://img.shields.io/badge/azd-Required-orange.svg)
![Version](https://img.shields.io/badge/version-1.1.0-green.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

## 📋 Overview

The `deploy-workflow` script is a comprehensive deployment utility for Azure Logic Apps Standard workflows that automates the complete deployment lifecycle. As a PowerShell-based tool integrated with Azure Developer CLI (azd), it handles environment configuration, placeholder replacement, and Azure CLI zip deployment in a single, streamlined operation.

This script performs intelligent placeholder replacement in both workflow.json and connections.json files, substituting environment variable tokens with actual values from the active azd environment. It then packages the workflow artifacts and deploys them to Azure Logic Apps Standard using the reliable zip deployment method, ensuring consistent and reproducible deployments across development, staging, and production environments.

With built-in WhatIf mode for deployment previews, comprehensive error handling, and detailed progress reporting across five distinct phases, the script typically completes in 30-60 seconds. It supports both automated CI/CD pipeline integration and manual execution, providing flexibility for various deployment workflows while maintaining a Zero Trust security approach through managed identity authentication.

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [🎯 Purpose](#-purpose)
- [📦 Placeholders Replaced](#-placeholders-replaced)
  - [🔄 Workflow Placeholders](#workflow-placeholders-workflowjson)
  - [🔗 Connection Placeholders](#connection-placeholders-connectionsjson)
- [🚀 Usage](#-usage)
  - [💻 Basic Usage](#basic-usage)
  - [⚡ Force Mode](#force-mode)
  - [👁️ Preview Mode (WhatIf)](#preview-mode-whatif)
  - [📝 Verbose Mode](#verbose-mode)
  - [🔀 Skip Placeholder Replacement](#skip-placeholder-replacement)
- [🔧 Parameters](#-parameters)
- [📚 Examples](#-examples)
  - [✅ Example 1: Standard Deployment](#example-1-standard-deployment)
  - [🔁 Example 2: CI/CD Integration](#example-2-cicd-integration)
- [🛠️ How It Works](#️-how-it-works)
  - [📊 Workflow Diagram](#workflow-diagram)
  - [🔗 Integration Points](#integration-points)
  - [🏗️ Deployment Process](#deployment-process)
- [📋 Prerequisites](#-prerequisites)
  - [🔧 Required Tools](#required-tools)
  - [🔑 Authentication](#authentication)
  - [📝 Required Environment Variables](#required-environment-variables)
- [🐛 Troubleshooting](#-troubleshooting)
  - [❓ Common Issues](#common-issues)
  - [🔧 Debug Mode](#debug-mode)
- [📖 Related Documentation](#-related-documentation)
- [🔐 Security Considerations](#-security-considerations)
  - [✅ Safe Operations](#safe-operations)
  - [🔑 Authentication Security](#authentication-security)
- [🎓 Best Practices](#-best-practices)
  - [📋 When to Use This Script](#when-to-use-this-script)
  - [🔄 Development Workflow Integration](#development-workflow-integration)
- [📊 Performance](#-performance)
  - [⚡ Performance Characteristics](#performance-characteristics)
- [📜 Version History](#-version-history)

---

## 🎯 Purpose

This script helps developers and operators:

- ✅ **Deploy Workflows**: Deploy Logic Apps Standard workflows using Azure CLI zip deployment
- ✅ **Replace Placeholders**: Automatically substitute placeholder tokens with environment values
- ✅ **Load azd Environment**: Automatically load variables from the active azd environment
- ✅ **Validate Configuration**: Ensure Azure CLI connection and environment variables before deployment
- ✅ **Preview Deployments**: Use WhatIf mode to see changes without deploying
- ✅ **CI/CD Integration**: Seamlessly integrate with automated deployment pipelines

---

## 📦 Placeholders Replaced

### Workflow Placeholders (workflow.json)

| Placeholder                             | Environment Variable                  | Description                           |
| --------------------------------------- | ------------------------------------- | ------------------------------------- |
| `${ORDERS_API_URL}`                     | `ORDERS_API_URL`                      | Orders API endpoint URL               |
| `${AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW}` | `AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW` | Storage account for workflow state    |

### Connection Placeholders (connections.json)

| Placeholder                              | Environment Variable                   | Description                           |
| ---------------------------------------- | -------------------------------------- | ------------------------------------- |
| `${AZURE_SUBSCRIPTION_ID}`               | `AZURE_SUBSCRIPTION_ID`                | Azure subscription ID                 |
| `${AZURE_RESOURCE_GROUP}`                | `AZURE_RESOURCE_GROUP`                 | Azure resource group name             |
| `${MANAGED_IDENTITY_NAME}`               | `MANAGED_IDENTITY_NAME`                | User-assigned managed identity name   |
| `${SERVICE_BUS_CONNECTION_RUNTIME_URL}`  | `SERVICE_BUS_CONNECTION_RUNTIME_URL`   | Service Bus API connection runtime URL |
| `${AZURE_BLOB_CONNECTION_RUNTIME_URL}`   | `AZURE_BLOB_CONNECTION_RUNTIME_URL`    | Blob Storage API connection runtime URL |

---

## 🚀 Usage

### Basic Usage

```powershell
# Deploy using environment variables from azd
./deploy-workflow.ps1

# Deploy to specific Logic App and Resource Group
./deploy-workflow.ps1 -LogicAppName "my-logic-app" -ResourceGroupName "my-rg"

# Deploy a specific workflow
./deploy-workflow.ps1 -WorkflowName "MyCustomWorkflow"

# Preview deployment without making changes
./deploy-workflow.ps1 -WhatIf

# Skip placeholder replacement (files already processed)
./deploy-workflow.ps1 -SkipPlaceholderReplacement

# Enable verbose output
./deploy-workflow.ps1 -Verbose
```

---

## 📋 Parameters

| Parameter                    | Type   | Required | Default                      | Description                                          |
| ---------------------------- | ------ | -------- | ---------------------------- | ---------------------------------------------------- |
| `-LogicAppName`              | String | No       | From `LOGIC_APP_NAME` env var | The name of the Azure Logic Apps Standard resource   |
| `-ResourceGroupName`         | String | No       | From `AZURE_RESOURCE_GROUP` env var | The name of the Azure resource group            |
| `-WorkflowName`              | String | No       | `ProcessingOrdersPlaced`     | The name of the workflow to deploy                   |
| `-WorkflowBasePath`          | String | No       | `../workflows/OrdersManagement/...` | Base path to the Logic App workflow files      |
| `-SkipPlaceholderReplacement`| Switch | No       | -                            | Skip placeholder replacement if files are processed  |
| `-WhatIf`                    | Switch | No       | -                            | Shows what changes would be made without deploying   |
| `-Confirm`                   | Switch | No       | -                            | Prompts for confirmation before deploying            |

---

## 📊 Example Output

```
╔══════════════════════════════════════════════════════════════╗
║     Azure Logic Apps Workflow Deployment Script              ║
║     (Using Azure CLI and Azure Developer CLI)                ║
╚══════════════════════════════════════════════════════════════╝

[1/5] Loading azd environment...
  Loading azd environment variables...
  Loaded 15 environment variables from azd.
  Using Logic App from environment: logic-app-dev
  Using Resource Group from environment: rg-logicapps-dev

[2/5] Validating Azure CLI connection...
  Connected as: user@domain.com
  Subscription: My Subscription (12345678-1234-1234-1234-123456789012)

[3/5] Validating environment variables...
  All required environment variables are set.

=== Environment Variables Summary ===
  Workflow Variables:
    ORDERS_API_URL: https://orders-api...
    AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW: stlogicappdev
  Connection Variables:
    AZURE_SUBSCRIPTION_ID: 12345678-1234...
    AZURE_RESOURCE_GROUP: rg-logicapps-dev
    MANAGED_IDENTITY_NAME: id-logicapps-dev
    SERVICE_BUS_CONNECTION_RUNTIME_URL: https://servicebus-...
    AZURE_BLOB_CONNECTION_RUNTIME_URL: https://blob-...

[4/5] Processing workflow files...
  Workflow file: D:\app\workflows\...\ProcessingOrdersPlaced\workflow.json
  Connections file: D:\app\workflows\...\connections.json
  Replacing placeholders in workflow.json...
  Replacing placeholders in connections.json...
  Files processed successfully.

[5/5] Deploying workflow to Azure Logic Apps via zip deploy...
  Logic App: logic-app-dev
  Resource Group: rg-logicapps-dev
  Workflow: ProcessingOrdersPlaced
  Creating deployment package...
  Deploying to Logic App via zip deploy...
  Workflow deployed successfully!

=== Post-Deployment Notes ===
  - Connections are configured in connections.json
  - Ensure API connections are authorized in Azure Portal
  - Verify managed identity has required permissions

╔══════════════════════════════════════════════════════════════╗
║              Deployment Completed Successfully!              ║
╚══════════════════════════════════════════════════════════════╝
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
    run: ./hooks/deploy-workflow.ps1
```

---

## 🏗️ Deployment Process

The script uses a **zip deployment** approach:

1. Creates a temporary directory
2. Copies workflow.json to `<WorkflowName>/workflow.json`
3. Copies connections.json to root level
4. Copies host.json if present
5. Creates a zip archive
6. Deploys using `az logicapp deployment source config-zip`
7. Cleans up temporary files

This approach is reliable and consistent with Azure Logic Apps Standard deployment patterns.

---

## ⚠️ Prerequisites

### Required Tools

| Tool                   | Version | Purpose                              | Installation                      |
| ---------------------- | ------- | ------------------------------------ | --------------------------------- |
| PowerShell Core        | 7.0+    | Script execution                     | `winget install Microsoft.PowerShell` |
| Azure CLI              | 2.60+   | Azure resource management            | `winget install Microsoft.AzureCLI` |
| Azure Developer CLI    | Latest  | Environment variable management      | `winget install Microsoft.Azd`    |

### Authentication

Before running the script:
1. Login to Azure CLI: `az login`
2. Select subscription: `az account set --subscription <id>`
3. Initialize azd environment: `azd env select <env-name>`

### Required Environment Variables

The following environment variables must be set (via azd or manually):

- `LOGIC_APP_NAME` (if not passed as parameter)
- `AZURE_RESOURCE_GROUP` (if not passed as parameter)
- `ORDERS_API_URL`
- `AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW`
- `AZURE_SUBSCRIPTION_ID`
- `MANAGED_IDENTITY_NAME`
- `SERVICE_BUS_CONNECTION_RUNTIME_URL`
- `AZURE_BLOB_CONNECTION_RUNTIME_URL`

---

## 🐛 Troubleshooting

### Common Issues

1. **"Not connected to Azure. Please run 'az login' first."**
   - Run: `az login`
   - Verify: `az account show`

2. **"Could not load azd environment variables"**
   - Ensure azd is installed: `azd version`
   - Ensure an environment is selected: `azd env list`
   - Initialize environment: `azd env select <env-name>`

3. **"LogicAppName parameter is required"**
   - Either pass `-LogicAppName` parameter or ensure `LOGIC_APP_NAME` is set
   - Set via azd: `azd env set LOGIC_APP_NAME <value>`

4. **"Deployment failed"**
   - Check Azure CLI version: `az --version`
   - Verify Logic App exists in Azure
   - Check Logic App deployment logs in Azure Portal

---

## 📖 Related Documentation

- [Azure Logic Apps Standard Deployment](https://learn.microsoft.com/azure/logic-apps/set-up-devops-deployment-single-tenant-azure-logic-apps)
- [Azure CLI Logic Apps Commands](https://learn.microsoft.com/cli/azure/logicapp)
- [Azure Developer CLI Hooks](https://learn.microsoft.com/azure/developer/azure-developer-cli/azd-extensibility)
