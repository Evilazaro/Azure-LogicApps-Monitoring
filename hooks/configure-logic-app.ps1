#!/usr/bin/env pwsh

<#
.SYNOPSIS
Configures Logic App content share settings after deployment

.DESCRIPTION
This script adds the WEBSITE_CONTENTSHARE and WEBSITE_CONTENTAZUREFILECONNECTIONSTRING
app settings to the Logic App after it has been successfully deployed.
This avoids 403 errors during initial Bicep deployment.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$EnvironmentName = $env:AZURE_ENV_NAME
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "Configuring Logic App content share settings..." -ForegroundColor Cyan
Write-Host ""

# Get environment variables
$resourceGroupName = azd env get-value AZURE_RESOURCE_GROUP
$logicAppName = (azd env get-values | Where-Object { $_ -match '^LOGIC_APP_NAME=' }) -replace '^LOGIC_APP_NAME=', ''
$contentShareName = (azd env get-values | Where-Object { $_ -match '^CONTENT_SHARE_NAME=' }) -replace '^CONTENT_SHARE_NAME=', ''
$storageAccountName = azd env get-value AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW

if (-not $logicAppName) {
    Write-Host "Logic App name not found in environment. Attempting to find it..." -ForegroundColor Yellow
    
    # Try to find the Logic App in the resource group
    $logicApps = az functionapp list --resource-group $resourceGroupName --query "[?kind=='functionapp,workflowapp'].name" -o tsv
    
    if ($logicApps) {
        $logicAppName = $logicApps
        Write-Host "Found Logic App: $logicAppName" -ForegroundColor Green
    } else {
        Write-Warning "No Logic App found in resource group: $resourceGroupName"
        exit 0
    }
}

if (-not $contentShareName) {
    $contentShareName = "$logicAppName-content"
    Write-Host "Using default content share name: $contentShareName" -ForegroundColor Yellow
}

Write-Host "Resource Group: $resourceGroupName"
Write-Host "Logic App: $logicAppName"
Write-Host "Content Share: $contentShareName"
Write-Host "Storage Account: $storageAccountName"
Write-Host ""

# Get storage account connection string
Write-Host "Retrieving storage account connection string..." -ForegroundColor Cyan
$storageConnectionString = az storage account show-connection-string `
    --name $storageAccountName `
    --resource-group $resourceGroupName `
    --query connectionString `
    -o tsv

if (-not $storageConnectionString) {
    Write-Error "Failed to retrieve storage connection string"
    exit 1
}

# Check current app settings
Write-Host "Checking current app settings..." -ForegroundColor Cyan
$currentSettings = az webapp config appsettings list `
    --name $logicAppName `
    --resource-group $resourceGroupName `
    --query "[?name=='WEBSITE_CONTENTSHARE' || name=='WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'].name" `
    -o tsv

$hasContentShare = $currentSettings -contains 'WEBSITE_CONTENTSHARE'
$hasConnectionString = $currentSettings -contains 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'

if ($hasContentShare -and $hasConnectionString) {
    Write-Host "Content share settings already configured." -ForegroundColor Green
    exit 0
}

# Add content share settings
Write-Host "Adding content share settings..." -ForegroundColor Cyan
az webapp config appsettings set `
    --name $logicAppName `
    --resource-group $resourceGroupName `
    --settings `
        "WEBSITE_CONTENTSHARE=$contentShareName" `
        "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING=$storageConnectionString" `
    --output none

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✓ Content share settings configured successfully!" -ForegroundColor Green
    Write-Host ""
} else {
    Write-Error "Failed to configure content share settings"
    exit 1
}
