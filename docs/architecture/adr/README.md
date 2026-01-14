# Architecture Decision Records

[← Deployment Architecture](../07-deployment-architecture.md) | [Index](../README.md)

## Overview

This directory contains Architecture Decision Records (ADRs) documenting significant architectural decisions made for the Azure Logic Apps Monitoring Solution.

## ADR Template

Each ADR follows this structure:

- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Context**: The circumstances that led to this decision
- **Decision**: The architectural choice made
- **Consequences**: The impact of this decision

## Decision Log

| ADR                                          | Title                                   | Status   | Date    |
| -------------------------------------------- | --------------------------------------- | -------- | ------- |
| [ADR-001](ADR-001-aspire-orchestration.md)   | .NET Aspire for Service Orchestration   | Accepted | 2026-01 |
| [ADR-002](ADR-002-service-bus-messaging.md)  | Azure Service Bus for Async Messaging   | Accepted | 2026-01 |
| [ADR-003](ADR-003-observability-strategy.md) | OpenTelemetry with Application Insights | Accepted | 2026-01 |

## Decision Categories

### Infrastructure Decisions

- [ADR-001](ADR-001-aspire-orchestration.md) - .NET Aspire for local development orchestration

### Integration Decisions

- [ADR-002](ADR-002-service-bus-messaging.md) - Asynchronous messaging patterns

### Observability Decisions

- [ADR-003](ADR-003-observability-strategy.md) - Telemetry and monitoring strategy

---

## Creating New ADRs

When creating a new ADR:

1. Copy the template structure
2. Use sequential numbering: `ADR-NNN-short-title.md`
3. Document the context, decision, and consequences
4. Update this index table
5. Link to relevant architecture documents

---

_Last Updated: January 2026_
