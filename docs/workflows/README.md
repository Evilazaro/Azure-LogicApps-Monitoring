# GitHub Actions Workflows Documentation

This directory contains comprehensive documentation for all GitHub Actions workflows in this repository.

---

## Workflow Overview

```mermaid
%%{init: {'theme': 'dark', 'themeVariables': {'fontSize': '14px', 'primaryColor': '#1f6feb', 'lineColor': '#8b949e'}}}%%
flowchart LR
    subgraph workflows["🔄 GitHub Actions Workflows"]
        direction TB
        style workflows fill:#0d1117,stroke:#30363d,stroke-width:3px,color:#e6edf3
        
        subgraph ci-workflows["🔨 CI Workflows"]
            direction TB
            style ci-workflows fill:#1c2128,stroke:#79c0ff,stroke-width:2px,color:#79c0ff
            ci["CI - .NET Build and Test"]:::node-build
            ci-reusable["CI - .NET Reusable"]:::node-build
        end
        
        subgraph cd-workflows["🚀 CD Workflows"]
            direction TB
            style cd-workflows fill:#1c2128,stroke:#3fb950,stroke-width:2px,color:#3fb950
            cd["CD - Azure Deployment"]:::node-production
        end
    end
    
    ci -->|"calls"| ci-reusable
    ci-reusable -->|"feeds"| cd
    
    classDef node-build fill:#1f6feb,stroke:#58a6ff,stroke-width:2px,color:#ffffff
    classDef node-production fill:#238636,stroke:#3fb950,stroke-width:2px,color:#ffffff,font-weight:bold
    
    linkStyle default stroke:#8b949e,stroke-width:2px
```

---

## Workflows Index

| Workflow | File | Type | Description |
|----------|------|------|-------------|
| [**CI - .NET Build and Test**](ci-dotnet.md) | `ci-dotnet.yml` | Entry Point | Triggers CI pipeline on push/PR |
| [**CI - .NET Reusable**](ci-dotnet-reusable.md) | `ci-dotnet-reusable.yml` | Reusable | Cross-platform build, test, analyze, CodeQL |
| [**CD - Azure Deployment**](azure-dev.md) | `azure-dev.yml` | Deployment | Azure infrastructure provisioning and app deployment |

---

## Workflow Details

### 🔨 CI - .NET Build and Test

[![Workflow](https://img.shields.io/badge/workflow-ci--dotnet.yml-blue?style=flat-square)](../../.github/workflows/ci-dotnet.yml)
[![Documentation](https://img.shields.io/badge/docs-ci--dotnet.md-green?style=flat-square)](ci-dotnet.md)

**Purpose:** Entry point workflow that handles triggers and delegates to the reusable CI workflow.

| Property | Value |
|----------|-------|
| **Triggers** | `push`, `pull_request`, `workflow_dispatch` |
| **Branches** | `main`, `feature/**`, `bugfix/**`, `hotfix/**`, `release/**`, `chore/**`, `docs/**`, `refactor/**`, `test/**` |
| **Path Filters** | `src/**`, `app.*/**`, `*.sln`, `global.json` |

---

### 🔨 CI - .NET Reusable Workflow

[![Workflow](https://img.shields.io/badge/workflow-ci--dotnet--reusable.yml-blue?style=flat-square)](../../.github/workflows/ci-dotnet-reusable.yml)
[![Documentation](https://img.shields.io/badge/docs-ci--dotnet--reusable.md-green?style=flat-square)](ci-dotnet-reusable.md)

**Purpose:** Comprehensive reusable CI workflow providing cross-platform build, test, analysis, and security scanning.

| Property | Value |
|----------|-------|
| **Type** | Reusable (`workflow_call`) |
| **Platforms** | Ubuntu, Windows, macOS |
| **Features** | Build, Test, Code Analysis, CodeQL Security Scan |

#### Jobs Executed

| Job | Description |
|-----|-------------|
| 🔨 Build | Cross-platform compilation (matrix) |
| 🧪 Test | Cross-platform testing with coverage (matrix) |
| 🔍 Analyze | Code formatting verification |
| 🛡️ CodeQL | Security vulnerability scanning |
| 📊 Summary | Aggregated results report |

---

### 🚀 CD - Azure Deployment

[![Workflow](https://img.shields.io/badge/workflow-azure--dev.yml-blue?style=flat-square)](../../.github/workflows/azure-dev.yml)
[![Documentation](https://img.shields.io/badge/docs-azure--dev.md-green?style=flat-square)](azure-dev.md)

**Purpose:** Provisions Azure infrastructure and deploys the .NET application using Azure Developer CLI with OIDC authentication.

| Property | Value |
|----------|-------|
| **Triggers** | `push`, `workflow_dispatch` |
| **Environment** | `dev` |
| **Authentication** | OIDC Federated Credentials |

#### Deployment Phases

| Phase | Description |
|-------|-------------|
| 1. Setup | Install prerequisites (go-sqlcmd, .NET, azd) |
| 2. Auth | OIDC authentication with Azure |
| 3. Provision | Infrastructure provisioning via `azd provision` |
| 4. SQL Config | Create managed identity user in SQL database |
| 5. Deploy | Application deployment via `azd deploy` |
| 6. Summary | Generate deployment report |

---

## Pipeline Architecture

```mermaid
%%{init: {'theme': 'dark', 'themeVariables': {'fontSize': '14px', 'primaryColor': '#1f6feb', 'lineColor': '#8b949e'}}}%%
flowchart TB
    subgraph pipeline["🔄 Complete CI/CD Pipeline"]
        direction TB
        style pipeline fill:#0d1117,stroke:#30363d,stroke-width:3px,color:#e6edf3
        
        subgraph triggers["⚡ Triggers"]
            style triggers fill:#1c2128,stroke:#7ee787,stroke-width:2px,color:#7ee787
            push(["🔔 Push"]):::node-trigger
            pr(["🔔 Pull Request"]):::node-trigger
            manual(["🔔 Manual"]):::node-trigger
        end
        
        subgraph ci["🔨 CI Stage"]
            direction LR
            style ci fill:#1c2128,stroke:#79c0ff,stroke-width:2px,color:#79c0ff
            build["Build"]:::node-build
            test["Test"]:::node-test
            analyze["Analyze"]:::node-lint
            codeql["CodeQL"]:::node-security
        end
        
        subgraph cd["🚀 CD Stage"]
            direction LR
            style cd fill:#1c2128,stroke:#3fb950,stroke-width:2px,color:#3fb950
            provision["Provision"]:::node-build
            sql["SQL Config"]:::node-staging
            deploy["Deploy"]:::node-production
        end
    end
    
    push & pr & manual --> build
    build --> test & analyze & codeql
    test & analyze & codeql --> provision
    provision --> sql --> deploy
    
    classDef node-trigger fill:#238636,stroke:#2ea043,stroke-width:2px,color:#ffffff,font-weight:bold
    classDef node-build fill:#1f6feb,stroke:#58a6ff,stroke-width:2px,color:#ffffff
    classDef node-test fill:#8957e5,stroke:#a371f7,stroke-width:2px,color:#ffffff
    classDef node-lint fill:#a371f7,stroke:#d2a8ff,stroke-width:2px,color:#ffffff
    classDef node-security fill:#da3633,stroke:#f85149,stroke-width:2px,color:#ffffff
    classDef node-staging fill:#9e6a03,stroke:#d29922,stroke-width:2px,color:#ffffff
    classDef node-production fill:#238636,stroke:#3fb950,stroke-width:2px,color:#ffffff,font-weight:bold
    
    linkStyle default stroke:#8b949e,stroke-width:2px
```

---

## Artifacts Summary

All workflows produce the following artifacts:

### CI Artifacts

| Artifact | Description | Retention |
|----------|-------------|-----------|
| `build-artifacts-{os}` | Compiled binaries per platform | 30 days |
| `test-results-{os}` | Test results (.trx) per platform | 30 days |
| `code-coverage-{os}` | Coverage reports (Cobertura) per platform | 30 days |
| `codeql-sarif-results` | Security scan results (SARIF) | 30 days |

### CD Outputs

| Output | Description |
|--------|-------------|
| `webapp-url` | Deployed application URL |
| `resource-group` | Azure resource group name |

---

## Required Permissions

### CI Workflows

| Permission | Level | Purpose |
|------------|-------|---------|
| `contents` | `read` | Repository checkout |
| `checks` | `write` | Test result check runs |
| `pull-requests` | `write` | PR comments |
| `security-events` | `write` | CodeQL SARIF upload |

### CD Workflows

| Permission | Level | Purpose |
|------------|-------|---------|
| `id-token` | `write` | OIDC authentication |
| `contents` | `read` | Repository checkout |
| `checks` | `write` | Test result check runs |
| `pull-requests` | `write` | PR comments |
| `security-events` | `write` | CodeQL SARIF upload |

---

## Required Repository Configuration

### Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_CLIENT_ID` | Yes | Azure Service Principal Client ID |
| `AZURE_TENANT_ID` | Yes | Azure AD Tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Yes | Azure Subscription ID |
| `AZURE_ENV_NAME` | No | Environment name (default: `dev`) |
| `AZURE_LOCATION` | No | Azure region (default: `eastus2`) |

### Environments

| Environment | Purpose | Protection Rules |
|-------------|---------|------------------|
| `dev` | Development deployment | Optional |

---

## Quick Reference

### Manual Workflow Triggers

```bash
# Run CI workflow
gh workflow run ci-dotnet.yml

# Run CI with Debug configuration
gh workflow run ci-dotnet.yml -f configuration=Debug

# Run CD workflow
gh workflow run azure-dev.yml

# Run CD skipping CI
gh workflow run azure-dev.yml -f skip-ci=true
```

### View Workflow Status

```bash
# List recent workflow runs
gh run list

# View specific run
gh run view <run-id>

# Watch running workflow
gh run watch <run-id>
```

---

## External Dependencies

### Actions Used

| Action | Version | Purpose |
|--------|---------|---------|
| `actions/checkout` | v6.0.2 | Repository checkout |
| `actions/setup-dotnet` | v5.1.0 | .NET SDK setup |
| `actions/upload-artifact` | v6.0.0 | Artifact upload |
| `dorny/test-reporter` | v2.5.0 | Test result publishing |
| `github/codeql-action/*` | v3.28.0 | Security scanning |
| `Azure/setup-azd` | v2.2.1 | Azure Developer CLI |
| `azure/login` | v2.4.0 | Azure CLI authentication |

---

## Related Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [.NET CLI Reference](https://learn.microsoft.com/en-us/dotnet/core/tools/)
- [CodeQL Documentation](https://docs.github.com/en/code-security/code-scanning)
