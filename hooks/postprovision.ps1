#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Post-provisioning script for Azure Developer CLI (azd).

.DESCRIPTION
    Configures .NET user secrets with Azure resource information after provisioning.
    This script is automatically executed by azd after infrastructure provisioning completes.

.NOTES
    File Name      : postprovision.ps1
    Prerequisite   : .NET SDK, Azure Developer CLI
    Required Env   : AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, AZURE_LOCATION
#>

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

#region Functions

function Test-RequiredEnvironmentVariable {
    <#
    .SYNOPSIS
        Validates that a required environment variable is set.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Error "Required environment variable '$Name' is not set."
        return $false
    }
    return $true
}

function Set-DotNetUserSecret {
    <#
    .SYNOPSIS
        Sets a .NET user secret with error handling.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Value,
        
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )
    
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Verbose "Skipping secret '$Key' - value is empty"
        return
    }
    
    try {
        $output = & dotnet user-secrets set $Key $Value -p $ProjectPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to set secret '$Key'. Exit code: $LASTEXITCODE. Output: $output"
        }
        Write-Verbose "Successfully set secret: $Key"
    }
    catch {
        Write-Error "Error setting user secret '$Key': $_"
        throw
    }
}

function Get-ProjectPath {
    <#
    .SYNOPSIS
        Constructs the cross-platform path to the project file.
    #>
    [CmdletBinding()]
    param()
    
    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptRoot = Get-Location
    }
    
    $path = Join-Path -Path $scriptRoot -ChildPath '..'
    $path = Join-Path -Path $path -ChildPath 'eShopOrders.AppHost'
    $path = Join-Path -Path $path -ChildPath 'eShopOrders.AppHost.csproj'
    
    return [System.IO.Path]::GetFullPath($path)
}

#endregion

#region Main Script

try {
    Write-Information "═══════════════════════════════════════════════════════"
    Write-Information "Post-provisioning script started"
    Write-Information "═══════════════════════════════════════════════════════"
    
    # Read environment variables
    $azureSubscriptionId = $env:AZURE_SUBSCRIPTION_ID
    $azureResourceGroup = $env:AZURE_RESOURCE_GROUP
    $azureLocation = $env:AZURE_LOCATION
    $azureApplicationInsightsName = $env:AZURE_APPLICATION_INSIGHTS_NAME
    $azureApplicationInsightsConnectionString = $env:AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING
    $azureTenantId = $env:AZURE_TENANT_ID
    $azureClientId = $env:AZURE_CLIENT_ID
    $azureServiceBusNamespace = $env:AZURE_SERVICE_BUS_NAMESPACE
    $azureEnvName = $env:AZURE_ENV_NAME
    
    # Display configuration
    Write-Information "`nAzure Configuration:"
    Write-Information "  Subscription ID        : $azureSubscriptionId"
    Write-Information "  Resource Group         : $azureResourceGroup"
    Write-Information "  Location               : $azureLocation"
    Write-Information "  Environment Name       : $azureEnvName"
    Write-Information "  Tenant ID              : $azureTenantId"
    Write-Information "  Client ID              : $azureClientId"
    Write-Information "  App Insights Name      : $azureApplicationInsightsName"
    Write-Information "  Service Bus Namespace  : $azureServiceBusNamespace"
    
    # Validate required environment variables
    Write-Information "`nValidating required environment variables..."
    $requiredVars = @('AZURE_SUBSCRIPTION_ID', 'AZURE_RESOURCE_GROUP', 'AZURE_LOCATION')
    $validationFailed = $false
    
    foreach ($varName in $requiredVars) {
        if (-not (Test-RequiredEnvironmentVariable -Name $varName)) {
            $validationFailed = $true
        }
    }
    
    if ($validationFailed) {
        throw "One or more required environment variables are missing."
    }
    
    # Verify dotnet CLI is available
    Write-Information "`nVerifying .NET SDK installation..."
    $dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCommand) {
        throw ".NET CLI not found. Please install .NET SDK from https://dotnet.microsoft.com/download"
    }
    
    $dotnetVersion = & dotnet --version
    Write-Information "  .NET SDK Version: $dotnetVersion"
    
    # Get project path
    $projectPath = Get-ProjectPath
    Write-Information "`nProject Path: $projectPath"
    
    # Verify project file exists
    if (-not (Test-Path -Path $projectPath -PathType Leaf)) {
        throw "Project file not found at: $projectPath"
    }
    
    # Clear existing user secrets
    Write-Information "`nClearing existing user secrets..."
    $output = & dotnet user-secrets clear -p $projectPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to clear user secrets. Output: $output"
    }
    
    # Configure user secrets
    Write-Information "`nConfiguring user secrets..."
    
    # Define secrets configuration
    $secrets = @{
        'Azure:AllowResourceGroupCreation'                  = 'false'
        'Azure:SubscriptionId'                              = $azureSubscriptionId
        'Azure:ResourceGroupName'                           = $azureResourceGroup
        'Azure:Location'                                    = $azureLocation
        'Azure:CredentialSource'                            = 'AzureDeveloperCli'
        'Azure:ClientId'                                    = $azureClientId
        'AZURE_APPLICATION_INSIGHTS_NAME'                   = $azureApplicationInsightsName
        'AZURE_APPLICATION_INSIGHTS_CONNECTION_STRING'      = $azureApplicationInsightsConnectionString
        'AZURE_TENANT_ID'                                   = $azureTenantId
        'AZURE_SERVICE_BUS_NAMESPACE'                       = $azureServiceBusNamespace
        'AZURE_ENV_NAME'                                    = $azureEnvName
    }
    
    # Set each secret
    foreach ($key in $secrets.Keys) {
        Set-DotNetUserSecret -Key $key -Value $secrets[$key] -ProjectPath $projectPath
    }
    
    Write-Information "`n═══════════════════════════════════════════════════════"
    Write-Information "Post-provisioning completed successfully!"
    Write-Information "═══════════════════════════════════════════════════════`n"
    
    exit 0
}
catch {
    Write-Error "`n═══════════════════════════════════════════════════════"
    Write-Error "Post-provisioning failed!"
    Write-Error "Error: $_"
    Write-Error "═══════════════════════════════════════════════════════`n"
    
    exit 1
}

#endregion