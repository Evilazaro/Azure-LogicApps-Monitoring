# ADR-001: .NET Aspire for Local Development Orchestration

## Status

**Accepted** - January 2024

## Context

The eShop Orders Management solution consists of multiple services:

- **eShop.Orders.API** - REST API with SQL and Service Bus dependencies
- **eShop.Web.App** - Blazor Server frontend
- **OrdersManagement Logic App** - Workflow automation

Developing and debugging this distributed system locally presents challenges:

1. **Service Dependencies** - Each service requires external dependencies (SQL, Service Bus, Storage)
2. **Configuration Management** - Connection strings and settings must be consistent across services
3. **Service Discovery** - Services need to locate each other during development
4. **Observability** - Distributed tracing must work locally for debugging
5. **Environment Parity** - Local environment should mirror Azure deployment

### Options Considered

| Option               | Pros                                                         | Cons                                      |
| -------------------- | ------------------------------------------------------------ | ----------------------------------------- |
| **Docker Compose**   | Industry standard, flexible                                  | Manual configuration, no .NET integration |
| **.NET Aspire**      | .NET-native, automatic configuration, built-in observability | Newer technology, .NET-specific           |
| **Tye (deprecated)** | Similar goals to Aspire                                      | Microsoft deprecated in favor of Aspire   |
| **Manual Scripts**   | Full control                                                 | High maintenance, error-prone             |

## Decision

We will use **.NET Aspire 9.x** as the local development orchestration platform.

### Implementation

**AppHost Project:** [app.AppHost/AppHost.cs](../../../app.AppHost/AppHost.cs)

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Add dependencies with automatic containerization
var sqlDatabase = builder.AddSqlServer("sql")
    .WithLifetime(ContainerLifetime.Persistent)
    .AddDatabase("orderDb");

var serviceBus = builder.AddAzureServiceBus("serviceBus")
    .RunAsEmulator();

// Add services with automatic service discovery
var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(sqlDatabase)
    .WithReference(serviceBus);

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
    .WithReference(ordersApi);
```

**ServiceDefaults:** [app.ServiceDefaults/Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)

Cross-cutting concerns (observability, health checks, resilience) are encapsulated in the shared ServiceDefaults project.

### Key Capabilities Used

| Capability                | Usage                                                |
| ------------------------- | ---------------------------------------------------- |
| **Service Discovery**     | `WithReference()` enables automatic URL resolution   |
| **Container Management**  | `RunAsEmulator()` for Service Bus emulator           |
| **Persistent Containers** | `WithLifetime(ContainerLifetime.Persistent)` for SQL |
| **Dashboard**             | Built-in observability dashboard at localhost:15888  |
| **Azure Integration**     | `RunAsExisting()` for Azure mode                     |

## Consequences

### Positive

1. **Simplified Configuration** - Connection strings automatically injected via environment variables
2. **Service Discovery** - Services reference each other by name, not hardcoded URLs
3. **Integrated Dashboard** - Real-time view of logs, traces, and metrics
4. **Azure Emulators** - Service Bus emulator runs locally without Azure subscription
5. **Smooth Transition** - Same code runs locally and in Azure with configuration switch
6. **Health Checks** - Automatic health check integration with the dashboard

### Negative

1. **Learning Curve** - Team must learn .NET Aspire concepts
2. **.NET Ecosystem Lock-in** - Only works with .NET applications
3. **Version Dependency** - Must track Aspire preview/release versions
4. **Resource Overhead** - Dashboard and containers consume local resources

### Neutral

1. **Docker Required** - Docker Desktop must be running for container dependencies
2. **IDE Integration** - Best experience with Visual Studio 2022 or VS Code with C# Dev Kit

## Alternatives Not Chosen

### Docker Compose

Docker Compose was considered but rejected because:

- Requires manual configuration of service discovery
- No automatic configuration injection
- Missing integrated observability dashboard
- More verbose configuration for .NET services

### Manual Local Setup

Running dependencies manually was rejected because:

- Inconsistent developer environments
- Time-consuming setup process
- No automatic service discovery
- Difficult to replicate across team

---

## Related Decisions

- [ADR-003: Observability Strategy](ADR-003-observability-strategy.md) - OpenTelemetry integration with Aspire

## References

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [Aspire Service Discovery](https://learn.microsoft.com/dotnet/aspire/service-discovery/overview)

---

<div align="center">

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**

[⬆ Back to Top](#adr-001-net-aspire-for-local-development-orchestration)

</div>
