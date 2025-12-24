# Pre-Provisioning Script - Validation Workflow

## Visual Workflow

```
┌─────────────────────────────────────────────────────────────────┐
│                    PREPROVISION.PS1 START                       │
│                      Version 2.0.0                              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 1: PowerShell Version Validation                         │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Test-PowerShellVersion                                   │ │
│  │  • Minimum Required: 7.0                                  │ │
│  │  • Current: 7.5.4                                         │ │
│  └───────────────────────────────────────────────────────────┘ │
└────────────────────────────┬────────────────────────────────────┘
                             │
                       ✓ PASS │ ✗ FAIL
                             │    └──► [ERROR: Upgrade PowerShell]
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 2: Prerequisites Validation                              │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  2.1 Test-DotNetSDK                                       │ │
│  │  • Minimum: 10.0                                          │ │
│  │  • Check: dotnet --version                                │ │
│  │  • Current: 10.0.101                                      │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│        ✓ PASS│ ✗ FAIL                                          │
│              │    └──► [WARN: Install .NET 10.0 SDK]           │
│              ▼                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  2.2 Test-AzureDeveloperCLI                               │ │
│  │  • Check: azd version                                     │ │
│  │  • Current: 1.22.5                                        │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│        ✓ PASS│ ✗ FAIL                                          │
│              │    └──► [WARN: Install azd]                     │
│              ▼                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  2.3 Test-AzureCLI                                        │ │
│  │  • Minimum: 2.60.0                                        │ │
│  │  • Check: az version                                      │ │
│  │  • Check: az account show (authentication)                │ │
│  │  • Current: 2.80.0                                        │ │
│  │  • User: admin@tenant.onmicrosoft.com                     │ │
│  │  • Subscription: Active                                   │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│        ✓ PASS│ ✗ FAIL                                          │
│              │    └──► [WARN: Install Azure CLI + az login]   │
│              ▼                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  2.4 Test-BicepCLI                                        │ │
│  │  • Minimum: 0.30.0                                        │ │
│  │  • Check: bicep --version OR az bicep version             │ │
│  │  • Current: 0.39.26                                       │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│        ✓ PASS│ ✗ FAIL                                          │
│              │    └──► [WARN: az bicep install/upgrade]        │
│              ▼                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  2.5 Test-AzureResourceProviders                         │ │
│  │  • Check 8 providers via: az provider show               │ │
│  │    ├─ Microsoft.App                          ✓ Registered│ │
│  │    ├─ Microsoft.ServiceBus                   ✓ Registered│ │
│  │    ├─ Microsoft.Storage                      ✓ Registered│ │
│  │    ├─ Microsoft.Web                          ✓ Registered│ │
│  │    ├─ Microsoft.ContainerRegistry            ✓ Registered│ │
│  │    ├─ Microsoft.Insights                     ✓ Registered│ │
│  │    ├─ Microsoft.OperationalInsights          ✓ Registered│ │
│  │    └─ Microsoft.ManagedIdentity              ✓ Registered│ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│        ✓ PASS│ ✗ FAIL                                          │
│              │    └──► [WARN: az provider register commands]   │
│              ▼                                                  │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  2.6 Test-AzureQuota (Informational)                     │ │
│  │  • Display minimum resource requirements                 │ │
│  │    ├─ Container Apps: 2 minimum                          │ │
│  │    ├─ Storage Accounts: 3 minimum                        │ │
│  │    ├─ Service Bus: 1 minimum                             │ │
│  │    ├─ Logic Apps Standard: 1 minimum                     │ │
│  │    └─ Container Registry: 1 minimum                      │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│              ▼ (Always passes - informational only)            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                   ✓ ALL PASS │ ✗ ANY FAIL
                             │    └──► [ERROR: Fix prerequisites]
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  STEP 3: Clear User Secrets                                    │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Invoke-CleanSecrets                                      │ │
│  │  • Execute: clean-secrets.ps1                             │ │
│  │  • Clears: All project user secrets                       │ │
│  │  • Projects: eShop.Orders.API, eShop.Web.App, AppHost    │ │
│  │                                                            │ │
│  │  SKIP CONDITIONS:                                          │ │
│  │  • -ValidateOnly parameter used                           │ │
│  │  • -SkipSecretsClear parameter used                       │ │
│  │  • -WhatIf parameter used                                 │ │
│  └───────────┬───────────────────────────────────────────────┘ │
│              │                                                  │
│        ✓ PASS│ ⚠ WARN                                          │
│              │    └──► [WARN: Secrets clear had issues]        │
│              ▼                                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EXECUTION SUMMARY                            │
│  ┌───────────────────────────────────────────────────────────┐ │
│  │  Status: ✓ SUCCESS                                        │ │
│  │  Duration: 14-22 seconds                                  │ │
│  │  Exit Code: 0                                             │ │
│  └───────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                             │
                             ▼
                      READY FOR DEPLOYMENT
                   (azd provision or azd up)


═══════════════════════════════════════════════════════════════════
                        PARAMETER MODES
═══════════════════════════════════════════════════════════════════

┌─────────────────────────────────────────────────────────────────┐
│  -ValidateOnly                                                  │
│  ├─ Steps 1 & 2: Full validation                               │
│  └─ Step 3: SKIPPED (no secrets clearing)                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  -SkipSecretsClear                                              │
│  ├─ Steps 1 & 2: Full validation                               │
│  └─ Step 3: SKIPPED (no secrets clearing)                      │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  -Force                                                         │
│  ├─ Steps 1 & 2: Full validation                               │
│  └─ Step 3: Execute WITHOUT confirmation prompts               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  -WhatIf                                                        │
│  ├─ Steps 1 & 2: Full validation                               │
│  └─ Step 3: PREVIEW only (no actual execution)                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│  -Verbose                                                       │
│  ├─ All steps: Detailed logging                                │
│  ├─ Shows: Tool paths, versions, authentication details        │
│  └─ Useful for: Troubleshooting, audit trails                  │
└─────────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════
                      FAILURE HANDLING
═══════════════════════════════════════════════════════════════════

Any validation failure in Step 2:
┌─────────────────────────────────────────────────────────────────┐
│  1. Display specific error with ✗ symbol                        │
│  2. Show installation/fix instructions                          │
│  3. Set $prerequisitesFailed = $true                            │
│  4. Continue checking remaining prerequisites                   │
│  5. After all checks, throw error and exit with code 1         │
│  6. Display failure summary with duration                       │
└─────────────────────────────────────────────────────────────────┘

Example failure output:
┌─────────────────────────────────────────────────────────────────┐
│  • Checking Azure CLI...                                        │
│  WARNING: ✗ Azure CLI 2.60.0 or higher is required            │
│  WARNING:   Install from: https://docs.microsoft.com/.../cli   │
│  WARNING:   After installation: az login                        │
│                                                                 │
│  ERROR: One or more required prerequisites are missing          │
│  Status: ✗ FAILED                                              │
│  Exit Code: 1                                                   │
└─────────────────────────────────────────────────────────────────┘


═══════════════════════════════════════════════════════════════════
                    INTEGRATION POINTS
═══════════════════════════════════════════════════════════════════

┌──────────────────────────────────┐
│  Azure Developer CLI (azd)       │
│  ┌────────────────────────────┐  │
│  │ azure.yaml                 │  │
│  │ hooks:                     │  │
│  │   preprovision:            │  │
│  │     windows:               │  │
│  │       run: preprovision.ps1│  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
              │
              ▼
    azd provision / azd up
              │
              ▼
    Executes preprovision.ps1
              │
              ▼
    ✓ Validation passes
              │
              ▼
    Continues with deployment

┌──────────────────────────────────┐
│  GitHub Actions                  │
│  ┌────────────────────────────┐  │
│  │ - name: Pre-provision      │  │
│  │   run: |                   │  │
│  │     pwsh preprovision.ps1  │  │
│  │     -Force                 │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘

┌──────────────────────────────────┐
│  Azure DevOps                    │
│  ┌────────────────────────────┐  │
│  │ - task: PowerShell@2       │  │
│  │   inputs:                  │  │
│  │     filePath: preprovision │  │
│  │     arguments: -Force      │  │
│  └────────────────────────────┘  │
└──────────────────────────────────┘
```

## Validation Matrix

| Component | Check Type | Version Check | Auth Check | Registration Check |
|-----------|-----------|---------------|------------|-------------------|
| PowerShell | ✓ | ✓ (7.0+) | ✗ | ✗ |
| .NET SDK | ✓ | ✓ (10.0+) | ✗ | ✗ |
| azd | ✓ | ✓ (any) | ✗ | ✗ |
| Azure CLI | ✓ | ✓ (2.60.0+) | ✓ | ✗ |
| Bicep CLI | ✓ | ✓ (0.30.0+) | ✗ | ✗ |
| Resource Providers | ✓ | ✗ | ✗ | ✓ (8 providers) |
| Azure Quota | ℹ | ✗ | ✗ | ✗ |

Legend:
- ✓ : Check performed and required
- ✗ : Check not performed
- ℹ : Informational only

## Time Breakdown

```
┌─────────────────────────────────────────────────────────┐
│  Typical Execution Timeline                             │
│                                                         │
│  0s    │ Start, Display Header                         │
│  0.5s  │ PowerShell Version Check                      │
│  1.0s  │ .NET SDK Check                                │
│  1.5s  │ Azure Developer CLI Check                     │
│  2.0s  │ Azure CLI Version Check                       │
│  3.0s  │ Azure Authentication Check                    │
│  4.0s  │ Bicep CLI Check                               │
│  5.0s  │ Resource Provider 1 Check                     │
│  6.0s  │ Resource Provider 2 Check                     │
│  7.0s  │ Resource Provider 3 Check                     │
│  8.0s  │ Resource Provider 4 Check                     │
│  9.0s  │ Resource Provider 5 Check                     │
│  10.0s │ Resource Provider 6 Check                     │
│  11.0s │ Resource Provider 7 Check                     │
│  12.0s │ Resource Provider 8 Check                     │
│  13.0s │ Quota Information Display                     │
│  14.0s │ Execute clean-secrets.ps1 (if not skipped)    │
│  20.0s │ Display Summary                               │
│  20.0s │ Exit                                          │
│                                                         │
│  Total: 14-16s (ValidateOnly)                          │
│         18-22s (Full execution with secrets clearing)  │
└─────────────────────────────────────────────────────────┘
```

## Success Criteria

```
┌─────────────────────────────────────────────────────────────────┐
│  All validations must PASS for successful execution:           │
│                                                                 │
│  ✓ PowerShell 7.0+                                             │
│  ✓ .NET SDK 10.0+                                              │
│  ✓ Azure Developer CLI (any version)                           │
│  ✓ Azure CLI 2.60.0+                                           │
│  ✓ Azure authenticated (az account show succeeds)              │
│  ✓ Bicep CLI 0.30.0+                                           │
│  ✓ All 8 resource providers registered                         │
│  ℹ  Quota information displayed (non-blocking)                 │
│                                                                 │
│  Result: Ready for Azure deployment                            │
└─────────────────────────────────────────────────────────────────┘
```
