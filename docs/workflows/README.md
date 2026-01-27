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
%%{init: {'theme': 'base', 'themeVariables': { 'primaryColor': '#1976D2', 'primaryTextColor': '#FFFFFF', 'primaryBorderColor': '#0D47A1', 'lineColor': '#616161', 'secondaryColor': '#E3F2FD', 'tertiaryColor': '#FAFAFA', 'clusterBkg': '#E3F2FD', 'clusterBorder': '#1976D2'}}}%%
flowchart TB
    subgraph triggers ["🎯 Triggers"]
        direction LR
        push["📤 Push"]
        pr["🔀 PR"]
        manual["🖱️ Manual"]
    end

    subgraph ci ["🔄 CI Pipeline"]
        direction TB
        subgraph build ["🔨 Build"]
            direction LR
            b-ubuntu["🐧 Ubuntu"]
            b-windows["🪟 Windows"]
            b-macos["🍎 macOS"]
        end
        subgraph test ["🧪 Test"]
            direction LR
            t-ubuntu["🐧 Ubuntu"]
            t-windows["🪟 Windows"]
            t-macos["🍎 macOS"]
        end
        subgraph analyze ["🔍 Analyze"]
            format["🎨 Format"]
            codeql["🛡️ CodeQL"]
        end
    end

    subgraph cd ["🚀 CD Pipeline"]
        direction TB
        provision["🏗️ Provision"]
        deploy["🚀 Deploy"]
    end

    summary["📊 Summary"]

    triggers --> ci
    triggers --> cd
    build --> test --> analyze
    ci --> summary
    provision --> deploy --> summary

    style push fill:#FF9800,stroke:#E65100,color:#fff
    style pr fill:#FF9800,stroke:#E65100,color:#fff
    style manual fill:#FF9800,stroke:#E65100,color:#fff
    style b-ubuntu fill:#E65100,stroke:#BF360C,color:#fff
    style b-windows fill:#0277BD,stroke:#01579B,color:#fff
    style b-macos fill:#424242,stroke:#212121,color:#fff
    style t-ubuntu fill:#E65100,stroke:#BF360C,color:#fff
    style t-windows fill:#0277BD,stroke:#01579B,color:#fff
    style t-macos fill:#424242,stroke:#212121,color:#fff
    style format fill:#00BCD4,stroke:#00838F,color:#fff
    style codeql fill:#00BCD4,stroke:#00838F,color:#fff
    style provision fill:#4CAF50,stroke:#2E7D32,color:#fff
    style deploy fill:#4CAF50,stroke:#2E7D32,color:#fff
    style summary fill:#607D8B,stroke:#455A64,color:#fff
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
