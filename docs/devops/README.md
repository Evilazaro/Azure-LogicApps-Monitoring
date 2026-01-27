# DevOps Documentation Index

> **Location:** `docs/devops/`  
> **Last Updated:** 2026-01-26

---

## Overview

This directory contains comprehensive documentation for the CI/CD pipelines and DevOps automation configurations used in the Azure Logic Apps Monitoring project.

---

## Documentation Files

### GitHub Actions Workflows

| Document | Workflow File | Description |
|----------|---------------|-------------|
| [Azure Deployment (CD)](./github-actions-azure-dev.md) | `.github/workflows/azure-dev.yml` | Continuous Delivery pipeline for Azure infrastructure provisioning and application deployment |
| [.NET CI Orchestrator](./github-actions-ci-dotnet.md) | `.github/workflows/ci-dotnet.yml` | Entry point workflow that orchestrates the CI pipeline |
| [.NET CI Reusable Workflow](./github-actions-ci-dotnet-reusable.md) | `.github/workflows/ci-dotnet-reusable.yml` | Comprehensive reusable CI workflow with cross-platform builds, testing, and security scanning |

### Dependency Management

| Document | Config File | Description |
|----------|-------------|-------------|
| [Dependabot Configuration](./github-dependabot-config.md) | `.github/dependabot.yml` | Automated dependency updates for NuGet packages and GitHub Actions |

---

## Quick Reference

### Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    CI/CD Pipeline Overview                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   Push/PR          CI Workflow              CD Workflow          │
│   ───────►    ┌────────────────┐      ┌────────────────┐        │
│               │ ci-dotnet.yml  │      │ azure-dev.yml  │        │
│               │ (orchestrator) │ ───► │ (deployment)   │        │
│               └───────┬────────┘      └────────────────┘        │
│                       │                                          │
│               ┌───────▼────────┐                                 │
│               │ ci-dotnet-     │                                 │
│               │ reusable.yml   │                                 │
│               │ ┌────────────┐ │                                 │
│               │ │ Build      │ │                                 │
│               │ │ Test       │ │                                 │
│               │ │ Analyze    │ │                                 │
│               │ │ CodeQL     │ │                                 │
│               │ └────────────┘ │                                 │
│               └────────────────┘                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Trigger Summary

| Workflow | Automatic Triggers | Manual Trigger |
|----------|-------------------|----------------|
| CI (.NET) | Push to branches, PR to main | Yes (workflow_dispatch) |
| CD (Azure) | Push to specific branch | Yes (with skip-ci option) |
| Dependabot | Weekly (Monday 06:00 UTC) | No |

### Security Features

| Feature | CI Workflow | CD Workflow |
|---------|-------------|-------------|
| CodeQL Security Scanning | Yes | Inherited via CI |
| OIDC Authentication | No | Yes |
| Pinned Action Versions | Yes | Yes |
| Least-Privilege Permissions | Yes | Yes |

---

## Maintenance Guidelines

### Making Changes to Workflows

1. **Create a feature branch** for workflow changes
2. **Test in isolation** before merging to main
3. **Update documentation** when behavior changes
4. **Review with DevOps team** for significant modifications

### Documentation Updates

When updating workflows, ensure:

- [ ] Documentation reflects current workflow behavior
- [ ] Mermaid diagrams are updated if job structure changes
- [ ] Inputs/outputs are documented accurately
- [ ] Security considerations are reviewed

---

## Related Resources

### External Documentation

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Azure Developer CLI](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [CodeQL Documentation](https://docs.github.com/en/code-security/code-scanning)
- [Dependabot Configuration](https://docs.github.com/code-security/dependabot)

### Internal Documentation

- Infrastructure as Code: `infra/` directory
- Application Code: `src/` directory
- Deployment Hooks: `hooks/` directory
