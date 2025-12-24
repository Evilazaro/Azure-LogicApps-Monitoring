# Pre-Provisioning Script Enhancements

## Overview
The `preprovision.ps1` script has been comprehensively enhanced to validate all prerequisites required for deploying the Azure Logic Apps Monitoring solution. This document details the enhancements made.

## Version Information
- **Script Version**: 2.0.0
- **Enhancement Date**: 2025-12-24
- **Target Framework**: .NET 10.0, PowerShell 7.0+

## New Capabilities

### 1. Enhanced Version Requirements
The script now validates specific minimum versions for all required tools:

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| PowerShell | 7.0 | Script execution environment |
| .NET SDK | 10.0 | Building and running .NET Aspire applications |
| Azure CLI | 2.60.0 | Azure resource management and authentication |
| Bicep CLI | 0.30.0 | Infrastructure as Code deployment |
| Azure Developer CLI (azd) | Latest | Azure deployment orchestration |

### 2. New Validation Functions

#### Test-AzureCLI
- **Purpose**: Validates Azure CLI installation, version, and authentication status
- **Checks**:
  - Azure CLI is installed and accessible
  - Version meets minimum requirement (2.60.0+)
  - User is authenticated to Azure subscription
  - Active subscription is accessible
- **Outputs**: Detailed information about authenticated user and active subscription
- **Failure Guidance**: Provides installation URL and authentication command

#### Test-BicepCLI
- **Purpose**: Validates Bicep CLI installation and version
- **Checks**:
  - Bicep CLI is available (standalone or via Azure CLI)
  - Version meets minimum requirement (0.30.0+)
- **Outputs**: Detected Bicep version
- **Failure Guidance**: Provides installation/upgrade commands via Azure CLI

#### Test-AzureResourceProviders
- **Purpose**: Validates required Azure Resource Providers are registered
- **Checks Registration Status For**:
  - `Microsoft.App` (Container Apps)
  - `Microsoft.ServiceBus` (Service Bus messaging)
  - `Microsoft.Storage` (Storage accounts)
  - `Microsoft.Web` (Logic Apps Standard)
  - `Microsoft.ContainerRegistry` (Container Registry)
  - `Microsoft.Insights` (Application Insights)
  - `Microsoft.OperationalInsights` (Log Analytics)
  - `Microsoft.ManagedIdentity` (Managed identities)
- **Outputs**: List of unregistered providers with registration commands
- **Failure Guidance**: Provides exact `az provider register` commands

#### Test-AzureQuota
- **Purpose**: Provides informational quota requirements
- **Information Displayed**:
  - Container Apps (minimum 2)
  - Storage Accounts (minimum 3)
  - Service Bus namespaces (minimum 1)
  - Logic Apps Standard (minimum 1)
  - Container Registry (minimum 1)
- **Note**: This is informational only and doesn't fail validation

### 3. Enhanced Validation Flow

The script now performs comprehensive validation in the following order:

```powershell
Step 1: PowerShell Version Validation
├─ Validates PowerShell 7.0 or higher
└─ Fails if version is incompatible

Step 2: Prerequisites Validation
├─ .NET SDK 10.0+
│  └─ Provides download URL if missing
├─ Azure Developer CLI (azd)
│  └─ Provides installation URL if missing
├─ Azure CLI 2.60.0+ with authentication
│  └─ Provides installation and login commands if missing
├─ Bicep CLI 0.30.0+
│  └─ Provides installation/upgrade commands if missing
├─ Azure Resource Provider Registration
│  └─ Lists unregistered providers with registration commands
└─ Azure Quota Information (informational)
   └─ Displays minimum resource requirements

Step 3: User Secrets Clearing
├─ Skipped in ValidateOnly mode
├─ Skipped if SkipSecretsClear flag is set
└─ Executes clean-secrets.ps1 otherwise
```

### 4. Improved Error Handling

- **Graceful Degradation**: Each validation function handles errors independently
- **Detailed Logging**: Verbose output available via `-Verbose` parameter
- **User Guidance**: Clear installation/configuration instructions for each missing prerequisite
- **Exit Codes**: Proper exit codes (0 = success, 1 = failure) for CI/CD integration

### 5. Enhanced User Experience

#### Before Enhancement
```
Running preprovision.ps1...
✓ PowerShell version OK
✓ .NET SDK found
Done.
```

#### After Enhancement
```
╔════════════════════════════════════════════════════════════════╗
║          Azure Pre-Provisioning Script                        ║
╚════════════════════════════════════════════════════════════════╝

  Version:          2.0.0
  Execution Time:   2025-12-24 09:35:22
  PowerShell:       7.5.4
  OS:               Microsoft Windows 10.0.26200

Step 1: Validating PowerShell version...
  ✓ PowerShell 7.5.4 is compatible

Step 2: Validating prerequisites...
  • Checking .NET SDK...
    ✓ .NET SDK is available and compatible
  • Checking Azure Developer CLI...
    ✓ Azure Developer CLI is available
  • Checking Azure CLI...
    ✓ Azure CLI is available and authenticated
  • Checking Bicep CLI...
    ✓ Bicep CLI is available and compatible
  • Checking Azure Resource Provider registration...
    ✓ All required resource providers are registered
  • Checking Azure subscription quotas...
    ℹ  Quota check: Ensure your subscription has sufficient quota for:
       - Container Apps (minimum 2 apps)
       - Storage Accounts (minimum 3 accounts)
       - Service Bus namespaces (minimum 1)
       - Logic Apps Standard (minimum 1)
       - Container Registry (minimum 1)

  ✓ All prerequisites validated successfully

Step 3: Skipping user secrets clearing (ValidateOnly mode)

────────────────────────────────────────────────────────────────
  Status:           ✓ SUCCESS
  Duration:         16.13 seconds
╔════════════════════════════════════════════════════════════════╗
║   Pre-provisioning completed successfully!                    ║
╚════════════════════════════════════════════════════════════════╝
```

## PowerShell Best Practices Applied

### 1. Comment-Based Help (CBH)
All functions include comprehensive CBH with:
- Synopsis
- Description
- Parameter descriptions
- Return types
- Examples

### 2. Advanced Function Features
- `[CmdletBinding()]` for advanced cmdlet behavior
- `[OutputType()]` for clear return type declaration
- Proper parameter validation
- ShouldProcess support where applicable

### 3. Error Handling
- Try-catch-finally blocks
- Proper error propagation
- Verbose logging
- Graceful failure handling

### 4. Code Organization
- Clear region definitions (#region/#endregion)
- Logical function grouping
- Consistent naming conventions
- Proper scope management (script: prefix)

### 5. Modern PowerShell Practices
- Splatting for parameter passing
- Pipeline-friendly output
- Preference variable management
- Typed variables where appropriate

## Usage Examples

### Basic Validation
```powershell
.\hooks\preprovision.ps1 -ValidateOnly
```

### Full Execution with Verbose Output
```powershell
.\hooks\preprovision.ps1 -Verbose
```

### Skip Secrets Clearing
```powershell
.\hooks\preprovision.ps1 -SkipSecretsClear
```

### Force Execution (No Prompts)
```powershell
.\hooks\preprovision.ps1 -Force
```

### WhatIf Mode (Dry Run)
```powershell
.\hooks\preprovision.ps1 -WhatIf
```

## Integration with Azure Developer CLI

The script is designed to be called by `azd` during the provisioning lifecycle:

```yaml
# azure.yaml
hooks:
  preprovision:
    windows:
      shell: pwsh
      run: ./hooks/preprovision.ps1
    posix:
      shell: sh
      run: ./hooks/preprovision.sh
```

## Error Scenarios and Guidance

### Missing .NET SDK 10.0
```
Step 2: Validating prerequisites...
  • Checking .NET SDK...
WARNING:     ✗ .NET SDK 10.0 or higher is required
WARNING:       Download from: https://dotnet.microsoft.com/download/dotnet/10.0

ERROR: One or more required prerequisites are missing or not configured.
```

### Missing Azure CLI or Not Authenticated
```
Step 2: Validating prerequisites...
  • Checking Azure CLI...
WARNING:     ✗ Azure CLI 2.60.0 or higher is required
WARNING:       Install from: https://docs.microsoft.com/cli/azure/install-azure-cli
WARNING:       After installation, authenticate with: az login

ERROR: One or more required prerequisites are missing or not configured.
```

### Unregistered Resource Providers
```
Step 2: Validating prerequisites...
  • Checking Azure Resource Provider registration...
WARNING: Some required resource providers are not registered:
WARNING:   - Microsoft.App
WARNING:   - Microsoft.ContainerRegistry
WARNING: 
WARNING: To register these providers, run:
WARNING:   az provider register --namespace Microsoft.App --wait
WARNING:   az provider register --namespace Microsoft.ContainerRegistry --wait

ERROR: One or more required prerequisites are missing or not configured.
```

## Benefits

### For Developers
- **Early Failure Detection**: Issues caught before deployment begins
- **Clear Guidance**: Exact commands to fix each issue
- **Time Savings**: No partial deployments that fail halfway through
- **Learning Aid**: Understand what tools and permissions are needed

### For CI/CD Pipelines
- **Reliable Execution**: Consistent validation across environments
- **Proper Exit Codes**: Integration with build/release pipelines
- **Verbose Logging**: Troubleshooting support via `-Verbose` flag
- **Skip Options**: Flexibility for different pipeline stages

### For Operations Teams
- **Documentation**: Self-documenting through CBH and verbose output
- **Audit Trail**: Execution summaries with timestamps and durations
- **Compliance**: Validates resource provider registrations
- **Quota Awareness**: Informational checks for capacity planning

## Future Enhancements

Potential areas for future improvement:
1. Add support for alternative authentication methods (Service Principal)
2. Implement quota validation API calls (currently informational)
3. Add support for multiple Azure subscriptions
4. Include region-specific validation (e.g., service availability)
5. Add configuration file support for custom validation rules
6. Implement remediation mode (auto-register providers, install tools)

## Testing

The script has been tested in the following modes:
- ✅ ValidateOnly mode
- ✅ Standard execution mode
- ✅ Force mode
- ✅ WhatIf mode
- ✅ Verbose mode
- ✅ SkipSecretsClear mode

## Related Files

- `hooks/preprovision.ps1` - Main pre-provisioning script
- `hooks/clean-secrets.ps1` - User secrets clearing script
- `azure.yaml` - Azure Developer CLI configuration
- `infra/main.bicep` - Infrastructure as Code definitions

## Support

For issues or questions about the pre-provisioning script:
1. Review the verbose output: `.\hooks\preprovision.ps1 -Verbose`
2. Check Azure authentication: `az account show`
3. Verify tool versions: `dotnet --version`, `az version`, `az bicep version`, `azd version`
4. Review resource provider status: `az provider list --output table`

## Changelog

### Version 2.0.0 (2025-12-24)
- ➕ Added Azure CLI validation with version check and authentication
- ➕ Added Bicep CLI validation with version check
- ➕ Added Azure Resource Provider registration validation
- ➕ Added Azure quota information check
- ⬆️ Updated .NET SDK requirement to version 10.0
- 📝 Enhanced error messages with actionable guidance
- 📝 Improved verbose logging throughout
- 🎨 Enhanced user interface with better formatting
- 🐛 Fixed comment syntax (changed // to #)

### Version 1.0.0
- Initial release with basic PowerShell and .NET SDK validation
- Integration with clean-secrets.ps1
