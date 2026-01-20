---
title: Architecture Decision Records Index
description: Index of Architecture Decision Records (ADRs) documenting significant architectural decisions for the Azure Logic Apps Monitoring Solution.
author: Architecture Team
date: 2026-01-20
version: 1.0.0
tags:
  - adr
  - architecture-decisions
  - documentation
---

# 📜 Architecture Decision Records

> [!NOTE]
> **Target Audience:** Cloud Solution Architects, Technical Leads, Developers
> **Reading Time:** ~5 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                                                      |     Index     |                                         Next |
| :------------------------------------------------------------ | :-----------: | -------------------------------------------: |
| [← Deployment Architecture](../07-deployment-architecture.md) | **ADR Index** | [ADR-001 →](ADR-001-aspire-orchestration.md) |

</details>

---

## 📑 Table of Contents

- [ℹ️ About ADRs](#-about-adrs)
- [📊 ADR Index](#-adr-index)
- [📝 Decision Log Summary](#-decision-log-summary)
- [📝 ADR Template](#-adr-template)

---

## ℹ️ About ADRs

> [!TIP]
> Architecture Decision Records (ADRs) document significant architectural decisions made during the design and evolution of the Azure Logic Apps Monitoring Solution. Each ADR captures:
>
> - **Context**: The situation and forces that led to the decision
> - **Decision**: What was decided
> - **Consequences**: The resulting context after applying the decision

---

## 📊 ADR Index

| ID                                           | Title                                                  | Status      | Date    |
| -------------------------------------------- | ------------------------------------------------------ | ----------- | ------- |
| [ADR-001](ADR-001-aspire-orchestration.md)   | Use .NET Aspire for Service Orchestration              | ✅ Accepted | 2025-01 |
| [ADR-002](ADR-002-service-bus-messaging.md)  | Use Azure Service Bus for Async Messaging              | ✅ Accepted | 2025-01 |
| [ADR-003](ADR-003-observability-strategy.md) | OpenTelemetry + Application Insights for Observability | ✅ Accepted | 2025-01 |

---

## 📝 Decision Log Summary

### ADR-001: .NET Aspire for Service Orchestration

**Problem**: Need consistent service orchestration across local development and cloud deployment.

**Decision**: Adopt .NET Aspire 13.1.0 as the service orchestration framework.

**Key Benefits**:

- Unified local/cloud configuration
- Built-in service discovery
- Integrated observability

[Read full ADR →](ADR-001-aspire-orchestration.md)

---

### ADR-002: Azure Service Bus for Async Messaging

**Problem**: Need reliable, scalable async communication between API and Logic Apps.

**Decision**: Use Azure Service Bus Standard tier with topic/subscription pattern.

**Key Benefits**:

- Enterprise-grade reliability
- Topic/subscription flexibility
- Native Azure integration

[Read full ADR →](ADR-002-service-bus-messaging.md)

---

### ADR-003: OpenTelemetry + Application Insights

**Problem**: Need comprehensive observability with vendor flexibility.

**Decision**: Use OpenTelemetry SDK with Azure Monitor exporter.

**Key Benefits**:

- Vendor-neutral instrumentation
- Automatic correlation
- Azure-native analysis tools

[Read full ADR →](ADR-003-observability-strategy.md)

---

## 📝 ADR Template

When creating new ADRs, use this template:

```markdown
# ADR-XXX: [Title]

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Date

YYYY-MM

## Context

[Describe the situation, forces, and constraints]

## Decision

[State the decision clearly]

## Consequences

### Positive

- [Benefit 1]
- [Benefit 2]

### Negative

- [Tradeoff 1]
- [Tradeoff 2]

### Neutral

- [Observation 1]

## Alternatives Considered

1. [Alternative 1]: [Why not chosen]
2. [Alternative 2]: [Why not chosen]

## References

- [Link to relevant documentation]
```

---

<div align="center">

[← Deployment Architecture](../07-deployment-architecture.md) | **ADR Index** | [ADR-001 →](ADR-001-aspire-orchestration.md)

</div>
