# OrdersManagement Logic App

Azure Logic App (Standard) for processing e-commerce orders through Service Bus and Blob Storage.

## Overview

This Logic App handles the order processing workflow for the eShop application:

1. **OrdersPlacedProcess**: Listens for new orders on Service Bus, processes them via the Orders API, and stores results in Blob Storage
2. **OrdersPlacedCompleteProcess**: Periodically cleans up successfully processed order blobs

## Configuration Files

### Runtime Configuration

| File | Purpose | Schema |
|------|---------|--------|
| `host.json` | Azure Functions host configuration | [host.json Schema](https://json.schemastore.org/host.json) |
| `local.settings.json` | Local development environment variables | [local.settings.json Schema](https://json.schemastore.org/local.settings.json) |
| `connections.json` | API connection definitions (Service Bus, Blob Storage) | Azure Logic Apps |
| `parameters.json` | Workflow parameter definitions | Azure Logic Apps |

### Workflow Definitions

| Folder | Workflow | Trigger | Description |
|--------|----------|---------|-------------|
| `OrdersPlacedProcess/` | Order Processing | Service Bus Topic | Processes incoming orders and calls Orders API |
| `OrdersPlacedCompleteProcess/` | Cleanup | Recurrence (3s) | Removes processed order blobs |

## Environment Variables

### Required for Local Development

Set these in `local.settings.json`:

| Variable | Description | Example |
|----------|-------------|---------|
| `SERVICE_BUS_CONNECTION_RUNTIME_URL` | Service Bus connection runtime URL | `https://<namespace>.servicebus.windows.net/...` |
| `AZURE_BLOB_CONNECTION_RUNTIME_URL` | Blob Storage connection runtime URL | `https://<storage>.blob.core.windows.net/...` |
| `AZURE_TENANT_ID` | Azure AD Tenant ID | GUID |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | GUID |
| `AZURE_RESOURCE_GROUP` | Resource group name | `rg-eshop-dev` |
| `AZURE_LOCATION` | Azure region | `eastus` |

### Required for Deployed Workflows

| Variable | Description |
|----------|-------------|
| `ORDERS_API_URL` | Base URL for the Orders API service |
| `AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW` | Storage account for workflow data |
| `MANAGED_IDENTITY_NAME` | User-assigned managed identity name |

## Connections

### Service Bus (`servicebus`)

- **Type**: Managed API Connection
- **Authentication**: User-Assigned Managed Identity
- **Audience**: `https://servicebus.azure.net`
- **Topic**: `ordersplaced`
- **Subscription**: `orderprocessingsub`

### Azure Blob Storage (`azureblob`, `azureblob-1`)

- **Type**: Managed API Connection
- **Authentication**: User-Assigned Managed Identity
- **Audience**: `https://storage.azure.com/`
- **Containers**:
  - `/ordersprocessedsuccessfully` - Successfully processed orders
  - `/ordersprocessedwitherrors` - Failed order processing

## Local Development

### Prerequisites

1. [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local)
2. [.NET 8.0 SDK](https://dotnet.microsoft.com/download)
3. [Azure Storage Emulator](https://learn.microsoft.com/azure/storage/common/storage-use-azurite) or Azurite

### Running Locally

1. Copy `local.settings.json.template` to `local.settings.json` (if exists)
2. Update environment variable placeholders with actual values
3. Start the Functions host:

   ```bash
   func host start
   ```

4. Or use VS Code task: `Ctrl+Shift+B` (runs `func: host start`)

### Debugging

1. Run the `func: host start` task
2. Attach debugger using `Run/Debug logic app OrdersManagementLogicApp` configuration
3. Set breakpoints in workflow.json files (supported in designer view)

## Deployment

Deployment is handled through Azure Developer CLI (`azd`) using the infrastructure definitions in `/infra/workload/logic-app.bicep`.

## Related Documentation

- [Azure Logic Apps (Standard) Documentation](https://learn.microsoft.com/azure/logic-apps/single-tenant-overview-compare)
- [Logic Apps in VS Code](https://learn.microsoft.com/azure/logic-apps/create-single-tenant-workflows-visual-studio-code)
- [Managed Connectors](https://learn.microsoft.com/azure/connectors/introduction)
