#!/usr/bin/env pwsh

#Requires -Version 7.0

<#
.SYNOPSIS
    Post-provisioning script for Azure Developer CLI (azd).

.DESCRIPTION
    Configures .NET user secrets with Azure resource information after provisioning.
    This script is automatically executed by azd after infrastructure provisioning completes.
    
    The script performs the following operations:
    - Validates required environment variables
    - Authenticates to Azure Container Registry (if configured)
    - Clears existing .NET user secrets
    - Configures new user secrets with Azure resource information

.PARAMETER Force
    Skips confirmation prompts and forces execution.

.EXAMPLE
    .\postprovision.ps1
    Runs the post-provisioning script with default settings.

.EXAMPLE
    .\postprovision.ps1 -Verbose
    Runs the script with verbose output for debugging.

.EXAMPLE
    .\postprovision.ps1 -WhatIf
    Shows what the script would do without making changes.

.NOTES
    File Name      : postprovision.ps1
    Prerequisite   : .NET SDK, Azure Developer CLI, Azure CLI
    Required Env   : AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, AZURE_LOCATION
    Author         : Azure DevOps Team
    Last Modified  : 2026-01-06
    Version        : 2.0.1
    
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
[OutputType([System.Void])]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Skip confirmation prompts')]
    [switch]$Force
)

# Script configuration
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# -Force is documented as "skip confirmation prompts".
# In PowerShell, confirmation prompts are controlled by $ConfirmPreference.
if ($Force) {
    $ConfirmPreference = 'None'
    Write-Verbose "Force enabled: confirmation prompts suppressed (ConfirmPreference=None)."
}

# Track final process exit code; exit once at the end to ensure finally cleanup runs.
$script:ExitCode = 0

# Script-level constants
$script:ScriptVersion = '2.0.1'
$script:RequiredEnvironmentVariables = @(
    'AZURE_SUBSCRIPTION_ID',
    'AZURE_RESOURCE_GROUP',
    'AZURE_LOCATION'
)

#region Helper Functions

<#
.DESCRIPTION
    Helper functions for environment validation, project path resolution,
    Azure authentication, and .NET user secrets management.
#>

function Test-RequiredEnvironmentVariable {
    <#
    .SYNOPSIS
        Validates that a required environment variable is set.
    
    .DESCRIPTION
        Checks if the specified environment variable exists and has a non-empty value.
        Logs appropriate messages for success and failure cases.
    
    .PARAMETER Name
        The name of the environment variable to validate.
    
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
        [Parameter(Mandatory = $true, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    begin {
        Write-Verbose "Starting environment variable validation for: $Name"
    }
    
    process {
        try {
            $value = [Environment]::GetEnvironmentVariable($Name)
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Warning "Required environment variable '$Name' is not set or is empty."
                return $false
            }
            
            Write-Verbose "Environment variable '$Name' is set with value length: $($value.Length)"
            return $true
        }
        catch {
            Write-Warning "Error checking environment variable '$Name': $($_.Exception.Message)"
            return $false
        }
    }
    
    end {
        Write-Verbose "Completed environment variable validation for: $Name"
    }
}

function Set-DotNetUserSecret {
    <#
    .SYNOPSIS
        Sets a .NET user secret with comprehensive error handling.
    
    .DESCRIPTION
        Configures a user secret for a .NET project using the dotnet CLI.
        Skips empty values and provides detailed error reporting.
        Validates all inputs before attempting to set the secret.
    
    .PARAMETER Key
        The secret key/name to set. Must not be null or empty.
    
    .PARAMETER Value
        The secret value. Empty values are skipped gracefully.
    
    .PARAMETER ProjectPath
        The full path to the .csproj file. Must exist on disk.
    
    .EXAMPLE
        Set-DotNetUserSecret -Key 'ApiKey' -Value 'secret123' -ProjectPath 'C:\app\app.csproj'
        
    .EXAMPLE
        Set-DotNetUserSecret -Key 'ConnectionString' -Value $connStr -ProjectPath $projectPath -Verbose
    
    .EXAMPLE
        Set-DotNetUserSecret -Key 'ApiKey' -Value $null -ProjectPath $projectPath
        # Silently skips because value is null
        
    .NOTES
        Throws terminating errors if the dotnet CLI command fails.
        Skips silently if the value is empty or whitespace.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        
        [Parameter(Mandatory = $false, Position = 1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Value,
        
        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ 
            if (Test-Path -Path $_ -PathType Leaf) {
                return $true
            }
            throw "Project file not found: $_"
        })]
        [string]$ProjectPath
    )
    
    begin {
        Write-Verbose "Attempting to set user secret for key: $Key"
    }
    
    process {
        # Skip empty values gracefully
        if ([string]::IsNullOrWhiteSpace($Value)) {
            Write-Verbose "Skipping secret '$Key' - value is null, empty, or whitespace"
            return
        }
        
        try {
            # Check for WhatIf support
            if ($PSCmdlet.ShouldProcess("$Key in $ProjectPath", "Set user secret")) {
                Write-Verbose "Executing: dotnet user-secrets set `"$Key`" <value> -p `"$ProjectPath`""
                
                # Capture both stdout and stderr, save exit code immediately
                $output = & dotnet user-secrets set $Key $Value -p $ProjectPath 2>&1
                $exitCode = $LASTEXITCODE  # Capture immediately to prevent race conditions
                
                if ($exitCode -ne 0) {
                    $errorMessage = "Failed to set secret '$Key'. Exit code: $exitCode"
                    if ($output) {
                        $errorMessage += "`nOutput: $($output -join "`n")"
                    }
                    throw $errorMessage
                }
                
                Write-Verbose "Successfully set secret: $Key"
            }
        }
        catch {
            # Re-throw to allow caller to handle; ErrorActionPreference will handle termination
            Write-Verbose "Error details - Exit Code: $LASTEXITCODE, Stack: $($_.ScriptStackTrace)"
            throw "Error setting user secret '$Key': $($_.Exception.Message)"
        }
    }
}

function Get-ApiProjectPath {
    <#
    .SYNOPSIS
        Constructs the cross-platform path to the API project file.
    
    .DESCRIPTION
        Builds the absolute path to the eShop.Orders.API.csproj file
        relative to the script location. Uses Join-Path for cross-platform compatibility.
    
    .OUTPUTS
        System.String - The absolute path to the API project file.
    
    .EXAMPLE
        Get-ApiProjectPath
        Returns: Z:\Logic\src\eShop.Orders.API\eShop.Orders.API.csproj
        
    .NOTES
        Falls back to current location if $PSScriptRoot is not available.
        Uses .NET's GetFullPath for path normalization.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    begin {
        Write-Verbose "Determining API project path..."
    }
    
    process {
        try {
            # Get script root directory
            $scriptRoot = $PSScriptRoot
            if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
                $scriptRoot = (Get-Location).Path
                Write-Verbose "PSScriptRoot is empty, using current location: $scriptRoot"
            }
            
            # Build path using Join-Path for cross-platform compatibility
            $path = Join-Path -Path $scriptRoot -ChildPath '..' | Join-Path -ChildPath 'src'
            $path = Join-Path -Path $path -ChildPath 'eShop.Orders.API'
            $path = Join-Path -Path $path -ChildPath 'eShop.Orders.API.csproj'
            
            # Normalize to absolute path
            $absolutePath = [System.IO.Path]::GetFullPath($path)
            Write-Verbose "Resolved API project path: $absolutePath"
            
            return $absolutePath
        }
        catch {
            throw "Failed to determine API project path: $($_.Exception.Message)"
        }
    }
    
    end {
        Write-Verbose "API project path determination completed"
    }
}

function Get-AppHostProjectPath {
    <#
    .SYNOPSIS
        Constructs the cross-platform path to the AppHost project file.
    
    .DESCRIPTION
        Builds the absolute path to the app.AppHost.csproj file
        relative to the script location. Uses Join-Path for cross-platform compatibility.
    
    .OUTPUTS
        System.String - The absolute path to the AppHost project file.
    
    .EXAMPLE
        Get-AppHostProjectPath
        Returns: Z:\app\app.AppHost\app.AppHost.csproj
        
    .NOTES
        Falls back to current location if $PSScriptRoot is not available.
        Uses .NET's GetFullPath for path normalization.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    begin {
        Write-Verbose "Determining AppHost project path..."
    }
    
    process {
        try {
            # Get script root directory
            $scriptRoot = $PSScriptRoot
            if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
                $scriptRoot = (Get-Location).Path
                Write-Verbose "PSScriptRoot is empty, using current location: $scriptRoot"
            }
            
            # Build path using Join-Path for cross-platform compatibility
            $path = Join-Path -Path $scriptRoot -ChildPath '..'
            $path = Join-Path -Path $path -ChildPath 'app.AppHost'
            $path = Join-Path -Path $path -ChildPath 'app.AppHost.csproj'
            
            # Normalize to absolute path
            $absolutePath = [System.IO.Path]::GetFullPath($path)
            Write-Verbose "Resolved AppHost project path: $absolutePath"
            
            return $absolutePath
        }
        catch {
            throw "Failed to determine AppHost project path: $($_.Exception.Message)"
        }
    }
    
    end {
        Write-Verbose "AppHost project path determination completed"
    }
}

function Get-WebAppProjectPath {
    <#
    .SYNOPSIS
        Constructs the cross-platform path to the Web App project file.
    
    .DESCRIPTION
        Builds the absolute path to the eShop.Web.App.csproj file
        relative to the script location. Uses Join-Path for cross-platform compatibility.
    
    .OUTPUTS
        System.String - The absolute path to the Web App project file.
    
    .EXAMPLE
        Get-WebAppProjectPath
        Returns: Z:\app\src\eShop.Web.App\eShop.Web.App.csproj
        
    .NOTES
        Falls back to current location if $PSScriptRoot is not available.
        Uses .NET's GetFullPath for path normalization.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    begin {
        Write-Verbose "Determining Web App project path..."
    }
    
    process {
        try {
            # Get script root directory
            $scriptRoot = $PSScriptRoot
            if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
                $scriptRoot = (Get-Location).Path
                Write-Verbose "PSScriptRoot is empty, using current location: $scriptRoot"
            }
            
            # Build path using Join-Path for cross-platform compatibility
            $path = Join-Path -Path $scriptRoot -ChildPath '..'
            $path = Join-Path -Path $path -ChildPath 'src'
            $path = Join-Path -Path $path -ChildPath 'eShop.Web.App'
            $path = Join-Path -Path $path -ChildPath 'eShop.Web.App.csproj'
            
            # Normalize to absolute path
            $absolutePath = [System.IO.Path]::GetFullPath($path)
            Write-Verbose "Resolved Web App project path: $absolutePath"
            
            return $absolutePath
        }
        catch {
            throw "Failed to determine Web App project path: $($_.Exception.Message)"
        }
    }
    
    end {
        Write-Verbose "Web App project path determination completed"
    }
}

function Invoke-AzureContainerRegistryLogin {
    <#
    .SYNOPSIS
        Authenticates to Azure Container Registry.
    
    .DESCRIPTION
        Logs into the Azure Container Registry using Azure CLI.
        Validates that the registry endpoint is configured before attempting login.
        Automatically strips .azurecr.io suffix if present.
        Gracefully handles missing Azure CLI or authentication issues.
    
    .PARAMETER RegistryEndpoint
        The Azure Container Registry endpoint name or FQDN.
        Examples: 'myregistry' or 'myregistry.azurecr.io'
    
    .EXAMPLE
        Invoke-AzureContainerRegistryLogin -RegistryEndpoint 'myregistry'
        Logs into the specified Azure Container Registry.
    
    .EXAMPLE
        Invoke-AzureContainerRegistryLogin -RegistryEndpoint 'myregistry.azurecr.io' -Verbose
        Logs in with verbose output for troubleshooting.
        
    .NOTES
        This function does not throw terminating errors. It logs warnings and continues.
        ACR authentication may not be required if using managed identities.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RegistryEndpoint
    )
    
    begin {
        Write-Verbose "Starting Azure Container Registry authentication process..."
    }
    
    process {
        # Validate registry endpoint is provided
        # ACR login is optional - some deployments use managed identities
        if ([string]::IsNullOrWhiteSpace($RegistryEndpoint)) {
            Write-Warning "Azure Container Registry endpoint not configured. Skipping ACR login."
            Write-Verbose "Set AZURE_CONTAINER_REGISTRY_ENDPOINT environment variable if ACR authentication is required."
            return
        }
        
        try {
            # Normalize registry endpoint by removing .azurecr.io suffix
            # Azure CLI expects just the registry name, not the full FQDN
            # Example: 'myregistry.azurecr.io' becomes 'myregistry'
            $registryName = $RegistryEndpoint -replace '\.azurecr\.io$', ''
            
            Write-Information "Authenticating to Azure Container Registry: $RegistryEndpoint"
            Write-Verbose "Using registry name: $registryName"
            
            # Verify Azure CLI is installed and accessible
            # ACR authentication requires Azure CLI (az)
            $azCommand = Get-Command -Name az -ErrorAction SilentlyContinue
            if (-not $azCommand) {
                Write-Warning "Azure CLI (az) not found in PATH. Skipping ACR authentication."
                Write-Information "  Install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
                Write-Verbose "Azure CLI is required for ACR authentication."
                return
            }
            
            Write-Verbose "Azure CLI found at: $($azCommand.Source)"
            
            # Retrieve and log Azure CLI version for troubleshooting
            # Helps identify version-specific issues with ACR authentication
            try {
                $azVersionJson = & az version --output json 2>&1
                $azVersionExitCode = $LASTEXITCODE
                if ($azVersionExitCode -eq 0) {
                    $azVersion = $azVersionJson | ConvertFrom-Json
                    Write-Verbose "Azure CLI version: $($azVersion.'azure-cli')"
                }
                else {
                    Write-Verbose "Could not determine Azure CLI version (exit code: $azVersionExitCode)"
                }
            }
            catch {
                Write-Verbose "Could not determine Azure CLI version: $($_.Exception.Message)"
            }
            
            # Check if logged into Azure CLI
            Write-Verbose "Checking Azure CLI authentication status..."
            $accountOutput = & az account show --output json 2>&1
            $accountExitCode = $LASTEXITCODE
            
            if ($accountExitCode -ne 0) {
                Write-Warning "Not authenticated with Azure CLI. Skipping ACR authentication."
                Write-Information "  Run 'az login' to authenticate with Azure."
                Write-Verbose "az account show exit code: $accountExitCode"
                Write-Verbose "az account show output: $accountOutput"
                return
            }
            
            Write-Verbose "Azure CLI authenticated successfully"
            
            # Perform ACR login with detailed error capture
            Write-Verbose "Executing: az acr login --name $registryName"
            $acrLoginOutput = & az acr login --name $registryName 2>&1
            $acrLoginExitCode = $LASTEXITCODE
            
            if ($acrLoginExitCode -ne 0) {
                Write-Warning "Failed to login to Azure Container Registry '$registryName'."
                Write-Information "  This may not affect deployment if using managed identity."
                Write-Verbose "Exit code: $acrLoginExitCode"
                Write-Verbose "Output: $($acrLoginOutput -join "`n")"
                return
            }
            
            Write-Information "✓ Successfully authenticated to Azure Container Registry: $registryName"
            Write-Verbose "ACR login output: $($acrLoginOutput -join "`n")"
        }
        catch {
            Write-Warning "Azure Container Registry login encountered an error: $($_.Exception.Message)"
            Write-Information "  Continuing with post-provisioning - ACR auth may not be required."
            Write-Verbose "Error details:"
            Write-Verbose "  Message: $($_.Exception.Message)"
            Write-Verbose "  Type: $($_.Exception.GetType().FullName)"
            if ($_.ScriptStackTrace) {
                Write-Verbose "  Stack trace: $($_.ScriptStackTrace)"
            }
        }
    }
    
    end {
        Write-Verbose "Azure Container Registry login process completed"
    }
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a formatted section header to the information stream.
    
    .DESCRIPTION
        Creates visually distinct section headers for script output.
        Supports three types: Main (double line), Sub (single line), and Info (plain).
    
    .PARAMETER Message
        The message to display in the header.
    
    .PARAMETER Type
        The type of header formatting to apply.
        Valid values: 'Main', 'Sub', 'Info'
        Default: 'Info'
        
    .EXAMPLE
        Write-SectionHeader -Message "Starting Configuration" -Type 'Main'
        Outputs a main section header with double-line borders.
        
    .EXAMPLE
        Write-SectionHeader -Message "Validating Prerequisites" -Type 'Sub'
        Outputs a sub-section header with single-line borders.
        
    .NOTES
        Uses Write-Information to allow output control via $InformationPreference.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory = $false, Position = 1)]
        [ValidateSet('Main', 'Sub', 'Info')]
        [string]$Type = 'Info'
    )
    
    begin {
        # Define line separator constants
        $mainSeparator = "═══════════════════════════════════════════════════════"
        $subSeparator  = "───────────────────────────────────────────────────────"
    }
    
    process {
        try {
            switch ($Type) {
                'Main' {
                    Write-Information ""
                    Write-Information $mainSeparator
                    Write-Information $Message
                    Write-Information $mainSeparator
                }
                'Sub' {
                    Write-Information ""
                    Write-Information $subSeparator
                    Write-Information $Message
                    Write-Information $subSeparator
                }
                'Info' {
                    Write-Information ""
                    Write-Information $Message
                }
            }
        }
        catch {
            # Fallback to basic output if Write-Information fails
            Write-Output $Message
        }
    }
    
    end {
        Write-Verbose "Section header written: $Message"
    }
}

function Get-EnvironmentVariableSafe {
    <#
    .SYNOPSIS
        Safely retrieves an environment variable value.
    
    .DESCRIPTION
        Gets an environment variable value with null/empty handling.
        Returns $null for missing or empty variables.
    
    .PARAMETER Name
        The name of the environment variable to retrieve.
        
    .PARAMETER DefaultValue
        Optional default value to return if variable is not set.
    
    .OUTPUTS
        System.String - The variable value, default value, or $null.
        
    .EXAMPLE
        $subscriptionId = Get-EnvironmentVariableSafe -Name 'AZURE_SUBSCRIPTION_ID'
        
    .EXAMPLE
        $location = Get-EnvironmentVariableSafe -Name 'AZURE_LOCATION' -DefaultValue 'eastus'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        
        [Parameter(Mandatory = $false, Position = 1)]
        [AllowNull()]
        [string]$DefaultValue = $null
    )
    
    process {
        try {
            $value = [Environment]::GetEnvironmentVariable($Name)
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Verbose "Environment variable '$Name' is not set or empty."
                return $DefaultValue
            }
            
            return $value
        }
        catch {
            Write-Verbose "Error retrieving environment variable '$Name': $($_.Exception.Message)"
            return $DefaultValue
        }
    }
    
    end {
        Write-Verbose "Environment variable retrieval completed for: $Name"
    }
}

#endregion

#region Main Script Execution

try {
    # Initialize execution timer for performance tracking and reporting
    # Used in finally block to calculate total execution duration
    $script:executionStart = Get-Date
    
    # Display script initialization banner with version and environment info
    # Provides context for troubleshooting and audit logging
    Write-SectionHeader -Message "Post-Provisioning Script Started" -Type 'Main'
    Write-Information "Script Version: $script:ScriptVersion"
    Write-Information "Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Information "PowerShell Version: $($PSVersionTable.PSVersion)"
    
    # Retrieve OS information using cross-platform approach
    # $PSVersionTable.OS exists on PowerShell Core but not Windows PowerShell
    $osInfo = if ($PSVersionTable.OS) { $PSVersionTable.OS } else { "$($PSVersionTable.PSEdition) on $([System.Environment]::OSVersion.Platform)" }
    Write-Information "Operating System: $osInfo"
    
    # Validate all required environment variables before proceeding
    # Fail-fast approach ensures we don't attempt provisioning with incomplete configuration
    Write-SectionHeader -Message "Validating Environment Variables" -Type 'Sub'
    
    # Use strongly-typed List for better performance than array concatenation
    $validationErrors = [System.Collections.Generic.List[string]]::new()
    
    # Check each required environment variable
    # Collect all failures before reporting to provide complete error context
    foreach ($varName in $script:RequiredEnvironmentVariables) {
        Write-Verbose "Validating: $varName"
        if (-not (Test-RequiredEnvironmentVariable -Name $varName)) {
            # Add to error collection (method returns void, hence $null assignment)
            $null = $validationErrors.Add($varName)
        }
        else {
            Write-Verbose "  ✓ $varName is set"
        }
    }
    
    # If any validation failed, build comprehensive error message and terminate
    # Provides user with complete list of missing variables
    if ($validationErrors.Count -gt 0) {
        $errorLines = [System.Collections.Generic.List[string]]::new()
        $errorLines.Add('The following required environment variables are missing or empty:')
        $validationErrors | ForEach-Object { $errorLines.Add("  - $_") }
        $errorLines.Add('')
        $errorLines.Add('Please ensure these environment variables are set before running this script.')
        throw ($errorLines -join "`n")
    }
    
    Write-Information "✓ All $($script:RequiredEnvironmentVariables.Count) required environment variables are set."
    
    # Retrieve all Azure configuration from environment variables
    # Using Get-EnvironmentVariableSafe for consistent null handling and default values
    Write-SectionHeader -Message "Reading Environment Variables" -Type 'Info'
    Write-Verbose "Using safe retrieval for all environment variables..."
    
    # Core Azure configuration (required)
    $azureTenantId = Get-EnvironmentVariableSafe -Name 'AZURE_TENANT_ID'
    $azureSubscriptionId = Get-EnvironmentVariableSafe -Name 'AZURE_SUBSCRIPTION_ID'
    $azureResourceGroup = Get-EnvironmentVariableSafe -Name 'AZURE_RESOURCE_GROUP'
    $azureLocation = Get-EnvironmentVariableSafe -Name 'AZURE_LOCATION'
    
    # Application Insights configuration
    $enableApplicationInsights = $true  # Feature flag for telemetry
    $applicationInsightsName = Get-EnvironmentVariableSafe -Name 'APPLICATION_INSIGHTS_NAME'
    $applicationInsightsConnectionString = Get-EnvironmentVariableSafe -Name 'APPLICATIONINSIGHTS_CONNECTION_STRING'
    
    # Managed Identity configuration
    $azureClientId = Get-EnvironmentVariableSafe -Name 'MANAGED_IDENTITY_CLIENT_ID'
    $azureManagedIdentityName = Get-EnvironmentVariableSafe -Name 'MANAGED_IDENTITY_NAME'
    
    # Service Bus messaging configuration
    $azureServiceBusHostName = Get-EnvironmentVariableSafe -Name 'MESSAGING_SERVICEBUSHOSTNAME'
    # Provide default values for Service Bus topic/subscription names
    $azureServiceBusTopicName = Get-EnvironmentVariableSafe -Name 'AZURE_SERVICE_BUS_TOPIC_NAME' -DefaultValue 'ordersplaced'
    $azureServiceBusSubscriptionName = Get-EnvironmentVariableSafe -Name 'AZURE_SERVICE_BUS_SUBSCRIPTION_NAME' -DefaultValue 'orderprocessingsub'
    $azureMessagingServiceBusEndpoint = Get-EnvironmentVariableSafe -Name 'MESSAGING_SERVICEBUSENDPOINT'
    
    # SQL Database configuration (new in current infrastructure)
    $azureSqlServerFqdn = Get-EnvironmentVariableSafe -Name 'ORDERSDATABASE_SQLSERVERFQDN'
    $azureSqlServerName = Get-EnvironmentVariableSafe -Name 'AZURE_SQL_SERVER_NAME'
    $azureSqlDatabaseName = Get-EnvironmentVariableSafe -Name 'AZURE_SQL_DATABASE_NAME'
    
    # Container Services configuration
    $azureContainerRegistryEndpoint = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_REGISTRY_ENDPOINT'
    $azureContainerRegistryName = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_REGISTRY_NAME'
    $azureContainerAppsEnvironmentName = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_APPS_ENVIRONMENT_NAME'
    $azureContainerAppsEnvironmentId = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_APPS_ENVIRONMENT_ID'
    $azureContainerAppsEnvironmentDomain = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN'
    
    # Monitoring configuration
    $azureLogAnalyticsWorkspaceName = Get-EnvironmentVariableSafe -Name 'AZURE_LOG_ANALYTICS_WORKSPACE_NAME'
    
    # Environment and deployment configuration
    $azureEnvName = Get-EnvironmentVariableSafe -Name 'AZURE_ENV_NAME'
    
    # Storage configuration for Logic Apps and Orders
    $azureStorageAccountName = Get-EnvironmentVariableSafe -Name 'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW'
    
    # Display complete Azure configuration for verification and troubleshooting
    # Using null-coalescing operator (??) to display "<not set>" for null values
    Write-SectionHeader -Message "Azure Configuration" -Type 'Sub'
    $notSet = '<not set>'  # Sentinel value for display purposes
    Write-Information "Azure Tenant ID          : $($azureTenantId ?? $notSet)"
    Write-Information "  Subscription ID        : $($azureSubscriptionId ?? $notSet)"
    Write-Information "  Resource Group         : $($azureResourceGroup ?? $notSet)"
    Write-Information "  Location               : $($azureLocation ?? $notSet)"
    Write-Information "  Environment Name       : $($azureEnvName ?? $notSet)"
    Write-Information "  Client ID              : $($azureClientId ?? $notSet)"
    Write-Information "  Enable App Insights    : $enableApplicationInsights"
    Write-Information "  App Insights Name      : $($applicationInsightsName ?? $notSet)"
    Write-Information "  App Insights Conn Str  : $($applicationInsightsConnectionString ?? $notSet)"
    Write-Information "  Service Bus Host Name  : $($azureServiceBusHostName ?? $notSet)"
    Write-Information "  Service Bus Topic Name : $($azureServiceBusTopicName ?? $notSet)"
    Write-Information "  Service Bus Subscription: $($azureServiceBusSubscriptionName ?? $notSet)"
    Write-Information "  Service Bus Endpoint   : $($azureMessagingServiceBusEndpoint ?? $notSet)"
    Write-Information "  SQL Server FQDN        : $($azureSqlServerFqdn ?? $notSet)"
    Write-Information "  SQL Server Name        : $($azureSqlServerName ?? $notSet)"
    Write-Information "  SQL Database Name      : $($azureSqlDatabaseName ?? $notSet)"
    Write-Information "  ACR Endpoint           : $($azureContainerRegistryEndpoint ?? $notSet)"
    Write-Information "  ACR Name               : $($azureContainerRegistryName ?? $notSet)"
    Write-Information "  Container Apps Env     : $($azureContainerAppsEnvironmentName ?? $notSet)"
    Write-Information "  Container Apps Domain  : $($azureContainerAppsEnvironmentDomain ?? $notSet)"
    Write-Information "  Log Analytics Workspace: $($azureLogAnalyticsWorkspaceName ?? $notSet)"
    Write-Information "  Storage Account Name   : $($azureStorageAccountName ?? $notSet)"
    
    # Attempt Azure Container Registry authentication
    # Non-blocking operation - script continues even if ACR login fails
    # Some deployments may not require ACR authentication (e.g., using managed identities)
    Invoke-AzureContainerRegistryLogin -RegistryEndpoint $azureContainerRegistryEndpoint
    
    # Verify that required tools are installed before proceeding
    # .NET CLI is required for managing user secrets
    Write-SectionHeader -Message "Verifying Prerequisites" -Type 'Sub'
    
    # Check for .NET CLI availability
    # User secrets management requires dotnet CLI
    $dotnetCommand = Get-Command -Name dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCommand) {
        # Build multi-line error message with installation guidance
        $errorMessage = @(
            '.NET CLI (dotnet) not found in PATH.'
            'Please install .NET SDK from: https://dotnet.microsoft.com/download'
            'Required for managing user secrets.'
        ) -join "`n"
        throw $errorMessage
    }
    
    Write-Verbose ".NET CLI found at: $($dotnetCommand.Source)"
    
    # Get .NET version
    try {
        $dotnetVersion = & dotnet --version 2>&1
        $dotnetExitCode = $LASTEXITCODE
        
        if ($dotnetExitCode -ne 0) {
            throw "Failed to get .NET version. Exit code: $dotnetExitCode. Output: $dotnetVersion"
        }
        
        Write-Information "✓ .NET SDK Version: $dotnetVersion"
        Write-Verbose ".NET SDK successfully verified"
    }
    catch {
        $errorMessage = @(
            "Error verifying .NET SDK: $($_.Exception.Message)"
            'Please ensure .NET SDK is properly installed and accessible.'
        ) -join "`n"
        throw $errorMessage
    }
    
    # Get and verify all three project paths
    Write-Verbose "Resolving project paths..."
    
    # Get AppHost project path
    $appHostProjectPath = Get-AppHostProjectPath
    Write-Information "  AppHost Project: $appHostProjectPath"
    
    if (-not (Test-Path -Path $appHostProjectPath -PathType Leaf)) {
        Write-Warning "AppHost project file not found at: $appHostProjectPath"
    }
    else {
        Write-Verbose "✓ AppHost project file verified"
    }
    
    # Get API project path
    $apiProjectPath = Get-ApiProjectPath
    Write-Information "  API Project: $apiProjectPath"
    
    if (-not (Test-Path -Path $apiProjectPath -PathType Leaf)) {
        $errorMessage = @(
            "API project file not found at: $apiProjectPath"
            'Please ensure the project structure is correct.'
            'Expected location: <script-root>/../src/eShop.Orders.API/eShop.Orders.API.csproj'
        ) -join "`n"
        throw $errorMessage
    }
    
    Write-Verbose "✓ API project file verified"
    
    # Get Web App project path
    $webAppProjectPath = Get-WebAppProjectPath
    Write-Information "  Web App Project: $webAppProjectPath"
    
    if (-not (Test-Path -Path $webAppProjectPath -PathType Leaf)) {
        Write-Warning "Web App project file not found at: $webAppProjectPath"
        Write-Warning "Web App secrets will be skipped."
        $webAppProjectPath = $null
    }
    else {
        Write-Verbose "✓ Web App project file verified"
    }
    
    Write-Information "✓ All project paths verified."
    
    # Configure SQL Database Managed Identity
    Write-SectionHeader -Message "Configuring SQL Database Managed Identity" -Type 'Sub'
    
    # IMPORTANT: The managed identity requires db_owner role for:
    # - Entity Framework migrations and schema creation
    # - Creating tables, indexes, and foreign key constraints
    # - Running EnsureCreatedAsync() operations
    # Without db_owner, the application will fail with REFERENCES permission errors
    
    # Only configure SQL managed identity if all required parameters are available
    if ($azureSqlServerName -and $azureSqlDatabaseName -and $azureManagedIdentityName) {
        Write-Information "SQL Database configuration detected..."
        Write-Information "  Server: $azureSqlServerName"
        Write-Information "  Database: $azureSqlDatabaseName"
        Write-Information "  Managed Identity: $azureManagedIdentityName"
        
        # Construct path to SQL managed identity configuration script
        $sqlConfigScriptPath = if ($PSScriptRoot) {
            Join-Path -Path $PSScriptRoot -ChildPath "sql-managed-identity-config.ps1"
        } else {
            Join-Path -Path (Get-Location).Path -ChildPath "sql-managed-identity-config.ps1"
        }
        
        if (-not (Test-Path -Path $sqlConfigScriptPath -PathType Leaf)) {
            Write-Warning "SQL managed identity configuration script not found at: $sqlConfigScriptPath"
            Write-Warning "Skipping SQL database user configuration. The API may not have database access."
        }
        else {
            Write-Verbose "SQL configuration script found at: $sqlConfigScriptPath"
            
            if ($PSCmdlet.ShouldProcess("$azureSqlServerName/$azureSqlDatabaseName", "Configure managed identity database user")) {
                try {
                    Write-Information "Executing SQL managed identity configuration..."
                    
                    # Define database roles for the application
                    # Using db_owner for full schema management and CRUD operations
                    # Required for Entity Framework migrations and EnsureCreatedAsync operations
                    $databaseRoles = @(
                        'db_owner'          # Full permissions: schema creation, data read/write, and constraints
                    )
                    
                    # Execute the SQL configuration script
                    $sqlConfigResult = & $sqlConfigScriptPath `
                        -SqlServerName $azureSqlServerName `
                        -DatabaseName $azureSqlDatabaseName `
                        -PrincipalDisplayName $azureManagedIdentityName `
                        -DatabaseRoles $databaseRoles `
                        -ErrorAction Stop
                    
                    # Check result
                    if ($sqlConfigResult -and $sqlConfigResult.Success) {
                        Write-Information "✓ SQL Database managed identity configured successfully"
                        Write-Verbose "Assigned roles: $($databaseRoles -join ', ')"
                    }
                    elseif ($sqlConfigResult) {
                        Write-Warning "SQL configuration completed with warnings"
                        Write-Warning "Details: $($sqlConfigResult.Message ?? $sqlConfigResult.Error ?? 'Unknown result')"
                    }
                    else {
                        Write-Warning "SQL configuration returned no result object"
                    }
                    
                    # Configure current user for local development access
                    Write-Information "Configuring current Azure user for local development..."
                    try {
                        $currentUser = az account show --query "user.name" -o tsv 2>$null
                        if ($currentUser -and -not [string]::IsNullOrWhiteSpace($currentUser)) {
                            Write-Verbose "Current user: $currentUser"
                            
                            $userConfigResult = & $sqlConfigScriptPath `
                                -SqlServerName $azureSqlServerName `
                                -DatabaseName $azureSqlDatabaseName `
                                -PrincipalDisplayName $currentUser `
                                -DatabaseRoles $databaseRoles `
                                -ErrorAction Stop
                            
                            if ($userConfigResult -and $userConfigResult.Success) {
                                Write-Information "✓ Current user configured for local database access"
                                Write-Information "  User: $currentUser"
                            }
                            else {
                                Write-Verbose "User configuration returned: $($userConfigResult.Message ?? 'Unknown')"
                            }
                        }
                        else {
                            Write-Verbose "Could not detect current Azure user - skipping user configuration"
                        }
                    }
                    catch {
                        Write-Verbose "Failed to configure current user (non-critical): $($_.Exception.Message)"
                        Write-Verbose "You can manually grant yourself permissions using:"
                        Write-Verbose "  .\sql-managed-identity-config.ps1 -SqlServerName '$azureSqlServerName' -DatabaseName '$azureSqlDatabaseName' -PrincipalDisplayName '<your-user@domain.com>' -DatabaseRoles @('db_owner')"
                    }
                }
                catch {
                    # Non-fatal error - log warning but continue with provisioning
                    # The database connection string will still be configured in user secrets
                    # Manual intervention may be required for database access
                    Write-Warning "Failed to configure SQL database managed identity: $($_.Exception.Message)"
                    Write-Warning "The application may not have database access. Manual configuration may be required."
                    Write-Verbose "Error details: $($_.Exception.ToString())"
                    Write-Information ""
                    Write-Information "To manually configure database access, run:"
                    Write-Information "  .\sql-managed-identity-config.ps1 -SqlServerName '$azureSqlServerName' -DatabaseName '$azureSqlDatabaseName' -PrincipalDisplayName '$azureManagedIdentityName' -DatabaseRoles @('db_owner')"
                    Write-Information ""
                }
            }
            else {
                Write-Information "SQL managed identity configuration skipped (WhatIf mode)"
            }
        }
    }
    else {
        Write-Information "SQL Database configuration parameters not available - skipping managed identity setup"
        
        if (-not $azureSqlServerName) {
            Write-Verbose "  Missing: AZURE_SQL_SERVER_NAME"
        }
        if (-not $azureSqlDatabaseName) {
            Write-Verbose "  Missing: AZURE_SQL_DATABASE_NAME"
        }
        if (-not $azureManagedIdentityName) {
            Write-Verbose "  Missing: MANAGED_IDENTITY_NAME"
        }
        
        Write-Information "Database user secrets will still be configured if connection string is available."
    }
    
    # Clear existing user secrets for all projects
    Write-SectionHeader -Message "Clearing Existing User Secrets" -Type 'Sub'
    
    # Clear AppHost secrets
    if ($PSCmdlet.ShouldProcess($appHostProjectPath, "Clear user secrets")) {
        try {
            Write-Verbose "Clearing AppHost secrets: dotnet user-secrets clear -p `"$appHostProjectPath`""
            $clearOutput = & dotnet user-secrets clear -p $appHostProjectPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to clear AppHost user secrets. Output: $clearOutput"
            }
            else {
                Write-Information "✓ AppHost user secrets cleared"
            }
        }
        catch {
            Write-Warning "Error clearing AppHost user secrets: $($_.Exception.Message)"
        }
    }
    
    # Clear API secrets
    if ($PSCmdlet.ShouldProcess($apiProjectPath, "Clear user secrets")) {
        try {
            Write-Verbose "Clearing API secrets: dotnet user-secrets clear -p `"$apiProjectPath`""
            $clearOutput = & dotnet user-secrets clear -p $apiProjectPath 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to clear API user secrets. Output: $clearOutput"
            }
            else {
                Write-Information "✓ API user secrets cleared"
            }
        }
        catch {
            Write-Warning "Error clearing API user secrets: $($_.Exception.Message)"
        }
    }
    
    # Clear Web App secrets (if project exists)
    if ($webAppProjectPath -and (Test-Path -Path $webAppProjectPath -PathType Leaf)) {
        if ($PSCmdlet.ShouldProcess($webAppProjectPath, "Clear user secrets")) {
            try {
                Write-Verbose "Clearing Web App secrets: dotnet user-secrets clear -p `"$webAppProjectPath`""
                $clearOutput = & dotnet user-secrets clear -p $webAppProjectPath 2>&1
                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Failed to clear Web App user secrets. Output: $clearOutput"
                }
                else {
                    Write-Information "✓ Web App user secrets cleared"
                }
            }
            catch {
                Write-Warning "Error clearing Web App user secrets: $($_.Exception.Message)"
            }
        }
    }
    
    # Configure user secrets
    Write-SectionHeader -Message "Configuring User Secrets" -Type 'Sub'
    
    # Define secrets for AppHost project (all Azure configuration)
    $appHostSecrets = [ordered]@{
        'Azure:TenantId'                   = $azureTenantId
        'Azure:SubscriptionId'             = $azureSubscriptionId
        'Azure:Location'                   = $azureLocation
        'Azure:ResourceGroup'              = $azureResourceGroup
        'ApplicationInsights:Enabled'      = $enableApplicationInsights
        'Azure:ApplicationInsights:Name'   = $applicationInsightsName
        'ApplicationInsights:ConnectionString' = $applicationInsightsConnectionString
        'Azure:ClientId'   = $azureClientId
        'Azure:ManagedIdentity:Name'       = $azureManagedIdentityName
        'Azure:ServiceBus:HostName'        = $azureServiceBusHostName
        'Azure:ServiceBus:TopicName'       = $azureServiceBusTopicName
        'Azure:ServiceBus:SubscriptionName' = $azureServiceBusSubscriptionName
        'Azure:ServiceBus:Endpoint'        = $azureMessagingServiceBusEndpoint
        'Azure:SqlServer:Fqdn'             = $azureSqlServerFqdn
        'Azure:SqlServer:Name'             = $azureSqlServerName
        'Azure:SqlDatabase:Name'           = $azureSqlDatabaseName
        'Azure:Storage:AccountName'        = $azureStorageAccountName
        'Azure:ContainerRegistry:Endpoint' = $azureContainerRegistryEndpoint
        'Azure:ContainerRegistry:Name'     = $azureContainerRegistryName
        'Azure:ContainerApps:EnvironmentName' = $azureContainerAppsEnvironmentName
        'Azure:ContainerApps:EnvironmentId' = $azureContainerAppsEnvironmentId
        'Azure:ContainerApps:DefaultDomain' = $azureContainerAppsEnvironmentDomain
        'Azure:LogAnalytics:WorkspaceName' = $azureLogAnalyticsWorkspaceName
    }
    
    # Define secrets for API project (Service Bus and Database configuration)
    $apiSecrets = [ordered]@{
        'Azure:TenantId'                   = $azureTenantId
        'Azure:ClientId'   = $azureClientId
        'ApplicationInsights:ConnectionString' = $applicationInsightsConnectionString
    }
    
    # Add SQL connection string if Azure SQL is configured
    # IMPORTANT: Connection string key must match Program.cs: 'ConnectionStrings:OrderDb'
    if ($azureSqlServerFqdn -and $azureSqlDatabaseName) {
        $sqlConnectionString = "Server=tcp:$azureSqlServerFqdn,1433;Initial Catalog=$azureSqlDatabaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;"
        $apiSecrets['ConnectionStrings:OrderDb'] = $sqlConnectionString
        Write-Verbose "Added SQL connection string for standalone API execution (Key: ConnectionStrings:OrderDb)"
    }
    
    # Define secrets for Web App project (minimal configuration for frontend)
    $webAppSecrets = [ordered]@{
        'ApplicationInsights:ConnectionString' = $applicationInsightsConnectionString
    }
    
    Write-Information "Preparing to configure user secrets for all projects..."
    Write-Information "  - AppHost: $($appHostSecrets.Count) secret(s)"
    Write-Information "  - API: $($apiSecrets.Count) secret(s)"
    Write-Information "  - Web App: $($webAppSecrets.Count) secret(s)"
    
    # Track results across all projects
    $totalSecretsCount = $appHostSecrets.Count + $apiSecrets.Count + $webAppSecrets.Count
    $totalSuccessCount = 0
    $totalSkippedCount = 0
    $failedSecrets = [System.Collections.Generic.List[PSCustomObject]]::new()
    
    # Configure AppHost project secrets
    Write-Information ""
    Write-Information "Configuring AppHost project secrets..."
    Write-Verbose "Target project: $appHostProjectPath"
    
    foreach ($key in $appHostSecrets.Keys) {
        try {
            $value = $appHostSecrets[$key]
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Verbose "  Skipping secret '$key' - value is null, empty, or whitespace"
                $totalSkippedCount++
                continue
            }
            
            Write-Verbose "  Processing secret: $key"
            Set-DotNetUserSecret -Key $key -Value $value -ProjectPath $appHostProjectPath
            $totalSuccessCount++
            Write-Information "  ✓ Set: $key"
        }
        catch {
            Write-Warning "  Failed to set secret '$key': $($_.Exception.Message)"
            $null = $failedSecrets.Add([PSCustomObject]@{
                    Project = 'AppHost'
                    Key     = $key
                    Message = $_.Exception.Message
                })
        }
    }
    
    # Configure API project secrets
    Write-Information ""
    Write-Information "Configuring API project secrets..."
    Write-Verbose "Target project: $apiProjectPath"
    
    foreach ($key in $apiSecrets.Keys) {
        try {
            $value = $apiSecrets[$key]
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Verbose "  Skipping secret '$key' - value is null, empty, or whitespace"
                $totalSkippedCount++
                continue
            }
            
            Write-Verbose "  Processing secret: $key"
            Set-DotNetUserSecret -Key $key -Value $value -ProjectPath $apiProjectPath
            $totalSuccessCount++
            Write-Information "  ✓ Set: $key"
        }
        catch {
            Write-Warning "  Failed to set secret '$key': $($_.Exception.Message)"
            $null = $failedSecrets.Add([PSCustomObject]@{
                    Project = 'API'
                    Key     = $key
                    Message = $_.Exception.Message
                })
        }
    }
    
    # Configure Web App project secrets (if project exists)
    if ($webAppProjectPath) {
        Write-Information ""
        Write-Information "Configuring Web App project secrets..."
        Write-Verbose "Target project: $webAppProjectPath"
        
        foreach ($key in $webAppSecrets.Keys) {
            try {
                $value = $webAppSecrets[$key]
                
                if ([string]::IsNullOrWhiteSpace($value)) {
                    Write-Verbose "  Skipping secret '$key' - value is null, empty, or whitespace"
                    $totalSkippedCount++
                    continue
                }
                
                Write-Verbose "  Processing secret: $key"
                Set-DotNetUserSecret -Key $key -Value $value -ProjectPath $webAppProjectPath
                $totalSuccessCount++
                Write-Information "  ✓ Set: $key"
            }
            catch {
                Write-Warning "  Failed to set secret '$key': $($_.Exception.Message)"
                $null = $failedSecrets.Add([PSCustomObject]@{
                        Project = 'WebApp'
                        Key     = $key
                        Message = $_.Exception.Message
                    })
            }
        }
    }
    else {
        Write-Information ""
        Write-Information "Skipping Web App secrets configuration (project not found)"
        $totalSkippedCount += $webAppSecrets.Count
    }
    
    # Report detailed results
    Write-SectionHeader -Message "Configuration Results" -Type 'Sub'
    Write-Information "User Secrets Configuration Summary:"
    Write-Information "  ✓ Successfully configured: $totalSuccessCount / $totalSecretsCount"
    
    if ($totalSkippedCount -gt 0) {
        Write-Information "  ⊘ Skipped (empty values): $totalSkippedCount"
    }
    
    if ($failedSecrets.Count -gt 0) {
        Write-Warning "  ✗ Failed: $($failedSecrets.Count)"
        foreach ($failed in $failedSecrets) {
            Write-Warning "    - [$($failed.Project)] $($failed.Key): $($failed.Message)"
        }
        
        # Don't fail the entire script for partial failures if some secrets were set
        if ($totalSuccessCount -eq 0) {
            throw "All user secrets failed to configure. Please review errors above."
        }
    }
    
    # Success summary
    Write-SectionHeader -Message "Post-Provisioning Completed Successfully!" -Type 'Main'
    Write-Information "Results:"
    Write-Information "  • Total secrets defined   : $totalSecretsCount"
    Write-Information "  • Successfully configured : $totalSuccessCount"
    Write-Information "  • Skipped (empty)         : $totalSkippedCount"
    Write-Information "  • Failed                  : $($failedSecrets.Count)"
    Write-Information ""
    Write-Information "Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $executionDuration = (New-TimeSpan -Start $script:executionStart -End (Get-Date)).TotalSeconds
    Write-Information "Duration: $([Math]::Round($executionDuration, 2)) seconds"
    Write-Information ""
    Write-Verbose "Exiting with success code 0"

    $script:ExitCode = 0
}
catch {
    # Comprehensive error reporting
    Write-SectionHeader -Message "Post-Provisioning Failed!" -Type 'Main'

    $failureLines = [System.Collections.Generic.List[string]]::new()
    $failureLines.Add('╔══════════════════════════════════════════════════════════════╗')
    $failureLines.Add('║                   EXECUTION FAILED                           ║')
    $failureLines.Add('╚══════════════════════════════════════════════════════════════╝')
    $failureLines.Add('')
    $failureLines.Add('Error Message:')
    $failureLines.Add("  $($_.Exception.Message)")
    $failureLines.Add('')
    $failureLines.Add("Error Type: $($_.Exception.GetType().FullName)")

    # Position information
    if ($_.InvocationInfo) {
        $failureLines.Add('')
        $failureLines.Add('Location:')
        $failureLines.Add("  Script: $($_.InvocationInfo.ScriptName)")
        $failureLines.Add("  Line: $($_.InvocationInfo.ScriptLineNumber)")
        $failureLines.Add("  Column: $($_.InvocationInfo.OffsetInLine)")
    }

    Write-Error ($failureLines -join "`n")
    
    # Stack trace (verbose only)
    if ($_.ScriptStackTrace) {
        Write-Verbose "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        Write-Verbose "Stack Trace:"
        Write-Verbose $_.ScriptStackTrace
        Write-Verbose "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    }
    
    # Troubleshooting guidance
    Write-Information ""
    Write-Information "╔══════════════════════════════════════════════════════════════╗"
    Write-Information "║             TROUBLESHOOTING SUGGESTIONS                      ║"
    Write-Information "╚══════════════════════════════════════════════════════════════╝"
    Write-Information ""
    Write-Information "1. Environment Variables:"
    Write-Information "   • Verify all required variables are set:"
    foreach ($varName in $script:RequiredEnvironmentVariables) {
        $isSet = Test-RequiredEnvironmentVariable -Name $varName
        $status = if ($isSet) { "✓" } else { "✗" }
        Write-Information "     $status $varName"
    }
    Write-Information ""
    Write-Information "2. Prerequisites:"
    Write-Information "   • Ensure .NET SDK is installed: dotnet --version"
    Write-Information "   • Verify Azure CLI authentication: az account show"
    Write-Information "   • Check project file exists: Test-Path <project-path>"
    Write-Information ""
    Write-Information "3. Permissions:"
    Write-Information "   • Ensure you have write access to the project directory"
    Write-Information "   • Verify Azure permissions for resources"
    Write-Information ""
    Write-Information "4. Debugging:"
    Write-Information "   • Run with -Verbose for detailed diagnostic output"
    Write-Information "   • Run with -WhatIf to preview changes without executing"
    Write-Information "   • Review error message and line number above"
    Write-Information ""
    Write-Information "5. Common Issues:"
    Write-Information "   • Project file not found - check directory structure"
    Write-Information "   • User secrets initialization - may need manual init"
    Write-Information "   • Azure CLI not logged in - run 'az login'"
    Write-Information ""
    
    # Exit with error code
    $script:ExitCode = 1
}
finally {
    # Cleanup and reset preferences
    Write-Verbose "Executing finally block - cleaning up..."
    
    # Reset progress preference to default
    $ProgressPreference = 'Continue'
    
    # Calculate total execution time if available
    if (Get-Variable -Name executionStart -Scope Script -ErrorAction SilentlyContinue) {
        try {
            $duration = (Get-Date) - $script:executionStart
            $durationSeconds = [Math]::Round($duration.TotalSeconds, 2)
            Write-Verbose "Total execution time: $durationSeconds seconds"
        }
        catch {
            Write-Verbose "Could not calculate execution duration"
        }
    }
    
    Write-Verbose "Script execution completed."

    exit $script:ExitCode
}

#endregion