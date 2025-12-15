#!/usr/bin/env pwsh

# Read values from environment variables set by azd
$AZURE_SUBSCRIPTION_ID = $env:AZURE_SUBSCRIPTION_ID
$AZURE_RESOURCE_GROUP = $env:AZURE_RESOURCE_GROUP
$AZURE_LOCATION = $env:AZURE_LOCATION
$AZURE_APPLICATION_INSIGHTS_NAME = $env:AZURE_APPLICATION_INSIGHTS_NAME
$AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING = $env:AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING
$AZURE_TENANT_ID = $env:AZURE_TENANT_ID

Write-Information "Post-provisioning script started." -InformationAction Continue
Write-Information "Subscription ID: $AZURE_SUBSCRIPTION_ID" -InformationAction Continue
Write-Information "Resource Group: $AZURE_RESOURCE_GROUP" -InformationAction Continue
Write-Information "Location: $AZURE_LOCATION" -InformationAction Continue
Write-Information "Application Insights Name: $AZURE_APPLICATION_INSIGHTS_NAME" -InformationAction Continue
write-Information "Application Insights Connection String: $AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING" -InformationAction Continue

# Validate required environment variables
if ([string]::IsNullOrEmpty($AZURE_SUBSCRIPTION_ID)) {
    Write-Error "AZURE_SUBSCRIPTION_ID environment variable is not set."
    exit 1
}
if ([string]::IsNullOrEmpty($AZURE_RESOURCE_GROUP)) {
    Write-Error "AZURE_RESOURCE_GROUP environment variable is not set."
    exit 1
}
if ([string]::IsNullOrEmpty($AZURE_LOCATION)) {
    Write-Error "AZURE_LOCATION environment variable is not set."
    exit 1
}

# Use cross-platform path construction
$scriptRoot = $PSScriptRoot
if ([string]::IsNullOrEmpty($scriptRoot)) {
    $scriptRoot = Get-Location
}
$projectPath = Join-Path -Path $scriptRoot -ChildPath ".." | Join-Path -ChildPath "eShopOrders.AppHost" | Join-Path -ChildPath "eShopOrders.AppHost.csproj"
$projectPath = [System.IO.Path]::GetFullPath($projectPath)

Write-Information "Configuring user secrets for project at $projectPath" -InformationAction Continue

# Verify dotnet CLI is available
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    Write-Error "dotnet CLI not found. Please install .NET SDK."
    exit 1
}

dotnet user-secrets clear -p $projectPath
dotnet user-secrets set "Azure:AllowResourceGroupCreation" false -p $projectPath
dotnet user-secrets set "Azure:SubscriptionId" $AZURE_SUBSCRIPTION_ID -p $projectPath
dotnet user-secrets set "Azure:ResourceGroupName" $AZURE_RESOURCE_GROUP -p $projectPath
dotnet user-secrets set "Azure:Location" $AZURE_LOCATION -p $projectPath
dotnet user-secrets set "Azure:CredentialSource" AzureDeveloperCli -p $projectPath
dotnet user-secrets set "AZURE_APPLICATION_INSIGHTS_NAME" $AZURE_APPLICATION_INSIGHTS_NAME -p $projectPath
dotnet user-secrets set "AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING" $AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING -p $projectPath
dotnet user-secrets set "Azure:TenantId" $AZURE_TENANT_ID -p $projectPath