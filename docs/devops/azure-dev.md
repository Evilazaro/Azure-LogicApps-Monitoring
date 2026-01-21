# 🚀 CD - Azure Deployment Workflow

> Continuous delivery pipeline that provisions Azure infrastructure and deploys the .NET application using Azure Developer CLI (azd) with OpenID Connect (OIDC) authentication.

---

## 📑 Table of Contents

- [🚀 CD - Azure Deployment Workflow](#-cd---azure-deployment-workflow)
  - [📑 Table of Contents](#-table-of-contents)
  - [📖 Overview](#-overview)
  - [📊 Pipeline Visualization](#-pipeline-visualization)
  - [🎯 Triggers](#-triggers)
  - [📋 Jobs](#-jobs)
  - [⚙️ Prerequisites](#️-prerequisites)
  - [🌐 Environment Variables](#-environment-variables)
  - [🔄 Concurrency](#-concurrency)
  - [💡 Usage Examples](#-usage-examples)
  - [🔧 Troubleshooting](#-troubleshooting)
  - [📚 Related Documentation](#-related-documentation)

---

## 📖 Overview

The **CD - Azure Deployment** workflow (`azure-dev.yml`) is the continuous delivery pipeline that provisions Azure infrastructure and deploys the .NET application using Azure Developer CLI (azd) with OpenID Connect (OIDC) authentication.

This workflow implements a comprehensive deployment pipeline with integrated CI validation, infrastructure provisioning, SQL Managed Identity configuration, and application deployment to Azure Container Apps.

## Pipeline Visualization

```mermaid
flowchart TD
    subgraph Triggers["🎯 Triggers"]
        T1([workflow_dispatch])
        T2([push to docs987678])
    end

    subgraph CI["🔄 CI Stage"]
        CI_JOB[[ci-dotnet-reusable.yml]]
        CI_BUILD[🔨 Build]
        CI_TEST[🧪 Test]
        CI_ANALYZE[🔍 Analyze]
        CI_CODEQL[🛡️ CodeQL]
    end

    subgraph Deploy["🚀 Deploy Dev Stage"]
        direction TB
        D1[📥 Checkout]
        D2[📦 Install Prerequisites]
        D3[🔧 Install azd CLI]
        D4[🔧 Setup .NET SDK]
        D5[🔐 Azure Auth - OIDC]
        D6[🏗️ Provision Infrastructure]
        D7[🔐 Refresh Credentials Pre-SQL]
        D8[🔑 Create SQL User]
        D9[🔐 Refresh Credentials Post-SQL]
        D10[🚀 Deploy Application]
        D11[📊 Generate Summary]
    end

    subgraph Summary["📊 Summary Stage"]
        SUM[📊 Workflow Summary]
    end

    subgraph Failure["❌ Failure Handling"]
        FAIL[❌ Handle Failure]
    end

    %% Trigger flows
    T1 --> CI_JOB
    T2 --> CI_JOB

    %% CI internal flow
    CI_JOB --> CI_BUILD
    CI_BUILD --> CI_TEST
    CI_BUILD --> CI_ANALYZE
    CI_BUILD --> CI_CODEQL

    %% CI to Deploy
    CI_JOB -->|success or skipped| D1

    %% Deploy internal flow
    D1 --> D2
    D2 --> D3
    D3 --> D4
    D4 --> D5
    D5 --> D6
    D6 --> D7
    D7 --> D8
    D8 --> D9
    D9 --> D10
    D10 --> D11

    %% Deploy to Summary
    D11 --> SUM

    %% Failure handling
    CI_JOB -.->|failure| FAIL
    D10 -.->|failure| FAIL

    %% Styling
    classDef trigger fill:#2196F3,stroke:#1565C0,color:#fff
    classDef reusable fill:#9C27B0,stroke:#6A1B9A,color:#fff
    classDef build fill:#FF9800,stroke:#EF6C00,color:#fff
    classDef test fill:#9C27B0,stroke:#6A1B9A,color:#fff
    classDef deploy fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef security fill:#607D8B,stroke:#455A64,color:#fff
    classDef summary fill:#00BCD4,stroke:#0097A7,color:#fff
    classDef failure fill:#F44336,stroke:#C62828,color:#fff

    class T1,T2 trigger
    class CI_JOB reusable
    class CI_BUILD build
    class CI_TEST,CI_ANALYZE test
    class CI_CODEQL security
    class D1,D2,D3,D4,D5,D6,D7,D8,D9,D10,D11 deploy
    class SUM summary
    class FAIL failure
```

## Triggers

| Trigger             | Condition                                                     | Description                   |
| ------------------- | ------------------------------------------------------------- | ----------------------------- |
| `workflow_dispatch` | Manual trigger with optional `skip-ci` input                  | Allows manual deployment runs |
| `push`              | Branch: `docs987678`                                          | Triggers on push to branch    |
| **Path Filters**    | `src/**`, `app.*/**`, `infra/**`, `azure.yaml`, workflow file | Only relevant file changes    |

### Manual Trigger Inputs

| Input     | Type    | Default | Description                       |
| --------- | ------- | ------- | --------------------------------- |
| `skip-ci` | boolean | `false` | Skip CI checks (use with caution) |

## Jobs

### 1. 🔄 CI (Reusable Workflow)

Calls the reusable CI workflow (`ci-dotnet-reusable.yml`) for build, test, and security analysis.

| Property      | Value                                        |
| ------------- | -------------------------------------------- |
| **Condition** | `github.event.inputs.skip-ci != 'true'`      |
| **Workflow**  | `./.github/workflows/ci-dotnet-reusable.yml` |

**Configuration passed:**

```yaml
configuration: "Release"
dotnet-version: "10.0.x"
solution-file: "app.sln"
enable-code-analysis: true
fail-on-format-issues: false
```

### 2. 🚀 Deploy Dev

Deploys the application to the development environment.

| Property        | Value                     |
| --------------- | ------------------------- |
| **Runner**      | `ubuntu-latest`           |
| **Timeout**     | 30 minutes                |
| **Depends On**  | `ci` (success or skipped) |
| **Environment** | `dev`                     |

#### Deployment Phases

```mermaid
flowchart LR
    subgraph Phase1["Phase 1: Setup"]
        P1A[Checkout]
        P1B[Install go-sqlcmd]
        P1C[Install azd CLI]
        P1D[Setup .NET SDK]
    end

    subgraph Phase2["Phase 2: Auth"]
        P2A[azd auth login]
        P2B[az login OIDC]
    end

    subgraph Phase3["Phase 3: Provision"]
        P3A[azd provision]
    end

    subgraph Phase4["Phase 4: SQL Config"]
        P4A[Refresh Credentials]
        P4B[Create SQL User]
    end

    subgraph Phase5["Phase 5: Deploy"]
        P5A[Refresh Credentials]
        P5B[azd deploy]
    end

    Phase1 --> Phase2
    Phase2 --> Phase3
    Phase3 --> Phase4
    Phase4 --> Phase5

    classDef setup fill:#2196F3,stroke:#1565C0,color:#fff
    classDef auth fill:#FFC107,stroke:#FFA000,color:#000
    classDef provision fill:#FF9800,stroke:#EF6C00,color:#fff
    classDef sql fill:#9C27B0,stroke:#6A1B9A,color:#fff
    classDef deploy fill:#4CAF50,stroke:#2E7D32,color:#fff

    class P1A,P1B,P1C,P1D setup
    class P2A,P2B auth
    class P3A provision
    class P4A,P4B sql
    class P5A,P5B deploy
```

#### Key Steps

| Step                           | Description                                                  |
| ------------------------------ | ------------------------------------------------------------ |
| 📥 Checkout repository         | Clone repository for deployment                              |
| 📦 Install Prerequisites       | Install jq, dos2unix, go-sqlcmd for SQL operations           |
| 🔧 Install Azure Developer CLI | Install latest azd CLI                                       |
| 🔧 Setup .NET SDK              | Install .NET 10.0.x SDK                                      |
| 🔐 Azure Auth (OIDC)           | Authenticate using federated credentials                     |
| 🏗️ Provision Infrastructure    | Run `azd provision` with retry logic (3 attempts)            |
| 🔐 Refresh Credentials         | Re-authenticate before SQL operations (OIDC token refresh)   |
| 🔑 Create SQL User             | Create managed identity user in SQL database using go-sqlcmd |
| 🚀 Deploy Application          | Run `azd deploy` with retry logic (3 attempts)               |
| 📊 Generate Summary            | Create deployment summary in workflow output                 |

#### Outputs

| Output           | Description                         |
| ---------------- | ----------------------------------- |
| `webapp-url`     | URL of the deployed web application |
| `resource-group` | Name of the Azure resource group    |

### 3. 📊 Summary

Generates a comprehensive workflow summary report.

| Property       | Value              |
| -------------- | ------------------ |
| **Runner**     | `ubuntu-latest`    |
| **Timeout**    | 5 minutes          |
| **Depends On** | `ci`, `deploy-dev` |
| **Condition**  | `always()`         |

### 4. ❌ Handle Failure

Reports pipeline failures with actionable information.

| Property      | Value           |
| ------------- | --------------- |
| **Runner**    | `ubuntu-latest` |
| **Timeout**   | 5 minutes       |
| **Condition** | `failure()`     |

## Prerequisites

### Required Secrets/Variables

| Variable                  | Type     | Description                                  |
| ------------------------- | -------- | -------------------------------------------- |
| `AZURE_CLIENT_ID`         | Variable | Azure AD application (client) ID             |
| `AZURE_TENANT_ID`         | Variable | Azure AD tenant ID                           |
| `AZURE_SUBSCRIPTION_ID`   | Variable | Azure subscription ID                        |
| `AZURE_ENV_NAME`          | Variable | Azure environment name (default: `dev`)      |
| `AZURE_LOCATION`          | Variable | Azure region (default: `eastus2`)            |
| `DEPLOYER_PRINCIPAL_TYPE` | Variable | Principal type (default: `ServicePrincipal`) |
| `DEPLOY_HEALTH_MODEL`     | Variable | Enable health model deployment               |

### Required Permissions

```yaml
permissions:
  id-token: write # OIDC authentication with Azure
  contents: read # Read repository contents
  checks: write # Create check runs for test results
  pull-requests: write # Post comments on pull requests
  security-events: write # Upload CodeQL SARIF results
```

### GitHub Environment

The workflow requires a GitHub environment named `dev` with:

- Environment protection rules (optional)
- Environment-specific variables configured

### Azure Prerequisites

1. **Federated Credentials**: Configure OIDC federation in Azure Entra ID
2. **Service Principal**: Application with appropriate Azure RBAC roles
3. **Azure SQL**: Database with Entra ID authentication enabled

## Environment Variables

| Variable                            | Value    | Description                  |
| ----------------------------------- | -------- | ---------------------------- |
| `DOTNET_VERSION`                    | `10.0.x` | .NET SDK version             |
| `DOTNET_SKIP_FIRST_TIME_EXPERIENCE` | `true`   | Skip .NET welcome experience |
| `DOTNET_NOLOGO`                     | `true`   | Suppress .NET logo           |
| `DOTNET_CLI_TELEMETRY_OPTOUT`       | `true`   | Disable telemetry            |

## Concurrency

```yaml
concurrency:
  group: deploy-dev-${{ github.ref }}
  cancel-in-progress: false
```

Prevents simultaneous deployments to the same environment while ensuring in-progress deployments complete.

## Usage Examples

### Manual Deployment

```bash
# Trigger deployment with CI checks
gh workflow run azure-dev.yml

# Trigger deployment skipping CI (use with caution)
gh workflow run azure-dev.yml -f skip-ci=true
```

### Rollback Instructions

```bash
# Option 1: Re-run with previous commit
gh workflow run azure-dev.yml --ref <previous-commit-sha>

# Option 2: Use Azure Developer CLI locally
git checkout <previous-commit-sha>
azd deploy --no-prompt
```

## Troubleshooting

### Common Issues

| Issue                     | Cause                                 | Solution                                    |
| ------------------------- | ------------------------------------- | ------------------------------------------- |
| OIDC authentication fails | Federated credential misconfiguration | Verify Azure AD app registration settings   |
| SQL user creation fails   | Token expired during long operations  | Credentials are auto-refreshed; check logs  |
| Provisioning timeout      | Azure API throttling                  | Retry logic handles transient failures      |
| go-sqlcmd not found       | PATH conflict with ODBC sqlcmd        | Workflow removes ODBC version automatically |

### Debugging Steps

1. **Check Authentication**: Verify federated credentials in Azure portal
2. **Review Logs**: Expand collapsed log groups for detailed output
3. **Azure Portal**: Check resource group status and activity logs
4. **Re-run Workflow**: Use the "Re-run failed jobs" option

## Related Documentation

- [Azure Developer CLI Documentation](https://learn.microsoft.com/azure/developer/azure-developer-cli/)
- [GitHub Actions OIDC with Azure](https://learn.microsoft.com/azure/developer/github/connect-from-azure)
- [CI Workflow Documentation](ci-dotnet.md)
- [Reusable CI Workflow](ci-dotnet-reusable.md)
