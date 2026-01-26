---
name: postinfradelete
version: 2.0.0
author: Evilazaro | Principal Cloud Solution Architect | Microsoft
last_modified: 2026-01-09
license: MIT
languages: [PowerShell, Bash]
---

# postinfradelete

## Synopsis

Post-infrastructure-delete hook for Azure Developer CLI (azd) that purges soft-deleted Logic Apps Standard resources after infrastructure deletion to ensure complete cleanup.

## Description

This script is automatically executed by Azure Developer CLI (azd) after the `azd down` command completes. It addresses a specific Azure behavior where Logic Apps Standard resources enter a soft-delete state when deleted rather than being permanently removed.

When Azure Logic Apps Standard are deleted through normal Azure Resource Manager operations, they remain in a recoverable soft-delete state for a retention period. This can cause conflicts when re-provisioning resources with the same names and may incur ongoing costs. This script handles the explicit purge operation to fully remove these soft-deleted resources.

The script queries the Azure REST API to retrieve all soft-deleted Logic Apps in the specified Azure location, filters them based on the resource group naming pattern to identify those belonging to the current azd environment, and then purges each matching Logic App. This ensures a clean slate for future deployments.

## Workflow Diagram

```mermaid
flowchart TD
    subgraph Initialization
        A([Start - azd hook]) --> B[Parse Arguments]
        B --> C[Initialize Logging]
    end
    
    subgraph Validation["Environment Validation"]
        C --> D{Validate AZURE_SUBSCRIPTION_ID}
        D -->|Set| E{Validate AZURE_LOCATION}
        D -->|Missing| Z([Exit with Error])
        E -->|Set| F[Environment Valid]
        E -->|Missing| Z
    end
    
    subgraph AzureAuth["Azure Authentication"]
        F --> G{Azure CLI Authenticated?}
        G -->|Yes| H[Get Access Token]
        G -->|No| Z
        H --> I[Set Subscription Context]
    end
    
    subgraph Discovery["Soft-Delete Discovery"]
        I --> J[Query Deleted Sites API]
        J --> K{Deleted Apps Found?}
        K -->|No| L([No Apps to Purge])
        K -->|Yes| M[Filter by Location]
        M --> N{Matching Apps?}
        N -->|No| L
        N -->|Yes| O[Display App List]
    end
    
    subgraph Confirmation["User Confirmation"]
        O --> P{Force Mode?}
        P -->|Yes| Q[Skip Confirmation]
        P -->|No| R{User Confirms?}
        R -->|Yes| Q
        R -->|No| S([Cancelled by User])
    end
    
    subgraph Purge["Purge Operations"]
        Q --> T[Begin Purge Loop]
        T --> U[Purge Logic App]
        U --> V{More Apps?}
        V -->|Yes| U
        V -->|No| W[Generate Summary]
    end
    
    W --> X([Success])
    
    style Z fill:#f96
    style S fill:#ff9
    style L fill:#9f9
    style X fill:#9f9
```

## Prerequisites

| Category | Requirement | Version | Verification Command | Required |
|----------|-------------|---------|---------------------|----------|
| Runtime | PowerShell Core | >= 7.0 | `$PSVersionTable.PSVersion` | Yes |
| Runtime | Bash | >= 4.0 | `bash --version` | Yes |
| CLI Tool | Azure CLI | >= 2.50 | `az --version` | Yes |
| CLI Tool | jq (Bash only) | Latest | `jq --version` | Yes (Bash) |
| Environment Variable | AZURE_SUBSCRIPTION_ID | N/A | `echo $AZURE_SUBSCRIPTION_ID` | Yes |
| Environment Variable | AZURE_LOCATION | N/A | `echo $AZURE_LOCATION` | Yes |
| Permission | Azure Subscription Access | N/A | `az account show` | Yes |

### Installation Commands (Bash Dependencies)

```bash
# Install jq for JSON parsing
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# RHEL/CentOS
sudo yum install jq
```

## Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Force` | `[switch]` | No | `$false` | Skips confirmation prompts and forces execution |
| `-WhatIf` | `[switch]` | No | `$false` | Shows what would be executed without making changes |

### Bash Arguments

| Position/Flag | Type | Required | Default | Description |
|---------------|------|----------|---------|-------------|
| `--force`, `-f` | flag | No | `false` | Skip confirmation prompts |
| `--verbose`, `-v` | flag | No | `false` | Enable verbose output |
| `--help`, `-h` | flag | No | N/A | Show help message |

## Input/Output Specifications

### Inputs

**Environment Variables Read (set by azd):**

| Variable | Required | Description |
|----------|----------|-------------|
| `AZURE_SUBSCRIPTION_ID` | Yes | Azure subscription GUID |
| `AZURE_LOCATION` | Yes | Azure region where resources were deployed |
| `AZURE_RESOURCE_GROUP` | No | Filter by resource group name pattern |
| `LOGIC_APP_NAME` | No | Filter by Logic App name pattern |

### Outputs

**Exit Codes:**

| Exit Code | Meaning |
|-----------|---------|
| 0 | Success - All soft-deleted Logic Apps purged |
| 1 | General error or purge failure |

**stdout Output:**

- Timestamped progress messages
- List of discovered soft-deleted Logic Apps
- Purge operation results

**Azure Resources Modified:**

- Soft-deleted Logic Apps permanently removed

## Usage Examples

### Basic Usage

```powershell
# PowerShell: Run post-infrastructure-delete (typically called by azd)
.\postinfradelete.ps1
```

```bash
# Bash: Run post-infrastructure-delete (typically called by azd)
./postinfradelete.sh
```

### Advanced Usage

```powershell
# PowerShell: See what would be purged without making changes
.\postinfradelete.ps1 -WhatIf

# PowerShell: Force purge without confirmation
.\postinfradelete.ps1 -Force -Verbose
```

```bash
# Bash: Force purge with verbose output
./postinfradelete.sh --force --verbose

# Bash: Display help
./postinfradelete.sh --help
```

### CI/CD Pipeline Usage

```yaml
# Azure DevOps Pipeline
- task: AzureCLI@2
  displayName: 'Purge soft-deleted Logic Apps'
  inputs:
    azureSubscription: 'Azure-Connection'
    scriptType: 'bash'
    scriptLocation: 'scriptPath'
    scriptPath: '$(System.DefaultWorkingDirectory)/hooks/postinfradelete.sh'
    arguments: '--force'
  env:
    AZURE_SUBSCRIPTION_ID: $(AZURE_SUBSCRIPTION_ID)
    AZURE_LOCATION: $(AZURE_LOCATION)
  condition: always()

# GitHub Actions
- name: Cleanup soft-deleted Logic Apps
  if: always()
  shell: pwsh
  run: ./hooks/postinfradelete.ps1 -Force
  env:
    AZURE_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    AZURE_LOCATION: ${{ vars.AZURE_LOCATION }}
```

## Error Handling and Exit Codes

| Exit Code | Meaning | Recovery Action |
|-----------|---------|-----------------|
| 0 | Success | N/A |
| 1 | General error | Check Azure CLI authentication, verify permissions |

### Error Handling Approach

**PowerShell:**

- `Set-StrictMode -Version Latest` for strict mode
- `$ErrorActionPreference = 'Stop'` for fail-fast
- `SupportsShouldProcess` for WhatIf/Confirm support
- Try/Catch/Finally with preference restoration

**Bash:**

- `set -euo pipefail` for strict error handling
- Cleanup trap for EXIT signal
- Detailed error logging with color coding

## Security Considerations

### Credential Handling

- [x] No hardcoded secrets
- [x] Uses Azure CLI session for authentication
- [x] Access tokens acquired via `az account get-access-token`

### Required Permissions

| Permission/Role | Scope | Justification |
|-----------------|-------|---------------|
| Website Contributor | Subscription | Delete soft-deleted Logic Apps |
| Reader | Subscription | List soft-deleted resources |

### Network Security

- **Endpoints accessed:** Azure Resource Manager (`management.azure.com`)
- **TLS requirements:** TLS 1.2+
- **API Version:** 2023-12-01

### Logging Security

- **Sensitive data masking:** Access tokens not logged
- **Audit trail:** Timestamped operation logs

## Known Limitations

- Only targets Logic Apps Standard (not Consumption tier)
- Requires Azure CLI authentication with sufficient permissions
- Location filtering is case-sensitive
- Cannot recover purged Logic Apps after execution
- Rate limiting may affect large-scale purge operations

## Related Scripts

| Script | Relationship | Description |
|--------|--------------|-------------|
| [preprovision.md](preprovision.md) | Related | Pre-provisioning validation |
| [postprovision.md](postprovision.md) | Related | Post-provisioning configuration |

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2026-01-09 | Complete rewrite with improved error handling |
| 1.0.0 | 2025-06-01 | Initial release |
