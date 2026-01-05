# Architecture Decision Records

Architecture Decision Records (ADRs) capture the key architectural choices made during the design and evolution of the Azure Logic Apps Monitoring Solution. Each ADR documents the context, rationale, and consequences of significant technical decisions—providing a historical record that helps current and future team members understand _why_ the system is built the way it is, not just _how_ it works.

This structured approach to decision documentation follows the lightweight ADR format popularized by Michael Nygard. By maintaining ADRs alongside the codebase, we ensure architectural knowledge remains accessible, searchable, and version-controlled. Whether you're onboarding to the project, evaluating alternative approaches, or revisiting past decisions during refactoring, these records provide the context needed to make informed choices without repeating past mistakes.

## 📑 Table of Contents

- [📋 ADR Index](#adr-index)
- [🔄 ADR Process](#adr-process)
  - [✍️ When to Write an ADR](#when-to-write-an-adr)
  - [📝 ADR Template](#adr-template)
  - [🔁 ADR Lifecycle](#adr-lifecycle)

---

## ADR Index

| ADR                                          | Title                                 | Status   | Date    |
| -------------------------------------------- | ------------------------------------- | -------- | ------- |
| [ADR-001](ADR-001-aspire-orchestration.md)   | .NET Aspire for Local Orchestration   | Accepted | 2024-01 |
| [ADR-002](ADR-002-service-bus-messaging.md)  | Azure Service Bus for Event Messaging | Accepted | 2024-01 |
| [ADR-003](ADR-003-observability-strategy.md) | OpenTelemetry Observability Strategy  | Accepted | 2024-01 |

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
