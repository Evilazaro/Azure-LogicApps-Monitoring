# ADR-001: Use .NET Aspire for Local Development Orchestration

## Status

**Accepted** - January 2025

---

## Context

Developing cloud-native distributed applications locally presents significant challenges:

1. **Multiple services** need to run simultaneously (Web App, API, databases, message brokers)
2. **Configuration complexity** - each service needs connection strings, environment variables, and service discovery
3. **Dependency management** - services depend on databases, message queues, and monitoring infrastructure
4. **Environment parity** - local development should mirror cloud deployment as closely as possible
5. **Developer experience** - setting up and maintaining local environments is time-consuming

### Alternatives Considered

| Option | Pros | Cons |
|--------|------|------|
| **Docker Compose** | Widely adopted, flexible | Manual configuration, no .NET integration, separate tooling |
| **Tye** | .NET-focused, service discovery | Discontinued project, limited features |
| **Manual scripts** | Full control | High maintenance, error-prone |
| **.NET Aspire** | .NET-native, integrated observability, service discovery | Preview status, learning curve |

---

## Decision

We will use **.NET Aspire 9.x** as the local development orchestration platform.

### Key Implementation

**AppHost Project** ([app.AppHost/AppHost.cs](../../../app.AppHost/AppHost.cs)):

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Configure shared resources
ConfigureServiceBus(builder, out var serviceBus);
ConfigureSQLAzure(builder, out var orderDb);
ConfigureApplicationInsights(builder, out var appInsights);

// Build and configure the Orders API
var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(orderDb)
    .WithReference(appInsights)
    .WithEnvironment("Messaging__ServiceBusHostName", serviceBusHostName);

// Build and configure the Web App
var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
    .WithExternalHttpEndpoints()
    .WithReference(ordersApi)
    .WithReference(appInsights);

builder.Build().Run();
```

**ServiceDefaults Library** ([app.ServiceDefaults/Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)):

```csharp
public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
{
    builder.ConfigureOpenTelemetry();
    builder.AddDefaultHealthChecks();
    builder.Services.AddServiceDiscovery();
    builder.Services.ConfigureHttpClientDefaults(http =>
    {
        http.AddStandardResilienceHandler();
        http.AddServiceDiscovery();
    });
    return builder;
}
```

---

## Consequences

### Positive

1. **Unified development experience**
   - Single `dotnet run` command starts entire application
   - Automatic service discovery (`http://orders-api` just works)
   - Consistent configuration across services

2. **Built-in observability**
   - Aspire Dashboard provides traces, logs, metrics out-of-the-box
   - OpenTelemetry configured automatically
   - No additional monitoring setup for local development

3. **Cloud-native patterns enabled**
   - Service discovery works identically to Azure Container Apps
   - Connection strings managed centrally
   - Health checks standardized

4. **Resource management**
   - SQL Server containers provisioned automatically
   - Service Bus emulator configured
   - Application Insights integration ready

5. **Future-proof**
   - Official Microsoft investment
   - Active development and community
   - Integration with Azure deployment

### Negative

1. **Preview/early adoption risk**
   - APIs may change between versions
   - **Mitigation**: Pin to specific version (9.x), follow release notes

2. **Learning curve**
   - Team needs to learn Aspire patterns
   - **Mitigation**: ServiceDefaults encapsulates complexity

3. **Windows/Mac/Linux differences**
   - Some features work differently across platforms
   - **Mitigation**: Document platform-specific setup

### Neutral

1. **Additional project** - AppHost project adds to solution structure
2. **Build time** - Slightly longer initial build to start orchestration
3. **Resource consumption** - Dashboard and container management use memory

---

## Related Decisions

- [ADR-003](ADR-003-observability-strategy.md) - OpenTelemetry integration leverages Aspire's built-in support

---

## References

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [AppHost Implementation](../../../app.AppHost/AppHost.cs)
- [ServiceDefaults Implementation](../../../app.ServiceDefaults/Extensions.cs)
