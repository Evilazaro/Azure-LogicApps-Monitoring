# 📝 Architecture Decision Records (ADRs)

← [Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)

---

## 📑 Table of Contents

- [📊 Overview](#-overview)
- [🚦 ADR Status Legend](#-adr-status-legend)
- [📇 ADR Index](#-adr-index)
- [📝 ADR Template](#-adr-template)
- [📂 Decision Categories](#-decision-categories)
- [🔗 Related Documents](#-related-documents)

---

## 📊 Overview

This directory contains Architecture Decision Records (ADRs) documenting significant architectural choices made for the Azure Logic Apps Monitoring Solution. ADRs capture the **context**, **decision**, and **consequences** of each choice to preserve institutional knowledge.

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 🚦 ADR Status Legend

| Status            | Description                                |
| ----------------- | ------------------------------------------ |
| 🟢 **Accepted**   | Decision has been approved and implemented |
| 🟡 **Proposed**   | Decision is under consideration            |
| 🔴 **Deprecated** | Decision has been superseded               |
| ⚪ **Superseded** | Replaced by a newer ADR                    |

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 📇 ADR Index

| #                                        | Title                     | Status      | Date    | Summary                                             |
| ---------------------------------------- | ------------------------- | ----------- | ------- | --------------------------------------------------- |
| [001](ADR-001-aspire-orchestration.md)   | .NET Aspire Orchestration | 🟢 Accepted | 2024-01 | Use .NET Aspire for local development orchestration |
| [002](ADR-002-service-bus-messaging.md)  | Service Bus Messaging     | 🟢 Accepted | 2024-01 | Use Azure Service Bus for async message handling    |
| [003](ADR-003-observability-strategy.md) | Observability Strategy    | 🟢 Accepted | 2024-01 | OpenTelemetry with Azure Monitor integration        |

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 📝 ADR Template

When creating new ADRs, use the following template:

```markdown
# ADR-XXX: Title

## Status

[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Context

[Describe the situation and problem requiring a decision]

## Decision

[State the architectural decision clearly]

## Consequences

### Positive

- [Benefit 1]
- [Benefit 2]

### Negative

- [Drawback 1]
- [Drawback 2]

### Neutral

- [Observation 1]

## Alternatives Considered

### Alternative 1: [Name]

- **Pros:** [...]
- **Cons:** [...]
- **Why not chosen:** [...]

## Related ADRs

- [ADR-XXX](ADR-XXX-title.md) - Related decision
```

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 📂 Decision Categories

### 🏗️ Infrastructure Decisions

- [ADR-001](ADR-001-aspire-orchestration.md) - Orchestration approach

### 🔗 Integration Decisions

- [ADR-002](ADR-002-service-bus-messaging.md) - Messaging platform

### ⚙️ Operations Decisions

- [ADR-003](ADR-003-observability-strategy.md) - Monitoring strategy

---

<div align="right"><a href="#-table-of-contents">⬆️ Back to top</a></div>

## 🔗 Related Documents

- [Technology Architecture](../04-technology-architecture.md) - Platform choices
- [Application Architecture](../03-application-architecture.md) - Service design
- [Observability Architecture](../05-observability-architecture.md) - Monitoring design

---

_Last Updated: January 2026_
