# ADR-001: .NET Aspire for Service Orchestration

## Status
**Accepted** - January 2024

## Context

The eShop Azure Platform requires a solution for:
- **Local development orchestration** - Running multiple services (Web App, API, SQL, Service Bus) locally
- **Service discovery** - Services need to find and communicate with each other
- **Configuration management** - Connection strings and settings vary between local and cloud environments
- **Cloud-native patterns** - Health checks, telemetry, resilience need consistent implementation

Traditional approaches include:
- Docker Compose for local orchestration
- Manual configuration management per environment
- Custom service discovery implementations
- Individual resilience pattern implementations per service

The development team needed a unified approach that would:
1. Simplify local development setup
2. Provide consistent patterns across services
3. Reduce boilerplate code
4. Support seamless local-to-cloud transitions

## Decision

**Use .NET Aspire as the service orchestration and cloud-native application framework.**

### Implementation

1. **AppHost Project** (`app.AppHost`)
   - Orchestrates all services and dependencies
   - Configures Azure resources for local emulation and cloud deployment
   - Manages service discovery through Aspire's built-in mechanisms

2. **ServiceDefaults Project** (`app.ServiceDefaults`)
   - Provides shared OpenTelemetry configuration
   - Implements standard health checks
   - Configures resilience patterns (retry, circuit breaker, timeout)
   - Manages Azure client configurations

3. **Dual-Mode Configuration**
   - Local development uses emulators (Azurite, SQL Edge)
   - Production uses Azure services with managed identity
   - Same codebase, different runtime configuration

### Code Example

```csharp
// app.AppHost/AppHost.cs
var builder = DistributedApplication.CreateBuilder(args);

// Configure Azure resources (works locally and in cloud)
var sql = ConfigureSQLAzure(builder, "sql");
var serviceBus = ConfigureServiceBus(builder, "messaging");
var appInsights = ConfigureApplicationInsights(builder, "appInsights");

// Define services with dependencies
var api = builder.AddProject<Projects.eShop_Orders_API>("api")
    .WithReference(sql)
    .WithReference(serviceBus)
    .WithReference(appInsights);

var web = builder.AddProject<Projects.eShop_Web_App>("web")
    .WithReference(api);
```

## Consequences

### Positive

| Benefit | Impact |
|---------|--------|
| **Simplified local development** | One-command startup (`dotnet run` in AppHost) |
| **Consistent patterns** | All services share telemetry, health checks, resilience |
| **Reduced boilerplate** | Service discovery automatic, no manual config per environment |
| **Cloud-native by default** | OpenTelemetry, health probes built-in |
| **Azure integration** | Native support for Azure services and emulators |
| **Type-safe configuration** | Compile-time errors for misconfigured dependencies |

### Negative

| Tradeoff | Mitigation |
|----------|------------|
| **Learning curve** | Comprehensive documentation, consistent patterns |
| **Framework coupling** | ServiceDefaults can be extracted if needed |
| **Version dependencies** | Lock Aspire SDK version, test upgrades |
| **Limited to .NET** | Non-.NET services can use standard HTTP/messaging |

### Neutral

- Aspire dashboard provides local observability (traces, logs, metrics)
- Deployment still requires Azure Developer CLI or custom pipelines
- Container Apps deployment is the primary supported cloud target

## Alternatives Considered

### 1. Docker Compose Only
- **Pros:** Well-known, language agnostic
- **Cons:** No service discovery, manual config management, no built-in telemetry
- **Rejected because:** Requires significant additional tooling for cloud-native patterns

### 2. Kubernetes (minikube/kind) for Local Development
- **Pros:** Production parity, full orchestration
- **Cons:** Heavy resource requirements, complex setup, steep learning curve
- **Rejected because:** Overkill for local development, slower iteration

### 3. Manual Service Configuration
- **Pros:** Full control, no framework dependencies
- **Cons:** Repetitive code, inconsistent patterns, error-prone
- **Rejected because:** Does not scale with team size or service count

### 4. Dapr (Distributed Application Runtime)
- **Pros:** Language agnostic, sidecar pattern, built-in patterns
- **Cons:** Additional runtime complexity, separate learning curve
- **Rejected because:** .NET Aspire provides native .NET experience with less overhead

## References

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [.NET Aspire GitHub Repository](https://github.com/dotnet/aspire)
- [Cloud-Native .NET Applications](https://learn.microsoft.com/dotnet/architecture/cloud-native/)
- [Application Architecture](../03-application-architecture.md)
- [Technology Architecture](../04-technology-architecture.md)

---

[← ADR Index](README.md) | [Next: ADR-002 →](ADR-002-service-bus-messaging.md)
