# preprovision.ps1 - Quick Reference Guide

## Synopsis
Validates all prerequisites before Azure provisioning and clears user secrets.

## Syntax

```powershell
.\hooks\preprovision.ps1 
    [-ValidateOnly]
    [-SkipSecretsClear]
    [-Force]
    [-WhatIf]
    [-Confirm]
    [-Verbose]
    [<CommonParameters>]
```

## Parameters

### -ValidateOnly
**Type**: Switch  
**Required**: No  
**Description**: Performs validation only without clearing user secrets.

**Example**:
```powershell
.\hooks\preprovision.ps1 -ValidateOnly
```

**Use Case**: Check if environment is ready without making changes.

---

### -SkipSecretsClear
**Type**: Switch  
**Required**: No  
**Description**: Skips the user secrets clearing step.

**Example**:
```powershell
.\hooks\preprovision.ps1 -SkipSecretsClear
```

**Use Case**: When you want validation but need to preserve secrets.

---

### -Force
**Type**: Switch  
**Required**: No  
**Description**: Forces execution without confirmation prompts.

**Example**:
```powershell
.\hooks\preprovision.ps1 -Force
```

**Use Case**: Automated execution in CI/CD pipelines.

---

### -WhatIf
**Type**: Switch  
**Required**: No  
**Description**: Shows what would happen without actually executing.

**Example**:
```powershell
.\hooks\preprovision.ps1 -WhatIf
```

**Use Case**: Preview changes before execution.

---

### -Confirm
**Type**: Switch  
**Required**: No  
**Description**: Prompts for confirmation before each operation.

**Example**:
```powershell
.\hooks\preprovision.ps1 -Confirm
```

**Use Case**: Interactive mode with confirmation prompts.

---

### -Verbose
**Type**: Switch  
**Required**: No  
**Description**: Displays detailed information about each step.

**Example**:
```powershell
.\hooks\preprovision.ps1 -Verbose
```

**Use Case**: Troubleshooting or detailed logging.

---

## Common Scenarios

### 1. First-Time Setup Validation
Check if your environment is ready before attempting deployment:
```powershell
.\hooks\preprovision.ps1 -ValidateOnly -Verbose
```

### 2. Automated CI/CD Execution
Run in pipeline without prompts:
```powershell
.\hooks\preprovision.ps1 -Force -InformationAction Continue
```

### 3. Development Testing
Preview changes without executing:
```powershell
.\hooks\preprovision.ps1 -WhatIf -Verbose
```

### 4. Troubleshooting
Get maximum diagnostic information:
```powershell
.\hooks\preprovision.ps1 -ValidateOnly -Verbose -InformationAction Continue
```

### 5. Skip Secret Clearing
Validate and run but keep existing secrets:
```powershell
.\hooks\preprovision.ps1 -SkipSecretsClear -Force
```

---

## What Gets Validated

| Component | Requirement | Check Performed |
|-----------|-------------|----------------|
| **PowerShell** | Version 7.0+ | Version comparison |
| **.NET SDK** | Version 10.0+ | Version check via `dotnet --version` |
| **Azure Developer CLI** | Latest | Command availability check |
| **Azure CLI** | Version 2.60.0+ | Version + authentication status |
| **Bicep CLI** | Version 0.30.0+ | Version check via Azure CLI or standalone |
| **Resource Providers** | 8 providers | Registration status in active subscription |
| **Azure Subscription** | Active | Authentication and access validation |

### Required Azure Resource Providers
1. `Microsoft.App` (Container Apps)
2. `Microsoft.ServiceBus` (Service Bus)
3. `Microsoft.Storage` (Storage Accounts)
4. `Microsoft.Web` (Logic Apps Standard)
5. `Microsoft.ContainerRegistry` (Container Registry)
6. `Microsoft.Insights` (Application Insights)
7. `Microsoft.OperationalInsights` (Log Analytics)
8. `Microsoft.ManagedIdentity` (Managed Identities)

---

## Exit Codes

| Code | Meaning | Description |
|------|---------|-------------|
| 0 | Success | All validations passed, secrets cleared (if applicable) |
| 1 | Failure | One or more validations failed or error occurred |

**CI/CD Integration**:
```yaml
- name: Run Pre-Provisioning
  run: |
    pwsh -File ./hooks/preprovision.ps1 -Force
  continue-on-error: false
```

---

## Output Examples

### ✅ Successful Validation
```
╔════════════════════════════════════════════════════════════════╗
║          Azure Pre-Provisioning Script                        ║
╚════════════════════════════════════════════════════════════════╝

  Version:          2.0.0
  Execution Time:   2025-12-24 09:35:22
  PowerShell:       7.5.4

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

  ✓ All prerequisites validated successfully

────────────────────────────────────────────────────────────────
  Status:           ✓ SUCCESS
  Duration:         16.13 seconds
╔════════════════════════════════════════════════════════════════╗
║   Pre-provisioning completed successfully!                    ║
╚════════════════════════════════════════════════════════════════╝
```

### ❌ Failed Validation (Missing Azure CLI)
```
Step 2: Validating prerequisites...
  • Checking Azure CLI...
WARNING:     ✗ Azure CLI 2.60.0 or higher is required
WARNING:       Install from: https://docs.microsoft.com/cli/azure/install-azure-cli
WARNING:       After installation, authenticate with: az login

ERROR: One or more required prerequisites are missing or not configured.

────────────────────────────────────────────────────────────────
  Status:           ✗ FAILED
  Duration:         2.45 seconds
╔════════════════════════════════════════════════════════════════╗
║   Pre-provisioning completed with errors.                     ║
╚════════════════════════════════════════════════════════════════╝
```

### ⚠️ Missing Resource Providers
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
```

---

## Troubleshooting

### "PowerShell version X is not supported"
**Solution**: Install PowerShell 7.0 or higher
```powershell
# Windows
winget install Microsoft.PowerShell

# macOS
brew install powershell/tap/powershell

# Linux
# Follow: https://learn.microsoft.com/powershell/scripting/install/installing-powershell
```

### "Azure CLI X or higher is required"
**Solution**: Install or upgrade Azure CLI
```powershell
# Windows
winget install Microsoft.AzureCLI

# macOS
brew update && brew install azure-cli

# Linux
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### "User is not authenticated to Azure"
**Solution**: Login to Azure
```powershell
az login
az account set --subscription "Your Subscription Name"
```

### "Bicep CLI X or higher is required"
**Solution**: Install or upgrade Bicep
```powershell
az bicep install
# Or upgrade existing
az bicep upgrade
```

### ".NET SDK 10.0 or higher is required"
**Solution**: Install .NET 10.0 SDK
```powershell
# Download from: https://dotnet.microsoft.com/download/dotnet/10.0
# Or use winget
winget install Microsoft.DotNet.SDK.10
```

### "Azure Developer CLI (azd) is required"
**Solution**: Install azd
```powershell
# Windows
winget install microsoft.azd

# macOS
brew tap azure/azd && brew install azd

# Linux
curl -fsSL https://aka.ms/install-azd.sh | bash
```

### Resource Providers Not Registered
**Solution**: Register required providers
```powershell
# Register all required providers
$providers = @(
    'Microsoft.App',
    'Microsoft.ServiceBus',
    'Microsoft.Storage',
    'Microsoft.Web',
    'Microsoft.ContainerRegistry',
    'Microsoft.Insights',
    'Microsoft.OperationalInsights',
    'Microsoft.ManagedIdentity'
)

foreach ($provider in $providers) {
    az provider register --namespace $provider --wait
}
```

---

## Environment Variables

### Optional Configuration
```powershell
# Set custom information preference
$InformationPreference = 'Continue'  # Show all info messages

# Set custom Azure subscription
az account set --subscription "Your-Subscription-ID"

# Set custom region (if needed)
$env:AZURE_LOCATION = "eastus"
```

---

## Integration Points

### azure.yaml
The script is automatically called by Azure Developer CLI:
```yaml
hooks:
  preprovision:
    windows:
      shell: pwsh
      run: ./hooks/preprovision.ps1
    posix:
      shell: sh
      run: ./hooks/preprovision.sh
```

### GitHub Actions
```yaml
- name: Pre-provision validation
  run: |
    pwsh -Command ".\hooks\preprovision.ps1 -Force -InformationAction Continue"
  shell: pwsh
```

### Azure DevOps
```yaml
- task: PowerShell@2
  displayName: 'Pre-provision validation'
  inputs:
    targetType: 'filePath'
    filePath: './hooks/preprovision.ps1'
    arguments: '-Force -InformationAction Continue'
    pwsh: true
```

---

## Performance Notes

- **Typical Execution Time**: 5-20 seconds (depends on Azure CLI calls)
- **ValidateOnly Mode**: Faster (no secrets clearing)
- **Resource Provider Checks**: Can take 10-15 seconds (8 provider status checks)
- **Network Dependency**: Requires internet for Azure CLI operations

---

## Best Practices

1. ✅ **Always run ValidateOnly first** in new environments
2. ✅ **Use -Verbose** when troubleshooting
3. ✅ **Run -WhatIf** before automation changes
4. ✅ **Check exit codes** in CI/CD pipelines
5. ✅ **Review warnings** even if script succeeds
6. ❌ **Don't skip validation** in production deployments
7. ❌ **Don't ignore resource provider warnings**
8. ❌ **Don't run without authentication** to Azure

---

## Quick Links

- [Azure CLI Installation](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Azure Developer CLI](https://aka.ms/azd/install)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [.NET 10.0 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)
- [PowerShell 7.x](https://learn.microsoft.com/powershell/scripting/install/installing-powershell)
- [Azure Resource Providers](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types)

---

## Support

For issues or questions:
1. Check this quick reference guide
2. Run with `-Verbose` flag for detailed diagnostics
3. Review the [PREPROVISION-ENHANCEMENTS.md](PREPROVISION-ENHANCEMENTS.md) document
4. Check Azure authentication: `az account show`
5. Verify tool installations: `dotnet --version`, `az version`, `azd version`

---

## Version
**Script Version**: 2.0.0  
**Last Updated**: 2025-12-24  
**PowerShell Version Required**: 7.0+
