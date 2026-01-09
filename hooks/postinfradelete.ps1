#!/usr/bin/env pwsh

#Requires -Version 7.0

<#
.SYNOPSIS
    Post-infrastructure-delete hook for Azure Developer CLI (azd).

.DESCRIPTION
    Purges soft-deleted Logic Apps Standard resources after infrastructure deletion.
    This script is automatically executed by azd after 'azd down' completes.
    
    When Azure Logic Apps Standard are deleted, they enter a soft-delete state
    and must be explicitly purged to fully remove them. This script handles
    the purge operation to ensure complete cleanup.
    
    The script performs the following operations:
    - Validates required environment variables (subscription, resource group, location)
    - Authenticates to Azure using the current session
    - Retrieves the list of soft-deleted Logic Apps in the specified location
    - Purges any Logic Apps that match the resource group naming pattern

.PARAMETER Force
    Skips confirmation prompts and forces execution.

.PARAMETER WhatIf
    Shows what would be executed without making changes.

.EXAMPLE
    .\postinfradelete.ps1
    Purges soft-deleted Logic Apps with confirmation prompt.

.EXAMPLE
    .\postinfradelete.ps1 -Force -Verbose
    Purges soft-deleted Logic Apps without confirmation, with verbose output.

.EXAMPLE
    .\postinfradelete.ps1 -WhatIf
    Shows which Logic Apps would be purged without making changes.

.NOTES
    File Name      : postinfradelete.ps1
    Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
    Version        : 1.0.0
    Last Modified  : 2026-01-09
    Prerequisite   : Azure CLI 2.50+, PowerShell Core 7.0+
    Required Env   : AZURE_SUBSCRIPTION_ID, AZURE_LOCATION

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring
    https://learn.microsoft.com/en-us/azure/logic-apps/
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
[OutputType([System.Void])]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Skip confirmation prompts')]
    [switch]$Force
)

#region Script Configuration

# Enable strict mode for robust error handling
Set-StrictMode -Version Latest

# Store original preferences to restore in finally block
$OriginalErrorActionPreference = $ErrorActionPreference
$OriginalInformationPreference = $InformationPreference
$OriginalProgressPreference = $ProgressPreference

# Set script preferences for consistent behavior
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Track final process exit code; exit once at the end to ensure finally cleanup runs
$script:ExitCode = 0

# Handle -Force parameter for confirmation prompts
if ($Force) {
    $ConfirmPreference = 'None'
    Write-Verbose "Force enabled: confirmation prompts suppressed (ConfirmPreference=None)."
}

#endregion Script Configuration

#region Script Constants

# Script metadata constants
$script:ScriptVersion = '1.0.0'

# Required environment variables for script execution
$script:RequiredEnvironmentVariables = @(
    'AZURE_SUBSCRIPTION_ID',
    'AZURE_LOCATION'
)

# Optional environment variable for filtering
$script:OptionalEnvironmentVariables = @(
    'AZURE_RESOURCE_GROUP',
    'LOGIC_APP_NAME'
)

#endregion Script Constants

#region Helper Functions

function Write-Log {
    <#
    .SYNOPSIS
        Writes a formatted log message to the console.
    
    .DESCRIPTION
        Outputs timestamped, color-coded log messages with level indicators.
    
    .PARAMETER Message
        The message to write.
    
    .PARAMETER Level
        The log level: Info, Success, Warning, or Error.
    
    .EXAMPLE
        Write-Log -Message "Operation completed" -Level Success
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    $prefix = @{
        Info    = '[i]'
        Success = '[✓]'
        Warning = '[!]'
        Error   = '[✗]'
    }[$Level]
    
    $color = @{
        Info    = 'Cyan'
        Success = 'Green'
        Warning = 'Yellow'
        Error   = 'Red'
    }[$Level]
    
    Write-Host "$(Get-Date -Format 'HH:mm:ss') $prefix $Message" -ForegroundColor $color
}

function Test-RequiredEnvironmentVariable {
    <#
    .SYNOPSIS
        Validates that a required environment variable is set.
    
    .DESCRIPTION
        Checks if the specified environment variable exists and has a non-empty value.
    
    .PARAMETER Name
        The name of the environment variable to validate.
    
    .OUTPUTS
        System.Boolean - Returns $true if variable is set and non-empty, $false otherwise.
    
    .EXAMPLE
        Test-RequiredEnvironmentVariable -Name 'AZURE_SUBSCRIPTION_ID'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Log -Message "Environment variable '$Name' is not set or empty" -Level Warning
        return $false
    }
    
    Write-Verbose "Environment variable '$Name' is set"
    return $true
}

function Get-EnvironmentValue {
    <#
    .SYNOPSIS
        Retrieves an environment variable value with optional default.
    
    .DESCRIPTION
        Gets the value of the specified environment variable, returning the default
        if the variable is not set or empty.
    
    .PARAMETER Name
        The name of the environment variable.
    
    .PARAMETER Default
        The default value to return if the variable is not set.
    
    .OUTPUTS
        System.String - The environment variable value or default.
    
    .EXAMPLE
        Get-EnvironmentValue -Name 'AZURE_LOCATION' -Default 'eastus2'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [string]$Default = ''
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
    }
    return $Default
}

function Test-AzureCliInstalled {
    <#
    .SYNOPSIS
        Checks if Azure CLI is installed and accessible.
    
    .DESCRIPTION
        Validates that the 'az' command is available in the system PATH.
    
    .OUTPUTS
        System.Boolean - Returns $true if Azure CLI is installed.
    
    .EXAMPLE
        if (Test-AzureCliInstalled) { Write-Host "Azure CLI is available" }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    $azCommand = Get-Command -Name 'az' -ErrorAction SilentlyContinue
    if (-not $azCommand) {
        Write-Log -Message "Azure CLI (az) is not installed or not in PATH" -Level Error
        return $false
    }
    
    Write-Verbose "Azure CLI found at: $($azCommand.Source)"
    return $true
}

function Test-AzureCliLoggedIn {
    <#
    .SYNOPSIS
        Checks if the user is logged in to Azure CLI.
    
    .DESCRIPTION
        Validates the current Azure CLI session by checking the account information.
    
    .OUTPUTS
        System.Boolean - Returns $true if logged in.
    
    .EXAMPLE
        if (Test-AzureCliLoggedIn) { Write-Host "Azure session is active" }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    try {
        $null = az account show --output none 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "Not logged in to Azure CLI. Run 'az login' first." -Level Error
            return $false
        }
        return $true
    }
    catch {
        Write-Log -Message "Failed to check Azure CLI login status: $($_.Exception.Message)" -Level Error
        return $false
    }
}

function Get-DeletedLogicApps {
    <#
    .SYNOPSIS
        Retrieves a list of soft-deleted Logic Apps in the specified location.
    
    .DESCRIPTION
        Queries the Azure REST API to get all Logic Apps Standard in a soft-deleted
        state within the specified subscription and location.
    
    .PARAMETER SubscriptionId
        The Azure subscription ID to query.
    
    .PARAMETER Location
        The Azure region to search for deleted Logic Apps.
    
    .OUTPUTS
        System.Object[] - Array of deleted Logic App objects.
    
    .EXAMPLE
        Get-DeletedLogicApps -SubscriptionId "12345-..." -Location "eastus2"
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$Location
    )
    
    Write-Log -Message "Querying for soft-deleted Logic Apps in location '$Location'..." -Level Info
    
    try {
        # Use the Azure REST API to list deleted sites (includes Logic Apps Standard)
        $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/deletedSites?api-version=2023-12-01"
        
        Write-Verbose "Calling REST API: $uri"
        
        $jsonOutput = az rest --method GET --uri $uri --output json 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log -Message "Failed to query deleted sites: $jsonOutput" -Level Warning
            return @()
        }
        
        $result = $jsonOutput | ConvertFrom-Json
        
        if (-not $result.value -or $result.value.Count -eq 0) {
            Write-Log -Message "No soft-deleted sites found in location '$Location'" -Level Info
            return @()
        }
        
        # Filter for Logic Apps (kind contains 'workflowapp' or 'functionapp,workflowapp')
        $deletedLogicApps = $result.value | Where-Object {
            $_.properties.kind -match 'workflowapp'
        }
        
        if ($deletedLogicApps.Count -eq 0) {
            Write-Log -Message "No soft-deleted Logic Apps found in location '$Location'" -Level Info
            return @()
        }
        
        Write-Log -Message "Found $($deletedLogicApps.Count) soft-deleted Logic App(s)" -Level Info
        return $deletedLogicApps
    }
    catch {
        Write-Log -Message "Error querying deleted Logic Apps: $($_.Exception.Message)" -Level Error
        return @()
    }
}

function Remove-DeletedLogicApp {
    <#
    .SYNOPSIS
        Permanently purges a soft-deleted Logic App.
    
    .DESCRIPTION
        Calls the Azure REST API to permanently delete (purge) a soft-deleted
        Logic App Standard, removing it from the soft-delete state.
    
    .PARAMETER DeletedSiteId
        The resource ID of the deleted site in the deletedSites collection.
    
    .PARAMETER SiteName
        The name of the Logic App for logging purposes.
    
    .OUTPUTS
        System.Boolean - Returns $true if purge was successful.
    
    .EXAMPLE
        Remove-DeletedLogicApp -DeletedSiteId "/subscriptions/.../deletedSites/123" -SiteName "my-logic-app"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$DeletedSiteId,
        
        [Parameter(Mandatory = $true)]
        [string]$SiteName
    )
    
    if ($PSCmdlet.ShouldProcess($SiteName, "Purge soft-deleted Logic App")) {
        try {
            Write-Log -Message "Purging Logic App: $SiteName" -Level Info
            Write-Verbose "Deleted site ID: $DeletedSiteId"
            
            # Use the DELETE method on the deletedSites resource to permanently purge
            $uri = "https://management.azure.com$DeletedSiteId?api-version=2023-12-01"
            
            Write-Verbose "Calling REST API: DELETE $uri"
            
            $output = az rest --method DELETE --uri $uri 2>&1
            
            if ($LASTEXITCODE -ne 0) {
                Write-Log -Message "Failed to purge Logic App '$SiteName': $output" -Level Error
                return $false
            }
            
            Write-Log -Message "Successfully purged Logic App: $SiteName" -Level Success
            return $true
        }
        catch {
            Write-Log -Message "Error purging Logic App '$SiteName': $($_.Exception.Message)" -Level Error
            return $false
        }
    }
    else {
        Write-Log -Message "Would purge Logic App: $SiteName (WhatIf)" -Level Info
        return $true
    }
}

function Invoke-LogicAppPurge {
    <#
    .SYNOPSIS
        Main function to orchestrate Logic App purge operations.
    
    .DESCRIPTION
        Validates prerequisites, retrieves deleted Logic Apps, and purges them.
        Optionally filters by resource group or Logic App name.
    
    .PARAMETER SubscriptionId
        The Azure subscription ID.
    
    .PARAMETER Location
        The Azure region to search.
    
    .PARAMETER ResourceGroup
        Optional resource group name to filter by.
    
    .PARAMETER LogicAppName
        Optional Logic App name to filter by.
    
    .OUTPUTS
        System.Int32 - Number of Logic Apps successfully purged.
    
    .EXAMPLE
        Invoke-LogicAppPurge -SubscriptionId "12345-..." -Location "eastus2"
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true)]
        [string]$Location,
        
        [Parameter(Mandatory = $false)]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory = $false)]
        [string]$LogicAppName
    )
    
    $purgedCount = 0
    
    # Get all deleted Logic Apps
    $deletedLogicApps = Get-DeletedLogicApps -SubscriptionId $SubscriptionId -Location $Location
    
    if ($deletedLogicApps.Count -eq 0) {
        Write-Log -Message "No Logic Apps to purge" -Level Success
        return 0
    }
    
    # Filter by resource group if specified
    if (-not [string]::IsNullOrWhiteSpace($ResourceGroup)) {
        Write-Verbose "Filtering by resource group: $ResourceGroup"
        $deletedLogicApps = $deletedLogicApps | Where-Object {
            $_.properties.resourceGroup -eq $ResourceGroup
        }
        
        if ($deletedLogicApps.Count -eq 0) {
            Write-Log -Message "No deleted Logic Apps found matching resource group '$ResourceGroup'" -Level Info
            return 0
        }
    }
    
    # Filter by Logic App name if specified
    if (-not [string]::IsNullOrWhiteSpace($LogicAppName)) {
        Write-Verbose "Filtering by Logic App name: $LogicAppName"
        $deletedLogicApps = $deletedLogicApps | Where-Object {
            $_.properties.deletedSiteName -like "*$LogicAppName*"
        }
        
        if ($deletedLogicApps.Count -eq 0) {
            Write-Log -Message "No deleted Logic Apps found matching name pattern '$LogicAppName'" -Level Info
            return 0
        }
    }
    
    Write-Log -Message "Found $($deletedLogicApps.Count) Logic App(s) to purge" -Level Info
    
    # List Logic Apps to be purged
    foreach ($logicApp in $deletedLogicApps) {
        $name = $logicApp.properties.deletedSiteName
        $deletedTime = $logicApp.properties.deletedTimestamp
        $rg = $logicApp.properties.resourceGroup
        Write-Log -Message "  - $name (Resource Group: $rg, Deleted: $deletedTime)" -Level Info
    }
    
    # Purge each Logic App
    foreach ($logicApp in $deletedLogicApps) {
        $name = $logicApp.properties.deletedSiteName
        $deletedSiteId = $logicApp.id
        
        $success = Remove-DeletedLogicApp -DeletedSiteId $deletedSiteId -SiteName $name
        if ($success) {
            $purgedCount++
        }
    }
    
    return $purgedCount
}

#endregion Helper Functions

#region Main Script

function Main {
    <#
    .SYNOPSIS
        Main entry point for the post-infrastructure-delete hook.
    
    .DESCRIPTION
        Orchestrates the Logic App purge process with proper error handling
        and exit code management.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()
    
    Write-Log -Message "========================================" -Level Info
    Write-Log -Message "Post-Infrastructure Delete Hook v$script:ScriptVersion" -Level Info
    Write-Log -Message "Logic Apps Purge Script" -Level Info
    Write-Log -Message "========================================" -Level Info
    
    try {
        # Validate Azure CLI installation
        Write-Log -Message "Validating prerequisites..." -Level Info
        
        if (-not (Test-AzureCliInstalled)) {
            $script:ExitCode = 1
            return
        }
        
        if (-not (Test-AzureCliLoggedIn)) {
            $script:ExitCode = 1
            return
        }
        
        Write-Log -Message "Azure CLI prerequisites validated" -Level Success
        
        # Validate required environment variables
        $allValid = $true
        foreach ($varName in $script:RequiredEnvironmentVariables) {
            if (-not (Test-RequiredEnvironmentVariable -Name $varName)) {
                $allValid = $false
            }
        }
        
        if (-not $allValid) {
            Write-Log -Message "Missing required environment variables. Skipping purge." -Level Warning
            Write-Log -Message "Hint: This script is designed to run as an azd hook where environment variables are set." -Level Info
            $script:ExitCode = 0  # Don't fail the hook, just skip
            return
        }
        
        # Get environment values
        $subscriptionId = Get-EnvironmentValue -Name 'AZURE_SUBSCRIPTION_ID'
        $location = Get-EnvironmentValue -Name 'AZURE_LOCATION'
        $resourceGroup = Get-EnvironmentValue -Name 'AZURE_RESOURCE_GROUP'
        $logicAppName = Get-EnvironmentValue -Name 'LOGIC_APP_NAME'
        
        Write-Log -Message "Configuration:" -Level Info
        Write-Log -Message "  Subscription: $subscriptionId" -Level Info
        Write-Log -Message "  Location: $location" -Level Info
        if (-not [string]::IsNullOrWhiteSpace($resourceGroup)) {
            Write-Log -Message "  Resource Group Filter: $resourceGroup" -Level Info
        }
        if (-not [string]::IsNullOrWhiteSpace($logicAppName)) {
            Write-Log -Message "  Logic App Name Filter: $logicAppName" -Level Info
        }
        
        # Execute purge
        Write-Log -Message "Starting Logic App purge process..." -Level Info
        
        $purgedCount = Invoke-LogicAppPurge `
            -SubscriptionId $subscriptionId `
            -Location $location `
            -ResourceGroup $resourceGroup `
            -LogicAppName $logicAppName
        
        Write-Log -Message "========================================" -Level Info
        Write-Log -Message "Purge Summary" -Level Info
        Write-Log -Message "========================================" -Level Info
        Write-Log -Message "Logic Apps purged: $purgedCount" -Level Success
        
        $script:ExitCode = 0
    }
    catch {
        Write-Log -Message "Unexpected error during purge: $($_.Exception.Message)" -Level Error
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
        $script:ExitCode = 1
    }
}

#endregion Main Script

#region Script Execution

try {
    Main
}
finally {
    # Restore original preferences
    $ErrorActionPreference = $OriginalErrorActionPreference
    $InformationPreference = $OriginalInformationPreference
    $ProgressPreference = $OriginalProgressPreference
    
    Write-Log -Message "Script completed with exit code: $script:ExitCode" -Level Info
    exit $script:ExitCode
}

#endregion Script Execution
