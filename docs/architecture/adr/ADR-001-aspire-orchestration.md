# 📝 ADR-001: .NET Aspire for Local Development Orchestration

← [ADR Index](README.md) | [ADR-002 →](ADR-002-service-bus-messaging.md)

---

## 📑 Table of Contents

- [🚦 Status](#-status)
- [📝 Context](#-context)
- [✅ Decision](#-decision)
- [📊 Consequences](#-consequences)
- [🔄 Alternatives Considered](#-alternatives-considered)
- [✅ Validation](#-validation)
- [🔗 Related ADRs](#-related-adrs)
- [📚 References](#-references)

---

## 🚦 Status

🟢 **Accepted** — January 2024

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 📝 Context

The Azure Logic Apps Monitoring Solution is a distributed system with multiple components:

- **eShop.Orders.API** — REST API for order management
- **eShop.Web.App** — Blazor Server frontend
- **Azure Service Bus** — Message broker
- **Azure SQL Database** — Order persistence
- **Azure Logic Apps** — Workflow orchestration
- **Application Insights** — Telemetry collection

**Challenges:**

1. Developers need to run 3+ services locally with proper configuration
2. Connection strings and dependencies vary between local/Azure environments
3. Service discovery is complex when ports change between runs
4. Starting services in the correct order requires manual coordination
5. Environment parity between dev and production is difficult to achieve

**Question:** How should we orchestrate local development to maximize developer productivity while maintaining environment parity with Azure?

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## ✅ Decision

**We will use .NET Aspire as the local development orchestration platform.**

### 🛠️ Implementation

The AppHost project (`app.AppHost/AppHost.cs`) defines the distributed application:

```csharp
var builder = DistributedApplication.CreateBuilder(args);

// Azure Service Bus (emulator for local, Azure for production)
var serviceBus = isEmulated
    ? builder.AddAzureServiceBus("messaging").RunAsEmulator()
    : builder.AddConnectionString("messaging");

// SQL Database (container for local, Azure for production)
var sqlServer = isLocalDB
    ? builder.AddSqlServer("sql").AddDatabase("orders")
    : builder.AddConnectionString("orders");

// Application services with dependencies
var ordersApi = builder.AddProject<Projects.eShop_Orders_API>("orders-api")
    .WithReference(sqlServer)
    .WithReference(serviceBus)
    .WithReference(insights);

var webApp = builder.AddProject<Projects.eShop_Web_App>("web-app")
    .WithReference(ordersApi)
    .WithReference(insights);
```

### 🎯 Key Decisions

| Aspect            | Decision            | Rationale                                           |
| ----------------- | ------------------- | --------------------------------------------------- |
| **Framework**     | .NET Aspire 9.1.0   | Native .NET integration, production-ready           |
| **Service Bus**   | Emulator for local  | No Azure costs during development                   |
| **SQL Server**    | Container for local | Consistent schema management                        |
| **Configuration** | Environment-based   | `ASPIRE_ALLOW_UNSECURED_TRANSPORT` toggles behavior |

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 📊 Consequences

### ✅ Positive

| Benefit                  | Impact                                                 |
| ------------------------ | ------------------------------------------------------ |
| **One-click startup**    | `F5` starts all services with correct dependencies     |
| **Service discovery**    | Automatic endpoint injection via `WithReference()`     |
| **Environment parity**   | Same code paths for local emulators and Azure services |
| **Observability**        | Built-in dashboard shows logs, traces, metrics         |
| **Container management** | Aspire handles SQL and Service Bus containers          |

### ⚠️ Negative

| Drawback                 | Mitigation                |
| ------------------------ | ------------------------- | ----------------------------------- |
| **Learning curve**       | Aspire concepts are new   | Documentation and examples provided |
| **Resource consumption** | Containers require memory | Minimum 16GB RAM recommended        |
| **Version dependency**   | .NET 9+ required          | Project already targets .NET 10     |

### ⚖️ Neutral

- Aspire is a development tool; production uses standard Azure services
- The AppHost project is excluded from production deployment
- Container emulators approximate but don't perfectly match Azure behavior

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 🔄 Alternatives Considered

### 🐳 Alternative 1: Docker Compose

```yaml
# docker-compose.yml
services:
  orders-api:
    build: ./src/eShop.Orders.API
    depends_on:
      - sql
      - servicebus
  sql:
    image: mcr.microsoft.com/mssql/server:2022
  servicebus:
    image: mcr.microsoft.com/azure-messaging/servicebus-emulator
```

| Criteria           | Assessment                                       |
| ------------------ | ------------------------------------------------ |
| **Pros**           | Industry standard, language-agnostic             |
| **Cons**           | No native .NET integration, manual configuration |
| **Why not chosen** | Aspire provides better DX for .NET developers    |

### ❌ Alternative 2: Tye (Project Tye)

| Criteria           | Assessment                                    |
| ------------------ | --------------------------------------------- |
| **Pros**           | Lightweight, familiar YAML syntax             |
| **Cons**           | Deprecated, no longer maintained by Microsoft |
| **Why not chosen** | Aspire is the official successor to Tye       |

### 📜 Alternative 3: Manual Scripts

```powershell
# start-all.ps1
Start-Process dotnet "run --project src/eShop.Orders.API"
Start-Process dotnet "run --project src/eShop.Web.App"
```

| Criteria           | Assessment                                   |
| ------------------ | -------------------------------------------- |
| **Pros**           | Simple, no additional tooling                |
| **Cons**           | No service discovery, manual port management |
| **Why not chosen** | Does not scale with service count            |

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## ✅ Validation

The decision is validated by:

1. **Developer feedback** — Single-click startup improves onboarding
2. **CI/CD parity** — Same Aspire configuration runs in GitHub Actions
3. **Emulator accuracy** — Service Bus and SQL emulators provide realistic testing

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 🔗 Related ADRs

- [ADR-002](ADR-002-service-bus-messaging.md) — Service Bus is orchestrated by Aspire
- [ADR-003](ADR-003-observability-strategy.md) — Aspire dashboard provides local observability

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 📚 References

- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [app.AppHost/AppHost.cs](../../../app.AppHost/AppHost.cs)
- [app.ServiceDefaults/Extensions.cs](../../../app.ServiceDefaults/Extensions.cs)

---

_Last Updated: January 2026_
