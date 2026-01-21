---
title: DevOps Documentation
description: Comprehensive documentation for CI/CD pipelines and DevOps configurations for the Azure Logic Apps Monitoring solution
author: Platform Team
date: 2026-01-21
version: 1.0.0
tags: [devops, ci-cd, github-actions, azure, pipelines]
---

# 🚀 DevOps Documentation

> [!NOTE]
> **Target Audience:** DevOps Engineers, Platform Engineers, Developers<br/>
> **Reading Time:** ~15 minutes

<details>
<summary>📍 Navigation</summary>

| Previous |      Index       |                        Next |
| :------- | :--------------: | --------------------------: |
| —        | **You are here** | [CI Workflow](ci-dotnet.md) |

</details>

---

## 📑 Table of Contents

- [🚀 DevOps Documentation](#-devops-documentation)
  - [📑 Table of Contents](#-table-of-contents)
  - [📖 Overview](#-overview)
  - [🏗️ Architecture Overview](#️-architecture-overview)
  - [📊 Master Pipeline Diagram](#-master-pipeline-diagram)
  - [📚 Documentation Index](#-documentation-index)
  - [⚡ Quick Reference](#-quick-reference)
  - [🔄 Pipeline Flow](#-pipeline-flow)
  - [💻 Local Development](#-local-development)
  - [✅ Best Practices](#-best-practices)
  - [🔧 Troubleshooting](#-troubleshooting)
  - [📚 Related Documentation](#-related-documentation)

---

## 📖 Overview

This folder contains comprehensive documentation for the CI/CD pipelines and DevOps configurations used in the Azure Logic Apps Monitoring solution. The project uses GitHub Actions for continuous integration and deployment to Azure.

---

## 🏗️ Architecture Overview

The DevOps architecture follows a modern CI/CD approach with:

> [!TIP]
> This architecture leverages GitHub Actions' native features for maximum efficiency and security.

- **Reusable Workflows**: Modular, DRY workflow design
- **Cross-Platform Testing**: Validation across Ubuntu, Windows, and macOS
- **Security-First**: CodeQL scanning on every CI run
- **Infrastructure as Code**: Azure resources provisioned via Bicep templates
- **OIDC Authentication**: Secure, secretless authentication with Azure

---

## 📊 Master Pipeline Diagram

<details>
<summary>🔍 Click to expand full pipeline diagram</summary>

```mermaid
---
title: Master CI/CD Pipeline Architecture
---
flowchart TD
    %% ===== TRIGGER EVENTS =====
    subgraph Triggers["🎯 Trigger Events"]
        T_PUSH(["Push to Branch"])
        T_PR(["Pull Request"])
        T_MANUAL(["Manual Dispatch"])
        T_SCHEDULE(["Weekly Schedule"])
    end

    %% ===== DEPENDABOT AUTOMATION =====
    subgraph Dependabot["🤖 Dependabot"]
        DEP_NUGET["NuGet Updates"]
        DEP_ACTIONS["Actions Updates"]
    end

    %% ===== CI ENTRY POINT =====
    subgraph CIWorkflow["📋 CI Workflow (ci-dotnet.yml)"]
        CI_ENTRY[["CI Entry Point"]]
    end

    %% ===== REUSABLE CI WORKFLOW =====
    subgraph ReusableCI["🔄 Reusable CI (ci-dotnet-reusable.yml)"]
        direction TB

        subgraph BuildMatrix["🔨 Build (Matrix)"]
            B_U["Ubuntu"]
            B_W["Windows"]
            B_M["macOS"]
        end

        subgraph TestMatrix["🧪 Test (Matrix)"]
            T_U["Ubuntu"]
            T_W["Windows"]
            T_M["macOS"]
        end

        ANALYZE["🔍 Analyze<br/>Code Format"]
        CODEQL["🛡️ CodeQL<br/>Security Scan"]
        CI_SUMMARY[/"📊 CI Summary"/]
    end

    %% ===== CD WORKFLOW =====
    subgraph CDWorkflow["🚀 CD Workflow (azure-dev.yml)"]
        direction TB
        CD_CI[["🔄 CI Stage"]]
        CD_DEPLOY["🚀 Deploy Dev"]
        CD_SUMMARY[/"📊 CD Summary"/]

        subgraph DeployPhases["Deployment Phases"]
            DP1["Setup & Auth"]
            DP2["Provision Infra"]
            DP3["SQL Config"]
            DP4["Deploy App"]
        end
    end

    %% ===== AZURE RESOURCES =====
    subgraph Azure["☁️ Azure"]
        AZ_RG[("Resource Group")]
        AZ_ACA["Container Apps"]
        AZ_SQL[("Azure SQL")]
        AZ_SB["Service Bus"]
    end

    %% ===== TRIGGER FLOWS =====
    T_PUSH -->|triggers| CI_ENTRY
    T_PR -->|triggers| CI_ENTRY
    T_MANUAL -->|triggers| CI_ENTRY
    T_MANUAL -->|triggers| CD_CI
    T_PUSH -->|triggers| CD_CI

    %% ===== DEPENDABOT FLOWS =====
    T_SCHEDULE -->|runs| DEP_NUGET
    T_SCHEDULE -->|runs| DEP_ACTIONS
    DEP_NUGET -.->|creates PR| T_PR
    DEP_ACTIONS -.->|creates PR| T_PR

    %% ===== CI FLOW =====
    CI_ENTRY ==>|calls| BuildMatrix
    BuildMatrix -->|compiles| TestMatrix
    BuildMatrix -->|validates| ANALYZE
    BuildMatrix -->|scans| CODEQL
    TestMatrix -->|reports| CI_SUMMARY
    ANALYZE -->|reports| CI_SUMMARY
    CODEQL -->|reports| CI_SUMMARY

    %% ===== CD FLOW =====
    CD_CI ==>|calls| BuildMatrix
    CD_CI -->|success/skipped| CD_DEPLOY
    CD_DEPLOY -->|executes| DP1
    DP1 -->|then| DP2
    DP2 -->|then| DP3
    DP3 -->|then| DP4
    DP4 -->|generates| CD_SUMMARY

    %% ===== AZURE DEPLOYMENT =====
    DP2 ==>|provisions| AZ_RG
    DP3 ==>|configures| AZ_SQL
    DP4 ==>|deploys to| AZ_ACA
    AZ_ACA -->|connects| AZ_SB

    %% ===== NODE STYLING =====
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef matrix fill:#D1FAE5,stroke:#10B981,color:#000000

    %% ===== APPLY NODE CLASSES =====
    class T_PUSH,T_PR,T_MANUAL,T_SCHEDULE trigger
    class DEP_NUGET,DEP_ACTIONS external
    class CI_ENTRY,CD_CI primary
    class B_U,B_W,B_M,T_U,T_W,T_M matrix
    class ANALYZE,CODEQL secondary
    class CD_DEPLOY,DP1,DP2,DP3,DP4 primary
    class AZ_RG,AZ_SQL datastore
    class AZ_ACA,AZ_SB secondary
    class CI_SUMMARY,CD_SUMMARY datastore

    %% ===== SUBGRAPH STYLING =====
    style Triggers fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style Dependabot fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
    style CIWorkflow fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style ReusableCI fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style BuildMatrix fill:#D1FAE5,stroke:#059669,stroke-width:1px
    style TestMatrix fill:#D1FAE5,stroke:#059669,stroke-width:1px
    style CDWorkflow fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style DeployPhases fill:#D1FAE5,stroke:#059669,stroke-width:1px
    style Azure fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
```

</details>

---

## 📚 Documentation Index

> [!IMPORTANT]
> Start with the [CI Workflow](ci-dotnet.md) to understand the foundation of our pipeline architecture.

| Document                                           | Description                                      |
| :------------------------------------------------- | :----------------------------------------------- |
| [🔨 CI - .NET Build and Test](ci-dotnet.md)        | Main CI workflow orchestrating builds and tests  |
| [🔄 CI - Reusable Workflow](ci-dotnet-reusable.md) | Reusable CI workflow with cross-platform support |
| [🚀 CD - Azure Deployment](azure-dev.md)           | Continuous deployment to Azure using azd         |
| [🤖 Dependabot Configuration](dependabot.md)       | Automated dependency update configuration        |

---

## ⚡ Quick Reference

### Workflows Summary

| Workflow                 | File                     | Triggers                     | Purpose                  |
| :----------------------- | :----------------------- | :--------------------------- | :----------------------- |
| CI - .NET Build and Test | `ci-dotnet.yml`          | push, pull_request, dispatch | Code quality validation  |
| CI - Reusable            | `ci-dotnet-reusable.yml` | workflow_call                | Shared CI implementation |
| CD - Azure Deployment    | `azure-dev.yml`          | push, dispatch               | Deploy to Azure          |
| Dependabot               | `dependabot.yml`         | schedule (weekly)            | Dependency updates       |

### Jobs Overview

| Job           | Workflow(s)           | Runners                | Purpose                     |
| :------------ | :-------------------- | :--------------------- | :-------------------------- |
| 🔨 Build      | CI Reusable           | ubuntu, windows, macos | Compile solution            |
| 🧪 Test       | CI Reusable           | ubuntu, windows, macos | Execute tests with coverage |
| 🔍 Analyze    | CI Reusable           | ubuntu-latest          | Code format verification    |
| 🛡️ CodeQL     | CI Reusable           | ubuntu-latest          | Security scanning           |
| 🚀 Deploy Dev | CD Azure              | ubuntu-latest          | Deploy to dev environment   |
| 📊 Summary    | CI Reusable, CD Azure | ubuntu-latest          | Generate reports            |

### Required Secrets & Variables

| Name                    | Type     | Used In | Description                    |
| :---------------------- | :------- | :------ | :----------------------------- |
| `AZURE_CLIENT_ID`       | Variable | CD      | Azure AD application client ID |
| `AZURE_TENANT_ID`       | Variable | CD      | Azure AD tenant ID             |
| `AZURE_SUBSCRIPTION_ID` | Variable | CD      | Azure subscription ID          |
| `AZURE_ENV_NAME`        | Variable | CD      | Azure environment name         |
| `AZURE_LOCATION`        | Variable | CD      | Azure region                   |

### Artifacts Generated

| Artifact               | Workflow | Contents                      | Retention |
| :--------------------- | :------- | :---------------------------- | :-------- |
| `build-artifacts-{os}` | CI       | Compiled binaries             | 30 days   |
| `test-results-{os}`    | CI       | Test results (.trx)           | 30 days   |
| `code-coverage-{os}`   | CI       | Coverage reports (Cobertura)  | 30 days   |
| `codeql-sarif-results` | CI       | Security scan results (SARIF) | 30 days   |

---

## 🔄 Pipeline Flow

### CI Pipeline (Pull Requests & Pushes)

<details>
<summary>🔍 View CI Pipeline Sequence Diagram</summary>

```mermaid
---
title: CI Pipeline Sequence
---
sequenceDiagram
    autonumber
    participant Dev as 👨‍💻 Developer
    participant GH as 🐙 GitHub
    participant CI as 🔄 CI Workflow
    participant Matrix as 📊 Build/Test Matrix

    %% ===== TRIGGER PHASE =====
    Dev->>GH: Push commit / Create PR
    GH->>CI: Trigger workflow
    CI->>Matrix: Start parallel builds

    %% ===== MATRIX EXECUTION =====
    par Ubuntu Build
        Matrix->>Matrix: Build → Test → Coverage
    and Windows Build
        Matrix->>Matrix: Build → Test → Coverage
    and macOS Build
        Matrix->>Matrix: Build → Test → Coverage
    end

    %% ===== RESULTS PHASE =====
    Matrix-->>CI: Aggregate results
    CI->>CI: Analyze (format check)
    CI->>CI: CodeQL (security scan)
    CI-->>GH: Post status checks
    GH-->>Dev: Display results
```

</details>

### CD Pipeline (Deployment)

<details>
<summary>🔍 View CD Pipeline Sequence Diagram</summary>

```mermaid
---
title: CD Pipeline Sequence
---
sequenceDiagram
    autonumber
    participant Dev as 👨‍💻 Developer
    participant GH as 🐙 GitHub
    participant CD as 🚀 CD Workflow
    participant Azure as ☁️ Azure

    %% ===== TRIGGER PHASE =====
    Dev->>GH: Push to branch / Manual trigger
    GH->>CD: Trigger workflow

    %% ===== CI STAGE =====
    CD->>CD: CI Stage (Build, Test, Analyze)

    %% ===== AUTHENTICATION =====
    CD->>Azure: OIDC Authentication
    Azure-->>CD: Access Token

    %% ===== PROVISIONING =====
    CD->>Azure: azd provision
    Azure-->>CD: Resources created

    %% ===== SQL CONFIGURATION =====
    CD->>Azure: Configure SQL User
    Azure-->>CD: User created

    %% ===== DEPLOYMENT =====
    CD->>Azure: azd deploy
    Azure-->>CD: App deployed

    %% ===== SUMMARY =====
    CD-->>GH: Generate summary
    GH-->>Dev: Display deployment status
```

</details>

---

## 💻 Local Development

> [!TIP]
> Running CI checks locally before pushing helps catch issues early and speeds up the feedback loop.

### Running CI Checks Locally

```bash
# Build solution
dotnet build app.sln --configuration Release

# Run tests with coverage
dotnet test app.sln --configuration Release --collect:"XPlat Code Coverage"

# Check code formatting
dotnet format app.sln --verify-no-changes

# Fix formatting issues
dotnet format app.sln
```

### Deploying Locally with azd

> [!WARNING]
> Running `azd up` locally will provision real Azure resources and may incur costs.

```bash
# Login to Azure
azd auth login

# Provision infrastructure
azd provision

# Deploy application
azd deploy

# Full provision and deploy
azd up
```

---

## ✅ Best Practices

### 🔒 Security

- ✅ OIDC authentication (no stored secrets)
- ✅ CodeQL security scanning on every CI run
- ✅ Pinned action versions (SHA-based)
- ✅ Least-privilege permissions
- ✅ Dependabot for dependency updates

### 🔄 Reliability

- ✅ Retry logic for transient failures
- ✅ Cross-platform testing (Ubuntu, Windows, macOS)
- ✅ Fail-fast disabled for complete feedback
- ✅ Comprehensive error reporting

### 🛠️ Maintainability

- ✅ Reusable workflow patterns
- ✅ Configurable inputs
- ✅ Detailed workflow summaries
- ✅ Semantic commit messages

---

## 🔧 Troubleshooting

### Common Issues

| Issue                     | Solution                                     |
| :------------------------ | :------------------------------------------- |
| OIDC auth fails           | Verify federated credential configuration    |
| Tests fail on specific OS | Check platform-specific code paths           |
| Format check fails        | Run `dotnet format` locally                  |
| CodeQL timeout            | Review query configuration and codebase size |
| Deployment fails          | Check Azure portal for resource status       |

### Getting Help

1. Check individual workflow documentation for detailed troubleshooting
2. Review workflow logs in GitHub Actions
3. Check Azure portal for deployment status
4. Open an issue in the repository

---

## 📚 Related Documentation

- [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [.NET CLI](https://learn.microsoft.com/dotnet/core/tools/)
- [CodeQL](https://codeql.github.com/docs/)

---

[⬆️ Back to Top](#-devops-documentation)

---

<div align="center">

**[CI Workflow →](ci-dotnet.md)**

</div>
