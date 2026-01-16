# CI - .NET Build and Test

**Workflow File:** [ci-dotnet.yml](../../.github/workflows/ci-dotnet.yml)

## 📋 Overview

This workflow orchestrates the CI pipeline by calling the reusable workflow. It handles triggers, path filters, and passes configuration to the reusable CI workflow for .NET solutions.

### Key Features

- ✅ Automatic triggering on push and pull requests
- 🔧 Configurable build configuration (Release/Debug)
- 🧪 Optional cross-platform matrix testing
- 🔍 Code formatting analysis with .editorconfig
- 📊 Test result publishing with detailed summaries
- 📦 Build artifact upload for debugging

## 🗺️ Pipeline Visualization

```mermaid
flowchart TD
    subgraph Triggers["🎯 Triggers"]
        push([Push to branches])
        pr([Pull Request to main])
        manual([Manual Dispatch])
    end

    subgraph Inputs["⚙️ Manual Inputs"]
        config{{"Configuration<br/>(Release/Debug)"}}
        analysis{{"Enable Code Analysis"}}
        matrix{{"Enable Matrix Testing"}}
    end

    subgraph CI["🔄 CI Pipeline"]
        ci_call[["🚀 CI Reusable Workflow"]]
        
        subgraph Jobs["Reusable Workflow Jobs"]
            build(["🔨 Build"])
            test(["🧪 Test"])
            analyze(["🔍 Analyze"])
            summary(["📊 Summary"])
        end
    end

    subgraph Artifacts["📦 Artifacts"]
        build_art[/"📁 build-artifacts"/]
        test_art[/"📋 test-results"/]
        cov_art[/"📊 code-coverage"/]
    end

    %% Trigger flow
    push --> ci_call
    pr --> ci_call
    manual --> config
    config --> ci_call
    analysis -.-> ci_call
    matrix -.-> ci_call

    %% CI flow
    ci_call --> build
    build --> test
    build --> analyze
    test --> summary
    analyze --> summary

    %% Artifact flow
    build --> build_art
    test --> test_art
    test --> cov_art

    %% Styling
    classDef trigger fill:#2196F3,stroke:#1565C0,color:#fff
    classDef input fill:#FFC107,stroke:#F57F17,color:#000
    classDef reusable fill:#607D8B,stroke:#455A64,color:#fff,stroke-dasharray: 5 5
    classDef build fill:#FF9800,stroke:#E65100,color:#fff
    classDef test fill:#9C27B0,stroke:#6A1B9A,color:#fff
    classDef analyze fill:#00BCD4,stroke:#00838F,color:#fff
    classDef summary fill:#4CAF50,stroke:#2E7D32,color:#fff
    classDef artifact fill:#8BC34A,stroke:#558B2F,color:#fff

    class push,pr,manual trigger
    class config,analysis,matrix input
    class ci_call reusable
    class build build
    class test test
    class analyze analyze
    class summary summary
    class build_art,test_art,cov_art artifact
```

## 🎯 Triggers

### Push Events

| Branch Pattern | Description |
|----------------|-------------|
| `main` | Main development branch |
| `feature/**` | Feature branches |
| `bugfix/**` | Bug fix branches |
| `hotfix/**` | Hotfix branches |
| `release/**` | Release branches |
| `chore/**` | Maintenance branches |
| `docs/**` | Documentation branches |
| `refactor/**` | Refactoring branches |
| `test/**` | Test branches |

### Pull Request Events

| Target Branch | Description |
|---------------|-------------|
| `main` | Pull requests targeting main branch |

### Path Filters

```yaml
paths:
  - "src/**"                              # Source code
  - "app.*/**"                            # .NET Aspire projects
  - "*.sln"                               # Solution files
  - "global.json"                         # .NET SDK configuration
  - ".github/workflows/ci-dotnet.yml"     # This workflow
  - ".github/workflows/ci-dotnet-reusable.yml"  # Reusable workflow
```

### Manual Dispatch Inputs

| Input | Type | Default | Options | Description |
|-------|------|---------|---------|-------------|
| `configuration` | `choice` | `Release` | `Release`, `Debug` | Build configuration |
| `enable-code-analysis` | `boolean` | `true` | - | Enable code formatting analysis |
| `enable-matrix` | `boolean` | `false` | - | Enable cross-platform matrix testing |

## 📋 Jobs & Steps

### Job: 🚀 CI

This workflow consists of a single job that calls the reusable CI workflow.

| Property | Value |
|----------|-------|
| **Type** | Reusable workflow call |
| **Workflow** | `.github/workflows/ci-dotnet-reusable.yml` |
| **Secrets** | Inherited |

### Reusable Workflow Parameters

| Parameter | Value | Description |
|-----------|-------|-------------|
| `configuration` | `${{ inputs.configuration \|\| 'Release' }}` | Build configuration |
| `dotnet-version` | `10.0.x` | .NET SDK version |
| `solution-file` | `app.sln` | Solution file path |
| `test-results-artifact-name` | `test-results` | Test results artifact name |
| `build-artifacts-name` | `build-artifacts` | Build artifacts name |
| `coverage-artifact-name` | `code-coverage` | Coverage artifact name |
| `artifact-retention-days` | `30` | Artifact retention period |
| `runs-on` | `ubuntu-latest` | Runner environment |
| `enable-code-analysis` | Dynamic | Enable code analysis |
| `enable-matrix` | `${{ inputs.enable-matrix \|\| false }}` | Enable matrix testing |
| `fail-on-format-issues` | `true` | Fail on formatting issues |

## 🔐 Prerequisites

### Required Permissions

```yaml
permissions:
  contents: read       # Required for checkout
  checks: write        # Required for test reporter
  pull-requests: write # Required for PR comments
```

### Concurrency Configuration

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

This prevents duplicate workflow runs for the same branch/PR and cancels in-progress runs when new commits are pushed.

## 📦 Artifacts

| Artifact | Contents | Retention |
|----------|----------|-----------|
| `build-artifacts` | Compiled binaries | 7 days |
| `test-results` | Test execution results (.trx) | 30 days |
| `code-coverage` | Cobertura XML coverage reports | 30 days |

## 🚀 Usage Examples

### Automatic CI on Push

```bash
# Create a feature branch and push
git checkout -b feature/my-feature
# Make changes...
git add .
git commit -m "feat: implement new feature"
git push origin feature/my-feature
```

### Automatic CI on Pull Request

```bash
# Create PR from feature branch
gh pr create --base main --head feature/my-feature
```

### Manual CI Run

1. Go to **Actions** → **CI - .NET Build and Test**
2. Click **Run workflow**
3. Select configuration options:
   - **Build configuration**: Release or Debug
   - **Enable code formatting analysis**: Check/uncheck
   - **Enable cross-platform matrix testing**: Check/uncheck
4. Click **Run workflow**

### Manual CI via CLI

```bash
# Run with defaults
gh workflow run ci-dotnet.yml

# Run with Debug configuration
gh workflow run ci-dotnet.yml -f configuration=Debug

# Run with matrix testing enabled
gh workflow run ci-dotnet.yml -f enable-matrix=true

# Run with all options
gh workflow run ci-dotnet.yml \
  -f configuration=Release \
  -f enable-code-analysis=true \
  -f enable-matrix=true
```

## 🔍 Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Build fails | Missing NuGet packages | Check `dotnet restore` logs |
| Tests fail | Test failures | Download `test-results` artifact for details |
| Format check fails | Code style violations | Run `dotnet format app.sln` locally |
| Matrix job fails | OS-specific issue | Check logs for the specific OS |

### Local Verification

```bash
# Restore dependencies
dotnet restore app.sln

# Build solution
dotnet build app.sln --configuration Release

# Run tests
dotnet test app.sln --configuration Release

# Check formatting
dotnet format app.sln --verify-no-changes

# Fix formatting issues
dotnet format app.sln
```

### Viewing Test Results

1. Navigate to the workflow run
2. Click on the **Test Results** check
3. View individual test results and failures
4. Download `test-results` artifact for detailed .trx files

## 🔗 Related Documentation

- [CI - .NET Reusable Workflow](./ci-dotnet-reusable.md)
- [CD - Azure Deployment](./azure-dev.md)
- [.NET Testing Documentation](https://docs.microsoft.com/en-us/dotnet/core/testing/)
- [dotnet format Documentation](https://docs.microsoft.com/en-us/dotnet/core/tools/dotnet-format)
