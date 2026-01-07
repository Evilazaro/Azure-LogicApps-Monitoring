#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploys Logic Apps Standard workflows to Azure using Azure CLI zip deployment.

.DESCRIPTION
    This script deploys all workflow definitions from the OrdersManagement Logic App
    workspace to an Azure Logic Apps Standard instance. It leverages the existing
    configuration files (connections.json, parameters.json, host.json) that use
    @appsetting() and @parameters() expressions, along with ${PLACEHOLDER} syntax
    for environment variables provided by Azure Developer CLI (azd).

    The script performs:
    1. Validates Azure CLI authentication and prerequisites
    2. Loads environment values from azd or environment variables
    3. Discovers workflow folders containing workflow.json files
    4. Resolves ${PLACEHOLDER} tokens in configuration files
    5. Creates a deployment package excluding local development files
    6. Updates Logic App application settings with connection runtime URLs
    7. Deploys using Azure CLI zip deployment
    8. Validates workflow deployment status

.PARAMETER ResourceGroupName
    Azure resource group containing the Logic App. Falls back to AZURE_RESOURCE_GROUP env var.

.PARAMETER LogicAppName
    Name of the Logic Apps Standard instance. Falls back to LOGIC_APP_NAME env var.

.PARAMETER SubscriptionId
    Azure subscription ID. Falls back to AZURE_SUBSCRIPTION_ID env var.

.PARAMETER WorkflowPath
    Path to the Logic App project directory. Defaults to workflows/OrdersManagement/OrdersManagementLogicApp.

.PARAMETER Force
    Skip confirmation prompts.

.PARAMETER SkipValidation
    Skip Azure CLI validation checks.

.PARAMETER Verbose
    Enable verbose logging output.

.EXAMPLE
    ./deploy-workflow.ps1
    Deploys workflows using azd environment values.

.EXAMPLE
    ./deploy-workflow.ps1 -Force -Verbose
    Deploys workflows with verbose output and no confirmation prompts.

.NOTES
    Author: Azure Logic Apps Monitoring Solution
    Version: 2.0.0
    Requires: Azure CLI 2.50+, PowerShell Core 7.0+
    
    Configuration Files:
    - connections.json: API connection definitions using @appsetting() and @parameters()
    - parameters.json: Workflow parameters using @appsetting() for runtime values
    - host.json: Logic Apps runtime configuration
    - workflow.json: Individual workflow definitions with ${PLACEHOLDER} tokens
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$LogicAppName,

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $false)]
    [string]$WorkflowPath,

    [Parameter(Mandatory = $false)]
    [string]$Location,

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
$script:ScriptVersion = '2.0.0'
$script:ScriptName = 'deploy-workflow.ps1'

# Files to exclude from deployment (matches .funcignore)
$script:ExcludePatterns = @(
    '.debug',
    '.git*',
    '.vscode',
    '__azurite_db*__.json',
    '__blobstorage__',
    '__queuestorage__',
    'local.settings.json',
    'test',
    'workflow-designtime'
)

# Required deployment files
$script:RequiredFiles = @(
    'host.json',
    'connections.json',
    'parameters.json'
)

# Placeholder pattern for environment variable substitution
$script:PlaceholderPattern = '\$\{([A-Z_][A-Z0-9_]*)\}'
#endregion

#region Logging Functions

function Write-Log {
    <#
    .SYNOPSIS
        Writes a formatted log message with timestamp and level indicator.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Debug')]
        [string]$Level = 'Info'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $colors = @{
        Info    = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error   = 'Red'
        Debug   = 'Gray'
    }
    $prefixes = @{
        Info    = '[i]'
        Success = '[✓]'
        Warning = '[!]'
        Error   = '[✗]'
        Debug   = '[D]'
    }

    # Skip debug messages unless verbose
    if ($Level -eq 'Debug' -and -not $VerbosePreference) {
        return
    }

    Write-Host "$timestamp $($prefixes[$Level]) $Message" -ForegroundColor $colors[$Level]
}

function Write-Banner {
    <#
    .SYNOPSIS
        Displays a formatted banner for script sections.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Color = 'Cyan'
    )

    $width = 74
    $padding = [math]::Max(0, ($width - $Title.Length - 2) / 2)
    $leftPad = ' ' * [math]::Floor($padding)
    $rightPad = ' ' * [math]::Ceiling($padding)

    Write-Host ''
    Write-Host ('╔' + '═' * $width + '╗') -ForegroundColor $Color
    Write-Host ('║' + $leftPad + $Title + $rightPad + '║') -ForegroundColor $Color
    Write-Host ('╚' + '═' * $width + '╝') -ForegroundColor $Color
    Write-Host ''
}

#endregion

#region Validation Functions

function Test-AzureCLI {
    <#
    .SYNOPSIS
        Validates Azure CLI installation and authentication status.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Log 'Validating Azure CLI installation...'

    # Check Azure CLI availability
    $azCmd = Get-Command 'az' -ErrorAction SilentlyContinue
    if (-not $azCmd) {
        Write-Log 'Azure CLI not found. Install from https://aka.ms/installazurecli' -Level Error
        return $false
    }

    # Verify version
    try {
        $versionJson = az version --output json 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Log 'Failed to get Azure CLI version' -Level Error
            return $false
        }
        $version = ($versionJson | ConvertFrom-Json).'azure-cli'
        Write-Log "Azure CLI version: $version" -Level Debug
    }
    catch {
        Write-Log "Azure CLI version check failed: $_" -Level Warning
    }

    # Verify authentication
    Write-Log 'Verifying Azure authentication...'
    $accountJson = az account show --output json 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'Not authenticated. Run "az login" first.' -Level Error
        return $false
    }

    $account = $accountJson | ConvertFrom-Json
    Write-Log "Authenticated: $($account.user.name)" -Level Success
    Write-Log "Subscription: $($account.name) ($($account.id))" -Level Debug

    return $true
}

function Test-LogicAppExists {
    <#
    .SYNOPSIS
        Verifies the Logic App exists in Azure.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $false)]
        [string]$Subscription
    )

    Write-Log "Verifying Logic App exists: $Name"

    $azArgs = @('functionapp', 'show', '--name', $Name, '--resource-group', $ResourceGroup, '--output', 'json')
    if ($Subscription) {
        $azArgs += @('--subscription', $Subscription)
    }

    $result = az @azArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Log "Logic App '$Name' not found in resource group '$ResourceGroup'" -Level Error
        return $false
    }

    $app = $result | ConvertFrom-Json
    Write-Log "Logic App found: $($app.name) (State: $($app.state))" -Level Success
    return $true
}

#endregion

#region Configuration Functions

function Get-AzdEnvironmentValues {
    <#
    .SYNOPSIS
        Retrieves environment values from Azure Developer CLI (azd).
    .DESCRIPTION
        Loads all environment variables from the current azd environment.
        These values are used to resolve ${PLACEHOLDER} tokens in configuration files.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    Write-Log 'Loading azd environment values...'
    $values = @{}

    # Check for azd CLI
    $azdCmd = Get-Command 'azd' -ErrorAction SilentlyContinue
    if (-not $azdCmd) {
        Write-Log 'Azure Developer CLI (azd) not found. Using environment variables only.' -Level Warning
        return $values
    }

    try {
        $envOutput = azd env get-values 2>$null
        if ($LASTEXITCODE -eq 0 -and $envOutput) {
            foreach ($line in $envOutput -split "`n") {
                $line = $line.Trim()
                if ($line -match '^([A-Z_][A-Z0-9_]*)="?([^"]*)"?$') {
                    $key = $matches[1]
                    $value = $matches[2].Trim('"')
                    $values[$key] = $value
                }
            }
            Write-Log "Loaded $($values.Count) values from azd environment" -Level Debug
        }
    }
    catch {
        Write-Log "Could not load azd environment: $_" -Level Warning
    }

    return $values
}

function Resolve-ConfigurationValue {
    <#
    .SYNOPSIS
        Resolves a configuration value from multiple sources.
    .DESCRIPTION
        Checks parameter value, azd values, and environment variables in order.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ParameterValue,

        [Parameter(Mandatory = $true)]
        [string]$AzdKey,

        [Parameter(Mandatory = $true)]
        [hashtable]$AzdValues,

        [Parameter(Mandatory = $false)]
        [string]$EnvironmentVariable,

        [Parameter(Mandatory = $false)]
        [string]$DefaultValue
    )

    # Priority: Parameter > AZD > Environment > Default
    if ($ParameterValue) { return $ParameterValue }
    if ($AzdValues.ContainsKey($AzdKey) -and $AzdValues[$AzdKey]) { return $AzdValues[$AzdKey] }
    if ($EnvironmentVariable) {
        $envValue = [Environment]::GetEnvironmentVariable($EnvironmentVariable)
        if ($envValue) { return $envValue }
    }
    return $DefaultValue
}

function Get-WorkflowProjectPath {
    <#
    .SYNOPSIS
        Locates the Logic App workflow project directory.
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

    # Search paths relative to script location
    $searchPaths = @(
        (Join-Path $PSScriptRoot '..\workflows\OrdersManagement\OrdersManagementLogicApp'),
        (Join-Path $PSScriptRoot 'workflows\OrdersManagement\OrdersManagementLogicApp'),
        '.\workflows\OrdersManagement\OrdersManagementLogicApp'
    )

    foreach ($path in $searchPaths) {
        if (Test-Path -Path $path) {
            $resolved = (Resolve-Path -Path $path).Path
            # Verify it's a Logic App project
            if (Test-Path (Join-Path $resolved 'host.json')) {
                Write-Log "Found workflow project: $resolved" -Level Debug
                return $resolved
            }
        }
    }

    throw 'Workflow project not found. Specify -WorkflowPath parameter.'
}

function Get-WorkflowFolders {
    <#
    .SYNOPSIS
        Discovers workflow folders containing workflow.json files.
    #>
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath
    )

    Write-Log "Discovering workflows in: $ProjectPath"

    $workflows = @()
    Get-ChildItem -Path $ProjectPath -Directory | ForEach-Object {
        $workflowFile = Join-Path $_.FullName 'workflow.json'
        if (Test-Path $workflowFile) {
            # Skip excluded directories
            $excluded = $false
            foreach ($pattern in $script:ExcludePatterns) {
                if ($_.Name -like $pattern) {
                    $excluded = $true
                    break
                }
            }
            if (-not $excluded) {
                $workflows += $_
                Write-Log "  Found: $($_.Name)" -Level Debug
            }
        }
    }

    if ($workflows.Count -eq 0) {
        throw "No workflow folders found in $ProjectPath"
    }

    Write-Log "Discovered $($workflows.Count) workflow(s)" -Level Success
    return $workflows
}

#endregion

#region Connection Runtime URL Functions

function Get-ApiConnectionRuntimeUrl {
    <#
    .SYNOPSIS
        Retrieves the runtime URL for an API connection from Azure.
    .DESCRIPTION
        Uses Azure REST API to list connection keys and extract the runtime URL.
        This URL is required for the Logic App to communicate with managed API connections.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionName,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )

    Write-Log "Retrieving runtime URL for connection: $ConnectionName" -Level Debug

    try {
        # Get connection resource
        $connectionId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/connections/$ConnectionName"
        
        # List connection keys via REST API
        $keysUri = "https://management.azure.com${connectionId}/listConnectionKeys?api-version=2016-06-01"
        $keysJson = az rest --method POST --uri $keysUri --output json 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $keysJson) {
            $keys = $keysJson | ConvertFrom-Json
            if ($keys.runtimeUrls -and $keys.runtimeUrls.Count -gt 0) {
                Write-Log "  Retrieved runtime URL for $ConnectionName" -Level Debug
                return $keys.runtimeUrls[0]
            }
        }
    }
    catch {
        Write-Log "  Could not retrieve runtime URL for ${ConnectionName}: $_" -Level Warning
    }

    return $null
}

function Get-AllConnectionRuntimeUrls {
    <#
    .SYNOPSIS
        Retrieves runtime URLs for all required API connections.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId
    )

    Write-Log 'Retrieving API connection runtime URLs...'

    $urls = @{
        'SERVICE_BUS_CONNECTION_RUNTIME_URL' = $null
        'AZURE_BLOB_CONNECTION_RUNTIME_URL'  = $null
    }

    # Service Bus connection
    $sbUrl = Get-ApiConnectionRuntimeUrl -ConnectionName 'servicebus' -ResourceGroup $ResourceGroup -SubscriptionId $SubscriptionId
    if ($sbUrl) {
        $urls['SERVICE_BUS_CONNECTION_RUNTIME_URL'] = $sbUrl
    }

    # Azure Blob connection
    $blobUrl = Get-ApiConnectionRuntimeUrl -ConnectionName 'azureblob' -ResourceGroup $ResourceGroup -SubscriptionId $SubscriptionId
    if ($blobUrl) {
        $urls['AZURE_BLOB_CONNECTION_RUNTIME_URL'] = $blobUrl
    }

    return $urls
}

#endregion

#region Placeholder Resolution Functions

function Resolve-PlaceholdersInContent {
    <#
    .SYNOPSIS
        Resolves ${PLACEHOLDER} tokens in content string using environment values.
    .DESCRIPTION
        Replaces all ${KEY} patterns with corresponding values from the provided hashtable.
        Unresolved placeholders are logged as warnings.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [hashtable]$Values,

        [Parameter(Mandatory = $false)]
        [string]$FileName = 'content'
    )

    $resolvedContent = $Content
    $unresolvedKeys = @()

    # Find all placeholders
    $matches = [regex]::Matches($Content, $script:PlaceholderPattern)
    
    foreach ($match in $matches) {
        $placeholder = $match.Value
        $key = $match.Groups[1].Value

        if ($Values.ContainsKey($key) -and $Values[$key]) {
            $resolvedContent = $resolvedContent.Replace($placeholder, $Values[$key])
        }
        else {
            if ($key -notin $unresolvedKeys) {
                $unresolvedKeys += $key
            }
        }
    }

    if ($unresolvedKeys.Count -gt 0) {
        Write-Log "  Unresolved placeholders in ${FileName}: $($unresolvedKeys -join ', ')" -Level Warning
    }

    return $resolvedContent
}

function Resolve-ConfigurationFile {
    <#
    .SYNOPSIS
        Reads a configuration file and resolves all placeholders.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$Values
    )

    if (-not (Test-Path $FilePath)) {
        Write-Log "Configuration file not found: $FilePath" -Level Warning
        return $null
    }

    $fileName = Split-Path $FilePath -Leaf
    $content = Get-Content -Path $FilePath -Raw
    
    return Resolve-PlaceholdersInContent -Content $content -Values $Values -FileName $fileName
}

#endregion

#region Deployment Package Functions

function New-DeploymentPackage {
    <#
    .SYNOPSIS
        Creates a zip deployment package for the Logic App workflows.
    .DESCRIPTION
        Stages all deployment files, resolves placeholders, and creates a zip archive.
        Excludes local development files per .funcignore patterns.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$EnvironmentValues
    )

    Write-Log 'Creating deployment package...'

    # Create staging directory
    $stagingDir = Join-Path ([System.IO.Path]::GetTempPath()) "logicapp-deploy-$(New-Guid)"
    New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null
    Write-Log "Staging directory: $stagingDir" -Level Debug

    try {
        # Copy and process host.json (no placeholders typically)
        $hostJsonPath = Join-Path $SourcePath 'host.json'
        if (Test-Path $hostJsonPath) {
            Copy-Item -Path $hostJsonPath -Destination $stagingDir -Force
            Write-Log '  Copied: host.json' -Level Debug
        }
        else {
            throw 'host.json not found - required for deployment'
        }

        # Process connections.json - resolve identity placeholders
        $connectionsPath = Join-Path $SourcePath 'connections.json'
        if (Test-Path $connectionsPath) {
            $resolvedConnections = Resolve-ConfigurationFile -FilePath $connectionsPath -Values $EnvironmentValues
            $destPath = Join-Path $stagingDir 'connections.json'
            Set-Content -Path $destPath -Value $resolvedConnections -Force
            Write-Log '  Processed: connections.json' -Level Debug
        }

        # Process parameters.json - resolve identity and value placeholders
        $parametersPath = Join-Path $SourcePath 'parameters.json'
        if (Test-Path $parametersPath) {
            $resolvedParameters = Resolve-ConfigurationFile -FilePath $parametersPath -Values $EnvironmentValues
            $destPath = Join-Path $stagingDir 'parameters.json'
            Set-Content -Path $destPath -Value $resolvedParameters -Force
            Write-Log '  Processed: parameters.json' -Level Debug
        }

        # Copy and process workflow folders
        $workflows = Get-WorkflowFolders -ProjectPath $SourcePath
        foreach ($workflow in $workflows) {
            $destWorkflowDir = Join-Path $stagingDir $workflow.Name
            New-Item -ItemType Directory -Path $destWorkflowDir -Force | Out-Null

            # Process workflow.json
            $workflowJsonPath = Join-Path $workflow.FullName 'workflow.json'
            if (Test-Path $workflowJsonPath) {
                $resolvedWorkflow = Resolve-ConfigurationFile -FilePath $workflowJsonPath -Values $EnvironmentValues
                $destPath = Join-Path $destWorkflowDir 'workflow.json'
                Set-Content -Path $destPath -Value $resolvedWorkflow -Force
                Write-Log "  Processed: $($workflow.Name)/workflow.json" -Level Debug
            }
        }

        # Create zip archive
        $timestamp = Get-Date -Format 'yyyyMMddHHmmss'
        $zipPath = Join-Path ([System.IO.Path]::GetTempPath()) "logicapp-deploy-$timestamp.zip"
        
        Compress-Archive -Path "$stagingDir\*" -DestinationPath $zipPath -Force
        
        $zipSize = [math]::Round((Get-Item $zipPath).Length / 1KB, 2)
        Write-Log "Package created: $zipPath ($zipSize KB)" -Level Success

        return $zipPath
    }
    finally {
        # Cleanup staging directory
        if (Test-Path $stagingDir) {
            Remove-Item -Path $stagingDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

#endregion

#region Deployment Functions

function Update-LogicAppSettings {
    <#
    .SYNOPSIS
        Updates Logic App application settings required for workflow execution.
    .DESCRIPTION
        Sets the connection runtime URLs as app settings. These are referenced
        by @appsetting() expressions in connections.json and parameters.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogicAppName,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [hashtable]$Settings,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId
    )

    Write-Log 'Updating Logic App application settings...'

    # Filter to only settings with values
    $settingsToUpdate = @()
    foreach ($key in $Settings.Keys) {
        if ($Settings[$key]) {
            $settingsToUpdate += "$key=$($Settings[$key])"
        }
    }

    if ($settingsToUpdate.Count -eq 0) {
        Write-Log 'No application settings to update' -Level Warning
        return
    }

    Write-Log "  Settings to update: $($settingsToUpdate.Count)" -Level Debug

    $azArgs = @(
        'functionapp', 'config', 'appsettings', 'set',
        '--name', $LogicAppName,
        '--resource-group', $ResourceGroup,
        '--settings'
    ) + $settingsToUpdate + @('--output', 'none')

    if ($SubscriptionId) {
        $azArgs += @('--subscription', $SubscriptionId)
    }

    az @azArgs 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Log 'Failed to update some application settings' -Level Warning
    }
    else {
        Write-Log "Updated $($settingsToUpdate.Count) application setting(s)" -Level Success
    }
}

function Deploy-WorkflowPackage {
    <#
    .SYNOPSIS
        Deploys the workflow package to Azure using zip deployment.
    .DESCRIPTION
        Uses Azure CLI functionapp deployment source config-zip command
        to deploy the Logic App workflow package.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ZipPath,

        [Parameter(Mandatory = $true)]
        [string]$LogicAppName,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $false)]
        [string]$SubscriptionId
    )

    Write-Log "Deploying to Logic App: $LogicAppName"

    $azArgs = @(
        'functionapp', 'deployment', 'source', 'config-zip',
        '--name', $LogicAppName,
        '--resource-group', $ResourceGroup,
        '--src', $ZipPath,
        '--output', 'json'
    )

    if ($SubscriptionId) {
        $azArgs += @('--subscription', $SubscriptionId)
    }

    $startTime = Get-Date
    Write-Log 'Starting zip deployment...' -Level Debug

    $result = az @azArgs 2>&1
    $exitCode = $LASTEXITCODE
    $duration = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 2)

    if ($exitCode -ne 0) {
        Write-Log "Deployment failed after $duration seconds" -Level Error
        Write-Log "Error: $result" -Level Error
        throw "Deployment failed: $result"
    }

    Write-Log "Deployment completed in $duration seconds" -Level Success
    return $result | ConvertFrom-Json
}

function Test-WorkflowDeployment {
    <#
    .SYNOPSIS
        Validates that workflows were deployed successfully.
    .DESCRIPTION
        Queries the Logic App for deployed workflows and verifies expected workflows exist.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LogicAppName,

        [Parameter(Mandatory = $true)]
        [string]$ResourceGroup,

        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedWorkflows
    )

    Write-Log 'Validating workflow deployment...'

    # Allow time for deployment to propagate
    Start-Sleep -Seconds 5

    try {
        $logicAppId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$LogicAppName"
        $uri = "https://management.azure.com${logicAppId}/workflows?api-version=2018-11-01"
        
        $workflowsJson = az rest --method GET --uri $uri --output json 2>$null
        if ($LASTEXITCODE -eq 0 -and $workflowsJson) {
            $workflows = ($workflowsJson | ConvertFrom-Json).value
            $deployedNames = $workflows | ForEach-Object { $_.name }
            
            Write-Log "Deployed workflows: $($deployedNames -join ', ')" -Level Debug

            $allFound = $true
            foreach ($expected in $ExpectedWorkflows) {
                if ($deployedNames -contains $expected) {
                    Write-Log "  ✓ $expected" -Level Success
                }
                else {
                    Write-Log "  ✗ $expected (not found)" -Level Warning
                    $allFound = $false
                }
            }
            return $allFound
        }
    }
    catch {
        Write-Log "Validation query failed: $_" -Level Warning
    }

    return $false
}

#endregion

#region Main Execution

function Invoke-WorkflowDeployment {
    <#
    .SYNOPSIS
        Main orchestration function for workflow deployment.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param()

    Write-Banner -Title 'Logic Apps Standard Workflow Deployment' -Color Cyan
    Write-Log "Script Version: $script:ScriptVersion"

    try {
        #region Step 1: Validate Prerequisites
        Write-Log 'Step 1/7: Validating prerequisites...'
        
        if (-not $SkipValidation) {
            if (-not (Test-AzureCLI)) {
                throw 'Azure CLI validation failed'
            }
        }
        #endregion

        #region Step 2: Load Configuration
        Write-Log 'Step 2/7: Loading configuration...'
        
        # Get azd environment values
        $azdValues = Get-AzdEnvironmentValues

        # Resolve configuration values with fallback chain
        $config = @{
            SubscriptionId    = Resolve-ConfigurationValue -ParameterValue $SubscriptionId -AzdKey 'AZURE_SUBSCRIPTION_ID' -AzdValues $azdValues -EnvironmentVariable 'AZURE_SUBSCRIPTION_ID'
            ResourceGroup     = Resolve-ConfigurationValue -ParameterValue $ResourceGroupName -AzdKey 'AZURE_RESOURCE_GROUP' -AzdValues $azdValues -EnvironmentVariable 'AZURE_RESOURCE_GROUP'
            LogicAppName      = Resolve-ConfigurationValue -ParameterValue $LogicAppName -AzdKey 'LOGIC_APP_NAME' -AzdValues $azdValues -EnvironmentVariable 'LOGIC_APP_NAME'
            Location          = Resolve-ConfigurationValue -ParameterValue $Location -AzdKey 'AZURE_LOCATION' -AzdValues $azdValues -EnvironmentVariable 'AZURE_LOCATION' -DefaultValue 'westus3'
            ManagedIdentityName = Resolve-ConfigurationValue -AzdKey 'MANAGED_IDENTITY_NAME' -AzdValues $azdValues -EnvironmentVariable 'MANAGED_IDENTITY_NAME'
            StorageAccountName  = Resolve-ConfigurationValue -AzdKey 'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW' -AzdValues $azdValues -EnvironmentVariable 'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW'
            OrdersApiUrl        = Resolve-ConfigurationValue -AzdKey 'ORDERS_API_URL' -AzdValues $azdValues -EnvironmentVariable 'ORDERS_API_URL'
        }

        # Validate required parameters
        $missing = @()
        if (-not $config.SubscriptionId) { $missing += 'AZURE_SUBSCRIPTION_ID' }
        if (-not $config.ResourceGroup) { $missing += 'AZURE_RESOURCE_GROUP' }
        if (-not $config.LogicAppName) { $missing += 'LOGIC_APP_NAME' }

        if ($missing.Count -gt 0) {
            throw "Missing required configuration: $($missing -join ', '). Set via azd environment or environment variables."
        }

        Write-Log 'Configuration:' -Level Debug
        Write-Log "  Subscription: $($config.SubscriptionId)" -Level Debug
        Write-Log "  Resource Group: $($config.ResourceGroup)" -Level Debug
        Write-Log "  Logic App: $($config.LogicAppName)" -Level Debug
        Write-Log "  Location: $($config.Location)" -Level Debug
        #endregion

        #region Step 3: Verify Logic App
        Write-Log 'Step 3/7: Verifying Logic App exists...'
        
        if (-not (Test-LogicAppExists -Name $config.LogicAppName -ResourceGroup $config.ResourceGroup -Subscription $config.SubscriptionId)) {
            throw "Logic App '$($config.LogicAppName)' not found"
        }
        #endregion

        #region Step 4: Discover Workflows
        Write-Log 'Step 4/7: Discovering workflows...'
        
        $projectPath = Get-WorkflowProjectPath -ProvidedPath $WorkflowPath
        Write-Log "Project path: $projectPath" -Level Success
        
        $workflows = Get-WorkflowFolders -ProjectPath $projectPath
        $workflowNames = $workflows | ForEach-Object { $_.Name }
        #endregion

        #region Step 5: Get Connection Runtime URLs
        Write-Log 'Step 5/7: Retrieving connection runtime URLs...'
        
        # Check if URLs are already in azd values, otherwise fetch from Azure
        $connectionUrls = @{
            'SERVICE_BUS_CONNECTION_RUNTIME_URL' = $azdValues['SERVICE_BUS_CONNECTION_RUNTIME_URL']
            'AZURE_BLOB_CONNECTION_RUNTIME_URL'  = $azdValues['AZURE_BLOB_CONNECTION_RUNTIME_URL']
        }

        if (-not $connectionUrls['SERVICE_BUS_CONNECTION_RUNTIME_URL'] -or -not $connectionUrls['AZURE_BLOB_CONNECTION_RUNTIME_URL']) {
            $fetchedUrls = Get-AllConnectionRuntimeUrls -ResourceGroup $config.ResourceGroup -SubscriptionId $config.SubscriptionId
            
            if (-not $connectionUrls['SERVICE_BUS_CONNECTION_RUNTIME_URL']) {
                $connectionUrls['SERVICE_BUS_CONNECTION_RUNTIME_URL'] = $fetchedUrls['SERVICE_BUS_CONNECTION_RUNTIME_URL']
            }
            if (-not $connectionUrls['AZURE_BLOB_CONNECTION_RUNTIME_URL']) {
                $connectionUrls['AZURE_BLOB_CONNECTION_RUNTIME_URL'] = $fetchedUrls['AZURE_BLOB_CONNECTION_RUNTIME_URL']
            }
        }

        # Build complete environment values for placeholder resolution
        $envValues = @{
            'AZURE_SUBSCRIPTION_ID'               = $config.SubscriptionId
            'AZURE_RESOURCE_GROUP'                = $config.ResourceGroup
            'AZURE_LOCATION'                      = $config.Location
            'WORKFLOWS_SUBSCRIPTION_ID'           = $config.SubscriptionId
            'WORKFLOWS_RESOURCE_GROUP_NAME'       = $config.ResourceGroup
            'WORKFLOWS_LOCATION_NAME'             = $config.Location
            'MANAGED_IDENTITY_NAME'               = $config.ManagedIdentityName
            'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW' = $config.StorageAccountName
            'ORDERS_API_URL'                      = $config.OrdersApiUrl
            'SERVICE_BUS_CONNECTION_RUNTIME_URL'  = $connectionUrls['SERVICE_BUS_CONNECTION_RUNTIME_URL']
            'AZURE_BLOB_CONNECTION_RUNTIME_URL'   = $connectionUrls['AZURE_BLOB_CONNECTION_RUNTIME_URL']
        }
        #endregion

        #region Step 6: Create Deployment Package
        Write-Log 'Step 6/7: Creating deployment package...'
        
        $zipPath = New-DeploymentPackage -SourcePath $projectPath -EnvironmentValues $envValues
        #endregion

        #region Step 7: Deploy to Azure
        Write-Log 'Step 7/7: Deploying to Azure...'

        # Confirm deployment
        if (-not $Force) {
            if (-not $PSCmdlet.ShouldProcess($config.LogicAppName, 'Deploy workflows')) {
                Write-Log 'Deployment cancelled' -Level Warning
                return [PSCustomObject]@{ Success = $false; Reason = 'Cancelled' }
            }
        }

        # Update application settings for connection runtime URLs
        $appSettings = @{
            'servicebus-ConnectionRuntimeUrl' = $connectionUrls['SERVICE_BUS_CONNECTION_RUNTIME_URL']
            'azureblob-ConnectionRuntimeUrl'  = $connectionUrls['AZURE_BLOB_CONNECTION_RUNTIME_URL']
        }
        Update-LogicAppSettings -LogicAppName $config.LogicAppName -ResourceGroup $config.ResourceGroup -Settings $appSettings -SubscriptionId $config.SubscriptionId

        # Deploy the package
        Deploy-WorkflowPackage -ZipPath $zipPath -LogicAppName $config.LogicAppName -ResourceGroup $config.ResourceGroup -SubscriptionId $config.SubscriptionId

        # Validate deployment
        $validated = Test-WorkflowDeployment -LogicAppName $config.LogicAppName -ResourceGroup $config.ResourceGroup -SubscriptionId $config.SubscriptionId -ExpectedWorkflows $workflowNames
        #endregion

        #region Cleanup and Summary
        if (Test-Path $zipPath) {
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
        }

        Write-Banner -Title 'Deployment Summary' -Color Green
        Write-Log "Logic App: $($config.LogicAppName)"
        Write-Log "Resource Group: $($config.ResourceGroup)"
        Write-Log "Workflows: $($workflowNames -join ', ')"
        Write-Log "Validation: $(if ($validated) { 'Passed' } else { 'Check Azure Portal' })" -Level $(if ($validated) { 'Success' } else { 'Warning' })

        return [PSCustomObject]@{
            Success       = $true
            LogicAppName  = $config.LogicAppName
            ResourceGroup = $config.ResourceGroup
            Workflows     = $workflowNames
            Validated     = $validated
        }
        #endregion
    }
    catch {
        Write-Log "Deployment failed: $_" -Level Error
        Write-Log $_.ScriptStackTrace -Level Debug
        
        return [PSCustomObject]@{
            Success = $false
            Error   = $_.Exception.Message
        }
    }
}

# Execute deployment
$result = Invoke-WorkflowDeployment

# Exit with appropriate code
exit $(if ($result.Success) { 0 } else { 1 })

#endregion
