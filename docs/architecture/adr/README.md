# Architecture Decision Records (ADRs)

← [Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)

---

## Overview

Architecture Decision Records capture significant architectural decisions made during the design and implementation of the Azure Logic Apps Monitoring Solution.

## ADR Format

Each ADR follows the structure:
- **Title**: Short descriptive title
- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Context**: What is the issue that we're seeing that is motivating this decision?
- **Decision**: What is the change that we're proposing and/or doing?
- **Consequences**: What becomes easier or more difficult to do because of this change?

---

## ADR Index

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| [ADR-001](ADR-001-aspire-orchestration.md) | Use .NET Aspire for Local Development Orchestration | Accepted | 2025-01 |
| [ADR-002](ADR-002-service-bus-messaging.md) | Use Azure Service Bus for Event-Driven Messaging | Accepted | 2025-01 |
| [ADR-003](ADR-003-observability-strategy.md) | Use OpenTelemetry with Application Insights | Accepted | 2025-01 |

---

## Decision Categories

### Orchestration & Development
- [ADR-001](ADR-001-aspire-orchestration.md) - .NET Aspire for local orchestration

### Integration & Messaging
- [ADR-002](ADR-002-service-bus-messaging.md) - Service Bus for messaging

### Observability
- [ADR-003](ADR-003-observability-strategy.md) - OpenTelemetry + App Insights

---

## Creating New ADRs

When creating a new ADR:

1. Use the next sequential number (e.g., ADR-004)
2. Create file: `ADR-00X-short-title.md`
3. Follow the standard template
4. Update this index
5. Link from relevant architecture documents

### Template

```markdown
# ADR-00X: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Context
[Describe the issue, problem, or opportunity]

## Decision
[Describe the decision and rationale]

## Consequences
### Positive
- [Benefit 1]
- [Benefit 2]

### Negative
- [Drawback 1]
- [Mitigation]

### Neutral
- [Observation]
```

---

← [Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)
