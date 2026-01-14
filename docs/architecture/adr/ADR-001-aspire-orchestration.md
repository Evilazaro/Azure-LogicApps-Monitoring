# ADR-001: .NET Aspire for Service Orchestration

[← ADR Index](README.md)

---

## Status

**Accepted** - January 2025

---

## Context

The eShop Orders system is a cloud-native distributed application consisting of multiple services:

- Orders API (ASP.NET Core Web API)
- Web Application (Blazor Server)
- Logic Apps (Order processing workflows)
- Supporting Azure services (SQL, Service Bus, App Insights)

We need a way to:

1. **Orchestrate** multiple services with dependencies
2. **Simplify** local development configuration
3. **Enable** service discovery without hardcoded addresses
4. **Standardize** cross-cutting concerns (health checks, telemetry, resilience)
5. **Support** deployment to Azure Container Apps

### Requirements

| Requirement                  | Priority | Notes                         |
| ---------------------------- | -------- | ----------------------------- |
| Multi-service orchestration  | High     | 2+ services with dependencies |
| Local development experience | High     | F5 debugging across services  |
| Service discovery            | High     | No hardcoded URLs             |
| Azure Container Apps support | High     | Target deployment platform    |
| Health checks and telemetry  | Medium   | Standardized implementation   |
| .NET native                  | Medium   | Team expertise                |

---

## Decision

We will use **.NET Aspire 13.1.0** as our distributed application orchestration framework.

### Implementation

```csharp
// app.AppHost/AppHost.cs
var builder = DistributedApplication.CreateBuilder(args);

// Configure shared resources
var insights = builder.AddAzureApplicationInsights("appinsights");
var serviceBus = builder.AddAzureServiceBus("messaging");
var sql = builder.AddSqlServer("sql")
    .AddDatabase("ordersdb");

// Configure Orders API with dependencies
var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(insights)
    .WithReference(serviceBus)
    .WithReference(sql);

// Configure Web App with reference to API
builder.AddProject<Projects.eShop_Web_App>("web-app")
    .WithReference(ordersApi)
    .WithReference(insights);

builder.Build().Run();
```

### Service Defaults Library

```csharp
// app.ServiceDefaults/Extensions.cs
public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder)
{
    builder.ConfigureOpenTelemetry();      // Distributed tracing
    builder.AddDefaultHealthChecks();       // Liveness/readiness
    builder.Services.AddServiceDiscovery(); // HTTP client discovery
    builder.Services.ConfigureHttpClientDefaults(http =>
    {
        http.AddStandardResilienceHandler(); // Polly resilience
    });
    return builder;
}
```

---

## Consequences

### Benefits

| Benefit                   | Description                                                      |
| ------------------------- | ---------------------------------------------------------------- |
| **Unified Experience**    | Single F5 starts all services with correct configuration         |
| **Service Discovery**     | Services resolve each other by name (`http://orders-api`)        |
| **Built-in Dashboard**    | Aspire Dashboard provides real-time telemetry view               |
| **Standardized Concerns** | ServiceDefaults ensures consistent health, telemetry, resilience |
| **Azure Integration**     | Native support for Container Apps, Service Bus, SQL              |
| **Type Safety**           | Compile-time validation of service references                    |

### Drawbacks

| Drawback                  | Mitigation                         |
| ------------------------- | ---------------------------------- |
| **.NET 9+ Required**      | Team is already on .NET 10         |
| **Aspire Learning Curve** | Well-documented, familiar patterns |
| **Preview Features**      | Using stable 13.1.0 release        |
| **Azure-centric**         | Primary target is Azure anyway     |

### Risks

| Risk                       | Probability | Impact | Mitigation                             |
| -------------------------- | ----------- | ------ | -------------------------------------- |
| Breaking changes in Aspire | Low         | Medium | Pin to specific version, test upgrades |
| Tooling gaps               | Low         | Low    | Active development, community support  |
| Vendor lock-in             | Medium      | Low    | Core services remain portable .NET     |

---

## Alternatives Considered

### 1. Docker Compose

**Pros**: Widely used, platform-agnostic, mature tooling
**Cons**: No .NET integration, manual service discovery, separate config files
**Why Rejected**: Poor developer experience for .NET projects

### 2. Kubernetes (Local)

**Pros**: Production-like environment, industry standard
**Cons**: Heavy local footprint, complex setup, slow iteration
**Why Rejected**: Overkill for development, high cognitive load

### 3. Manual Configuration

**Pros**: Simple, no dependencies, full control
**Cons**: Error-prone, duplication, no service discovery
**Why Rejected**: Does not scale with service count

### 4. Dapr

**Pros**: Platform-agnostic, sidecar pattern, building blocks
**Cons**: Additional runtime, learning curve, debugging complexity
**Why Rejected**: Aspire provides simpler .NET-native alternative

### Comparison Matrix

| Criteria             | Aspire | Docker Compose | K8s    | Manual | Dapr   |
| -------------------- | ------ | -------------- | ------ | ------ | ------ |
| .NET Integration     | ⭐⭐⭐ | ⭐             | ⭐     | ⭐⭐   | ⭐⭐   |
| Service Discovery    | ⭐⭐⭐ | ⭐             | ⭐⭐⭐ | ❌     | ⭐⭐⭐ |
| Local Dev Experience | ⭐⭐⭐ | ⭐⭐           | ⭐     | ⭐⭐   | ⭐⭐   |
| Azure Container Apps | ⭐⭐⭐ | ⭐⭐           | ⭐⭐   | ⭐     | ⭐⭐   |
| Learning Curve       | ⭐⭐   | ⭐⭐⭐         | ⭐     | ⭐⭐⭐ | ⭐⭐   |

---

## References

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [AppHost.cs](../../../app.AppHost/AppHost.cs)
- [Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)

---

[← ADR Index](README.md)
