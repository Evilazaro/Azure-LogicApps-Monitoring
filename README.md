# Azure Logic Apps Monitoring Solution

![Build status badge showing CI/CD pipeline state](https://img.shields.io/badge/build-passing-brightgreen)
![License badge showing MIT license](https://img.shields.io/badge/license-MIT-blue)
![Version badge showing current release](https://img.shields.io/badge/version-1.0.0-orange)
![Coverage badge showing code coverage percentage](https://img.shields.io/badge/coverage-check%20CI-lightgrey)

> [!NOTE]
> Replace the badges above with actual pipeline URLs once your CI/CD pipeline is configured.

**Azure Logic Apps Monitoring** is a comprehensive monitoring and order-processing solution built on **.NET Aspire** orchestration. It demonstrates an end-to-end distributed system that integrates **Azure Logic Apps Standard** workflows with a microservices-based eShop application deployed to **Azure Container Apps**.

This solution solves the challenge of monitoring and automating order processing workflows at scale. It uses **Azure Service Bus** for event-driven messaging, **Azure Logic Apps** for workflow automation and error handling, and **Application Insights** with **OpenTelemetry** for full-stack observability across all services.

The technology stack leverages **.NET 10**, **Blazor Server** with **Fluent UI** for the frontend, **ASP.NET Core** Web API with **Entity Framework Core** for the backend, and **Azure Bicep** for declarative infrastructure provisioning via the **Azure Developer CLI** (`azd`).

## Table of Contents

- [Features](#features)
- [Architecture](#architecture)
- [Technologies Used](#technologies-used)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Usage](#usage)
- [Contributing](#contributing)
- [License](#license)

## Features

| Feature                      | Description                                                                                                        |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 🛒 Order Management API      | RESTful API for placing, retrieving, and deleting customer orders with full CRUD operations.                       |
| 🌐 Blazor Web Frontend       | Interactive server-side rendered web application with **Fluent UI** components for order management.               |
| ⚡ Logic Apps Workflows      | Automated order processing workflows that validate, process, and archive orders via **Azure Logic Apps Standard**. |
| 📨 Event-Driven Messaging    | Asynchronous order event publishing and consumption through **Azure Service Bus** topics and subscriptions.        |
| 📊 Full-Stack Observability  | Distributed tracing, metrics, and logging with **OpenTelemetry** and **Azure Application Insights**.               |
| 🏗️ .NET Aspire Orchestration | Service discovery, health checks, and resilience patterns managed by the **.NET Aspire** AppHost.                  |
| 🔐 Managed Identity Security | Zero-secret authentication using **Azure Managed Identity** for all service-to-service communication.              |
| 🚀 Infrastructure as Code    | Declarative Azure infrastructure provisioning with **Bicep** templates and automated lifecycle hooks.              |
| 🧪 Comprehensive Testing     | Unit and integration test suites for the AppHost, ServiceDefaults, Orders API, and Web App projects.               |

## Architecture

The **Azure Logic Apps Monitoring Solution** follows a microservices architecture orchestrated by .NET Aspire. The system processes customer orders through an API layer, publishes events to a message bus, and automates downstream workflows using Logic Apps Standard. All services communicate securely via Managed Identity and export telemetry to a centralized observability platform.

```mermaid
---
config:
  theme: base
  flowchart:
    htmlLabels: true
    nodeSpacing: 60
    rankSpacing: 80
    padding: 20
  themeVariables:
    fontSize: 14px
    fontFamily: "Segoe UI, system-ui, sans-serif"
    primaryColor: "#0078D4"
    primaryTextColor: "#242424"
    primaryBorderColor: "#005A9E"
    secondaryColor: "#50E6FF"
    tertiaryColor: "#F5F5F5"
    lineColor: "#616161"
    noteBkgColor: "#F5F5F5"
    noteTextColor: "#242424"
---
flowchart TB
    %% C4 Container Diagram — Azure Logic Apps Monitoring Solution
    %% Styled per Microsoft Fluent UI Design Guidelines
    %% Emoji SVGs from Azure Emoji Icon Library (emoji-library.json) embedded as data URIs

    %% ============================================================
    %% PERSONS / ACTORS
    %% ============================================================
    Customer([<b>Customer</b><br><i>Person</i><br>Places and manages orders<br>through the web application])
    Developer([<b>Developer</b><br><i>Person</i><br>Deploys, monitors, and<br>manages the solution])

    %% ============================================================
    %% EXTERNAL SYSTEMS
    %% ============================================================
    AzureMonitor[\<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPk1vbml0b3I8L3RpdGxlPgogIDxkZXNjPkVtb2ppLXN0eWxlIGljb24gZm9yIEF6dXJlIE1vbml0b3Igc2VydmljZTwvZGVzYz4KICA8Zz4KICAgIDxjaXJjbGUgY3g9IjY0IiBjeT0iNjQiIHI9IjI4IiBmaWxsPSIjN0ZCQTAwIiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iMyIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICA8Y2lyY2xlIGN4PSI2NCIgY3k9IjY0IiByPSIxMiIgZmlsbD0iIzAwNzhENCIvPgogICAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iNiIgZmlsbD0iI0ZGRkZGRiIvPgogICAgPGxpbmUgeDE9Ijg5LjAiIHkxPSI2NC4wIiB4Mj0iOTcuMCIgeTI9IjY0LjAiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSI2IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxsaW5lIHgxPSI4MS43IiB5MT0iODEuNyIgeDI9Ijg3LjMiIHkyPSI4Ny4zIiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iNiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICA8bGluZSB4MT0iNjQuMCIgeTE9Ijg5LjAiIHgyPSI2NC4wIiB5Mj0iOTcuMCIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGxpbmUgeDE9IjQ2LjMiIHkxPSI4MS43IiB4Mj0iNDAuNyIgeTI9Ijg3LjMiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSI2IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxsaW5lIHgxPSIzOS4wIiB5MT0iNjQuMCIgeDI9IjMxLjAiIHkyPSI2NC4wIiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iNiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICA8bGluZSB4MT0iNDYuMyIgeTE9IjQ2LjMiIHgyPSI0MC43IiB5Mj0iNDAuNyIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGxpbmUgeDE9IjY0LjAiIHkxPSIzOS4wIiB4Mj0iNjQuMCIgeTI9IjMxLjAiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSI2IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxsaW5lIHgxPSI4MS43IiB5MT0iNDYuMyIgeDI9Ijg3LjMiIHkyPSI0MC43IiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iNiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICAKICAgIDxjaXJjbGUgY3g9Ijg0IiBjeT0iNDQiIHI9IjQiIGZpbGw9IiMwMDc4RDQiIG9wYWNpdHk9IjAuNyIvPgogIDwvZz4KPC9zdmc+' width='24' height='24' /><br><b>Azure Monitor</b><br><i>External System</i><br>Collects telemetry, logs,<br>and metrics from all services\]

    %% ============================================================
    %% SYSTEM BOUNDARY
    %% ============================================================
    subgraph SystemBoundary [<b>Azure Logic Apps Monitoring — System Boundary</b>]
        direction TB

        %% ========================================================
        %% PRESENTATION LAYER
        %% ========================================================
        subgraph Presentation [<b>Presentation Layer</b>]
            direction LR
            WebApp[<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPkFwcCBTZXJ2aWNlczwvdGl0bGU+CiAgPGRlc2M+RW1vamktc3R5bGUgaWNvbiBmb3IgQXp1cmUgQXBwIFNlcnZpY2VzIHNlcnZpY2U8L2Rlc2M+CiAgPGc+CiAgICA8cmVjdCB4PSIxNSIgeT0iMTUiIHdpZHRoPSI5OCIgaGVpZ2h0PSI5OCIgcng9IjEyIiBmaWxsPSIjMDA3OEQ0IiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iMyIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+CiAgICA8cmVjdCB4PSIyNSIgeT0iNDAiIHdpZHRoPSI3OCIgaGVpZ2h0PSI2MyIgcng9IjQiIGZpbGw9IiNGRkZGRkYiIG9wYWNpdHk9IjAuOSIvPgogICAgPHJlY3QgeD0iMjUiIHk9IjI1IiB3aWR0aD0iNzgiIGhlaWdodD0iMTIiIHJ4PSI0IiBmaWxsPSIjNTBFNkZGIi8+CiAgICA8Y2lyY2xlIGN4PSIzMyIgY3k9IjMxIiByPSIyLjUiIGZpbGw9IiNGRkZGRkYiLz4KICAgIDxjaXJjbGUgY3g9IjQxIiBjeT0iMzEiIHI9IjIuNSIgZmlsbD0iI0ZGRkZGRiIvPgogICAgCiAgICA8cG9seWdvbiBwb2ludHM9Ijg0LDM4IDg4LDQ2IDgwLDQ2IiBmaWxsPSIjNTBFNkZGIiBvcGFjaXR5PSIwLjciLz4KICA8L2c+Cjwvc3ZnPg==' width='24' height='24' /><br><b>eShop Web App</b><br><i>Blazor Server · Container Apps</i><br>Delivers order management UI<br>with Fluent UI components]
        end

        %% ========================================================
        %% APPLICATION LAYER
        %% ========================================================
        subgraph Application [<b>Application Layer</b>]
            direction LR
            OrdersAPI(<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPkNvbnRhaW5lciBBcHBzIEVudmlyb25tZW50czwvdGl0bGU+CiAgPGRlc2M+RW1vamktc3R5bGUgaWNvbiBmb3IgQXp1cmUgQ29udGFpbmVyIEFwcHMgRW52aXJvbm1lbnRzIHNlcnZpY2U8L2Rlc2M+CiAgPGc+CiAgICA8cG9seWdvbiBwb2ludHM9IjY0LDMyIDk2LDY0IDY0LDk2IDMyLDY0IiBmaWxsPSIjMDA3OEQ0IiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iMyIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+CiAgICA8cG9seWdvbiBwb2ludHM9IjY0LDUwIDc4LDY0IDY0LDc4IDUwLDY0IiBmaWxsPSIjNTBFNkZGIi8+CiAgICAKICAgIDxwb2x5Z29uIHBvaW50cz0iODQsMzggODgsNDYgODAsNDYiIGZpbGw9IiM1MEU2RkYiIG9wYWNpdHk9IjAuNyIvPgogIDwvZz4KPC9zdmc+' width='24' height='24' /><br><b>eShop Orders API</b><br><i>ASP.NET Core · Container Apps</i><br>Manages order CRUD operations<br>and publishes events)
            LogicApp(<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPkxvZ2ljIEFwcHM8L3RpdGxlPgogIDxkZXNjPkVtb2ppLXN0eWxlIGljb24gZm9yIEF6dXJlIExvZ2ljIEFwcHMgc2VydmljZTwvZGVzYz4KICA8Zz4KICAgIDxyZWN0IHg9IjIwIiB5PSIyMCIgd2lkdGg9Ijg4IiBoZWlnaHQ9Ijg4IiByeD0iOCIgZmlsbD0iIzdGQkEwMCIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIvPgogICAgPHBhdGggZD0iTTY0IDIwIEw2NCA2NCIgc3Ryb2tlPSIjMDA3OEQ0IiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPHBhdGggZD0iTTIwIDY0IEwxMDggNjQiIHN0cm9rZT0iIzAwNzhENCIgc3Ryb2tlLXdpZHRoPSIzIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxjaXJjbGUgY3g9IjY0IiBjeT0iNjQiIHI9IjgiIGZpbGw9IiMwMDc4RDQiLz4KICAgIDxjaXJjbGUgY3g9IjY0IiBjeT0iNjQiIHI9IjQiIGZpbGw9IiNGRkZGRkYiLz4KICAgIAogICAgPGNpcmNsZSBjeD0iODQiIGN5PSI0NCIgcj0iNCIgZmlsbD0iIzAwNzhENCIgb3BhY2l0eT0iMC43Ii8+CiAgPC9nPgo8L3N2Zz4=' width='24' height='24' /><br><b>Orders Management</b><br><i>Logic Apps Standard</i><br>Automates order processing<br>and archival workflows)
        end

        %% ========================================================
        %% DATA LAYER
        %% ========================================================
        subgraph Data [<b>Data Layer</b>]
            direction LR
            SqlDB[(<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPkF6dXJlIFNRTDwvdGl0bGU+CiAgPGRlc2M+RW1vamktc3R5bGUgaWNvbiBmb3IgQXp1cmUgQXp1cmUgU1FMIHNlcnZpY2U8L2Rlc2M+CiAgPGc+CiAgICA8ZWxsaXBzZSBjeD0iNjQiIGN5PSI0NCIgcng9IjMwIiByeT0iMTIiIGZpbGw9IiM1RUEwRUYiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSIzIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxyZWN0IHg9IjM0IiB5PSI0NCIgd2lkdGg9IjYwIiBoZWlnaHQ9IjQwIiBmaWxsPSIjMDA3OEQ0IiBzdHJva2U9Im5vbmUiLz4KICAgIDxsaW5lIHgxPSIzNCIgeTE9IjQ0IiB4Mj0iMzQiIHkyPSI4NCIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGxpbmUgeDE9Ijk0IiB5MT0iNDQiIHgyPSI5NCIgeTI9Ijg0IiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iMyIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICA8ZWxsaXBzZSBjeD0iNjQiIGN5PSI4NCIgcng9IjMwIiByeT0iMTIiIGZpbGw9IiMwMDc4RDQiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSIzIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxlbGxpcHNlIGN4PSI2NCIgY3k9IjQ0IiByeD0iMzAiIHJ5PSIxMiIgZmlsbD0iIzVFQTBFRiIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGxpbmUgeDE9IjQ2IiB5MT0iNTkiIHgyPSI4MiIgeTI9IjU5IiBzdHJva2U9IiNGRkZGRkYiIHN0cm9rZS13aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBvcGFjaXR5PSIwLjYiLz4KICAgIDxsaW5lIHgxPSI0NiIgeTE9IjY5IiB4Mj0iODIiIHkyPSI2OSIgc3Ryb2tlPSIjRkZGRkZGIiBzdHJva2Utd2lkdGg9IjIiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgb3BhY2l0eT0iMC42Ii8+CiAgICA8cmVjdCB4PSI1NCIgeT0iNTYiIHdpZHRoPSIyMCIgaGVpZ2h0PSIxNiIgcng9IjIiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI0ZGRkZGRiIgc3Ryb2tlLXdpZHRoPSIyIi8+PGxpbmUgeDE9IjU0IiB5MT0iNjIiIHgyPSI3NCIgeTI9IjYyIiBzdHJva2U9IiNGRkZGRkYiIHN0cm9rZS13aWR0aD0iMS41Ii8+PGxpbmUgeDE9IjY0IiB5MT0iNjIiIHgyPSI2NCIgeTI9IjcyIiBzdHJva2U9IiNGRkZGRkYiIHN0cm9rZS13aWR0aD0iMS41Ii8+CiAgICAKICA8L2c+Cjwvc3ZnPg==' width='24' height='24' /><br><b>Azure SQL Database</b><br><i>SQL Server</i><br>Persists order and<br>product data)]
            BlobStorage[(<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPlN0b3JhZ2UgQWNjb3VudHM8L3RpdGxlPgogIDxkZXNjPkVtb2ppLXN0eWxlIGljb24gZm9yIEF6dXJlIFN0b3JhZ2UgQWNjb3VudHMgc2VydmljZTwvZGVzYz4KICA8Zz4KICAgIDxyZWN0IHg9IjE1IiB5PSIxNSIgd2lkdGg9Ijk4IiBoZWlnaHQ9Ijk4IiByeD0iMTIiIGZpbGw9IiMwMDc4RDQiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSIzIiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz4KICAgIDxyZWN0IHg9IjIzIiB5PSIyMyIgd2lkdGg9IjgyIiBoZWlnaHQ9IjIwIiByeD0iNCIgZmlsbD0iIzUwRTZGRiIvPgogICAgPGNpcmNsZSBjeD0iNjQiIGN5PSI3NCIgcj0iMTUiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI0ZGRkZGRiIgc3Ryb2tlLXdpZHRoPSIzIi8+CiAgICA8Y2lyY2xlIGN4PSI2NCIgY3k9Ijc0IiByPSI1IiBmaWxsPSIjRkZGRkZGIi8+CiAgICAKICAgIDxjaXJjbGUgY3g9Ijg0IiBjeT0iNDQiIHI9IjQiIGZpbGw9IiM1MEU2RkYiIG9wYWNpdHk9IjAuNyIvPgogIDwvZz4KPC9zdmc+' width='24' height='24' /><br><b>Azure Blob Storage</b><br><i>Storage Account</i><br>Archives processed order<br>results and errors)]
        end

        %% ========================================================
        %% CROSS-CUTTING CONCERNS
        %% ========================================================
        subgraph CrossCutting [<b>Cross-Cutting Concerns</b>]
            direction LR
            ServiceBus(<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPkF6dXJlIFNlcnZpY2UgQnVzPC90aXRsZT4KICA8ZGVzYz5FbW9qaS1zdHlsZSBpY29uIGZvciBBenVyZSBBenVyZSBTZXJ2aWNlIEJ1cyBzZXJ2aWNlPC9kZXNjPgogIDxnPgogICAgPHJlY3QgeD0iMjAiIHk9IjIwIiB3aWR0aD0iODgiIGhlaWdodD0iODgiIHJ4PSI4IiBmaWxsPSIjN0ZCQTAwIiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iMyIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+CiAgICA8cGF0aCBkPSJNNjQgMjAgTDY0IDY0IiBzdHJva2U9IiMwMDc4RDQiIHN0cm9rZS13aWR0aD0iMyIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICA8cGF0aCBkPSJNMjAgNjQgTDEwOCA2NCIgc3Ryb2tlPSIjMDA3OEQ0IiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iOCIgZmlsbD0iIzAwNzhENCIvPgogICAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iNCIgZmlsbD0iI0ZGRkZGRiIvPgogICAgCiAgICAKICA8L2c+Cjwvc3ZnPg==' width='24' height='24' /><br><b>Azure Service Bus</b><br><i>Messaging</i><br>Routes order events between<br>services via topics)
            AppInsights(<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPkFwcGxpY2F0aW9uIEluc2lnaHRzPC90aXRsZT4KICA8ZGVzYz5FbW9qaS1zdHlsZSBpY29uIGZvciBBenVyZSBBcHBsaWNhdGlvbiBJbnNpZ2h0cyBzZXJ2aWNlPC9kZXNjPgogIDxnPgogICAgPGNpcmNsZSBjeD0iNjQiIGN5PSI2NCIgcj0iMjgiIGZpbGw9IiM3RkJBMDAiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSIzIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxjaXJjbGUgY3g9IjY0IiBjeT0iNjQiIHI9IjEyIiBmaWxsPSIjMDA3OEQ0Ii8+CiAgICA8Y2lyY2xlIGN4PSI2NCIgY3k9IjY0IiByPSI2IiBmaWxsPSIjRkZGRkZGIi8+CiAgICA8bGluZSB4MT0iODkuMCIgeTE9IjY0LjAiIHgyPSI5Ny4wIiB5Mj0iNjQuMCIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGxpbmUgeDE9IjgxLjciIHkxPSI4MS43IiB4Mj0iODcuMyIgeTI9Ijg3LjMiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSI2IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxsaW5lIHgxPSI2NC4wIiB5MT0iODkuMCIgeDI9IjY0LjAiIHkyPSI5Ny4wIiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iNiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICA8bGluZSB4MT0iNDYuMyIgeTE9IjgxLjciIHgyPSI0MC43IiB5Mj0iODcuMyIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGxpbmUgeDE9IjM5LjAiIHkxPSI2NC4wIiB4Mj0iMzEuMCIgeTI9IjY0LjAiIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSI2IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIDxsaW5lIHgxPSI0Ni4zIiB5MT0iNDYuMyIgeDI9IjQwLjciIHkyPSI0MC43IiBzdHJva2U9IiMwMDVBOUUiIHN0cm9rZS13aWR0aD0iNiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+CiAgICA8bGluZSB4MT0iNjQuMCIgeTE9IjM5LjAiIHgyPSI2NC4wIiB5Mj0iMzEuMCIgc3Ryb2tlPSIjMDA1QTlFIiBzdHJva2Utd2lkdGg9IjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPgogICAgPGxpbmUgeDE9IjgxLjciIHkxPSI0Ni4zIiB4Mj0iODcuMyIgeTI9IjQwLjciIHN0cm9rZT0iIzAwNUE5RSIgc3Ryb2tlLXdpZHRoPSI2IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz4KICAgIAogICAgPHBvbHlnb24gcG9pbnRzPSI4NCwzOCA4OCw0NiA4MCw0NiIgZmlsbD0iIzAwNzhENCIgb3BhY2l0eT0iMC43Ii8+CiAgPC9nPgo8L3N2Zz4=' width='24' height='24' /><br><b>Application Insights</b><br><i>Observability</i><br>Collects traces, metrics,<br>and logs via OpenTelemetry)
            ManagedIdentity(<img src='data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMjgiIGhlaWdodD0iMTI4IiB2aWV3Qm94PSIwIDAgMTI4IDEyOCI+CiAgPHRpdGxlPk1hbmFnZWQgSWRlbnRpdGllczwvdGl0bGU+CiAgPGRlc2M+RW1vamktc3R5bGUgaWNvbiBmb3IgQXp1cmUgTWFuYWdlZCBJZGVudGl0aWVzIHNlcnZpY2U8L2Rlc2M+CiAgPGc+CiAgICA8cGF0aCBkPSJNNjQgMjkgTDk0IDQ0IEw5NCA2OSBROTQgOTQgNjQgMTAyIFEzNCA5NCAzNCA2OSBMMzQgNDQgWiIgZmlsbD0iI0ZGQjkwMCIgc3Ryb2tlPSIjREEzQjAxIiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIvPgogICAgPHBhdGggZD0iTTU2IDY3IEw2MiA3NCBMNzYgNTYiIGZpbGw9Im5vbmUiIHN0cm9rZT0iI0ZGRkZGRiIgc3Ryb2tlLXdpZHRoPSI0IiBzdHJva2UtbGluZWNhcD0icm91bmQiIHN0cm9rZS1saW5lam9pbj0icm91bmQiLz4KICAgIAogICAgCiAgPC9nPgo8L3N2Zz4=' width='24' height='24' /><br><b>Managed Identity</b><br><i>Security</i><br>Provides zero-secret<br>authentication for all services)
        end
    end

    %% ============================================================
    %% RELATIONSHIPS
    %% ============================================================

    %% Actor interactions
    Customer -- "Places and views orders" --> WebApp
    Developer -- "Deploys and monitors via azd" --> OrdersAPI

    %% Presentation to Application
    WebApp -- "HTTP requests" --> OrdersAPI

    %% Application to Data
    OrdersAPI -- "Reads/Writes order data" --> SqlDB
    LogicApp -- "Archives processed orders" --> BlobStorage

    %% Messaging interactions
    OrdersAPI -- "Publishes order events" --> ServiceBus
    ServiceBus -- "Triggers processing" --> LogicApp
    LogicApp -- "Calls process endpoint" --> OrdersAPI

    %% Observability
    OrdersAPI -. "Telemetry" .-> AppInsights
    WebApp -. "Telemetry" .-> AppInsights
    LogicApp -. "Telemetry" .-> AppInsights
    AppInsights -. "Forwards metrics" .-> AzureMonitor

    %% Security
    OrdersAPI -. "Authenticates via" .-> ManagedIdentity
    LogicApp -. "Authenticates via" .-> ManagedIdentity

    %% ============================================================
    %% FLUENT UI STYLES
    %% ============================================================
    %% Category colors from Azure Emoji Icon Library:
    %% App Services: fill #0078D4, stroke #005A9E
    %% Integration: fill #7FBA00, stroke #005A9E
    %% Databases: fill #0078D4, stroke #005A9E
    %% Storage: fill #0078D4, stroke #005A9E
    %% Identity: fill #FFB900, stroke #DA3B01
    %% Management + Governance: fill #7FBA00, stroke #005A9E
    %% Containers: fill #00B7C3, stroke #005A9E

    %% Actors
    style Customer fill:#F5F5F5,stroke:#616161,stroke-width:2px,color:#242424
    style Developer fill:#F5F5F5,stroke:#616161,stroke-width:2px,color:#242424

    %% External Systems
    style AzureMonitor fill:#7FBA00,stroke:#005A9E,stroke-width:3px,color:#FFFFFF

    %% Presentation Layer
    style WebApp fill:#0078D4,stroke:#005A9E,stroke-width:3px,color:#FFFFFF

    %% Application Layer
    style OrdersAPI fill:#0078D4,stroke:#005A9E,stroke-width:3px,color:#FFFFFF
    style LogicApp fill:#7FBA00,stroke:#005A9E,stroke-width:3px,color:#FFFFFF

    %% Data Layer
    style SqlDB fill:#0078D4,stroke:#005A9E,stroke-width:3px,color:#FFFFFF
    style BlobStorage fill:#0078D4,stroke:#005A9E,stroke-width:3px,color:#FFFFFF

    %% Cross-Cutting Concerns
    style ServiceBus fill:#7FBA00,stroke:#005A9E,stroke-width:3px,color:#FFFFFF
    style AppInsights fill:#00B7C3,stroke:#005A9E,stroke-width:3px,color:#FFFFFF
    style ManagedIdentity fill:#FFB900,stroke:#DA3B01,stroke-width:3px,color:#242424

    %% Subgraph Styles
    style SystemBoundary fill:#FAFAFA,stroke:#0078D4,stroke-width:2px,color:#242424
    style Presentation fill:#E8F4FD,stroke:#0078D4,stroke-width:1px,color:#242424
    style Application fill:#E8F8E8,stroke:#7FBA00,stroke-width:1px,color:#242424
    style Data fill:#E8F4FD,stroke:#0078D4,stroke-width:1px,color:#242424
    style CrossCutting fill:#FFF8E1,stroke:#FFB900,stroke-width:1px,color:#242424
```

## Technologies Used

| Technology                           | Type            | Purpose                                                         |
| ------------------------------------ | --------------- | --------------------------------------------------------------- |
| .NET 10                              | Runtime         | Application runtime for all services                            |
| ASP.NET Core                         | Framework       | Web API framework for the Orders API                            |
| Blazor Server                        | Framework       | Interactive server-side UI rendering for the Web App            |
| .NET Aspire 13.x                     | Orchestrator    | Service orchestration, discovery, health checks, and resilience |
| Entity Framework Core                | ORM             | Database access and migrations for Azure SQL                    |
| Microsoft Fluent UI                  | UI Library      | Component library for the Blazor frontend                       |
| Azure Logic Apps Standard            | Workflow Engine | Automated order processing and archival workflows               |
| Azure Service Bus                    | Messaging       | Asynchronous event-driven communication between services        |
| Azure SQL Database                   | Database        | Persistent storage for orders and product data                  |
| Azure Blob Storage                   | Storage         | Archival of processed order results                             |
| Azure Container Apps                 | Hosting         | Serverless container hosting for API and Web App                |
| Azure Application Insights           | Observability   | Distributed tracing, metrics, and log aggregation               |
| OpenTelemetry                        | Telemetry       | Vendor-neutral instrumentation for traces and metrics           |
| Azure Managed Identity               | Security        | Passwordless authentication for all Azure services              |
| Azure Bicep                          | IaC             | Declarative infrastructure provisioning templates               |
| Azure Developer CLI (azd)            | Tooling         | End-to-end deployment lifecycle management                      |
| Swashbuckle                          | API Docs        | OpenAPI/Swagger documentation generation                        |
| Azure.Identity                       | Library         | Managed Identity credential provider                            |
| Microsoft.Extensions.Http.Resilience | Library         | HTTP retry policies and circuit breakers                        |

## Quick Start

### Prerequisites

| Prerequisite              | Minimum Version | Purpose                         |
| ------------------------- | --------------- | ------------------------------- |
| .NET SDK                  | 10.0.100        | Build and run the application   |
| Azure CLI                 | 2.60.0          | Azure resource management       |
| Azure Developer CLI (azd) | 1.11.0          | Deployment lifecycle automation |
| Docker                    | Latest          | Local container emulation       |

> [!IMPORTANT]
> Ensure all prerequisites are installed and available on your system `PATH` before proceeding.

### Installation Steps

1. Clone the repository:

```bash
git clone https://github.com/Evilazaro/Azure-LogicApps-Monitoring.git
cd Azure-LogicApps-Monitoring
```

2. Restore dependencies and build the solution:

```bash
dotnet restore --verbosity minimal
dotnet build --configuration Debug --verbosity minimal
```

3. Run the application locally using the .NET Aspire AppHost:

```bash
dotnet run --project app.AppHost/app.AppHost.csproj
```

4. Open the Aspire Dashboard at the URL shown in the terminal output to view all services, health checks, and telemetry.

### Minimal Working Example

```bash
# Start the Aspire AppHost (orchestrates all services)
dotnet run --project app.AppHost/app.AppHost.csproj

# In a separate terminal, place a test order via the Orders API
curl -X POST https://localhost:<port>/api/Orders \
  -H "Content-Type: application/json" \
  -d '{"id":"order-001","total":99.99,"products":[{"name":"Widget","price":99.99,"quantity":1}]}'
```

> [!TIP]
> The actual port is dynamically assigned by Aspire. Check the dashboard or terminal output for the Orders API endpoint URL.

## Configuration

| Option                                  | Default      | Description                                                 |
| --------------------------------------- | ------------ | ----------------------------------------------------------- |
| `ConnectionStrings:OrderDb`             | _(required)_ | SQL Server connection string for order persistence          |
| `ConnectionStrings:messaging`           | _(optional)_ | Service Bus connection string for local emulator            |
| `Azure:ServiceBus:HostName`             | _(optional)_ | Azure Service Bus fully qualified namespace                 |
| `APPLICATIONINSIGHTS_CONNECTION_STRING` | _(optional)_ | Application Insights connection string for telemetry export |
| `Azure:TenantId`                        | _(optional)_ | Azure AD tenant ID for local development authentication     |
| `Azure:ClientId`                        | _(optional)_ | Azure AD client ID for local development authentication     |
| `OTEL_EXPORTER_OTLP_ENDPOINT`           | _(optional)_ | OpenTelemetry collector endpoint for trace export           |
| `MESSAGING_HOST`                        | `localhost`  | Service Bus namespace hostname or `localhost` for emulator  |

### Configuration Override Example

Override settings via `appsettings.Development.json` or user secrets:

```json
{
  "ConnectionStrings": {
    "OrderDb": "Server=localhost;Database=OrdersDb;Trusted_Connection=True;TrustServerCertificate=True"
  },
  "Azure": {
    "ServiceBus": {
      "HostName": "my-namespace.servicebus.windows.net"
    },
    "TenantId": "<your-tenant-id>",
    "ClientId": "<your-client-id>"
  }
}
```

> [!WARNING]
> Never commit secrets or connection strings to source control. Use `dotnet user-secrets` for local development and **Azure Key Vault** for production deployments.

## Deployment

1. Authenticate with Azure:

```bash
azd auth login
```

2. Create a new deployment environment:

```bash
azd env new <environment-name>
```

3. Provision infrastructure and deploy the application:

```bash
azd up
```

> [!NOTE]
> The `azd up` command executes lifecycle hooks that build the solution, run tests, provision **Bicep** infrastructure, and configure post-deployment secrets automatically.

4. Verify the deployment by navigating to the Azure Container Apps URLs shown in the deployment output.

5. Generate sample order data for testing (runs automatically via `postprovision` hook, or manually):

```bash
./hooks/Generate-Orders.ps1 -Force -Verbose
```

6. To tear down all deployed resources:

```bash
azd down
```

### Infrastructure Layout

The `infra/` directory contains all **Bicep** templates organized as follows:

| Path               | Purpose                                                         |
| ------------------ | --------------------------------------------------------------- |
| `infra/main.bicep` | Entry point orchestrator                                        |
| `infra/shared/`    | Identity, monitoring, networking, and data resources            |
| `infra/workload/`  | Service Bus, Container Apps, Container Registry, and Logic Apps |

## Usage

### Place an Order via the API

```bash
curl -X POST https://<orders-api-url>/api/Orders \
  -H "Content-Type: application/json" \
  -d '{
    "id": "order-123",
    "total": 149.97,
    "products": [
      { "name": "Keyboard", "price": 79.99, "quantity": 1 },
      { "name": "Mouse", "price": 69.98, "quantity": 2 }
    ]
  }'
```

Expected response (HTTP 201 Created):

```json
{
  "id": "order-123",
  "total": 149.97,
  "status": "Placed",
  "products": [
    { "name": "Keyboard", "price": 79.99, "quantity": 1 },
    { "name": "Mouse", "price": 69.98, "quantity": 2 }
  ]
}
```

### Order Processing Workflow

Once an order is placed, the system executes the following automated workflow:

1. The **Orders API** publishes an order event to **Azure Service Bus**.
2. The **OrdersPlacedProcess** Logic App workflow triggers on new Service Bus messages.
3. The workflow validates the message content type and calls the Orders API `/api/Orders/process` endpoint.
4. On success (HTTP 201), the order payload is archived to the `ordersprocessedsuccessfully` blob container.
5. On failure, the order payload is archived to the `ordersprocessedwitherrors` blob container.
6. The **OrdersPlacedCompleteProcess** workflow runs on a recurrence schedule, lists processed blobs, and cleans up completed entries.

### Run Tests

```bash
dotnet test --configuration Debug --verbosity minimal
```

### View API Documentation

Access the Swagger UI at `https://<orders-api-url>/swagger` when the Orders API is running to explore all available endpoints interactively.

## Contributing

Contributions are welcome and encouraged. To contribute:

1. Fork the repository.
2. Create a feature branch from `main`.
3. Make your changes and ensure all tests pass with `dotnet test`.
4. Submit a pull request with a clear description of the changes.

> [!TIP]
> Open an issue first to discuss significant changes before investing development time.

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for full details.
