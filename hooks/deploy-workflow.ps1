#!/usr/bin/env pwsh

#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys an Azure Logic Apps Standard workflow with placeholder replacement.

.DESCRIPTION
    This script performs the following operations:
    1. Loads azd environment variables
    2. Validates required environment variables
    3. Replaces placeholders in workflow.json and connections.json
    4. Deploys the workflow to Azure Logic Apps Standard using Azure CLI zip deploy

.PARAMETER LogicAppName
    The name of the Azure Logic Apps Standard resource. 
    If not provided, uses LOGIC_APP_NAME from azd environment.

.PARAMETER ResourceGroupName
    The name of the Azure resource group containing the Logic App. 
    If not provided, uses AZURE_RESOURCE_GROUP from azd environment.

.PARAMETER WorkflowName
    The name of the workflow to deploy. Defaults to 'ProcessingOrdersPlaced'.

.PARAMETER WorkflowBasePath
    Base path to the Logic App workflow files. Defaults to the OrdersManagement folder.

.PARAMETER SkipPlaceholderReplacement
    Skip placeholder replacement if files are already processed.

.PARAMETER WhatIf
    Shows what changes would be made without actually deploying.

.PARAMETER Confirm
    Prompts for confirmation before deploying.

.OUTPUTS
    None. Deploys workflow to Azure and outputs status messages.

.EXAMPLE
    ./deploy-workflow.ps1
    Deploys the workflow using environment variables from the active azd environment.

.EXAMPLE
    ./deploy-workflow.ps1 -LogicAppName 'my-logic-app' -ResourceGroupName 'my-rg'
    Deploys to a specific Logic App in a specific resource group.

.EXAMPLE
    ./deploy-workflow.ps1 -WhatIf
    Shows what would be deployed without making changes.

.NOTES
    File Name      : deploy-workflow.ps1
    Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
    Version        : 1.1.0
    Last Modified  : 2026-01-06
    Prerequisite   : PowerShell 7.0 or later
    Prerequisite   : Azure CLI (az)
    Prerequisite   : Azure Developer CLI (azd)
    

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
[OutputType([System.Void])]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$LogicAppName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkflowName = 'ProcessingOrdersPlaced',

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$WorkflowBasePath = "$PSScriptRoot/../workflows/OrdersManagement/OrdersManagementLogicApp",

    [Parameter(Mandatory = $false)]
    [switch]$SkipPlaceholderReplacement
)

# Script configuration
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Script-level constants
$script:ScriptVersion = '1.1.0'

#region Configuration

# Define placeholders for workflow.json
[hashtable[]]$script:WorkflowPlaceholders = @(
    @{ Placeholder = '${ORDERS_API_URL}'; EnvVar = 'ORDERS_API_URL' }
    @{ Placeholder = '${AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW}'; EnvVar = 'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW' }
)

# Define placeholders for connections.json
[hashtable[]]$script:ConnectionPlaceholders = @(
    @{ Placeholder = '${AZURE_SUBSCRIPTION_ID}'; EnvVar = 'AZURE_SUBSCRIPTION_ID' }
    @{ Placeholder = '${AZURE_RESOURCE_GROUP}'; EnvVar = 'AZURE_RESOURCE_GROUP' }
    @{ Placeholder = '${MANAGED_IDENTITY_NAME}'; EnvVar = 'MANAGED_IDENTITY_NAME' }
    @{ Placeholder = '${SERVICE_BUS_CONNECTION_RUNTIME_URL}'; EnvVar = 'SERVICE_BUS_CONNECTION_RUNTIME_URL' }
    @{ Placeholder = '${AZURE_BLOB_CONNECTION_RUNTIME_URL}'; EnvVar = 'AZURE_BLOB_CONNECTION_RUNTIME_URL' }
)

#endregion Configuration

#region Helper Functions

function Initialize-AzdEnvironment {
    <#
    .SYNOPSIS
        Loads azd environment variables into the current session.
    
    .DESCRIPTION
        Retrieves environment variables from the active Azure Developer CLI
        environment and sets them in the current PowerShell session.
    
    .OUTPUTS
        System.Boolean - Returns $true if variables were loaded successfully.
    
    .EXAMPLE
        $success = Initialize-AzdEnvironment
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Host '  Loading azd environment variables...' -ForegroundColor Gray
    
    $azdEnvOutput = azd env get-values 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $azdEnvOutput) {
        Write-Warning 'Could not load azd environment variables. Ensure azd environment is configured.'
        return $false
    }

    $loadedCount = 0
    foreach ($line in $azdEnvOutput) {
        if ($line -match '^([^=]+)="?([^"]*)"?$') {
            $varName = $matches[1]
            $varValue = $matches[2]
            [System.Environment]::SetEnvironmentVariable($varName, $varValue)
            $loadedCount++
            Write-Verbose "Set environment variable: $varName"
        }
    }

    Write-Host "  Loaded $loadedCount environment variables from azd." -ForegroundColor Green
    return $true
}

function Test-RequiredEnvironmentVariables {
    <#
    .SYNOPSIS
        Validates that all required environment variables are set.
    
    .DESCRIPTION
        Checks each placeholder configuration to verify that the corresponding
        environment variable is set and has a non-empty value.
    
    .PARAMETER PlaceholderList
        An array of hashtables containing Placeholder and EnvVar keys.
    
    .OUTPUTS
        System.Boolean - Returns $true if all variables are set.
    
    .EXAMPLE
        Test-RequiredEnvironmentVariables -PlaceholderList $script:WorkflowPlaceholders
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$PlaceholderList
    )

    [string[]]$missingVars = @()
    
    foreach ($item in $PlaceholderList) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        if ([string]::IsNullOrWhiteSpace($envValue)) {
            $missingVars += $item.EnvVar
        }
    }

    if ($missingVars.Count -gt 0) {
        Write-Warning "Missing environment variables: $($missingVars -join ', ')"
        return $false
    }

    return $true
}

function Update-PlaceholderContent {
    <#
    .SYNOPSIS
        Replaces placeholders in the content with environment variable values.
    
    .DESCRIPTION
        Iterates through the placeholder list and replaces each placeholder
        pattern with the corresponding environment variable value.
    
    .PARAMETER Content
        The content string containing placeholders to replace.
    
    .PARAMETER PlaceholderList
        An array of hashtables containing Placeholder and EnvVar keys.
    
    .OUTPUTS
        System.String - The content with all placeholders replaced.
    
    .EXAMPLE
        Update-PlaceholderContent -Content $json -PlaceholderList $script:WorkflowPlaceholders
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$PlaceholderList
    )

    $result = $Content

    foreach ($item in $PlaceholderList) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        if ($null -ne $envValue) {
            $result = $result.Replace($item.Placeholder, $envValue)
            Write-Verbose "Replaced $($item.Placeholder) with value from $($item.EnvVar)"
        }
    }

    return $result
}

function Get-MaskedValue {
    <#
    .SYNOPSIS
        Returns a masked version of sensitive values for display purposes.
    
    .DESCRIPTION
        Masks sensitive values (URLs, secrets, keys, passwords, connections) 
        to prevent accidental exposure in logs or console output.
    
    .PARAMETER Value
        The value to potentially mask.
    
    .PARAMETER VariableName
        The name of the variable, used to determine if masking is needed.
    
    .OUTPUTS
        System.String - The masked or original value.
    
    .EXAMPLE
        Get-MaskedValue -Value $secret -VariableName 'SERVICE_BUS_CONNECTION_RUNTIME_URL'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$VariableName
    )

    if ([string]::IsNullOrEmpty($Value)) {
        return '[Not Set]'
    }

    if ($VariableName -match 'URL|SECRET|KEY|PASSWORD|CONNECTION') {
        $maxLength = [Math]::Min(30, $Value.Length)
        return "$($Value.Substring(0, $maxLength))..."
    }

    return $Value
}

function Invoke-PlaceholderReplacement {
    <#
    .SYNOPSIS
        Replaces placeholders in a file and returns the updated content.
    
    .DESCRIPTION
        Reads a file, replaces all placeholder patterns with their corresponding
        environment variable values, and optionally writes to an output file.
    
    .PARAMETER FilePath
        The path to the file containing placeholders.
    
    .PARAMETER PlaceholderList
        An array of hashtables containing Placeholder and EnvVar keys.
    
    .PARAMETER OutputPath
        Optional path to write the processed content.
    
    .OUTPUTS
        System.String - The content with all placeholders replaced.
    
    .EXAMPLE
        Invoke-PlaceholderReplacement -FilePath './workflow.json' -PlaceholderList $placeholders
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$PlaceholderList,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    if (-not (Test-Path -Path $FilePath)) {
        throw [System.IO.FileNotFoundException]::new("File not found: $FilePath")
    }

    Write-Host "  Processing: $FilePath" -ForegroundColor Gray
    
    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8
    $updatedContent = Update-PlaceholderContent -Content $content -PlaceholderList $PlaceholderList

    if ($OutputPath) {
        $outputDir = Split-Path -Path $OutputPath -Parent
        if (-not [string]::IsNullOrEmpty($outputDir) -and -not (Test-Path -Path $outputDir)) {
            $null = New-Item -ItemType Directory -Path $outputDir -Force
        }
        $updatedContent | Set-Content -Path $OutputPath -Encoding UTF8 -NoNewline
        Write-Host "  Output: $OutputPath" -ForegroundColor Gray
    }

    return $updatedContent
}

function Test-AzureCLIConnection {
    <#
    .SYNOPSIS
        Validates Azure CLI connection and returns account information.
    
    .DESCRIPTION
        Checks if the Azure CLI is authenticated and returns the current
        account information including subscription and tenant details.
    
    .OUTPUTS
        PSCustomObject - Account information with AccountId, SubscriptionId, 
                         SubscriptionName, and TenantId properties.
    
    .EXAMPLE
        $account = Test-AzureCLIConnection
        Write-Host "Connected as: $($account.AccountId)"
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    try {
        $accountJson = az account show --output json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $accountJson) {
            throw 'Not connected to Azure. Please run "az login" first.'
        }
        
        $account = $accountJson | ConvertFrom-Json
        return [PSCustomObject]@{
            AccountId        = $account.user.name
            SubscriptionId   = $account.id
            SubscriptionName = $account.name
            TenantId         = $account.tenantId
        }
    }
    catch {
        throw "Azure CLI connection validation failed: $($_.Exception.Message)"
    }
}

function Deploy-LogicAppWorkflow {
    <#
    .SYNOPSIS
        Deploys a workflow to Azure Logic Apps Standard using zip deployment.
    
    .DESCRIPTION
        Creates a deployment package containing the workflow definition and
        connections configuration, then deploys it to Azure Logic Apps Standard
        using the Azure CLI zip deploy command.
    
    .PARAMETER ResourceGroupName
        The name of the Azure resource group containing the Logic App.
    
    .PARAMETER LogicAppName
        The name of the Azure Logic App resource.
    
    .PARAMETER WorkflowName
        The name of the workflow to deploy.
    
    .PARAMETER WorkflowBasePath
        The base path containing the workflow files.
    
    .PARAMETER WorkflowContent
        The processed workflow.json content.
    
    .PARAMETER ConnectionsContent
        The processed connections.json content.
    
    .OUTPUTS
        PSCustomObject - Deployment result with Success, WorkflowName, and Response properties.
    
    .EXAMPLE
        Deploy-LogicAppWorkflow -ResourceGroupName 'my-rg' -LogicAppName 'my-logic-app' ...
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$LogicAppName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkflowName,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkflowBasePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$WorkflowContent,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionsContent
    )

    if ($PSCmdlet.ShouldProcess("$LogicAppName/$WorkflowName", 'Deploy workflow via zip deploy')) {
        try {
            # Create a temporary directory for the deployment package
            $tempDir = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "logicapp-deploy-$(Get-Random)"
            $null = New-Item -ItemType Directory -Path $tempDir -Force
            
            # Create workflow directory structure
            $workflowDir = Join-Path -Path $tempDir -ChildPath $WorkflowName
            $null = New-Item -ItemType Directory -Path $workflowDir -Force

            # Write workflow.json
            $workflowFilePath = Join-Path -Path $workflowDir -ChildPath 'workflow.json'
            $WorkflowContent | Set-Content -Path $workflowFilePath -Encoding UTF8 -NoNewline
            Write-Verbose "Created workflow file: $workflowFilePath"

            # Write connections.json at root level
            $connectionsFilePath = Join-Path -Path $tempDir -ChildPath 'connections.json'
            $ConnectionsContent | Set-Content -Path $connectionsFilePath -Encoding UTF8 -NoNewline
            Write-Verbose "Created connections file: $connectionsFilePath"

            # Copy host.json if it exists in the source
            $sourceHostJson = Join-Path -Path $WorkflowBasePath -ChildPath 'host.json'
            if (Test-Path -Path $sourceHostJson) {
                $destHostJson = Join-Path -Path $tempDir -ChildPath 'host.json'
                Copy-Item -Path $sourceHostJson -Destination $destHostJson
                Write-Verbose "Copied host.json"
            }

            # Create zip file
            $zipPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "logicapp-deploy-$(Get-Random).zip"
            Write-Host "  Creating deployment package..." -ForegroundColor Gray
            Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
            Write-Verbose "Created zip file: $zipPath"

            # Deploy using Azure CLI
            Write-Host "  Deploying to Logic App via zip deploy..." -ForegroundColor Gray
            $deployOutput = az logicapp deployment source config-zip `
                --resource-group $ResourceGroupName `
                --name $LogicAppName `
                --src $zipPath `
                --output json 2>&1

            if ($LASTEXITCODE -ne 0) {
                # Try alternative deployment method using webapp deploy
                Write-Verbose "Trying alternative deployment method..."
                $deployOutput = az webapp deployment source config-zip `
                    --resource-group $ResourceGroupName `
                    --name $LogicAppName `
                    --src $zipPath `
                    --output json 2>&1
                
                if ($LASTEXITCODE -ne 0) {
                    throw "Deployment failed: $deployOutput"
                }
            }

            # Cleanup temporary files
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue

            return [PSCustomObject]@{
                Success      = $true
                WorkflowName = $WorkflowName
                Response     = $deployOutput
            }
        }
        catch {
            # Cleanup on error
            if ($tempDir -and (Test-Path -Path $tempDir)) {
                Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
            if ($zipPath -and (Test-Path -Path $zipPath)) {
                Remove-Item -Path $zipPath -Force -ErrorAction SilentlyContinue
            }
            throw "Failed to deploy workflow '$WorkflowName': $($_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        Success      = $true
        WorkflowName = $WorkflowName
        WhatIf       = $true
    }
}

function Write-DeploymentSummary {
    <#
    .SYNOPSIS
        Displays a deployment summary with environment variable values.
    
    .DESCRIPTION
        Outputs a formatted summary showing both workflow and connection
        environment variables and their masked values for verification.
    
    .PARAMETER WorkflowPlaceholders
        An array of hashtables containing workflow placeholder configurations.
    
    .PARAMETER ConnectionPlaceholders
        An array of hashtables containing connection placeholder configurations.
    
    .EXAMPLE
        Write-DeploymentSummary -WorkflowPlaceholders $workflow -ConnectionPlaceholders $connections
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$WorkflowPlaceholders,

        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [hashtable[]]$ConnectionPlaceholders
    )

    Write-Host ''
    Write-Host '=== Environment Variables Summary ===' -ForegroundColor Cyan
    
    Write-Host '  Workflow Variables:' -ForegroundColor Yellow
    foreach ($item in $WorkflowPlaceholders) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        $displayValue = Get-MaskedValue -Value $envValue -VariableName $item.EnvVar
        Write-Host "    $($item.EnvVar): $displayValue" -ForegroundColor Gray
    }

    Write-Host '  Connection Variables:' -ForegroundColor Yellow
    foreach ($item in $ConnectionPlaceholders) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        $displayValue = Get-MaskedValue -Value $envValue -VariableName $item.EnvVar
        Write-Host "    $($item.EnvVar): $displayValue" -ForegroundColor Gray
    }
}

#endregion Helper Functions

#region Main Execution

try {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Cyan
    Write-Host '║     Azure Logic Apps Workflow Deployment Script              ║' -ForegroundColor Cyan
    Write-Host '║     (Using Azure CLI and Azure Developer CLI)                ║' -ForegroundColor Cyan
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''

    # Step 1: Load azd environment variables
    Write-Host '[1/5] Loading azd environment...' -ForegroundColor Yellow
    $azdLoaded = Initialize-AzdEnvironment
    if (-not $azdLoaded) {
        Write-Warning 'azd environment not loaded. Using existing environment variables.'
    }

    # Resolve LogicAppName and ResourceGroupName from environment if not provided
    if (-not $LogicAppName) {
        $LogicAppName = [System.Environment]::GetEnvironmentVariable('LOGIC_APP_NAME')
        if (-not $LogicAppName) {
            throw 'LogicAppName parameter is required or LOGIC_APP_NAME environment variable must be set.'
        }
        Write-Host "  Using Logic App from environment: $LogicAppName" -ForegroundColor Gray
    }

    if (-not $ResourceGroupName) {
        $ResourceGroupName = [System.Environment]::GetEnvironmentVariable('AZURE_RESOURCE_GROUP')
        if (-not $ResourceGroupName) {
            throw 'ResourceGroupName parameter is required or AZURE_RESOURCE_GROUP environment variable must be set.'
        }
        Write-Host "  Using Resource Group from environment: $ResourceGroupName" -ForegroundColor Gray
    }

    # Step 2: Validate Azure CLI connection
    Write-Host ''
    Write-Host '[2/5] Validating Azure CLI connection...' -ForegroundColor Yellow
    $azAccount = Test-AzureCLIConnection
    Write-Host "  Connected as: $($azAccount.AccountId)" -ForegroundColor Green
    Write-Host "  Subscription: $($azAccount.SubscriptionName) ($($azAccount.SubscriptionId))" -ForegroundColor Green

    # Step 3: Validate environment variables
    Write-Host ''
    Write-Host '[3/5] Validating environment variables...' -ForegroundColor Yellow
    
    if (-not $SkipPlaceholderReplacement) {
        $allPlaceholders = @()
        $allPlaceholders += $script:WorkflowPlaceholders
        $allPlaceholders += $script:ConnectionPlaceholders

        if (-not (Test-RequiredEnvironmentVariables -PlaceholderList $allPlaceholders)) {
            throw 'Required environment variables are missing. Please set all required variables or run "azd provision" first.'
        }
        Write-Host '  All required environment variables are set.' -ForegroundColor Green
        Write-DeploymentSummary -WorkflowPlaceholders $script:WorkflowPlaceholders -ConnectionPlaceholders $script:ConnectionPlaceholders
    }
    else {
        Write-Host '  Skipping environment variable validation (placeholder replacement disabled).' -ForegroundColor Gray
    }

    # Step 4: Resolve file paths and process placeholders
    Write-Host ''
    Write-Host '[4/5] Processing workflow files...' -ForegroundColor Yellow

    $workflowFilePath = Join-Path -Path $WorkflowBasePath -ChildPath "$WorkflowName/workflow.json"
    $connectionsFilePath = Join-Path -Path $WorkflowBasePath -ChildPath 'connections.json'

    # Resolve paths
    $resolvedWorkflowPath = Resolve-Path -Path $workflowFilePath -ErrorAction Stop
    $resolvedConnectionsPath = Resolve-Path -Path $connectionsFilePath -ErrorAction Stop

    Write-Host "  Workflow file: $resolvedWorkflowPath" -ForegroundColor Gray
    Write-Host "  Connections file: $resolvedConnectionsPath" -ForegroundColor Gray

    # Process files
    if ($SkipPlaceholderReplacement) {
        Write-Host '  Reading files without placeholder replacement...' -ForegroundColor Gray
        $workflowContent = Get-Content -Path $resolvedWorkflowPath -Raw -Encoding UTF8
        $connectionsContent = Get-Content -Path $resolvedConnectionsPath -Raw -Encoding UTF8
    }
    else {
        Write-Host '  Replacing placeholders in workflow.json...' -ForegroundColor Gray
        $workflowContent = Invoke-PlaceholderReplacement -FilePath $resolvedWorkflowPath -PlaceholderList $script:WorkflowPlaceholders

        Write-Host '  Replacing placeholders in connections.json...' -ForegroundColor Gray
        $connectionsContent = Invoke-PlaceholderReplacement -FilePath $resolvedConnectionsPath -PlaceholderList $script:ConnectionPlaceholders
    }

    Write-Host '  Files processed successfully.' -ForegroundColor Green

    # Step 5: Deploy workflow via zip deploy
    Write-Host ''
    Write-Host '[5/5] Deploying workflow to Azure Logic Apps via zip deploy...' -ForegroundColor Yellow
    Write-Host "  Logic App: $LogicAppName" -ForegroundColor Gray
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Gray
    Write-Host "  Workflow: $WorkflowName" -ForegroundColor Gray

    # Resolve the base path for deployment
    $resolvedBasePath = Resolve-Path -Path $WorkflowBasePath -ErrorAction Stop

    $deploymentResult = Deploy-LogicAppWorkflow `
        -ResourceGroupName $ResourceGroupName `
        -LogicAppName $LogicAppName `
        -WorkflowName $WorkflowName `
        -WorkflowBasePath $resolvedBasePath `
        -WorkflowContent $workflowContent `
        -ConnectionsContent $connectionsContent

    if ($deploymentResult.Success) {
        if ($deploymentResult.PSObject.Properties['WhatIf'] -and $deploymentResult.WhatIf) {
            Write-Host '  WhatIf: Workflow deployment would succeed.' -ForegroundColor Yellow
        }
        else {
            Write-Host '  Workflow deployed successfully!' -ForegroundColor Green
        }
    }

    # Post-deployment notes
    Write-Host ''
    Write-Host '=== Post-Deployment Notes ===' -ForegroundColor Cyan
    Write-Host '  - Connections are configured in connections.json' -ForegroundColor Gray
    Write-Host '  - Ensure API connections are authorized in Azure Portal' -ForegroundColor Gray
    Write-Host '  - Verify managed identity has required permissions' -ForegroundColor Gray

    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Green
    Write-Host '║              Deployment Completed Successfully!              ║' -ForegroundColor Green
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Green
    Write-Host ''
}
catch {
    Write-Host ''
    Write-Host '╔══════════════════════════════════════════════════════════════╗' -ForegroundColor Red
    Write-Host '║                    Deployment Failed                         ║' -ForegroundColor Red
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Red
    Write-Host ''
    Write-Error "Deployment failed: $($_.Exception.Message)"
    exit 1
}

#endregion Main Execution
