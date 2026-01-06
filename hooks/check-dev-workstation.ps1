#!/usr/bin/env pwsh

#Requires -Version 7.0

<#
.SYNOPSIS
    Validates developer workstation prerequisites for Azure Logic Apps Monitoring solution.

.DESCRIPTION
    This script performs comprehensive validation of the development environment to ensure
    all required tools, software dependencies, and Azure configurations are properly set up
    before beginning development work on the Azure Logic Apps Monitoring solution.
    
    The script acts as a wrapper around preprovision.ps1 in ValidateOnly mode, providing
    a developer-friendly way to check workstation readiness without performing any
    modifications to the environment.
    
    Validations performed include:
    - PowerShell version (7.0+)
    - .NET SDK version (10.0+)
    - Azure Developer CLI (azd)
    - Azure CLI (2.60.0+) with active authentication
    - Bicep CLI (0.30.0+)
    - Azure Resource Provider registrations
    - Azure subscription quota requirements
    
.PARAMETER Verbose
    Displays detailed diagnostic information during validation.

.EXAMPLE
    .\check-dev-workstation.ps1
    Performs standard workstation validation with normal output.

.EXAMPLE
    .\check-dev-workstation.ps1 -Verbose
    Performs validation with detailed diagnostic output for troubleshooting.

.OUTPUTS
    System.String
    Formatted output string containing validation results.

.NOTES
    File Name      : check-dev-workstation.ps1
    Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
    Version        : 1.0.0
    Last Modified  : 2026-01-07
    Prerequisite   : PowerShell 7.0+, preprovision.ps1
    Purpose        : Development environment validation wrapper
    

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring

.LINK
    preprovision.ps1 - The underlying validation script

.COMPONENT
    Azure Logic Apps Monitoring - Development Tools

.ROLE
    Development Environment Validation

.FUNCTIONALITY
    Validates development workstation prerequisites for Azure deployment
#>

[CmdletBinding()]
[OutputType([System.Void])]
param()

#region Script Configuration

# Enable strict mode for robust error handling
Set-StrictMode -Version Latest

# Store original preference to restore in finally block
$originalErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'

# Script metadata constants with script scope for proper accessibility
$script:ScriptVersion = '1.0.0'
$script:ScriptName = 'check-dev-workstation.ps1'

#endregion Script Configuration

#region Main Execution

try {
    # Validate that preprovision.ps1 exists in the same directory
    $preprovisionPath = Join-Path -Path $PSScriptRoot -ChildPath 'preprovision.ps1'
    
    if (-not (Test-Path -Path $preprovisionPath -PathType Leaf)) {
        throw "Required script not found: $preprovisionPath`nThis script requires preprovision.ps1 to be in the same directory."
    }

    Write-Verbose -Message "Starting developer workstation validation..."
    Write-Verbose -Message "Using validation script: $preprovisionPath"
    Write-Verbose -Message "Script version: $script:ScriptVersion"
    
    # Resolve PowerShell executable path for child process execution
    # Run in a child pwsh process so that any exit in preprovision.ps1
    # does not terminate this wrapper, and so the exit code can be trusted
    $pwshPath = $null
    $pwshCommand = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    
    if ($null -ne $pwshCommand -and $pwshCommand.CommandType -in @('Application', 'ExternalScript')) {
        $pwshPath = $pwshCommand.Source
    }
    elseif (Test-Path -Path (Join-Path -Path $PSHOME -ChildPath 'pwsh') -PathType Leaf) {
        $pwshPath = Join-Path -Path $PSHOME -ChildPath 'pwsh'
    }
    elseif (Test-Path -Path (Join-Path -Path $PSHOME -ChildPath 'pwsh.exe') -PathType Leaf) {
        $pwshPath = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
    }
    else {
        throw "Unable to locate 'pwsh' to run preprovision.ps1 in a child process."
    }

    # Build arguments for preprovision.ps1 execution in ValidateOnly mode
    $preprovisionArgs = @(
        '-NoProfile',
        '-NonInteractive',
        '-File', $preprovisionPath,
        '-ValidateOnly',
        '-InformationAction', 'Continue'
    )

    # Add ExecutionPolicy bypass on Windows for script execution
    if ($IsWindows) {
        $preprovisionArgs = @('-ExecutionPolicy', 'Bypass') + $preprovisionArgs
    }

    Write-Verbose -Message "Executing: $pwshPath $($preprovisionArgs -join ' ')"

    # Execute preprovision.ps1 and stream output to caller while capturing it
    $null = & $pwshPath @preprovisionArgs 2>&1 | Tee-Object -Variable validationOutput

    # Check if validation was successful by examining the child process exit code
    if ($LASTEXITCODE -eq 0) {
        Write-Verbose -Message '✓ Workstation validation completed successfully'
        Write-Verbose -Message 'Your development environment is properly configured for Azure deployment'
        exit 0
    }
    else {
        Write-Warning -Message '⚠ Workstation validation completed with issues'
        Write-Warning -Message 'Please address the warnings/errors above before proceeding with development'
        exit $LASTEXITCODE
    }
}
catch {
    # Handle unexpected errors during validation
    Write-Error -Message "Workstation validation failed with error: $($_.Exception.Message)"
    
    if ($_.ScriptStackTrace) {
        Write-Error -Message "Stack trace: $($_.ScriptStackTrace)"
    }
    
    Write-Verbose -Message 'Please ensure preprovision.ps1 is available and executable'
    exit 1
}
finally {
    # Cleanup - restore error preference to original value
    $ErrorActionPreference = $originalErrorActionPreference
    Write-Verbose -Message 'Workstation validation process completed'
}

#endregion Main Execution