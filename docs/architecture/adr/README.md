# Architecture Decision Records

This folder contains Architecture Decision Records (ADRs) documenting significant architectural decisions for the eShop Orders Management solution.

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](ADR-001-aspire-orchestration.md) | .NET Aspire for Local Orchestration | Accepted | 2024-01 |
| [ADR-002](ADR-002-service-bus-messaging.md) | Azure Service Bus for Event Messaging | Accepted | 2024-01 |
| [ADR-003](ADR-003-observability-strategy.md) | OpenTelemetry Observability Strategy | Accepted | 2024-01 |

## ADR Process

### When to Write an ADR

Write an ADR when making decisions that:
- Have long-lasting impact on the system
- Are difficult or expensive to change later
- Affect multiple components or teams
- Involve trade-offs between competing concerns

### ADR Template

```markdown
# ADR-NNN: Title

## Status
[Proposed | Accepted | Deprecated | Superseded]

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult because of this change?
```

### ADR Lifecycle

1. **Proposed** - Under discussion
2. **Accepted** - Decision made and implemented
3. **Deprecated** - No longer relevant
4. **Superseded** - Replaced by another ADR

---

← [Architecture Index](../README.md)

---

<div align="center">

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**

[⬆ Back to Top](#-azure-logic-apps-monitoring-solution)

</div>
