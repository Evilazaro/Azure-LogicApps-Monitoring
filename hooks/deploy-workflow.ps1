#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys Logic Apps Standard workflows to Azure.

.DESCRIPTION
    This script deploys workflow definitions from the OrdersManagement Logic App to Azure.
    It is designed to run as an Azure Developer CLI (azd) predeploy hook, where environment
    variables are automatically loaded from the azd environment.

    The script performs the following operations:
    1. Validates required environment variables (AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, LOGIC_APP_NAME)
    2. Discovers workflow directories containing workflow.json files
    3. Resolves ${VARIABLE} placeholders in connections.json, parameters.json, and workflow.json files
    4. Fetches connection runtime URLs for Service Bus and Azure Blob connections if not provided
    5. Creates a deployment package (zip) with processed files
    6. Updates Logic App application settings with connection runtime URLs
    7. Deploys the package using Azure CLI zip deployment

    Environment variable aliases are automatically set up to map AZURE_* variables to
    WORKFLOWS_* equivalents for connections.json compatibility.

.PARAMETER WorkflowPath
    Optional path to the workflow project directory. If not specified, defaults to
    '../workflows/OrdersManagement/OrdersManagementLogicApp' relative to script location.
    The directory must contain host.json and at least one workflow subdirectory with workflow.json.

.EXAMPLE
    ./deploy-workflow.ps1
    Deploys workflows using default path and environment variables from azd.

.EXAMPLE
    ./deploy-workflow.ps1 -WorkflowPath "C:\MyWorkflows\LogicApp"
    Deploys workflows from a custom path.

.EXAMPLE
    $env:AZURE_SUBSCRIPTION_ID = "00000000-0000-0000-0000-000000000000"
    $env:AZURE_RESOURCE_GROUP = "my-rg"
    $env:LOGIC_APP_NAME = "my-logic-app"
    ./deploy-workflow.ps1
    Deploys workflows with manually set environment variables.

.INPUTS
    None. This script does not accept pipeline input.

.OUTPUTS
    None. This script outputs status messages to the console.

.NOTES
    Version: 2.0.1
    Requires: Azure CLI 2.50+, PowerShell Core 7.0+
    
    Required Environment Variables:
    - AZURE_SUBSCRIPTION_ID: The Azure subscription ID
    - AZURE_RESOURCE_GROUP: The resource group containing the Logic App
    - LOGIC_APP_NAME: The name of the Logic App Standard resource

    Optional Environment Variables:
    - AZURE_LOCATION: Azure region (defaults to 'westus3')
    - SERVICE_BUS_CONNECTION_RUNTIME_URL: Runtime URL for Service Bus connection
    - AZURE_BLOB_CONNECTION_RUNTIME_URL: Runtime URL for Azure Blob connection

.LINK
    https://learn.microsoft.com/azure/logic-apps/

.LINK
    https://learn.microsoft.com/azure/developer/azure-developer-cli/
#>

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [AllowEmptyString()]
    [string]$WorkflowPath
)

# Enable strict mode for robust error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Store original preferences to restore in finally block
$script:OriginalErrorActionPreference = $ErrorActionPreference
$script:OriginalProgressPreference = $ProgressPreference

# Placeholder pattern for ${VARIABLE} substitution
$PlaceholderPattern = '\$\{([A-Z_][A-Z0-9_]*)\}'

# Files to exclude from deployment (per .funcignore)
$ExcludePatterns = @('.debug', '.git*', '.vscode', '__azurite*', '__blobstorage__', '__queuestorage__', 'local.settings.json', 'test', 'workflow-designtime')

#region Helper Functions

function Write-Log {
    [CmdletBinding()]
    [OutputType([void])]
    param([string]$Message, [ValidateSet('Info', 'Success', 'Warning', 'Error')][string]$Level = 'Info')
    $prefix = @{ Info = '[i]'; Success = '[✓]'; Warning = '[!]'; Error = '[✗]' }[$Level]
    $color = @{ Info = 'Cyan'; Success = 'Green'; Warning = 'Yellow'; Error = 'Red' }[$Level]
    Write-Host "$(Get-Date -Format 'HH:mm:ss') $prefix $Message" -ForegroundColor $color
}

function Get-EnvironmentValue {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        
        [Parameter()]
        [string]$Default = ''
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrEmpty($value)) {
        return $value
    }
    return $Default
}

function Set-WorkflowEnvironmentAliases {
    [CmdletBinding()]
    [OutputType([void])]
    param()
    
    # Map WORKFLOWS_* variables to AZURE_* equivalents for connections.json compatibility
    $mappings = @{
        'WORKFLOWS_SUBSCRIPTION_ID'     = 'AZURE_SUBSCRIPTION_ID'
        'WORKFLOWS_RESOURCE_GROUP_NAME' = 'AZURE_RESOURCE_GROUP'
        'WORKFLOWS_LOCATION_NAME'       = 'AZURE_LOCATION'
    }
    
    foreach ($key in $mappings.Keys) {
        $existingValue = [Environment]::GetEnvironmentVariable($key)
        if ([string]::IsNullOrEmpty($existingValue)) {
            $sourceValue = [Environment]::GetEnvironmentVariable($mappings[$key])
            if (-not [string]::IsNullOrEmpty($sourceValue)) {
                [Environment]::SetEnvironmentVariable($key, $sourceValue)
            }
        }
    }
}

function Resolve-Placeholders {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content,
        
        [Parameter(Mandatory)]
        [string]$FileName
    )
    
    $resolved = $Content
    $unresolved = [System.Collections.Generic.List[string]]::new()
    
    [regex]::Matches($Content, $PlaceholderPattern) | ForEach-Object {
        $key = $_.Groups[1].Value
        $value = [Environment]::GetEnvironmentVariable($key)
        if (-not [string]::IsNullOrEmpty($value)) {
            $resolved = $resolved.Replace($_.Value, $value)
        }
        else {
            $unresolved.Add($key)
        }
    }
    
    if ($unresolved.Count -gt 0) {
        Write-Log -Message "Unresolved in ${FileName}: $($unresolved -join ', ')" -Level Warning
    }
    return $resolved
}

function Get-ConnectionRuntimeUrl {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ConnectionName,
        
        [Parameter(Mandatory)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory)]
        [string]$SubscriptionId
    )
    
    try {
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/$ConnectionName/listConnectionKeys?api-version=2016-06-01"
        # Disable ANSI colors to prevent JSON parsing errors in CI environments
        $env:AZURE_CORE_NO_COLOR = "true"
        $env:NO_COLOR = "1"
        $jsonOutput = az rest --method POST --uri $uri --output json --only-show-errors 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Failed to get runtime URL for connection '$ConnectionName': $jsonOutput"
            return $null
        }
        
        $result = $jsonOutput | ConvertFrom-Json
        if ($null -ne $result.runtimeUrls -and $result.runtimeUrls.Count -gt 0) {
            return $result.runtimeUrls[0]
        }
    }
    catch {
        Write-Verbose "Exception getting runtime URL for connection '$ConnectionName': $($_.Exception.Message)"
    }
    return $null
}

#endregion

#region Main

try {

    # Disable ANSI colors globally to prevent JSON parsing errors in CI environments
    $env:AZURE_CORE_NO_COLOR = "true"
    $env:NO_COLOR = "1"

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║     Logic Apps Standard Workflow Deployment            ║" -ForegroundColor Cyan
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Cyan

    # Set up environment variable aliases for connections.json compatibility
    Set-WorkflowEnvironmentAliases

    # Load required configuration from environment
    $config = @{
        SubscriptionId       = Get-EnvironmentValue 'AZURE_SUBSCRIPTION_ID'
        ResourceGroup        = Get-EnvironmentValue 'AZURE_RESOURCE_GROUP'
        LogicAppName         = Get-EnvironmentValue 'LOGIC_APP_NAME'
        Location             = Get-EnvironmentValue 'AZURE_LOCATION' 'westus3'
        ServiceBusRuntimeUrl = Get-EnvironmentValue 'SERVICE_BUS_CONNECTION_RUNTIME_URL'
        BlobRuntimeUrl       = Get-EnvironmentValue 'AZURE_BLOB_CONNECTION_RUNTIME_URL'
    }

    # Validate required values
    $missing = @()
    if (-not $config.SubscriptionId) { $missing += 'AZURE_SUBSCRIPTION_ID' }
    if (-not $config.ResourceGroup) { $missing += 'AZURE_RESOURCE_GROUP' }
    if (-not $config.LogicAppName) { $missing += 'LOGIC_APP_NAME' }

    if ($missing.Count -gt 0) {
        Write-Log -Message "Missing environment variables: $($missing -join ', ')" -Level Error
        exit 1
    }

    Write-Log -Message "Target: $($config.LogicAppName) in $($config.ResourceGroup)"

    # Find workflow project
    $projectPath = if ($WorkflowPath -and (Test-Path $WorkflowPath)) {
        $WorkflowPath
    }
    else {
        $searchPath = Join-Path $PSScriptRoot '..\workflows\OrdersManagement\OrdersManagementLogicApp'
        if (Test-Path $searchPath) { (Resolve-Path $searchPath).Path }
        else { throw 'Workflow project not found' }
    }
    Write-Log -Message "Source: $projectPath"

    # Discover workflows
    $workflows = Get-ChildItem -Path $projectPath -Directory | Where-Object {
        $dirName = $_.Name
        (Test-Path (Join-Path $_.FullName 'workflow.json')) -and
        (-not ($ExcludePatterns | Where-Object { $dirName -like $_ }))
    }

    if ($workflows.Count -eq 0) { throw 'No workflows found' }
    Write-Log -Message "Workflows: $($workflows.Name -join ', ')" -Level Success

    # Get connection runtime URLs if not in environment
    if ([string]::IsNullOrEmpty($config.ServiceBusRuntimeUrl)) {
        Write-Log -Message 'Fetching Service Bus connection runtime URL...'
        $config.ServiceBusRuntimeUrl = Get-ConnectionRuntimeUrl -ConnectionName 'servicebus' -ResourceGroup $config.ResourceGroup -SubscriptionId $config.SubscriptionId
    }
    if ([string]::IsNullOrEmpty($config.BlobRuntimeUrl)) {
        Write-Log -Message 'Fetching Azure Blob connection runtime URL...'
        $config.BlobRuntimeUrl = Get-ConnectionRuntimeUrl -ConnectionName 'azureblob' -ResourceGroup $config.ResourceGroup -SubscriptionId $config.SubscriptionId
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
        Write-Log -Message "Package: $([math]::Round((Get-Item $zipPath).Length / 1KB, 1)) KB" -Level Success

        # Update app settings with connection runtime URLs
        Write-Log -Message 'Updating application settings...'
        $settings = @()
        if ($config.ServiceBusRuntimeUrl) { $settings += "servicebus-ConnectionRuntimeUrl=$($config.ServiceBusRuntimeUrl)" }
        if ($config.BlobRuntimeUrl) { $settings += "azureblob-ConnectionRuntimeUrl=$($config.BlobRuntimeUrl)" }
    
        if ($settings.Count -gt 0) {
            $settingsArgs = @(
                'functionapp', 'config', 'appsettings', 'set'
                '--name', $config.LogicAppName
                '--resource-group', $config.ResourceGroup
                '--subscription', $config.SubscriptionId
                '--settings'
            ) + $settings + @('--output', 'none')
        
            $null = az @settingsArgs 2>&1
        
            if ($LASTEXITCODE -ne 0) {
                Write-Log -Message 'Failed to update application settings' -Level Warning
            }
        }

        # Deploy
        Write-Log -Message 'Deploying workflows...'
        $startTime = Get-Date
    
        $deployArgs = @(
            'functionapp', 'deployment', 'source', 'config-zip'
            '--name', $config.LogicAppName
            '--resource-group', $config.ResourceGroup
            '--subscription', $config.SubscriptionId
            '--src', $zipPath
            '--output', 'none'
        )
    
        az @deployArgs
    
        if ($LASTEXITCODE -ne 0) {
            throw 'Deployment failed with exit code: {0}' -f $LASTEXITCODE
        }

        $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
        Write-Log -Message "Deployed in $duration seconds" -Level Success

        # Cleanup
        Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    }
    finally {
        Remove-Item $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`n╔════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║              Deployment Complete                       ║" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════╝`n" -ForegroundColor Green
}
catch {
    Write-Log -Message "Deployment failed: $($_.Exception.Message)" -Level Error
    Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
    exit 1
}
finally {
    # Restore original preferences
    $ErrorActionPreference = $script:OriginalErrorActionPreference
    $ProgressPreference = $script:OriginalProgressPreference
}

#endregion
