---
title: Deployment Architecture
description: Infrastructure as Code, CI/CD, and environment management for the Azure Logic Apps Monitoring solution
author: Evilazaro
version: 1.0
tags: [architecture, deployment, ci-cd, bicep, azd, github-actions]
---

# 🚀 Deployment Architecture

> [!NOTE]
> 🎯 **For DevOps and Platform Engineers**: This document covers CI/CD, environments, and Infrastructure as Code.  
> ⏱️ **Estimated reading time:** 20 minutes

<details>
<summary>📍 <strong>Quick Navigation</strong></summary>

| Previous                                               |         Index         |                    Next |
| :----------------------------------------------------- | :-------------------: | ----------------------: |
| [← Security Architecture](06-security-architecture.md) | [📑 Index](README.md) | [ADRs →](adr/README.md) |

</details>

---

## 📑 Table of Contents

- [📋 Deployment Overview](#-1-deployment-overview)
- [📁 Infrastructure as Code](#-2-infrastructure-as-code)
- [⚙️ Azure Developer CLI (azd)](#%EF%B8%8F-3-azure-developer-cli-azd)
- [🚀 CI/CD Pipeline](#-4-cicd-pipeline)
- [🔐 Workload Identity Federation](#-5-workload-identity-federation)
- [💻 Local Development](#-6-local-development)

---

## 📋 1. Deployment Overview

### Deployment Strategy

| Aspect             | Approach                     | Rationale                                  |
| ------------------ | ---------------------------- | ------------------------------------------ |
| **Methodology**    | Infrastructure as Code (IaC) | Repeatable, version-controlled deployments |
| **IaC Language**   | Azure Bicep                  | Native Azure support, type safety          |
| **Orchestration**  | Azure Developer CLI (azd)    | Unified developer experience               |
| **CI/CD**          | GitHub Actions               | Native GitHub integration                  |
| **Authentication** | Workload Identity Federation | Zero secrets in pipelines                  |

### Environment Model

> 📖 **See also:** [DevOps Documentation](../devops/README.md) for detailed pipeline configuration and secrets management.

```mermaid
---
title: Environment Model - Promotion Flow
---
flowchart LR
    %% ===== CLASS DEFINITIONS =====
    %% Primary components: Indigo - main processes/services
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    %% Secondary components: Emerald - secondary elements
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    %% Data stores: Amber - environments/reporting
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    %% External systems: Gray - external calls
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    %% Triggers: Indigo light - entry points
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF

    %% ===== DEVELOPMENT ENVIRONMENT =====
    subgraph Dev["🔧 Development"]
        Local["Local<br/>.NET Aspire"]
        DevEnv["Dev Environment<br/>Azure"]
    end
    style Dev fill:#ECFDF5,stroke:#10B981,stroke-width:2px

    %% ===== STAGING ENVIRONMENT =====
    subgraph Stage["🧪 Staging"]
        StageEnv["Staging<br/>Azure"]
    end
    style Stage fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== PRODUCTION ENVIRONMENT =====
    subgraph Prod["🚀 Production"]
        ProdEnv["Production<br/>Azure"]
    end
    style Prod fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== PROMOTION FLOW =====
    Local -->|"Deploy locally"| DevEnv
    DevEnv -->|"Promote to staging"| StageEnv
    StageEnv -->|"Approval required"| ProdEnv

    %% ===== APPLY STYLES =====
    class Local trigger
    class DevEnv primary
    class StageEnv datastore
    class ProdEnv secondary
```

---

## 📁 2. Infrastructure as Code

### Bicep Module Structure

```
infra/
├── main.bicep                    # Subscription-scoped orchestrator
├── main.parameters.json          # Parameter file
├── types.bicep                   # Shared type definitions
├── shared/
│   ├── main.bicep               # Shared resources module
│   ├── identity/                 # Managed Identity
│   ├── monitoring/               # App Insights, Log Analytics
│   ├── network/                  # VNet, subnets, NSGs
│   └── data/                     # SQL Server, databases
└── workload/
    ├── main.bicep               # Workload resources module
    ├── messaging/                # Service Bus
    ├── services/                 # Container Apps
    └── logic-app.bicep          # Logic Apps
```

### Module Relationships

```mermaid
---
title: Bicep Module Relationships
---
flowchart TB
    %% ===== CLASS DEFINITIONS =====
    %% Primary components: Indigo - main processes/services
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    %% Secondary components: Emerald - secondary elements
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    %% Data stores: Amber - artifacts/outputs
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    %% External systems: Gray - external calls
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    %% Triggers: Indigo light - entry points
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF

    %% ===== SUBSCRIPTION SCOPE =====
    subgraph Subscription["📦 Subscription Scope"]
        Main["main.bicep"]
    end
    style Subscription fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px

    %% ===== RESOURCE GROUP SCOPE =====
    subgraph RG["📁 Resource Group"]
        Shared["shared/main.bicep"]
        Workload["workload/main.bicep"]
    end
    style RG fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== SHARED MODULES =====
    subgraph SharedModules["🔧 Shared Modules"]
        Identity["identity/"]
        Monitoring["monitoring/"]
        Network["network/"]
        Data["data/"]
    end
    style SharedModules fill:#ECFDF5,stroke:#10B981,stroke-width:2px

    %% ===== WORKLOAD MODULES =====
    subgraph WorkloadModules["⚙️ Workload Modules"]
        Messaging["messaging/"]
        Services["services/"]
        LogicApp["logic-app.bicep"]
    end
    style WorkloadModules fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== MODULE DEPENDENCIES =====
    Main -->|"deploys"| Shared
    Main -->|"deploys"| Workload
    Shared -->|"includes"| Identity
    Shared -->|"includes"| Monitoring
    Shared -->|"includes"| Network
    Shared -->|"includes"| Data
    Workload -->|"includes"| Messaging
    Workload -->|"includes"| Services
    Workload -->|"includes"| LogicApp
    Workload -.->|"references outputs"| Shared

    %% ===== APPLY STYLES =====
    class Main primary
    class Shared,Workload trigger
    class Identity,Monitoring,Network,Data secondary
    class Messaging,Services,LogicApp datastore
```

### Key Bicep Patterns

| Pattern                   | Implementation       | Purpose                   |
| ------------------------- | -------------------- | ------------------------- |
| **Modular Design**        | Nested modules       | Reusability, separation   |
| **Parameter Files**       | main.parameters.json | Environment configuration |
| **Type Safety**           | types.bicep          | Shared type definitions   |
| **Output Chaining**       | Module outputs       | Cross-module references   |
| **Conditional Resources** | `if` expressions     | Feature toggles           |

---

## ⚙️ 3. Azure Developer CLI (azd)

### azd Workflow

```mermaid
---
title: Azure Developer CLI Workflow
---
flowchart TB
    %% ===== CLASS DEFINITIONS =====
    %% Primary components: Indigo - main processes/services
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    %% Secondary components: Emerald - secondary elements
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    %% Data stores: Amber - artifacts/outputs
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    %% Triggers: Indigo light - entry points/hooks
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF

    %% ===== INITIALIZE STAGE =====
    subgraph Init["🔧 Initialize"]
        Init1["azd init"]
        Init2["Select template"]
    end
    style Init fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== PROVISION STAGE =====
    subgraph Provision["☁️ Provision"]
        Prov1["azd provision"]
        Prov2["Deploy Bicep"]
        Prov3["Create resources"]
    end
    style Provision fill:#ECFDF5,stroke:#10B981,stroke-width:2px

    %% ===== DEPLOY STAGE =====
    subgraph Deploy["🚀 Deploy"]
        Deploy1["azd deploy"]
        Deploy2["Build apps"]
        Deploy3["Push to Azure"]
    end
    style Deploy fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== LIFECYCLE HOOKS =====
    subgraph Hooks["🪝 Lifecycle Hooks"]
        PreProv["preprovision"]
        PostProv["postprovision"]
        PreDeploy["predeploy"]
        PostDeploy["postdeploy"]
    end
    style Hooks fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px

    %% ===== WORKFLOW CONNECTIONS =====
    Init1 -->|"start"| Init2
    Init2 -->|"triggers hook"| PreProv
    PreProv -->|"validates"| Prov1
    Prov1 -->|"executes"| Prov2
    Prov2 -->|"creates"| Prov3
    Prov3 -->|"triggers hook"| PostProv
    PostProv -->|"triggers hook"| PreDeploy
    PreDeploy -->|"starts"| Deploy1
    Deploy1 -->|"compiles"| Deploy2
    Deploy2 -->|"uploads"| Deploy3
    Deploy3 -->|"triggers hook"| PostDeploy

    %% ===== APPLY STYLES =====
    class Init1,Init2 primary
    class Prov1,Prov2,Prov3 secondary
    class Deploy1,Deploy2,Deploy3 datastore
    class PreProv,PostProv,PreDeploy,PostDeploy trigger
```

### azure.yaml Configuration

```yaml
# azure.yaml - Azure Developer CLI configuration
name: eShop-Orders
metadata:
  template: azd-init
services:
  orders-api:
    project: ./src/eShop.Orders.API
    language: csharp
    host: containerapp
  web-app:
    project: ./src/eShop.Web.App
    language: csharp
    host: containerapp
hooks:
  preprovision:
    posix:
      shell: sh
      run: ./hooks/preprovision.sh
    windows:
      shell: pwsh
      run: ./hooks/preprovision.ps1
  postprovision:
    posix:
      shell: sh
      run: ./hooks/postprovision.sh
    windows:
      shell: pwsh
      run: ./hooks/postprovision.ps1
```

### Lifecycle Hooks

| Hook                | Script                                                 | Purpose                                        |
| ------------------- | ------------------------------------------------------ | ---------------------------------------------- |
| **preprovision**    | [preprovision.ps1](../../hooks/preprovision.ps1)       | Validate prerequisites, check workstation      |
| **postprovision**   | [postprovision.ps1](../../hooks/postprovision.ps1)     | Configure SQL Managed Identity, run migrations |
| **postinfradelete** | [postinfradelete.ps1](../../hooks/postinfradelete.ps1) | Clean up after infrastructure deletion         |

---

## 🚀 4. CI/CD Pipeline

> 📖 **See also:** [DevOps Documentation](../devops/README.md) for detailed workflow documentation and configuration.

### Pipeline Architecture

```mermaid
---
title: CI/CD Pipeline Architecture
---
flowchart TB
    %% ===== CLASS DEFINITIONS =====
    %% Primary components: Indigo - main processes/services
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    %% Secondary components: Emerald - secondary elements
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    %% Data stores: Amber - reporting/environments
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    %% External systems: Gray - reusable/external calls
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    %% Error/failure states: Red - error handling
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    %% Triggers: Indigo light - entry points
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    %% Matrix: Light indigo - parallel execution
    classDef matrix fill:#E0E7FF,stroke:#4F46E5,color:#000000

    %% ===== TRIGGER SOURCES =====
    subgraph TriggerGroup["🎯 Triggers"]
        Push(["Push to main"])
        PR(["Pull Request"])
        Manual(["Manual dispatch"])
    end
    style TriggerGroup fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== EXTERNAL SERVICES =====
    subgraph ExternalGroup["🔧 External Services"]
        Dependabot["Dependabot<br/>(Config-based)"]
    end
    style ExternalGroup fill:#F3F4F6,stroke:#6B7280,stroke-width:2px

    %% ===== CI PIPELINE =====
    subgraph CI["🔄 CI Pipeline (Reusable Workflow)"]
        direction TB
        subgraph BuildMatrix["Build (Cross-Platform Matrix)"]
            BuildLinux["🐧 ubuntu-latest"]
            BuildWindows["🪟 windows-latest"]
            BuildMac["🍎 macos-latest"]
        end
        subgraph TestMatrix["Test (Cross-Platform Matrix)"]
            TestLinux["🐧 ubuntu-latest"]
            TestWindows["🪟 windows-latest"]
            TestMac["🍎 macos-latest"]
        end
        Analyze["📊 Code Analysis"]
    end
    style CI fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style BuildMatrix fill:#E0E7FF,stroke:#818CF8,stroke-width:1px
    style TestMatrix fill:#E0E7FF,stroke:#818CF8,stroke-width:1px

    %% ===== CD PIPELINE =====
    subgraph CD["🚀 CD Pipeline"]
        Login["Azure Login<br/>(OIDC)"]
        Provision["azd provision"]
        Deploy["azd deploy"]
    end
    style CD fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== AZURE ENVIRONMENTS =====
    subgraph Azure["☁️ Azure Environments"]
        Dev["Dev Environment"]
        Staging["Staging Environment"]
        Prod["Production Environment"]
    end
    style Azure fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== RESULTS =====
    subgraph ResultsGroup["📊 Results"]
        Summary(["Summary"])
        FailureHandler(["Handle Failure"])
    end
    style ResultsGroup fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== TRIGGER CONNECTIONS =====
    Push -->|"triggers CI"| CI
    Push -->|"triggers CD"| CD
    PR -->|"triggers CI"| CI
    Manual -->|"triggers CI"| CI
    Manual -->|"triggers CD"| CD

    %% ===== DEPENDABOT FLOW =====
    Dependabot -.->|"creates PRs"| PR

    %% ===== CI FLOW =====
    BuildMatrix -->|"parallel builds"| TestMatrix
    TestMatrix -->|"tests complete"| Analyze
    Analyze -->|"reports to"| Summary

    %% ===== CD FLOW =====
    CI -->|"on success"| CD
    Login -->|"authenticates"| Provision
    Provision -->|"creates infra"| Deploy
    Deploy -->|"deploys to"| Dev
    Deploy -->|"reports to"| Summary
    Dev -->|"promotes to"| Staging
    Staging -->|"approval gates"| Prod

    %% ===== FAILURE PATHS =====
    TestMatrix --x|"on failure"| FailureHandler
    Analyze --x|"on failure"| FailureHandler
    Deploy --x|"on failure"| FailureHandler

    %% ===== APPLY STYLES =====
    class Push,PR,Manual trigger
    class BuildLinux,BuildWindows,BuildMac,TestLinux,TestWindows,TestMac primary
    class Analyze secondary
    class Login,Provision,Deploy secondary
    class Dev,Staging,Prod datastore
    class Dependabot external
    class FailureHandler failed
    class Summary datastore
```

### GitHub Actions Workflows

| Workflow           | File                                                                     | Trigger           | Purpose                                 |
| ------------------ | ------------------------------------------------------------------------ | ----------------- | --------------------------------------- |
| **CI**             | [ci-dotnet.yml](../../.github/workflows/ci-dotnet.yml)                   | Push, PR          | Orchestrates CI via reusable workflow   |
| **CI Reusable**    | [ci-dotnet-reusable.yml](../../.github/workflows/ci-dotnet-reusable.yml) | Called by CI      | Build, test, analyze (cross-platform)   |
| **Azure Dev (CD)** | [azure-dev.yml](../../.github/workflows/azure-dev.yml)                   | Manual, CD events | Full deployment to Azure                |
| **Dependabot**     | [dependabot.yml](../../.github/dependabot.yml)                           | Automated         | Dependency updates (NuGet, npm, Docker) |

### Cross-Platform Matrix Strategy

The CI pipeline **always** runs on multiple operating systems to ensure consistent behavior across platforms:

| Platform    | Runner         | Purpose                        |
| ----------- | -------------- | ------------------------------ |
| **Linux**   | ubuntu-latest  | Primary build/test environment |
| **Windows** | windows-latest | Windows compatibility testing  |
| **macOS**   | macos-latest   | macOS compatibility testing    |

### Artifact Naming Convention

To avoid conflicts when multiple matrix jobs run in parallel, artifacts use platform-specific naming:

| Artifact Type       | Naming Pattern         | Example                         |
| ------------------- | ---------------------- | ------------------------------- |
| **Build Artifacts** | `build-artifacts-{os}` | `build-artifacts-ubuntu-latest` |
| **Test Results**    | `test-results-{os}`    | `test-results-windows-latest`   |
| **Code Coverage**   | `code-coverage-{os}`   | `code-coverage-macos-latest`    |

This ensures each platform's artifacts are stored separately, enabling:

- **Independent downloads** per platform
- **Platform-specific debugging** when issues occur
- **No 409 Conflict errors** from duplicate artifact names

### CI Workflow Steps

```yaml
# .github/workflows/ci-dotnet-reusable.yml (simplified)
name: CI (.NET) - Reusable

on:
  workflow_call:
    inputs:
      dotnet-version:
        type: string
        default: "10.0.x"

jobs:
  build:
    # Cross-platform matrix: always runs on all platforms
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ inputs.dotnet-version }}
      - run: dotnet restore
      - run: dotnet build --no-restore
      - name: Upload Build Artifacts
        uses: actions/upload-artifact@v4
        with:
          # Artifacts named with OS suffix to avoid conflicts
          name: build-artifacts-${{ matrix.os }}
          path: "**/bin/**"

  test:
    needs: build
    # Cross-platform matrix: always runs on all platforms
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: ${{ inputs.dotnet-version }}
      - run: dotnet test --collect:"XPlat Code Coverage"
      - name: Upload Test Results
        uses: actions/upload-artifact@v4
        with:
          # Artifacts named with OS suffix to avoid conflicts
          name: test-results-${{ matrix.os }}
          path: "**/TestResults/**"
```

### Azure Dev Workflow Steps

```yaml
# .github/workflows/azure-dev.yml (simplified)
name: Azure Developer CLI (CD)

on:
  workflow_dispatch:
    inputs:
      environment:
        description: "Environment to deploy"
        required: true
        default: "dev"
        type: choice
        options:
          - dev
          - staging
          - production
  push:
    branches: [main]

permissions:
  id-token: write
  contents: read
  checks: write
  pull-requests: write
  security-events: write # Required for CodeQL SARIF upload

jobs:
  # First run CI via reusable workflow
  ci:
    name: CI
    uses: ./.github/workflows/ci-dotnet-reusable.yml
    permissions:
      contents: read
      checks: write
      pull-requests: write
      security-events: write # Required for CodeQL
    with:
      dotnet-version: "10.0.x"

  # Then deploy to Azure
  deploy:
    needs: ci
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment || 'dev' }}
    steps:
      - uses: actions/checkout@v4
      - name: Azure Login (OIDC)
        uses: azure/login@v2
        with:
          client-id: ${{ vars.AZURE_CLIENT_ID }}
          tenant-id: ${{ vars.AZURE_TENANT_ID }}
          subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
      - name: Install Azure Developer CLI
        uses: Azure/setup-azd@v2
      - run: azd provision --no-prompt
      - run: azd deploy --no-prompt
```

---

## 🔐 5. Workload Identity Federation

### OIDC Authentication Flow

```mermaid
---
title: OIDC Authentication Flow
---
sequenceDiagram
    %% ===== WORKLOAD IDENTITY FEDERATION =====
    %% OIDC authentication flow for GitHub Actions
    autonumber

    %% ===== PARTICIPANTS =====
    participant GH as GitHub Actions
    participant Entra as Microsoft Entra ID
    participant Azure as Azure Resources

    %% ===== TOKEN GENERATION =====
    GH->>GH: Generate OIDC token

    %% ===== TOKEN VALIDATION =====
    GH->>Entra: Present OIDC token for validation
    Entra->>Entra: Validate issuer, subject, audience
    Entra-->>GH: Return Azure access token

    %% ===== DEPLOYMENT =====
    GH->>Azure: Deploy with access token
    Azure-->>GH: Return deployment result
```

### Federated Credential Configuration

| Setting      | Value                                         | Purpose              |
| ------------ | --------------------------------------------- | -------------------- |
| **Issuer**   | `https://token.actions.githubusercontent.com` | GitHub OIDC provider |
| **Subject**  | `repo:{org}/{repo}:ref:refs/heads/main`       | Branch binding       |
| **Audience** | `api://AzureADTokenExchange`                  | Azure token exchange |

### Setup Script

```powershell
# hooks/configure-federated-credential.ps1
$appId = az ad app list --display-name "github-actions-$env:AZURE_ENV_NAME" --query "[0].appId" -o tsv

az ad app federated-credential create `
  --id $appId `
  --parameters @{
    name = "github-main"
    issuer = "https://token.actions.githubusercontent.com"
    subject = "repo:$($env:GITHUB_REPOSITORY):ref:refs/heads/main"
    audiences = @("api://AzureADTokenExchange")
  }
```

---

## 💻 6. Local Development

### Prerequisites

| Tool                    | Version | Purpose                    |
| ----------------------- | ------- | -------------------------- |
| **.NET SDK**            | 10.0+   | Build and run applications |
| **Azure CLI**           | 2.60+   | Azure authentication       |
| **Azure Developer CLI** | 1.11.0+ | Deployment orchestration   |
| **Docker Desktop**      | Latest  | Container runtime          |
| **Visual Studio Code**  | Latest  | Development IDE            |

### Development Workflow

```mermaid
---
title: Local Development Workflow
---
flowchart LR
    %% ===== CLASS DEFINITIONS =====
    %% Primary components: Indigo - main processes/services
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    %% Secondary components: Emerald - secondary elements
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    %% Data stores: Amber - authentication/config
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000

    %% ===== SETUP STAGE =====
    subgraph Setup["🔧 Setup"]
        Clone["git clone"]
        Deps["dotnet restore"]
    end
    style Setup fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== AUTHENTICATION STAGE =====
    subgraph Auth["🔐 Authentication"]
        Login["az login"]
        Select["az account set"]
    end
    style Auth fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px

    %% ===== RUN STAGE =====
    subgraph Run["▶️ Run"]
        Aspire["dotnet run<br/>(AppHost)"]
        Dashboard["Aspire Dashboard<br/>localhost:15217"]
    end
    style Run fill:#ECFDF5,stroke:#10B981,stroke-width:2px

    %% ===== WORKFLOW CONNECTIONS =====
    Clone -->|"downloads repo"| Deps
    Deps -->|"restores packages"| Login
    Login -->|"authenticates"| Select
    Select -->|"sets subscription"| Aspire
    Aspire -->|"starts app"| Dashboard

    %% ===== APPLY STYLES =====
    class Clone,Deps primary
    class Login,Select datastore
    class Aspire,Dashboard secondary
```

### Check Workstation Script

```powershell
# hooks/check-dev-workstation.ps1
$requiredTools = @(
    @{ Name = "dotnet"; MinVersion = "10.0.0" },
    @{ Name = "az"; MinVersion = "2.60.0" },
    @{ Name = "azd"; MinVersion = "1.11.0" },
    @{ Name = "docker"; MinVersion = "24.0.0" }
)

foreach ($tool in $requiredTools) {
    $version = & $tool.Name --version 2>$null
    if (-not $version) {
        Write-Error "$($tool.Name) not found"
    }
}
```

---

## 7. Release Strategy

### Release Flow

| Stage          | Trigger         | Approval  | Actions                   |
| -------------- | --------------- | --------- | ------------------------- |
| **Dev**        | Push to main    | Automatic | Build, test, deploy       |
| **Staging**    | Dev success     | Manual    | Integration tests, deploy |
| **Production** | Staging success | Required  | Deploy, smoke tests       |

### Rollback Procedures

| Scenario                 | Procedure                                   |
| ------------------------ | ------------------------------------------- |
| **Application Issue**    | `azd deploy` previous version               |
| **Infrastructure Issue** | `azd provision` with previous parameters    |
| **Data Issue**           | Restore from Azure SQL backup               |
| **Complete Rollback**    | `azd down` + `azd up` from known-good state |

---

## 8. Deployment Checklist

### Pre-Deployment

- [ ] All tests passing in CI
- [ ] Code review approved
- [ ] Infrastructure changes reviewed
- [ ] Secrets and variables configured
- [ ] Feature flags set appropriately

### Post-Deployment

- [ ] Health checks passing
- [ ] Smoke tests completed
- [ ] Application Insights showing telemetry
- [ ] No new errors in logs
- [ ] Performance baselines verified

---

## Cross-Architecture Relationships

| Related Architecture           | Connection              | Reference                                                      |
| ------------------------------ | ----------------------- | -------------------------------------------------------------- |
| **Technology Architecture**    | Infrastructure platform | [Technology Architecture](04-technology-architecture.md)       |
| **Security Architecture**      | OIDC, secret management | [Security Architecture](06-security-architecture.md)           |
| **Observability Architecture** | Deployment monitoring   | [Observability Architecture](05-observability-architecture.md) |

---

[← Security Architecture](06-security-architecture.md) | [Index](README.md) | [ADRs →](adr/README.md)
