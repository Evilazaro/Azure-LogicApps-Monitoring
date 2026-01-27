---
title: CI - .NET Build and Test Workflow
description: Main CI orchestrator workflow that triggers the reusable .NET CI workflow
author: Documentation Team
last_updated: 2025-01-15
workflow_file: .github/workflows/ci-dotnet.yml
---

# 🔄 CI - .NET Build and Test

> 📚 **Summary**: This workflow serves as the main CI orchestrator, triggering the reusable `.NET` CI workflow for comprehensive build, test, and analysis operations.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Workflow Diagram](#workflow-diagram)
- [Triggers](#triggers)
- [Configuration](#configuration)
- [Job Details](#job-details)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)
- [See Also](#see-also)

---

## Overview

| Property | Value |
|----------|-------|
| **Workflow Name** | `CI - .NET Build and Test` |
| **File Location** | `.github/workflows/ci-dotnet.yml` |
| **Type** | Orchestrator |
| **Calls** | `ci-dotnet-reusable.yml` |

### Key Features

- ✅ **Multi-branch support** - Triggers on main, feature/**, bugfix/**, release/**, hotfix/**
- ✅ **Pull request validation** - Runs on all PR types
- ✅ **Manual dispatch** - Can be triggered manually with custom configuration
- ✅ **Configurable options** - Build configuration and code analysis settings

---

## Workflow Diagram

This diagram shows the **actual job structure** from the workflow files:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1976D2', 'primaryTextColor': '#FFFFFF', 'lineColor': '#616161', 'clusterBkg': '#E3F2FD', 'clusterBorder': '#1976D2'}}}%%
flowchart TB
    subgraph TRIGGERS ["Triggers"]
        push["📤 Push\nmain, feature/**\nbugfix/**, etc."]
        pr["🔀 Pull Request\nmain branch"]
        dispatch["🖱️ Manual\nworkflow_dispatch"]
    end

    subgraph ORCHESTRATOR ["ci-dotnet.yml (1 job)"]
        ci-job["ci job\nuses: ci-dotnet-reusable.yml"]
    end

    subgraph REUSABLE ["ci-dotnet-reusable.yml (6 jobs)"]
        subgraph BUILD_MATRIX ["build job (matrix)"]
            b1["🐧 ubuntu-latest"]
            b2["🪟 windows-latest"]
            b3["🍎 macos-latest"]
        end
        
        subgraph TEST_MATRIX ["test job (matrix)\nneeds: build"]
            t1["🐧 ubuntu-latest"]
            t2["🪟 windows-latest"]
            t3["🍎 macos-latest"]
        end
        
        analyze["analyze job\nneeds: build"]
        codeql["codeql job\nneeds: build"]
        summary["summary job\nneeds: build, test,\nanalyze, codeql"]
        onfailure["on-failure job\nif: failure()"]
    end

    TRIGGERS --> ORCHESTRATOR
    ci-job -.->|calls| REUSABLE
    BUILD_MATRIX --> TEST_MATRIX
    BUILD_MATRIX --> analyze
    BUILD_MATRIX --> codeql
    TEST_MATRIX --> summary
    analyze --> summary
    codeql --> summary
    summary -.-> onfailure

    style push fill:#FF9800,stroke:#E65100,color:#fff
    style pr fill:#FF9800,stroke:#E65100,color:#fff
    style dispatch fill:#FF9800,stroke:#E65100,color:#fff
    style ci-job fill:#9C27B0,stroke:#6A1B9A,color:#fff
    style b1 fill:#E65100,stroke:#BF360C,color:#fff
    style b2 fill:#0277BD,stroke:#01579B,color:#fff
    style b3 fill:#424242,stroke:#212121,color:#fff
    style t1 fill:#E65100,stroke:#BF360C,color:#fff
    style t2 fill:#0277BD,stroke:#01579B,color:#fff
    style t3 fill:#424242,stroke:#212121,color:#fff
    style analyze fill:#00BCD4,stroke:#00838F,color:#fff
    style codeql fill:#00BCD4,stroke:#00838F,color:#fff
    style summary fill:#607D8B,stroke:#455A64,color:#fff
    style onfailure fill:#F44336,stroke:#C62828,color:#fff
```

---

## Triggers

### Push Events

```yaml
on:
  push:
    branches:
      - main
      - feature/**
      - bugfix/**
      - release/**
      - hotfix/**
```

### Pull Request Events

```yaml
on:
  pull_request:
    branches:
      - main
```

### Manual Dispatch

```yaml
on:
  workflow_dispatch:
    inputs:
      configuration:
        description: "Build configuration"
        default: "Release"
        type: choice
        options:
          - Debug
          - Release
      enable-code-analysis:
        description: "Enable code analysis"
        default: true
        type: boolean
```

---

## Configuration

### Inputs Passed to Reusable Workflow

| Input | Default | Description |
|-------|---------|-------------|
| `configuration` | `Release` | Build configuration (Debug/Release) |
| `dotnet-version` | `10.0.x` | .NET SDK version |
| `solution-file` | `app.sln` | Solution file to build |
| `enable-code-analysis` | `true` | Enable code formatting analysis |
| `fail-on-format-issues` | `false` | Fail workflow on format issues |

---

## Job Details

### CI Job

This workflow contains a single job that calls the reusable CI workflow:

```yaml
jobs:
  ci:
    name: 🔄 CI
    uses: ./.github/workflows/ci-dotnet-reusable.yml
    with:
      configuration: ${{ inputs.configuration || 'Release' }}
      dotnet-version: "10.0.x"
      solution-file: "app.sln"
      enable-code-analysis: ${{ inputs.enable-code-analysis != false }}
      fail-on-format-issues: false
    secrets: inherit
```

---

## Usage Examples

### Trigger via GitHub CLI

```bash
# Run with default configuration
gh workflow run "CI - .NET Build and Test"

# Run with Debug configuration
gh workflow run "CI - .NET Build and Test" \
  -f configuration=Debug

# Run without code analysis
gh workflow run "CI - .NET Build and Test" \
  -f enable-code-analysis=false
```

### Trigger via Push

```bash
# Push to feature branch triggers CI
git checkout -b feature/my-feature
git push origin feature/my-feature
```

### Trigger via Pull Request

```bash
# Create PR to trigger CI
gh pr create --base main --head feature/my-feature
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| **Workflow not triggering** | Verify branch name matches pattern (feature/**, bugfix/**, etc.) |
| **Build failures** | Check reusable workflow outputs for detailed error messages |
| **Code analysis failures** | Run `dotnet format` locally to fix formatting issues |

### Viewing Logs

```bash
# View recent CI runs
gh run list --workflow="CI - .NET Build and Test"

# View detailed logs for a specific run
gh run view <run-id> --log
```

---

## See Also

- [ci-dotnet-reusable.md](ci-dotnet-reusable.md) - Reusable CI workflow details
- [azure-dev.md](azure-dev.md) - CD workflow documentation
- [README.md](README.md) - Workflows overview

---

[⬆️ Back to Top](#-ci---net-build-and-test)
