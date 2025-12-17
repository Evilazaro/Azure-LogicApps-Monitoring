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
                
                # Capture both stdout and stderr
                $output = & dotnet user-secrets set $Key $Value -p $ProjectPath 2>&1
                $exitCode = $LASTEXITCODE
                
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
            $errorDetails = @{
                Key        = $Key
                ExitCode   = $LASTEXITCODE
                Message    = $_.Exception.Message
                StackTrace = $_.ScriptStackTrace
            }
            
            Write-Error "Error setting user secret '$Key': $($_.Exception.Message)" -ErrorAction Stop
            throw
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
            Write-Error "Failed to determine API project path: $($_.Exception.Message)"
            throw
        }
    }
}

function Get-ProjectPath {
    <#
    .SYNOPSIS
        Constructs the cross-platform path to the AppHost project file.
    
    .DESCRIPTION
        Builds the absolute path to the eShopOrders.AppHost.csproj file
        relative to the script location. Uses Join-Path for cross-platform compatibility.
    
    .OUTPUTS
        System.String - The absolute path to the AppHost project file.
    
    .EXAMPLE
        Get-ProjectPath
        Returns: Z:\Logic\eShopOrders.AppHost\eShopOrders.AppHost.csproj
        
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
            $path = Join-Path -Path $path -ChildPath 'eShopOrders.AppHost'
            $path = Join-Path -Path $path -ChildPath 'eShopOrders.AppHost.csproj'
            
            # Normalize to absolute path
            $absolutePath = [System.IO.Path]::GetFullPath($path)
            Write-Verbose "Resolved AppHost project path: $absolutePath"
            
            return $absolutePath
        }
        catch {
            Write-Error "Failed to determine AppHost project path: $($_.Exception.Message)"
            throw
        }
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
        if ([string]::IsNullOrWhiteSpace($RegistryEndpoint)) {
            Write-Warning "Azure Container Registry endpoint not configured. Skipping ACR login."
            Write-Verbose "Set AZURE_CONTAINER_REGISTRY_ENDPOINT environment variable if ACR authentication is required."
            return
        }
        
        try {
            # Strip .azurecr.io suffix if present (az acr login expects just the registry name)
            $registryName = $RegistryEndpoint -replace '\.azurecr\.io$', ''
            
            Write-Information "Authenticating to Azure Container Registry: $RegistryEndpoint"
            Write-Verbose "Using registry name: $registryName"
            
            # Check if Azure CLI is available
            $azCommand = Get-Command -Name az -ErrorAction SilentlyContinue
            if (-not $azCommand) {
                Write-Warning "Azure CLI (az) not found in PATH. Skipping ACR authentication."
                Write-Information "  Install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
                Write-Verbose "Azure CLI is required for ACR authentication."
                return
            }
            
            Write-Verbose "Azure CLI found at: $($azCommand.Source)"
            
            # Check Azure CLI version
            try {
                $azVersion = & az version --output json 2>&1 | ConvertFrom-Json
                Write-Verbose "Azure CLI version: $($azVersion.'azure-cli')"
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

#endregion

#region Main Script Execution

try {
    # Start execution timer
    $executionStart = Get-Date
    
    # Script initialization
    Write-SectionHeader -Message "Post-Provisioning Script Started" -Type 'Main'
    Write-Information "Script Version: $script:ScriptVersion"
    Write-Information "Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Information "PowerShell Version: $($PSVersionTable.PSVersion)"
    Write-Information "Operating System: $($PSVersionTable.OS)"
    
    # Validate required environment variables
    Write-SectionHeader -Message "Validating Environment Variables" -Type 'Sub'
    
    $validationErrors = [System.Collections.Generic.List[string]]::new()
    
    foreach ($varName in $script:RequiredEnvironmentVariables) {
        if (-not (Test-RequiredEnvironmentVariable -Name $varName)) {
            $validationErrors.Add($varName)
        }
    }
    
    if ($validationErrors.Count -gt 0) {
        $errorMessage = "The following required environment variables are missing or empty:`n"
        $errorMessage += ($validationErrors | ForEach-Object { "  - $_" }) -join "`n"
        $errorMessage += "`n`nPlease ensure these environment variables are set before running this script."
        throw $errorMessage
    }
    
    Write-Information "✓ All $($script:RequiredEnvironmentVariables.Count) required environment variables are set."
    
    # Read environment variables with safe retrieval
    Write-Verbose "Reading environment variables..."
    $azureSubscriptionId = Get-EnvironmentVariableSafe -Name 'AZURE_SUBSCRIPTION_ID'
    $azureResourceGroup = Get-EnvironmentVariableSafe -Name 'AZURE_RESOURCE_GROUP'
    $azureLocation = Get-EnvironmentVariableSafe -Name 'AZURE_LOCATION'
    $azureApplicationInsightsName = Get-EnvironmentVariableSafe -Name 'AZURE_APPLICATION_INSIGHTS_NAME'
    $azureTenantId = Get-EnvironmentVariableSafe -Name 'AZURE_TENANT_ID'
    $azureClientId = Get-EnvironmentVariableSafe -Name 'AZURE_CLIENT_ID'
    $azureServiceBusNamespace = Get-EnvironmentVariableSafe -Name 'AZURE_SERVICE_BUS_NAMESPACE'
    $azureServiceBusQueueName = Get-EnvironmentVariableSafe -Name 'AZURE_SERVICE_BUS_QUEUE_NAME' -DefaultValue 'orders-queue'
    $azureMessagingServiceBusEndpoint = Get-EnvironmentVariableSafe -Name 'MESSAGING_SERVICEBUSENDPOINT'
    $azureEnvName = Get-EnvironmentVariableSafe -Name 'AZURE_ENV_NAME'
    $azureContainerRegistryEndpoint = Get-EnvironmentVariableSafe -Name 'AZURE_CONTAINER_REGISTRY_ENDPOINT'
    
    # Display configuration (with safe null handling)
    Write-SectionHeader -Message "Azure Configuration" -Type 'Sub'
    Write-Information "  Subscription ID        : $(if ($azureSubscriptionId) { $azureSubscriptionId } else { '<not set>' })"
    Write-Information "  Resource Group         : $(if ($azureResourceGroup) { $azureResourceGroup } else { '<not set>' })"
    Write-Information "  Location               : $(if ($azureLocation) { $azureLocation } else { '<not set>' })"
    Write-Information "  Environment Name       : $(if ($azureEnvName) { $azureEnvName } else { '<not set>' })"
    Write-Information "  Tenant ID              : $(if ($azureTenantId) { $azureTenantId } else { '<not set>' })"
    Write-Information "  Client ID              : $(if ($azureClientId) { $azureClientId } else { '<not set>' })"
    Write-Information "  App Insights Name      : $(if ($azureApplicationInsightsName) { $azureApplicationInsightsName } else { '<not set>' })"
    Write-Information "  Service Bus Namespace  : $(if ($azureServiceBusNamespace) { $azureServiceBusNamespace } else { '<not set>' })"
    Write-Information "  Service Bus Queue Name : $(if ($azureServiceBusQueueName) { $azureServiceBusQueueName } else { '<not set>' })"
    Write-Information "  Service Bus Endpoint   : $(if ($azureMessagingServiceBusEndpoint) { $azureMessagingServiceBusEndpoint } else { '<not set>' })"
    Write-Information "  ACR Endpoint           : $(if ($azureContainerRegistryEndpoint) { $azureContainerRegistryEndpoint } else { '<not set>' })"
    
    # Authenticate to Azure Container Registry (non-blocking)
    Invoke-AzureContainerRegistryLogin -RegistryEndpoint $azureContainerRegistryEndpoint
    
    # Verify prerequisites
    Write-SectionHeader -Message "Verifying Prerequisites" -Type 'Sub'
    
    # Check for .NET CLI
    $dotnetCommand = Get-Command -Name dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCommand) {
        $errorMessage = ".NET CLI (dotnet) not found in PATH.`n"
        $errorMessage += "Please install .NET SDK from: https://dotnet.microsoft.com/download`n"
        $errorMessage += "Required for managing user secrets."
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
        $errorMessage = "Error verifying .NET SDK: $($_.Exception.Message)`n"
        $errorMessage += "Please ensure .NET SDK is properly installed and accessible."
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
        $errorMessage = "API project file not found at: $projectPath`n"
        $errorMessage += "Please ensure the project structure is correct.`n"
        $errorMessage += "Expected location: <script-root>/../src/eShop.Orders.API/eShop.Orders.API.csproj"
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
            $errorMessage = "Error clearing user secrets: $($_.Exception.Message)`n"
            $errorMessage += "This may indicate the project doesn't have user secrets initialized."
            throw $errorMessage
        }
    }
    
    # Configure user secrets
    Write-SectionHeader -Message "Configuring User Secrets" -Type 'Sub'
    
    # Define secrets configuration using ordered hashtable for consistent output
    $secrets = [ordered]@{
        'Azure:ServiceBus:QueueName' = $azureServiceBusQueueName
    }
    
    Write-Information "Preparing to configure $($secrets.Count) user secret(s)..."
    
    # Track success and failures
    $successCount = 0
    $skippedCount = 0
    $failedSecrets = [System.Collections.Generic.List[PSCustomObject]]::new()
    
    # Set each secret with detailed tracking
    foreach ($key in $secrets.Keys) {
        try {
            $value = $secrets[$key]
            
            if ([string]::IsNullOrWhiteSpace($value)) {
                Write-Verbose "Skipping secret '$key' - value is null, empty, or whitespace"
                $skippedCount++
                continue
            }
            
            Write-Verbose "Processing secret: $key"
            Set-DotNetUserSecret -Key $key -Value $value -ProjectPath $projectPath
            $successCount++
            Write-Verbose "Successfully set secret: $key"
        }
        catch {
            Write-Warning "Failed to set secret '$key': $($_.Exception.Message)"
            $failedSecrets.Add([PSCustomObject]@{
                    Key     = $key
                    Message = $_.Exception.Message
                })
        }
    }
    
    # Report detailed results
    Write-SectionHeader -Message "Configuration Results" -Type 'Sub'
    Write-Information "User Secrets Configuration Summary:"
    Write-Information "  ✓ Successfully configured: $successCount / $($secrets.Count)"
    
    if ($skippedCount -gt 0) {
        Write-Information "  ⊘ Skipped (empty values): $skippedCount"
    }
    
    if ($failedSecrets.Count -gt 0) {
        Write-Warning "  ✗ Failed: $($failedSecrets.Count)"
        foreach ($failed in $failedSecrets) {
            Write-Warning "    - $($failed.Key): $($failed.Message)"
        }
        
        # Don't fail the entire script for partial failures if some secrets were set
        if ($successCount -eq 0) {
            throw "All user secrets failed to configure. Please review errors above."
        }
    }
    
    # Success summary
    Write-SectionHeader -Message "Post-Provisioning Completed Successfully!" -Type 'Main'
    Write-Information "Results:"
    Write-Information "  • Total secrets defined   : $($secrets.Count)"
    Write-Information "  • Successfully configured : $successCount"
    Write-Information "  • Skipped (empty)         : $skippedCount"
    Write-Information "  • Failed                  : $($failedSecrets.Count)"
    Write-Information ""
    Write-Information "Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Information "Duration: $((New-TimeSpan -Start $executionStart -End (Get-Date)).TotalSeconds) seconds"
    Write-Information ""
    
    exit 0
}
catch {
    # Comprehensive error reporting
    Write-SectionHeader -Message "Post-Provisioning Failed!" -Type 'Main'
    
    Write-Error "╔══════════════════════════════════════════════════════════════╗"
    Write-Error "║                   EXECUTION FAILED                           ║"
    Write-Error "╚══════════════════════════════════════════════════════════════╝"
    Write-Error ""
    Write-Error "Error Message:"
    Write-Error "  $($_.Exception.Message)"
    Write-Error ""
    Write-Error "Error Type: $($_.Exception.GetType().FullName)"
    
    # Position information
    if ($_.InvocationInfo) {
        Write-Error ""
        Write-Error "Location:"
        Write-Error "  Script: $($_.InvocationInfo.ScriptName)"
        Write-Error "  Line: $($_.InvocationInfo.ScriptLineNumber)"
        Write-Error "  Column: $($_.InvocationInfo.OffsetInLine)"
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
    
    # Reset progress preference
    $ProgressPreference = 'Continue'
    
    # Calculate total execution time if available
    if ($null -ne $executionStart) {
        $duration = (Get-Date) - $executionStart
        Write-Verbose "Total execution time: $($duration.TotalSeconds) seconds"
    }
    
    Write-Verbose "Script execution completed."
}

#endregion