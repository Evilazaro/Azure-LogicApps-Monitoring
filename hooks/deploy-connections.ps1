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
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]$ConnectionsJsonPath = (Join-Path $PSScriptRoot 'connections.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

Write-Host '📋 Configuring Logic App connections...' -ForegroundColor Cyan

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
    Write-Host '🔍 Retrieving API connection resources...' -ForegroundColor Yellow
    
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
    Write-Host '🔗 Retrieving connection runtime URLs...' -ForegroundColor Yellow
    
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
    Write-Host '📄 Reading connections template...' -ForegroundColor Yellow
    $connectionsJson = Get-Content -Path $ConnectionsJsonPath -Raw -ErrorAction Stop | ConvertFrom-Json

    # Update queue connection using modern property access
    $connectionsJson.managedApiConnections.azurequeues.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azurequeues"
    $connectionsJson.managedApiConnections.azurequeues.connection.id = $queueConnection.ResourceId
    $connectionsJson.managedApiConnections.azurequeues.connectionRuntimeUrl = $queueRuntimeUrl

    # Update table connection
    $connectionsJson.managedApiConnections.azuretables.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azuretables"
    $connectionsJson.managedApiConnections.azuretables.connection.id = $tableConnection.ResourceId
    $connectionsJson.managedApiConnections.azuretables.connectionRuntimeUrl = $tableRuntimeUrl

    # Save to temp file with proper encoding
    $tempConnectionsFile = Join-Path ([System.IO.Path]::GetTempPath()) "connections_$([Guid]::NewGuid()).json"
    $connectionsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $tempConnectionsFile -Encoding utf8NoBOM -ErrorAction Stop

    Write-Host '🚀 Deploying connections.json to Logic App...' -ForegroundColor Yellow

    # Use Azure CLI to upload the connections.json file
    $workflowPath = "$WorkflowName/connections.json"
    
    $deployOutput = az functionapp deploy `
        --resource-group $ResourceGroupName `
        --name $LogicAppName `
        --src-path $tempConnectionsFile `
        --type static `
        --target-path $workflowPath `
        2>&1

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to deploy connections.json. Azure CLI output: $deployOutput"
    }

    Write-Host '✅ Connections.json deployed successfully!' -ForegroundColor Green

    Write-Host "`n✅ Logic App connections configured successfully!" -ForegroundColor Green
    Write-Host "`n📊 Connection Details:" -ForegroundColor Cyan
    Write-Host "  • Queue Connection: $($queueConnection.ResourceId)" -ForegroundColor Gray
    Write-Host "  • Table Connection: $($tableConnection.ResourceId)" -ForegroundColor Gray
    
    exit 0
}
catch {
    Write-Error "❌ Error configuring Logic App connections: $_"
    Write-Verbose "Stack Trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Clean up temp file
    if (Test-Path -Path $tempConnectionsFile -ErrorAction SilentlyContinue) {
        Remove-Item -Path $tempConnectionsFile -Force -ErrorAction SilentlyContinue
        Write-Verbose "Cleaned up temporary file: $tempConnectionsFile"
    }
}
