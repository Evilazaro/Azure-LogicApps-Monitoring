# Architecture Decision Records

[← Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)

---

## 📑 Table of Contents

- [📋 About ADRs](#-about-adrs)
- [📊 Decision Log](#-decision-log)
- [📋 Summary](#-summary)
- [⏳ Pending Decisions](#-pending-decisions)

---

## 📋 About ADRs

Architecture Decision Records (ADRs) document significant architectural decisions made during the design and development of the eShop Orders system. Each ADR captures the context, decision, consequences, and rationale for a specific architectural choice.

### ADR Template

Each ADR follows this structure:

1. **Title** - Short description of the decision
2. **Status** - Proposed, Accepted, Deprecated, Superseded
3. **Context** - The situation that motivated the decision
4. **Decision** - The change or approach we're proposing
5. **Consequences** - The resulting context after applying the decision
6. **Alternatives Considered** - Other options evaluated

---

## 📊 Decision Log

| ADR                                          | Title                                 | Status   | Date    |
| -------------------------------------------- | ------------------------------------- | -------- | ------- |
| [ADR-001](ADR-001-aspire-orchestration.md)   | .NET Aspire for Service Orchestration | Accepted | 2025-01 |
| [ADR-002](ADR-002-service-bus-messaging.md)  | Azure Service Bus for Async Messaging | Accepted | 2025-01 |
| [ADR-003](ADR-003-observability-strategy.md) | OpenTelemetry with Azure Monitor      | Accepted | 2025-01 |

---

## 📋 Summary

### ADR-001: .NET Aspire for Service Orchestration

**Decision**: Use .NET Aspire 13.1.0 as the distributed application orchestration framework.

**Key Drivers**:

- Native .NET integration
- Built-in service discovery
- Unified local development experience
- Azure Container Apps compatibility

---

### ADR-002: Azure Service Bus for Async Messaging

**Decision**: Use Azure Service Bus topics for asynchronous order event messaging.

**Key Drivers**:

- Decoupling order creation from processing
- Reliable message delivery
- Support for multiple subscribers
- Integration with Logic Apps

---

### ADR-003: OpenTelemetry with Azure Monitor

**Decision**: Implement OpenTelemetry instrumentation with Azure Monitor export.

**Key Drivers**:

- Vendor-neutral observability standard
- Distributed tracing across services
- Custom metrics support
- Correlation with Azure services

---

## ⏳ Pending Decisions

| Topic          | Status      | Notes                         |
| -------------- | ----------- | ----------------------------- |
| API Gateway    | Proposed    | Consider Azure API Management |
| Multi-Region   | Not Started | DR strategy needed            |
| Event Sourcing | Deferred    | May revisit for order history |

---

[← Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)
