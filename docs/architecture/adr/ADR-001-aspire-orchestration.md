# ADR-001: .NET Aspire for Service Orchestration

[← ADR Index](README.md) | [ADR-002 →](ADR-002-service-bus-messaging.md)

## Status

**Accepted** (January 2026)

## Context

The Azure Logic Apps Monitoring Solution consists of multiple services that need to work together:

- **Orders API** - REST API for order management
- **Web Application** - Blazor Server frontend
- **Azure Service Bus** - Message broker
- **Azure SQL Database** - Persistent storage
- **Azure Logic Apps** - Workflow automation
- **Application Insights** - Telemetry platform

### Challenges

1. **Local Development Complexity**: Running multiple services locally requires manual configuration of connection strings, ports, and dependencies
2. **Service Discovery**: Services need to locate each other in different environments (local vs. Azure)
3. **Configuration Management**: Managing environment-specific settings across services is error-prone
4. **Dependency Orchestration**: Services have startup order dependencies (database before API)
5. **Observability Setup**: Configuring telemetry consistently across all services requires boilerplate code

### Options Considered

| Option                 | Pros                              | Cons                                          |
| ---------------------- | --------------------------------- | --------------------------------------------- |
| **Docker Compose**     | Well-known, portable              | No .NET integration, manual service discovery |
| **Kubernetes (local)** | Production-like                   | Heavy resource usage, complex setup           |
| **Manual Scripts**     | Full control                      | High maintenance, error-prone                 |
| **.NET Aspire**        | Native .NET, opinionated defaults | Newer technology, Azure-centric               |

## Decision

**We will use .NET Aspire 13.1.0 as the distributed application orchestrator.**

### Rationale

1. **Native .NET Integration**: Aspire is built for .NET applications and provides first-class integration with the ecosystem
2. **Automatic Service Discovery**: Services reference each other by name; Aspire handles endpoint resolution
3. **Local Emulators**: Built-in support for Azure service emulators (Service Bus, SQL, Storage)
4. **Consistent Observability**: OpenTelemetry configuration is standardized across all services
5. **Azure Deployment Path**: Aspire generates deployment manifests for Azure Container Apps
6. **Developer Experience**: Single `dotnet run` command starts the entire application stack

### Implementation

```csharp
// AppHost.cs - Orchestrator definition
var builder = DistributedApplication.CreateBuilder(args);

// Infrastructure resources
var insights = builder.AddAzureApplicationInsights("insights");
var sqlServer = builder.AddSqlServer("sql").AddDatabase("OrdersDatabase");
var serviceBus = builder.AddAzureServiceBus("messaging");

// Application services
var api = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(sqlServer)
    .WithReference(serviceBus)
    .WithReference(insights);

var web = builder.AddProject<Projects.eShop_Web_App>("web")
    .WithReference(api)
    .WithReference(insights);

builder.Build().Run();
```

### Service Defaults Pattern

The solution uses a shared `ServiceDefaults` project that provides:

- OpenTelemetry configuration
- Health check endpoints
- Resilience patterns (Polly)
- Azure credential management

```csharp
// Extensions.cs - Service configuration
public static IHostApplicationBuilder AddServiceDefaults(
    this IHostApplicationBuilder builder)
{
    builder.ConfigureOpenTelemetry();
    builder.AddDefaultHealthChecks();
    builder.Services.AddServiceDiscovery();
    return builder;
}
```

## Consequences

### Positive

| Benefit                      | Impact                                 |
| ---------------------------- | -------------------------------------- |
| **Simplified local dev**     | Single command starts entire stack     |
| **Consistent configuration** | No manual connection string management |
| **Built-in observability**   | Telemetry works out of the box         |
| **Clear deployment path**    | Aspire → Azure Container Apps          |
| **Developer productivity**   | Less time on infrastructure setup      |

### Negative

| Trade-off                | Mitigation                              |
| ------------------------ | --------------------------------------- |
| **Newer technology**     | Use stable GA versions only             |
| **Azure-centric**        | Acceptable for Azure-targeted solution  |
| **Learning curve**       | Provide documentation, team training    |
| **Emulator limitations** | Fall back to Azure services when needed |

### Neutral

- Requires .NET 8+ (already using .NET 10)
- Dashboard requires browser access (acceptable for development)
- Some Azure services need emulation workarounds

## Related Decisions

- [ADR-002](ADR-002-service-bus-messaging.md) - Service Bus integration with Aspire
- [ADR-003](ADR-003-observability-strategy.md) - OpenTelemetry configuration via Aspire

## References

- [.NET Aspire Documentation](https://learn.microsoft.com/en-us/dotnet/aspire/)
- [app.AppHost/AppHost.cs](../../app.AppHost/AppHost.cs)
- [app.ServiceDefaults/Extensions.cs](../../app.ServiceDefaults/Extensions.cs)
- [Application Architecture](../03-application-architecture.md)

---

_Last Updated: January 2026_
