# Azure-LogicApps-Monitoring - Hooks Directory

## Overview
This directory contains PowerShell automation scripts that are executed during the Azure deployment lifecycle via Azure Developer CLI (azd). These scripts ensure that the environment is properly configured and prepared before and after provisioning Azure resources.

## Files in This Directory

### Core Scripts

#### 1. `preprovision.ps1` (Production Script)
**Purpose**: Pre-provisioning validation and preparation  
**Execution**: Automatically called by `azd provision` or `azd up`  
**Version**: 2.0.0  
**Lines of Code**: ~850

**What It Does**:
- ✓ Validates PowerShell 7.0+ is installed
- ✓ Validates .NET SDK 10.0+ is installed and configured
- ✓ Validates Azure Developer CLI (azd) is available
- ✓ Validates Azure CLI 2.60.0+ is installed
- ✓ Validates user is authenticated to Azure subscription
- ✓ Validates Bicep CLI 0.30.0+ is installed
- ✓ Validates 8 required Azure Resource Providers are registered
- ℹ️ Displays Azure subscription quota requirements
- 🧹 Clears user secrets for all projects (optional)

**Usage**:
```powershell
# Validate environment only (no secrets clearing)
.\preprovision.ps1 -ValidateOnly

# Full execution (validation + secrets clearing)
.\preprovision.ps1

# Force execution without prompts (CI/CD)
.\preprovision.ps1 -Force

# Preview changes without executing
.\preprovision.ps1 -WhatIf

# Detailed logging for troubleshooting
.\preprovision.ps1 -Verbose

# Validate but skip secrets clearing
.\preprovision.ps1 -SkipSecretsClear
```

**Parameters**:
- `-ValidateOnly`: Performs validation without clearing secrets
- `-SkipSecretsClear`: Validates and runs but skips secret clearing
- `-Force`: Forces execution without confirmation prompts
- `-WhatIf`: Shows what would happen without executing
- `-Confirm`: Prompts for confirmation before operations
- `-Verbose`: Displays detailed diagnostic information

**Exit Codes**:
- `0`: Success - all validations passed
- `1`: Failure - one or more validations failed

---

#### 2. `clean-secrets.ps1` (Utility Script)
**Purpose**: Clear .NET user secrets for all projects  
**Execution**: Called by `preprovision.ps1` or manually  
**Version**: 1.0.0  
**Lines of Code**: ~450

**What It Does**:
- Scans workspace for .NET projects with user secrets configured
- Clears user secrets using `dotnet user-secrets clear`
- Validates .NET SDK availability before execution
- Provides detailed execution summary

**Usage**:
```powershell
# Interactive mode with confirmation
.\clean-secrets.ps1

# Force mode (no confirmations)
.\clean-secrets.ps1 -Force

# Preview mode
.\clean-secrets.ps1 -WhatIf

# Verbose output
.\clean-secrets.ps1 -Verbose

# Validate only (check what would be cleared)
.\clean-secrets.ps1 -ValidateOnly
```

**Parameters**:
- `-Force`: Skip confirmation prompts
- `-WhatIf`: Show what would be cleared without executing
- `-ValidateOnly`: Validate projects without clearing
- `-Verbose`: Display detailed logging

---

#### 3. `postprovision.ps1` (Placeholder)
**Purpose**: Post-provisioning cleanup and configuration  
**Status**: Placeholder script (minimal functionality)  
**Execution**: Automatically called after `azd provision` completes

**Future Enhancements**:
- Add post-deployment validation
- Configure deployed resources
- Run database migrations
- Seed initial data

---

#### 4. `preprovision.sh` (POSIX Script)
**Purpose**: Linux/macOS equivalent of preprovision.ps1  
**Status**: Not yet implemented  
**Note**: Use PowerShell Core (pwsh) on Linux/macOS instead

---

#### 5. Python Support Scripts

**`generate_orders_script.py`**
**Purpose**: Generates sample order data for testing  
**Execution**: Manual or as part of test data setup  
**Language**: Python 3.x

**`Generate-Orders.ps1`**
**Purpose**: PowerShell wrapper for generate_orders_script.py  
**Execution**: Manual  
**Note**: Provides Windows-friendly interface to Python script

---

### Documentation Files

#### 1. `PREPROVISION-ENHANCEMENTS.md` (~450 lines)
**Comprehensive enhancement documentation**

Contents:
- Overview of enhancements made to preprovision.ps1
- New capabilities and validation functions
- Before/after comparisons
- PowerShell best practices applied
- Usage examples and scenarios
- Error handling examples
- Benefits for developers, CI/CD, and operations
- Future enhancement opportunities
- Changelog

---

#### 2. `PREPROVISION-QUICK-REFERENCE.md` (~400 lines)
**Quick reference guide for preprovision.ps1**

Contents:
- Parameter reference with examples
- Common usage scenarios
- Validation matrix (what gets checked)
- Exit codes and CI/CD integration
- Output examples (success and failure)
- Troubleshooting guide with solutions
- Environment variables
- Integration points (GitHub Actions, Azure DevOps)
- Performance notes
- Best practices

---

#### 3. `ENHANCEMENT-SUMMARY.md` (~350 lines)
**Executive summary of enhancements**

Contents:
- Project context and objectives
- What was accomplished
- Technical improvements and metrics
- Testing results and validation
- Benefits delivered
- Integration points
- Files modified/created
- Compliance with requirements
- Conclusion and key achievements

---

#### 4. `VALIDATION-WORKFLOW.md` (~300 lines)
**Visual workflow documentation**

Contents:
- ASCII art workflow diagrams
- Step-by-step validation flow
- Parameter modes visualization
- Failure handling flowcharts
- Integration points diagrams
- Validation matrix
- Time breakdown analysis
- Success criteria

---

#### 5. `README.md` (This File)
**Directory overview and navigation**

Contents:
- File descriptions
- Quick start guide
- Architecture overview
- Common workflows
- Troubleshooting
- Support information

---

## Quick Start

### First Time Setup
```powershell
# 1. Navigate to repository root
cd Z:\Azure-LogicApps-Monitoring

# 2. Validate your environment
.\hooks\preprovision.ps1 -ValidateOnly -Verbose

# 3. If validation passes, proceed with deployment
azd provision
```

### Daily Development Workflow
```powershell
# Clear secrets before testing
.\hooks\clean-secrets.ps1 -Force

# Run application locally
azd up

# After testing, provision to Azure
azd provision  # Automatically runs preprovision.ps1
```

### CI/CD Pipeline
```yaml
# GitHub Actions example
- name: Pre-provision validation
  run: |
    pwsh -Command ".\hooks\preprovision.ps1 -Force -InformationAction Continue"
  shell: pwsh

- name: Deploy to Azure
  run: azd provision --no-prompt
```

---

## Architecture

### Script Relationships
```
azure.yaml
    │
    └── hooks:
            │
            ├── preprovision (before provisioning)
            │     │
            │     └── preprovision.ps1
            │           │
            │           ├── Test-PowerShellVersion
            │           ├── Test-DotNetSDK
            │           ├── Test-AzureDeveloperCLI
            │           ├── Test-AzureCLI
            │           ├── Test-BicepCLI
            │           ├── Test-AzureResourceProviders
            │           ├── Test-AzureQuota
            │           │
            │           └── Invoke-CleanSecrets
            │                 │
            │                 └── clean-secrets.ps1
            │                       │
            │                       ├── Test-DotNetSDK
            │                       ├── Test-ProjectPaths
            │                       └── Clear-UserSecrets
            │
            └── postprovision (after provisioning)
                  │
                  └── postprovision.ps1
```

---

## Validation Prerequisites

### Required Tools (Validated by preprovision.ps1)

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| **PowerShell** | 7.0 | Script execution environment |
| **.NET SDK** | 10.0 | Build and run .NET Aspire applications |
| **Azure Developer CLI** | Latest | Deployment orchestration (azd) |
| **Azure CLI** | 2.60.0 | Azure resource management |
| **Bicep CLI** | 0.30.0 | Infrastructure as Code deployment |

### Required Azure Configuration

**Azure Authentication**:
- Must be authenticated via `az login`
- Must have active subscription selected
- Must have appropriate permissions (Contributor or Owner)

**Resource Providers** (8 required):
1. `Microsoft.App` - Container Apps
2. `Microsoft.ServiceBus` - Service Bus
3. `Microsoft.Storage` - Storage Accounts
4. `Microsoft.Web` - Logic Apps Standard
5. `Microsoft.ContainerRegistry` - Container Registry
6. `Microsoft.Insights` - Application Insights
7. `Microsoft.OperationalInsights` - Log Analytics
8. `Microsoft.ManagedIdentity` - Managed Identities

**Resource Quotas** (informational):
- Container Apps: Minimum 2
- Storage Accounts: Minimum 3
- Service Bus Namespaces: Minimum 1
- Logic Apps Standard: Minimum 1
- Container Registries: Minimum 1

---

## Common Workflows

### Scenario 1: New Developer Setup
```powershell
# Step 1: Clone repository
git clone <repository-url>
cd Azure-LogicApps-Monitoring

# Step 2: Install prerequisites
# Install PowerShell 7.x, .NET 10.0 SDK, Azure CLI, azd, Bicep

# Step 3: Authenticate to Azure
az login
az account set --subscription "Your-Subscription-Name"

# Step 4: Validate environment
.\hooks\preprovision.ps1 -ValidateOnly -Verbose

# Step 5: If validation passes, deploy
azd up
```

### Scenario 2: Troubleshooting Failed Validation
```powershell
# Get detailed diagnostics
.\hooks\preprovision.ps1 -ValidateOnly -Verbose -InformationAction Continue

# Check specific tools manually
dotnet --version        # Should be 10.0+
az version             # Should be 2.60.0+
az account show        # Should show active subscription
az bicep version       # Should be 0.30.0+
azd version           # Any version

# Check resource provider registration
az provider list --query "[?registrationState=='NotRegistered']" --output table

# Register missing providers
az provider register --namespace Microsoft.App --wait
```

### Scenario 3: CI/CD Pipeline Integration
```yaml
# GitHub Actions
name: Deploy to Azure

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Azure Login
        uses: azure/login@v1
        with:
          creds: ${{ secrets.AZURE_CREDENTIALS }}
      
      - name: Pre-provision validation
        run: |
          .\hooks\preprovision.ps1 -Force -InformationAction Continue
        shell: pwsh
      
      - name: Deploy to Azure
        run: azd provision --no-prompt
        shell: pwsh
```

### Scenario 4: Manual Secret Management
```powershell
# Clear secrets for all projects
.\hooks\clean-secrets.ps1 -Force

# Clear secrets and see what's being cleared
.\hooks\clean-secrets.ps1 -Force -Verbose

# Preview what would be cleared
.\hooks\clean-secrets.ps1 -WhatIf

# Validate projects without clearing
.\hooks\clean-secrets.ps1 -ValidateOnly
```

---

## Troubleshooting

### Common Issues and Solutions

#### Issue: "PowerShell version X is not supported"
**Solution**: Install PowerShell 7.0 or higher
```powershell
winget install Microsoft.PowerShell
```

#### Issue: ".NET SDK 10.0 or higher is required"
**Solution**: Install .NET 10.0 SDK
```powershell
winget install Microsoft.DotNet.SDK.10
# Or download from: https://dotnet.microsoft.com/download/dotnet/10.0
```

#### Issue: "Azure CLI X or higher is required"
**Solution**: Install or upgrade Azure CLI
```powershell
winget install Microsoft.AzureCLI
```

#### Issue: "User is not authenticated to Azure"
**Solution**: Login to Azure
```powershell
az login
az account set --subscription "Your-Subscription-Name"
az account show  # Verify
```

#### Issue: "Bicep CLI X or higher is required"
**Solution**: Install or upgrade Bicep
```powershell
az bicep install
# Or upgrade:
az bicep upgrade
```

#### Issue: "Resource provider not registered"
**Solution**: Register the required provider
```powershell
az provider register --namespace Microsoft.App --wait
az provider register --namespace Microsoft.ServiceBus --wait
# Repeat for each unregistered provider
```

#### Issue: Script execution policy error
**Solution**: Set execution policy
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Performance Considerations

### Execution Times
- **preprovision.ps1 -ValidateOnly**: 14-16 seconds
- **preprovision.ps1 (full)**: 18-22 seconds
- **clean-secrets.ps1**: 2-5 seconds

### Network Dependencies
- Azure CLI operations require internet connectivity
- Resource provider checks make 8 API calls to Azure
- Authentication validation requires Azure subscription access

### Optimization Tips
- Use `-ValidateOnly` when only checking prerequisites
- Use `-SkipSecretsClear` when secrets don't need clearing
- Run with `-Verbose` only when troubleshooting
- Cache tool versions in CI/CD for faster execution

---

## Best Practices

### Development
1. ✅ Always run `-ValidateOnly` before first deployment
2. ✅ Use `-Verbose` when troubleshooting issues
3. ✅ Clear secrets before committing code
4. ✅ Test scripts locally before CI/CD integration
5. ❌ Don't skip prerequisite validation
6. ❌ Don't commit user secrets to source control

### CI/CD
1. ✅ Always use `-Force` parameter in pipelines
2. ✅ Check exit codes (`$LASTEXITCODE`)
3. ✅ Use `-InformationAction Continue` for logging
4. ✅ Run validation as separate step before deployment
5. ❌ Don't ignore validation warnings
6. ❌ Don't deploy without authentication

### Operations
1. ✅ Monitor execution times in logs
2. ✅ Review warnings even if validation passes
3. ✅ Keep documentation up to date
4. ✅ Test in non-production first
5. ❌ Don't bypass validation in production
6. ❌ Don't ignore resource provider registration

---

## Support and Resources

### Documentation
- **Comprehensive Guide**: [PREPROVISION-ENHANCEMENTS.md](PREPROVISION-ENHANCEMENTS.md)
- **Quick Reference**: [PREPROVISION-QUICK-REFERENCE.md](PREPROVISION-QUICK-REFERENCE.md)
- **Enhancement Summary**: [ENHANCEMENT-SUMMARY.md](ENHANCEMENT-SUMMARY.md)
- **Visual Workflow**: [VALIDATION-WORKFLOW.md](VALIDATION-WORKFLOW.md)

### External Links
- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [Azure Developer CLI](https://aka.ms/azd)
- [Bicep Documentation](https://learn.microsoft.com/azure/azure-resource-manager/bicep/)
- [.NET 10.0 Documentation](https://dotnet.microsoft.com/download/dotnet/10.0)
- [PowerShell Documentation](https://learn.microsoft.com/powershell/)

### Getting Help
1. Review the documentation files in this directory
2. Run scripts with `-Verbose` flag for detailed diagnostics
3. Check tool versions: `dotnet --version`, `az version`, `azd version`
4. Verify Azure authentication: `az account show`
5. Review Azure activity log for deployment issues

---

## Contributing

### Adding New Validations
1. Create new `Test-*` function in `preprovision.ps1`
2. Follow existing function structure (CBH, parameters, error handling)
3. Add validation call to Step 2 in main execution block
4. Update documentation (this README and PREPROVISION-*.md files)
5. Test all parameter combinations
6. Update version number and changelog

### Modifying Existing Functions
1. Maintain backward compatibility when possible
2. Update Comment-Based Help (CBH)
3. Test with all parameter combinations
4. Update documentation
5. Update version number

### Documentation Standards
- Use Comment-Based Help for all functions
- Include examples in CBH
- Keep README.md as navigation hub
- Update all affected documentation files
- Use consistent formatting and style

---

## Version History

### Version 2.0.0 (2025-12-24)
- ➕ Added Azure CLI validation with authentication check
- ➕ Added Bicep CLI validation
- ➕ Added Azure Resource Provider registration validation
- ➕ Added Azure quota information display
- ⬆️ Updated .NET SDK requirement to 10.0
- 📝 Enhanced error messages with actionable guidance
- 📝 Comprehensive documentation created (4 files)
- 🎨 Improved user experience with better formatting
- ✅ Fully tested across 6 scenarios

### Version 1.0.0
- Initial release with basic validation
- PowerShell and .NET SDK checks
- Integration with clean-secrets.ps1

---

## License
See [LICENSE](../LICENSE) in repository root.

## Security
See [SECURITY.md](../SECURITY.md) for security policies.

## Code of Conduct
See [CODE_OF_CONDUCT.md](../CODE_OF_CONDUCT.md) for community guidelines.

---

**Last Updated**: 2025-12-24  
**Maintained By**: Azure-LogicApps-Monitoring Team  
**Status**: ✅ Production Ready
