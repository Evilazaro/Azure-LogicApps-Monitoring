# CI - .NET Build and Test Workflow

[![Workflow Status](https://img.shields.io/badge/workflow-ci--dotnet.yml-blue?style=flat-square)](../../.github/workflows/ci-dotnet.yml)

## Overview

| Property | Value |
|----------|-------|
| **Workflow Name** | `CI - .NET Build and Test` |
| **File** | [`.github/workflows/ci-dotnet.yml`](../../.github/workflows/ci-dotnet.yml) |
| **Purpose** | Orchestrates the CI pipeline by calling the reusable workflow |

### Description

This workflow serves as the entry point for the CI pipeline, handling:

- Trigger configuration for push and pull request events
- Path filters for relevant source changes
- Manual workflow dispatch with configurable options
- Delegation to the comprehensive reusable CI workflow

---

## Trigger Events

### `push`

| Property | Value |
|----------|-------|
| **Branches** | `main`, `feature/**`, `bugfix/**`, `hotfix/**`, `release/**`, `chore/**`, `docs/**`, `refactor/**`, `test/**` |
| **Paths** | `src/**`, `app.*/**`, `*.sln`, `global.json`, `.github/workflows/ci-dotnet.yml`, `.github/workflows/ci-dotnet-reusable.yml` |

### `pull_request`

| Property | Value |
|----------|-------|
| **Branches** | `main` |
| **Paths** | `src/**`, `app.*/**`, `*.sln`, `global.json`, `.github/workflows/ci-dotnet.yml`, `.github/workflows/ci-dotnet-reusable.yml` |

### `workflow_dispatch` (Manual Trigger)

| Input | Type | Required | Default | Options | Description |
|-------|------|----------|---------|---------|-------------|
| `configuration` | `choice` | No | `Release` | `Release`, `Debug` | Build configuration |
| `enable-code-analysis` | `boolean` | No | `true` | - | Enable code formatting analysis |

---

## Workflow Diagram

```mermaid
%%{init: {'theme': 'dark', 'themeVariables': {'fontSize': '14px', 'primaryColor': '#1f6feb', 'lineColor': '#8b949e'}}}%%
flowchart TB
    subgraph wf["🔄 Workflow: CI - .NET Build and Test"]
        direction TB
        style wf fill:#0d1117,stroke:#30363d,stroke-width:3px,color:#e6edf3
        
        subgraph triggers["⚡ Stage: Triggers"]
            direction LR
            style triggers fill:#1c2128,stroke:#7ee787,stroke-width:2px,color:#7ee787
            subgraph events["Events"]
                style events fill:#161b22,stroke:#30363d,stroke-width:1px,color:#c9d1d9
                push(["🔔 push"]):::node-trigger
                pr(["🔔 pull_request"]):::node-trigger
                manual(["🔔 workflow_dispatch"]):::node-trigger
            end
        end
        
        subgraph ci-stage["🚀 Stage: CI Pipeline"]
            direction TB
            style ci-stage fill:#1c2128,stroke:#79c0ff,stroke-width:2px,color:#79c0ff
            subgraph reusable["Reusable Workflow"]
                style reusable fill:#161b22,stroke:#30363d,stroke-width:1px,color:#c9d1d9
                ci[["🚀 CI Reusable Workflow"]]:::node-build
            end
            subgraph executed-jobs["Executed Jobs"]
                style executed-jobs fill:#161b22,stroke:#a371f7,stroke-width:1px,color:#d2a8ff
                build["🔨 Build (3 platforms)"]:::node-build
                test["🧪 Test (3 platforms)"]:::node-test
                analyze["🔍 Analyze"]:::node-lint
                codeql["🛡️ CodeQL"]:::node-security
                summary["📊 Summary"]:::node-staging
            end
        end
    end
    
    push & pr & manual -->|"triggers"| ci
    ci -->|"executes"| build
    build --> test
    build --> analyze
    build --> codeql
    test & analyze & codeql --> summary
    
    classDef node-trigger fill:#238636,stroke:#2ea043,stroke-width:2px,color:#ffffff,font-weight:bold
    classDef node-build fill:#1f6feb,stroke:#58a6ff,stroke-width:2px,color:#ffffff
    classDef node-test fill:#8957e5,stroke:#a371f7,stroke-width:2px,color:#ffffff
    classDef node-lint fill:#a371f7,stroke:#d2a8ff,stroke-width:2px,color:#ffffff
    classDef node-security fill:#da3633,stroke:#f85149,stroke-width:2px,color:#ffffff
    classDef node-staging fill:#9e6a03,stroke:#d29922,stroke-width:2px,color:#ffffff
    
    linkStyle default stroke:#8b949e,stroke-width:2px
```

---

## Jobs Breakdown

### 🚀 CI

| Property | Value |
|----------|-------|
| **Name** | `🚀 CI` |
| **Type** | Reusable Workflow Call |
| **Workflow** | `./.github/workflows/ci-dotnet-reusable.yml` |

#### Inputs Passed

| Input | Value |
|-------|-------|
| `configuration` | `${{ inputs.configuration \|\| 'Release' }}` |
| `dotnet-version` | `10.0.x` |
| `solution-file` | `app.sln` |
| `test-results-artifact-name` | `test-results` |
| `build-artifacts-name` | `build-artifacts` |
| `coverage-artifact-name` | `code-coverage` |
| `artifact-retention-days` | `30` |
| `runs-on` | `ubuntu-latest` |
| `enable-code-analysis` | `${{ inputs.enable-code-analysis == '' && true \|\| inputs.enable-code-analysis }}` |
| `fail-on-format-issues` | `true` |

---

## Features (via Reusable Workflow)

| Feature | Description |
|---------|-------------|
| **Cross-platform builds** | Ubuntu, Windows, macOS |
| **Cross-platform testing** | Code coverage with Cobertura |
| **Code formatting analysis** | .editorconfig compliance |
| **CodeQL security scanning** | Always enabled |
| **Test result publishing** | Detailed summaries via dorny/test-reporter |
| **Build artifacts upload** | Per-platform artifacts |

---

## Permissions

| Permission | Level | Purpose |
|------------|-------|---------|
| `contents` | `read` | Read repository contents for checkout |
| `checks` | `write` | Create check runs for test results |
| `pull-requests` | `write` | Post comments on pull requests |
| `security-events` | `write` | Upload CodeQL SARIF results to Security tab |

---

## Concurrency

| Property | Value |
|----------|-------|
| **Group** | `${{ github.workflow }}-${{ github.event.pull_request.number \|\| github.ref }}` |
| **Cancel In Progress** | `true` |

---

## Path Filters

### Watched Paths

| Path Pattern | Description |
|--------------|-------------|
| `src/**` | Source code changes |
| `app.*/**` | Application project changes |
| `*.sln` | Solution file changes |
| `global.json` | .NET SDK version changes |
| `.github/workflows/ci-dotnet.yml` | This workflow file |
| `.github/workflows/ci-dotnet-reusable.yml` | Reusable workflow file |

---

## Dependencies

### Reusable Workflows

| Workflow | Purpose |
|----------|---------|
| `./.github/workflows/ci-dotnet-reusable.yml` | Comprehensive CI pipeline execution |

---

## Usage Examples

### Automatic Trigger (Push to main)

The workflow runs automatically when pushing to the `main` branch with changes in watched paths:

```bash
git push origin main
```

### Automatic Trigger (Feature Branch)

```bash
git checkout -b feature/my-feature
# Make changes to src/
git add .
git commit -m "Add new feature"
git push origin feature/my-feature
```

### Manual Trigger (Default Configuration)

```bash
gh workflow run ci-dotnet.yml
```

### Manual Trigger (Debug Build)

```bash
gh workflow run ci-dotnet.yml -f configuration=Debug
```

### Manual Trigger (Disable Code Analysis)

```bash
gh workflow run ci-dotnet.yml -f enable-code-analysis=false
```

### Manual Trigger (Full Options)

```bash
gh workflow run ci-dotnet.yml \
  -f configuration=Release \
  -f enable-code-analysis=true
```

---

## Branch Patterns

| Pattern | Example | Description |
|---------|---------|-------------|
| `main` | `main` | Main branch |
| `feature/**` | `feature/auth`, `feature/api/users` | Feature branches |
| `bugfix/**` | `bugfix/login-issue` | Bug fix branches |
| `hotfix/**` | `hotfix/security-patch` | Hotfix branches |
| `release/**` | `release/v1.0.0` | Release branches |
| `chore/**` | `chore/update-deps` | Maintenance branches |
| `docs/**` | `docs/api-reference` | Documentation branches |
| `refactor/**` | `refactor/cleanup` | Refactoring branches |
| `test/**` | `test/integration` | Test branches |

---

## Artifacts Generated

The following artifacts are produced by the reusable workflow:

| Artifact | Description | Retention |
|----------|-------------|-----------|
| `build-artifacts-ubuntu-latest` | Compiled binaries (Ubuntu) | 30 days |
| `build-artifacts-windows-latest` | Compiled binaries (Windows) | 30 days |
| `build-artifacts-macos-latest` | Compiled binaries (macOS) | 30 days |
| `test-results-ubuntu-latest` | Test results .trx (Ubuntu) | 30 days |
| `test-results-windows-latest` | Test results .trx (Windows) | 30 days |
| `test-results-macos-latest` | Test results .trx (macOS) | 30 days |
| `code-coverage-ubuntu-latest` | Cobertura coverage (Ubuntu) | 30 days |
| `code-coverage-windows-latest` | Cobertura coverage (Windows) | 30 days |
| `code-coverage-macos-latest` | Cobertura coverage (macOS) | 30 days |
| `codeql-sarif-results` | Security scan SARIF | 30 days |

---

## Prerequisites

| Requirement | Description |
|-------------|-------------|
| **Reusable Workflow** | `.github/workflows/ci-dotnet-reusable.yml` must exist |
| **Branch Location** | Workflow must be on default branch (main) or same branch for reference resolution |
| **Solution File** | `app.sln` must exist in repository root |

---

## Related Documentation

- [GitHub Actions - Triggers](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows)
- [GitHub Actions - Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [.NET Build and Test](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-net)
- [CI Reusable Workflow](ci-dotnet-reusable.md)
- [CD Workflow](azure-dev.md)
