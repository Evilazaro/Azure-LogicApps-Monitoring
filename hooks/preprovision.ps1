#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Pre-provisioning script for Azure Developer CLI (azd) deployment.

.DESCRIPTION
    This script performs pre-provisioning tasks before Azure resources are provisioned.
    It ensures a clean state by clearing user secrets and validates the development environment.
    
    The script performs the following operations:
    - Validates PowerShell version compatibility
    - Clears .NET user secrets for all projects
    - Validates required tools (.NET SDK)
    - Prepares environment for Azure deployment
    - Provides detailed logging and error handling

.PARAMETER Force
    Skips confirmation prompts and forces execution of all operations.

.PARAMETER SkipSecretsClear
    Skips the user secrets clearing step.

.PARAMETER ValidateOnly
    Only validates prerequisites without making changes.

.PARAMETER UseDeviceCodeLogin
    Uses device code flow for Azure authentication instead of browser-based login.
    Useful for remote sessions, SSH connections, or environments without a browser.

.EXAMPLE
    .\preprovision.ps1
    Runs standard pre-provisioning with confirmation prompts.

.EXAMPLE
    .\preprovision.ps1 -Force
    Runs pre-provisioning without confirmation prompts.

.EXAMPLE
    .\preprovision.ps1 -ValidateOnly
    Only validates prerequisites without clearing secrets.

.EXAMPLE
    .\preprovision.ps1 -SkipSecretsClear -Verbose
    Skips secret clearing and shows verbose output.

.EXAMPLE
    .\preprovision.ps1 -UseDeviceCodeLogin
    Uses device code flow for Azure login (useful for remote/headless sessions).

.NOTES
    File Name      : preprovision.ps1
    Author         : Azure-LogicApps-Monitoring Team
    Version        : 2.1.0
    Last Modified  : 2025-12-30
    Prerequisite   : PowerShell 7.0 or higher
    Prerequisite   : .NET SDK 8.0 or higher
    Prerequisite   : Azure Developer CLI (azd)
    Copyright      : (c) 2025. All rights reserved.

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Skip confirmation prompts')]
    [switch]$Force,

    [Parameter(Mandatory = $false, HelpMessage = 'Skip clearing user secrets')]
    [switch]$SkipSecretsClear,

    [Parameter(Mandatory = $false, HelpMessage = 'Only validate prerequisites without making changes')]
    [switch]$ValidateOnly,

    [Parameter(Mandatory = $false, HelpMessage = 'Use device code flow for Azure authentication (for remote/headless sessions)')]
    [switch]$UseDeviceCodeLogin,

    [Parameter(Mandatory = $false, HelpMessage = 'Automatically install missing prerequisites without prompting')]
    [switch]$AutoInstall
)

#Requires -Version 7.0

# Script configuration
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$WarningPreference = 'Continue'

# Script-level constants
$script:ScriptVersion = '2.1.0'
$script:MinimumPowerShellVersion = [version]'7.0'
$script:MinimumDotNetVersion = [version]'10.0'
$script:MinimumAzureCLIVersion = [version]'2.60.0'
$script:MinimumBicepVersion = [version]'0.30.0'
$script:CleanSecretsScriptPath = Join-Path $PSScriptRoot 'clean-secrets.ps1'
$script:RequiredResourceProviders = @(
    'Microsoft.App'
    'Microsoft.ServiceBus'
    'Microsoft.Storage'
    'Microsoft.Web'
    'Microsoft.ContainerRegistry'
    'Microsoft.Insights'
    'Microsoft.OperationalInsights'
    'Microsoft.ManagedIdentity'
)

#region Functions

function Test-PowerShellVersion {
    <#
    .SYNOPSIS
        Validates PowerShell version meets minimum requirements.
    
    .DESCRIPTION
        Checks if the current PowerShell version is compatible with the script requirements.
        Returns $true if version is acceptable, $false otherwise.
    
    .OUTPUTS
        System.Boolean - Returns $true if PowerShell version is sufficient, $false otherwise.
    
    .EXAMPLE
        Test-PowerShellVersion
        Returns $true if PowerShell 7.0 or higher is running.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose 'Validating PowerShell version...'
    }

    process {
        try {
            $currentVersion = $PSVersionTable.PSVersion
            
            if ($currentVersion -lt $script:MinimumPowerShellVersion) {
                Write-Warning "Current PowerShell version: $currentVersion"
                Write-Warning "Minimum required version: $script:MinimumPowerShellVersion"
                return $false
            }
            
            Write-Verbose "PowerShell version $currentVersion is compatible"
            return $true
        }
        catch {
            Write-Verbose "Error validating PowerShell version: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-DotNetSDK {
    <#
    .SYNOPSIS
        Validates .NET SDK availability and version.
    
    .DESCRIPTION
        Checks if .NET SDK is installed and meets the minimum version requirement (.NET 10.0).
        Returns $true if .NET SDK is available and compatible, $false otherwise.
    
    .OUTPUTS
        System.Boolean - Returns $true if .NET SDK is available and compatible, $false otherwise.
    
    .EXAMPLE
        Test-DotNetSDK
        Returns $true if .NET SDK 10.0 or higher is installed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose 'Validating .NET SDK...'
    }

    process {
        try {
            # Check if dotnet command exists
            $dotnetCommand = Get-Command -Name dotnet -ErrorAction SilentlyContinue
            if (-not $dotnetCommand) {
                Write-Verbose '.NET SDK not found in PATH'
                return $false
            }
            
            Write-Verbose "dotnet found at: $($dotnetCommand.Source)"
            
            # Get .NET version
            $versionOutput = & dotnet --version 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose 'Failed to retrieve .NET version'
                return $false
            }
            
            # Parse version
            $versionString = $versionOutput | Select-Object -First 1
            Write-Verbose "Detected .NET SDK version: $versionString"
            
            # Extract major version for comparison
            if ($versionString -match '^(\d+)\.') {
                $majorVersion = [int]$matches[1]
                $minMajorVersion = [int]$script:MinimumDotNetVersion.Major
                
                if ($majorVersion -lt $minMajorVersion) {
                    Write-Warning "Current .NET SDK version: $versionString"
                    Write-Warning "Minimum required version: $script:MinimumDotNetVersion"
                    return $false
                }
            }
            
            Write-Verbose ".NET SDK version $versionString is compatible"
            return $true
        }
        catch {
            Write-Verbose "Error validating .NET SDK: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-AzureDeveloperCLI {
    <#
    .SYNOPSIS
        Validates Azure Developer CLI (azd) availability.
    
    .DESCRIPTION
        Checks if Azure Developer CLI is installed and accessible.
        Returns $true if azd is available, $false otherwise.
    
    .OUTPUTS
        System.Boolean - Returns $true if azd is available, $false otherwise.
    
    .EXAMPLE
        Test-AzureDeveloperCLI
        Returns $true if azd command is available.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose 'Validating Azure Developer CLI...'
    }

    process {
        try {
            $azdCommand = Get-Command -Name azd -ErrorAction SilentlyContinue
            if (-not $azdCommand) {
                Write-Verbose 'Azure Developer CLI not found in PATH'
                return $false
            }
            
            Write-Verbose "azd found at: $($azdCommand.Source)"
            
            # Verify azd can execute
            $versionOutput = & azd version 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose 'Failed to execute azd version command'
                return $false
            }
            
            Write-Verbose "Azure Developer CLI version: $($versionOutput | Select-Object -First 1)"
            return $true
        }
        catch {
            Write-Verbose "Error validating Azure Developer CLI: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-AzureCLI {
    <#
    .SYNOPSIS
        Validates Azure CLI availability and version.
    
    .DESCRIPTION
        Checks if Azure CLI is installed and meets the minimum version requirement.
        Also validates that the user is authenticated to Azure.
        Returns a hashtable with detailed status information.
    
    .OUTPUTS
        System.Collections.Hashtable - Returns hashtable with:
          - IsInstalled: $true if Azure CLI is found
          - IsVersionValid: $true if version meets requirements
          - IsAuthenticated: $true if user is logged in
          - Version: The detected Azure CLI version
          - AccountInfo: The authenticated account details (if authenticated)
          - Success: $true if all checks pass
    
    .EXAMPLE
        $result = Test-AzureCLI
        if (-not $result.IsAuthenticated) { Invoke-AzureLogin }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    begin {
        Write-Verbose 'Validating Azure CLI...'
    }

    process {
        $result = @{
            IsInstalled     = $false
            IsVersionValid  = $false
            IsAuthenticated = $false
            Version         = $null
            AccountInfo     = $null
            Success         = $false
        }
        
        try {
            # Check if az command exists
            $azCommand = Get-Command -Name az -ErrorAction SilentlyContinue
            if (-not $azCommand) {
                Write-Verbose 'Azure CLI not found in PATH'
                return $result
            }
            
            $result.IsInstalled = $true
            Write-Verbose "az found at: $($azCommand.Source)"
            
            # Get Azure CLI version
            $versionOutput = & az version --output json 2>&1 | ConvertFrom-Json
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose 'Failed to retrieve Azure CLI version'
                return $result
            }
            
            $azVersion = [version]$versionOutput.'azure-cli'
            $result.Version = $azVersion
            Write-Verbose "Detected Azure CLI version: $azVersion"
            
            if ($azVersion -lt $script:MinimumAzureCLIVersion) {
                Write-Warning "Current Azure CLI version: $azVersion"
                Write-Warning "Minimum required version: $script:MinimumAzureCLIVersion"
                return $result
            }
            
            $result.IsVersionValid = $true
            
            # Check if user is authenticated
            Write-Verbose 'Checking Azure authentication...'
            $accountInfo = & az account show --output json 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose 'User is not authenticated to Azure'
                return $result
            }
            
            $account = $accountInfo | ConvertFrom-Json
            $result.IsAuthenticated = $true
            $result.AccountInfo = $account
            $result.Success = $true
            
            Write-Verbose "Authenticated as: $($account.user.name)"
            Write-Verbose "Active subscription: $($account.name) ($($account.id))"
            
            return $result
        }
        catch {
            Write-Verbose "Error validating Azure CLI: $($_.Exception.Message)"
            return $result
        }
    }
}

function Invoke-AzureLogin {
    <#
    .SYNOPSIS
        Initiates Azure CLI login process with user guidance.
    
    .DESCRIPTION
        Provides clear instructions to the user and initiates the Azure CLI login process.
        Supports both interactive browser-based login and device code flow.
        Returns $true if login succeeds, $false otherwise.
    
    .PARAMETER UseDeviceCode
        Uses device code flow instead of browser-based authentication.
        Useful for remote sessions or environments without a browser.
    
    .OUTPUTS
        System.Boolean - Returns $true if login succeeds, $false otherwise.
    
    .EXAMPLE
        Invoke-AzureLogin
        Initiates browser-based Azure login.
    
    .EXAMPLE
        Invoke-AzureLogin -UseDeviceCode
        Initiates device code flow for Azure login.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$UseDeviceCode
    )

    process {
        try {
            Write-Information ''
            Write-Information '┌────────────────────────────────────────────────────────────────┐'
            Write-Information '│                    Azure Authentication Required               │'
            Write-Information '└────────────────────────────────────────────────────────────────┘'
            Write-Information ''
            Write-Information '  You are not currently logged into Azure CLI.'
            Write-Information '  This script requires Azure authentication to:'
            Write-Information '    • Verify resource provider registration'
            Write-Information '    • Check subscription quotas'
            Write-Information '    • Prepare for Azure resource provisioning'
            Write-Information ''
            
            if ($UseDeviceCode) {
                Write-Information '  Starting device code authentication...'
                Write-Information '  Please follow the instructions below to authenticate.'
                Write-Information ''
                
                & az login --use-device-code
            }
            else {
                Write-Information '  Starting browser-based authentication...'
                Write-Information '  A browser window will open for you to sign in.'
                Write-Information ''
                Write-Information '  💡 Tip: If no browser opens or you''re in a remote session,'
                Write-Information '          re-run with: .\preprovision.ps1 -UseDeviceCodeLogin'
                Write-Information ''
                
                & az login
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Information ''
                Write-Information '  ✓ Azure login successful!'
                Write-Information ''
                
                # Display account info
                $accountInfo = & az account show --output json 2>&1 | ConvertFrom-Json
                if ($LASTEXITCODE -eq 0) {
                    Write-Information "  Logged in as:      $($accountInfo.user.name)"
                    Write-Information "  Subscription:      $($accountInfo.name)"
                    Write-Information "  Subscription ID:   $($accountInfo.id)"
                    Write-Information ''
                }
                
                return $true
            }
            else {
                Write-Warning ''
                Write-Warning '  ✗ Azure login failed or was cancelled.'
                Write-Warning ''
                Write-Warning '  Please try again or log in manually using:'
                Write-Warning '    az login'
                Write-Warning ''
                return $false
            }
        }
        catch {
            Write-Error "Error during Azure login: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-BicepCLI {
    <#
    .SYNOPSIS
        Validates Bicep CLI availability and version.
    
    .DESCRIPTION
        Checks if Bicep CLI is installed and meets the minimum version requirement.
        Bicep is typically installed via Azure CLI or as a standalone tool.
        Returns $true if Bicep CLI is available and compatible, $false otherwise.
    
    .OUTPUTS
        System.Boolean - Returns $true if Bicep CLI is available and compatible, $false otherwise.
    
    .EXAMPLE
        Test-BicepCLI
        Returns $true if Bicep CLI 0.30.0 or higher is installed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose 'Validating Bicep CLI...'
    }

    process {
        try {
            # Check if bicep command exists (standalone)
            $bicepCommand = Get-Command -Name bicep -ErrorAction SilentlyContinue
            
            if (-not $bicepCommand) {
                # Try Azure CLI bicep
                Write-Verbose 'Standalone Bicep CLI not found, checking via Azure CLI...'
                $versionOutput = & az bicep version 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Verbose 'Bicep CLI not available via Azure CLI'
                    return $false
                }
            }
            else {
                Write-Verbose "bicep found at: $($bicepCommand.Source)"
                $versionOutput = & bicep --version 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Verbose 'Failed to retrieve Bicep version'
                    return $false
                }
            }
            
            # Parse version from output (format: "Bicep CLI version x.y.z")
            if ($versionOutput -match '(\d+\.\d+\.\d+)') {
                $bicepVersion = [version]$matches[1]
                Write-Verbose "Detected Bicep CLI version: $bicepVersion"
                
                if ($bicepVersion -lt $script:MinimumBicepVersion) {
                    Write-Warning "Current Bicep CLI version: $bicepVersion"
                    Write-Warning "Minimum required version: $script:MinimumBicepVersion"
                    return $false
                }
                
                return $true
            }
            else {
                Write-Verbose 'Failed to parse Bicep version'
                return $false
            }
        }
        catch {
            Write-Verbose "Error validating Bicep CLI: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-AzureResourceProviders {
    <#
    .SYNOPSIS
        Validates required Azure resource providers are registered.
    
    .DESCRIPTION
        Checks if all required Azure resource providers are registered in the active subscription.
        Provides warnings for unregistered providers with instructions to register them.
        Returns $true if all providers are registered, $false otherwise.
    
    .OUTPUTS
        System.Boolean - Returns $true if all required providers are registered, $false otherwise.
    
    .EXAMPLE
        Test-AzureResourceProviders
        Checks registration status of all required Azure resource providers.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    begin {
        Write-Verbose 'Validating Azure resource provider registration...'
    }

    process {
        try {
            $allRegistered = $true
            $unregisteredProviders = [System.Collections.Generic.List[string]]::new()
            
            foreach ($provider in $script:RequiredResourceProviders) {
                Write-Verbose "Checking provider: $provider"
                
                $providerInfo = & az provider show --namespace $provider --output json 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Verbose "Failed to retrieve provider info for: $provider"
                    $unregisteredProviders.Add($provider)
                    $allRegistered = $false
                    continue
                }
                
                $providerData = $providerInfo | ConvertFrom-Json
                $registrationState = $providerData.registrationState
                
                if ($registrationState -ne 'Registered') {
                    Write-Verbose "Provider $provider is not registered (State: $registrationState)"
                    $unregisteredProviders.Add($provider)
                    $allRegistered = $false
                }
                else {
                    Write-Verbose "Provider $provider is registered"
                }
            }
            
            if (-not $allRegistered) {
                Write-Warning 'Some required resource providers are not registered:'
                foreach ($provider in $unregisteredProviders) {
                    Write-Warning "  - $provider"
                }
                Write-Warning ''
                Write-Warning 'To register these providers, run:'
                foreach ($provider in $unregisteredProviders) {
                    Write-Warning "  az provider register --namespace $provider --wait"
                }
            }
            
            return $allRegistered
        }
        catch {
            Write-Verbose "Error validating resource providers: $($_.Exception.Message)"
            return $false
        }
    }
}

function Test-AzureQuota {
    <#
    .SYNOPSIS
        Validates Azure subscription has sufficient quota for deployment.
    
    .DESCRIPTION
        Provides informational check about common quota limits that might affect deployment.
        This is a best-effort check and doesn't fail the validation.
    
    .EXAMPLE
        Test-AzureQuota
        Displays information about subscription quotas.
    #>
    [CmdletBinding()]
    param()

    begin {
        Write-Verbose 'Checking Azure subscription quotas...'
    }

    process {
        try {
            Write-Verbose 'Retrieving subscription limits information...'
            
            # This is informational only - we don't fail based on quotas
            # as some resources (like Container Apps) don't have easy-to-check quotas
            Write-Information '  ℹ  Quota check: Ensure your subscription has sufficient quota for:'
            Write-Information '     - Container Apps (minimum 2 apps)'
            Write-Information '     - Storage Accounts (minimum 3 accounts)'
            Write-Information '     - Service Bus namespaces (minimum 1)'
            Write-Information '     - Logic Apps Standard (minimum 1)'
            Write-Information '     - Container Registry (minimum 1)'
            Write-Information ''
            
            return $true
        }
        catch {
            Write-Verbose "Error checking Azure quotas: $($_.Exception.Message)"
            return $true  # Don't fail on quota check errors
        }
    }
}

function Invoke-CleanSecrets {
    <#
    .SYNOPSIS
        Invokes the clean-secrets.ps1 script to clear user secrets.
    
    .DESCRIPTION
        Executes the clean-secrets.ps1 script with appropriate parameters.
        Handles errors gracefully and provides detailed logging.
    
    .PARAMETER Force
        Passes the Force parameter to clean-secrets.ps1 to skip confirmations.
    
    .OUTPUTS
        System.Boolean - Returns $true if successful, $false otherwise.
    
    .EXAMPLE
        Invoke-CleanSecrets -Force
        Clears all user secrets without confirmation.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    begin {
        Write-Verbose 'Preparing to clear user secrets...'
    }

    process {
        try {
            # Validate clean-secrets.ps1 exists
            if (-not (Test-Path -Path $script:CleanSecretsScriptPath -PathType Leaf)) {
                Write-Warning "clean-secrets.ps1 not found at: $script:CleanSecretsScriptPath"
                return $false
            }
            
            if ($PSCmdlet.ShouldProcess('User secrets', 'Clear all project secrets')) {
                Write-Information 'Clearing user secrets for all projects...'
                Write-Verbose "Executing: $script:CleanSecretsScriptPath"
                
                # Build splatting hashtable for parameters
                $cleanSecretsParams = @{}
                if ($Force) {
                    $cleanSecretsParams['Force'] = $true
                }
                if ($VerbosePreference -eq 'Continue') {
                    $cleanSecretsParams['Verbose'] = $true
                }
                
                # Execute clean-secrets.ps1 using splatting
                if ($cleanSecretsParams.Count -gt 0) {
                    & $script:CleanSecretsScriptPath @cleanSecretsParams
                }
                else {
                    & $script:CleanSecretsScriptPath
                }
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Information '✓ User secrets cleared successfully'
                    return $true
                }
                else {
                    Write-Warning "clean-secrets.ps1 exited with code: $LASTEXITCODE"
                    return $false
                }
            }
            else {
                Write-Verbose 'WhatIf: Would clear user secrets'
                return $true
            }
        }
        catch {
            Write-Error "Error clearing user secrets: $($_.Exception.Message)"
            return $false
        }
    }
}

function Write-PreProvisionHeader {
    <#
    .SYNOPSIS
        Displays the script header with version and environment information.
    
    .DESCRIPTION
        Outputs a formatted header with script details and execution context.
    
    .EXAMPLE
        Write-PreProvisionHeader
    #>
    [CmdletBinding()]
    param()

    process {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $psVersion = $PSVersionTable.PSVersion
        $osDescription = if ($PSVersionTable.PSObject.Properties['OS']) { 
            $PSVersionTable.OS 
        } 
        else { 
            [System.Runtime.InteropServices.RuntimeInformation]::OSDescription 
        }
        
        Write-Information ''
        Write-Information '╔════════════════════════════════════════════════════════════════╗'
        Write-Information '║          Azure Pre-Provisioning Script                        ║'
        Write-Information '╚════════════════════════════════════════════════════════════════╝'
        Write-Information ''
        Write-Information "  Version:          $script:ScriptVersion"
        Write-Information "  Execution Time:   $timestamp"
        Write-Information "  PowerShell:       $psVersion"
        Write-Information "  OS:               $osDescription"
        Write-Information ''
        Write-Information '────────────────────────────────────────────────────────────────'
        Write-Information ''
    }
}

function Write-PreProvisionSummary {
    <#
    .SYNOPSIS
        Displays the execution summary.
    
    .DESCRIPTION
        Outputs a summary of the pre-provisioning execution results.
    
    .PARAMETER Duration
        The execution duration in seconds.
    
    .PARAMETER Success
        Indicates if the execution was successful.
    
    .EXAMPLE
        Write-PreProvisionSummary -Duration 5.23 -Success $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [double]$Duration,
        
        [Parameter(Mandatory = $true)]
        [bool]$Success
    )

    process {
        Write-Information ''
        Write-Information '────────────────────────────────────────────────────────────────'
        Write-Information ''
        if ($Success) {
            Write-Information '  Status:           ✓ SUCCESS'
        }
        else {
            Write-Information '  Status:           ✗ FAILED'
        }
        Write-Information "  Duration:         $([Math]::Round($Duration, 2)) seconds"
        Write-Information ''
        Write-Information '╔════════════════════════════════════════════════════════════════╗'
        if ($Success) {
            Write-Information '║   Pre-provisioning completed successfully!                    ║'
        }
        else {
            Write-Information '║   Pre-provisioning completed with errors.                     ║'
        }
        Write-Information '╚════════════════════════════════════════════════════════════════╝'
        Write-Information ''
    }
}

#endregion

#region Main Execution

try {
    # Start execution timer
    $executionStart = Get-Date
    
    # Display header
    Write-PreProvisionHeader
    
    # Step 1: Validate PowerShell version
    Write-Information 'Step 1: Validating PowerShell version...'
    if (-not (Test-PowerShellVersion)) {
        throw "PowerShell version $($PSVersionTable.PSVersion) is not supported. Minimum required: $script:MinimumPowerShellVersion"
    }
    Write-Information "  ✓ PowerShell $($PSVersionTable.PSVersion) is compatible"
    Write-Information ''
    
    # Step 2: Validate prerequisites
    Write-Information 'Step 2: Validating prerequisites...'
    Write-Information ''
    
    $prerequisitesFailed = $false
    
    # Check .NET SDK
    Write-Information '  • Checking .NET SDK...'
    if (-not (Test-DotNetSDK)) {
        Write-Warning "    ✗ .NET SDK $script:MinimumDotNetVersion or higher is required"
        Write-Warning "      Download from: https://dotnet.microsoft.com/download/dotnet/10.0"
        $prerequisitesFailed = $true
    }
    else {
        Write-Information '    ✓ .NET SDK is available and compatible'
    }
    Write-Information ''
    
    # Check Azure Developer CLI
    Write-Information '  • Checking Azure Developer CLI...'
    if (-not (Test-AzureDeveloperCLI)) {
        Write-Warning '    ✗ Azure Developer CLI (azd) is required'
        Write-Warning '      Install from: https://aka.ms/azd/install'
        $prerequisitesFailed = $true
    }
    else {
        Write-Information '    ✓ Azure Developer CLI is available'
    }
    Write-Information ''
    
    # Check Azure CLI
    Write-Information '  • Checking Azure CLI...'
    $azCliResult = Test-AzureCLI
    
    if (-not $azCliResult.IsInstalled) {
        Write-Warning '    ✗ Azure CLI is not installed'
        Write-Warning "      Minimum required version: $script:MinimumAzureCLIVersion"
        Write-Warning '      Install from: https://docs.microsoft.com/cli/azure/install-azure-cli'
        $prerequisitesFailed = $true
    }
    elseif (-not $azCliResult.IsVersionValid) {
        Write-Warning "    ✗ Azure CLI version $($azCliResult.Version) is below minimum required"
        Write-Warning "      Minimum required version: $script:MinimumAzureCLIVersion"
        Write-Warning '      Update with: az upgrade'
        $prerequisitesFailed = $true
    }
    elseif (-not $azCliResult.IsAuthenticated) {
        Write-Warning '    ⚠ Azure CLI is installed but you are not logged in'
        Write-Information ''
        
        # Attempt to login
        $loginSuccess = Invoke-AzureLogin -UseDeviceCode:$UseDeviceCodeLogin
        
        if (-not $loginSuccess) {
            Write-Warning '    ✗ Azure authentication is required to continue'
            $prerequisitesFailed = $true
        }
        else {
            Write-Information '    ✓ Azure CLI is available and authenticated'
        }
    }
    else {
        Write-Information '    ✓ Azure CLI is available and authenticated'
    }
    Write-Information ''
    
    # Check Bicep CLI
    Write-Information '  • Checking Bicep CLI...'
    if (-not (Test-BicepCLI)) {
        Write-Warning "    ✗ Bicep CLI $script:MinimumBicepVersion or higher is required"
        Write-Warning '      Install with Azure CLI: az bicep install'
        Write-Warning '      Or upgrade: az bicep upgrade'
        $prerequisitesFailed = $true
    }
    else {
        Write-Information '    ✓ Bicep CLI is available and compatible'
    }
    Write-Information ''
    
    # Check Azure Resource Providers
    if (-not $prerequisitesFailed) {
        Write-Information '  • Checking Azure Resource Provider registration...'
        if (-not (Test-AzureResourceProviders)) {
            Write-Warning '    ✗ Some required Azure resource providers are not registered'
            Write-Warning '      See warnings above for registration commands'
            $prerequisitesFailed = $true
        }
        else {
            Write-Information '    ✓ All required resource providers are registered'
        }
        Write-Information ''
        
        # Check quotas (informational only)
        Write-Information '  • Checking Azure subscription quotas...'
        Test-AzureQuota | Out-Null
        Write-Information ''
    }
    else {
        Write-Information '  • Skipping Azure resource provider check (previous validations failed)'
        Write-Information ''
    }
    
    if ($prerequisitesFailed) {
        throw 'One or more required prerequisites are missing or not configured. Please address the issues above.'
    }
    
    Write-Information '  ✓ All prerequisites validated successfully'
    Write-Information ''
    
    # Step 3: Clear user secrets (unless skipped or validate-only)
    if ($ValidateOnly) {
        Write-Information 'Step 3: Skipping user secrets clearing (ValidateOnly mode)'
        Write-Information ''
    }
    elseif ($SkipSecretsClear) {
        Write-Information 'Step 3: Skipping user secrets clearing (SkipSecretsClear flag set)'
        Write-Information ''
    }
    else {
        Write-Information 'Step 3: Clearing user secrets...'
        Write-Information ''
        
        $cleanSuccess = Invoke-CleanSecrets -Force:$Force
        
        if (-not $cleanSuccess) {
            Write-Warning 'User secrets clearing completed with warnings.'
            Write-Warning 'This may not affect deployment, but should be investigated.'
        }
        
        Write-Information ''
    }
    
    # Calculate execution duration
    $executionDuration = (New-TimeSpan -Start $executionStart -End (Get-Date)).TotalSeconds
    
    # Display summary
    Write-PreProvisionSummary -Duration $executionDuration -Success $true
    
    Write-Verbose 'Pre-provisioning completed successfully'
    exit 0
}
catch {
    # Calculate execution duration
    $executionDuration = if ($executionStart) {
        (New-TimeSpan -Start $executionStart -End (Get-Date)).TotalSeconds
    }
    else {
        0
    }
    
    # Display error summary
    Write-PreProvisionSummary -Duration $executionDuration -Success $false
    
    Write-Error "Pre-provisioning failed: $($_.Exception.Message)"
    Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Reset preferences
    $ErrorActionPreference = 'Continue'
    $InformationPreference = 'Continue'
    Write-Verbose 'Pre-provisioning script execution completed.'
}

#endregion