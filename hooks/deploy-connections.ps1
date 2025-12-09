#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Deploy Logic App Connections Configuration

.DESCRIPTION
    This script configures the API connections for the Logic App workflow using Azure CLI.
    Compatible with azd workflows and cross-platform execution.

.PARAMETER ResourceGroupName
    The name of the Azure resource group containing the Logic App

.PARAMETER LogicAppName
    The name of the Logic App (Standard) to configure

.PARAMETER QueueConnectionName
    The name of the Azure Queue Storage API connection

.PARAMETER TableConnectionName
    The name of the Azure Table Storage API connection

.PARAMETER WorkflowName
    The name of the workflow within the Logic App (default: eShopOrders)

.PARAMETER ConnectionsJsonPath
    Path to the connections.json template file

.EXAMPLE
    ./deploy-connections.ps1 -ResourceGroupName "rg-myapp" -LogicAppName "mylogicapp" -QueueConnectionName "azurequeues" -TableConnectionName "azuretables"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$LogicAppName,
    
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$QueueConnectionName,
    
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TableConnectionName,
    
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$WorkflowName = 'eShopOrders',
    
    [Parameter()]
    [ValidateScript({ 
        if (-not (Test-Path -Path $_ -PathType Leaf)) {
            throw "File not found: $_"
        }
        return $true
    })]
    [string]$ConnectionsJsonPath = (Join-Path -Path $PSScriptRoot -ChildPath '..\infra\workload\connections.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

# Initialize temp file variable in outer scope
$tempConnectionsFile = $null

# Detect if terminal supports Unicode (for emojis)
$useEmoji = $PSVersionTable.PSVersion.Major -ge 7 -and 
            ($IsLinux -or $IsMacOS -or 
            ($IsWindows -and [System.Console]::OutputEncoding.CodePage -eq 65001))

function Write-StatusMessage {
    param(
        [string]$Message,
        [string]$Emoji,
        [string]$Prefix,
        [ConsoleColor]$Color = 'White'
    )
    $displayMessage = if ($useEmoji) { "$Emoji $Message" } else { "[$Prefix] $Message" }
    Write-Host $displayMessage -ForegroundColor $Color
}

function Invoke-AzCli {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        
        [Parameter()]
        [string]$ErrorMessage = "Azure CLI command failed"
    )
    
    Write-Verbose "Executing: az $($Arguments -join ' ')"
    $output = & az @Arguments 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        throw "$ErrorMessage. Exit code: $LASTEXITCODE. Output: $output"
    }
    
    return $output
}

# Check if Azure CLI is available
Write-Verbose "Checking for Azure CLI..."
$azCliCheck = Get-Command az -ErrorAction SilentlyContinue
if (-not $azCliCheck) {
    $errorMsg = "Azure CLI (az) is not installed or not in PATH. Please install it from: https://learn.microsoft.com/cli/azure/install-azure-cli"
    Write-Host "❌ $errorMsg" -ForegroundColor Red
    throw $errorMsg
}

# Ensure we're logged in to Azure CLI
Write-Verbose "Checking Azure CLI authentication..."
try {
    $accountInfo = az account show 2>&1 | ConvertFrom-Json
    if (-not $accountInfo) {
        throw "Not authenticated"
    }
    Write-Verbose "Authenticated as: $($accountInfo.user.name)"
}
catch {
    throw "Not authenticated to Azure CLI. Please run 'az login' first."
}

Write-StatusMessage -Message 'Configuring Logic App connections...' -Emoji '📋' -Prefix 'INFO' -Color Cyan

try {
    # Get subscription and location info
    Write-Verbose "Retrieving subscription information..."
    $subscription = az account show | ConvertFrom-Json
    $subscriptionId = $subscription.id
    
    Write-Verbose "Retrieving Logic App resource: $LogicAppName"
    $logicAppJson = Invoke-AzCli -Arguments @(
        'resource', 'show',
        '--resource-group', $ResourceGroupName,
        '--resource-type', 'Microsoft.Web/sites',
        '--name', $LogicAppName
    ) -ErrorMessage "Failed to retrieve Logic App '$LogicAppName'"
    
    $logicApp = $logicAppJson | ConvertFrom-Json
    $location = $logicApp.location
    
    Write-Verbose "Subscription: $subscriptionId"
    Write-Verbose "Location: $location"

    # Get the connection resources
    Write-StatusMessage -Message 'Retrieving API connection resources...' -Emoji '🔍' -Prefix 'SEARCH' -Color Yellow
    
    Write-Verbose "Retrieving Queue connection: $QueueConnectionName"
    $queueConnectionJson = Invoke-AzCli -Arguments @(
        'resource', 'show',
        '--resource-group', $ResourceGroupName,
        '--resource-type', 'Microsoft.Web/connections',
        '--name', $QueueConnectionName
    ) -ErrorMessage "Queue connection '$QueueConnectionName' not found in resource group '$ResourceGroupName'"
    
    $queueConnection = $queueConnectionJson | ConvertFrom-Json
    
    Write-Verbose "Retrieving Table connection: $TableConnectionName"
    $tableConnectionJson = Invoke-AzCli -Arguments @(
        'resource', 'show',
        '--resource-group', $ResourceGroupName,
        '--resource-type', 'Microsoft.Web/connections',
        '--name', $TableConnectionName
    ) -ErrorMessage "Table connection '$TableConnectionName' not found in resource group '$ResourceGroupName'"
    
    $tableConnection = $tableConnectionJson | ConvertFrom-Json

    # Get connection runtime URLs
    Write-StatusMessage -Message 'Retrieving connection runtime URLs...' -Emoji '🔗' -Prefix 'LINK' -Color Yellow
    
    $queueRuntimeUrl = $queueConnection.properties.connectionRuntimeUrl
    $tableRuntimeUrl = $tableConnection.properties.connectionRuntimeUrl
    
    $queueConnectionId = $queueConnection.id
    $tableConnectionId = $tableConnection.id

    Write-Verbose "Queue Runtime URL: $queueRuntimeUrl"
    Write-Verbose "Table Runtime URL: $tableRuntimeUrl"

    # Read and update connections.json
    Write-StatusMessage -Message 'Reading connections template...' -Emoji '📄' -Prefix 'READ' -Color Yellow
    $connectionsJson = Get-Content -Path $ConnectionsJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json

    # Update queue connection
    $connectionsJson.managedApiConnections.azurequeues.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azurequeues"
    $connectionsJson.managedApiConnections.azurequeues.connection.id = $queueConnectionId
    $connectionsJson.managedApiConnections.azurequeues.connectionRuntimeUrl = $queueRuntimeUrl

    # Update table connection
    $connectionsJson.managedApiConnections.azuretables.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azuretables"
    $connectionsJson.managedApiConnections.azuretables.connection.id = $tableConnectionId
    $connectionsJson.managedApiConnections.azuretables.connectionRuntimeUrl = $tableRuntimeUrl

    # Save to temp file with proper encoding and platform-agnostic path
    $tempDir = if ($IsWindows) { $env:TEMP } elseif ($IsLinux -or $IsMacOS) { '/tmp' } else { [System.IO.Path]::GetTempPath() }
    $tempConnectionsFile = Join-Path -Path $tempDir -ChildPath "connections_$([Guid]::NewGuid()).json"
    
    # Convert to JSON with platform-neutral line endings
    $jsonContent = $connectionsJson | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($tempConnectionsFile, $jsonContent, [System.Text.UTF8Encoding]::new($false))

    Write-StatusMessage -Message 'Deploying connections.json to Logic App...' -Emoji '🚀' -Prefix 'DEPLOY' -Color Yellow

    # Use Azure CLI to upload the connections.json file (use forward slash for Azure path)
    $workflowPath = "$WorkflowName/connections.json"
    
    # Invoke Azure CLI in a platform-agnostic way
    Invoke-AzCli -Arguments @(
        'functionapp', 'deploy',
        '--resource-group', $ResourceGroupName,
        '--name', $LogicAppName,
        '--src-path', $tempConnectionsFile,
        '--type', 'static',
        '--target-path', $workflowPath
    ) -ErrorMessage "Failed to deploy connections.json to Logic App" | Out-Null

    Write-StatusMessage -Message 'Connections.json deployed successfully!' -Emoji '✅' -Prefix 'SUCCESS' -Color Green

    Write-Host ""
    Write-StatusMessage -Message 'Logic App connections configured successfully!' -Emoji '✅' -Prefix 'SUCCESS' -Color Green
    Write-Host ""
    Write-StatusMessage -Message 'Connection Details:' -Emoji '📊' -Prefix 'INFO' -Color Cyan
    $bullet = if ($useEmoji) { '•' } else { '-' }
    Write-Host "  $bullet Queue Connection: $queueConnectionId" -ForegroundColor Gray
    Write-Host "  $bullet Table Connection: $tableConnectionId" -ForegroundColor Gray
    
    exit 0
}
catch {
    $errorPrefix = if ($useEmoji) { '❌' } else { '[ERROR]' }
    Write-Host "$errorPrefix Error configuring Logic App connections: $_" -ForegroundColor Red
    Write-Verbose "Stack Trace: $($_.ScriptStackTrace)"
    
    # Ensure temp file cleanup on error
    if ($tempConnectionsFile -and (Test-Path -Path $tempConnectionsFile -ErrorAction SilentlyContinue)) {
        Remove-Item -Path $tempConnectionsFile -Force -ErrorAction SilentlyContinue
    }
    
    exit 1
}
finally {
    # Clean up temp file (if not already cleaned in catch)
    if ($tempConnectionsFile -and (Test-Path -Path $tempConnectionsFile -ErrorAction SilentlyContinue)) {
        Remove-Item -Path $tempConnectionsFile -Force -ErrorAction SilentlyContinue
        Write-Verbose "Cleaned up temporary file: $tempConnectionsFile"
    }
}
