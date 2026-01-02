# Architecture Decision Records

[← Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)

## Overview

Architecture Decision Records (ADRs) capture significant architectural decisions made during the design and implementation of the eShop Azure Platform solution. Each ADR documents the context, decision, and consequences of a specific architectural choice.

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](ADR-001-aspire-orchestration.md) | .NET Aspire for Service Orchestration | Accepted | 2024-01 |
| [ADR-002](ADR-002-service-bus-messaging.md) | Azure Service Bus for Asynchronous Messaging | Accepted | 2024-01 |
| [ADR-003](ADR-003-observability-strategy.md) | OpenTelemetry-Based Observability Strategy | Accepted | 2024-01 |
| [ADR-004](ADR-004-managed-identity.md) | Managed Identity for Zero-Trust Authentication | Accepted | 2024-01 |

## ADR Status Definitions

| Status | Description |
|--------|-------------|
| **Proposed** | Under discussion, not yet accepted |
| **Accepted** | Decision made and implemented |
| **Deprecated** | No longer valid, superseded by another decision |
| **Superseded** | Replaced by a newer decision (link to replacement) |

## ADR Template

When creating new ADRs, use the following template:

```markdown
# ADR-NNN: Title

## Status
Proposed | Accepted | Deprecated | Superseded by ADR-XXX

## Context
What is the issue that we're seeing that is motivating this decision?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult to do because of this change?

### Positive
- Benefit 1
- Benefit 2

### Negative
- Tradeoff 1
- Tradeoff 2

### Neutral
- Side effect 1

## Alternatives Considered
What other options were evaluated?

## References
- Links to relevant documentation
- Related ADRs
```

---

[← Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)
