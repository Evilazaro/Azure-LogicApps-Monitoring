<#
.SYNOPSIS
    Replaces placeholder tokens in connections.json with environment variable values.

.DESCRIPTION
    This script reads the connections.json file and replaces all ${VARIABLE_NAME} 
    placeholders with the corresponding environment variable values.

.PARAMETER ConnectionsFilePath
    Path to the connections.json file. Defaults to the OrdersManagement Logic App connections file.

.PARAMETER OutputFilePath
    Optional output file path. If not specified, the original file will be overwritten.

.EXAMPLE
    ./Replace-ConnectionPlaceholders.ps1
    
.EXAMPLE
    ./Replace-ConnectionPlaceholders.ps1 -ConnectionsFilePath "./custom/connections.json" -OutputFilePath "./output/connections.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConnectionsFilePath = "$PSScriptRoot/../workflows/OrdersManagement/OrdersManagementLogicApp/connections.json",

    [Parameter(Mandatory = $false)]
    [string]$OutputFilePath
)

$ErrorActionPreference = "Stop"

# Define the required environment variables and their placeholder names
$placeholders = @(
    @{ Placeholder = '${AZURE_SUBSCRIPTION_ID}'; EnvVar = 'AZURE_SUBSCRIPTION_ID' }
    @{ Placeholder = '${AZURE_RESOURCE_GROUP}'; EnvVar = 'AZURE_RESOURCE_GROUP' }
    @{ Placeholder = '${MANAGED_IDENTITY_NAME}'; EnvVar = 'MANAGED_IDENTITY_NAME' }
    @{ Placeholder = '${SERVICE_BUS_CONNECTION_RUNTIME_URL}'; EnvVar = 'SERVICE_BUS_CONNECTION_RUNTIME_URL' }
    @{ Placeholder = '${AZURE_BLOB_CONNECTION_RUNTIME_URL}'; EnvVar = 'AZURE_BLOB_CONNECTION_RUNTIME_URL' }
)

function Test-RequiredEnvVariables {
    <#
    .SYNOPSIS
        Validates that all required environment variables are set.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Placeholders
    )

    $missingVars = @()
    
    foreach ($item in $Placeholders) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        if ([string]::IsNullOrWhiteSpace($envValue)) {
            $missingVars += $item.EnvVar
        }
    }

    if ($missingVars.Count -gt 0) {
        Write-Error "The following required environment variables are not set: $($missingVars -join ', ')"
        return $false
    }

    return $true
}

function Replace-Placeholders {
    <#
    .SYNOPSIS
        Replaces placeholders in the content with environment variable values.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [array]$Placeholders
    )

    $result = $Content

    foreach ($item in $Placeholders) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        $result = $result.Replace($item.Placeholder, $envValue)
        Write-Verbose "Replaced $($item.Placeholder) with value from $($item.EnvVar)"
    }

    return $result
}

# Main execution
Write-Host "=== Connection Placeholders Replacement Script ===" -ForegroundColor Cyan
Write-Host ""

# Resolve the connections file path
$resolvedPath = Resolve-Path -Path $ConnectionsFilePath -ErrorAction SilentlyContinue
if (-not $resolvedPath) {
    Write-Error "Connections file not found: $ConnectionsFilePath"
    exit 1
}

Write-Host "Input file: $resolvedPath" -ForegroundColor Yellow

# Validate environment variables
Write-Host "Validating required environment variables..." -ForegroundColor Yellow
if (-not (Test-RequiredEnvVariables -Placeholders $placeholders)) {
    exit 1
}
Write-Host "All required environment variables are set." -ForegroundColor Green

# Read the connections file
Write-Host "Reading connections file..." -ForegroundColor Yellow
$content = Get-Content -Path $resolvedPath -Raw -Encoding UTF8

# Replace placeholders
Write-Host "Replacing placeholders with environment variable values..." -ForegroundColor Yellow
$updatedContent = Replace-Placeholders -Content $content -Placeholders $placeholders

# Determine output path
$outputPath = if ($OutputFilePath) { $OutputFilePath } else { $resolvedPath }

# Ensure output directory exists
$outputDir = Split-Path -Path $outputPath -Parent
if (-not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Write the updated content
Write-Host "Writing updated connections file to: $outputPath" -ForegroundColor Yellow
$updatedContent | Set-Content -Path $outputPath -Encoding UTF8 -NoNewline

Write-Host ""
Write-Host "Successfully replaced all placeholders in connections.json" -ForegroundColor Green
Write-Host ""

# Display summary of replacements
Write-Host "=== Replacement Summary ===" -ForegroundColor Cyan
foreach ($item in $placeholders) {
    $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
    # Mask sensitive values for display
    $displayValue = if ($item.EnvVar -match 'URL|SECRET|KEY|PASSWORD') {
        "$($envValue.Substring(0, [Math]::Min(20, $envValue.Length)))..."
    } else {
        $envValue
    }
    Write-Host "  $($item.EnvVar): $displayValue" -ForegroundColor Gray
}
