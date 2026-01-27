---
title: GitHub Actions Workflows Documentation
description: Comprehensive documentation for CI/CD workflows in the Azure-LogicApps-Monitoring project
author: Documentation Team
last_updated: 2025-01-15
---

# 🔄 GitHub Actions Workflows

> 📚 **Summary**: This documentation covers all GitHub Actions workflows used for continuous integration and deployment in the Azure-LogicApps-Monitoring project.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Workflow Architecture](#workflow-architecture)
- [Available Workflows](#available-workflows)
- [Quick Reference](#quick-reference)
- [See Also](#see-also)

---

## Overview

This project implements a modern CI/CD pipeline using GitHub Actions with the following key features:

| Feature | Description |
|---------|-------------|
| **Cross-Platform CI** | Build and test on Ubuntu, Windows, and macOS |
| **Reusable Workflows** | Modular workflow design for maintainability |
| **Security Scanning** | CodeQL analysis for vulnerability detection |
| **OIDC Authentication** | Secure Azure deployment with federated credentials |
| **Automated Deployment** | Azure Developer CLI (azd) integration |

---

## Workflow Architecture

```mermaid
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1976D2', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#0D47A1', 'lineColor': '#424242', 'secondaryColor': '#F5F5F5', 'tertiaryColor': '#E3F2FD'}}}%%
flowchart TB
    subgraph workflow-trigger ["🎯 Workflow Triggers"]
        direction LR
        trigger-push["📤 Push"]
        trigger-pr["🔀 Pull Request"]
        trigger-dispatch["🖱️ Manual Dispatch"]
    end

    subgraph ci-workflow ["🔄 CI - .NET Build and Test"]
        direction TB
        ci-orchestrator["📋 ci-dotnet.yml<br/>Orchestrator"]
    end

    subgraph ci-reusable ["🔧 CI - .NET Reusable Workflow"]
        direction TB
        subgraph build-stage ["🔨 Build Stage"]
            direction LR
            build-ubuntu["🐧 Ubuntu"]
            build-windows["🪟 Windows"]
            build-macos["🍎 macOS"]
        end
        subgraph test-stage ["🧪 Test Stage"]
            direction LR
            test-ubuntu["🐧 Ubuntu"]
            test-windows["🪟 Windows"]
            test-macos["🍎 macOS"]
        end
        subgraph analysis-stage ["🔍 Analysis Stage"]
            analyze-job["🎨 Code Format"]
            codeql-job["🛡️ CodeQL Security"]
        end
        ci-summary["📊 Summary"]
    end

    subgraph cd-workflow ["🚀 CD - Azure Deployment"]
        direction TB
        cd-ci["🔄 CI Check"]
        cd-deploy["🚀 Deploy Dev"]
        cd-summary["📊 Summary"]
    end

    trigger-push --> ci-workflow
    trigger-pr --> ci-workflow
    trigger-dispatch --> ci-workflow
    trigger-push --> cd-workflow
    trigger-dispatch --> cd-workflow

    ci-orchestrator --> ci-reusable
    build-stage --> test-stage
    test-stage --> analysis-stage
    analysis-stage --> ci-summary

    cd-ci --> cd-deploy
    cd-deploy --> cd-summary
```

---

## Available Workflows

| Workflow | File | Description | Triggers |
|----------|------|-------------|----------|
| **CI - .NET Build and Test** | [ci-dotnet.yml](ci-dotnet.md) | Main CI orchestrator | Push, PR, Manual |
| **CI - .NET Reusable** | [ci-dotnet-reusable.yml](ci-dotnet-reusable.md) | Reusable CI workflow with cross-platform matrix | Called by ci-dotnet.yml |
| **CD - Azure Deployment** | [azure-dev.yml](azure-dev.md) | Continuous deployment to Azure | Push, Manual |

---

## Quick Reference

### Running Workflows Manually

```bash
# Run CI workflow
gh workflow run "CI - .NET Build and Test"

# Run CD workflow (skip CI)
gh workflow run "CD - Azure Deployment" -f skip-ci=true

# Run CD workflow with CI
gh workflow run "CD - Azure Deployment"
```

### Viewing Workflow Status

```bash
# List recent workflow runs
gh run list

# View specific run details
gh run view <run-id>

# Watch a running workflow
gh run watch <run-id>
```

---

## See Also

- [ci-dotnet.md](ci-dotnet.md) - CI orchestrator workflow documentation
- [ci-dotnet-reusable.md](ci-dotnet-reusable.md) - Reusable CI workflow documentation
- [azure-dev.md](azure-dev.md) - Azure deployment workflow documentation
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Developer CLI Documentation](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)

---

[⬆️ Back to Top](#-github-actions-workflows)
