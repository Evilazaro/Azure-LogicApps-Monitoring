# ADR-004: Managed Identity for Zero-Trust Authentication

## Status
**Accepted** - January 2024

## Context

The eShop Azure Platform requires secure authentication between:
- **Applications → Azure SQL Database**
- **Applications → Azure Service Bus**
- **Applications → Azure Storage**
- **Logic Apps → Azure Service Bus**
- **Logic Apps → Azure Storage**
- **Container Apps → Azure Container Registry**

Security requirements:
1. **No stored credentials** - Eliminate connection strings with embedded passwords
2. **Automatic rotation** - No manual secret management or rotation schedules
3. **Audit trail** - Track which identity accessed which resource
4. **Least privilege** - Grant minimal required permissions
5. **Compliance** - Meet enterprise security standards

## Decision

**Use Azure User-Assigned Managed Identity with RBAC for all service-to-service authentication.**

### Implementation

1. **Single User-Assigned Managed Identity**
   - Shared across all application workloads
   - Assigned to Container Apps, Logic Apps
   - RBAC roles granted for each Azure resource

2. **DefaultAzureCredential SDK Pattern**
   ```csharp
   // Extensions.cs
   builder.AddAzureServiceBusClient(connectionName, settings =>
   {
       settings.Credential = new DefaultAzureCredential();
   });
   ```

3. **SQL Database Entra ID Authentication**
   ```csharp
   // Connection string (no password)
   "Server=tcp:sql-server.database.windows.net;Database=OrderDb;Authentication=Active Directory Default;"
   ```

4. **Container Registry Pull**
   ```bicep
   // container-apps.bicep
   registries: [
     {
       server: containerRegistryLoginServer
       identity: managedIdentityId  // No admin credentials
     }
   ]
   ```

5. **Logic Apps API Connections**
   ```bicep
   // logic-app.bicep
   parameterValueSet: {
     name: 'managedIdentityAuth'
     values: {
       namespaceEndpoint: {
         value: 'sb://${serviceBusNamespace}.servicebus.windows.net/'
       }
     }
   }
   ```

### RBAC Configuration

| Resource | Role | Scope | Purpose |
|----------|------|-------|---------|
| SQL Database | `db_datareader`, `db_datawriter` | Database | Data access |
| Service Bus | `Azure Service Bus Data Sender` | Namespace | Message publishing |
| Service Bus | `Azure Service Bus Data Receiver` | Namespace | Message consumption |
| Storage Account | `Storage Blob Data Contributor` | Account | Blob read/write |
| Container Registry | `AcrPull` | Registry | Image pull |
| Application Insights | `Monitoring Metrics Publisher` | Workspace | Telemetry export |

### Authentication Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Container App  │     │  Managed        │     │  Microsoft      │
│                 │     │  Identity       │     │  Entra ID       │
│  orders-api     │     │  (UAMI)         │     │                 │
└────────┬────────┘     └────────┬────────┘     └────────┬────────┘
         │                       │                       │
         │  1. Request token     │                       │
         │  for SQL Database     │                       │
         │──────────────────────▶│                       │
         │                       │  2. Authenticate      │
         │                       │  (certificate)        │
         │                       │──────────────────────▶│
         │                       │                       │
         │                       │  3. Issue JWT         │
         │                       │  (audience: SQL)      │
         │                       │◀──────────────────────│
         │  4. Return token      │                       │
         │◀──────────────────────│                       │
         │                       │                       │
         │  5. Connect with token                        │
         │─────────────────────────────────────────────────────────▶│
         │                                               │    Azure  │
         │  6. Validate token, check RBAC               │    SQL    │
         │◀─────────────────────────────────────────────────────────│
```

## Consequences

### Positive

| Benefit | Impact |
|---------|--------|
| **No secrets to manage** | Zero credential rotation burden |
| **Automatic token refresh** | SDK handles token lifecycle |
| **Auditable access** | Entra ID logs show identity and resource |
| **Least privilege** | RBAC scoped to specific resources |
| **Compliance ready** | Meets SOC 2, ISO 27001 requirements |
| **Consistent pattern** | Same auth mechanism for all Azure services |
| **Local development** | DefaultAzureCredential falls back to Azure CLI |

### Negative

| Tradeoff | Mitigation |
|----------|------------|
| **Azure-only** | Acceptable for Azure-first architecture |
| **RBAC complexity** | Document roles, use Bicep for consistency |
| **Initial setup** | Automated in postprovision hook |
| **SQL contained user** | Required for Entra ID auth, script in hook |
| **Debugging auth issues** | Detailed error messages, Azure logs |

### Neutral

- Token caching handled by SDK (5-minute cache)
- Regional service principal in each Azure region
- Works with both User-Assigned and System-Assigned MI

## Alternatives Considered

### 1. Connection Strings with Key Vault
- **Pros:** Familiar pattern, centralized secrets
- **Cons:** Still requires secret rotation, another service dependency
- **Rejected because:** Managed Identity eliminates secrets entirely

### 2. Service Principal with Client Secret
- **Pros:** Works outside Azure, flexible
- **Cons:** Secret rotation required, credential storage needed
- **Rejected because:** Higher operational burden, security risk

### 3. Service Principal with Certificate
- **Pros:** More secure than secrets, longer validity
- **Cons:** Certificate management, renewal process
- **Rejected because:** Managed Identity provides automatic credential handling

### 4. System-Assigned Managed Identity per Service
- **Pros:** Identity lifecycle tied to resource
- **Cons:** More identities to manage, complex RBAC
- **Rejected because:** Single UAMI simplifies role assignments

### 5. Workload Identity Federation (OIDC)
- **Pros:** Works with external identity providers, Kubernetes native
- **Cons:** More complex setup, additional configuration
- **Rejected because:** Not needed for Azure-only workloads

## Implementation Checklist

### Infrastructure (Bicep)

- [x] Create User-Assigned Managed Identity
- [x] Assign UAMI to Container Apps
- [x] Assign UAMI to Logic Apps
- [x] Configure SQL Server for Entra ID admin
- [x] Grant Service Bus RBAC roles
- [x] Grant Storage RBAC roles
- [x] Configure ACR with identity-based pull

### Post-Provisioning (PowerShell)

- [x] Create SQL contained database user for UAMI
- [x] Grant db_datareader and db_datawriter roles
- [x] Configure Logic Apps API connections with MI

### Application Code

- [x] Use DefaultAzureCredential in SDK clients
- [x] Configure EF Core with Entra ID authentication
- [x] No hardcoded credentials in configuration

## References

- [Managed Identities for Azure Resources](https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/)
- [DefaultAzureCredential Class](https://learn.microsoft.com/dotnet/api/azure.identity.defaultazurecredential)
- [Azure SQL with Entra ID Authentication](https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-overview)
- [Security Architecture](../06-security-architecture.md)
- [Deployment Architecture](../07-deployment-architecture.md#deployment-hooks)

---

[← ADR-003](ADR-003-observability-strategy.md) | [ADR Index](README.md)
