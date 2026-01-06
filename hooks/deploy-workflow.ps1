#Requires -Version 7.0
#Requires -Modules Az.Accounts, Az.Resources

<#
.SYNOPSIS
    Deploys an Azure Logic Apps Standard workflow with placeholder replacement.

.DESCRIPTION
    This script performs the following operations:
    1. Validates required environment variables
    2. Replaces placeholders in workflow.json and connections.json
    3. Deploys the workflow to Azure Logic Apps Standard

.PARAMETER LogicAppName
    The name of the Azure Logic Apps Standard resource.

.PARAMETER ResourceGroupName
    The name of the Azure resource group containing the Logic App.

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
    ./deploy-workflow.ps1 -LogicAppName 'my-logic-app' -ResourceGroupName 'my-rg'

.EXAMPLE
    ./deploy-workflow.ps1 -LogicAppName 'my-logic-app' -ResourceGroupName 'my-rg' -WhatIf

.EXAMPLE
    ./deploy-workflow.ps1 -LogicAppName 'my-logic-app' -ResourceGroupName 'my-rg' -WorkflowName 'CustomWorkflow'

.NOTES
    Author: Azure Logic Apps Team
    Requires: PowerShell 7.0 or later, Az.Accounts, Az.Resources modules
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$LogicAppName,

    [Parameter(Mandatory = $true)]
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
[System.Collections.Generic.List[hashtable]]$script:WorkflowPlaceholders = @(
    @{ Placeholder = '${ORDERS_API_URL}'; EnvVar = 'ORDERS_API_URL' }
    @{ Placeholder = '${STORAGE_ACCOUNT_NAME}'; EnvVar = 'STORAGE_ACCOUNT_NAME' }
)

# Define placeholders for connections.json
[System.Collections.Generic.List[hashtable]]$script:ConnectionPlaceholders = @(
    @{ Placeholder = '${AZURE_SUBSCRIPTION_ID}'; EnvVar = 'AZURE_SUBSCRIPTION_ID' }
    @{ Placeholder = '${AZURE_RESOURCE_GROUP}'; EnvVar = 'AZURE_RESOURCE_GROUP' }
    @{ Placeholder = '${MANAGED_IDENTITY_NAME}'; EnvVar = 'MANAGED_IDENTITY_NAME' }
    @{ Placeholder = '${SERVICE_BUS_CONNECTION_RUNTIME_URL}'; EnvVar = 'SERVICE_BUS_CONNECTION_RUNTIME_URL' }
    @{ Placeholder = '${AZURE_BLOB_CONNECTION_RUNTIME_URL}'; EnvVar = 'AZURE_BLOB_CONNECTION_RUNTIME_URL' }
)

#endregion Configuration

#region Helper Functions

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
        [System.Collections.Generic.List[hashtable]]$PlaceholderList
    )

    [System.Collections.Generic.List[string]]$missingVars = [System.Collections.Generic.List[string]]::new()
    
    foreach ($item in $PlaceholderList) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        if ([string]::IsNullOrWhiteSpace($envValue)) {
            $missingVars.Add($item.EnvVar)
        }
    }

    if ($missingVars.Count -gt 0) {
        Write-Warning -Message "Missing environment variables: $($missingVars -join ', ')"
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
        [System.Collections.Generic.List[hashtable]]$PlaceholderList
    )

    $result = $Content

    foreach ($item in $PlaceholderList) {
        $envValue = [System.Environment]::GetEnvironmentVariable($item.EnvVar)
        if ($null -ne $envValue) {
            $result = $result.Replace($item.Placeholder, $envValue)
            Write-Verbose -Message "Replaced $($item.Placeholder) with value from $($item.EnvVar)"
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
        [System.Collections.Generic.List[hashtable]]$PlaceholderList,

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

function Test-AzureConnection {
    <#
    .SYNOPSIS
        Validates Azure connection and returns context information.
    .OUTPUTS
        Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext])]
    param()

    try {
        $context = Get-AzContext -ErrorAction Stop
        if ($null -eq $context -or $null -eq $context.Account) {
            throw 'Not connected to Azure. Please run Connect-AzAccount first.'
        }
        return $context
    }
    catch {
        throw "Azure connection validation failed: $($_.Exception.Message)"
    }
}

function Get-LogicAppAccessToken {
    <#
    .SYNOPSIS
        Gets an access token for Azure Logic Apps API calls.
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $token = Get-AzAccessToken -ResourceUrl 'https://management.azure.com/' -ErrorAction Stop
        return $token.Token
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
        System.Object
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
            Write-Verbose -Message "Deploying workflow to: $uri"
            $response = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $requestBody -ErrorAction Stop
            return [PSCustomObject]@{
                Success      = $true
                WorkflowName = $WorkflowName
                Response     = $response
            }
        }
        catch {
            $errorDetails = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
            throw "Failed to deploy workflow '$WorkflowName': $($errorDetails.error.message ?? $_.Exception.Message)"
        }
    }

    return [PSCustomObject]@{
        Success      = $true
        WorkflowName = $WorkflowName
        WhatIf       = $true
    }
}

function Update-LogicAppConnections {
    <#
    .SYNOPSIS
        Updates the connections configuration for a Logic App.
    .OUTPUTS
        System.Object
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
        [string]$ConnectionsContent,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AccessToken
    )

    $apiVersion = '2023-01-01'
    $uri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName/config/appsettings/list?api-version=$apiVersion"

    $headers = @{
        'Authorization' = "Bearer $AccessToken"
        'Content-Type'  = 'application/json'
    }

    if ($PSCmdlet.ShouldProcess("$LogicAppName", 'Update connections configuration')) {
        try {
            # Get current app settings
            Write-Verbose -Message 'Getting current app settings...'
            $currentSettings = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -ErrorAction Stop

            # Parse connections content
            $connectionsObject = $ConnectionsContent | ConvertFrom-Json -Depth 100

            # Update the Workflows.connections app setting
            $settingsUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.Web/sites/$LogicAppName/config/appsettings?api-version=$apiVersion"
            
            $currentSettings.properties | Add-Member -NotePropertyName 'Workflows.Connection.String' -NotePropertyValue ($ConnectionsContent) -Force

            $updateBody = @{
                properties = $currentSettings.properties
            } | ConvertTo-Json -Depth 100 -Compress

            Write-Verbose -Message 'Updating app settings with connections...'
            $response = Invoke-RestMethod -Uri $settingsUri -Method Put -Headers $headers -Body $updateBody -ErrorAction Stop

            return [PSCustomObject]@{
                Success  = $true
                Response = $response
            }
        }
        catch {
            Write-Warning -Message "Failed to update connections via app settings: $($_.Exception.Message)"
            Write-Warning -Message 'Connections may need to be updated manually or via Azure Portal.'
            return [PSCustomObject]@{
                Success = $false
                Error   = $_.Exception.Message
            }
        }
    }

    return [PSCustomObject]@{
        Success = $true
        WhatIf  = $true
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
        [System.Collections.Generic.List[hashtable]]$WorkflowPlaceholders,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.List[hashtable]]$ConnectionPlaceholders
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
    Write-Host '╚══════════════════════════════════════════════════════════════╝' -ForegroundColor Cyan
    Write-Host ''

    # Step 1: Validate Azure connection
    Write-Host '[1/5] Validating Azure connection...' -ForegroundColor Yellow
    $azContext = Test-AzureConnection
    Write-Host "  Connected as: $($azContext.Account.Id)" -ForegroundColor Green
    Write-Host "  Subscription: $($azContext.Subscription.Name) ($($azContext.Subscription.Id))" -ForegroundColor Green

    # Step 2: Validate environment variables
    Write-Host ''
    Write-Host '[2/5] Validating environment variables...' -ForegroundColor Yellow
    
    if (-not $SkipPlaceholderReplacement) {
        $allPlaceholders = [System.Collections.Generic.List[hashtable]]::new()
        $script:WorkflowPlaceholders | ForEach-Object { $allPlaceholders.Add($_) }
        $script:ConnectionPlaceholders | ForEach-Object { $allPlaceholders.Add($_) }

        if (-not (Test-RequiredEnvironmentVariables -PlaceholderList $allPlaceholders)) {
            $PSCmdlet.ThrowTerminatingError(
                [System.Management.Automation.ErrorRecord]::new(
                    [System.InvalidOperationException]::new('Required environment variables are missing. Please set all required variables.'),
                    'MissingEnvironmentVariables',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $null
                )
            )
        }
        Write-Host '  All required environment variables are set.' -ForegroundColor Green
        Write-DeploymentSummary -WorkflowPlaceholders $script:WorkflowPlaceholders -ConnectionPlaceholders $script:ConnectionPlaceholders
    }
    else {
        Write-Host '  Skipping environment variable validation (placeholder replacement disabled).' -ForegroundColor Gray
    }

    # Step 3: Resolve file paths and process placeholders
    Write-Host ''
    Write-Host '[3/5] Processing workflow files...' -ForegroundColor Yellow

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

    # Step 4: Get access token
    Write-Host ''
    Write-Host '[4/5] Acquiring Azure access token...' -ForegroundColor Yellow
    $accessToken = Get-LogicAppAccessToken
    Write-Host '  Access token acquired.' -ForegroundColor Green

    # Step 5: Deploy workflow
    Write-Host ''
    Write-Host '[5/5] Deploying workflow to Azure Logic Apps...' -ForegroundColor Yellow
    Write-Host "  Logic App: $LogicAppName" -ForegroundColor Gray
    Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Gray
    Write-Host "  Workflow: $WorkflowName" -ForegroundColor Gray

    $deploymentResult = Deploy-LogicAppWorkflow `
        -SubscriptionId $azContext.Subscription.Id `
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

    # Update connections (informational - may require manual steps)
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
    Write-Error -Message "Deployment failed: $($_.Exception.Message)" -Exception $_.Exception
    throw
}

#endregion Main Execution
