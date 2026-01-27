# CI - .NET Reusable Workflow

[![Workflow Status](https://img.shields.io/badge/workflow-ci--dotnet--reusable.yml-blue?style=flat-square)](../../.github/workflows/ci-dotnet-reusable.yml)

## Overview

| Property | Value |
|----------|-------|
| **Workflow Name** | `CI - .NET Reusable Workflow` |
| **File** | [`.github/workflows/ci-dotnet-reusable.yml`](../../.github/workflows/ci-dotnet-reusable.yml) |
| **Type** | Reusable Workflow (`workflow_call`) |
| **Purpose** | Comprehensive reusable CI workflow for .NET solutions |

### Description

This reusable workflow provides a complete CI pipeline for .NET solutions including:

- Cross-platform builds (Ubuntu, Windows, macOS)
- Cross-platform testing with code coverage
- Code formatting analysis (.editorconfig compliance)
- CodeQL security scanning (always enabled)
- Comprehensive workflow summaries

---

## Trigger Events

### `workflow_call` (Reusable Workflow)

This workflow is designed to be called from other workflows using the `uses` keyword.

```yaml
jobs:
  ci:
    uses: ./.github/workflows/ci-dotnet-reusable.yml
    with:
      configuration: 'Release'
      dotnet-version: '10.0.x'
      solution-file: 'app.sln'
    secrets: inherit
```

---

## Workflow Diagram

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '14px', 'primaryColor': '#1976D2', 'lineColor': '#78909C', 'textColor': '#37474F'}}}%%
flowchart TB
    subgraph wf["🔄 Workflow: CI - .NET Reusable"]
        direction TB
        style wf fill:#263238,stroke:#455A64,stroke-width:3px,color:#ECEFF1
        
        subgraph triggers["⚡ Stage: Triggers"]
            direction LR
            style triggers fill:#37474F,stroke:#66BB6A,stroke-width:2px,color:#A5D6A7
            subgraph events["Events"]
                style events fill:#455A64,stroke:#78909C,stroke-width:1px,color:#CFD8DC
                call(["🔔 workflow_call"]):::node-trigger
            end
        end
        
        subgraph build-stage["🔨 Stage: Build"]
            direction TB
            style build-stage fill:#37474F,stroke:#42A5F5,stroke-width:2px,color:#90CAF9
            subgraph build-matrix["🔨 Build Matrix"]
                direction LR
                style build-matrix fill:#455A64,stroke:#4FC3F7,stroke-width:1px,color:#B3E5FC
                build-ubuntu["🐧 Ubuntu"]:::node-ubuntu
                build-windows["🪟 Windows"]:::node-windows
                build-macos["🍎 macOS"]:::node-macos
            end
        end
        
        subgraph test-stage["🧪 Stage: Test"]
            direction TB
            style test-stage fill:#37474F,stroke:#AB47BC,stroke-width:2px,color:#CE93D8
            subgraph test-matrix["🧪 Test Matrix"]
                direction LR
                style test-matrix fill:#455A64,stroke:#4FC3F7,stroke-width:1px,color:#B3E5FC
                test-ubuntu["🐧 Ubuntu"]:::node-ubuntu
                test-windows["🪟 Windows"]:::node-windows
                test-macos["🍎 macOS"]:::node-macos
            end
        end
        
        subgraph analysis-stage["🔍 Stage: Analysis"]
            direction LR
            style analysis-stage fill:#37474F,stroke:#BA68C8,stroke-width:2px,color:#E1BEE7
            subgraph quality["Quality Checks"]
                style quality fill:#455A64,stroke:#BA68C8,stroke-width:1px,color:#E1BEE7
                analyze["🔍 Analyze"]:::node-lint
            end
            subgraph security["Security"]
                style security fill:#455A64,stroke:#EF5350,stroke-width:1px,color:#EF9A9A
                codeql["🛡️ CodeQL Scan"]:::node-security
            end
        end
        
        subgraph summary-stage["📊 Stage: Reporting"]
            direction LR
            style summary-stage fill:#37474F,stroke:#66BB6A,stroke-width:2px,color:#A5D6A7
            subgraph reports["Reports"]
                style reports fill:#455A64,stroke:#66BB6A,stroke-width:1px,color:#C8E6C9
                summary["📊 Summary"]:::node-production
                failure["❌ On Failure"]:::node-error
            end
        end
    end
    
    %% Trigger connections (parallel to all OS)
    call -->|"triggers"| build-ubuntu & build-windows & build-macos
    
    %% Build to Test (OS-specific)
    build-ubuntu --> test-ubuntu
    build-windows --> test-windows
    build-macos --> test-macos
    
    %% Build to Analysis (from any build)
    build-ubuntu & build-windows & build-macos --> analyze & codeql
    
    %% Test and Analysis to Summary
    test-ubuntu & test-windows & test-macos --> summary
    analyze & codeql --> summary
    
    %% Failure handling
    build-ubuntu & build-windows & build-macos -.->|"if: failure()"| failure
    test-ubuntu & test-windows & test-macos -.->|"if: failure()"| failure
    analyze & codeql -.->|"if: failure()"| failure
    
    %% Material Design Node Classes
    classDef node-trigger fill:#43A047,stroke:#66BB6A,stroke-width:2px,color:#FFFFFF,font-weight:bold
    classDef node-build fill:#1976D2,stroke:#42A5F5,stroke-width:2px,color:#FFFFFF
    classDef node-lint fill:#8E24AA,stroke:#BA68C8,stroke-width:2px,color:#FFFFFF
    classDef node-security fill:#C62828,stroke:#EF5350,stroke-width:2px,color:#FFFFFF
    classDef node-production fill:#2E7D32,stroke:#66BB6A,stroke-width:2px,color:#FFFFFF,font-weight:bold
    classDef node-error fill:#C62828,stroke:#EF5350,stroke-width:2px,color:#FFFFFF
    
    %% OS-Specific Node Classes (Material Design)
    classDef node-ubuntu fill:#E65100,stroke:#FF9800,stroke-width:2px,color:#FFFFFF,font-weight:bold
    classDef node-windows fill:#0277BD,stroke:#03A9F4,stroke-width:2px,color:#FFFFFF,font-weight:bold
    classDef node-macos fill:#455A64,stroke:#78909C,stroke-width:2px,color:#FFFFFF,font-weight:bold
    
    linkStyle default stroke:#78909C,stroke-width:2px
```

---

## Input Parameters

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `configuration` | `string` | No | `Release` | Build configuration (Release/Debug) |
| `dotnet-version` | `string` | No | `10.0.x` | .NET SDK version to use |
| `solution-file` | `string` | No | `app.sln` | Path to the solution file |
| `test-results-artifact-name` | `string` | No | `test-results` | Name for test results artifact |
| `build-artifacts-name` | `string` | No | `build-artifacts` | Name for build artifacts |
| `coverage-artifact-name` | `string` | No | `code-coverage` | Name for code coverage artifact |
| `artifact-retention-days` | `number` | No | `30` | Number of days to retain artifacts |
| `runs-on` | `string` | No | `ubuntu-latest` | Runner for analyze/summary jobs |
| `enable-code-analysis` | `boolean` | No | `true` | Enable code formatting analysis |
| `fail-on-format-issues` | `boolean` | No | `true` | Fail workflow if formatting issues found |

---

## Output Parameters

| Output | Description |
|--------|-------------|
| `build-version` | The generated build version |
| `build-result` | Build job result |
| `test-result` | Test job result |
| `analyze-result` | Analysis job result |
| `codeql-result` | CodeQL security scan result |

---

## Jobs Breakdown

### 1. 🔨 Build (Cross-Platform Matrix)

| Property | Value |
|----------|-------|
| **Name** | `🔨 Build (${{ matrix.os }})` |
| **Runs On** | `ubuntu-latest`, `windows-latest`, `macos-latest` |
| **Timeout** | 15 minutes |
| **Strategy** | Matrix (fail-fast: false) |

#### Outputs

| Output | Description |
|--------|-------------|
| `build-version` | Generated version number (`1.0.${{ github.run_number }}`) |

#### Steps

| # | Step | Action/Command |
|---|------|----------------|
| 1 | 📥 Checkout repository | `actions/checkout@v6.0.2` |
| 2 | 🔧 Setup .NET SDK | `actions/setup-dotnet@v5.1.0` |
| 3 | ☁️ Update .NET workloads | `dotnet workload update` |
| 4 | 🏷️ Generate build version | Shell script |
| 5 | 📥 Restore dependencies | `dotnet restore` |
| 6 | 🔨 Build solution | `dotnet build` |
| 7 | 📤 Upload build artifacts | `actions/upload-artifact@v6.0.0` |
| 8 | 📊 Generate build summary | Shell script |

#### Artifacts Generated

| Artifact | Pattern | Description |
|----------|---------|-------------|
| `build-artifacts-{os}` | `**/bin/${{ inputs.configuration }}/**` | Compiled binaries per platform |

---

### 2. 🧪 Test (Cross-Platform Matrix)

| Property | Value |
|----------|-------|
| **Name** | `🧪 Test (${{ matrix.os }})` |
| **Runs On** | `ubuntu-latest`, `windows-latest`, `macos-latest` |
| **Timeout** | 30 minutes |
| **Depends On** | `build` |
| **Strategy** | Matrix (fail-fast: false) |

#### Steps

| # | Step | Action/Command |
|---|------|----------------|
| 1 | 📥 Checkout repository | `actions/checkout@v6.0.2` |
| 2 | 🔧 Setup .NET SDK | `actions/setup-dotnet@v5.1.0` |
| 3 | ☁️ Update .NET workloads | `dotnet workload update` |
| 4 | 📥 Restore dependencies | `dotnet restore` |
| 5 | 🔨 Build solution | `dotnet build` |
| 6 | 🧪 Run tests with coverage | `dotnet test --coverage --coverage-output-format cobertura` |
| 7 | 📋 Publish test results | `dorny/test-reporter@v2.5.0` |
| 8 | 📤 Upload test results | `actions/upload-artifact@v6.0.0` |
| 9 | 📤 Upload code coverage | `actions/upload-artifact@v6.0.0` |
| 10 | 📊 Generate test summary | Shell script |

#### Artifacts Generated

| Artifact | Description |
|----------|-------------|
| `test-results-{os}` | Test execution results (.trx format) |
| `code-coverage-{os}` | Coverage reports (Cobertura XML) |

---

### 3. 🔍 Analyze

| Property | Value |
|----------|-------|
| **Name** | `🔍 Analyze` |
| **Runs On** | `${{ inputs.runs-on }}` |
| **Timeout** | 15 minutes |
| **Depends On** | `build` |
| **Condition** | `${{ inputs.enable-code-analysis }}` |

#### Steps

| # | Step | Action/Command |
|---|------|----------------|
| 1 | 📥 Checkout repository | `actions/checkout@v6.0.2` |
| 2 | 🔧 Setup .NET SDK | `actions/setup-dotnet@v5.1.0` |
| 3 | ☁️ Update .NET workloads | `dotnet workload update` |
| 4 | 📥 Restore dependencies | `dotnet restore` |
| 5 | 🎨 Verify code formatting | `dotnet format --verify-no-changes` |
| 6 | 📊 Generate analysis summary | Shell script |
| 7 | ❌ Fail on format issues | Conditional exit based on `fail-on-format-issues` |

---

### 4. 🛡️ CodeQL Security Scan

| Property | Value |
|----------|-------|
| **Name** | `🛡️ CodeQL Security Scan` |
| **Runs On** | `${{ inputs.runs-on }}` |
| **Timeout** | 45 minutes |
| **Depends On** | `build` |
| **Condition** | Always runs (no skip condition) |

#### Configuration

| Property | Value |
|----------|-------|
| **Language** | `csharp` |
| **Query Suites** | `security-extended`, `security-and-quality` |
| **Build Mode** | Autobuild |
| **Category** | `/language:csharp` |

#### Paths Ignored

- `**/tests/**`
- `**/test/**`
- `**/*.test.cs`
- `**/*.Tests.cs`

#### Steps

| # | Step | Action/Command |
|---|------|----------------|
| 1 | 📥 Checkout repository | `actions/checkout@v6.0.2` (fetch-depth: 0) |
| 2 | 🔧 Setup .NET SDK | `actions/setup-dotnet@v5.1.0` |
| 3 | 🛡️ Initialize CodeQL | `github/codeql-action/init@v3.28.0` |
| 4 | 🔨 Autobuild for CodeQL | `github/codeql-action/autobuild@v3.28.0` |
| 5 | 🛡️ Perform CodeQL analysis | `github/codeql-action/analyze@v3.28.0` |
| 6 | 📤 Upload CodeQL SARIF results | `actions/upload-artifact@v6.0.0` |
| 7 | 📊 Generate CodeQL summary | Shell script |

#### Artifacts Generated

| Artifact | Description |
|----------|-------------|
| `codeql-sarif-results` | Security scan results (SARIF format) |

---

### 5. 📊 Summary

| Property | Value |
|----------|-------|
| **Name** | `📊 Summary` |
| **Runs On** | `${{ inputs.runs-on }}` |
| **Timeout** | 5 minutes |
| **Depends On** | `build`, `test`, `analyze`, `codeql` |
| **Condition** | `always()` |

#### Steps

| # | Step | Description |
|---|------|-------------|
| 1 | 📊 Generate workflow summary | Creates comprehensive summary with all job results |

---

### 6. ❌ Failed

| Property | Value |
|----------|-------|
| **Name** | `❌ Failed` |
| **Runs On** | `${{ inputs.runs-on }}` |
| **Timeout** | 5 minutes |
| **Depends On** | `build`, `test`, `analyze`, `codeql` |
| **Condition** | `failure()` |

#### Steps

| # | Step | Description |
|---|------|-------------|
| 1 | ❌ Report CI failure | Generates failure report with job statuses |

---

## Permissions

| Permission | Level | Purpose |
|------------|-------|---------|
| `contents` | `read` | Read repository contents for checkout |
| `checks` | `write` | Create check runs for test results |
| `pull-requests` | `write` | Post comments on pull requests |
| `security-events` | `write` | Upload CodeQL SARIF results to Security tab |

---

## Environment Variables

| Variable | Value | Description |
|----------|-------|-------------|
| `DOTNET_SKIP_FIRST_TIME_EXPERIENCE` | `true` | Skip .NET welcome experience |
| `DOTNET_NOLOGO` | `true` | Suppress .NET logo |
| `DOTNET_CLI_TELEMETRY_OPTOUT` | `true` | Disable telemetry |

---

## Artifacts Generated

| Artifact | Description | Retention |
|----------|-------------|-----------|
| `build-artifacts-ubuntu-latest` | Compiled binaries (Ubuntu) | `artifact-retention-days` |
| `build-artifacts-windows-latest` | Compiled binaries (Windows) | `artifact-retention-days` |
| `build-artifacts-macos-latest` | Compiled binaries (macOS) | `artifact-retention-days` |
| `test-results-ubuntu-latest` | Test results .trx (Ubuntu) | `artifact-retention-days` |
| `test-results-windows-latest` | Test results .trx (Windows) | `artifact-retention-days` |
| `test-results-macos-latest` | Test results .trx (macOS) | `artifact-retention-days` |
| `code-coverage-ubuntu-latest` | Cobertura coverage (Ubuntu) | `artifact-retention-days` |
| `code-coverage-windows-latest` | Cobertura coverage (Windows) | `artifact-retention-days` |
| `code-coverage-macos-latest` | Cobertura coverage (macOS) | `artifact-retention-days` |
| `codeql-sarif-results` | Security scan SARIF | `artifact-retention-days` |

---

## Dependencies

### External Actions

| Action | Version | Purpose |
|--------|---------|---------|
| `actions/checkout` | `v6.0.2` (SHA: `de0fac2e...`) | Checkout repository |
| `actions/setup-dotnet` | `v5.1.0` (SHA: `baa11fbf...`) | Setup .NET SDK |
| `actions/upload-artifact` | `v6.0.0` (SHA: `b7c566a7...`) | Upload artifacts |
| `dorny/test-reporter` | `v2.5.0` (SHA: `b082adf0...`) | Publish test results |
| `github/codeql-action/init` | `v3.28.0` (SHA: `cdefb33c...`) | Initialize CodeQL |
| `github/codeql-action/autobuild` | `v3.28.0` (SHA: `cdefb33c...`) | Autobuild for CodeQL |
| `github/codeql-action/analyze` | `v3.28.0` (SHA: `cdefb33c...`) | Run CodeQL analysis |

---

## Usage Examples

### Basic Usage

```yaml
jobs:
  ci:
    uses: ./.github/workflows/ci-dotnet-reusable.yml
    with:
      configuration: 'Release'
      dotnet-version: '10.0.x'
      solution-file: 'app.sln'
    secrets: inherit
```

### Full Configuration

```yaml
jobs:
  ci:
    uses: ./.github/workflows/ci-dotnet-reusable.yml
    with:
      configuration: 'Release'
      dotnet-version: '10.0.x'
      solution-file: 'app.sln'
      test-results-artifact-name: 'test-results'
      build-artifacts-name: 'build-artifacts'
      coverage-artifact-name: 'code-coverage'
      artifact-retention-days: 30
      runs-on: 'ubuntu-latest'
      enable-code-analysis: true
      fail-on-format-issues: true
    secrets: inherit
```

### Debug Configuration

```yaml
jobs:
  ci:
    uses: ./.github/workflows/ci-dotnet-reusable.yml
    with:
      configuration: 'Debug'
      enable-code-analysis: false
    secrets: inherit
```

---

## CodeQL Security Scanning

### Vulnerability Categories Scanned

| Category | Description |
|----------|-------------|
| 💉 Injection Attacks | SQL injection, XSS, command injection |
| 🔐 Cryptographic Issues | Insecure cryptographic practices |
| 📤 Data Exposure | Sensitive data leakage |
| 🔑 Auth Issues | Authentication and authorization flaws |
| 🛡️ Path Traversal | Directory traversal vulnerabilities |
| ⚠️ Deserialization | Unsafe deserialization patterns |

### Best Practices Applied

| Practice | Status |
|----------|--------|
| Pinned action versions (SHA) | ✅ |
| Full git history for blame | ✅ |
| Autobuild for .NET | ✅ |
| Extended security queries | ✅ |
| SARIF upload enabled | ✅ |
| Runs on every CI execution | ✅ |

---

## Related Documentation

- [GitHub Reusable Workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
- [CodeQL Documentation](https://docs.github.com/en/code-security/code-scanning/introduction-to-code-scanning/about-code-scanning-with-codeql)
- [.NET CLI Reference](https://learn.microsoft.com/en-us/dotnet/core/tools/)
- [CI Workflow (Caller)](ci-dotnet.md)
- [CD Workflow](azure-dev.md)
