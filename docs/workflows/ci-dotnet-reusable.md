---
title: CI - .NET Reusable Workflow
description: Comprehensive reusable CI workflow with cross-platform build, test, and security analysis
author: Documentation Team
last_updated: 2025-01-15
workflow_file: .github/workflows/ci-dotnet-reusable.yml
---

# 🔧 CI - .NET Reusable Workflow

> 📚 **Summary**: This reusable workflow provides comprehensive CI capabilities including cross-platform builds, testing with coverage, code formatting analysis, and CodeQL security scanning.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Workflow Diagram](#workflow-diagram)
- [Inputs](#inputs)
- [Outputs](#outputs)
- [Job Details](#job-details)
- [OS Matrix Configuration](#os-matrix-configuration)
- [Artifacts](#artifacts)
- [Best Practices](#best-practices)
- [See Also](#see-also)

---

## Overview

| Property | Value |
|----------|-------|
| **Workflow Name** | `CI - .NET Reusable Workflow` |
| **File Location** | `.github/workflows/ci-dotnet-reusable.yml` |
| **Type** | Reusable (workflow_call) |
| **Total Jobs** | 6 |
| **Timeout** | Varies by job (15-45 minutes) |

### Key Features

- ✅ **Cross-platform matrix builds** - Ubuntu, Windows, macOS
- ✅ **Comprehensive testing** - With code coverage (Cobertura format)
- ✅ **Code formatting** - .editorconfig compliance verification
- ✅ **Security scanning** - CodeQL with extended security queries
- ✅ **Rich summaries** - Detailed GitHub step summaries
- ✅ **Configurable inputs** - Extensive customization options

---

## Workflow Diagram

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1976D2', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#0D47A1', 'lineColor': '#616161', 'secondaryColor': '#E3F2FD', 'tertiaryColor': '#FAFAFA', 'clusterBkg': '#E3F2FD', 'clusterBorder': '#1976D2'}}}%%
flowchart TB
    subgraph level1 ["🎯 Level 1: Trigger"]
        wf-call["📞 workflow_call"]
    end

    subgraph level2 ["📋 Level 2: Stages"]
        direction LR
        s-build["🔨 Build"]
        s-test["🧪 Test"]
        s-analyze["🔍 Analyze"]
        s-summary["📊 Summary"]
    end

    subgraph level3 ["🔨 Level 3: Build Jobs"]
        direction LR
        build-ubuntu["🐧 Ubuntu<br/>───────<br/>Checkout<br/>Setup .NET<br/>Restore<br/>Build<br/>Upload"]
        build-windows["🪟 Windows<br/>───────<br/>Checkout<br/>Setup .NET<br/>Restore<br/>Build<br/>Upload"]
        build-macos["🍎 macOS<br/>───────<br/>Checkout<br/>Setup .NET<br/>Restore<br/>Build<br/>Upload"]
    end

    subgraph level3b ["🧪 Level 3: Test Jobs"]
        direction LR
        test-ubuntu["🐧 Ubuntu<br/>───────<br/>Checkout<br/>Setup .NET<br/>Build<br/>Test<br/>Coverage"]
        test-windows["🪟 Windows<br/>───────<br/>Checkout<br/>Setup .NET<br/>Build<br/>Test<br/>Coverage"]
        test-macos["🍎 macOS<br/>───────<br/>Checkout<br/>Setup .NET<br/>Build<br/>Test<br/>Coverage"]
    end

    subgraph level3c ["🔍 Level 3: Analysis Jobs"]
        direction LR
        analyze["🎨 Format Check<br/>───────<br/>dotnet format<br/>--verify-no-changes"]
        codeql["🛡️ CodeQL Scan<br/>───────<br/>security-extended<br/>security-and-quality"]
    end

    subgraph level3d ["📊 Level 3: Summary"]
        direction LR
        summary["📊 Results<br/>Aggregation"]
        failure["❌ Failure<br/>Handler"]
    end

    level1 --> level2
    s-build --> s-test --> s-analyze --> s-summary
    s-build -.-> level3
    s-test -.-> level3b
    s-analyze -.-> level3c
    s-summary -.-> level3d

    style wf-call fill:#FF9800,stroke:#E65100,color:#fff
    style s-build fill:#4CAF50,stroke:#2E7D32,color:#fff
    style s-test fill:#9C27B0,stroke:#6A1B9A,color:#fff
    style s-analyze fill:#00BCD4,stroke:#00838F,color:#fff
    style s-summary fill:#607D8B,stroke:#455A64,color:#fff
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

## Inputs

### Required Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `configuration` | `string` | `Release` | Build configuration (Debug/Release) |
| `dotnet-version` | `string` | `10.0.x` | .NET SDK version to use |
| `solution-file` | `string` | `app.sln` | Solution file path |

### Optional Inputs

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `runs-on` | `string` | `ubuntu-latest` | Default runner for non-matrix jobs |
| `enable-code-analysis` | `boolean` | `true` | Enable code formatting analysis |
| `fail-on-format-issues` | `boolean` | `true` | Fail on formatting issues |
| `build-artifacts-name` | `string` | `build-artifacts` | Build artifacts name prefix |
| `test-results-artifact-name` | `string` | `test-results` | Test results artifacts name prefix |
| `coverage-artifact-name` | `string` | `code-coverage` | Coverage artifacts name prefix |
| `artifact-retention-days` | `number` | `5` | Artifact retention period |

---

## Outputs

| Output | Source | Description |
|--------|--------|-------------|
| `build-version` | `jobs.build.outputs.build-version` | Generated build version (1.0.{run_number}) |
| `build-result` | `jobs.build.result` | Build job result |
| `test-result` | `jobs.test.result` | Test job result |
| `analyze-result` | `jobs.analyze.result` | Analysis job result |
| `codeql-result` | `jobs.codeql.result` | CodeQL scan result |

---

## Job Details

### 🔨 Build Job

**Purpose**: Cross-platform compilation with artifact generation

| Property | Value |
|----------|-------|
| **Name** | `🔨 Build (${{ matrix.os }})` |
| **Timeout** | 15 minutes |
| **Matrix** | `ubuntu-latest`, `windows-latest`, `macos-latest` |
| **Fail-fast** | `false` |

**Steps**:

1. 📥 Checkout repository (full history)
2. 🔧 Setup .NET SDK
3. ☁️ Update .NET workloads
4. 🏷️ Generate build version
5. 📥 Restore dependencies
6. 🔨 Build solution
7. 📤 Upload build artifacts
8. 📊 Generate build summary

---

### 🧪 Test Job

**Purpose**: Cross-platform testing with code coverage

| Property | Value |
|----------|-------|
| **Name** | `🧪 Test (${{ matrix.os }})` |
| **Timeout** | 30 minutes |
| **Matrix** | `ubuntu-latest`, `windows-latest`, `macos-latest` |
| **Fail-fast** | `false` |
| **Needs** | `build` |

**Steps**:

1. 📥 Checkout repository
2. 🔧 Setup .NET SDK
3. ☁️ Update .NET workloads
4. 📥 Restore dependencies
5. 🔨 Build solution
6. 🧪 Run tests with coverage
7. 📋 Publish test results (dorny/test-reporter)
8. 📤 Upload test results
9. 📤 Upload code coverage
10. 📊 Generate test summary

---

### 🔍 Analyze Job

**Purpose**: Code formatting verification

| Property | Value |
|----------|-------|
| **Name** | `🔍 Analyze` |
| **Timeout** | 15 minutes |
| **Runner** | `${{ inputs.runs-on }}` |
| **Needs** | `build` |
| **Condition** | `${{ inputs.enable-code-analysis }}` |

**Steps**:

1. 📥 Checkout repository
2. 🔧 Setup .NET SDK
3. ☁️ Update .NET workloads
4. 📥 Restore dependencies
5. 🎨 Verify code formatting (`dotnet format --verify-no-changes`)
6. 📊 Generate analysis summary
7. ❌ Fail on format issues (if configured)

---

### 🛡️ CodeQL Job

**Purpose**: Security vulnerability scanning

| Property | Value |
|----------|-------|
| **Name** | `🛡️ CodeQL Security Scan` |
| **Timeout** | 45 minutes |
| **Runner** | `${{ inputs.runs-on }}` |
| **Needs** | `build` |

**Steps**:

1. 📥 Checkout repository (full history)
2. 🔧 Setup .NET SDK
3. 🛡️ Initialize CodeQL (csharp, security-extended, security-and-quality)
4. 🔨 Autobuild for CodeQL
5. 🛡️ Perform CodeQL analysis
6. 📤 Upload CodeQL SARIF results
7. 📊 Generate CodeQL summary

---

### 📊 Summary Job

**Purpose**: Aggregate workflow results

| Property | Value |
|----------|-------|
| **Name** | `📊 Summary` |
| **Timeout** | 5 minutes |
| **Runner** | `${{ inputs.runs-on }}` |
| **Needs** | `build`, `test`, `analyze`, `codeql` |
| **Condition** | `always()` |

---

### ❌ On Failure Job

**Purpose**: Visual failure indication and reporting

| Property | Value |
|----------|-------|
| **Name** | `❌ Failed` |
| **Timeout** | 5 minutes |
| **Runner** | `${{ inputs.runs-on }}` |
| **Needs** | `build`, `test`, `analyze`, `codeql` |
| **Condition** | `failure()` |

---

## OS Matrix Configuration

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1976D2', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#0D47A1', 'lineColor': '#424242'}}}%%
flowchart LR
    subgraph matrix-config ["🖥️ OS Matrix Configuration"]
        direction TB
        
        subgraph ubuntu-runner ["🐧 Ubuntu Runner"]
            ubuntu-os["ubuntu-latest"]
            ubuntu-shell["Shell: bash"]
            ubuntu-arch["Arch: x64"]
        end

        subgraph windows-runner ["🪟 Windows Runner"]
            windows-os["windows-latest"]
            windows-shell["Shell: bash"]
            windows-arch["Arch: x64"]
        end

        subgraph macos-runner ["🍎 macOS Runner"]
            macos-os["macos-latest"]
            macos-shell["Shell: bash"]
            macos-arch["Arch: arm64"]
        end
    end

    classDef ubuntu fill:#E65100,stroke:#BF360C,color:#FFFFFF
    classDef windows fill:#0277BD,stroke:#01579B,color:#FFFFFF
    classDef macos fill:#424242,stroke:#212121,color:#FFFFFF

    class ubuntu-os,ubuntu-shell,ubuntu-arch ubuntu
    class windows-os,windows-shell,windows-arch windows
    class macos-os,macos-shell,macos-arch macos
```

### Matrix Strategy

```yaml
strategy:
  fail-fast: false
  matrix:
    os: [ubuntu-latest, windows-latest, macos-latest]
```

> ⚠️ **Note**: `fail-fast: false` ensures all platform builds complete even if one fails.

---

## Artifacts

### Build Artifacts

| Artifact | Pattern | Description |
|----------|---------|-------------|
| `build-artifacts-ubuntu-latest` | `**/bin/{config}/**` | Ubuntu build output |
| `build-artifacts-windows-latest` | `**/bin/{config}/**` | Windows build output |
| `build-artifacts-macos-latest` | `**/bin/{config}/**` | macOS build output |

### Test Artifacts

| Artifact | Pattern | Description |
|----------|---------|-------------|
| `test-results-{os}` | `**/TestResults/**/*.trx` | Test execution results |
| `code-coverage-{os}` | `**/coverage.cobertura.xml` | Code coverage reports |
| `codeql-sarif-results` | `codeql-results/` | CodeQL SARIF results |

---

## Best Practices

### Security Best Practices Applied

| Practice | Status | Description |
|----------|--------|-------------|
| Pinned action versions (SHA) | ✅ | All actions use commit SHA |
| Least privilege permissions | ✅ | Only required permissions granted |
| Secret inheritance | ✅ | `secrets: inherit` for secure passing |
| CodeQL on every run | ✅ | No conditional skipping |
| SARIF upload | ✅ | Security results in Security tab |

### CI Best Practices Applied

| Practice | Status | Description |
|----------|--------|-------------|
| Cross-platform testing | ✅ | Ubuntu, Windows, macOS |
| Full git history | ✅ | `fetch-depth: 0` for blame info |
| Code coverage | ✅ | Cobertura format for compatibility |
| Rich summaries | ✅ | GitHub step summaries for visibility |

---

## See Also

- [ci-dotnet.md](ci-dotnet.md) - CI orchestrator workflow
- [azure-dev.md](azure-dev.md) - CD workflow documentation
- [README.md](README.md) - Workflows overview
- [CodeQL Documentation](https://codeql.github.com/docs/)
- [dorny/test-reporter](https://github.com/dorny/test-reporter)

---

[⬆️ Back to Top](#-ci---net-reusable-workflow)
