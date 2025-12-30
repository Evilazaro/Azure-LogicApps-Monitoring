# ADR-001: .NET Aspire for Service Orchestration

## Status

**Accepted** - December 2025

## Context

The Azure Logic Apps Monitoring Solution requires orchestration of multiple services (Web App, Orders API, Logic Apps) with dependencies on Azure resources (SQL Database, Service Bus, Application Insights). Key challenges include:

1. **Local Development Complexity**: Developers need to run multiple services with proper configuration and dependencies
2. **Azure Resource Emulation**: Testing against real Azure resources during development is slow and costly
3. **Service Discovery**: Services need to discover and communicate with each other reliably
4. **Consistent Configuration**: Environment variables and connection strings must be consistent across services
5. **Observability Setup**: Telemetry should work seamlessly in both local and cloud environments

Traditional approaches using Docker Compose or manual startup scripts create friction and configuration drift.

## Decision

We adopt **.NET Aspire** as the service orchestration framework for both local development and Azure deployment.

### Key Capabilities Used

```csharp
// From AppHost.cs
var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api");
var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
    .WithExternalHttpEndpoints()
    .WithHttpHealthCheck("/health")
    .WithReference(ordersApi)
    .WaitFor(ordersApi);
```

### Aspire Features Leveraged

| Feature | Usage |
|---------|-------|
| `AddProject<T>()` | Register .NET services |
| `WithReference()` | Declare service dependencies |
| `WaitFor()` | Ensure startup order |
| `AddAzureServiceBus().RunAsEmulator()` | Local Service Bus emulation |
| `AddAzureSqlServer().RunAsContainer()` | Local SQL container |
| `AddAzureApplicationInsights().RunAsExisting()` | Connect to Azure AI |
| Service Discovery | Automatic endpoint resolution |

### Local Development Mode

```csharp
// SQL with local container
var sqlServer = builder.AddAzureSqlServer(DefaultSqlServerName)
    .RunAsContainer(configureContainer => {
        configureContainer.WithDataVolume();
    });

// Service Bus with emulator
var serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName)
    .RunAsEmulator();
```

### Azure Deployment Mode

```csharp
// Existing Azure SQL
var sqlServer = builder.AddAzureSqlServer(DefaultSqlServerName)
    .RunAsExisting(sqlServerParam, resourceGroupParameter);

// Existing Azure Service Bus
var serviceBusResource = builder.AddAzureServiceBus(DefaultConnectionStringName)
    .AsExisting(sbParam, resourceGroupParameter);
```

## Consequences

### Positive

1. **Unified Experience**: Single `dotnet run` command starts entire solution
2. **Built-in Dashboard**: Real-time logs, traces, and metrics at `https://localhost:18888`
3. **Automatic Service Discovery**: No hardcoded URLs; services find each other
4. **Azure Parity**: Same code paths for local emulators and Azure services
5. **Integrated Telemetry**: OpenTelemetry configured automatically
6. **Reduced Configuration**: Less environment variables to manage manually
7. **Health Monitoring**: Built-in health checks and dependency tracking

### Negative

1. **Learning Curve**: Team must learn Aspire patterns and APIs
2. **Preview Status**: Aspire is relatively new (though rapidly maturing)
3. **Docker Dependency**: Requires Docker Desktop for local emulators
4. **Memory Overhead**: Running containers locally requires resources
5. **Limited Customization**: Some advanced scenarios may need workarounds

### Neutral

1. **azd Integration**: Aspire works well with Azure Developer CLI but requires specific patterns
2. **Visual Studio Integration**: Best experience in VS 2022 17.9+; VS Code support improving

## Alternatives Considered

### Docker Compose

| Aspect | Docker Compose | .NET Aspire |
|--------|---------------|-------------|
| Service Definition | YAML files | C# code |
| .NET Integration | External | Native |
| Service Discovery | Custom DNS | Built-in |
| Telemetry | Manual setup | Automatic |
| Azure Emulators | Manual images | Built-in support |
| Debugging | Attach to container | Native VS debugging |

**Rejected**: Requires separate configuration layer; less integrated with .NET tooling.

### Manual Startup Scripts

**Rejected**: Error-prone; configuration drift; no automatic dependency management.

### Tye (Microsoft Project)

**Rejected**: Deprecated in favor of .NET Aspire.

### Dapr

| Aspect | Dapr | .NET Aspire |
|--------|------|-------------|
| Scope | Full distributed app runtime | Orchestration + dev tools |
| Sidecar | Required | Not required |
| Language | Polyglot | .NET focused |
| Complexity | Higher | Lower for .NET |

**Rejected**: Overkill for this solution's scope; adds operational complexity.

## References

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [AppHost.cs](../../../app.AppHost/AppHost.cs) - Implementation
- [app.ServiceDefaults/](../../../app.ServiceDefaults/) - Shared configuration
- [Application Architecture](../03-application-architecture.md) - Service details
