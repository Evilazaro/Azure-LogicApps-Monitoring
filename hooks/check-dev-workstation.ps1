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
$ErrorActionPreference = 'Continue'  # Allow script to complete even if preprovision has warnings

# Script metadata
$script:ScriptVersion = '1.0.0'
$script:ScriptName = 'check-dev-workstation.ps1'

#region Main Execution

try {
    # Validate preprovision.ps1 exists
    $preprovisionPath = Join-Path $PSScriptRoot 'preprovision.ps1'
    if (-not (Test-Path -Path $preprovisionPath -PathType Leaf)) {
        Write-Error "Required script not found: $preprovisionPath"
        Write-Error "This script requires preprovision.ps1 to be in the same directory."
        exit 1
    }

    Write-Verbose "Starting developer workstation validation..."
    Write-Verbose "Using validation script: $preprovisionPath"
    Write-Verbose "Script version: $script:ScriptVersion"
    
    # Execute preprovision.ps1 in ValidateOnly mode
    # This performs all prerequisite checks without making any changes
    # Parameters:
    #   -ValidateOnly: Skips secret clearing, only performs validation
    #   -InformationAction Continue: Ensures all informational messages are displayed
    #   2>&1: Redirects error stream to output stream for complete capture
    #   | Out-String: Converts output objects to formatted string
    
    $validationOutput = & $preprovisionPath -ValidateOnly -InformationAction Continue 2>&1 | Out-String
    
    # Display validation results
    Write-Output $validationOutput
    
    # Check if validation was successful by examining the last exit code
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
    Write-Error "Stack trace: $($_.ScriptStackTrace)"
    Write-Verbose "Please ensure preprovision.ps1 is available and executable"
    exit 1
}
finally {
    # Cleanup - ensure error preference is restored
    $ErrorActionPreference = 'Continue'
    Write-Verbose "Workstation validation process completed"
}

#endregion