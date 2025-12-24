# clean-secrets (.ps1 / .sh)

![PowerShell](https://img.shields.io/badge/PowerShell-7.0+-blue.svg)
![Bash](https://img.shields.io/badge/Bash-4.0+-green.svg)
![.NET](https://img.shields.io/badge/.NET-10.0+-purple.svg)
![Cross-Platform](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey.svg)
![Version](https://img.shields.io/badge/version-2.0.0-green.svg)
![License](https://img.shields.io/badge/license-MIT-orange.svg)

## 📋 Overview

The `clean-secrets` script is a utility tool in the Developer Inner Loop Workflow that safely clears .NET user secrets from all projects in the Azure Logic Apps Monitoring solution. Available in both PowerShell (`.ps1`) and Bash (`.sh`) versions, it provides cross-platform support for managing local development secrets stored in user-specific directories.

This script operates as a helper utility called by both `preprovision` and `postprovision` scripts to ensure a clean state before configuring new secrets. It validates .NET SDK availability, confirms user intent (unless forced), and systematically clears secrets from three target projects: app.AppHost, eShop.Orders.API, and eShop.Web.App. The operation is non-destructive to project files, only removing secrets from the local user secrets storage.

By providing multiple execution modes (interactive, force, preview, verbose), the script supports various workflows from manual troubleshooting to automated CI/CD pipelines, completing typical operations in 2-4 seconds with comprehensive error handling and detailed logging capabilities.

## 📑 Table of Contents

- [Overview](#-overview)
- [Purpose](#-purpose)
- [Target Projects](#️-target-projects)
- [Usage](#-usage)
  - [Basic Usage](#basic-usage)
  - [Force Mode](#force-mode-no-confirmation)
  - [Preview Mode](#preview-mode-whatif)
  - [Verbose Mode](#verbose-mode)
  - [Combined Options](#combined-options)
- [Parameters](#-parameters)
- [Examples](#-examples)
- [How It Works](#️-how-it-works)
  - [Internal Process Flow](#internal-process-flow)
  - [Integration Points](#integration-points)
- [Troubleshooting](#️-troubleshooting)
- [Technical Implementation](#-technical-implementation)
- [Related Documentation](#-related-documentation)
- [Security Considerations](#-security-considerations)
- [Best Practices](#-best-practices)
- [Performance](#-performance)
- [Version History](#-version-history)

## 🎯 Purpose

This script helps developers and operators:
- 🧹 **Clear Secrets**: Remove all user secrets from configured projects
- 🔄 **Reset State**: Prepare for fresh configuration during re-provisioning
- 🔍 **Troubleshoot**: Eliminate stale secrets when debugging configuration issues
- ✅ **Safe Execution**: Validate .NET SDK availability before making changes
- 📊 **Detailed Logging**: Track which secrets are cleared and provide execution summary
- 🔗 **Workflow Integration**: Automatically invoked by preprovision and postprovision scripts

## 🏗️ Target Projects

The script clears user secrets from three projects:

| Project | Path | Secret ID Required |
|---------|------|-------------------|
| **App Host** | `app.AppHost/app.AppHost.csproj` | Yes |
| **Orders API** | `src/eShop.Orders.API/eShop.Orders.API.csproj` | Yes |
| **Web App** | `src/eShop.Web.App/eShop.Web.App.csproj` | Yes |

### How User Secrets Work

.NET user secrets are stored in:
- **Windows**: `%APPDATA%\Microsoft\UserSecrets\<user-secrets-id>\secrets.json`
- **Linux/macOS**: `~/.microsoft/usersecrets/<user-secrets-id>/secrets.json`

Each project has a unique `UserSecretsId` in its `.csproj` file:

```xml
<PropertyGroup>
  <UserSecretsId>12345678-1234-1234-1234-123456789012</UserSecretsId>
</PropertyGroup>
```

## 🚀 Usage

### Basic Usage

**PowerShell (Windows):**
```powershell
# Interactive mode - prompts for confirmation
.\clean-secrets.ps1
```

**Bash (Linux/macOS):**
```bash
# Interactive mode - prompts for confirmation
./clean-secrets.sh
```

**Confirmation Prompt:**
```
Confirm
Are you sure you want to clear user secrets for all projects?
This action will remove all stored secrets from:
  - app.AppHost
  - eShop.Orders.API
  - eShop.Web.App

[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"):
```

### Force Mode (No Confirmation)

**PowerShell (Windows):**
```powershell
# Skip all confirmation prompts
.\clean-secrets.ps1 -Force
```

**Bash (Linux/macOS):**
```bash
# Skip all confirmation prompts
./clean-secrets.sh --force
```

**Output:**
```
[10:15:30] Starting user secrets cleanup...
[10:15:31] ✓ .NET SDK validated (version 10.0.0)
[10:15:32] ✓ Cleared secrets for app.AppHost
[10:15:33] ✓ Cleared secrets for eShop.Orders.API
[10:15:34] ✓ Cleared secrets for eShop.Web.App

Summary:
  Total projects: 3
  Cleared successfully: 3
  Errors: 0

Operation completed successfully in 4.2 seconds.
```

### Preview Mode (WhatIf)

**PowerShell (Windows):**
```powershell
# Show what would be cleared without making changes
.\clean-secrets.ps1 -WhatIf
```

**Bash (Linux/macOS):**
```bash
# Show what would be cleared without making changes
./clean-secrets.sh --dry-run
```

**Output:**
```
What if: Performing operation "Clear User Secrets" on target "app.AppHost".
What if: Performing operation "Clear User Secrets" on target "eShop.Orders.API".
What if: Performing operation "Clear User Secrets" on target "eShop.Web.App".

No changes were made. This was a simulation.
```

### Verbose Mode

**PowerShell (Windows):**
```powershell
# Get detailed execution information
.\clean-secrets.ps1 -Verbose
```

**Bash (Linux/macOS):**
```bash
# Get detailed execution information
./clean-secrets.sh --verbose
```

**Output:**
```
VERBOSE: Script started at 2025-12-24 10:15:30
VERBOSE: Validating .NET SDK availability...
VERBOSE: Found .NET SDK version: 10.0.0
VERBOSE: .NET SDK validation: PASS
VERBOSE: Processing project: app.AppHost
VERBOSE: Project path: Z:\Azure-LogicApps-Monitoring\app.AppHost\app.AppHost.csproj
VERBOSE: Executing: dotnet user-secrets clear --project "app.AppHost.csproj"
VERBOSE: Successfully cleared secrets for app.AppHost
VERBOSE: Processing project: eShop.Orders.API
...
```

### Combined Options

**PowerShell (Windows):**
```powershell
# Preview with verbose output
.\clean-secrets.ps1 -WhatIf -Verbose

# Force execution with verbose logging
.\clean-secrets.ps1 -Force -Verbose
```

**Bash (Linux/macOS):**
```bash
# Preview with verbose output
./clean-secrets.sh --dry-run --verbose

# Force execution with verbose logging
./clean-secrets.sh --force --verbose
```

## 🔧 Parameters

### `-Force` (PowerShell) / `--force` (Bash)

Skips all confirmation prompts and forces immediate execution.

**Type:** `SwitchParameter` (PowerShell) / `Flag` (Bash)  
**Required:** No  
**Default:** `$false` / `false`  
**Confirm Impact:** High (requires confirmation without `-Force`/`--force`)

**PowerShell Example:**
```powershell
.\clean-secrets.ps1 -Force
```

**Bash Example:**
```bash
./clean-secrets.sh --force
```

**Use Cases:**
- Automated CI/CD pipelines
- Scripted provisioning workflows
- Batch operations
- Non-interactive environments

---

### `-WhatIf` (PowerShell) / `--dry-run` (Bash)

Shows what operations would be performed without making actual changes.

**Type:** `SwitchParameter` (PowerShell built-in) / `Flag` (Bash)  
**Required:** No  
**Default:** `$false` / `false`

**PowerShell Example:**
```powershell
.\clean-secrets.ps1 -WhatIf
```

**Bash Example:**
```bash
./clean-secrets.sh --dry-run
```

**Use Cases:**
- Verifying script behavior before execution
- Auditing planned changes
- Training and demonstrations
- Testing script logic

---

### `-Confirm`

Prompts for confirmation before each operation.

**Type:** `SwitchParameter` (built-in)  
**Required:** No  
**Default:** `$true` (due to `ConfirmImpact = 'High'`)

**Example:**
```powershell
# Explicitly request confirmation
.\clean-secrets.ps1 -Confirm

# Suppress confirmation (same as -Force)
.\clean-secrets.ps1 -Confirm:$false
```

---

### `-Verbose` (PowerShell) / `--verbose` (Bash)

Enables detailed diagnostic output for troubleshooting.

**Type:** `SwitchParameter` (PowerShell built-in) / `Flag` (Bash)  
**Required:** No  
**Default:** `$false` / `false`

**PowerShell Example:**
```powershell
.\clean-secrets.ps1 -Verbose
```

**Bash Example:**
```bash
./clean-secrets.sh --verbose
```

**Use Cases:**
- Troubleshooting failures
- Debugging script execution
- Generating detailed logs
- Understanding internal operations

## 📚 Examples

### Example 1: Clean Secrets Before Re-provisioning

**PowerShell (Windows):**
```powershell
# Scenario: About to run 'azd provision' and want clean state
cd Z:\Azure-LogicApps-Monitoring\hooks

# Clear all existing secrets
.\clean-secrets.ps1 -Force

# Proceed with provisioning
cd ..
azd provision
```

**Bash (Linux/macOS):**
```bash
# Scenario: About to run 'azd provision' and want clean state
cd /path/to/Azure-LogicApps-Monitoring/hooks

# Clear all existing secrets
./clean-secrets.sh --force

# Proceed with provisioning
cd ..
azd provision
```

---

### Example 2: CI/CD Pipeline Integration

**PowerShell (Windows):**
```powershell
# In CI/CD pipeline script
$ErrorActionPreference = 'Stop'

try {
    # Clear secrets non-interactively
    & ./hooks/clean-secrets.ps1 -Force
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clear secrets"
    }
    
    Write-Host "✓ Secrets cleared successfully"
}
catch {
    Write-Error "Secret clearing failed: $_"
    exit 1
}
```

**Bash (Linux/macOS):**
```bash
# In CI/CD pipeline script
set -e  # Exit on error

# Clear secrets non-interactively
if ./hooks/clean-secrets.sh --force; then
    echo "✓ Secrets cleared successfully"
else
    echo "ERROR: Secret clearing failed" >&2
    exit 1
fi
```

---

## 🛠️ How It Works

### Internal Process Flow

The script executes a systematic secret clearing workflow through five distinct phases:

```mermaid
flowchart LR
    Start(["🚀 clean-secrets starts"])
    Validate["1️⃣ Prerequisites Validation<br/>• PowerShell 7.0+ check<br/>• .NET SDK availability<br/>• Project files existence"]
    Confirm{"2️⃣ User Confirmation<br/>Required?"}
    ForceMode["Force mode: Skip confirmation"]
    PromptUser{"Prompt user:<br/>Clear all secrets?"}
    UserDecision{"User<br/>response?"}
    Declined["❌ User declined<br/>Exit code: 0<br/>No changes made"]
    Clear["3️⃣ Sequential Clearing<br/>• app.AppHost<br/>• eShop.Orders.API<br/>• eShop.Web.App"]
    Track["4️⃣ Track Results<br/>• Success count<br/>• Error count<br/>• Execution time"]
    Summary["5️⃣ Display Summary<br/>• Total: 3 projects<br/>• Cleared: X<br/>• Errors: Y<br/>• Time: Z seconds"]
    End(["🏁 Script completes"])
    
    Start --> Validate
    Validate --> Confirm
    Confirm -->|Force flag set| ForceMode
    Confirm -->|No force flag| PromptUser
    ForceMode --> Clear
    PromptUser --> UserDecision
    UserDecision -->|Yes/Yes to All| Clear
    UserDecision -->|No/No to All| Declined
    Declined --> End
    Clear --> Track
    Track --> Summary
    Summary --> End
    
    classDef startEnd fill:#e8f5e9,stroke:#2e7d32,stroke-width:3px,color:#1b5e20
    classDef process fill:#e3f2fd,stroke:#1976d2,stroke-width:2px,color:#0d47a1
    classDef decision fill:#fff3e0,stroke:#f57c00,stroke-width:2px,color:#e65100
    classDef clear fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px,color:#4a148c
    classDef declined fill:#ffebee,stroke:#c62828,stroke-width:2px,color:#b71c1c
    
    class Start,End startEnd
    class Validate,ForceMode,Track,Summary process
    class Confirm,PromptUser,UserDecision decision
    class Clear clear
    class Declined declined
```

**Process Details:**

1. **Prerequisites Validation**: Verifies PowerShell version, .NET SDK installation, and project file existence
2. **User Confirmation**: Either skips confirmation with `-Force` flag or prompts user interactively
3. **Sequential Clearing**: Clears secrets from each project using `dotnet user-secrets clear` command
4. **Track Results**: Monitors success/failure status for each project operation
5. **Display Summary**: Outputs detailed execution results including timing and error counts

### Integration Points

| Aspect | Details |
|--------|---------|  
| **Called By** | • `preprovision.ps1` or `preprovision.sh` before infrastructure provisioning<br/>• `postprovision.ps1` or `postprovision.sh` before setting new secrets<br/>• Developers manually for troubleshooting configuration issues<br/>• CI/CD pipelines during automated deployment workflows |
| **Calls** | • `dotnet user-secrets clear` for each target project<br/>• `dotnet --version` for SDK validation<br/>• .NET CLI commands to manage local user secrets storage<br/>• No external APIs or network calls |
| **Dependencies** | • **Runtime:** PowerShell 7.0+ or Bash 4.0+<br/>• **.NET SDK:** Version 10.0+ with user-secrets CLI tool<br/>• **Projects:** app.AppHost, eShop.Orders.API, eShop.Web.App with UserSecretsId configured<br/>• **File System:** Access to user secrets directory (Windows: %APPDATA%, Linux/macOS: ~/.microsoft) |
| **Outputs** | • **Exit Code:** `0` (success/user declined) or `1` (failure/errors occurred)<br/>• **Console Output:** Timestamped messages for each operation with success/failure indicators<br/>• **Summary Report:** Total projects processed, success count, error count, execution time<br/>• **Verbose Logs:** Detailed diagnostic information including paths and command execution (optional) |
| **Integration Role** | Acts as a **state reset utility** ensuring a clean slate for secret management. Prevents stale or conflicting configurations by clearing all local user secrets before provisioning or when troubleshooting. Critical for environment consistency across development, CI/CD, and re-provisioning scenarios. |

#### `Test-DotNetSDK`
Validates that .NET SDK is available and accessible.

```powershell
function Test-DotNetSDK {
    try {
        $version = dotnet --version
        Write-Verbose ".NET SDK version: $version"
        return $true
    }
    catch {
        Write-Error ".NET SDK not found. Please install .NET SDK 10.0+"
        return $false
    }
}
```

#### `Clear-ProjectSecrets`
Clears secrets for a specific project.

```powershell
function Clear-ProjectSecrets {
    param(
        [string]$ProjectName,
        [string]$ProjectPath
    )
    
    if ($PSCmdlet.ShouldProcess($ProjectName, "Clear User Secrets")) {
        dotnet user-secrets clear --project $ProjectPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Information "✓ Cleared secrets for $ProjectName"
            return $true
        }
        else {
            Write-Warning "Failed to clear secrets for $ProjectName"
            return $false
        }
    }
}
```

#### `Get-ProjectsList`
Returns array of projects with their paths.

```powershell
function Get-ProjectsList {
    return @(
        @{
            Name = "app.AppHost"
            Path = "..\app.AppHost\app.AppHost.csproj"
        },
        @{
            Name = "eShop.Orders.API"
            Path = "..\src\eShop.Orders.API\eShop.Orders.API.csproj"
        },
        @{
            Name = "eShop.Web.App"
            Path = "..\src\eShop.Web.App\eShop.Web.App.csproj"
        }
    )
}
```

## ⚠️ Troubleshooting

### Common Issues and Solutions

#### Issue: .NET SDK Not Found

**Error Message:**
```
ERROR: .NET SDK not found
Please install .NET SDK 10.0+
```

**Solution:**
```powershell
# Download and install .NET SDK 10.0+
# https://dotnet.microsoft.com/download

# Verify installation
dotnet --version

# Restart terminal and try again
.\clean-secrets.ps1
```

---

#### Issue: Project File Not Found

**Error Message:**
```
ERROR: Project file not found
Path: Z:\Azure-LogicApps-Monitoring\app.AppHost\app.AppHost.csproj
```

**Solution:**
```powershell
# Ensure you're in the hooks directory
cd Z:\Azure-LogicApps-Monitoring\hooks

# Verify project structure
Test-Path ..\app.AppHost\app.AppHost.csproj

# If false, check repository integrity
git status
```

---

#### Issue: User Secrets Not Configured

**Error Message:**
```
Could not find the global property 'UserSecretsId' in MSBuild project
```

**Explanation:**
This error occurs when a project doesn't have user secrets configured. This is normal if the project hasn't been initialized with secrets yet.

**Solution:**
```powershell
# Initialize user secrets for the project
dotnet user-secrets init --project ..\app.AppHost\app.AppHost.csproj

# Verify secrets ID was added
Select-String -Path ..\app.AppHost\app.AppHost.csproj -Pattern "UserSecretsId"
```

---

#### Issue: Permission Denied

**Error Message:**
```
Access to the path 'C:\Users\...\Microsoft\UserSecrets\...' is denied
```

**Solution:**
```powershell
# Run PowerShell as Administrator (Windows)
Start-Process pwsh -Verb RunAs

# Navigate to hooks directory
cd Z:\Azure-LogicApps-Monitoring\hooks

# Run script
.\clean-secrets.ps1 -Force
```

---

#### Issue: Script Execution Policy

**Error Message:**
```
.\clean-secrets.ps1 : File cannot be loaded because running scripts is disabled
```

**Solution:**
```powershell
# Check current execution policy
Get-ExecutionPolicy

# Set execution policy (current user)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify
Get-ExecutionPolicy

# Run script
.\clean-secrets.ps1
```

---
## 🔧 Technical Implementation

This section provides technical details about the clean-secrets.ps1 implementation.

### How It Works

**Project Discovery Process:**
```powershell
# 1. Find solution file
$solutionPath = Get-ChildItem -Path $PSScriptRoot -Filter "*.sln" -Recurse

# 2. Parse project references
$projects = dotnet sln $solutionPath list | Select-Object -Skip 2

# 3. For each project, check for UserSecretsId
foreach ($project in $projects) {
    $projectXml = [xml](Get-Content $project)
    $secretId = $projectXml.Project.PropertyGroup.UserSecretsId
    
    if ($secretId) {
        # 4. Clear secrets
        dotnet user-secrets clear --project $project
    }
}
```

**Target Projects in This Repository:**

1. **app.AppHost**
   - Path: `app.AppHost/app.AppHost.csproj`
   - UserSecretsId: Generated GUID
   - Purpose: Aspire orchestration secrets

2. **eShop.Orders.API**
   - Path: `src/eShop.Orders.API/eShop.Orders.API.csproj`
   - UserSecretsId: Generated GUID
   - Purpose: API connection strings and keys

3. **eShop.Web.App**
   - Path: `src/eShop.Web.App/eShop.Web.App.csproj`
   - UserSecretsId: Generated GUID
   - Purpose: Web app configuration

### Secret Storage Location

**Windows:**
```
%APPDATA%\Microsoft\UserSecrets\<UserSecretsId>\secrets.json
```

**Linux/macOS:**
```
~/.microsoft/usersecrets/<UserSecretsId>/secrets.json
```

**What Gets Cleared:**
- All key-value pairs in secrets.json
- File remains but content becomes `{}`
- UserSecretsId in .csproj is preserved

### Integration with Deployment Workflow

**Workflow Position:**
```mermaid
graph LR
    A[check-dev-workstation] --> B[preprovision]
    B --> C[clean-secrets]
    C --> D[azd provision]
    D --> E[postprovision]
    
    style C fill:#ff6b6b,color:#fff
```

**Called By:**
- **preprovision.ps1** - Before provisioning (unless `-SkipSecretsClear`)
- **postprovision.ps1** - Before setting new secrets
- **Manual execution** - For troubleshooting

**Call Chain:**
```
preprovision.ps1
  └─> Invoke-CleanSecrets function
       └─> .\clean-secrets.ps1 -Force
```

### Error Handling

**Common Errors & Solutions:**

1. **"dotnet command not found"**
   - Cause: .NET SDK not installed
   - Solution: Install .NET SDK 10.0+

2. **"Project does not contain UserSecretsId"**
   - Cause: Project not initialized for user secrets
   - Solution: Run `dotnet user-secrets init --project <path>`

3. **"Access denied to secrets file"**
   - Cause: File permissions issue
   - Solution: Run PowerShell as Administrator

4. **"Project file not found"**
   - Cause: Incorrect path or missing project
   - Solution: Verify project exists and .csproj path is correct

### Performance Metrics

**Execution Time:**
- Single project: < 1 second
- Three projects: 2-3 seconds
- **Fast:** Minimal I/O operations

**Operations Performed:**
- Find .sln file: 1 file system scan
- Parse project list: 1 dotnet sln command
- Clear secrets: 3 dotnet user-secrets commands

### Security Considerations

**What This Script Does NOT Do:**
- ❌ Does not access or read secret values
- ❌ Does not transmit secrets over network
- ❌ Does not log secret values
- ❌ Does not modify .csproj files

**What This Script DOES Do:**
- ✅ Clears secrets from local file system only
- ✅ Preserves UserSecretsId configuration
- ✅ Logs project paths (not secret values)
- ✅ Uses official .NET CLI commands

**Best Practices:**
- Always clear secrets before provisioning (prevents stale data)
- Never commit secrets.json to source control (already in .gitignore)
- Use Azure Key Vault for production secrets
- Rotate secrets regularly

---
## 📖 Related Documentation

- **[postprovision.ps1](./postprovision.md)** - Sets user secrets after provisioning (inverse operation)
- **[preprovision.ps1](./preprovision.ps1)** - Calls this script during pre-provisioning
- **[check-dev-workstation.md](./check-dev-workstation.md)** - Environment validation
- **[Main README](./README.md)** - Hooks directory overview
- **[.NET User Secrets](https://learn.microsoft.com/aspnet/core/security/app-secrets)** - Official Microsoft documentation

## 🔐 Security Considerations

### Safe Operations

✅ **Safe to Run:**
- Only modifies user-secrets storage (not project files)
- Does not modify source code
- Does not affect production environments
- Local operation only (no network calls)
- Idempotent (can run multiple times safely)

### What Gets Deleted

This script clears:
- Connection strings stored in user secrets
- API keys stored in user secrets
- Azure resource information stored in user secrets
- Application configuration stored in user secrets

This script does **NOT** affect:
- appsettings.json files
- appsettings.Development.json files
- Environment variables
- Azure Key Vault secrets
- Production secrets
- Source code

### When to Run

| Scenario | Safe to Run? | Notes |
|----------|--------------|-------|
| **Local Development** | ✅ Yes | Standard use case |
| **Before Provisioning** | ✅ Yes | Ensures clean state |
| **CI/CD Pipeline** | ✅ Yes | Use `-Force` flag |
| **Production Environment** | ⚠️ No | Never affects production |
| **Shared Workstation** | ⚠️ Caution | Other users affected |

## 🎓 Best Practices

### When to Use This Script

| Situation | Recommendation |
|-----------|----------------|
| **Before `azd provision`** | ✅ Recommended |
| **After failed provisioning** | ✅ Recommended |
| **Configuration errors** | ✅ Recommended |
| **Switching environments** | ✅ Recommended |
| **Team onboarding** | ✅ Recommended |
| **Regular development** | ⚠️ Only if needed |

### Development Workflow Integration

```powershell
# Typical re-provisioning workflow

# Step 1: Clear old secrets
.\hooks\clean-secrets.ps1 -Force

# Step 2: Provision fresh infrastructure
azd provision

# Step 3: Verify new secrets were set
dotnet user-secrets list --project app.AppHost\app.AppHost.csproj

# Step 4: Run application
azd up
```

### Team Standards

**Recommended Practices:**
1. **Document Usage**: Add to team's runbook
2. **CI/CD Integration**: Include in deployment scripts
3. **Error Handling**: Always check exit codes
4. **Verbose Logging**: Use `-Verbose` in CI/CD for audit trails
5. **Regular Execution**: Clear secrets before each provisioning

## 📊 Performance

### Performance Characteristics

| Characteristic | Details |
|----------------|---------|
| **Execution Time** | • **Standard execution:** 2-4 seconds (3 projects)<br/>• **With -Verbose flag:** 3-5 seconds<br/>• **Large number of secrets:** 5-8 seconds<br/>• **Per-project time:** ~1 second (dotnet user-secrets clear)<br/>• **Scaling:** Linear O(n) with number of projects |
| **Resource Usage** | • **Memory:** ~30 MB peak during execution<br/>• **CPU:** Low utilization - dotnet CLI operations only<br/>• **Disk I/O:** Minimal delete operations on secrets.json files<br/>• **Process spawning:** 3 dotnet CLI child processes<br/>• **Baseline:** Lightweight script with minimal overhead |
| **Network Impact** | • **Zero network calls** - completely offline operation<br/>• **No Azure connections** - local file system only<br/>• **No API requests** - uses .NET SDK local commands<br/>• **Ideal for disconnected environments**<br/>• **No bandwidth consumption** |
| **Scalability** | • **Consistent per-project time:** No degradation with secrets count<br/>• **Parallel safe:** Can run in multiple terminals (different projects)<br/>• **No locking issues:** Each project has unique secret storage<br/>• **Fast completion:** 3 projects cleared in under 5 seconds |
| **Optimization** | • **Sequential processing:** Projects cleared one at a time<br/>• **No redundant checks:** Direct dotnet CLI invocation<br/>• **Minimal validation:** Only checks .NET SDK availability<br/>• **Efficient operation:** Single delete per project<br/>• **No caching needed:** Direct file system operations |

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| **2.0.0** | 2025-12-24 | Production release |
|           |            | • Complete rewrite with best practices |
|           |            | • Added comprehensive error handling |
|           |            | • Implemented validation functions |
|           |            | • Added WhatIf support |
|           |            | • Comprehensive logging |
|           |            | • 420+ lines of production code |
| **1.0.0** | 2025-12-15 | Initial release |
|           |            | • Basic secret clearing |

##  Quick Links

- **Repository**: [Azure-LogicApps-Monitoring](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)
- **Issues**: [Report Bug](https://github.com/Evilazaro/Azure-LogicApps-Monitoring/issues)
- **User Secrets Docs**: [Microsoft Learn](https://learn.microsoft.com/aspnet/core/security/app-secrets)

---

**Last Updated**: December 24, 2025  
**Script Version**: 2.0.0  
**Compatibility**: PowerShell 7.0+, .NET 10.0+, Windows/macOS/Linux

---

**Made with ❤️ by Evilazaro | Principal Cloud Solution Architect | Microsoft**
