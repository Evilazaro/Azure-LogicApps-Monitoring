---
name: check-dev-workstation
version: 1.0.0
author: Evilazaro | Principal Cloud Solution Architect | Microsoft
last_modified: 2026-01-07
license: MIT
languages: [PowerShell, Bash]
---

# check-dev-workstation

## Overview

Developer-friendly validation wrapper script that checks workstation prerequisites for the Azure Logic Apps Monitoring solution without making any changes to the environment.

## Description

This script provides a convenient way for developers to validate their workstation setup before beginning development work on the Azure Logic Apps Monitoring solution. It acts as a wrapper around the `preprovision` script, executing it in validation-only mode to check all prerequisites without performing any modifications.

The script performs comprehensive validation including checking PowerShell/Bash version compatibility, .NET SDK availability and version, Azure Developer CLI (azd) installation, Azure CLI installation and authentication status, Bicep CLI availability, Azure Resource Provider registrations, and Azure subscription quota requirements.

Unlike the preprovision script which can clear secrets and modify the environment, this wrapper is completely read-only and safe to run at any time. It provides clear, actionable feedback on any issues found, helping developers quickly identify and resolve configuration problems before they impact development work.

## Workflow Diagram

```mermaid
flowchart TD
    subgraph Initialization
        A([Start]) --> B[Locate preprovision Script]
        B --> C{Script Found?}
        C -->|Yes| D[Resolve PowerShell/Bash Path]
        C -->|No| Z([Exit with Error])
    end
    
    subgraph Execution["Child Process Execution"]
        D --> E[Build Arguments Array]
        E --> F[Add -ValidateOnly Flag]
        F --> G[Execute preprovision Script]
        G --> H[Stream Output to Console]
    end
    
    subgraph Results["Result Evaluation"]
        H --> I{Exit Code = 0?}
        I -->|Yes| J[Display Success Message]
        I -->|No| K[Display Warning Message]
        J --> L([Success])
        K --> M([Exit with Warning])
    end
    
    style Z fill:#f96
    style L fill:#9f9
    style M fill:#ff9
```

## Prerequisites

| Category | Requirement | Version | Verification Command | Required |
|----------|-------------|---------|---------------------|----------|
| Runtime | PowerShell Core | >= 7.0 | `$PSVersionTable.PSVersion` | Yes |
| Runtime | Bash | >= 4.0 | `bash --version` | Yes |
| Script | preprovision.ps1 / preprovision.sh | N/A | Must exist in same directory | Yes |

**Note:** All other prerequisites are validated by this script, not required to run it.

## Parameters/Arguments

### PowerShell Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `-Verbose` | `[switch]` | No | `$false` | Displays detailed diagnostic information during validation |

### Bash Arguments

| Position/Flag | Type | Required | Default | Description |
|---------------|------|----------|---------|-------------|
| `-v`, `--verbose` | flag | No | `false` | Display detailed diagnostic information during validation |
| `-h`, `--help` | flag | No | N/A | Display help message and exit |

## Input/Output Specifications

### Inputs

**Environment Variables Read:**

- None (all validation is performed by preprovision script)

**Files/Paths Expected:**

- `preprovision.ps1` (PowerShell) or `preprovision.sh` (Bash) - Must exist in the same directory

### Outputs

**Exit Codes:**

| Exit Code | Meaning |
|-----------|---------|
| 0 | Validation successful - All prerequisites met |
| 1 | General error - Missing script or invalid execution |
| >1 | Validation failed - See preprovision exit codes for details |
| 130 | Script interrupted by user (Ctrl+C) |

**stdout Output:**

- Formatted validation results from preprovision script
- Success or warning summary message
- Troubleshooting steps on error

## Usage Examples

### Basic Usage

```powershell
# PowerShell: Check workstation prerequisites
.\check-dev-workstation.ps1
```

```bash
# Bash: Check workstation prerequisites
./check-dev-workstation.sh
```

### Advanced Usage

```powershell
# PowerShell: Verbose validation with detailed output
.\check-dev-workstation.ps1 -Verbose
```

```bash
# Bash: Verbose validation with detailed output
./check-dev-workstation.sh --verbose

# Bash: Display help
./check-dev-workstation.sh --help
```

### CI/CD Pipeline Usage

```yaml
# Azure DevOps Pipeline - Validation gate
- task: PowerShell@2
  displayName: 'Validate build agent prerequisites'
  inputs:
    targetType: 'filePath'
    filePath: '$(System.DefaultWorkingDirectory)/hooks/check-dev-workstation.ps1'
    pwsh: true
  continueOnError: false

# GitHub Actions
- name: Validate runner prerequisites
  shell: bash
  run: |
    chmod +x ./hooks/check-dev-workstation.sh
    ./hooks/check-dev-workstation.sh --verbose
```

## Error Handling and Exit Codes

| Exit Code | Meaning | Recovery Action |
|-----------|---------|-----------------|
| 0 | Success - All prerequisites met | N/A |
| 1 | General error | Check if preprovision script exists |
| 2+ | Validation failure | Address specific issues from preprovision output |
| 130 | User interrupted | Re-run script when ready |

### Error Handling Approach

**PowerShell:**

- Try/Catch/Finally for structured error handling
- Child process execution isolates failures
- Original preferences restored in finally block
- Detailed troubleshooting steps provided on error

**Bash:**

- `set -euo pipefail` for strict error handling
- Trap handlers for EXIT, INT, and TERM signals
- Graceful interrupt handling (Ctrl+C)
- Color-coded error messages

## Security Considerations

### Credential Handling

- [x] No credentials handled directly
- [x] Read-only operation - no modifications to environment
- [x] Delegates authentication checks to preprovision script

### Required Permissions

| Permission/Role | Scope | Justification |
|-----------------|-------|---------------|
| None | Local | Only reads local configuration |
| Reader | Azure (via preprovision) | Validates Azure access |

### Network Security

- **Endpoints accessed:** None directly (preprovision handles Azure calls)
- **TLS requirements:** N/A
- **Firewall rules needed:** N/A

### Logging Security

- **Sensitive data masking:** Yes - preprovision handles masking
- **Audit trail:** Standard console output

## Known Limitations

- Requires preprovision script in the same directory
- Cannot fix issues - only reports them
- PowerShell version must execute child processes correctly
- Some validation requires Azure CLI authentication
- Windows may require execution policy bypass

## Related Scripts

| Script | Relationship | Description |
|--------|--------------|-------------|
| [preprovision.md](preprovision.md) | Called by | Underlying validation logic |
| [postprovision.md](postprovision.md) | Related | Post-provisioning configuration |
| [clean-secrets.md](clean-secrets.md) | Related | Secrets management utility |

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-07 | Initial release |
