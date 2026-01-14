# Azure Logic Apps Monitoring - Documentation Hub

![Azure](https://img.shields.io/badge/Azure-Logic%20Apps-0078D4?logo=microsoftazure&logoColor=white)
![.NET Aspire](https://img.shields.io/badge/.NET%20Aspire-9.5+-512BD4?logo=dotnet&logoColor=white)
![Bicep](https://img.shields.io/badge/Bicep-IaC-f9d423?logo=azure-devops&logoColor=black)
![OpenTelemetry](https://img.shields.io/badge/OpenTelemetry-Observability-7B68EE)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

## 📑 Table of Contents

- [📋 Overview](#-overview)
- [🗺️ Documentation Map](#️-documentation-map)
- [🚀 Quick Links](#-quick-links)
  - [👨‍💻 For Developers](#-for-developers)
  - [🏛️ For Architects](#️-for-architects)
  - [⚙️ For DevOps Engineers](#️-for-devops-engineers)
- [📄 Document Index](#-document-index)
  - [🏗️ Architecture Documentation](#️-architecture-documentation)
  - [📝 Architecture Decision Records](#-architecture-decision-records)
  - [🔄 DevOps Documentation](#-devops-documentation)
  - [🪝 Deployment Hooks Documentation](#-deployment-hooks-documentation)
  - [📚 Root-Level Documentation](#-root-level-documentation)
- [🔗 Related Resources](#-related-resources)

---

## 📋 Overview

This folder contains comprehensive documentation for the **Azure Logic Apps Monitoring Solution**, a cloud-native reference architecture demonstrating enterprise-grade observability patterns for Azure Logic Apps Standard workflows. The documentation follows TOGAF-aligned architecture principles and provides guidance for developers, architects, and DevOps engineers working with .NET Aspire, Azure Services, and Infrastructure as Code.

---

## 🗺️ Documentation Map

| Folder                                            | Description                                                                                                                                 | Contents                                               |
| ------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------ |
| [architecture/](./architecture/README.md)         | TOGAF-aligned architecture documentation covering business, data, application, technology, observability, security, and deployment concerns | 7 architecture documents + ADR subfolder               |
| [architecture/adr/](./architecture/adr/README.md) | Architecture Decision Records documenting key technical decisions with context, rationale, and consequences                                 | 3 ADRs covering Aspire, Service Bus, and Observability |
| [devops/](./devops/README.md)                     | CI/CD pipeline documentation for GitHub Actions workflows including build validation and deployment automation                              | 2 workflow documents                                   |
| [hooks/](./hooks/README.md)                       | Azure Developer CLI (azd) hook scripts documentation for environment validation, provisioning, and deployment automation                    | 11 script documentation files                          |

---

## 🚀 Quick Links

### 👨‍💻 For Developers

| Document                                                                   | Description                                                         |
| -------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| [Developer Inner Loop Workflow](./hooks/README.md)                         | Complete guide for local development and Azure deployment workflows |
| [Application Architecture](./architecture/03-application-architecture.md)  | Service catalog, API contracts, and code organization               |
| [Local Development Setup](./hooks/check-dev-workstation.md)                | Validate workstation prerequisites for development                  |
| [Generate Test Data](./hooks/Generate-Orders.md)                           | Create sample order data for testing workflows                      |
| [ADR-001: .NET Aspire](./architecture/adr/ADR-001-aspire-orchestration.md) | Understanding the orchestration framework decision                  |

### 🏛️ For Architects

| Document                                                                | Description                                          |
| ----------------------------------------------------------------------- | ---------------------------------------------------- |
| [Architecture Overview](./architecture/README.md)                       | High-level system architecture with Mermaid diagrams |
| [Business Architecture](./architecture/01-business-architecture.md)     | Business context, capabilities, and value streams    |
| [Data Architecture](./architecture/02-data-architecture.md)             | Data stores, flows, and telemetry mapping            |
| [Technology Architecture](./architecture/04-technology-architecture.md) | Platform services, standards, and cost analysis      |
| [Security Architecture](./architecture/06-security-architecture.md)     | Zero-trust implementation and threat model           |
| [ADR Index](./architecture/adr/README.md)                               | All architecture decision records                    |

### ⚙️ For DevOps Engineers

| Document                                                                      | Description                                       |
| ----------------------------------------------------------------------------- | ------------------------------------------------- |
| [CI/CD Pipeline Overview](./devops/README.md)                                 | Pipeline architecture and security practices      |
| [azure-dev.yml Workflow](./devops/azure-dev-workflow.md)                      | Main deployment pipeline with OIDC authentication |
| [ci.yml Workflow](./devops/ci-workflow.md)                                    | Build validation pipeline for pull requests       |
| [Deployment Architecture](./architecture/07-deployment-architecture.md)       | IaC strategy, environments, and CI/CD design      |
| [Observability Architecture](./architecture/05-observability-architecture.md) | Monitoring, alerting, and SLO definitions         |
| [IP Security Restrictions](./IP-SECURITY-RESTRICTIONS.md)                     | Network security configuration guide              |

---

## 📄 Document Index

### 🏗️ Architecture Documentation

| Document                                                                            | Description                                                                         | Audience                      |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ----------------------------- |
| [README.md](./architecture/README.md)                                               | Architecture overview with high-level diagrams and service inventory                | All                           |
| [01-business-architecture.md](./architecture/01-business-architecture.md)           | Business context, capabilities, stakeholders, value streams, and quality attributes | Architects, Business Analysts |
| [02-data-architecture.md](./architecture/02-data-architecture.md)                   | Data stores, ownership model, flow architecture, and telemetry mapping              | Architects, Developers        |
| [03-application-architecture.md](./architecture/03-application-architecture.md)     | Service catalog, API contracts, interaction patterns, and code organization         | Developers, Architects        |
| [04-technology-architecture.md](./architecture/04-technology-architecture.md)       | Technology standards, platform services, Azure resource topology, and cost analysis | Architects, DevOps            |
| [05-observability-architecture.md](./architecture/05-observability-architecture.md) | Telemetry strategy, distributed tracing, metrics, logs, and alerting                | DevOps, SRE, Developers       |
| [06-security-architecture.md](./architecture/06-security-architecture.md)           | Zero-trust implementation, managed identity, network security, and compliance       | Security, Architects, DevOps  |
| [07-deployment-architecture.md](./architecture/07-deployment-architecture.md)       | Infrastructure as Code, Azure Developer CLI, CI/CD pipelines, and environments      | DevOps, Architects            |

### 📝 Architecture Decision Records

| Document                                                                                  | Description                                                                     | Audience                |
| ----------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- | ----------------------- |
| [README.md](./architecture/adr/README.md)                                                 | ADR index with decision log and pending decisions                               | All                     |
| [ADR-001-aspire-orchestration.md](./architecture/adr/ADR-001-aspire-orchestration.md)     | Decision to use .NET Aspire 13.1.0 for distributed application orchestration    | Architects, Developers  |
| [ADR-002-service-bus-messaging.md](./architecture/adr/ADR-002-service-bus-messaging.md)   | Decision to use Azure Service Bus topics for asynchronous order event messaging | Architects, Developers  |
| [ADR-003-observability-strategy.md](./architecture/adr/ADR-003-observability-strategy.md) | Decision to implement OpenTelemetry instrumentation with Azure Monitor export   | Architects, DevOps, SRE |

### 🔄 DevOps Documentation

| Document                                                | Description                                                                    | Audience           |
| ------------------------------------------------------- | ------------------------------------------------------------------------------ | ------------------ |
| [README.md](./devops/README.md)                         | DevOps overview with pipeline architecture diagram and security practices      | DevOps, Developers |
| [azure-dev-workflow.md](./devops/azure-dev-workflow.md) | Primary CI/CD pipeline documentation for provisioning and deployment with OIDC | DevOps, Architects |
| [ci-workflow.md](./devops/ci-workflow.md)               | Build validation pipeline for pull requests with .NET and Bicep compilation    | DevOps, Developers |

### 🪝 Deployment Hooks Documentation

| Document                                                                       | Description                                                                     | Audience           |
| ------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- | ------------------ |
| [README.md](./hooks/README.md)                                                 | Developer inner loop workflow overview with script inventory and best practices | All                |
| [VALIDATION-WORKFLOW.md](./hooks/VALIDATION-WORKFLOW.md)                       | Complete validation workflow with visual diagrams and timeline                  | DevOps, Developers |
| [check-dev-workstation.md](./hooks/check-dev-workstation.md)                   | Workstation prerequisite validation script (read-only checks)                   | Developers         |
| [preprovision.md](./hooks/preprovision.md)                                     | Pre-provisioning validation and Azure authentication setup                      | DevOps, Developers |
| [postprovision.md](./hooks/postprovision.md)                                   | Post-provisioning configuration of .NET user secrets from Azure resources       | DevOps, Developers |
| [sql-managed-identity-config.md](./hooks/sql-managed-identity-config.md)       | SQL Database managed identity access configuration                              | DevOps, DBA        |
| [clean-secrets.md](./hooks/clean-secrets.md)                                   | Utility to clear .NET user secrets from all projects                            | Developers         |
| [deploy-workflow.md](./hooks/deploy-workflow.md)                               | Logic Apps Standard workflow deployment automation                              | DevOps, Developers |
| [postinfradelete.md](./hooks/postinfradelete.md)                               | Soft-deleted Logic Apps purge after infrastructure deletion                     | DevOps             |
| [Generate-Orders.md](./hooks/Generate-Orders.md)                               | Sample order data generation for testing workflows                              | Developers, QA     |
| [configure-federated-credential.md](./hooks/configure-federated-credential.md) | GitHub Actions OIDC federated credential setup for passwordless Azure auth      | DevOps             |

### 📚 Root-Level Documentation

| Document                                                                     | Description                                                                         | Audience                       |
| ---------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------ |
| [IP-SECURITY-RESTRICTIONS.md](./IP-SECURITY-RESTRICTIONS.md)                 | Comprehensive IP security restrictions configuration across all Azure resources     | Security, DevOps, Architects   |
| [IP-SECURITY-RESTRICTIONS-SUMMARY.md](./IP-SECURITY-RESTRICTIONS-SUMMARY.md) | Quick reference for IP security restrictions with configuration matrix              | Security, DevOps               |
| [planoProjetoModernizacao.md](./planoProjetoModernizacao.md)                 | Project modernization plan (Portuguese) - Néctar Integration Module for Cooperflora | Project Managers, Stakeholders |

---

## 🔗 Related Resources

### Azure Documentation

| Resource                                                                                                    | Description                                         |
| ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| [Azure Logic Apps Standard](https://learn.microsoft.com/azure/logic-apps/single-tenant-overview-compare)    | Official documentation for single-tenant Logic Apps |
| [Azure Service Bus](https://learn.microsoft.com/azure/service-bus-messaging/service-bus-messaging-overview) | Enterprise messaging service documentation          |
| [Azure Container Apps](https://learn.microsoft.com/azure/container-apps/overview)                           | Serverless container hosting platform               |
| [Azure Application Insights](https://learn.microsoft.com/azure/azure-monitor/app/app-insights-overview)     | Application performance monitoring documentation    |
| [Azure Developer CLI (azd)](https://learn.microsoft.com/azure/developer/azure-developer-cli/)               | Developer workflow automation tool                  |
| [Bicep Language](https://learn.microsoft.com/azure/azure-resource-manager/bicep/overview)                   | Infrastructure as Code for Azure                    |

### .NET and Aspire

| Resource                                                                             | Description                                      |
| ------------------------------------------------------------------------------------ | ------------------------------------------------ |
| [.NET Aspire](https://learn.microsoft.com/dotnet/aspire/get-started/aspire-overview) | Cloud-native application orchestration framework |
| [OpenTelemetry for .NET](https://opentelemetry.io/docs/languages/net/)               | Vendor-neutral observability instrumentation     |
| [ASP.NET Core](https://learn.microsoft.com/aspnet/core/)                             | Web framework documentation                      |
| [Entity Framework Core](https://learn.microsoft.com/ef/core/)                        | ORM documentation                                |

### DevOps and CI/CD

| Resource                                                                                                         | Description                                    |
| ---------------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| [GitHub Actions](https://docs.github.com/en/actions)                                                             | CI/CD platform documentation                   |
| [OIDC with Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure)                         | Federated credentials for GitHub Actions       |
| [Azure Managed Identity](https://learn.microsoft.com/entra/identity/managed-identities-azure-resources/overview) | Passwordless authentication for Azure services |

---

[← Back to Repository Root](../README.md)
