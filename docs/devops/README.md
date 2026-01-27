# DevOps Documentation

This folder contains documentation for the CI/CD workflows used in this repository.

## 🧭 Overview

The DevOps documentation describes GitHub Actions workflows that automate the build, test, and deployment processes for the Azure Logic Apps Monitoring solution. The workflows follow a modular design with reusable components to ensure consistency across all .NET projects.

## 📄 Documents

| Document | Description |
|----------|-------------|
| [CI - .NET Build and Test Workflow](ci-dotnet.md) | Entry point for .NET CI with trigger configuration and path filtering |
| [CI - .NET Reusable Workflow](ci-dotnet-reusable.md) | Comprehensive reusable CI workflow for cross-platform builds, testing, and security scanning |
| [CD - Azure Deployment Workflow](azure-dev.md) | Complete CD pipeline for Azure infrastructure provisioning and application deployment |

## 🔄 Workflow Relationships

```mermaid
---
title: DevOps Workflow Relationships
---
flowchart LR
    %% ===== CONTINUOUS INTEGRATION =====
    subgraph ci["Continuous Integration"]
        direction TB
        entry["CI Entry Point"]:::trigger
        reusable[["Reusable CI Workflow"]]:::external
    end

    %% ===== CONTINUOUS DELIVERY =====
    subgraph cd["Continuous Delivery"]
        direction TB
        deploy["Azure Deployment"]:::primary
    end

    %% ===== AZURE RESOURCES =====
    azure[("Azure Resources")]:::datastore

    %% ===== CONNECTIONS =====
    entry ==>|calls| reusable
    reusable -->|outputs| deploy
    deploy -->|provisions & deploys| azure

    %% ===== NODE STYLES =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray:5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000
    classDef matrix fill:#D1FAE5,stroke:#10B981,color:#000000

    %% ===== SUBGRAPH STYLES =====
    style ci fill:#ECFDF5,stroke:#10B981,stroke-width:2px
    style cd fill:#E0E7FF,stroke:#4F46E5,stroke-width:2px
```

## 🚀 Getting Started

1. Read [CI - .NET Build and Test Workflow](ci-dotnet.md) to understand trigger configuration
2. Read [CI - .NET Reusable Workflow](ci-dotnet-reusable.md) for details on build, test, and analysis jobs
3. Read [CD - Azure Deployment Workflow](azure-dev.md) for infrastructure provisioning and deployment

## Prerequisites

Before using these workflows, ensure the following are configured:

- **Repository Variables**: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
- **Azure Entra ID**: Federated credentials for GitHub Actions OIDC authentication
- **GitHub Environment**: `dev` environment (optional but recommended)
