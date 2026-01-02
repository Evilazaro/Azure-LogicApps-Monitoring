# ADR-004: Use Managed Identity for Passwordless Authentication

## Status

**Accepted** - January 2025

---

## Context

Modern cloud applications require secure authentication to backend services (databases, message brokers, storage). Traditional approaches use connection strings with embedded credentials, which creates several security challenges:

1. **Secret management overhead** - Credentials must be securely stored, rotated, and distributed
2. **Security risk** - Secrets in configuration files or environment variables can be leaked
3. **Compliance burden** - Audit requirements for credential access and rotation
4. **Operational complexity** - Different credentials per environment increase management burden
5. **Developer friction** - Local development often uses different auth patterns than production

### Services Requiring Authentication

| Service | Traditional Method | Security Concern |
|---------|-------------------|------------------|
| Azure SQL Database | Connection string with password | Password exposure |
| Azure Service Bus | SAS key or connection string | Key rotation complexity |
| Azure Storage | Access key or SAS token | Overly permissive access |
| Application Insights | Instrumentation key | Write-access exposure |

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Connection strings with passwords** | Simple, familiar | Secrets in config, rotation burden |
| **Azure Key Vault references** | Centralized secrets | Still requires secret management |
| **Service Principal** | Explicit identity | Certificate/secret rotation needed |
| **Managed Identity** | No secrets, auto-rotation | Azure-only, requires RBAC setup |

---

## Decision

We will use **User-Assigned Managed Identity** as the primary authentication mechanism for all Azure services, implementing a **passwordless architecture**.

### Key Implementation

**Infrastructure Definition** ([infra/shared/identity/main.bicep](../../../infra/shared/identity/main.bicep)):

```bicep
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: name
  location: location
  tags: tags
}
```

**Application Configuration** ([app.AppHost/AppHost.cs](../../../app.AppHost/AppHost.cs)):

```csharp
private static void ConfigureAzureCredentials(
    IDistributedApplicationBuilder builder,
    out string tenantId,
    out string clientId)
{
    tenantId = builder.Configuration.GetValue<string>("Azure:TenantId") ?? "";
    clientId = builder.Configuration.GetValue<string>("Azure:ClientId") ?? "";
}

// SQL connection with Managed Identity
private static void ConfigureSQLAzure(
    IDistributedApplicationBuilder builder, 
    out IResourceBuilder<AzureSqlDatabaseResource> orderDb)
{
    var connectionString = builder.Configuration.GetConnectionString("orders-database-conn");
    // Connection string includes: Authentication=Active Directory Managed Identity
    orderDb = builder.AddAzureSqlServer("orders-sql-server")
        .WithConnectionString(connectionString)
        .AddDatabase("orders-db");
}
```

**Service Bus Client** ([app.ServiceDefaults/Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)):

```csharp
public static IHostApplicationBuilder AddAzureServiceBusClient(
    this IHostApplicationBuilder builder)
{
    var serviceBusHostName = builder.Configuration
        .GetValue<string>("Messaging:ServiceBusHostName");
    
    if (!string.IsNullOrEmpty(serviceBusHostName))
    {
        builder.Services.AddSingleton(sp =>
        {
            // Uses DefaultAzureCredential which automatically uses Managed Identity
            return new ServiceBusClient(
                serviceBusHostName, 
                new DefaultAzureCredential());
        });
    }
    return builder;
}
```

**SQL Server Entra ID Configuration** ([hooks/sql-managed-identity-config.ps1](../../../hooks/sql-managed-identity-config.ps1)):

```powershell
# Configure SQL Server to use Entra ID authentication
Set-AzSqlServerActiveDirectoryAdministrator `
    -ResourceGroupName $resourceGroup `
    -ServerName $serverName `
    -DisplayName $managedIdentityName `
    -ObjectId $managedIdentityObjectId

# Create contained database user for the managed identity
$createUserQuery = @"
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = '$managedIdentityName')
BEGIN
    CREATE USER [$managedIdentityName] FROM EXTERNAL PROVIDER;
END
ALTER ROLE db_datareader ADD MEMBER [$managedIdentityName];
ALTER ROLE db_datawriter ADD MEMBER [$managedIdentityName];
"@
```

---

## Role-Based Access Control (RBAC)

Each service receives only the permissions it needs:

| Identity | Resource | Role | Purpose |
|----------|----------|------|---------|
| User-Assigned MI | SQL Database | `db_datareader`, `db_datawriter` | CRUD operations |
| User-Assigned MI | Service Bus | `Azure Service Bus Data Sender` | Publish messages |
| User-Assigned MI | Service Bus | `Azure Service Bus Data Receiver` | Consume messages |
| System MI (Logic App) | Storage Account | `Storage Blob Data Contributor` | Workflow state |

---

## Consequences

### Positive

1. **Eliminated secrets management**
   - No passwords or keys in configuration
   - No secrets to rotate or protect
   - Simplified deployment process

2. **Enhanced security posture**
   - No credential leakage risk
   - Automatic token rotation by Azure
   - Reduced attack surface

3. **Simplified compliance**
   - No credential storage requirements
   - Built-in audit trail via Entra ID
   - Follows zero-trust principles

4. **Consistent authentication**
   - Same pattern for all Azure services
   - Works across all environments (dev/staging/prod)
   - Simplified troubleshooting

5. **Better local development experience**
   - `DefaultAzureCredential` uses Azure CLI credentials locally
   - No separate credential setup for developers
   - Automatic fallback chain for authentication

### Negative

1. **Azure-only pattern**
   - Managed Identity is Azure-specific
   - **Mitigation:** Application code uses `DefaultAzureCredential` which supports multiple credential types

2. **RBAC configuration complexity**
   - Must define and maintain role assignments
   - **Mitigation:** Automated via Bicep and post-provision hooks

3. **Initial setup overhead**
   - SQL requires Entra ID admin configuration
   - **Mitigation:** Automated in `sql-managed-identity-config.ps1`

### Neutral

1. **Development modes differ slightly**
   - Local uses Azure CLI credentials
   - Azure uses Managed Identity
   - Both handled transparently by `DefaultAzureCredential`

---

## Implementation Checklist

- [x] Create User-Assigned Managed Identity in shared infrastructure
- [x] Assign identity to Container Apps (orders-api, web-app)
- [x] Configure Service Bus RBAC (Sender, Receiver roles)
- [x] Configure SQL Server for Entra ID authentication
- [x] Create SQL contained database user for MI
- [x] Update connection strings to use MI authentication
- [x] Configure Application Insights with MI
- [x] Verify DefaultAzureCredential for local development

---

## Related Decisions

- [ADR-001: .NET Aspire Orchestration](ADR-001-aspire-orchestration.md) - Local credential configuration
- [ADR-002: Service Bus Messaging](ADR-002-service-bus-messaging.md) - Service Bus authentication
- [ADR-003: Observability Strategy](ADR-003-observability-strategy.md) - App Insights authentication

---

## References

- [Microsoft Entra Managed Identities Documentation](https://learn.microsoft.com/en-us/entra/identity/managed-identities-azure-resources/)
- [Azure SQL Entra ID Authentication](https://learn.microsoft.com/en-us/azure/azure-sql/database/authentication-aad-overview)
- [DefaultAzureCredential Class](https://learn.microsoft.com/en-us/dotnet/api/azure.identity.defaultazurecredential)
- [Security Architecture](../06-security-architecture.md)

---

← [ADR Index](README.md) | [Security Architecture](../06-security-architecture.md)
