---
title: CI - .NET Build and Test Workflow
description: Continuous integration pipeline for .NET solution code quality validation with cross-platform support, code coverage, and security scanning
author: Platform Team
date: 2026-01-21
version: 1.0.0
tags: [ci, build, test, dotnet, github-actions, codeql]
---

# 🔄 CI - .NET Build and Test Workflow

> [!NOTE]
> **Target Audience:** Developers, DevOps Engineers, QA Engineers<br/>
> **Reading Time:** ~8 minutes

<details>
<summary>📍 Navigation</summary>

| Previous                  |           Index           |                                 Next |
| :------------------------ | :-----------------------: | -----------------------------------: |
| [DevOps Index](README.md) | [DevOps Index](README.md) | [CI Reusable](ci-dotnet-reusable.md) |

</details>

---

## 📑 Table of Contents

- [🔄 CI - .NET Build and Test Workflow](#-ci---net-build-and-test-workflow)
  - [📑 Table of Contents](#-table-of-contents)
  - [📖 Overview](#-overview)
  - [📊 Pipeline Visualization](#-pipeline-visualization)
  - [🎯 Triggers](#-triggers)
  - [📋 Jobs](#-jobs)
  - [⚙️ Configuration](#️-configuration)
  - [📦 Artifacts](#-artifacts)
  - [💡 Usage Examples](#-usage-examples)
  - [🔧 Troubleshooting](#-troubleshooting)
  - [📚 Related Documentation](#-related-documentation)

---

## 📖 Overview

The **CI - .NET Build and Test** workflow (`ci-dotnet.yml`) is the continuous integration pipeline that orchestrates code quality validation for the .NET solution. It serves as the entry point that calls the reusable CI workflow with appropriate configuration.

This workflow provides:

- Cross-platform builds (Ubuntu, Windows, macOS)
- Cross-platform testing with code coverage (Cobertura)
- Code formatting analysis (.editorconfig compliance)
- CodeQL security vulnerability scanning
- Test result publishing with detailed summaries

---

## 📊 Pipeline Visualization

<details>
<summary>🔍 Click to expand pipeline diagram</summary>

```mermaid
---
title: CI Pipeline Architecture
---
flowchart TD
    %% ===== TRIGGER EVENTS =====
    subgraph Triggers["🎯 Triggers"]
        T1(["push"])
        T2(["pull_request"])
        T3(["workflow_dispatch"])
    end

    %% ===== PATH FILTERS =====
    subgraph PathFilters["📁 Path Filters"]
        PF[/"src/**, app.*/**,<br/>*.sln, global.json,<br/>workflow files"/]
    end

    %% ===== CI PIPELINE =====
    subgraph CI["🚀 CI Pipeline"]
        CI_CALL[["ci-dotnet-reusable.yml"]]
    end

    %% ===== EXECUTED JOBS =====
    subgraph Jobs["📋 Jobs Executed"]
        direction TB

        subgraph BuildMatrix["🔨 Build Matrix"]
            B1["Ubuntu"]
            B2["Windows"]
            B3["macOS"]
        end

        subgraph TestMatrix["🧪 Test Matrix"]
            TM_U["Ubuntu"]
            TM_W["Windows"]
            TM_M["macOS"]
        end

        ANALYZE["🔍 Analyze"]
        CODEQL["🛡️ CodeQL"]
        SUMMARY[/"📊 Summary"/]
    end

    %% ===== TRIGGER FLOWS =====
    T1 -->|evaluates| PF
    T2 -->|evaluates| PF
    T3 -->|triggers directly| CI_CALL
    PF -->|matches| CI_CALL

    %% ===== CI TO JOBS =====
    CI_CALL ==>|executes| BuildMatrix
    BuildMatrix -->|compiles| TestMatrix
    BuildMatrix -->|validates| ANALYZE
    BuildMatrix -->|scans| CODEQL
    TestMatrix -->|reports| SUMMARY
    ANALYZE -->|reports| SUMMARY
    CODEQL -->|reports| SUMMARY

    %% ===== NODE STYLING =====
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef matrix fill:#D1FAE5,stroke:#10B981,color:#000000
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000

    %% ===== APPLY NODE CLASSES =====
    class T1,T2,T3 trigger
    class PF input
    class CI_CALL external
    class B1,B2,B3,TM_U,TM_W,TM_M matrix
    class ANALYZE secondary
    class CODEQL secondary
    class SUMMARY datastore

    %% ===== SUBGRAPH STYLING =====
    style Triggers fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px
    style PathFilters fill:#F3F4F6,stroke:#6B7280,stroke-width:2px
    style CI fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style Jobs fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style BuildMatrix fill:#D1FAE5,stroke:#059669,stroke-width:1px
    style TestMatrix fill:#D1FAE5,stroke:#059669,stroke-width:1px
```

</details>

---

## 🎯 Triggers

| Trigger             | Branches                                                                                                      | Description                       |
| :------------------ | :------------------------------------------------------------------------------------------------------------ | :-------------------------------- |
| `push`              | `main`, `feature/**`, `bugfix/**`, `hotfix/**`, `release/**`, `chore/**`, `docs/**`, `refactor/**`, `test/**` | Triggers on push to any branch    |
| `pull_request`      | `main`                                                                                                        | Triggers on PRs targeting main    |
| `workflow_dispatch` | Any                                                                                                           | Manual trigger with configuration |

### Path Filters

The workflow only triggers when changes are made to:

| Path Pattern                               | Description                 |
| :----------------------------------------- | :-------------------------- |
| `src/**`                                   | Source code files           |
| `app.*/**`                                 | AppHost and ServiceDefaults |
| `*.sln`                                    | Solution files              |
| `global.json`                              | .NET SDK configuration      |
| `.github/workflows/ci-dotnet.yml`          | This workflow file          |
| `.github/workflows/ci-dotnet-reusable.yml` | Reusable workflow file      |

### Manual Trigger Inputs

| Input                  | Type    | Default   | Description                         |
| :--------------------- | :------ | :-------- | :---------------------------------- |
| `configuration`        | choice  | `Release` | Build configuration (Release/Debug) |
| `enable-code-analysis` | boolean | `true`    | Enable code formatting analysis     |

---

## 📋 Jobs

### 🚀 CI (Reusable Workflow Call)

This workflow delegates all CI operations to the reusable workflow.

| Property     | Value                                        |
| :----------- | :------------------------------------------- |
| **Workflow** | `./.github/workflows/ci-dotnet-reusable.yml` |
| **Secrets**  | `inherit` (passes all secrets)               |

#### Configuration Passed

```yaml
configuration: ${{ inputs.configuration || 'Release' }}
dotnet-version: "10.0.x"
solution-file: "app.sln"
test-results-artifact-name: "test-results"
build-artifacts-name: "build-artifacts"
coverage-artifact-name: "code-coverage"
artifact-retention-days: 30
runs-on: "ubuntu-latest"
enable-code-analysis: ${{ inputs.enable-code-analysis == '' && true || inputs.enable-code-analysis }}
fail-on-format-issues: true
```

### Jobs Executed (via Reusable Workflow)

The reusable workflow executes the following jobs:

<details>
<summary>🔍 View jobs flow diagram</summary>

```mermaid
---
title: CI Jobs Flow Overview
---
flowchart LR
    %% ===== CROSS-PLATFORM MATRIX =====
    subgraph CrossPlatform["🌐 Cross-Platform Matrix"]
        direction TB
        BUILD["🔨 Build<br/>(Ubuntu, Windows, macOS)"]
        TEST["🧪 Test<br/>(Ubuntu, Windows, macOS)"]
    end

    %% ===== SINGLE RUNNER JOBS =====
    subgraph SingleRunner["🖥️ Single Runner"]
        ANALYZE["🔍 Analyze"]
        CODEQL["🛡️ CodeQL"]
    end

    %% ===== FINAL AGGREGATION =====
    subgraph Final["📊 Aggregation"]
        SUMMARY[/"📊 Summary"/]
        FAILURE["❌ On-Failure"]
    end

    %% ===== JOB FLOW =====
    BUILD ==>|compiles| TEST
    BUILD -->|validates| ANALYZE
    BUILD -->|scans| CODEQL
    TEST -->|reports| SUMMARY
    ANALYZE -->|reports| SUMMARY
    CODEQL -->|reports| SUMMARY
    SUMMARY -.->|on failure| FAILURE

    %% ===== NODE STYLING =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF

    %% ===== APPLY NODE CLASSES =====
    class BUILD primary
    class TEST secondary
    class ANALYZE secondary
    class CODEQL secondary
    class SUMMARY datastore
    class FAILURE failed

    %% ===== SUBGRAPH STYLING =====
    style CrossPlatform fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style SingleRunner fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
    style Final fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px
```

</details>

### Job Details

| Job           | Runner                          | Description                                   |
| :------------ | :------------------------------ | :-------------------------------------------- |
| 🔨 Build      | Matrix (ubuntu, windows, macos) | Compiles solution on all platforms            |
| 🧪 Test       | Matrix (ubuntu, windows, macos) | Runs tests with coverage on all platforms     |
| 🔍 Analyze    | ubuntu-latest                   | Verifies code formatting (optional)           |
| 🛡️ CodeQL     | ubuntu-latest                   | Security vulnerability scanning (always runs) |
| 📊 Summary    | ubuntu-latest                   | Aggregates results from all jobs              |
| ❌ On-Failure | ubuntu-latest                   | Reports failures (runs only on failure)       |

---

## ⚙️ Configuration

### Required Permissions

```yaml
permissions:
  contents: read # Read repository contents
  checks: write # Create check runs for test results
  pull-requests: write # Post comments on pull requests
  security-events: write # Upload CodeQL SARIF results
```

### .NET SDK

- Version: `10.0.x`
- Workloads: Updated automatically during workflow

### Code Quality Requirements

- `.editorconfig` file for formatting rules
- Solution file (`app.sln`) at repository root

---

## 📦 Artifacts

| Artifact               | Description                      | Retention |
| :--------------------- | :------------------------------- | :-------- |
| `build-artifacts-{os}` | Compiled binaries per platform   | 30 days   |
| `test-results-{os}`    | Test execution results (.trx)    | 30 days   |
| `code-coverage-{os}`   | Coverage reports (Cobertura XML) | 30 days   |
| `codeql-sarif-results` | Security scan results (SARIF)    | 30 days   |

### Concurrency

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

Prevents duplicate workflow runs for the same branch/PR and cancels in-progress runs when new commits are pushed.

---

## 💡 Usage Examples

### Automatic Trigger

```bash
# Push to any configured branch triggers CI
git push origin feature/my-feature
```

### Manual Trigger

```bash
# Trigger with default configuration (Release)
gh workflow run ci-dotnet.yml

# Trigger with Debug configuration
gh workflow run ci-dotnet.yml -f configuration=Debug

# Trigger without code analysis
gh workflow run ci-dotnet.yml -f enable-code-analysis=false
```

### Pull Request

```bash
# Create PR to main - automatically triggers CI
gh pr create --base main --title "My feature"
```

---

## 🔧 Troubleshooting

### Common Issues

> [!WARNING]
> Platform-specific issues are common in cross-platform builds. Always test on all platforms before merging.

| Issue                            | Cause                            | Solution                                 |
| :------------------------------- | :------------------------------- | :--------------------------------------- |
| Build fails on one platform only | Platform-specific code issues    | Check conditional compilation directives |
| Code formatting check fails      | Code doesn't match .editorconfig | Run `dotnet format` locally              |
| Tests fail on specific OS        | Environment-dependent tests      | Review test assumptions about file paths |
| CodeQL timeout                   | Large codebase analysis          | CodeQL has 45-minute timeout             |

### Local Verification

> [!TIP]
> Run these commands before pushing to catch issues early.

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

---

## 📚 Related Documentation

- [Reusable CI Workflow](ci-dotnet-reusable.md) - Detailed documentation of the reusable workflow
- [CD - Azure Deployment](azure-dev.md) - Deployment workflow that uses this CI
- [GitHub Actions .NET Documentation](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-net)

---

[⬆️ Back to Top](#-ci---net-build-and-test-workflow)

---

<div align="center">

**[← DevOps Index](README.md)** | **[DevOps Index](README.md)** | **[CI Reusable →](ci-dotnet-reusable.md)**

</div>
