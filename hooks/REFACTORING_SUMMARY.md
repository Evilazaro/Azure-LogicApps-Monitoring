# Hooks Scripts Refactoring Summary

## Overview

The hooks scripts have been refactored to accurately reflect the current state of the Azure Logic Apps Monitoring solution infrastructure as defined in the Bicep templates.

## Date of Refactoring

**December 26, 2025**

## Changes Made

### 1. Infrastructure Analysis Completed

Analyzed all Bicep files in the `infra` folder to understand the complete infrastructure:

#### Core Infrastructure (infra/shared/)

**Identity** (`infra/shared/identity/main.bicep`):
- User-assigned managed identity with comprehensive role assignments
- Roles for Storage, Monitoring, Service Bus, Container Registry, etc.

**Monitoring** (`infra/shared/monitoring/main.bicep`):
- Log Analytics workspace
- Application Insights (workspace-based)
- Azure Monitor health model
- Storage account for diagnostic logs

**Data** (`infra/shared/data/main.bicep`):
- Storage account for Logic Apps runtime
- Blob containers: `ordersprocessedsuccessfully`, `ordersprocessedwitherrors`
- **SQL Server with Entra ID-only authentication**
- **SQL Database for application data** (NEW)

#### Workload Infrastructure (infra/workload/)

**Messaging** (`infra/workload/messaging/main.bicep`):
- Service Bus Standard namespace (16 messaging units)
- **Topic**: `OrdersPlaced` (changed from queue)
- **Subscription**: `OrderProcessingSubscription`

**Container Services** (`infra/workload/services/main.bicep`):
- **Azure Container Registry** (Premium tier)
- **Container Apps managed environment**
- **.NET Aspire dashboard component**

**Logic Apps** (`infra/workload/logic-app.bicep`):
- Logic Apps Standard workflow engine
- App Service Plan (WorkflowStandard tier, WS1 SKU)
- Elastic scaling: 3-20 instances

### 2. Updated postprovision.ps1

**New Environment Variables Added:**

```powershell
# SQL Database (NEW)
$azureSqlServerFqdn = Get-EnvironmentVariableSafe -Name 'ORDERSDATABASE_SQLSERVERFQDN'

# Container Services (EXPANDED)
$azureContainerRegistryName = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_REGISTRY_NAME'
$azureContainerAppsEnvironmentName = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_APPS_ENVIRONMENT_NAME'
$azureContainerAppsEnvironmentId = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_APPS_ENVIRONMENT_ID'
$azureContainerAppsEnvironmentDomain = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN'

# Monitoring (EXPANDED)
$azureLogAnalyticsWorkspaceName = Get-EnvironmentVariableSafe -Name 'AZURE_LOG_ANALYTICS_WORKSPACE_NAME'

# Identity (EXPANDED)
$azureManagedIdentityName = Get-EnvironmentVariableSafe -Name 'MANAGED_IDENTITY_NAME'

# Service Bus (UPDATED)
$azureMessagingServiceBusEndpoint = Get-EnvironmentVariableSafe -Name 'MESSAGING_SERVICEBUSENDPOINT'
```

**Updated AppHost Secrets (21 secrets):**

```powershell
$appHostSecrets = [ordered]@{
    'Azure:TenantId'                   = $azureTenantId
    'Azure:SubscriptionId'             = $azureSubscriptionId
    'Azure:Location'                   = $azureLocation
    'Azure:ResourceGroup'              = $azureResourceGroup
    'ApplicationInsights:Enabled'      = $enableApplicationInsights
    'Azure:ApplicationInsights:Name'   = $applicationInsightsName
    'ApplicationInsights:ConnectionString' = $applicationInsightsConnectionString
    'Azure:ClientId'   = $azureClientId
    'Azure:ManagedIdentity:Name'       = $azureManagedIdentityName
    'Azure:ServiceBus:HostName'        = $azureServiceBusHostName
    'Azure:ServiceBus:TopicName'       = $azureServiceBusTopicName
    'Azure:ServiceBus:SubscriptionName' = $azureServiceBusSubscriptionName
    'Azure:ServiceBus:Endpoint'        = $azureMessagingServiceBusEndpoint
    'Azure:SqlServer:Fqdn'             = $azureSqlServerFqdn  # NEW
    'Azure:Storage:AccountName'        = $azureStorageAccountName
    'Azure:ContainerRegistry:Endpoint' = $azureContainerRegistryEndpoint
    'Azure:ContainerRegistry:Name'     = $azureContainerRegistryName  # NEW
    'Azure:ContainerApps:EnvironmentName' = $azureContainerAppsEnvironmentName  # NEW
    'Azure:ContainerApps:EnvironmentId' = $azureContainerAppsEnvironmentId  # NEW
    'Azure:ContainerApps:DefaultDomain' = $azureContainerAppsEnvironmentDomain  # NEW
    'Azure:LogAnalytics:WorkspaceName' = $azureLogAnalyticsWorkspaceName  # NEW
}
```

**Updated API Secrets (7 secrets):**

```powershell
$apiSecrets = [ordered]@{
    'Azure:ServiceBus:HostName'        = $azureServiceBusHostName
    'Azure:ServiceBus:TopicName'       = $azureServiceBusTopicName
    'Azure:ServiceBus:SubscriptionName' = $azureServiceBusSubscriptionName
    'Azure:ServiceBus:Endpoint'        = $azureMessagingServiceBusEndpoint  # NEW
    'Azure:SqlServer:Fqdn'             = $azureSqlServerFqdn  # NEW
    'Azure:ClientId'   = $azureClientId  # NEW
    'ApplicationInsights:ConnectionString' = $applicationInsightsConnectionString  # NEW
}
```

### 3. Updated postprovision.sh

Applied identical changes to the Bash version for cross-platform consistency:

**New Environment Variables:**
- All environment variables from PowerShell version
- Same naming conventions
- Same default values for optional parameters

**Updated Secrets:**
- AppHost: 21 secrets (matching PowerShell)
- API: 7 secrets (matching PowerShell)

### 4. Key Changes Summary

| Component | Before | After | Change Type |
|-----------|--------|-------|-------------|
| **Database** | Not configured | SQL Server + Database with Entra ID auth | **ADDED** |
| **Service Bus** | Queue (implied) | Topic: `OrdersPlaced` + Subscription | **UPDATED** |
| **Container Registry** | Basic config | Full ACR with name and endpoint | **EXPANDED** |
| **Container Apps** | Not configured | Environment with ID and domain | **ADDED** |
| **Monitoring** | Basic App Insights | Full observability with Log Analytics | **EXPANDED** |
| **Identity** | Client ID only | Client ID + Name | **EXPANDED** |
| **Storage** | Volume names | Workflow storage account | **SIMPLIFIED** |
| **Total Secrets** | 26 (3 projects) | 28 (2 projects) | **UPDATED** |

### 5. Removed Configuration

**Removed from scripts:**
- `ORDERS_STORAGE_VOLUME_NAME` - No longer in Bicep outputs
- `ORDERS_STORAGE_ACCOUNT_NAME` - Consolidated to workflow storage
- `eShop.Web.App` secrets - Not required by current architecture

### 6. Documentation Updates

Created comprehensive documentation covering:

1. **Complete environment variable reference**
   - Source: Bicep outputs from `main.bicep`
   - Default values for optional parameters
   - Relationship between variables and infrastructure

2. **Infrastructure component mapping**
   - How each Bicep module contributes environment variables
   - Resource relationships and dependencies

3. **Security model documentation**
   - Entra ID authentication for SQL Server
   - Managed identity usage throughout
   - RBAC role assignments

4. **Troubleshooting guide**
   - SQL Server Entra ID authentication
   - Service Bus topic configuration
   - Container Registry authentication
   - Common deployment issues

## Bicep Output Mapping

### main.bicep Outputs

```bicep
// Identity Outputs (infra/shared/identity/)
MANAGED_IDENTITY_CLIENT_ID         → Azure:ClientId
MANAGED_IDENTITY_NAME              → Azure:ManagedIdentity:Name

// Monitoring Outputs (infra/shared/monitoring/)
AZURE_LOG_ANALYTICS_WORKSPACE_NAME → Azure:LogAnalytics:WorkspaceName
APPLICATION_INSIGHTS_NAME          → Azure:ApplicationInsights:Name
APPLICATIONINSIGHTS_CONNECTION_STRING → ApplicationInsights:ConnectionString

// Data Outputs (infra/shared/data/)
ORDERSDATABASE_SQLSERVERFQDN       → Azure:SqlServer:Fqdn
AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW → Azure:Storage:AccountName

// Messaging Outputs (infra/workload/messaging/)
MESSAGING_SERVICEBUSENDPOINT       → Azure:ServiceBus:Endpoint
MESSAGING_SERVICEBUSHOSTNAME       → Azure:ServiceBus:HostName

// Container Registry Outputs (infra/workload/services/)
AZURE_CONTAINER_REGISTRY_ENDPOINT  → Azure:ContainerRegistry:Endpoint
AZURE_CONTAINER_REGISTRY_NAME      → Azure:ContainerRegistry:Name

// Container Apps Outputs (infra/workload/services/)
AZURE_CONTAINER_APPS_ENVIRONMENT_NAME → Azure:ContainerApps:EnvironmentName
AZURE_CONTAINER_APPS_ENVIRONMENT_ID   → Azure:ContainerApps:EnvironmentId
AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN → Azure:ContainerApps:DefaultDomain
```

## Testing Recommendations

After refactoring, test the following scenarios:

### 1. Fresh Deployment

```powershell
# Clean environment
azd down --force --purge

# Fresh provision
azd provision

# Verify secrets
dotnet user-secrets list --project .\app.AppHost\app.AppHost.csproj
dotnet user-secrets list --project .\src\eShop.Orders.API\eShop.Orders.API.csproj
```

### 2. Manual Execution

```powershell
# PowerShell
.\hooks\postprovision.ps1 -Verbose

# Verify output matches Bicep resources
```

```bash
# Bash
./hooks/postprovision.sh --verbose
```

### 3. Verify Infrastructure

```powershell
# Check SQL Server
az sql server show --name <server-name> --resource-group <rg-name>

# Check Service Bus topic
az servicebus topic show `
    --namespace-name <namespace> `
    --resource-group <rg-name> `
    --name OrdersPlaced

# Check Container Registry
az acr show --name <acr-name> --resource-group <rg-name>

# Check Container Apps Environment
az containerapp env show --name <env-name> --resource-group <rg-name>
```

### 4. Application Configuration

Verify the application can:
- Connect to SQL Database using Entra ID authentication
- Publish/subscribe to Service Bus topic
- Access storage account with managed identity
- Send telemetry to Application Insights

## Breaking Changes

### For Developers

1. **SQL Authentication**: Now uses Entra ID only, no SQL passwords
   - Update connection strings to use `Authentication=Active Directory Default`
   - Ensure managed identity has database permissions

2. **Service Bus**: Changed from queue to topic/subscription model
   - Update code to use topics instead of queues
   - Subscription name: `OrderProcessingSubscription`

3. **Secret Keys**: Some secret keys have changed
   - `Azure:ClientId` → `Azure:ClientId`
   - Added `Azure:ManagedIdentity:Name`
   - Added `Azure:SqlServer:Fqdn`

### For Operations

1. **Environment Variables**: New required variables from Bicep
   - `ORDERSDATABASE_SQLSERVERFQDN`
   - `AZURE_CONTAINER_REGISTRY_NAME`
   - `AZURE_CONTAINER_APPS_ENVIRONMENT_NAME`
   - `AZURE_CONTAINER_APPS_ENVIRONMENT_ID`
   - `AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN`
   - `AZURE_LOG_ANALYTICS_WORKSPACE_NAME`
   - `MANAGED_IDENTITY_NAME`

2. **SQL Server Setup**: Ensure Entra ID admin is configured
   - Bicep automatically sets managed identity as admin
   - Verify with: `az sql server ad-admin list`

3. **Service Bus**: Topic requires subscription for message processing
   - Automatically created by Bicep
   - Verify with: `az servicebus topic subscription list`

## Migration Path

For existing deployments:

1. **Backup current secrets**:
   ```powershell
   dotnet user-secrets list --project .\app.AppHost\app.AppHost.csproj > backup-apphost.txt
   dotnet user-secrets list --project .\src\eShop.Orders.API\eShop.Orders.API.csproj > backup-api.txt
   ```

2. **Deploy updated infrastructure**:
   ```powershell
   azd provision
   ```

3. **Run postprovision** (automatic or manual):
   ```powershell
   .\hooks\postprovision.ps1 -Verbose
   ```

4. **Verify new secrets**:
   ```powershell
   dotnet user-secrets list --project .\app.AppHost\app.AppHost.csproj
   # Should show 21 secrets including new SQL Server config
   ```

5. **Update application code** if needed:
   - SQL connection strings
   - Service Bus topic references
   - Managed identity usage

## Files Changed

| File | Lines Changed | Description |
|------|---------------|-------------|
| `hooks/postprovision.ps1` | ~50 lines | Added SQL, Container Registry, Container Apps, monitoring variables and secrets |
| `hooks/postprovision.sh` | ~50 lines | Same changes as PowerShell version for Bash |
| `hooks/postprovision.md` | ~200 lines | Complete rewrite to reflect current infrastructure |
| `hooks/REFACTORING_SUMMARY.md` | NEW | This document |

## Validation Checklist

- [x] All Bicep outputs mapped to environment variables
- [x] PowerShell script updated with new secrets
- [x] Bash script updated with new secrets  
- [x] Documentation updated with current architecture
- [x] SQL Server configuration documented
- [x] Service Bus topic/subscription documented
- [x] Container Registry configuration documented
- [x] Container Apps configuration documented
- [x] Managed identity usage documented
- [x] Troubleshooting guide updated
- [x] Security model documented

## Next Steps

1. **Test the refactored scripts**:
   - Fresh azd deployment
   - Manual postprovision execution
   - Verify all 28 secrets are set correctly

2. **Update application code** if needed:
   - SQL connection using Entra ID
   - Service Bus topic usage
   - Managed identity authentication

3. **Update CI/CD pipelines** if they reference old environment variables

4. **Notify team** of the changes and breaking changes

5. **Update other hook scripts** if needed:
   - preprovision.ps1/.sh
   - Generate-Orders.ps1/.sh
   - check-dev-workstation.ps1/.sh

## Contact

For questions about the refactoring:
- Review this document
- Check the updated `postprovision.md`
- Review Bicep files in `infra/` folder
- Contact: Azure Logic Apps Monitoring Team

---

**Refactoring Date**: December 26, 2025  
**Version**: 2.0.0  
**Status**: ✅ Complete
