#!/usr/bin/env pwsh

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
    Author         : Azure-LogicApps-Monitoring Team
    Version        : 1.0.0
    Last Modified  : 2025-12-24
    Prerequisite   : PowerShell 7.0+, preprovision.ps1
    Purpose        : Development environment validation wrapper
    Copyright      : (c) 2025. All rights reserved.

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
param()

#Requires -Version 7.0

# Script configuration
Set-StrictMode -Version Latest

$originalErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Stop'

# Script metadata
$script:ScriptVersion = '1.0.0'
$script:ScriptName = 'check-dev-workstation.ps1'

#region Main Execution

try {
    # Validate preprovision.ps1 exists
    $preprovisionPath = Join-Path $PSScriptRoot 'preprovision.ps1'
    if (-not (Test-Path -Path $preprovisionPath -PathType Leaf)) {
        throw "Required script not found: $preprovisionPath`nThis script requires preprovision.ps1 to be in the same directory."
    }

    Write-Verbose "Starting developer workstation validation..."
    Write-Verbose "Using validation script: $preprovisionPath"
    Write-Verbose "Script version: $script:ScriptVersion"
    
    # Execute preprovision.ps1 in ValidateOnly mode.
    # Run in a child pwsh process so that any `exit` in preprovision.ps1
    # does not terminate this wrapper, and so the exit code can be trusted.

    $pwshPath = $null
    $pwshCommand = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    if ($null -ne $pwshCommand -and $pwshCommand.CommandType -in @('Application', 'ExternalScript')) {
        $pwshPath = $pwshCommand.Source
    }
    elseif (Test-Path -Path (Join-Path $PSHOME 'pwsh') -PathType Leaf) {
        $pwshPath = Join-Path $PSHOME 'pwsh'
    }
    elseif (Test-Path -Path (Join-Path $PSHOME 'pwsh.exe') -PathType Leaf) {
        $pwshPath = Join-Path $PSHOME 'pwsh.exe'
    }
    else {
        throw "Unable to locate 'pwsh' to run preprovision.ps1 in a child process."
    }

    $preprovisionArgs = @(
        '-NoProfile',
        '-NonInteractive',
        '-File', $preprovisionPath,
        '-ValidateOnly',
        '-InformationAction', 'Continue'
    )

    if ($IsWindows) {
        $preprovisionArgs = @('-ExecutionPolicy', 'Bypass') + $preprovisionArgs
    }

    Write-Verbose "Executing: $pwshPath $($preprovisionArgs -join ' ')"

    # Stream output to the caller while also capturing it if needed.
    $null = & $pwshPath @preprovisionArgs 2>&1 | Tee-Object -Variable validationOutput

    # Check if validation was successful by examining the child process exit code
    if ($LASTEXITCODE -eq 0) {
        Write-Verbose "✓ Workstation validation completed successfully"
        Write-Verbose "Your development environment is properly configured for Azure deployment"
        exit 0
    }
    else {
        Write-Warning "⚠ Workstation validation completed with issues"
        Write-Warning "Please address the warnings/errors above before proceeding with development"
        exit $LASTEXITCODE
    }
}
catch {
    # Handle unexpected errors during validation
    Write-Error "Workstation validation failed with error: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) {
        Write-Error "Stack trace: $($_.ScriptStackTrace)"
    }
    Write-Verbose "Please ensure preprovision.ps1 is available and executable"
    exit 1
}
finally {
    # Cleanup - ensure error preference is restored
    $ErrorActionPreference = $originalErrorActionPreference
    Write-Verbose "Workstation validation process completed"
}

#endregion