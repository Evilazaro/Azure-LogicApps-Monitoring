# Glossary

← [Operations Runbook](08-operations-runbook.md) | [Index](README.md)

---

This glossary provides definitions for key technical terms, acronyms, and concepts used throughout the Azure Logic Apps Monitoring Solution architecture documentation. Terms are organized alphabetically with cross-references to relevant architecture documents where applicable.

---

## A

### Activity Source

A .NET `System.Diagnostics.ActivitySource` that creates spans (activities) for distributed tracing. Used to track operations across service boundaries. See [Observability Architecture](05-observability-architecture.md#5-distributed-tracing).

### ADR (Architecture Decision Record)

A document that captures an important architectural decision made along with its context and consequences. See [ADR folder](adr/).

### AMQP (Advanced Message Queuing Protocol)

The wire protocol used by Azure Service Bus for messaging. Provides reliable, ordered message delivery.

### Aspire

See [.NET Aspire](#net-aspire).

### Azure Container Apps (ACA)

A serverless container hosting platform that runs containerized applications without managing infrastructure. Hosts the Orders API and Web App. See [Technology Architecture](04-technology-architecture.md#7-container-apps-configuration).

### Azure Developer CLI (azd)

A command-line tool that simplifies the developer workflow for building, deploying, and managing Azure applications. See [Deployment Architecture](07-deployment-architecture.md#3-azure-developer-cli-workflow).

### Azure Monitor

The comprehensive monitoring solution for collecting, analyzing, and acting on telemetry from Azure and on-premises environments. Includes Application Insights and Log Analytics.

---

## B

### Bicep

A domain-specific language (DSL) for deploying Azure resources declaratively. Used for Infrastructure as Code in this solution. See [Technology Architecture](04-technology-architecture.md#4-infrastructure-as-code-structure).

### Blazor Server

A .NET web framework that runs on the server with UI updates sent over a SignalR connection. Powers the eShop.Web.App frontend.

### Bounded Context

A Domain-Driven Design (DDD) concept defining a boundary within which a particular domain model applies. Each service in this solution has its own bounded context.

---

## C

### Circuit Breaker

A resilience pattern that prevents cascading failures by "opening" when a service is failing, blocking further requests until recovery. Implemented via Polly. See [Application Architecture](03-application-architecture.md#8-resilience-patterns).

### Container Apps Environment

The shared hosting environment for Azure Container Apps, providing networking, observability, and scaling infrastructure.

### Counter

An OpenTelemetry metric type that represents a cumulative value that only increases (e.g., `eShop.orders.placed`). See [Observability Architecture](05-observability-architecture.md#4-custom-metrics-inventory).

---

## D

### Dead-Letter Queue (DLQ)

A secondary queue where messages that cannot be processed are moved. Used for troubleshooting failed message processing in Service Bus.

### Distributed Tracing

The method of tracking requests as they flow through distributed systems. Implemented using OpenTelemetry with W3C Trace Context. See [Observability Architecture](05-observability-architecture.md#5-distributed-tracing).

### DTU (Database Transaction Unit)

A blended measure of CPU, memory, and I/O resources for Azure SQL Database. Used for capacity planning.

---

## E

### EF Core (Entity Framework Core)

The object-relational mapper (ORM) used for database access in the Orders API. Provides code-first migrations and LINQ queries.

### Emulator

A local development tool that simulates Azure services. Used for Service Bus and SQL during local development with .NET Aspire.

### Event-Driven Architecture

An architectural pattern where services communicate through events (messages) rather than direct calls. Implemented via Service Bus pub/sub. See [ADR-002](adr/ADR-002-service-bus-messaging.md).

---

## F

### Fluent UI

Microsoft's design system and component library used in the eShop.Web.App Blazor frontend for consistent UI.

---

## H

### Health Check

An endpoint that reports the health status of a service and its dependencies. Implemented at `/health` and `/alive` endpoints. See [Observability Architecture](05-observability-architecture.md#7-health-checks).

### Histogram

An OpenTelemetry metric type that records the distribution of values (e.g., `eShop.orders.processing.duration`). Used for latency measurements.

### Hook (azd Lifecycle Hook)

A script that runs at specific points during Azure Developer CLI operations (preprovision, postprovision, predeploy). See [Deployment Architecture](07-deployment-architecture.md#4-lifecycle-hooks).

---

## I

### IaC (Infrastructure as Code)

The practice of managing infrastructure through declarative configuration files rather than manual processes. Implemented with Bicep. See [Technology Architecture](04-technology-architecture.md).

---

## K

### KQL (Kusto Query Language)

The query language used in Azure Monitor, Log Analytics, and Application Insights for analyzing telemetry data. See [Operations Runbook](08-operations-runbook.md#4-kql-query-library).

---

## L

### Log Analytics Workspace

An Azure Monitor resource that stores and queries log data from multiple sources. Central repository for all solution telemetry.

### Logic Apps Standard

Azure's serverless workflow service that runs in a dedicated hosting plan. Processes order events in this solution. See [Application Architecture](03-application-architecture.md#ordersmanagement-logic-app).

---

## M

### Managed Identity

An Azure Active Directory identity automatically managed by Azure, eliminating the need to store credentials in code. See [Security Architecture](06-security-architecture.md#3-managed-identity-configuration).

### Meter

An OpenTelemetry component that creates metrics instruments (counters, histograms, gauges). Defined as `new Meter("eShop.orders", "1.0.0")`.

### Microservices

An architectural style where applications are composed of small, independently deployable services. This solution follows microservices principles.

---

## N

### .NET Aspire

A cloud-ready stack for building observable, production-ready distributed applications with .NET. Used for local development orchestration. See [ADR-001](adr/ADR-001-aspire-orchestration.md).

---

## O

### OpenTelemetry (OTel)

A vendor-neutral observability framework for generating, collecting, and exporting telemetry data (traces, metrics, logs). See [ADR-003](adr/ADR-003-observability-strategy.md).

### Operation ID

A unique identifier that correlates all telemetry (requests, dependencies, traces) belonging to a single logical operation. Propagated via W3C Trace Context.

### OTLP (OpenTelemetry Protocol)

The wire protocol for transmitting telemetry data between OpenTelemetry components. Used to export data to Azure Monitor.

---

## P

### Partition Key

A value used to distribute data across partitions in Service Bus topics. Enables parallel processing and scalability.

### Peek-Lock

A message retrieval mode in Service Bus where messages are locked during processing, then completed or abandoned. Used by Logic Apps trigger.

### Polly

A .NET resilience library providing retry, circuit breaker, timeout, and bulkhead patterns. Integrated via `AddStandardResilienceHandler()`. See [Application Architecture](03-application-architecture.md#8-resilience-patterns).

### Pub/Sub (Publish/Subscribe)

A messaging pattern where publishers send messages to topics, and subscribers receive messages from subscriptions. Implemented with Service Bus.

---

## R

### RBAC (Role-Based Access Control)

Azure's authorization system that grants permissions based on roles assigned to identities. See [Security Architecture](06-security-architecture.md#4-rbac-role-assignments).

### Resilience Handler

A component that wraps HTTP calls with retry logic, circuit breakers, and timeouts. Configured in ServiceDefaults.

### Revision

A specific version of a Container App deployment. Enables blue-green deployments and rollbacks.

---

## S

### Service Bus

Azure's enterprise messaging service providing queues and topics for asynchronous communication. See [ADR-002](adr/ADR-002-service-bus-messaging.md).

### Service Discovery

The mechanism by which services locate each other in a distributed system. .NET Aspire provides automatic service discovery. See [Application Architecture](03-application-architecture.md#6-inter-service-communication).

### ServiceDefaults

A shared .NET project containing cross-cutting concerns (telemetry, resilience, health checks) used by all services. Located at `app.ServiceDefaults/`.

### SignalR

A .NET library for adding real-time web functionality. Used by Blazor Server for UI updates.

### SLA (Service Level Agreement)

A commitment to a certain level of service availability and performance. Typically expressed as uptime percentage (e.g., 99.9%).

### SLI (Service Level Indicator)

A quantitative measure of service level (e.g., request latency, error rate). See [Observability Architecture](05-observability-architecture.md#10-service-level-indicators-slis).

### SLO (Service Level Objective)

A target value or range for a service level indicator (e.g., "99th percentile latency < 500ms").

### Span

A single operation within a distributed trace, representing a unit of work. Created by Activity/ActivitySource in .NET.

### Subscription (Service Bus)

A named consumer of messages from a Service Bus topic. Multiple subscriptions can receive copies of the same message.

---

## T

### TDE (Transparent Data Encryption)

Encryption at rest for Azure SQL Database. Automatically enabled for data protection.

### Three Pillars of Observability

The foundational telemetry types: **Logs** (events), **Metrics** (measurements), **Traces** (request flows). See [Observability Architecture](05-observability-architecture.md).

### TOGAF (The Open Group Architecture Framework)

An enterprise architecture methodology. This documentation follows TOGAF BDAT (Business, Data, Application, Technology) principles.

### Topic (Service Bus)

A message destination that supports multiple subscriptions. The `ordersplaced` topic receives order events.

### Trace Context

Metadata (trace ID, span ID) propagated between services to correlate distributed operations. Uses W3C Trace Context standard.

---

## U

### User-Assigned Managed Identity

A Managed Identity created as a standalone Azure resource and assigned to multiple resources. Used for consistent authentication across services.

---

## V

### Value Stream

A TOGAF concept representing the end-to-end flow of value delivery to customers. See [Business Architecture](01-business-architecture.md#4-value-streams).

---

## W

### W3C Trace Context

A standardized format for propagating trace context across services. Includes `traceparent` and `tracestate` headers.

### Workflow (Logic Apps)

A stateful sequence of actions in Logic Apps that processes events. The `ProcessingOrdersPlaced` workflow handles order events.

---

## Z

### Zero Trust

A security model that requires strict verification for every user and device, regardless of location. Implemented through Managed Identity and RBAC. See [Security Architecture](06-security-architecture.md).

---

## Acronym Reference

| Acronym | Full Term                                      |
| ------- | ---------------------------------------------- |
| ACA     | Azure Container Apps                           |
| ACR     | Azure Container Registry                       |
| ADR     | Architecture Decision Record                   |
| AMQP    | Advanced Message Queuing Protocol              |
| APM     | Application Performance Monitoring             |
| azd     | Azure Developer CLI                            |
| BDAT    | Business, Data, Application, Technology        |
| CI/CD   | Continuous Integration / Continuous Deployment |
| DDD     | Domain-Driven Design                           |
| DLQ     | Dead-Letter Queue                              |
| DTU     | Database Transaction Unit                      |
| EF      | Entity Framework                               |
| IaC     | Infrastructure as Code                         |
| KQL     | Kusto Query Language                           |
| MTTR    | Mean Time To Recovery                          |
| OTel    | OpenTelemetry                                  |
| OTLP    | OpenTelemetry Protocol                         |
| RBAC    | Role-Based Access Control                      |
| SLA     | Service Level Agreement                        |
| SLI     | Service Level Indicator                        |
| SLO     | Service Level Objective                        |
| TDE     | Transparent Data Encryption                    |
| TOGAF   | The Open Group Architecture Framework          |

---

<div align="center">

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**

[⬆ Back to Top](#glossary)

</div>
