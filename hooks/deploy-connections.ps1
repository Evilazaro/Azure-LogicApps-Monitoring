#!/usr/bin/env pwsh
#Requires -Version 7.0
<#
.SYNOPSIS
    Deploy Logic App Connections Configuration

.DESCRIPTION
    This script configures the API connections for the Logic App workflow using modern PowerShell 7+ features.

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
    [string]$ConnectionsJsonPath = (Join-Path -Path $PSScriptRoot -ChildPath 'connections.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

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

Write-StatusMessage -Message 'Configuring Logic App connections...' -Emoji '📋' -Prefix 'INFO' -Color Cyan

try {
    # Get subscription and location info
    Write-Verbose "Retrieving Logic App resource: $LogicAppName"
    $logicApp = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType 'Microsoft.Web/sites' -Name $LogicAppName -ErrorAction Stop
    
    $context = Get-AzContext -ErrorAction Stop
    $subscriptionId = $context.Subscription.Id
    $location = $logicApp.Location
    
    Write-Verbose "Subscription: $subscriptionId"
    Write-Verbose "Location: $location"

    # Get the connection resources in parallel
    Write-StatusMessage -Message 'Retrieving API connection resources...' -Emoji '🔍' -Prefix 'SEARCH' -Color Yellow
    
    $connections = @(
        @{ Name = $QueueConnectionName; Type = 'Queue' }
        @{ Name = $TableConnectionName; Type = 'Table' }
    ) | ForEach-Object -Parallel {
        $conn = $_
        $result = Get-AzResource -ResourceGroupName $using:ResourceGroupName `
            -ResourceType 'Microsoft.Web/connections' `
            -Name $conn.Name `
            -ErrorAction SilentlyContinue
        
        [PSCustomObject]@{
            Type = $conn.Type
            Name = $conn.Name
            Resource = $result
        }
    } -ThrottleLimit 2

    $queueConnection = ($connections | Where-Object Type -eq 'Queue').Resource
    $tableConnection = ($connections | Where-Object Type -eq 'Table').Resource

    if (-not $queueConnection) {
        throw "Queue connection '$QueueConnectionName' not found in resource group '$ResourceGroupName'"
    }

    if (-not $tableConnection) {
        throw "Table connection '$TableConnectionName' not found in resource group '$ResourceGroupName'"
    }

    # Get connection runtime URLs in parallel
    Write-StatusMessage -Message 'Retrieving connection runtime URLs...' -Emoji '🔗' -Prefix 'LINK' -Color Yellow
    
    $connectionDetails = @($queueConnection, $tableConnection) | ForEach-Object -Parallel {
        $conn = $_
        $props = Get-AzResource -ResourceId $conn.ResourceId -ErrorAction Stop | 
            Select-Object -ExpandProperty Properties
        
        [PSCustomObject]@{
            ResourceId = $conn.ResourceId
            RuntimeUrl = $props.connectionRuntimeUrl
        }
    } -ThrottleLimit 2

    $queueRuntimeUrl = ($connectionDetails | Where-Object ResourceId -eq $queueConnection.ResourceId).RuntimeUrl
    $tableRuntimeUrl = ($connectionDetails | Where-Object ResourceId -eq $tableConnection.ResourceId).RuntimeUrl

    Write-Verbose "Queue Runtime URL: $queueRuntimeUrl"
    Write-Verbose "Table Runtime URL: $tableRuntimeUrl"

    # Read and update connections.json
    Write-StatusMessage -Message 'Reading connections template...' -Emoji '📄' -Prefix 'READ' -Color Yellow
    $connectionsJson = Get-Content -Path $ConnectionsJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable:$false

    # Update queue connection using modern property access
    $connectionsJson.managedApiConnections.azurequeues.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azurequeues"
    $connectionsJson.managedApiConnections.azurequeues.connection.id = $queueConnection.ResourceId
    $connectionsJson.managedApiConnections.azurequeues.connectionRuntimeUrl = $queueRuntimeUrl

    # Update table connection
    $connectionsJson.managedApiConnections.azuretables.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azuretables"
    $connectionsJson.managedApiConnections.azuretables.connection.id = $tableConnection.ResourceId
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
    $azCliArgs = @(
        'functionapp', 'deploy',
        '--resource-group', $ResourceGroupName,
        '--name', $LogicAppName,
        '--src-path', $tempConnectionsFile,
        '--type', 'static',
        '--target-path', $workflowPath
    )
    
    Write-Verbose "Executing: az $($azCliArgs -join ' ')"
    $deployOutput = & az @azCliArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy connections.json. Azure CLI output: $deployOutput"
    }

    Write-StatusMessage -Message 'Connections.json deployed successfully!' -Emoji '✅' -Prefix 'SUCCESS' -Color Green

    Write-Host ""
    Write-StatusMessage -Message 'Logic App connections configured successfully!' -Emoji '✅' -Prefix 'SUCCESS' -Color Green
    Write-Host ""
    Write-StatusMessage -Message 'Connection Details:' -Emoji '📊' -Prefix 'INFO' -Color Cyan
    $bullet = if ($useEmoji) { '•' } else { '-' }
    Write-Host "  $bullet Queue Connection: $($queueConnection.ResourceId)" -ForegroundColor Gray
    Write-Host "  $bullet Table Connection: $($tableConnection.ResourceId)" -ForegroundColor Gray
    
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
