# ADR-001: Use .NET Aspire for Service Orchestration

← [ADR Index](README.md) | **ADR-001** | [ADR-002 →](ADR-002-service-bus-messaging.md)

---

## Status

✅ **Accepted**

## Date

2025-01

## Context

The Azure Logic Apps Monitoring Solution requires orchestration of multiple services:

- Orders API (REST backend)
- Web App (frontend)
- Azure Service Bus
- Azure SQL Database
- Application Insights

Key challenges:

1. **Development/Production Parity**: Developers need local environments that mirror production topology
2. **Service Discovery**: Services need to locate each other without hardcoded endpoints
3. **Configuration Management**: Connection strings, endpoints, and settings vary by environment
4. **Observability Setup**: Distributed tracing requires consistent instrumentation across services
5. **Azure Integration**: Resources must be provisioned consistently with proper authentication

### Forces

| Force                   | Direction                             |
| ----------------------- | ------------------------------------- |
| Developer productivity  | ↗️ Simplified local development       |
| Azure-native deployment | ↗️ Seamless cloud integration         |
| Learning curve          | ↘️ Team must learn Aspire concepts    |
| Maturity concerns       | ↘️ Aspire is relatively new (GA 2024) |

## Decision

**Adopt .NET Aspire 13.1.0 as the service orchestration framework** for the Azure Logic Apps Monitoring Solution.

### Implementation Details

1. **AppHost Project** (`app.AppHost/`):
   - Central orchestration point
   - Defines service topology
   - Configures Azure resources

2. **ServiceDefaults Project** (`app.ServiceDefaults/`):
   - Shared cross-cutting concerns
   - OpenTelemetry configuration
   - Health checks
   - Resilience policies

3. **Resource Configuration Pattern**:

```csharp
// AppHost.cs
var serviceBus = builder.AddAzureServiceBus("messaging")
    .RunAsEmulator();

var sqlServer = builder.AddAzureSqlServer("sql")
    .RunAsContainer();

var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(serviceBus)
    .WithReference(sqlServer);
```

## Consequences

### Positive

| Benefit                        | Impact                                                 |
| ------------------------------ | ------------------------------------------------------ |
| **Unified Configuration**      | Single place to define service topology                |
| **Built-in Service Discovery** | Automatic endpoint injection via environment variables |
| **Local Emulators**            | Service Bus emulator, SQL container for local dev      |
| **Integrated Observability**   | Aspire Dashboard with OTLP support                     |
| **Azure-Native Deployment**    | Direct integration with azd CLI                        |
| **Resource Visualization**     | Dashboard shows service dependencies                   |

### Negative

| Tradeoff                        | Mitigation                                           |
| ------------------------------- | ---------------------------------------------------- |
| **Learning Curve**              | Team training, documentation, pair programming       |
| **Framework Coupling**          | ServiceDefaults abstracts most Aspire specifics      |
| **Version Dependencies**        | Pin versions in global.json, test upgrades in CI     |
| **Local Resource Requirements** | Docker Desktop required, documented in prerequisites |

### Neutral

- Aspire patterns align with existing .NET extension methods
- Team already familiar with dependency injection concepts
- Azure deployment still uses standard Bicep/ARM

## Alternatives Considered

### 1. Docker Compose

**Description**: Use docker-compose.yml for local orchestration

**Why Not Chosen**:

- No native .NET integration
- Separate configuration from code
- No built-in service discovery for .NET
- Different deployment model than production

### 2. Kubernetes (Minikube/Kind)

**Description**: Run Kubernetes locally for full parity

**Why Not Chosen**:

- Significant complexity overhead
- Heavy resource requirements
- Production uses Container Apps, not AKS
- Slower inner dev loop

### 3. Manual Configuration

**Description**: Configure each service independently with environment variables

**Why Not Chosen**:

- Error-prone endpoint management
- No visualization of dependencies
- Duplicated configuration across projects
- Harder to maintain consistency

## Related Decisions

- [ADR-003: Observability Strategy](ADR-003-observability-strategy.md) - Leverages Aspire's OpenTelemetry integration

## References

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [Aspire Service Discovery](https://learn.microsoft.com/dotnet/aspire/service-discovery/overview)
- [Aspire + Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/overview)

---

_← [ADR Index](README.md) | [ADR-002 →](ADR-002-service-bus-messaging.md)_
