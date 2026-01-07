#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys Logic Apps Standard workflows to Azure using Azure CLI and zip deployment.

.DESCRIPTION
    This script deploys all workflow definitions from the OrdersManagement Logic App
    workspace to an Azure Logic Apps Standard instance. It performs the following:
    
    1. Validates required environment variables and Azure CLI authentication
    2. Discovers workflow folders in the Logic App project
    3. Creates a deployment package with all workflow artifacts
    4. Configures API connections and runtime settings
    5. Deploys the package using Azure CLI zip deployment
    6. Validates the deployment by checking workflow status

.PARAMETER ResourceGroupName
    The Azure resource group name containing the Logic App.
    Defaults to the AZURE_RESOURCE_GROUP environment variable.

.PARAMETER LogicAppName
    The name of the Logic Apps Standard instance.
    Defaults to the LOGIC_APP_NAME environment variable.

.PARAMETER SubscriptionId
    The Azure subscription ID.
    Defaults to the AZURE_SUBSCRIPTION_ID environment variable.

.PARAMETER WorkflowPath
    Path to the workflow project directory.
    Defaults to the workflows/OrdersManagement/OrdersManagementLogicApp folder.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER Verbose
    Enable verbose logging.

.EXAMPLE
    ./deploy-workflow.ps1
    Deploys workflows using environment variables for configuration.

.EXAMPLE
    ./deploy-workflow.ps1 -ResourceGroupName "rg-myapp" -LogicAppName "my-logicapp" -Force
    Deploys workflows to a specific Logic App with no confirmation prompts.

.NOTES
    Author: Azure Logic Apps Monitoring Solution
    Version: 1.0.0
    Requires: Azure CLI 2.50+, PowerShell Core 7.0+
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = $env:AZURE_RESOURCE_GROUP,

    [Parameter(Mandatory = $false)]
    [string]$LogicAppName = $env:LOGIC_APP_NAME,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId = $env:AZURE_SUBSCRIPTION_ID,

    [Parameter(Mandatory = $false)]
    [string]$WorkflowPath,

    [Parameter(Mandatory = $false)]
    [string]$Location = $env:AZURE_LOCATION,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [switch]$SkipValidation
)

#region Script Configuration
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Script metadata
$script:ScriptVersion = '1.0.0'
$script:ScriptName = 'deploy-workflow.ps1'

# Color definitions for console output
$script:Colors = @{
    Success = 'Green'
    Warning = 'Yellow'
    Error   = 'Red'
    Info    = 'Cyan'
    Debug   = 'Gray'
}
#endregion

#region Helper Functions

function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes a formatted log message to the console.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Success', 'Warning', 'Error', 'Info', 'Debug')]
        [string]$Level = 'Info',

        [Parameter(Mandatory = $false)]
        [switch]$NoNewLine
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $prefix = switch ($Level) {
        'Success' { '[✓]' }
        'Warning' { '[!]' }
        'Error' { '[✗]' }
        'Info' { '[i]' }
        'Debug' { '[D]' }
    }

    $color = $script:Colors[$Level]
    $formattedMessage = "$timestamp $prefix $Message"

    if ($NoNewLine) {
        Write-Host $formattedMessage -ForegroundColor $color -NoNewline
    }
    else {
        Write-Host $formattedMessage -ForegroundColor $color
    }
}

function Test-AzureCLI {
    <#
    .SYNOPSIS
        Validates Azure CLI installation and authentication.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-LogMessage -Message 'Validating Azure CLI installation...' -Level Info

    # Check if Azure CLI is installed
    $azCmd = Get-Command 'az' -ErrorAction SilentlyContinue
    if (-not $azCmd) {
        Write-LogMessage -Message 'Azure CLI is not installed. Please install it from https://aka.ms/installazurecli' -Level Error
        return $false
    }

    # Get Azure CLI version
    $azVersion = az version --output json 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Write-LogMessage -Message 'Failed to get Azure CLI version' -Level Error
        return $false
    }
    Write-LogMessage -Message "Azure CLI version: $($azVersion.'azure-cli')" -Level Debug

    # Check authentication status
    Write-LogMessage -Message 'Checking Azure authentication...' -Level Info
    $account = az account show --output json 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        Write-LogMessage -Message 'Not logged in to Azure. Please run "az login" first.' -Level Error
        return $false
    }

    Write-LogMessage -Message "Authenticated as: $($account.user.name)" -Level Success
    Write-LogMessage -Message "Subscription: $($account.name) ($($account.id))" -Level Info

    return $true
}

function Get-WorkflowProjectPath {
    <#
    .SYNOPSIS
        Determines the workflow project path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ProvidedPath
    )

    if ($ProvidedPath -and (Test-Path -Path $ProvidedPath)) {
        return (Resolve-Path -Path $ProvidedPath).Path
    }

    # Default paths to search
    $searchPaths = @(
        (Join-Path -Path $PSScriptRoot -ChildPath '..\workflows\OrdersManagement\OrdersManagementLogicApp'),
        (Join-Path -Path $PSScriptRoot -ChildPath 'workflows\OrdersManagement\OrdersManagementLogicApp'),
        '.\workflows\OrdersManagement\OrdersManagementLogicApp',
        '..\workflows\OrdersManagement\OrdersManagementLogicApp'
    )

    foreach ($path in $searchPaths) {
        $resolvedPath = $null
        try {
            if (Test-Path -Path $path) {
                $resolvedPath = (Resolve-Path -Path $path).Path
                Write-LogMessage -Message "Found workflow project at: $resolvedPath" -Level Debug
                return $resolvedPath
            }
        }
        catch {
            continue
        }
    }

    throw 'Could not find the workflow project directory. Please specify the -WorkflowPath parameter.'
}

function Get-WorkflowFolders {
    <#
    .SYNOPSIS
        Discovers workflow folders in the project directory.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    Write-LogMessage -Message "Discovering workflows in: $ProjectPath" -Level Info

    $workflows = @()
    $directories = Get-ChildItem -Path $ProjectPath -Directory -ErrorAction SilentlyContinue

    foreach ($dir in $directories) {
        $workflowFile = Join-Path -Path $dir.FullName -ChildPath 'workflow.json'
        if (Test-Path -Path $workflowFile) {
            $workflows += $dir
            Write-LogMessage -Message "  Found workflow: $($dir.Name)" -Level Debug
        }
    }

    if ($workflows.Count -eq 0) {
        throw "No workflow folders found in $ProjectPath. Each workflow must have a workflow.json file."
    }

    Write-LogMessage -Message "Discovered $($workflows.Count) workflow(s)" -Level Success
    return $workflows
}

function Get-LogicAppSettings {
    <#
    .SYNOPSIS
        Retrieves the current Logic App configuration from Azure.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Subscription
    )

    Write-LogMessage -Message "Retrieving Logic App settings for: $Name" -Level Info

    $azArgs = @('functionapp', 'show', '--name', $Name, '--resource-group', $ResourceGroup, '--output', 'json')
    if ($Subscription) {
        $azArgs += @('--subscription', $Subscription)
    }

    $result = az @azArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to retrieve Logic App settings: $result"
    }

    return $result | ConvertFrom-Json
}

function Get-ConnectionRuntimeUrls {
    <#
    .SYNOPSIS
        Retrieves the API connection runtime URLs from Azure.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $false)]
        [string]$Subscription
    )

    Write-LogMessage -Message 'Retrieving API connection runtime URLs...' -Level Info

    $connections = @{
        ServiceBusConnectionRuntimeUrl = ''
        AzureBlobConnectionRuntimeUrl  = ''
    }

    # Get Service Bus connection
    try {
        $sbResult = az resource show `
            --resource-group $ResourceGroup `
            --name 'servicebus' `
            --resource-type 'Microsoft.Web/connections' `
            --output json 2>$null | ConvertFrom-Json

        if ($sbResult) {
            # List connection keys to get runtime URL
            $sbKeys = az rest --method POST `
                --uri "https://management.azure.com$($sbResult.id)/listConnectionKeys?api-version=2016-06-01" `
                --output json 2>$null | ConvertFrom-Json
            
            if ($sbKeys -and $sbKeys.runtimeUrls) {
                $connections.ServiceBusConnectionRuntimeUrl = $sbKeys.runtimeUrls[0]
                Write-LogMessage -Message "  Service Bus connection runtime URL retrieved" -Level Debug
            }
        }
    }
    catch {
        Write-LogMessage -Message "  Warning: Could not retrieve Service Bus connection: $_" -Level Warning
    }

    # Get Azure Blob connection
    try {
        $blobResult = az resource show `
            --resource-group $ResourceGroup `
            --name 'azureblob' `
            --resource-type 'Microsoft.Web/connections' `
            --output json 2>$null | ConvertFrom-Json

        if ($blobResult) {
            $blobKeys = az rest --method POST `
                --uri "https://management.azure.com$($blobResult.id)/listConnectionKeys?api-version=2016-06-01" `
                --output json 2>$null | ConvertFrom-Json
            
            if ($blobKeys -and $blobKeys.runtimeUrls) {
                $connections.AzureBlobConnectionRuntimeUrl = $blobKeys.runtimeUrls[0]
                Write-LogMessage -Message "  Azure Blob connection runtime URL retrieved" -Level Debug
            }
        }
    }
    catch {
        Write-LogMessage -Message "  Warning: Could not retrieve Azure Blob connection: $_" -Level Warning
    }

    return $connections
}

function Update-ConnectionsJson {
    <#
    .SYNOPSIS
        Updates the connections.json file with Azure-specific configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$Location,

        [Parameter(Mandatory = $false)]
        [string]$ManagedIdentityName
    )

    Write-LogMessage -Message 'Updating connections.json for deployment...' -Level Info

    if (-not (Test-Path -Path $FilePath)) {
        Write-LogMessage -Message "connections.json not found at: $FilePath" -Level Warning
        return
    }

    $content = Get-Content -Path $FilePath -Raw
    
    # Replace placeholders with actual values
    $content = $content -replace '\$\{WORKFLOWS_SUBSCRIPTION_ID\}', $SubscriptionId
    $content = $content -replace '\$\{AZURE_SUBSCRIPTION_ID\}', $SubscriptionId
    $content = $content -replace '\$\{WORKFLOWS_RESOURCE_GROUP_NAME\}', $ResourceGroup
    $content = $content -replace '\$\{AZURE_RESOURCE_GROUP\}', $ResourceGroup
    $content = $content -replace '\$\{WORKFLOWS_LOCATION_NAME\}', $Location
    $content = $content -replace '\$\{AZURE_LOCATION\}', $Location

    if ($ManagedIdentityName) {
        $content = $content -replace '\$\{MANAGED_IDENTITY_NAME\}', $ManagedIdentityName
    }

    # Replace appsetting references for runtime URLs with actual environment variable syntax
    $content = $content -replace "@appsetting\('WORKFLOWS_SUBSCRIPTION_ID'\)", $SubscriptionId
    $content = $content -replace "@appsetting\('WORKFLOWS_LOCATION_NAME'\)", $Location
    $content = $content -replace "@appsetting\('WORKFLOWS_RESOURCE_GROUP_NAME'\)", $ResourceGroup

    return $content
}

function Update-ParametersJson {
    <#
    .SYNOPSIS
        Updates the parameters.json file with Azure-specific configuration.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $false)]
        [string]$ManagedIdentityName,

        [Parameter(Mandatory = $false)]
        [string]$StorageAccountName,

        [Parameter(Mandatory = $false)]
        [string]$OrdersApiUrl
    )

    Write-LogMessage -Message 'Updating parameters.json for deployment...' -Level Info

    if (-not (Test-Path -Path $FilePath)) {
        Write-LogMessage -Message "parameters.json not found at: $FilePath" -Level Warning
        return
    }

    $content = Get-Content -Path $FilePath -Raw

    # Replace placeholders with actual values
    $content = $content -replace '\$\{AZURE_SUBSCRIPTION_ID\}', $SubscriptionId
    $content = $content -replace '\$\{AZURE_RESOURCE_GROUP\}', $ResourceGroup

    if ($ManagedIdentityName) {
        $content = $content -replace '\$\{MANAGED_IDENTITY_NAME\}', $ManagedIdentityName
    }

    if ($StorageAccountName) {
        $content = $content -replace '\$\{AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW\}', $StorageAccountName
    }

    if ($OrdersApiUrl) {
        $content = $content -replace '\$\{ORDERS_API_URL\}', $OrdersApiUrl
    }

    return $content
}

function New-DeploymentPackage {
    <#
    .SYNOPSIS
        Creates a zip deployment package for the Logic App workflows.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$Location,

        [Parameter(Mandatory = $false)]
        [hashtable]$AppSettings = @{}
    )

    Write-LogMessage -Message 'Creating deployment package...' -Level Info

    # Create temp directory for staging
    $stagingDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "logicapp-deploy-$(New-Guid)"
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

    try {
        # Copy required files to staging directory
        $filesToCopy = @(
            'host.json',
            'connections.json',
            'parameters.json'
        )

        foreach ($file in $filesToCopy) {
            $sourcefile = Join-Path -Path $SourcePath -ChildPath $file
            if (Test-Path -Path $sourcefile) {
                Copy-Item -Path $sourcefile -Destination $stagingDir -Force
            }
        }

        # Copy workflow folders
        $workflows = Get-WorkflowFolders -ProjectPath $SourcePath
        foreach ($workflow in $workflows) {
            $destPath = Join-Path -Path $stagingDir -ChildPath $workflow.Name
            Copy-Item -Path $workflow.FullName -Destination $destPath -Recurse -Force
            Write-LogMessage -Message "  Copied workflow: $($workflow.Name)" -Level Debug
        }

        # Update connections.json with deployment values
        $connectionsPath = Join-Path -Path $stagingDir -ChildPath 'connections.json'
        if (Test-Path -Path $connectionsPath) {
            $updatedConnections = Update-ConnectionsJson `
                -FilePath $connectionsPath `
                -SubscriptionId $SubscriptionId `
                -ResourceGroup $ResourceGroup `
                -Location $Location `
                -ManagedIdentityName $AppSettings['MANAGED_IDENTITY_NAME']
            
            if ($updatedConnections) {
                Set-Content -Path $connectionsPath -Value $updatedConnections -Force
            }
        }

        # Update parameters.json with deployment values
        $parametersPath = Join-Path -Path $stagingDir -ChildPath 'parameters.json'
        if (Test-Path -Path $parametersPath) {
            $updatedParameters = Update-ParametersJson `
                -FilePath $parametersPath `
                -SubscriptionId $SubscriptionId `
                -ResourceGroup $ResourceGroup `
                -ManagedIdentityName $AppSettings['MANAGED_IDENTITY_NAME'] `
                -StorageAccountName $AppSettings['AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW'] `
                -OrdersApiUrl $AppSettings['ORDERS_API_URL']
            
            if ($updatedParameters) {
                Set-Content -Path $parametersPath -Value $updatedParameters -Force
            }
        }

        # Update workflow.json files to replace placeholders
        foreach ($workflow in $workflows) {
            $workflowJsonPath = Join-Path -Path $stagingDir -ChildPath $workflow.Name -AdditionalChildPath 'workflow.json'
            if (Test-Path -Path $workflowJsonPath) {
                $workflowContent = Get-Content -Path $workflowJsonPath -Raw
                
                # Replace storage account placeholder
                if ($AppSettings['AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW']) {
                    $workflowContent = $workflowContent -replace '\$\{AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW\}', $AppSettings['AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW']
                }
                
                # Replace Orders API URL placeholder
                if ($AppSettings['ORDERS_API_URL']) {
                    $workflowContent = $workflowContent -replace '\$\{ORDERS_API_URL\}', $AppSettings['ORDERS_API_URL']
                }

                Set-Content -Path $workflowJsonPath -Value $workflowContent -Force
            }
        }

        # Create zip package
        $zipPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "logicapp-deploy-$(Get-Date -Format 'yyyyMMddHHmmss').zip"
        
        Write-LogMessage -Message "Creating zip archive at: $zipPath" -Level Debug
        Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -Force

        $zipSize = (Get-Item -Path $zipPath).Length / 1KB
        Write-LogMessage -Message "Deployment package created: $([math]::Round($zipSize, 2)) KB" -Level Success

        return $zipPath
    }
    finally {
        # Cleanup staging directory
        if (Test-Path -Path $stagingDir) {
            Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function Deploy-LogicAppWorkflows {
    <#
    .SYNOPSIS
        Deploys the workflow package to Azure Logic Apps Standard.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$LogicAppName,

        [Parameter(Mandatory = $false)]
        [string]$Subscription
    )

    Write-LogMessage -Message "Deploying workflows to Logic App: $LogicAppName" -Level Info

    # Build the deployment command
    $azArgs = @(
        'functionapp', 'deployment', 'source', 'config-zip',
        '--name', $LogicAppName,
        '--resource-group', $ResourceGroup,
        '--src', $ZipPath,
        '--output', 'json'
    )

    if ($Subscription) {
        $azArgs += @('--subscription', $Subscription)
    }

    Write-LogMessage -Message 'Starting zip deployment...' -Level Info
    $startTime = Get-Date

    $result = az @azArgs 2>&1
    $exitCode = $LASTEXITCODE

    $duration = (Get-Date) - $startTime

    if ($exitCode -ne 0) {
        Write-LogMessage -Message "Deployment failed after $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level Error
        Write-LogMessage -Message "Error details: $result" -Level Error
        throw "Deployment failed: $result"
    }

    Write-LogMessage -Message "Deployment completed successfully in $([math]::Round($duration.TotalSeconds, 2)) seconds" -Level Success
    return $result | ConvertFrom-Json
}

function Update-LogicAppSettings {
    <#
    .SYNOPSIS
        Updates Logic App application settings with connection runtime URLs.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$LogicAppName,

        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $false)]
        [string]$Subscription
    )

    Write-LogMessage -Message 'Updating Logic App application settings...' -Level Info

    # Build settings string
    $settingsArray = @()
    foreach ($key in $Settings.Keys) {
        if ($Settings[$key]) {
            $settingsArray += "$key=$($Settings[$key])"
        }
    }

    if ($settingsArray.Count -eq 0) {
        Write-LogMessage -Message 'No settings to update' -Level Warning
        return
    }

    $azArgs = @(
        'functionapp', 'config', 'appsettings', 'set',
        '--name', $LogicAppName,
        '--resource-group', $ResourceGroup,
        '--settings'
    ) + $settingsArray + @('--output', 'json')

    if ($Subscription) {
        $azArgs += @('--subscription', $Subscription)
    }

    $result = az @azArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-LogMessage -Message "Warning: Failed to update some settings: $result" -Level Warning
    }
    else {
        Write-LogMessage -Message "Updated $($settingsArray.Count) application setting(s)" -Level Success
    }
}

function Test-WorkflowDeployment {
    <#
    .SYNOPSIS
        Validates that workflows were deployed successfully.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$LogicAppName,

        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedWorkflows,

        [Parameter(Mandatory = $false)]
        [string]$Subscription
    )

    Write-LogMessage -Message 'Validating workflow deployment...' -Level Info

    # Give Azure a moment to process the deployment
    Start-Sleep -Seconds 5

    # List workflows using Azure REST API
    $logicAppId = "/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$LogicAppName"
    
    try {
        $workflows = az rest --method GET `
            --uri "https://management.azure.com$logicAppId/workflows?api-version=2018-11-01" `
            --output json 2>$null | ConvertFrom-Json

        if ($workflows -and $workflows.value) {
            $deployedWorkflows = $workflows.value | ForEach-Object { $_.name }
            Write-LogMessage -Message "Deployed workflows: $($deployedWorkflows -join ', ')" -Level Info

            $allFound = $true
            foreach ($expected in $ExpectedWorkflows) {
                if ($deployedWorkflows -contains $expected) {
                    Write-LogMessage -Message "  ✓ $expected" -Level Success
                }
                else {
                    Write-LogMessage -Message "  ✗ $expected (not found)" -Level Warning
                    $allFound = $false
                }
            }

            return $allFound
        }
    }
    catch {
        Write-LogMessage -Message "Could not validate workflows: $_" -Level Warning
    }

    return $false
}

function Get-AzdEnvironmentValues {
    <#
    .SYNOPSIS
        Retrieves environment values from azd environment.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    Write-LogMessage -Message 'Retrieving azd environment values...' -Level Info

    $values = @{}

    try {
        # Check if azd is available
        $azdCmd = Get-Command 'azd' -ErrorAction SilentlyContinue
        if (-not $azdCmd) {
            Write-LogMessage -Message 'Azure Developer CLI (azd) not found, using environment variables' -Level Warning
            return $values
        }

        # Get all environment values
        $envOutput = azd env get-values 2>$null
        if ($LASTEXITCODE -eq 0 -and $envOutput) {
            foreach ($line in $envOutput -split "`n") {
                if ($line -match '^([A-Z_]+)="?([^"]*)"?$') {
                    $values[$matches[1]] = $matches[2]
                }
            }
            Write-LogMessage -Message "Retrieved $($values.Count) environment value(s) from azd" -Level Debug
        }
    }
    catch {
        Write-LogMessage -Message "Could not retrieve azd environment values: $_" -Level Warning
    }

    return $values
}

#endregion

#region Main Execution

function Invoke-WorkflowDeployment {
    <#
    .SYNOPSIS
        Main function that orchestrates the workflow deployment process.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║          Logic Apps Standard Workflow Deployment Script              ║' -ForegroundColor Cyan
    Write-Host '║                         Version 1.0.0                                ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''

    try {
        # Step 1: Validate prerequisites
        Write-LogMessage -Message 'Step 1/7: Validating prerequisites...' -Level Info
        
        if (-not $SkipValidation) {
            if (-not (Test-AzureCLI)) {
                throw 'Azure CLI validation failed'
            }
        }

        # Step 2: Get azd environment values (if available)
        Write-LogMessage -Message 'Step 2/7: Loading configuration...' -Level Info
        $azdValues = Get-AzdEnvironmentValues

        # Resolve parameters with fallback to azd values and environment variables
        $resolvedSubscriptionId = $SubscriptionId
        if (-not $resolvedSubscriptionId) { $resolvedSubscriptionId = $azdValues['AZURE_SUBSCRIPTION_ID'] }
        if (-not $resolvedSubscriptionId) { $resolvedSubscriptionId = $env:AZURE_SUBSCRIPTION_ID }

        $resolvedResourceGroup = $ResourceGroupName
        if (-not $resolvedResourceGroup) { $resolvedResourceGroup = $azdValues['AZURE_RESOURCE_GROUP'] }
        if (-not $resolvedResourceGroup) { $resolvedResourceGroup = $env:AZURE_RESOURCE_GROUP }

        $resolvedLogicAppName = $LogicAppName
        if (-not $resolvedLogicAppName) { $resolvedLogicAppName = $azdValues['LOGIC_APP_NAME'] }
        if (-not $resolvedLogicAppName) { $resolvedLogicAppName = $env:LOGIC_APP_NAME }

        $resolvedLocation = $Location
        if (-not $resolvedLocation) { $resolvedLocation = $azdValues['AZURE_LOCATION'] }
        if (-not $resolvedLocation) { $resolvedLocation = $env:AZURE_LOCATION }
        if (-not $resolvedLocation) { $resolvedLocation = 'westus3' }

        # Get additional settings from azd or environment
        $appSettings = @{
            'MANAGED_IDENTITY_NAME'             = $azdValues['MANAGED_IDENTITY_NAME'] ?? $env:MANAGED_IDENTITY_NAME
            'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW' = $azdValues['AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW'] ?? $env:AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW
            'ORDERS_API_URL'                    = $azdValues['ORDERS_API_URL'] ?? $env:ORDERS_API_URL
            'SERVICE_BUS_CONNECTION_RUNTIME_URL'  = $azdValues['SERVICE_BUS_CONNECTION_RUNTIME_URL'] ?? $env:SERVICE_BUS_CONNECTION_RUNTIME_URL
            'AZURE_BLOB_CONNECTION_RUNTIME_URL'   = $azdValues['AZURE_BLOB_CONNECTION_RUNTIME_URL'] ?? $env:AZURE_BLOB_CONNECTION_RUNTIME_URL
        }

        # Validate required parameters
        $missingParams = @()
        if (-not $resolvedSubscriptionId) { $missingParams += 'SubscriptionId (AZURE_SUBSCRIPTION_ID)' }
        if (-not $resolvedResourceGroup) { $missingParams += 'ResourceGroupName (AZURE_RESOURCE_GROUP)' }
        if (-not $resolvedLogicAppName) { $missingParams += 'LogicAppName (LOGIC_APP_NAME)' }

        if ($missingParams.Count -gt 0) {
            throw "Missing required parameters: $($missingParams -join ', '). Please set these as environment variables or pass them as parameters."
        }

        Write-LogMessage -Message "Configuration loaded:" -Level Info
        Write-LogMessage -Message "  Subscription: $resolvedSubscriptionId" -Level Debug
        Write-LogMessage -Message "  Resource Group: $resolvedResourceGroup" -Level Debug
        Write-LogMessage -Message "  Logic App: $resolvedLogicAppName" -Level Debug
        Write-LogMessage -Message "  Location: $resolvedLocation" -Level Debug

        # Step 3: Discover workflow project
        Write-LogMessage -Message 'Step 3/7: Discovering workflow project...' -Level Info
        $projectPath = Get-WorkflowProjectPath -ProvidedPath $WorkflowPath
        Write-LogMessage -Message "Workflow project: $projectPath" -Level Success

        # Step 4: Discover workflows
        Write-LogMessage -Message 'Step 4/7: Discovering workflows...' -Level Info
        $workflows = Get-WorkflowFolders -ProjectPath $projectPath
        $workflowNames = $workflows | ForEach-Object { $_.Name }

        # Step 5: Get connection runtime URLs (if not provided)
        Write-LogMessage -Message 'Step 5/7: Retrieving API connection details...' -Level Info
        if (-not $appSettings['SERVICE_BUS_CONNECTION_RUNTIME_URL'] -or -not $appSettings['AZURE_BLOB_CONNECTION_RUNTIME_URL']) {
            $connectionUrls = Get-ConnectionRuntimeUrls -ResourceGroup $resolvedResourceGroup -Subscription $resolvedSubscriptionId
            
            if (-not $appSettings['SERVICE_BUS_CONNECTION_RUNTIME_URL'] -and $connectionUrls.ServiceBusConnectionRuntimeUrl) {
                $appSettings['SERVICE_BUS_CONNECTION_RUNTIME_URL'] = $connectionUrls.ServiceBusConnectionRuntimeUrl
            }
            if (-not $appSettings['AZURE_BLOB_CONNECTION_RUNTIME_URL'] -and $connectionUrls.AzureBlobConnectionRuntimeUrl) {
                $appSettings['AZURE_BLOB_CONNECTION_RUNTIME_URL'] = $connectionUrls.AzureBlobConnectionRuntimeUrl
            }
        }

        # Step 6: Create deployment package
        Write-LogMessage -Message 'Step 6/7: Creating deployment package...' -Level Info
        $zipPath = New-DeploymentPackage `
            -SourcePath $projectPath `
            -SubscriptionId $resolvedSubscriptionId `
            -ResourceGroup $resolvedResourceGroup `
            -Location $resolvedLocation `
            -AppSettings $appSettings

        # Confirm deployment
        if (-not $Force -and -not $PSCmdlet.ShouldProcess($resolvedLogicAppName, 'Deploy workflows')) {
            Write-LogMessage -Message 'Deployment cancelled by user' -Level Warning
            return
        }

        # Step 7: Deploy to Azure
        Write-LogMessage -Message 'Step 7/7: Deploying to Azure...' -Level Info
        
        # Update app settings first
        $settingsToUpdate = @{
            'servicebus-ConnectionRuntimeUrl' = $appSettings['SERVICE_BUS_CONNECTION_RUNTIME_URL']
            'azureblob-ConnectionRuntimeUrl'  = $appSettings['AZURE_BLOB_CONNECTION_RUNTIME_URL']
        }
        Update-LogicAppSettings `
            -ResourceGroup $resolvedResourceGroup `
            -LogicAppName $resolvedLogicAppName `
            -Settings $settingsToUpdate `
            -Subscription $resolvedSubscriptionId

        # Deploy the zip package
        $deployResult = Deploy-LogicAppWorkflows `
            -ZipPath $zipPath `
            -ResourceGroup $resolvedResourceGroup `
            -LogicAppName $resolvedLogicAppName `
            -Subscription $resolvedSubscriptionId

        # Validate deployment
        $validationResult = Test-WorkflowDeployment `
            -ResourceGroup $resolvedResourceGroup `
            -LogicAppName $resolvedLogicAppName `
            -ExpectedWorkflows $workflowNames `
            -Subscription $resolvedSubscriptionId

        # Cleanup
        if (Test-Path -Path $zipPath) {
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        }

        # Summary
        Write-Host ''
        Write-Host '╔══════════════════════════════════════════════════════════════════════╗' -ForegroundColor Green
        Write-Host '║                    Deployment Summary                                ║' -ForegroundColor Green
        Write-Host '╚══════════════════════════════════════════════════════════════════════╝' -ForegroundColor Green
        Write-Host ''
        Write-LogMessage -Message "Logic App: $resolvedLogicAppName" -Level Info
        Write-LogMessage -Message "Resource Group: $resolvedResourceGroup" -Level Info
        Write-LogMessage -Message "Workflows Deployed: $($workflowNames -join ', ')" -Level Info
        Write-LogMessage -Message "Validation: $(if ($validationResult) { 'Passed' } else { 'Check Azure Portal' })" -Level $(if ($validationResult) { 'Success' } else { 'Warning' })
        Write-Host ''

        # Return deployment info
        return [PSCustomObject]@{
            Success       = $true
            LogicAppName  = $resolvedLogicAppName
            ResourceGroup = $resolvedResourceGroup
            Workflows     = $workflowNames
            Validated     = $validationResult
        }
    }
    catch {
        Write-LogMessage -Message "Deployment failed: $_" -Level Error
        Write-LogMessage -Message $_.ScriptStackTrace -Level Debug
        
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.Exception.Message
        }
    }
}

# Execute main deployment
$result = Invoke-WorkflowDeployment

# Exit with appropriate code
if (-not $result.Success) {
    exit 1
}

exit 0

#endregion
