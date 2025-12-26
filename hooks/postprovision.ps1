#!/usr/bin/env pwsh

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
    Last Modified  : 2025-12-17
    Version        : 2.0.0
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Skip confirmation prompts')]
    [switch]$Force
)

# Script configuration
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

# Script-level constants
$script:ScriptVersion = '2.0.0'
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
                $scriptRoot = Get-Location
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

function Get-ProjectPath {
    <#
    .SYNOPSIS
        Constructs the cross-platform path to the AppHost project file.
    
    .DESCRIPTION
        Builds the absolute path to the app.AppHost.csproj file
        relative to the script location. Uses Join-Path for cross-platform compatibility.
    
    .OUTPUTS
        System.String - The absolute path to the AppHost project file.
    
    .EXAMPLE
        Get-ProjectPath
        Returns: Z:\Logic\app.AppHost\app.AppHost.csproj
        
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
                $scriptRoot = Get-Location
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
            Write-Host $Message -ForegroundColor Cyan
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
    $azureServiceBusTopicName = Get-EnvironmentVariableSafe -Name 'AZURE_SERVICE_BUS_TOPIC_NAME' -DefaultValue 'OrdersPlaced'
    $azureServiceBusSubscriptionName = Get-EnvironmentVariableSafe -Name 'AZURE_SERVICE_BUS_SUBSCRIPTION_NAME' -DefaultValue 'OrderProcessingSubscription'
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
    
    # Get and verify both project paths
    Write-Verbose "Resolving project paths..."
    
    # Get AppHost project path
    $appHostProjectPath = Get-ProjectPath
    Write-Information "  AppHost Project: $appHostProjectPath"
    
    if (-not (Test-Path -Path $appHostProjectPath -PathType Leaf)) {
        Write-Warning "AppHost project file not found at: $appHostProjectPath"
    }
    else {
        Write-Verbose "✓ AppHost project file verified"
    }
    
    # Get API project path (primary target for secrets)
    $projectPath = Get-ApiProjectPath
    Write-Information "✓ API Project Path: $projectPath"
    
    if (-not (Test-Path -Path $projectPath -PathType Leaf)) {
        $errorMessage = @(
            "API project file not found at: $projectPath"
            'Please ensure the project structure is correct.'
            'Expected location: <script-root>/../src/eShop.Orders.API/eShop.Orders.API.csproj'
        ) -join "`n"
        throw $errorMessage
    }
    
    Write-Information "✓ API project file verified."
    
    # Clear existing user secrets
    Write-SectionHeader -Message "Clearing Existing User Secrets" -Type 'Sub'
    
    if ($PSCmdlet.ShouldProcess($projectPath, "Clear user secrets")) {
        try {
            Write-Verbose "Executing: dotnet user-secrets clear -p `"$projectPath`""
            $clearOutput = & dotnet user-secrets clear -p $projectPath 2>&1
            $clearExitCode = $LASTEXITCODE
            
            if ($clearExitCode -ne 0) {
                $errorMessage = "Failed to clear user secrets. Exit code: $clearExitCode"
                if ($clearOutput) {
                    $errorMessage += "`nOutput: $($clearOutput -join "`n")"
                }
                throw $errorMessage
            }
            
            Write-Information "✓ User secrets cleared successfully."
            Write-Verbose "Clear operation completed"
        }
        catch {
            $errorMessage = @(
                "Error clearing user secrets: $($_.Exception.Message)"
                "This may indicate the project doesn't have user secrets initialized."
            ) -join "`n"
            throw $errorMessage
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
        'Azure:ManagedIdentity:ClientId'   = $azureClientId
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
        'Azure:ManagedIdentity:ClientId'   = $azureClientId
        'ApplicationInsights:ConnectionString' = $applicationInsightsConnectionString
    }
    
    Write-Information "Preparing to configure user secrets for both projects..."
    Write-Information "  - AppHost: $($appHostSecrets.Count) secret(s)"
    Write-Information "  - API: $($apiSecrets.Count) secret(s)"
    
    # Track results across both projects
    $totalSecretsCount = $appHostSecrets.Count + $apiSecrets.Count
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
    Write-Verbose "Target project: $projectPath"
    
    foreach ($key in $apiSecrets.Keys) {
        try {
            $value = $apiSecrets[$key]
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Verbose "  Skipping secret '$key' - value is null, empty, or whitespace"
                $totalSkippedCount++
                continue
            }
            
            Write-Verbose "  Processing secret: $key"
            Set-DotNetUserSecret -Key $key -Value $value -ProjectPath $projectPath
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
    
    exit 0
}
catch {
    # Comprehensive error reporting
    Write-SectionHeader -Message "Post-Provisioning Failed!" -Type 'Main'
    
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║                   EXECUTION FAILED                           ║" -ForegroundColor Red
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error Message:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error Type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    
    # Position information
    if ($_.InvocationInfo) {
        Write-Host "" -ForegroundColor Red
        Write-Host "Location:" -ForegroundColor Red
        Write-Host "  Script: $($_.InvocationInfo.ScriptName)" -ForegroundColor Red
        Write-Host "  Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        Write-Host "  Column: $($_.InvocationInfo.OffsetInLine)" -ForegroundColor Red
    }
    
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
    exit 1
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
}

#endregion