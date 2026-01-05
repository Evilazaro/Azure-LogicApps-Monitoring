# Azure Logic Apps Monitoring - Documentation

[![Azure](https://img.shields.io/badge/Azure-Logic%20Apps-0078D4.svg)](https://azure.microsoft.com/services/logic-apps/)
[![.NET](https://img.shields.io/badge/.NET-10.0+-512BD4.svg)](https://dotnet.microsoft.com/)
[![Aspire](https://img.shields.io/badge/.NET%20Aspire-9.x-512BD4.svg)](https://learn.microsoft.com/dotnet/aspire/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)

---

## 📋 Overview

This documentation provides comprehensive technical guidance for the **Azure Logic Apps Monitoring Solution** - a cloud-native reference implementation demonstrating enterprise-grade observability patterns for Azure Logic Apps Standard workflows.

The documentation is organized into two main sections:

| Section | Purpose | Primary Audience |
|---------|---------|------------------|
| **[Architecture](architecture/README.md)** | TOGAF BDAT architecture documentation with design decisions | Architects, Technical Leads, Platform Engineers |
| **[Hooks](hooks/README.md)** | Developer workflow automation and azd lifecycle scripts | Developers, DevOps Engineers, SREs |

---

## 📚 Documentation Structure

```
docs/
│
├── 📁 architecture/                    # Architecture Documentation (TOGAF BDAT)
│   ├── README.md                       # Architecture overview & high-level diagrams
│   ├── 01-business-architecture.md     # Business capabilities & value streams
│   ├── 02-data-architecture.md         # Data domains, stores & telemetry mapping
│   ├── 03-application-architecture.md  # Service catalog, APIs & communication patterns
│   ├── 04-technology-architecture.md   # Azure infrastructure topology & Bicep modules
│   ├── 05-observability-architecture.md # Distributed tracing, metrics & alerting
│   ├── 06-security-architecture.md     # Managed identity, RBAC & data protection
│   ├── 07-deployment-architecture.md   # CI/CD pipelines & environment strategy
│   │
│   └── 📁 adr/                         # Architecture Decision Records
│       ├── README.md                   # ADR index & process
│       ├── ADR-001-aspire-orchestration.md
│       ├── ADR-002-service-bus-messaging.md
│       └── ADR-003-observability-strategy.md
│
└── 📁 hooks/                           # Developer Automation Documentation
    ├── README.md                       # Developer inner loop workflow guide
    ├── preprovision.md                 # Pre-deployment validation script
    ├── postprovision.md                # Post-deployment configuration script
    ├── check-dev-workstation.md        # Environment validation script
    ├── sql-managed-identity-config.md  # SQL managed identity setup
    ├── clean-secrets.md                # Secret cleanup utility
    ├── Generate-Orders.md              # Test data generation script
    └── VALIDATION-WORKFLOW.md          # Validation workflow guide
```

---

## 🏗️ Architecture Documentation

The architecture documentation follows the **TOGAF Architecture Development Method (ADM)** with Business, Data, Application, and Technology (BDAT) layers.

### Document Index

| Document | Description | Key Topics |
|----------|-------------|------------|
| [**Architecture Overview**](architecture/README.md) | Executive summary and high-level architecture | Solution overview, service inventory, navigation guide |
| [**Business Architecture**](architecture/01-business-architecture.md) | Business context and capabilities | Value streams, stakeholder analysis, capability mapping |
| [**Data Architecture**](architecture/02-data-architecture.md) | Data domains and flows | Entity models, telemetry mapping, data ownership |
| [**Application Architecture**](architecture/03-application-architecture.md) | Service design and APIs | Component diagrams, communication patterns, API specifications |
| [**Technology Architecture**](architecture/04-technology-architecture.md) | Azure infrastructure | Resource topology, Bicep modules, networking |
| [**Observability Architecture**](architecture/05-observability-architecture.md) | Monitoring and tracing | OpenTelemetry, Application Insights, alerting |
| [**Security Architecture**](architecture/06-security-architecture.md) | Identity and access | Managed Identity, RBAC, Zero Trust patterns |
| [**Deployment Architecture**](architecture/07-deployment-architecture.md) | CI/CD and deployment | Azure Developer CLI, pipelines, environment strategy |

### Architecture Decision Records (ADRs)

| ADR | Decision | Status |
|-----|----------|--------|
| [ADR-001](architecture/adr/ADR-001-aspire-orchestration.md) | .NET Aspire for local service orchestration | ✅ Accepted |
| [ADR-002](architecture/adr/ADR-002-service-bus-messaging.md) | Azure Service Bus for event-driven messaging | ✅ Accepted |
| [ADR-003](architecture/adr/ADR-003-observability-strategy.md) | OpenTelemetry + Azure Monitor for observability | ✅ Accepted |

---

## 🔧 Developer Hooks Documentation

The hooks documentation covers Azure Developer CLI (azd) lifecycle scripts that automate environment setup, provisioning, and configuration.

### Script Index

| Script | Documentation | Purpose |
|--------|---------------|---------|
| `preprovision.ps1/sh` | [preprovision.md](hooks/preprovision.md) | Pre-deployment validation and environment preparation |
| `postprovision.ps1/sh` | [postprovision.md](hooks/postprovision.md) | Post-deployment secret configuration |
| `check-dev-workstation.ps1/sh` | [check-dev-workstation.md](hooks/check-dev-workstation.md) | Workstation prerequisite validation |
| `sql-managed-identity-config.ps1/sh` | [sql-managed-identity-config.md](hooks/sql-managed-identity-config.md) | SQL Database managed identity setup |
| `clean-secrets.ps1/sh` | [clean-secrets.md](hooks/clean-secrets.md) | .NET user secrets cleanup |
| `Generate-Orders.ps1/sh` | [Generate-Orders.md](hooks/Generate-Orders.md) | Test order data generation |

### Developer Workflows

The [hooks README](hooks/README.md) provides comprehensive guidance for:

- **Local Development Workflow** - Using .NET Aspire with containerized dependencies
- **Azure Deployment Workflow** - Using `azd provision` and `azd deploy`
- **Hybrid Development Mode** - Local apps with Azure backend services
- **CI/CD Pipeline Integration** - GitHub Actions and Azure DevOps patterns

---

## 🎯 Reading Paths by Role

| Role | Recommended Reading Path |
|------|-------------------------|
| **Solution Architect** | [Architecture Overview](architecture/README.md) → [Business](architecture/01-business-architecture.md) → [Technology](architecture/04-technology-architecture.md) → [ADRs](architecture/adr/README.md) |
| **Platform Engineer** | [Architecture Overview](architecture/README.md) → [Technology](architecture/04-technology-architecture.md) → [Deployment](architecture/07-deployment-architecture.md) → [Hooks](hooks/README.md) |
| **Application Developer** | [Hooks README](hooks/README.md) → [Application](architecture/03-application-architecture.md) → [Data](architecture/02-data-architecture.md) → [Observability](architecture/05-observability-architecture.md) |
| **DevOps Engineer** | [Hooks README](hooks/README.md) → [Deployment](architecture/07-deployment-architecture.md) → [Security](architecture/06-security-architecture.md) |
| **SRE/Operations** | [Observability](architecture/05-observability-architecture.md) → [Deployment](architecture/07-deployment-architecture.md) → [Technology](architecture/04-technology-architecture.md) |

---

## 🚀 Quick Start

### Prerequisites

| Tool | Version | Installation |
|------|---------|--------------|
| .NET SDK | 10.0+ | `winget install Microsoft.DotNet.SDK.10` |
| Docker Desktop | Latest | [docker.com](https://docker.com/products/docker-desktop) |
| Azure CLI | 2.60.0+ | `winget install Microsoft.AzureCLI` |
| Azure Developer CLI | Latest | `winget install Microsoft.Azd` |

### Local Development

```powershell
# 1. Clone the repository
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git

# 2. Start Docker Desktop
# Ensure Docker is running for Aspire emulators

# 3. Run with .NET Aspire
cd Azure-LogicApps-Monitoring
dotnet run --project app.AppHost
```

### Azure Deployment

```powershell
# 1. Authenticate
azd auth login

# 2. Initialize environment
azd init

# 3. Provision and deploy
azd up
```

For detailed instructions, see the [Developer Inner Loop Workflow](hooks/README.md).

---

## 🔗 Related Resources

### Repository Links

- [Repository Root](../README.md) - Main README with project overview
- [Source Code](../src/) - Application source code
- [Infrastructure](../infra/) - Bicep templates
- [Workflows](../workflows/) - Logic Apps workflow definitions

### External Documentation

- [Azure Logic Apps Documentation](https://learn.microsoft.com/azure/logic-apps/)
- [.NET Aspire Documentation](https://learn.microsoft.com/dotnet/aspire/)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [OpenTelemetry .NET Documentation](https://opentelemetry.io/docs/languages/net/)

---

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**

