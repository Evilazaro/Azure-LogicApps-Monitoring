#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys Logic Apps Standard workflows to Azure.

.DESCRIPTION
    Deploys workflow definitions from OrdersManagement Logic App to Azure.
    Runs as azd predeploy hook - environment variables are already loaded.

.NOTES
    Version: 2.0.0
    Requires: Azure CLI 2.50+, PowerShell Core 7.0+
#>

[CmdletBinding()]
param(
    [string]$WorkflowPath
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Placeholder pattern for ${VARIABLE} substitution
$PlaceholderPattern = '\$\{([A-Z_][A-Z0-9_]*)\}'

# Files to exclude from deployment (per .funcignore)
$ExcludePatterns = @('.debug', '.git*', '.vscode', '__azurite*', '__blobstorage__', '__queuestorage__', 'local.settings.json', 'test', 'workflow-designtime')

#region Helper Functions

function Write-Log {
    param([string]$Message, [ValidateSet('Info','Success','Warning','Error')][string]$Level = 'Info')
    $prefix = @{ Info = '[i]'; Success = '[✓]'; Warning = '[!]'; Error = '[✗]' }[$Level]
    $color = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }[$Level]
    Write-Host "$(Get-Date -Format 'HH:mm:ss') $prefix $Message" -ForegroundColor $color
}

function Get-EnvironmentValue {
    param([string]$Name, [string]$Default)
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { return $value }
    return $Default
}

function Set-WorkflowEnvironmentAliases {
    # Map WORKFLOWS_* variables to AZURE_* equivalents for connections.json compatibility
    $mappings = @{
        'WORKFLOWS_SUBSCRIPTION_ID'     = 'AZURE_SUBSCRIPTION_ID'
        'WORKFLOWS_RESOURCE_GROUP_NAME' = 'AZURE_RESOURCE_GROUP'
        'WORKFLOWS_LOCATION_NAME'       = 'AZURE_LOCATION'
    }
    foreach ($key in $mappings.Keys) {
        if (-not [Environment]::GetEnvironmentVariable($key)) {
            $value = [Environment]::GetEnvironmentVariable($mappings[$key])
            if ($value) { [Environment]::SetEnvironmentVariable($key, $value) }
        }
    }
}

function Resolve-Placeholders {
    param([string]$Content, [string]$FileName)
    
    $resolved = $Content
    $unresolved = @()
    
    [regex]::Matches($Content, $PlaceholderPattern) | ForEach-Object {
        $key = $_.Groups[1].Value
        $value = [Environment]::GetEnvironmentVariable($key)
        if ($value) {
            $resolved = $resolved.Replace($_.Value, $value)
        } else {
            $unresolved += $key
        }
    }
    
    if ($unresolved.Count -gt 0) {
        Write-Log "Unresolved in ${FileName}: $($unresolved -join ', ')" -Level Warning
    }
    return $resolved
}

function Get-ConnectionRuntimeUrl {
    param([string]$ConnectionName, [string]$ResourceGroup, [string]$SubscriptionId)
    
    try {
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/$ConnectionName/listConnectionKeys?api-version=2016-06-01"
        $result = az rest --method POST --uri $uri --output json 2>$null | ConvertFrom-Json
        if ($result.runtimeUrls) { return $result.runtimeUrls[0] }
    } catch { }
    return $null
}

#endregion

#region Main

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Logic Apps Standard Workflow Deployment            ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

# Set up environment variable aliases for connections.json compatibility
Set-WorkflowEnvironmentAliases

# Load required configuration from environment
$config = @{
    SubscriptionId     = Get-EnvironmentValue 'AZURE_SUBSCRIPTION_ID'
    ResourceGroup      = Get-EnvironmentValue 'AZURE_RESOURCE_GROUP'
    LogicAppName       = Get-EnvironmentValue 'LOGIC_APP_NAME'
    Location           = Get-EnvironmentValue 'AZURE_LOCATION' 'westus3'
    ServiceBusRuntimeUrl = Get-EnvironmentValue 'SERVICE_BUS_CONNECTION_RUNTIME_URL'
    BlobRuntimeUrl     = Get-EnvironmentValue 'AZURE_BLOB_CONNECTION_RUNTIME_URL'
}

# Validate required values
$missing = @()
if (-not $config.SubscriptionId) { $missing += 'AZURE_SUBSCRIPTION_ID' }
if (-not $config.ResourceGroup) { $missing += 'AZURE_RESOURCE_GROUP' }
if (-not $config.LogicAppName) { $missing += 'LOGIC_APP_NAME' }

if ($missing.Count -gt 0) {
    Write-Log "Missing environment variables: $($missing -join ', ')" -Level Error
    exit 1
}

Write-Log "Target: $($config.LogicAppName) in $($config.ResourceGroup)"

# Find workflow project
$projectPath = if ($WorkflowPath -and (Test-Path $WorkflowPath)) {
    $WorkflowPath
} else {
    $searchPath = Join-Path $PSScriptRoot '..\workflows\OrdersManagement\OrdersManagementLogicApp'
    if (Test-Path $searchPath) { (Resolve-Path $searchPath).Path }
    else { throw 'Workflow project not found' }
}
Write-Log "Source: $projectPath"

# Discover workflows
$workflows = Get-ChildItem -Path $projectPath -Directory | Where-Object {
    (Test-Path (Join-Path $_.FullName 'workflow.json')) -and
    ($ExcludePatterns | ForEach-Object { $_.Name -notlike $_ } | Where-Object { $_ } | Select-Object -First 1)
}

if ($workflows.Count -eq 0) { throw 'No workflows found' }
Write-Log "Workflows: $($workflows.Name -join ', ')" -Level Success

# Get connection runtime URLs if not in environment
if (-not $config.ServiceBusRuntimeUrl) {
    Write-Log "Fetching Service Bus connection runtime URL..."
    $config.ServiceBusRuntimeUrl = Get-ConnectionRuntimeUrl 'servicebus' $config.ResourceGroup $config.SubscriptionId
}
if (-not $config.BlobRuntimeUrl) {
    Write-Log "Fetching Azure Blob connection runtime URL..."
    $config.BlobRuntimeUrl = Get-ConnectionRuntimeUrl 'azureblob' $config.ResourceGroup $config.SubscriptionId
}

# Create staging directory
$stagingDir = Join-Path ([IO.Path]::GetTempPath()) "logicapp-$(Get-Random)"
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

try {
    # Copy host.json
    Copy-Item (Join-Path $projectPath 'host.json') $stagingDir

    # Process connections.json
    $connectionsFile = Join-Path $projectPath 'connections.json'
    if (Test-Path $connectionsFile) {
        $content = Get-Content $connectionsFile -Raw
        $resolved = Resolve-Placeholders $content 'connections.json'
        Set-Content (Join-Path $stagingDir 'connections.json') $resolved
    }

    # Process parameters.json
    $parametersFile = Join-Path $projectPath 'parameters.json'
    if (Test-Path $parametersFile) {
        $content = Get-Content $parametersFile -Raw
        $resolved = Resolve-Placeholders $content 'parameters.json'
        Set-Content (Join-Path $stagingDir 'parameters.json') $resolved
    }

    # Process workflow folders
    foreach ($wf in $workflows) {
        $destDir = Join-Path $stagingDir $wf.Name
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        
        $wfFile = Join-Path $wf.FullName 'workflow.json'
        $content = Get-Content $wfFile -Raw
        $resolved = Resolve-Placeholders $content "$($wf.Name)/workflow.json"
        Set-Content (Join-Path $destDir 'workflow.json') $resolved
    }

    # Create zip package
    $zipPath = Join-Path ([IO.Path]::GetTempPath()) "logicapp-deploy.zip"
    Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -Force
    Write-Log "Package: $([math]::Round((Get-Item $zipPath).Length / 1KB, 1)) KB" -Level Success

    # Update app settings with connection runtime URLs
    Write-Log "Updating application settings..."
    $settings = @()
    if ($config.ServiceBusRuntimeUrl) { $settings += "servicebus-ConnectionRuntimeUrl=$($config.ServiceBusRuntimeUrl)" }
    if ($config.BlobRuntimeUrl) { $settings += "azureblob-ConnectionRuntimeUrl=$($config.BlobRuntimeUrl)" }
    
    if ($settings.Count -gt 0) {
        az functionapp config appsettings set `
            --name $config.LogicAppName `
            --resource-group $config.ResourceGroup `
            --subscription $config.SubscriptionId `
            --settings @settings `
            --output none 2>&1 | Out-Null
    }

    # Deploy
    Write-Log "Deploying workflows..."
    $startTime = Get-Date
    
    az functionapp deployment source config-zip `
        --name $config.LogicAppName `
        --resource-group $config.ResourceGroup `
        --subscription $config.SubscriptionId `
        --src $zipPath `
        --output none

    if ($LASTEXITCODE -ne 0) {
        throw "Deployment failed"
    }

    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
    Write-Log "Deployed in $duration seconds" -Level Success

    # Cleanup
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
}
finally {
    Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║              Deployment Complete                       ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green

#endregion
