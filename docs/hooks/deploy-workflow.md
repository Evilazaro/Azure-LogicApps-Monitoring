# deploy-workflow Hook

Deploys Logic Apps Standard workflows to Azure as part of the Azure Developer CLI (azd) deployment process.

## Overview

This hook deploys workflow definitions from the OrdersManagement Logic App to Azure. It runs as an `azd predeploy` hook, meaning all required environment variables are automatically loaded by azd during the provisioning process.

## Prerequisites

- **Azure CLI** 2.50 or later
- **PowerShell Core** 7.0 or later (for `.ps1`)
- **Bash** 4.0 or later with `jq` (for `.sh`)
- Active Azure subscription with appropriate permissions
- Logic App Standard resource already provisioned

## Files

| File | Platform | Description |
|------|----------|-------------|
| `deploy-workflow.ps1` | Windows/Linux/macOS | PowerShell Core implementation |
| `deploy-workflow.sh` | Linux/macOS | Bash implementation |

## Usage

### As AZD Hook (Recommended)

The scripts are automatically executed by azd during deployment. No manual invocation required.

### Manual Execution

```powershell
# PowerShell
./hooks/deploy-workflow.ps1

# With custom workflow path
./hooks/deploy-workflow.ps1 -WorkflowPath "C:\MyWorkflows\LogicApp"
```

```bash
# Bash
./hooks/deploy-workflow.sh

# With custom workflow path
./hooks/deploy-workflow.sh "/path/to/workflows"
```

## Environment Variables

### Required Variables

| Variable | Description | Source |
|----------|-------------|--------|
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | azd env |
| `AZURE_RESOURCE_GROUP` | Target resource group name | azd env |
| `LOGIC_APP_NAME` | Name of the Logic App Standard resource | azd env |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `AZURE_LOCATION` | Azure region | `westus3` |
| `SERVICE_BUS_CONNECTION_RUNTIME_URL` | Service Bus connection runtime URL | Auto-fetched |
| `AZURE_BLOB_CONNECTION_RUNTIME_URL` | Blob storage connection runtime URL | Auto-fetched |

### Auto-Generated Aliases

The script automatically creates these aliases for `connections.json` compatibility:

| Alias Variable | Source Variable |
|----------------|-----------------|
| `WORKFLOWS_SUBSCRIPTION_ID` | `AZURE_SUBSCRIPTION_ID` |
| `WORKFLOWS_RESOURCE_GROUP_NAME` | `AZURE_RESOURCE_GROUP` |
| `WORKFLOWS_LOCATION_NAME` | `AZURE_LOCATION` |

## Workflow Discovery

The script automatically discovers workflows by:

1. Scanning subdirectories of the workflow project path
2. Looking for directories containing a `workflow.json` file
3. Excluding directories matching patterns in `.funcignore`:
   - `.debug`, `.git*`, `.vscode`
   - `__azurite*`, `__blobstorage__`, `__queuestorage__`
   - `local.settings.json`, `test`, `workflow-designtime`

## Placeholder Resolution

The script resolves `${VARIABLE_NAME}` placeholders in:

- `connections.json`
- `parameters.json`
- `workflow.json` files

Unresolved placeholders generate warnings but don't fail the deployment.

## Deployment Process

1. **Environment Setup**: Maps `AZURE_*` variables to `WORKFLOWS_*` aliases
2. **Validation**: Checks required environment variables
3. **Discovery**: Finds workflow project and discovers workflows
4. **Connection URLs**: Fetches runtime URLs for API connections (if not in environment)
5. **Staging**: Creates temporary directory with resolved configuration files
6. **Packaging**: Creates ZIP archive of deployment artifacts
7. **Settings Update**: Updates Logic App application settings with connection URLs
8. **Deployment**: Deploys ZIP package using `az functionapp deployment source config-zip`
9. **Cleanup**: Removes temporary files

## Error Handling

| Exit Code | Description |
|-----------|-------------|
| 0 | Deployment successful |
| 1 | Missing required environment variables |
| 1 | Workflow project not found |
| 1 | No workflows discovered |
| 1 | Deployment command failed |

## Troubleshooting

### Common Issues

#### "Missing environment variables" Error

Ensure azd environment is properly initialized:

```bash
azd env list
azd env get-values
```

#### "Workflow project not found" Error

Verify the workflow project exists at:

```
workflows/OrdersManagement/OrdersManagementLogicApp/
```

Or provide a custom path using the `WorkflowPath` parameter.

#### Unresolved Placeholders Warnings

Check that all required environment variables are set in your azd environment:

```bash
azd env set VARIABLE_NAME "value"
```

#### Connection Runtime URL Fetch Failed

Ensure:
1. API connections exist in the resource group
2. Azure CLI is authenticated with appropriate permissions
3. Subscription ID is correct

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.1 | 2026-01-07 | PSScriptAnalyzer compliance, added Bash equivalent |
| 2.0.0 | - | Initial release with environment variable support |
