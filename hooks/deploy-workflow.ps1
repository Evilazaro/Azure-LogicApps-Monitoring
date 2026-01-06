#Requires -Version 7.0

<#
.SYNOPSIS
    Deploys an Azure Logic Apps Standard workflow with placeholder replacement.

.DESCRIPTION
    This script performs the following operations:
    1. Loads azd environment variables
    2. Validates required environment variables
    3. Replaces placeholders in workflow.json and connections.json
    4. Deploys the workflow to Azure Logic Apps Standard using Azure CLI

.PARAMETER LogicAppName
    The name of the Azure Logic Apps Standard resource. If not provided, uses LOGIC_APP_NAME from azd environment.

.PARAMETER ResourceGroupName
    The name of the Azure resource group containing the Logic App. If not provided, uses AZURE_RESOURCE_GROUP from azd environment.

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

.EXAMPLE
    ./deploy-workflow.ps1

.EXAMPLE
    ./deploy-workflow.ps1 -LogicAppName 'my-logic-app' -ResourceGroupName 'my-rg'

.EXAMPLE
    ./deploy-workflow.ps1 -WhatIf

.NOTES
    Author: Azure Logic Apps Team
    Requires: PowerShell 7.0 or later, Azure CLI (az), Azure Developer CLI (azd)
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration

# Define placeholders for workflow.json
$script:WorkflowPlaceholders = @(
    @{ Placeholder = '${ORDERS_API_URL}'; EnvVar = 'ORDERS_API_URL' }
    @{ Placeholder = '${AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW}'; EnvVar = 'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW' }
)

# Define placeholders for connections.json
$script:ConnectionPlaceholders = @(
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
    .OUTPUTS
        System.Boolean
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
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [array]$PlaceholderList
    )

    $missingVars = @()
    
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
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [array]$PlaceholderList
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
    .OUTPUTS
        System.String
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
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [array]$PlaceholderList,

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
    .OUTPUTS
        PSCustomObject with account info
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

function Get-AzureCLIAccessToken {
    <#
    .SYNOPSIS
        Gets an access token for Azure Management API using Azure CLI.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $tokenJson = az account get-access-token --resource 'https://management.azure.com/' --output json 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $tokenJson) {
            throw 'Failed to get access token from Azure CLI.'
        }
        
        $tokenData = $tokenJson | ConvertFrom-Json
        return $tokenData.accessToken
    }
    catch {
        throw "Failed to get access token: $($_.Exception.Message)"
    }
}

function Deploy-LogicAppWorkflow {
    <#
    .SYNOPSIS
        Deploys a workflow to Azure Logic Apps Standard using the REST API.
    .OUTPUTS
        PSCustomObject
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,

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
        [string]$WorkflowDefinition,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken
    )

    $apiVersion = '2023-01-01'
    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/$WorkflowName`?api-version=$apiVersion"

    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type'  = 'application/json'
    }

    # Parse the workflow definition to create the request body
    $workflowObject = $WorkflowDefinition | ConvertFrom-Json -Depth 100
    $requestBody = @{
        properties = @{
            definition = $workflowObject.definition
        }
        kind       = $workflowObject.kind
    } | ConvertTo-Json -Depth 100 -Compress

    if ($PSCmdlet.ShouldProcess("$LogicAppName/$WorkflowName", 'Deploy workflow')) {
        try {
            Write-Verbose "Deploying workflow to: $uri"
            $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $requestBody -ErrorAction Stop
            return [PSCustomObject]@{
                Success      = $true
                WorkflowName = $WorkflowName
                Response     = $response
            }
        }
        catch {
            $errorDetails = $null
            try {
                $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json
            }
            catch {
                # Ignore JSON parse errors
            }
            $errorMessage = if ($errorDetails) { $errorDetails.error.message } else { $_.Exception.Message }
            throw "Failed to deploy workflow '$WorkflowName': $errorMessage"
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
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$WorkflowPlaceholders,

        [Parameter(Mandatory = $true)]
        [array]$ConnectionPlaceholders
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
    Write-Host '[1/6] Loading azd environment...' -ForegroundColor Yellow
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
    Write-Host '[2/6] Validating Azure CLI connection...' -ForegroundColor Yellow
    $azAccount = Test-AzureCLIConnection
    Write-Host "  Connected as: $($azAccount.AccountId)" -ForegroundColor Green
    Write-Host "  Subscription: $($azAccount.SubscriptionName) ($($azAccount.SubscriptionId))" -ForegroundColor Green

    # Step 3: Validate environment variables
    Write-Host ''
    Write-Host '[3/6] Validating environment variables...' -ForegroundColor Yellow
    
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
    Write-Host '[4/6] Processing workflow files...' -ForegroundColor Yellow

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

    # Step 5: Get access token using Azure CLI
    Write-Host ''
    Write-Host '[5/6] Acquiring Azure access token via Azure CLI...' -ForegroundColor Yellow
    $accessToken = Get-AzureCLIAccessToken
    Write-Host '  Access token acquired.' -ForegroundColor Green

    # Step 6: Deploy workflow
    Write-Host ''
    Write-Host '[6/6] Deploying workflow to Azure Logic Apps...' -ForegroundColor Yellow
    Write-Host "  Logic App: $LogicAppName" -ForegroundColor Gray
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Gray
    Write-Host "  Workflow: $WorkflowName" -ForegroundColor Gray

    $deploymentResult = Deploy-LogicAppWorkflow `
        -SubscriptionId $azAccount.SubscriptionId `
        -ResourceGroupName $ResourceGroupName `
        -LogicAppName $LogicAppName `
        -WorkflowName $WorkflowName `
        -WorkflowDefinition $workflowContent `
        -AccessToken $accessToken

    if ($deploymentResult.Success) {
        if ($deploymentResult.WhatIf) {
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
