# Logic App API Connections Setup

This document explains how to link API connections to your Logic App workflow.

## Overview

Logic Apps use API connections to interact with external services like Azure Storage Queues and Tables. To use these connections in your workflow, you need to:

1. **Create the API connection resources** (done in `logic-app.bicep`)
2. **Configure access policies** to allow the Logic App's managed identity to use the connections (done in `logic-app.bicep`)
3. **Create a connections.json file** that maps connection reference names to actual connection resource IDs
4. **Deploy the connections.json** to your Logic App

## Architecture

```
Logic App (Managed Identity)
    ↓ (has access via access policies)
API Connections (azurequeues, azuretables)
    ↓ (authenticated to)
Storage Account (with RBAC roles)
```

## Files

### 1. logic-app.bicep
Creates:
- Logic App (Standard) with user-assigned managed identity
- API connection resources (`storageQueueApiConnection` and `tbConn`)
- Access policies that grant the managed identity permission to use the connections
- RBAC role assignments on the storage account

### 2. connections.json
Maps the connection reference names (used in workflow definition) to actual Azure resources:
```json
{
  "managedApiConnections": {
    "azurequeues": {
      "api": { "id": "..." },
      "connection": { "id": "..." },
      "connectionRuntimeUrl": "...",
      "authentication": { "type": "ManagedServiceIdentity" }
    }
  }
}
```

### 3. workflowDefinition.json
Your workflow references connections by name:
```json
{
  "triggers": {
    "When_there_are_messages_in_a_queue_(V2)": {
      "type": "ApiConnection",
      "inputs": {
        "host": {
          "connection": {
            "referenceName": "azurequeues"  ← This name must match connections.json
          }
        }
      }
    }
  }
}
```

## Deployment Steps

### Step 1: Deploy Infrastructure
```powershell
# Deploy using Azure Developer CLI
azd provision -e dev

# Or using Azure CLI
az deployment group create \
  --resource-group <resource-group-name> \
  --template-file infra/main.bicep
```

### Step 2: Configure Connections
After infrastructure is deployed, run the PowerShell script to upload connections.json:

```powershell
.\deploy-connections.ps1 `
  -ResourceGroupName "rg-eshoporders-dev" `
  -LogicAppName "eshoporders-abc123-logicapp" `
  -QueueConnectionName "azurequeues" `
  -TableConnectionName "azuretables" `
  -WorkflowName "eShopOrders"
```

**What this script does:**
1. Retrieves the actual connection resource IDs
2. Gets the connection runtime URLs from Azure
3. Updates the connections.json template with real values
4. Deploys the connections.json to your Logic App's workflow folder

### Step 3: Deploy Workflow Definition
```powershell
# Deploy the workflow definition
az logicapp deployment source config-zip \
  --resource-group <resource-group-name> \
  --name <logic-app-name> \
  --src <path-to-workflow-zip>
```

## Manual Alternative (Azure Portal)

If you prefer to configure connections manually:

1. Go to Azure Portal → Your Logic App
2. Open the workflow designer for your workflow
3. For each action/trigger using a connection:
   - Click on the connection
   - Select "Add new connection"
   - Choose "Connect with managed identity"
   - Select your Logic App's managed identity
   - Save

## Connection Reference Names

Your workflow uses these connection reference names:
- `azurequeues` - For Azure Queue Storage operations
- `azuretables` - For Azure Table Storage operations

These names MUST match the keys in `managedApiConnections` in connections.json.

## Troubleshooting

### Error: "The workflow trigger or action references a connection that does not exist"
**Solution:** Run the `deploy-connections.ps1` script to deploy connections.json

### Error: "Unauthorized" when workflow runs
**Solution:** Check that:
1. Access policies are created for both connections
2. The managed identity has proper RBAC roles on the storage account
3. The connections.json references the correct connection resource IDs

### Connection shows as "Disconnected" in portal
**Solution:** This is normal for managed identity connections. They don't show as "Connected" in the portal but will work if configured correctly.

## Security Best Practices

✓ **Uses Managed Identity** - No keys or secrets stored in workflow  
✓ **RBAC on Storage** - Managed identity has minimal required permissions  
✓ **Access Policies** - Only the Logic App's identity can use the connections  
✓ **HTTPS Only** - All connections use encrypted communication  

## Learn More

- [Logic Apps API Connections](https://learn.microsoft.com/azure/logic-apps/logic-apps-securing-a-logic-app#access-to-connections)
- [Managed Identities in Logic Apps](https://learn.microsoft.com/azure/logic-apps/create-managed-service-identity)
- [Azure Storage RBAC Roles](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory)
