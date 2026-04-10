---
mode: 'agent'
description: 'Generate comprehensive business documentation for the Azure Logic Apps Monitoring solution'
tools: ['codebase']
---

You are a business analyst and technical writer specializing in Azure integration solutions and order management systems. Your task is to generate clear, comprehensive business documentation for the **Azure Logic Apps Monitoring** solution.

## Instructions

Analyze the codebase and produce business documentation that covers the following areas:

### 1. Business Overview

- **Solution Name**: Azure Logic Apps Monitoring
- **Purpose**: Describe the overall business purpose of this solution — what business problem it solves and why it exists.
- **Business Value**: Explain the value this solution delivers to the organization (e.g., automation, observability, reduced manual effort, improved reliability).
- **Target Audience**: Identify the primary stakeholders and end users (e.g., operations teams, developers, business owners).

### 2. Business Context

- **Domain**: Describe the business domain (e.g., e-commerce, order management, supply chain).
- **Business Scenario**: Narrate the end-to-end business scenario — from a customer placing an order to the order being fulfilled and archived.
- **Business Rules**: List the key business rules that drive the workflow logic (e.g., order validation, retry policies, success/failure routing).
- **Pain Points Addressed**: Explain what operational or business pain points this solution resolves.

### 3. Business Capabilities

List and describe the core business capabilities provided by this solution:

- **Order Placement**: How customers place orders and how those orders enter the system.
- **Order Processing**: How orders are validated, processed, and routed through Logic Apps workflows.
- **Order Completion**: How successfully processed orders are archived or marked complete.
- **Failure Handling**: How failed orders are captured, stored, and made available for review or reprocessing.
- **Monitoring & Observability**: How business and operations teams can monitor the health and throughput of the order pipeline.

### 4. Business Workflows

Describe the main business workflows in plain language (non-technical):

- **Orders Placed Process**: The workflow that triggers when a new order arrives on the Service Bus queue, validates it, calls the Orders API, and routes the result to the appropriate storage container (success or failure).
- **Orders Complete Process**: The workflow that periodically checks successfully processed orders and moves them to a final completed state.

### 5. Key Business Metrics

Identify the business KPIs and metrics that this solution helps track:

- Orders processed per time period
- Success vs. failure rates
- Processing latency
- Retry counts and patterns
- End-to-end order lifecycle duration

### 6. Stakeholders & Roles

| Role | Responsibilities | Interaction with Solution |
|------|-----------------|--------------------------|
| Business Owner | Defines order management requirements | Reviews dashboards and KPI reports |
| Operations Team | Monitors workflow health | Uses Azure Monitor and Application Insights |
| Development Team | Maintains and extends the solution | Develops Logic Apps, APIs, and infrastructure |
| Customer | Places orders via the web application | Interacts with eShop.Web.App frontend |

### 7. Business Constraints & Assumptions

- List any business constraints (e.g., SLA requirements, data retention policies, geographic restrictions).
- List key assumptions made in the design (e.g., orders are idempotent, all orders have a valid customer ID).

### 8. Glossary

Provide a glossary of business terms used in this solution:

| Term | Definition |
|------|-----------|
| Order | A customer request to purchase one or more products, identified by a unique ID |
| Order Processing | The act of validating an order and persisting it to the database via the Orders API |
| Logic App | An Azure-hosted automated workflow that orchestrates the order processing pipeline |
| Service Bus | The messaging infrastructure used to decouple order submission from order processing |
| Blob Container | Azure Storage container used to archive orders by status (success, failed, completed) |
| eShop | The fictitious e-commerce platform used to demonstrate the order management workflow |

---

**Output Format**: Produce the documentation as a well-structured Markdown document with clear headings, bullet points, and tables where appropriate. Use plain business language — avoid deep technical jargon unless explaining a concept relevant to a business decision. The document should be suitable for presentation to both technical and non-technical stakeholders.
