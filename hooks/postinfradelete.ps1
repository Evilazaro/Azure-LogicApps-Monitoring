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
    - Validates required environment variables (subscription, location)
    - Authenticates to Azure using the current CLI session
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
    Version        : 2.0.0
    Last Modified  : 2026-01-09
    Prerequisite   : Azure CLI 2.50+, PowerShell Core 7.0+
    Required Env   : AZURE_SUBSCRIPTION_ID, AZURE_LOCATION (set by azd)

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
    Write-Verbose -Message 'Force enabled: confirmation prompts suppressed (ConfirmPreference=None).'
}

#endregion Script Configuration

#region Script Constants

# Script metadata constants
$script:ScriptVersion = '2.0.0'

# Required environment variables for script execution (set by azd)
$script:RequiredEnvironmentVariables = @(
    'AZURE_SUBSCRIPTION_ID',
    'AZURE_LOCATION'
)

# Azure REST API version for deleted sites operations
$script:AzureApiVersion = '2023-12-01'

#endregion Script Constants

#region Helper Functions

function Write-Log {
    <#
    .SYNOPSIS
        Writes a formatted log message to the console.
    
    .DESCRIPTION
        Outputs timestamped, color-coded log messages with level indicators.
        Provides consistent logging format across the script.
    
    .PARAMETER Message
        The message to write. Must not be null or empty.
    
    .PARAMETER Level
        The log level: Info, Success, Warning, or Error. Defaults to Info.
    
    .EXAMPLE
        Write-Log -Message 'Operation completed' -Level Success
        
    .EXAMPLE
        Write-Log -Message 'Starting process...'
        
    .NOTES
        This function does not throw exceptions.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error')]
        [string]$Level = 'Info'
    )
    
    begin {
        Write-Verbose -Message "Logging message at level: $Level"
    }
    
    process {
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
        
        $timestamp = Get-Date -Format 'HH:mm:ss'
        Write-Host -Object "$timestamp $prefix $Message" -ForegroundColor $color
    }
    
    end {
        Write-Verbose -Message 'Log message written'
    }
}

function Test-RequiredEnvironmentVariable {
    <#
    .SYNOPSIS
        Validates that a required environment variable is set.
    
    .DESCRIPTION
        Checks if the specified environment variable exists and has a non-empty value.
        Environment variables are expected to be set by azd during hook execution.
    
    .PARAMETER Name
        The name of the environment variable to validate. Must not be null or empty.
    
    .OUTPUTS
        System.Boolean - Returns $true if variable is set and non-empty, $false otherwise.
    
    .EXAMPLE
        Test-RequiredEnvironmentVariable -Name 'AZURE_SUBSCRIPTION_ID'
        
    .NOTES
        This function does not throw exceptions; it returns a boolean result.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    begin {
        Write-Verbose -Message "Starting environment variable validation for: $Name"
    }
    
    process {
        try {
            $value = [Environment]::GetEnvironmentVariable($Name)
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Warning -Message "Required environment variable '$Name' is not set or is empty."
                return $false
            }
            
            Write-Verbose -Message "Environment variable '$Name' is set with value length: $($value.Length)"
            return $true
        }
        catch {
            Write-Warning -Message "Error checking environment variable '$Name': $($_.Exception.Message)"
            return $false
        }
    }
    
    end {
        Write-Verbose -Message "Completed environment variable validation for: $Name"
    }
}

function Get-EnvironmentValue {
    <#
    .SYNOPSIS
        Retrieves an environment variable value with optional default.
    
    .DESCRIPTION
        Gets the value of the specified environment variable, returning the default
        if the variable is not set or empty. Environment variables are typically
        set by azd during hook execution.
    
    .PARAMETER Name
        The name of the environment variable. Must not be null or empty.
    
    .PARAMETER Default
        The default value to return if the variable is not set. Defaults to empty string.
    
    .OUTPUTS
        System.String - The environment variable value or default.
    
    .EXAMPLE
        Get-EnvironmentValue -Name 'AZURE_LOCATION' -Default 'eastus2'
        
    .EXAMPLE
        $subscriptionId = Get-EnvironmentValue -Name 'AZURE_SUBSCRIPTION_ID'
        
    .NOTES
        This function does not throw exceptions.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory = $false, Position = 1)]
        [AllowEmptyString()]
        [string]$Default = ''
    )
    
    begin {
        Write-Verbose -Message "Retrieving environment variable: $Name"
    }
    
    process {
        try {
            $value = [Environment]::GetEnvironmentVariable($Name)
            
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                Write-Verbose -Message "Environment variable '$Name' found with value length: $($value.Length)"
                return $value
            }
            
            Write-Verbose -Message "Environment variable '$Name' not set, returning default"
            return $Default
        }
        catch {
            Write-Verbose -Message "Error retrieving environment variable '$Name': $($_.Exception.Message)"
            return $Default
        }
    }
    
    end {
        Write-Verbose -Message "Completed retrieval of environment variable: $Name"
    }
}

function Test-AzureCliInstalled {
    <#
    .SYNOPSIS
        Checks if Azure CLI is installed and accessible.
    
    .DESCRIPTION
        Validates that the 'az' command is available in the system PATH.
        Azure CLI is required for making REST API calls to Azure.
    
    .OUTPUTS
        System.Boolean - Returns $true if Azure CLI is installed, $false otherwise.
    
    .EXAMPLE
        if (Test-AzureCliInstalled) { Write-Host 'Azure CLI is available' }
        
    .NOTES
        This function does not throw exceptions; it returns a boolean result.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    begin {
        Write-Verbose -Message 'Checking Azure CLI installation...'
    }
    
    process {
        try {
            $azCommand = Get-Command -Name 'az' -ErrorAction SilentlyContinue
            
            if (-not $azCommand) {
                Write-Log -Message 'Azure CLI (az) is not installed or not in PATH' -Level Error
                return $false
            }
            
            Write-Verbose -Message "Azure CLI found at: $($azCommand.Source)"
            return $true
        }
        catch {
            Write-Log -Message "Error checking Azure CLI: $($_.Exception.Message)" -Level Error
            return $false
        }
    }
    
    end {
        Write-Verbose -Message 'Azure CLI installation check completed'
    }
}

function Test-AzureCliLoggedIn {
    <#
    .SYNOPSIS
        Checks if the user is logged in to Azure CLI.
    
    .DESCRIPTION
        Validates the current Azure CLI session by checking the account information.
        The azd tool typically handles authentication before running hooks.
    
    .OUTPUTS
        System.Boolean - Returns $true if logged in, $false otherwise.
    
    .EXAMPLE
        if (Test-AzureCliLoggedIn) { Write-Host 'Azure session is active' }
        
    .NOTES
        This function does not throw exceptions; it returns a boolean result.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    begin {
        Write-Verbose -Message 'Checking Azure CLI login status...'
    }
    
    process {
        try {
            # Use --output none to suppress output, capture stderr
            $null = az account show --output none 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -ne 0) {
                Write-Log -Message "Not logged in to Azure CLI. Run 'az login' first." -Level Error
                return $false
            }
            
            Write-Verbose -Message 'Azure CLI login verified'
            return $true
        }
        catch {
            Write-Log -Message "Failed to check Azure CLI login status: $($_.Exception.Message)" -Level Error
            return $false
        }
    }
    
    end {
        Write-Verbose -Message 'Azure CLI login check completed'
    }
}

function Get-DeletedLogicApps {
    <#
    .SYNOPSIS
        Retrieves a list of soft-deleted Logic Apps in the specified location.
    
    .DESCRIPTION
        Queries the Azure REST API to get all Logic Apps Standard in a soft-deleted
        state within the specified subscription and location. Uses Azure CLI's
        'az rest' command for authenticated API calls.
    
    .PARAMETER SubscriptionId
        The Azure subscription ID to query. Must not be null or empty.
    
    .PARAMETER Location
        The Azure region to search for deleted Logic Apps. Must not be null or empty.
    
    .OUTPUTS
        System.Object[] - Array of deleted Logic App objects, or empty array if none found.
    
    .EXAMPLE
        Get-DeletedLogicApps -SubscriptionId '12345678-...' -Location 'eastus2'
        
    .NOTES
        Returns an empty array on error rather than throwing exceptions.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Location
    )
    
    begin {
        Write-Verbose -Message "Starting query for deleted Logic Apps in location: $Location"
    }
    
    process {
        Write-Log -Message "Querying for soft-deleted Logic Apps in location '$Location'..." -Level Info
        
        try {
            # Build the Azure REST API URI for listing deleted sites
            $uri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Web/locations/$Location/deletedSites?api-version=$script:AzureApiVersion"
            
            Write-Verbose -Message "Calling REST API: $uri"
            
            # Execute the REST API call using Azure CLI
            $jsonOutput = az rest --method GET --uri $uri --output json 2>&1
            $exitCode = $LASTEXITCODE
            
            if ($exitCode -ne 0) {
                Write-Log -Message "Failed to query deleted sites: $jsonOutput" -Level Warning
                return @()
            }
            
            # Parse the JSON response
            $result = $jsonOutput | ConvertFrom-Json
            
            if (-not $result.value -or $result.value.Count -eq 0) {
                Write-Log -Message "No soft-deleted sites found in location '$Location'" -Level Info
                return @()
            }
            
            # Filter for Logic Apps Standard (kind contains 'workflowapp')
            $deletedLogicApps = @($result.value | Where-Object {
                $_.properties.kind -match 'workflowapp'
            })
            
            if ($deletedLogicApps.Count -eq 0) {
                Write-Log -Message "No soft-deleted Logic Apps found in location '$Location'" -Level Info
                return @()
            }
            
            Write-Log -Message "Found $($deletedLogicApps.Count) soft-deleted Logic App(s)" -Level Info
            return $deletedLogicApps
        }
        catch {
            Write-Log -Message "Error querying deleted Logic Apps: $($_.Exception.Message)" -Level Error
            Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
            return @()
        }
    }
    
    end {
        Write-Verbose -Message 'Completed query for deleted Logic Apps'
    }
}

function Remove-DeletedLogicApp {
    <#
    .SYNOPSIS
        Permanently purges a soft-deleted Logic App.
    
    .DESCRIPTION
        Calls the Azure REST API to permanently delete (purge) a soft-deleted
        Logic App Standard, removing it from the soft-delete state. This action
        is irreversible.
    
    .PARAMETER DeletedSiteId
        The resource ID of the deleted site in the deletedSites collection.
        Must not be null or empty.
    
    .PARAMETER SiteName
        The name of the Logic App for logging purposes. Must not be null or empty.
    
    .OUTPUTS
        System.Boolean - Returns $true if purge was successful, $false otherwise.
    
    .EXAMPLE
        Remove-DeletedLogicApp -DeletedSiteId '/subscriptions/.../deletedSites/123' -SiteName 'my-logic-app'
        
    .NOTES
        Supports -WhatIf and -Confirm through ShouldProcess.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$DeletedSiteId,
        
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SiteName
    )
    
    begin {
        Write-Verbose -Message "Preparing to purge Logic App: $SiteName"
    }
    
    process {
        if ($PSCmdlet.ShouldProcess($SiteName, 'Purge soft-deleted Logic App')) {
            try {
                Write-Log -Message "Purging Logic App: $SiteName" -Level Info
                Write-Verbose -Message "Deleted site ID: $DeletedSiteId"
                
                # Build the DELETE URI for purging the deleted site
                $uri = "https://management.azure.com$DeletedSiteId`?api-version=$script:AzureApiVersion"
                
                Write-Verbose -Message "Calling REST API: DELETE $uri"
                
                # Execute the DELETE request using Azure CLI
                $output = az rest --method DELETE --uri $uri 2>&1
                $exitCode = $LASTEXITCODE
                
                if ($exitCode -ne 0) {
                    Write-Log -Message "Failed to purge Logic App '$SiteName': $output" -Level Error
                    return $false
                }
                
                Write-Log -Message "Successfully purged Logic App: $SiteName" -Level Success
                return $true
            }
            catch {
                Write-Log -Message "Error purging Logic App '$SiteName': $($_.Exception.Message)" -Level Error
                Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
                return $false
            }
        }
        else {
            Write-Log -Message "Would purge Logic App: $SiteName (WhatIf)" -Level Info
            return $true
        }
    }
    
    end {
        Write-Verbose -Message "Completed purge operation for: $SiteName"
    }
}

function Invoke-LogicAppPurge {
    <#
    .SYNOPSIS
        Main function to orchestrate Logic App purge operations.
    
    .DESCRIPTION
        Validates prerequisites, retrieves deleted Logic Apps, and purges them.
        Optionally filters by resource group or Logic App name pattern.
    
    .PARAMETER SubscriptionId
        The Azure subscription ID. Must not be null or empty.
    
    .PARAMETER Location
        The Azure region to search. Must not be null or empty.
    
    .PARAMETER ResourceGroup
        Optional resource group name to filter by.
    
    .PARAMETER LogicAppName
        Optional Logic App name pattern to filter by.
    
    .OUTPUTS
        System.Int32 - Number of Logic Apps successfully purged.
    
    .EXAMPLE
        Invoke-LogicAppPurge -SubscriptionId '12345678-...' -Location 'eastus2'
        
    .EXAMPLE
        Invoke-LogicAppPurge -SubscriptionId '12345678-...' -Location 'eastus2' -ResourceGroup 'rg-myapp'
        
    .NOTES
        Supports -WhatIf and -Confirm through ShouldProcess.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SubscriptionId,
        
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Location,
        
        [Parameter(Mandatory = $false, Position = 2)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$ResourceGroup,
        
        [Parameter(Mandatory = $false, Position = 3)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$LogicAppName
    )
    
    begin {
        Write-Verbose -Message 'Starting Logic App purge orchestration...'
        $purgedCount = 0
    }
    
    process {
        # Get all deleted Logic Apps in the specified location
        $deletedLogicApps = Get-DeletedLogicApps -SubscriptionId $SubscriptionId -Location $Location
        
        if ($deletedLogicApps.Count -eq 0) {
            Write-Log -Message 'No Logic Apps to purge' -Level Success
            return 0
        }
        
        # Filter by resource group if specified
        if (-not [string]::IsNullOrWhiteSpace($ResourceGroup)) {
            Write-Verbose -Message "Filtering by resource group: $ResourceGroup"
            $deletedLogicApps = @($deletedLogicApps | Where-Object {
                $_.properties.resourceGroup -eq $ResourceGroup
            })
            
            if ($deletedLogicApps.Count -eq 0) {
                Write-Log -Message "No deleted Logic Apps found matching resource group '$ResourceGroup'" -Level Info
                return 0
            }
        }
        
        # Filter by Logic App name pattern if specified
        if (-not [string]::IsNullOrWhiteSpace($LogicAppName)) {
            Write-Verbose -Message "Filtering by Logic App name pattern: $LogicAppName"
            $deletedLogicApps = @($deletedLogicApps | Where-Object {
                $_.properties.deletedSiteName -like "*$LogicAppName*"
            })
            
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
    
    end {
        Write-Verbose -Message "Logic App purge orchestration completed. Purged: $purgedCount"
    }
}

#endregion Helper Functions

#region Main Script

function Main {
    <#
    .SYNOPSIS
        Main entry point for the post-infrastructure-delete hook.
    
    .DESCRIPTION
        Orchestrates the Logic App purge process with proper error handling
        and exit code management. This function is called automatically when
        the script runs as an azd hook.
        
    .NOTES
        Supports -WhatIf and -Confirm through ShouldProcess.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param()
    
    begin {
        Write-Verbose -Message 'Initializing post-infrastructure-delete hook...'
    }
    
    process {
        Write-Log -Message '========================================' -Level Info
        Write-Log -Message "Post-Infrastructure Delete Hook v$script:ScriptVersion" -Level Info
        Write-Log -Message 'Logic Apps Purge Script' -Level Info
        Write-Log -Message '========================================' -Level Info
        
        try {
            # Validate Azure CLI installation
            Write-Log -Message 'Validating prerequisites...' -Level Info
            
            if (-not (Test-AzureCliInstalled)) {
                $script:ExitCode = 1
                return
            }
            
            if (-not (Test-AzureCliLoggedIn)) {
                $script:ExitCode = 1
                return
            }
            
            Write-Log -Message 'Azure CLI prerequisites validated' -Level Success
            
            # Validate required environment variables (set by azd)
            $allValid = $true
            foreach ($varName in $script:RequiredEnvironmentVariables) {
                if (-not (Test-RequiredEnvironmentVariable -Name $varName)) {
                    $allValid = $false
                }
            }
            
            if (-not $allValid) {
                Write-Log -Message 'Missing required environment variables. Skipping purge.' -Level Warning
                Write-Log -Message 'Hint: This script is designed to run as an azd hook where environment variables are set.' -Level Info
                $script:ExitCode = 0  # Don't fail the hook, just skip
                return
            }
            
            # Get environment values (set by azd)
            $subscriptionId = Get-EnvironmentValue -Name 'AZURE_SUBSCRIPTION_ID'
            $location = Get-EnvironmentValue -Name 'AZURE_LOCATION'
            $resourceGroup = Get-EnvironmentValue -Name 'AZURE_RESOURCE_GROUP'
            $logicAppName = Get-EnvironmentValue -Name 'LOGIC_APP_NAME'
            
            Write-Log -Message 'Configuration:' -Level Info
            Write-Log -Message "  Subscription: $subscriptionId" -Level Info
            Write-Log -Message "  Location: $location" -Level Info
            
            if (-not [string]::IsNullOrWhiteSpace($resourceGroup)) {
                Write-Log -Message "  Resource Group Filter: $resourceGroup" -Level Info
            }
            
            if (-not [string]::IsNullOrWhiteSpace($logicAppName)) {
                Write-Log -Message "  Logic App Name Filter: $logicAppName" -Level Info
            }
            
            # Execute purge
            Write-Log -Message 'Starting Logic App purge process...' -Level Info
            
            $purgedCount = Invoke-LogicAppPurge `
                -SubscriptionId $subscriptionId `
                -Location $location `
                -ResourceGroup $resourceGroup `
                -LogicAppName $logicAppName
            
            Write-Log -Message '========================================' -Level Info
            Write-Log -Message 'Purge Summary' -Level Info
            Write-Log -Message '========================================' -Level Info
            Write-Log -Message "Logic Apps purged: $purgedCount" -Level Success
            
            $script:ExitCode = 0
        }
        catch {
            Write-Log -Message "Unexpected error during purge: $($_.Exception.Message)" -Level Error
            Write-Verbose -Message "Stack trace: $($_.ScriptStackTrace)"
            $script:ExitCode = 1
        }
    }
    
    end {
        Write-Verbose -Message 'Post-infrastructure-delete hook completed'
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
