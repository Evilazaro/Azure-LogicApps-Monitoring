#!/usr/bin/env pwsh

#Requires -Version 7.0

<#
.SYNOPSIS
    Validates developer workstation prerequisites for the Azure Logic Apps Monitoring solution.

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

    The script spawns a child PowerShell process to execute preprovision.ps1, ensuring
    that any exit calls in the validation script do not terminate the wrapper process
    and that exit codes are reliably captured.

.PARAMETER Verbose
    Displays detailed diagnostic information during validation, including the pwsh
    executable path, script arguments, and stack traces on errors.

.EXAMPLE
    .\check-dev-workstation.ps1
    
    Performs standard workstation validation with normal output. Returns exit code 0
    on success or a non-zero exit code if validation issues are detected.

.EXAMPLE
    .\check-dev-workstation.ps1 -Verbose
    
    Performs validation with detailed diagnostic output for troubleshooting, including
    information about script paths, command execution, and validation progress.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    System.Void
    This script produces console output and returns an exit code but does not output objects.

.NOTES
    File Name      : check-dev-workstation.ps1
    Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
    Version        : 1.0.0
    Last Modified  : 2026-01-07
    Prerequisite   : PowerShell 7.0+, preprovision.ps1 in the same directory
    Purpose        : Development environment validation wrapper
    
    Exit Codes:
    - 0: All validations passed successfully
    - 1: Script execution error (e.g., missing preprovision.ps1)
    - Other: Exit code from preprovision.ps1 indicating specific validation failures

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

# Store original preferences to restore in finally block
$originalErrorActionPreference = $ErrorActionPreference
$originalInformationPreference = $InformationPreference
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Script metadata constants with script scope for proper accessibility
$script:ScriptVersion = '1.0.0'

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
    
    # Try Get-Command first (most reliable)
    $pwshCommand = Get-Command -Name 'pwsh' -CommandType Application -ErrorAction SilentlyContinue
    
    if ($null -ne $pwshCommand) {
        $pwshPath = $pwshCommand.Source
        Write-Verbose -Message "Found pwsh via Get-Command: $pwshPath"
    }
    # Try $PSHOME directory (PowerShell installation directory)
    elseif (Test-Path -Path (Join-Path -Path $PSHOME -ChildPath 'pwsh') -PathType Leaf) {
        $pwshPath = Join-Path -Path $PSHOME -ChildPath 'pwsh'
        Write-Verbose -Message "Found pwsh in PSHOME: $pwshPath"
    }
    elseif (Test-Path -Path (Join-Path -Path $PSHOME -ChildPath 'pwsh.exe') -PathType Leaf) {
        $pwshPath = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
        Write-Verbose -Message "Found pwsh.exe in PSHOME: $pwshPath"
    }
    else {
        throw "Unable to locate 'pwsh' executable to run preprovision.ps1 in a child process. Please ensure PowerShell Core is properly installed."
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
        Write-Verbose -Message "Added ExecutionPolicy bypass for Windows"
    }

    Write-Verbose -Message "Executing preprovision script with arguments:"
    Write-Verbose -Message "  Command: $pwshPath"
    Write-Verbose -Message "  Arguments: $($preprovisionArgs -join ' ')"

    # Execute preprovision.ps1 and stream output directly to console
    # Note: Output streams to caller in real-time; exit code determines success
    & $pwshPath @preprovisionArgs
    
    # Capture exit code immediately to prevent it from being overwritten
    $validationExitCode = $LASTEXITCODE

    # Check if validation was successful by examining the child process exit code
    if ($validationExitCode -eq 0) {
        Write-Verbose -Message '✓ Workstation validation completed successfully'
        Write-Verbose -Message 'Your development environment is properly configured for Azure deployment'
        exit 0
    }
    else {
        Write-Warning -Message '⚠ Workstation validation completed with issues'
        Write-Warning -Message 'Please address the warnings/errors above before proceeding with development'
        Write-Verbose -Message "Exit code from preprovision: $validationExitCode"
        exit $validationExitCode
    }
}
catch {
    # Handle unexpected errors during validation
    Write-Error -Message "Workstation validation failed with error: $($_.Exception.Message)"
    
    # Display additional context for troubleshooting
    if ($_.Exception.InnerException) {
        Write-Verbose -Message "Inner exception: $($_.Exception.InnerException.Message)"
    }
    
    if ($_.ScriptStackTrace) {
        Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
    }
    
    # Provide actionable guidance for resolution
    Write-Information -Message ''
    Write-Information -Message 'Troubleshooting steps:'
    Write-Information -Message '  1. Ensure preprovision.ps1 is in the same directory as this script'
    Write-Information -Message '  2. Verify PowerShell Core 7.0+ is properly installed'
    Write-Information -Message '  3. Check that you have execute permissions on the scripts'
    Write-Information -Message '  4. Run with -Verbose flag for detailed diagnostic information'
    Write-Information -Message ''
    
    exit 1
}
finally {
    # Cleanup - restore preferences to original values
    $ErrorActionPreference = $originalErrorActionPreference
    $InformationPreference = $originalInformationPreference
    Write-Verbose -Message 'Workstation validation process completed'
}

#endregion Main Execution