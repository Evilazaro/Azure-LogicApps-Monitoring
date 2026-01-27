# GitHub Actions Workflows Documentation

This directory contains comprehensive documentation for all GitHub Actions workflows in this repository.

## 📋 Workflow Index

| Workflow | File | Purpose | Type |
|----------|------|---------|------|
| [CD - Azure Deployment](azure-dev.md) | `azure-dev.yml` | Provisions Azure infrastructure and deploys the application | Deployment |
| [CI - .NET Reusable Workflow](ci-dotnet-reusable.md) | `ci-dotnet-reusable.yml` | Cross-platform CI pipeline (build, test, analyze, security) | Reusable |
| [CI - .NET Build and Test](ci-dotnet.md) | `ci-dotnet.yml` | Orchestrates CI by calling the reusable workflow | CI Orchestrator |

## 🔄 Workflow Relationships

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '14px', 'primaryColor': '#E3F2FD', 'lineColor': '#90A4AE', 'textColor': '#37474F', 'clusterBkg': '#FAFAFA'}}}%%
flowchart LR
    subgraph workflows["🔄 Workflow Dependencies"]
        direction LR
        
        subgraph triggers["⚡ Triggers"]
            direction TB
            push(["🔔 push"]):::node-trigger
            pr(["🔔 pull_request"]):::node-trigger
            dispatch(["🔔 workflow_dispatch"]):::node-trigger
        end
        
        subgraph ci-workflows["🔨 CI Workflows"]
            direction TB
            ci-dotnet["📄 ci-dotnet.yml"]:::node-build
            ci-reusable[["📄 ci-dotnet-reusable.yml"]]:::node-build
        end
        
        subgraph cd-workflows["🚀 CD Workflows"]
            direction TB
            azure-dev["📄 azure-dev.yml"]:::node-staging
        end
    end
    
    %% Trigger connections
    push & pr & dispatch --> ci-dotnet
    push & dispatch --> azure-dev
    
    %% Workflow calls
    ci-dotnet -->|"uses"| ci-reusable
    azure-dev -->|"uses"| ci-reusable
    
    %% Style definitions
    style workflows fill:#FAFAFA,stroke:#90A4AE,stroke-width:2px,color:#37474F
    style triggers fill:#E8F5E9,stroke:#66BB6A,stroke-width:2px,color:#2E7D32
    style ci-workflows fill:#E3F2FD,stroke:#42A5F5,stroke-width:2px,color:#1565C0
    style cd-workflows fill:#FFF3E0,stroke:#FFA726,stroke-width:2px,color:#E65100
    
    %% Node class definitions
    classDef node-trigger fill:#E8F5E9,stroke:#66BB6A,stroke-width:2px,color:#2E7D32,font-weight:bold
    classDef node-build fill:#E3F2FD,stroke:#42A5F5,stroke-width:2px,color:#1565C0
    classDef node-staging fill:#FFF3E0,stroke:#FFA726,stroke-width:2px,color:#E65100
```

## 📊 CI/CD Pipeline Overview

### Continuous Integration (CI)

The CI pipeline is triggered on:

- **Push** to `main`, `feature/**`, `bugfix/**`, `hotfix/**`, `release/**`, `chore/**`, `docs/**`, `refactor/**`, `test/**` branches
- **Pull requests** targeting `main`
- **Manual dispatch** via GitHub UI or CLI

**Jobs executed:**

| Job | Description | Platforms |
|-----|-------------|-----------|
| 🔨 Build | Compiles .NET solution | Ubuntu, Windows, macOS |
| 🧪 Test | Runs tests with coverage | Ubuntu, Windows, macOS |
| 🔍 Analyze | Verifies code formatting | Ubuntu |
| 🛡️ CodeQL | Security vulnerability scanning | Ubuntu |

### Continuous Deployment (CD)

The CD pipeline is triggered on:

- **Push** to `docs987678` branch (with path filters)
- **Manual dispatch** via GitHub UI or CLI

**Jobs executed:**

| Job | Description | Environment |
|-----|-------------|-------------|
| 🔄 CI | Calls reusable CI workflow | Cross-platform |
| 🚀 Deploy Dev | Provisions infrastructure and deploys | Ubuntu → Azure |
| 📊 Summary | Generates deployment report | Ubuntu |

## 🔐 Security Features

| Feature | Description |
|---------|-------------|
| **OIDC Authentication** | Uses federated credentials (no stored secrets) |
| **CodeQL Scanning** | Security vulnerability detection in C# code |
| **Pinned Actions** | All actions use SHA-pinned versions |
| **Least Privilege** | Minimal permissions at workflow and job level |

## 📦 Artifacts Generated

| Artifact | Source | Description |
|----------|--------|-------------|
| `build-artifacts-{os}` | CI | Compiled binaries per platform |
| `test-results-{os}` | CI | Test results (.trx) per platform |
| `code-coverage-{os}` | CI | Cobertura coverage reports per platform |
| `codeql-sarif-results` | CI | Security scan results (SARIF) |

## 🚀 Quick Start

### Running CI Manually

```bash
# Run with default settings
gh workflow run ci-dotnet.yml

# Run with Debug configuration
gh workflow run ci-dotnet.yml -f configuration=Debug

# Run without code analysis
gh workflow run ci-dotnet.yml -f enable-code-analysis=false
```

### Running CD Manually

```bash
# Run deployment with CI checks
gh workflow run azure-dev.yml

# Run deployment skipping CI (use with caution)
gh workflow run azure-dev.yml -f skip-ci=true
```

## 📝 Prerequisites

### For CI Workflows

- .NET SDK 10.0.x (installed automatically)
- Repository access with appropriate permissions

### For CD Workflows

- Azure subscription with configured resources
- GitHub Environment: `dev`
- Repository variables:
  - `AZURE_CLIENT_ID`
  - `AZURE_TENANT_ID`
  - `AZURE_SUBSCRIPTION_ID`
- Federated credentials configured in Azure Entra ID

## 📖 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [CodeQL Documentation](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql)
- [.NET CLI Reference](https://learn.microsoft.com/en-us/dotnet/core/tools/)

---

*Documentation generated for workflows in `.github/workflows/`*
