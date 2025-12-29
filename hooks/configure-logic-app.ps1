#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Configures Logic App content share settings after deployment.

.DESCRIPTION
    This script adds the WEBSITE_CONTENTSHARE and WEBSITE_CONTENTAZUREFILECONNECTIONSTRING
    app settings to the Logic App after it has been successfully deployed.
    This avoids 403 errors during initial Bicep deployment.

.PARAMETER EnvironmentName
    The Azure Developer CLI environment name. Defaults to AZURE_ENV_NAME environment variable.

.EXAMPLE
    .\configure-logic-app.ps1
    
.EXAMPLE
    .\configure-logic-app.ps1 -EnvironmentName "dev"

.NOTES
    Requires Azure CLI (az) and Azure Developer CLI (azd) to be installed and authenticated.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$EnvironmentName = $env:AZURE_ENV_NAME
)

#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

#region Helper Functions

function Write-StatusMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Type = 'Info'
    )
    
    $colorMap = @{
        'Info'    = 'Cyan'
        'Success' = 'Green'
        'Warning' = 'Yellow'
        'Error'   = 'Red'
    }
    
    $symbolMap = @{
        'Info'    = 'ℹ'
        'Success' = '✓'
        'Warning' = '⚠'
        'Error'   = '✗'
    }
    
    Write-Host "$($symbolMap[$Type]) $Message" -ForegroundColor $colorMap[$Type]
}

function Invoke-AzCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,
        
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments,
        
        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = 'Azure CLI command failed'
    )
    
    try {
        $result = & az $Command @Arguments 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "$ErrorMessage. Exit code: $LASTEXITCODE"
        }
        return $result
    }
    catch {
        throw "$ErrorMessage`: $_"
    }
}

function Get-AzdEnvironmentValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )
    
    try {
        $value = & azd env get-value $Key 2>&1
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($value)) {
            return $value.Trim()
        }
        return $null
    }
    catch {
        Write-Verbose "Failed to get environment value for key '$Key': $_"
        return $null
    }
}

function Get-LogicAppFromResourceGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    $arguments = @(
        'functionapp', 'list',
        '--resource-group', $ResourceGroupName,
        '--query', "[?kind=='functionapp,workflowapp'].name",
        '-o', 'tsv'
    )
    
    $result = Invoke-AzCommand -Command 'functionapp' -Arguments $arguments -ErrorMessage 'Failed to list Logic Apps'
    
    if ([string]::IsNullOrWhiteSpace($result)) {
        return $null
    }
    
    # Return first Logic App if multiple found
    $apps = $result -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    return $apps[0].Trim()
}

#endregion

#region Main Script

try {
    Write-Host ''
    Write-StatusMessage -Message 'Configuring Logic App content share settings...' -Type Info
    Write-Host ''
    
    # Validate required tools
    $requiredCommands = @('az', 'azd')
    foreach ($cmd in $requiredCommands) {
        if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
            throw "Required command '$cmd' not found. Please install Azure CLI and Azure Developer CLI."
        }
    }
    
    # Get environment variables
    Write-Verbose 'Retrieving environment configuration...'
    $resourceGroupName = Get-AzdEnvironmentValue -Key 'AZURE_RESOURCE_GROUP'
    $storageAccountName = Get-AzdEnvironmentValue -Key 'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW'
    
    if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
        throw 'AZURE_RESOURCE_GROUP environment variable is not set'
    }
    
    if ([string]::IsNullOrWhiteSpace($storageAccountName)) {
        throw 'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW environment variable is not set'
    }
    
    # Get Logic App name
    $logicAppName = Get-AzdEnvironmentValue -Key 'LOGIC_APP_NAME'
    
    if ([string]::IsNullOrWhiteSpace($logicAppName)) {
        Write-StatusMessage -Message 'Logic App name not found in environment. Searching resource group...' -Type Warning
        
        $logicAppName = Get-LogicAppFromResourceGroup -ResourceGroupName $resourceGroupName
        
        if ([string]::IsNullOrWhiteSpace($logicAppName)) {
            Write-StatusMessage -Message "No Logic App found in resource group: $resourceGroupName" -Type Warning
            return 0
        }
        
        Write-StatusMessage -Message "Found Logic App: $logicAppName" -Type Success
    }
    
    # Get content share name
    $contentShareName = Get-AzdEnvironmentValue -Key 'CONTENT_SHARE_NAME'
    
    if ([string]::IsNullOrWhiteSpace($contentShareName)) {
        $contentShareName = "$logicAppName-content"
        Write-StatusMessage -Message "Using default content share name: $contentShareName" -Type Warning
    }
    
    # Display configuration
    Write-Host ''
    Write-Host 'Configuration:' -ForegroundColor Cyan
    Write-Host "  Resource Group   : $resourceGroupName"
    Write-Host "  Logic App        : $logicAppName"
    Write-Host "  Content Share    : $contentShareName"
    Write-Host "  Storage Account  : $storageAccountName"
    Write-Host ''
    
    # Get storage account connection string
    Write-StatusMessage -Message 'Retrieving storage account connection string...' -Type Info
    
    $connectionStringArgs = @(
        'storage', 'account', 'show-connection-string',
        '--name', $storageAccountName,
        '--resource-group', $resourceGroupName,
        '--query', 'connectionString',
        '-o', 'tsv'
    )
    
    $storageConnectionString = Invoke-AzCommand `
        -Command 'storage' `
        -Arguments $connectionStringArgs `
        -ErrorMessage 'Failed to retrieve storage connection string'
    
    if ([string]::IsNullOrWhiteSpace($storageConnectionString)) {
        throw 'Storage connection string is empty'
    }
    
    # Check current app settings
    Write-StatusMessage -Message 'Checking current app settings...' -Type Info
    
    $settingsArgs = @(
        'webapp', 'config', 'appsettings', 'list',
        '--name', $logicAppName,
        '--resource-group', $resourceGroupName,
        '--query', "[?name=='WEBSITE_CONTENTSHARE' || name=='WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'].name",
        '-o', 'tsv'
    )
    
    $currentSettings = Invoke-AzCommand `
        -Command 'webapp' `
        -Arguments $settingsArgs `
        -ErrorMessage 'Failed to retrieve current app settings'
    
    $settingsArray = $currentSettings -split "`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_.Trim() }
    $hasContentShare = $settingsArray -contains 'WEBSITE_CONTENTSHARE'
    $hasConnectionString = $settingsArray -contains 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
    
    if ($hasContentShare -and $hasConnectionString) {
        Write-StatusMessage -Message 'Content share settings already configured.' -Type Success
        return 0
    }
    
    # Add content share settings
    Write-StatusMessage -Message 'Adding content share settings...' -Type Info
    
    $updateArgs = @(
        'webapp', 'config', 'appsettings', 'set',
        '--name', $logicAppName,
        '--resource-group', $resourceGroupName,
        '--settings',
        "WEBSITE_CONTENTSHARE=$contentShareName",
        "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING=$storageConnectionString",
        '--output', 'none'
    )
    
    Invoke-AzCommand `
        -Command 'webapp' `
        -Arguments $updateArgs `
        -ErrorMessage 'Failed to configure content share settings'
    
    Write-Host ''
    Write-StatusMessage -Message 'Content share settings configured successfully!' -Type Success
    Write-Host ''
    
    return 0
}
catch {
    Write-Host ''
    Write-StatusMessage -Message $_.Exception.Message -Type Error
    Write-Host ''
    
    if ($VerbosePreference -eq 'Continue') {
        Write-Host 'Stack Trace:' -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
    }
    
    return 1
}

#endregion
