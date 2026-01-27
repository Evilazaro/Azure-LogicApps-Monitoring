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

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1976D2', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#0D47A1', 'lineColor': '#616161', 'secondaryColor': '#E3F2FD', 'tertiaryColor': '#FAFAFA', 'clusterBkg': '#E3F2FD', 'clusterBorder': '#1976D2'}}}%%
flowchart TB
    subgraph level1 ["🎯 Level 1: Triggers"]
        direction LR
        push["📤 Push<br/>main, feature/**, bugfix/**"]
        pr["🔀 Pull Request"]
        dispatch["🖱️ Manual"]
    end

    subgraph level2 ["📋 Level 2: Orchestration"]
        orchestrator["🔧 ci-dotnet.yml<br/>calls reusable workflow"]
    end

    subgraph level3 ["🔨 Level 3: Jobs"]
        direction TB
        subgraph build-group ["🔨 Build Matrix"]
            direction LR
            build-ubuntu["🐧 Ubuntu"]
            build-windows["🪟 Windows"]
            build-macos["🍎 macOS"]
        end
        subgraph test-group ["🧪 Test Matrix"]
            direction LR
            test-ubuntu["🐧 Ubuntu"]
            test-windows["🪟 Windows"]
            test-macos["🍎 macOS"]
        end
        subgraph analysis-group ["🔍 Analysis"]
            direction LR
            analyze["🎨 Format"]
            codeql["🛡️ CodeQL"]
        end
        summary["📊 Summary"]
        failure["❌ On Failure"]
    end

    level1 --> level2 --> level3
    build-group --> test-group --> analysis-group --> summary
    analysis-group -.-> failure

    style push fill:#FF9800,stroke:#E65100,color:#fff
    style pr fill:#FF9800,stroke:#E65100,color:#fff
    style dispatch fill:#FF9800,stroke:#E65100,color:#fff
    style orchestrator fill:#1976D2,stroke:#0D47A1,color:#fff
    style build-ubuntu fill:#E65100,stroke:#BF360C,color:#fff
    style build-windows fill:#0277BD,stroke:#01579B,color:#fff
    style build-macos fill:#424242,stroke:#212121,color:#fff
    style test-ubuntu fill:#E65100,stroke:#BF360C,color:#fff
    style test-windows fill:#0277BD,stroke:#01579B,color:#fff
    style test-macos fill:#424242,stroke:#212121,color:#fff
    style analyze fill:#00BCD4,stroke:#00838F,color:#fff
    style codeql fill:#00BCD4,stroke:#00838F,color:#fff
    style summary fill:#607D8B,stroke:#455A64,color:#fff
    style failure fill:#F44336,stroke:#C62828,color:#fff
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
