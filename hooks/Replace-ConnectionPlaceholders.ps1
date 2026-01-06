#!/usr/bin/env pwsh

#Requires -Version 7.0

<#
.SYNOPSIS
    Replaces placeholder tokens in connections.json with environment variable values.

.DESCRIPTION
    This script reads the connections.json file and replaces all ${VARIABLE_NAME} 
    placeholders with the corresponding environment variable values.
    Supports -WhatIf and -Confirm for safe execution.
    
    The script integrates with Azure Developer CLI (azd) to automatically load
    environment variables from the active azd environment.

.PARAMETER ConnectionsFilePath
    Path to the connections.json file. Defaults to the OrdersManagement Logic App connections file.
    Alias: PSPath (for pipeline compatibility).

.PARAMETER OutputFilePath
    Optional output file path. If not specified, the original file will be overwritten.

.EXAMPLE
    ./Replace-ConnectionPlaceholders.ps1
    Replaces placeholders using environment variables from the active azd environment.

.EXAMPLE
    ./Replace-ConnectionPlaceholders.ps1 -ConnectionsFilePath "./custom/connections.json" -OutputFilePath "./output/connections.json"
    Processes a custom connections file and outputs to a specified location.

.EXAMPLE
    ./Replace-ConnectionPlaceholders.ps1 -WhatIf
    Shows what changes would be made without actually modifying any files.

.OUTPUTS
    None. This script writes directly to files.

.NOTES
    File Name      : Replace-ConnectionPlaceholders.ps1
    Author         :Evilazaro | Principal Cloud Solution Architect | Microsoft
    Version        : 1.1.0
    Last Modified  : 2026-01-06
    Prerequisite   : PowerShell 7.0 or later
    Prerequisite   : Azure Developer CLI (azd)
    Copyright      : (c) 2025-2026. All rights reserved.

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
[OutputType([System.Void])]
param(
    [Parameter(Mandatory = $false, ValueFromPipeline = $false)]
    [ValidateNotNullOrEmpty()]
    [Alias('PSPath', 'Path')]
    [string]$ConnectionsFilePath = "$PSScriptRoot/../workflows/OrdersManagement/OrdersManagementLogicApp/connections.json",

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [Alias('Output', 'Destination')]
    [string]$OutputFilePath
)

# Script configuration
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Script-level constants
$script:ScriptVersion = '1.1.0'

# Load azd environment variables if not already set
# This ensures the script works both when called from azd hooks and standalone
Write-Host "Loading azd environment variables..." -ForegroundColor Cyan
$azdEnvOutput = azd env get-values 2>$null
if ($LASTEXITCODE -eq 0 -and $azdEnvOutput) {
    foreach ($line in $azdEnvOutput) {
        if ($line -match '^([^=]+)="?([^"]*)"?$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            if (-not [System.Environment]::GetEnvironmentVariable($varName)) {
                [System.Environment]::SetEnvironmentVariable($varName, $varValue)
                Write-Verbose "Set environment variable: $varName"
            }
        }
    }
    Write-Host "azd environment variables loaded successfully." -ForegroundColor Green
} else {
    Write-Warning "Could not load azd environment variables. Ensure 'azd env' is configured."
}

# Define the required environment variables and their placeholder names
[hashtable[]]$script:Placeholders = @(
    @{ Placeholder = '${AZURE_SUBSCRIPTION_ID}'; EnvVar = 'AZURE_SUBSCRIPTION_ID' }
    @{ Placeholder = '${AZURE_RESOURCE_GROUP}'; EnvVar = 'AZURE_RESOURCE_GROUP' }
    @{ Placeholder = '${MANAGED_IDENTITY_NAME}'; EnvVar = 'MANAGED_IDENTITY_NAME' }
    @{ Placeholder = '${SERVICE_BUS_CONNECTION_RUNTIME_URL}'; EnvVar = 'SERVICE_BUS_CONNECTION_RUNTIME_URL' }
    @{ Placeholder = '${AZURE_BLOB_CONNECTION_RUNTIME_URL}'; EnvVar = 'AZURE_BLOB_CONNECTION_RUNTIME_URL' }
)

function Test-RequiredEnvironmentVariables {
    <#
    .SYNOPSIS
        Validates that all required environment variables are set.
    
    .DESCRIPTION
        Checks each placeholder configuration to verify that the corresponding
        environment variable is set and has a non-empty value.
    
    .PARAMETER PlaceholderList
        An array of hashtables containing Placeholder and EnvVar keys.
    
    .OUTPUTS
        System.Boolean - Returns $true if all variables are set, $false otherwise.
    
    .EXAMPLE
        Test-RequiredEnvironmentVariables -PlaceholderList $script:Placeholders
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$PlaceholderList
    )

    [string[]]$missingVars = @()
    
    foreach ($item in $PlaceholderList) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        if ([string]::IsNullOrWhiteSpace($envValue)) {
            $missingVars += $item.EnvVar
        }
    }

    if ($missingVars.Count -gt 0) {
        $errorMessage = "The following required environment variables are not set: $($missingVars -join ', ')"
        Write-Error -Message $errorMessage -Category InvalidOperation -ErrorId 'MissingEnvironmentVariables'
        return $false
    }

    return $true
}

function Update-PlaceholderContent {
    <#
    .SYNOPSIS
        Replaces placeholders in the content with environment variable values.
    
    .DESCRIPTION
        Iterates through the placeholder list and replaces each placeholder
        pattern with the corresponding environment variable value.
    
    .PARAMETER Content
        The content string containing placeholders to replace.
    
    .PARAMETER PlaceholderList
        An array of hashtables containing Placeholder and EnvVar keys.
    
    .OUTPUTS
        System.String - The content with all placeholders replaced.
    
    .EXAMPLE
        Update-PlaceholderContent -Content $json -PlaceholderList $script:Placeholders
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$PlaceholderList
    )

    $result = $Content

    foreach ($item in $PlaceholderList) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        if ($null -ne $envValue) {
            $result = $result.Replace($item.Placeholder, $envValue)
            Write-Verbose -Message "Replaced $($item.Placeholder) with value from $($item.EnvVar)"
        }
    }

    return $result
}

function Get-MaskedValue {
    <#
    .SYNOPSIS
        Returns a masked version of sensitive values for display purposes.
    
    .DESCRIPTION
        Masks sensitive values (URLs, secrets, keys, passwords, connections) 
        to prevent accidental exposure in logs or console output.
    
    .PARAMETER Value
        The value to potentially mask.
    
    .PARAMETER VariableName
        The name of the variable, used to determine if masking is needed.
    
    .OUTPUTS
        System.String - The masked or original value.
    
    .EXAMPLE
        Get-MaskedValue -Value $secret -VariableName 'SERVICE_BUS_CONNECTION_RUNTIME_URL'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VariableName
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return '[Not Set]'
    }

    if ($VariableName -match 'URL|SECRET|KEY|PASSWORD|CONNECTION') {
        $maxLength = [Math]::Min(20, $Value.Length)
        return "$($Value.Substring(0, $maxLength))..."
    }

    return $Value
}

function Write-ReplacementSummary {
    <#
    .SYNOPSIS
        Displays a summary of the placeholder replacements.
    
    .DESCRIPTION
        Outputs a formatted summary showing each environment variable
        and its masked value for verification purposes.
    
    .PARAMETER PlaceholderList
        An array of hashtables containing Placeholder and EnvVar keys.
    
    .EXAMPLE
        Write-ReplacementSummary -PlaceholderList $script:Placeholders
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$PlaceholderList
    )

    Write-Host '=== Replacement Summary ===' -ForegroundColor Cyan
    foreach ($item in $PlaceholderList) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        $displayValue = Get-MaskedValue -Value $envValue -VariableName $item.EnvVar
        Write-Host "  $($item.EnvVar): $displayValue" -ForegroundColor Gray
    }
}

#region Main Execution

try {
    Write-Host '=== Connection Placeholders Replacement Script ===' -ForegroundColor Cyan
    Write-Host ''

    # Resolve the connections file path
    $resolvedPath = $null
    try {
        $resolvedPath = Resolve-Path -Path $ConnectionsFilePath -ErrorAction Stop
    }
    catch {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.IO.FileNotFoundException]::new("Connections file not found: $ConnectionsFilePath"),
                'ConnectionsFileNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $ConnectionsFilePath
            )
        )
    }

    Write-Host "Input file: $resolvedPath" -ForegroundColor Yellow

    # Validate environment variables
    Write-Host 'Validating required environment variables...' -ForegroundColor Yellow
    if (-not (Test-RequiredEnvironmentVariables -PlaceholderList $script:Placeholders)) {
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new('Required environment variables are missing'),
                'MissingEnvironmentVariables',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
        )
    }
    Write-Host 'All required environment variables are set.' -ForegroundColor Green

    # Read the connections file
    Write-Host 'Reading connections file...' -ForegroundColor Yellow
    $content = Get-Content -Path $resolvedPath -Raw -Encoding UTF8

    # Replace placeholders
    Write-Host 'Replacing placeholders with environment variable values...' -ForegroundColor Yellow
    $updatedContent = Update-PlaceholderContent -Content $content -PlaceholderList $script:Placeholders

    # Determine output path
    $outputPath = if ($OutputFilePath) { $OutputFilePath } else { $resolvedPath.Path }

    # Ensure output directory exists
    $outputDir = Split-Path -Path $outputPath -Parent
    if (-not [string]::IsNullOrEmpty($outputDir) -and -not (Test-Path -Path $outputDir)) {
        if ($PSCmdlet.ShouldProcess($outputDir, 'Create directory')) {
            $null = New-Item -ItemType Directory -Path $outputDir -Force
        }
    }

    # Write the updated content
    if ($PSCmdlet.ShouldProcess($outputPath, 'Write updated connections file')) {
        Write-Host "Writing updated connections file to: $outputPath" -ForegroundColor Yellow
        $updatedContent | Set-Content -Path $outputPath -Encoding UTF8 -NoNewline

        Write-Host ''
        Write-Host 'Successfully replaced all placeholders in connections.json' -ForegroundColor Green
        Write-Host ''

        # Display summary of replacements
        Write-ReplacementSummary -PlaceholderList $script:Placeholders
    }
    else {
        Write-Host ''
        Write-Host 'WhatIf: No changes were made to the file.' -ForegroundColor Yellow
    }
}
catch {
    Write-Error -Message "Script execution failed: $($_.Exception.Message)" -Exception $_.Exception
    throw
}
#endregion Main Execution