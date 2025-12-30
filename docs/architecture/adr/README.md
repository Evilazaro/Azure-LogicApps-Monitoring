# Architecture Decision Records

This directory contains the Architecture Decision Records (ADRs) for the Azure Logic Apps Monitoring Solution.

## What is an ADR?

An Architecture Decision Record captures a significant architectural decision made along with its context and consequences. ADRs help teams:

- **Document rationale** behind technical decisions
- **Communicate** decisions to stakeholders
- **Onboard** new team members quickly
- **Review** past decisions when requirements change

## Decision Log

| ID | Title | Status | Date | Summary |
|----|-------|--------|------|---------|
| [ADR-001](ADR-001-aspire-orchestration.md) | .NET Aspire for Local Orchestration | **Accepted** | 2025-01 | Use .NET Aspire 9.x for local development orchestration and service discovery |
| [ADR-002](ADR-002-service-bus-messaging.md) | Azure Service Bus for Async Messaging | **Accepted** | 2025-01 | Use Azure Service Bus Topics/Subscriptions for event-driven order processing |
| [ADR-003](ADR-003-observability-strategy.md) | OpenTelemetry + Application Insights | **Accepted** | 2025-01 | Adopt OpenTelemetry for vendor-neutral telemetry with Application Insights backend |

## ADR Status Values

| Status | Meaning |
|--------|---------|
| **Proposed** | Under discussion, not yet decided |
| **Accepted** | Decision made, implementation in progress or complete |
| **Deprecated** | Decision superseded by a newer ADR |
| **Superseded** | Replaced by another ADR (reference the new ADR) |

## ADR Template

When creating new ADRs, use the following template:

```markdown
# ADR-XXX: [Title]

## Status
[Proposed | Accepted | Deprecated | Superseded by ADR-XXX]

## Context
[Describe the issue that motivated this decision or change]

## Decision
[Describe the change/decision that was made]

## Consequences
### Positive
- [Benefit 1]
- [Benefit 2]

### Negative
- [Tradeoff 1]
- [Tradeoff 2]

## Alternatives Considered
1. **Alternative 1:** [Description and why rejected]
2. **Alternative 2:** [Description and why rejected]

## References
- [Link to relevant documentation]
- [Link to related ADRs]
```

---

← [Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)
