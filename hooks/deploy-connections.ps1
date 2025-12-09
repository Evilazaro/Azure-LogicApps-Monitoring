# Deploy Logic App Connections Configuration
# This script configures the API connections for the Logic App workflow

param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$LogicAppName,
    
    [Parameter(Mandatory=$true)]
    [string]$QueueConnectionName,
    
    [Parameter(Mandatory=$true)]
    [string]$TableConnectionName,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkflowName = "eShopOrders",
    
    [Parameter(Mandatory=$false)]
    [string]$ConnectionsJsonPath = "$PSScriptRoot/connections.json"
)

Write-Host "Configuring Logic App connections..." -ForegroundColor Cyan

# Get subscription and location info
$logicApp = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Web/sites" -Name $LogicAppName
$subscriptionId = (Get-AzContext).Subscription.Id
$location = $logicApp.Location

# Get the connection resources
$queueConnection = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Web/connections" -Name $QueueConnectionName
$tableConnection = Get-AzResource -ResourceGroupName $ResourceGroupName -ResourceType "Microsoft.Web/connections" -Name $TableConnectionName

if (-not $queueConnection) {
    Write-Error "Queue connection '$QueueConnectionName' not found in resource group '$ResourceGroupName'"
    exit 1
}

if (-not $tableConnection) {
    Write-Error "Table connection '$TableConnectionName' not found in resource group '$ResourceGroupName'"
    exit 1
}

# Get connection runtime URLs
Write-Host "Retrieving connection runtime URLs..." -ForegroundColor Yellow
$queueConnectionProps = Get-AzResource -ResourceId $queueConnection.ResourceId | Select-Object -ExpandProperty Properties
$tableConnectionProps = Get-AzResource -ResourceId $tableConnection.ResourceId | Select-Object -ExpandProperty Properties

$queueRuntimeUrl = $queueConnectionProps.connectionRuntimeUrl
$tableRuntimeUrl = $tableConnectionProps.connectionRuntimeUrl

# Read and update connections.json
Write-Host "Reading connections template..." -ForegroundColor Yellow
$connectionsJson = Get-Content -Path $ConnectionsJsonPath -Raw | ConvertFrom-Json

# Update queue connection
$connectionsJson.managedApiConnections.azurequeues.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azurequeues"
$connectionsJson.managedApiConnections.azurequeues.connection.id = $queueConnection.ResourceId
$connectionsJson.managedApiConnections.azurequeues.connectionRuntimeUrl = $queueRuntimeUrl

# Update table connection
$connectionsJson.managedApiConnections.azuretables.api.id = "/subscriptions/$subscriptionId/providers/Microsoft.Web/locations/$location/managedApis/azuretables"
$connectionsJson.managedApiConnections.azuretables.connection.id = $tableConnection.ResourceId
$connectionsJson.managedApiConnections.azuretables.connectionRuntimeUrl = $tableRuntimeUrl

# Save to temp file
$tempConnectionsFile = Join-Path $env:TEMP "connections_$([Guid]::NewGuid()).json"
$connectionsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $tempConnectionsFile

Write-Host "Deploying connections.json to Logic App..." -ForegroundColor Yellow

# Use Azure CLI to upload the connections.json file
$workflowPath = "$WorkflowName/connections.json"
az functionapp deploy --resource-group $ResourceGroupName --name $LogicAppName --src-path $tempConnectionsFile --type static --target-path $workflowPath

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Connections.json deployed successfully!" -ForegroundColor Green
} else {
    Write-Error "Failed to deploy connections.json"
    exit 1
}

# Clean up temp file
Remove-Item -Path $tempConnectionsFile -Force

Write-Host "✓ Logic App connections configured successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Connection Details:" -ForegroundColor Cyan
Write-Host "  Queue Connection: $($queueConnection.ResourceId)" -ForegroundColor Gray
Write-Host "  Table Connection: $($tableConnection.ResourceId)" -ForegroundColor Gray
