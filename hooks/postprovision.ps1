#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Post-provisioning script for Azure Developer CLI (azd).

.DESCRIPTION
    Configures .NET user secrets with Azure resource information after provisioning.
    This script is automatically executed by azd after infrastructure provisioning completes.

.PARAMETER Force
    Skips confirmation prompts and forces execution.

.EXAMPLE
    .\postprovision.ps1
    Runs the post-provisioning script with default settings.

.EXAMPLE
    .\postprovision.ps1 -Verbose
    Runs the script with verbose output for debugging.

.NOTES
    File Name      : postprovision.ps1
    Prerequisite   : .NET SDK, Azure Developer CLI, Azure CLI
    Required Env   : AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, AZURE_LOCATION
    Author         : Azure DevOps Team
    Last Modified  : 2025-12-15
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'

#region Functions

function Test-RequiredEnvironmentVariable {
    <#
    .SYNOPSIS
        Validates that a required environment variable is set.
    
    .DESCRIPTION
        Checks if the specified environment variable exists and has a non-empty value.
    
    .PARAMETER Name
        The name of the environment variable to validate.
    
    .OUTPUTS
        System.Boolean
    
    .EXAMPLE
        Test-RequiredEnvironmentVariable -Name 'AZURE_SUBSCRIPTION_ID'
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )
    
    Write-Verbose "Validating environment variable: $Name"
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        Write-Warning "Required environment variable '$Name' is not set or is empty."
        return $false
    }
    
    Write-Verbose "Environment variable '$Name' is set."
    return $true
}

function Set-DotNetUserSecret {
    <#
    .SYNOPSIS
        Sets a .NET user secret with error handling.
    
    .DESCRIPTION
        Configures a user secret for a .NET project using the dotnet CLI.
        Skips empty values and provides detailed error reporting.
    
    .PARAMETER Key
        The secret key/name to set.
    
    .PARAMETER Value
        The secret value. Empty values are skipped.
    
    .PARAMETER ProjectPath
        The full path to the .csproj file.
    
    .EXAMPLE
        Set-DotNetUserSecret -Key 'ApiKey' -Value 'secret123' -ProjectPath 'C:\app\app.csproj'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Key,
        
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Value,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
        [string]$ProjectPath
    )
    
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-Verbose "Skipping secret '$Key' - value is empty or whitespace"
        return
    }
    
    try {
        Write-Verbose "Setting user secret: $Key"
        
        $output = & dotnet user-secrets set $Key $Value -p $ProjectPath 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $errorMessage = "Failed to set secret '$Key'. Exit code: $LASTEXITCODE"
            if ($output) {
                $errorMessage += "`nOutput: $output"
            }
            throw $errorMessage
        }
        
        Write-Verbose "Successfully set secret: $Key"
    }
    catch {
        Write-Error "Error setting user secret '$Key': $($_.Exception.Message)"
        throw
    }
}

function Get-ProjectPath {
    <#
    .SYNOPSIS
        Constructs the cross-platform path to the project file.
    
    .DESCRIPTION
        Builds the absolute path to the eShopOrders.AppHost.csproj file
        relative to the script location.
    
    .OUTPUTS
        System.String
    
    .EXAMPLE
        Get-ProjectPath
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    Write-Verbose "Determining project path..."
    
    $scriptRoot = $PSScriptRoot
    if ([string]::IsNullOrWhiteSpace($scriptRoot)) {
        $scriptRoot = Get-Location
        Write-Verbose "PSScriptRoot is empty, using current location: $scriptRoot"
    }
    
    # Build path using Join-Path for cross-platform compatibility
    $path = Join-Path -Path $scriptRoot -ChildPath '..'
    $path = Join-Path -Path $path -ChildPath 'eShopOrders.AppHost'
    $path = Join-Path -Path $path -ChildPath 'eShopOrders.AppHost.csproj'
    
    # Get absolute path
    $absolutePath = [System.IO.Path]::GetFullPath($path)
    Write-Verbose "Resolved project path: $absolutePath"
    
    return $absolutePath
}

function Invoke-AzureContainerRegistryLogin {
    <#
    .SYNOPSIS
        Authenticates to Azure Container Registry.
    
    .DESCRIPTION
        Logs into the Azure Container Registry using Azure CLI.
        Validates that the registry endpoint is configured before attempting login.
        Automatically strips .azurecr.io suffix if present.
    
    .PARAMETER RegistryEndpoint
        The Azure Container Registry endpoint name or FQDN (e.g., 'myregistry' or 'myregistry.azurecr.io').
    
    .PARAMETER ErrorAction
        Override the default error action preference for this function.
    
    .EXAMPLE
        Invoke-AzureContainerRegistryLogin -RegistryEndpoint 'myregistry'
    
    .EXAMPLE
        Invoke-AzureContainerRegistryLogin -RegistryEndpoint 'myregistry.azurecr.io'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$RegistryEndpoint
    )
    
    if ([string]::IsNullOrWhiteSpace($RegistryEndpoint)) {
        Write-Warning "Azure Container Registry endpoint not configured. Skipping ACR login."
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
            Write-Warning "Azure CLI not found. Skipping ACR authentication."
            Write-Information "  Install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
            return
        }
        
        Write-Verbose "Azure CLI found: $($azCommand.Source)"
        
        # Check if logged into Azure CLI
        $accountOutput = & az account show 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Not authenticated with Azure CLI. Skipping ACR authentication."
            Write-Information "  Run 'az login' to authenticate with Azure."
            Write-Verbose "az account show output: $accountOutput"
            return
        }
        
        Write-Verbose "Azure CLI authenticated successfully"
        
        # Perform ACR login with detailed error capture
        $acrLoginOutput = & az acr login --name $registryName 2>&1
        $acrLoginExitCode = $LASTEXITCODE
        
        if ($acrLoginExitCode -ne 0) {
            Write-Warning "Failed to login to Azure Container Registry '$registryName'."
            Write-Information "  This may not affect deployment if using managed identity."
            Write-Verbose "Exit code: $acrLoginExitCode"
            Write-Verbose "Output: $acrLoginOutput"
            return
        }
        
        Write-Information "✓ Successfully authenticated to Azure Container Registry."
    }
    catch {
        Write-Warning "Azure Container Registry login encountered an error: $($_.Exception.Message)"
        Write-Information "  Continuing with post-provisioning..."
        Write-Verbose "Stack trace: $($_.ScriptStackTrace)"
    }
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a formatted section header to the information stream.
    
    .PARAMETER Message
        The message to display in the header.
    
    .PARAMETER Type
        The type of header: 'Main', 'Sub', or 'Info'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Main', 'Sub', 'Info')]
        [string]$Type = 'Info'
    )
    
    switch ($Type) {
        'Main' {
            Write-Information ""
            Write-Information "═══════════════════════════════════════════════════════"
            Write-Information $Message
            Write-Information "═══════════════════════════════════════════════════════"
        }
        'Sub' {
            Write-Information ""
            Write-Information "───────────────────────────────────────────────────────"
            Write-Information $Message
            Write-Information "───────────────────────────────────────────────────────"
        }
        'Info' {
            Write-Information ""
            Write-Information $Message
        }
    }
}

#endregion

#region Main Script

try {
    Write-SectionHeader -Message "Post-Provisioning Script Started" -Type 'Main'
    Write-Information "Script Version: 1.0.0"
    Write-Information "Execution Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    
    # Validate required environment variables first
    Write-SectionHeader -Message "Validating Environment Variables" -Type 'Sub'
    
    $requiredVars = @(
        'AZURE_SUBSCRIPTION_ID',
        'AZURE_RESOURCE_GROUP',
        'AZURE_LOCATION'
    )
    
    $validationErrors = [System.Collections.Generic.List[string]]::new()
    
    foreach ($varName in $requiredVars) {
        if (-not (Test-RequiredEnvironmentVariable -Name $varName)) {
            $validationErrors.Add($varName)
        }
    }
    
    if ($validationErrors.Count -gt 0) {
        $errorMessage = "The following required environment variables are missing or empty:`n"
        $errorMessage += ($validationErrors | ForEach-Object { "  - $_" }) -join "`n"
        throw $errorMessage
    }
    
    Write-Information "✓ All required environment variables are set."
    
    # Read environment variables
    Write-Verbose "Reading environment variables..."
    $azureSubscriptionId = $env:AZURE_SUBSCRIPTION_ID
    $azureResourceGroup = $env:AZURE_RESOURCE_GROUP
    $azureLocation = $env:AZURE_LOCATION
    $azureApplicationInsightsName = $env:AZURE_APPLICATION_INSIGHTS_NAME
    $azureTenantId = $env:AZURE_TENANT_ID
    $azureClientId = $env:AZURE_CLIENT_ID
    $azureServiceBusNamespace = $env:AZURE_SERVICE_BUS_NAMESPACE
    $azureMessagingServiceBusEndpoint = $env:MESSAGING_SERVICEBUSENDPOINT
    $azureEnvName = $env:AZURE_ENV_NAME
    $azureContainerRegistryEndpoint = $env:AZURE_CONTAINER_REGISTRY_ENDPOINT
    
    # Display configuration
    Write-SectionHeader -Message "Azure Configuration" -Type 'Sub'
    Write-Information "  Subscription ID        : $azureSubscriptionId"
    Write-Information "  Resource Group         : $azureResourceGroup"
    Write-Information "  Location               : $azureLocation"
    Write-Information "  Environment Name       : $azureEnvName"
    Write-Information "  Tenant ID              : $azureTenantId"
    Write-Information "  Client ID              : $azureClientId"
    Write-Information "  App Insights Name      : $azureApplicationInsightsName"
    Write-Information "  Service Bus Namespace  : $azureServiceBusNamespace"
    Write-Information "  Service Bus Endpoint   : $azureMessagingServiceBusEndpoint"
    Write-Information "  ACR Endpoint           : $azureContainerRegistryEndpoint"
    
    # Authenticate to Azure Container Registry
    Invoke-AzureContainerRegistryLogin -RegistryEndpoint $azureContainerRegistryEndpoint
    
    # Verify dotnet CLI is available
    Write-SectionHeader -Message "Verifying Prerequisites" -Type 'Sub'
    
    $dotnetCommand = Get-Command -Name dotnet -ErrorAction SilentlyContinue
    if (-not $dotnetCommand) {
        throw ".NET CLI not found. Please install .NET SDK from https://dotnet.microsoft.com/download"
    }
    
    try {
        $dotnetVersion = & dotnet --version 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to get .NET version. Output: $dotnetVersion"
        }
        Write-Information "✓ .NET SDK Version: $dotnetVersion"
    }
    catch {
        throw "Error verifying .NET SDK: $($_.Exception.Message)"
    }
    
    # Get and verify project path
    $projectPath = Get-ProjectPath
    Write-Information "✓ Project Path: $projectPath"
    
    if (-not (Test-Path -Path $projectPath -PathType Leaf)) {
        throw "Project file not found at: $projectPath`nPlease ensure the project structure is correct."
    }
    
    Write-Information "✓ Project file verified."
    
    # Clear existing user secrets
    Write-SectionHeader -Message "Clearing Existing User Secrets" -Type 'Sub'
    
    try {
        $output = & dotnet user-secrets clear -p $projectPath 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to clear user secrets. Exit code: $LASTEXITCODE. Output: $output"
        }
        
        Write-Information "✓ User secrets cleared successfully."
    }
    catch {
        throw "Error clearing user secrets: $($_.Exception.Message)"
    }
    
    # Configure user secrets
    Write-SectionHeader -Message "Configuring User Secrets" -Type 'Sub'
    
    # Define secrets configuration using ordered hashtable for consistent output
    $secrets = [ordered]@{
        'Azure:AllowResourceGroupCreation'             = 'false'
        'Azure:SubscriptionId'                         = $azureSubscriptionId
        'AZURE_RESOURCE_GROUP'                         = $azureResourceGroup
        'Azure:Location'                               = $azureLocation
        'Azure:CredentialSource'                       = 'AzureDeveloperCli'
        'AZURE_CLIENT_ID'                              = $azureClientId
        'AZURE_APPLICATION_INSIGHTS_NAME'              = $azureApplicationInsightsName
        'AZURE_TENANT_ID'                              = $azureTenantId
        'AZURE_SERVICE_BUS_NAMESPACE'                  = $azureServiceBusNamespace
        'AZURE_MESSAGING_SERVICEBUSENDPOINT'            = $azureMessagingServiceBusEndpoint
        'AZURE_ENV_NAME'                               = $azureEnvName
    }
    
    # Track success and failures
    $successCount = 0
    $skippedCount = 0
    $failedSecrets = [System.Collections.Generic.List[string]]::new()
    
    # Set each secret
    foreach ($key in $secrets.Keys) {
        try {
            if ([string]::IsNullOrWhiteSpace($secrets[$key])) {
                Write-Verbose "Skipping secret '$key' - value is empty"
                $skippedCount++
                continue
            }
            
            Set-DotNetUserSecret -Key $key -Value $secrets[$key] -ProjectPath $projectPath
            $successCount++
        }
        catch {
            Write-Warning "Failed to set secret '$key': $($_.Exception.Message)"
            $failedSecrets.Add($key)
        }
    }
    
    # Report results
    Write-Information ""
    Write-Information "User Secrets Configuration Summary:"
    Write-Information "  ✓ Successfully configured: $successCount"
    if ($skippedCount -gt 0) {
        Write-Information "  ⊘ Skipped (empty values): $skippedCount"
    }
    if ($failedSecrets.Count -gt 0) {
        Write-Warning "  ✗ Failed: $($failedSecrets.Count)"
        Write-Warning "  Failed secrets: $($failedSecrets -join ', ')"
    }
    
    Write-SectionHeader -Message "Post-Provisioning Completed Successfully!" -Type 'Main'
    Write-Information "Total secrets processed: $($secrets.Count)"
    Write-Information "Completion Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Information ""
    
    exit 0
}
catch {
    Write-SectionHeader -Message "Post-Provisioning Failed!" -Type 'Main'
    Write-Error "An error occurred during post-provisioning:"
    Write-Error "Error Message: $($_.Exception.Message)"
    Write-Error "Error Type: $($_.Exception.GetType().FullName)"
    
    if ($_.ScriptStackTrace) {
        Write-Verbose "Stack Trace: $($_.ScriptStackTrace)"
    }
    
    Write-Information ""
    Write-Information "Troubleshooting tips:"
    Write-Information "  1. Verify all required environment variables are set correctly"
    Write-Information "  2. Ensure .NET SDK is installed and accessible"
    Write-Information "  3. Check Azure CLI authentication status: az account show"
    Write-Information "  4. Review the error message above for specific details"
    Write-Information "  5. Run with -Verbose flag for detailed diagnostic information"
    Write-Information ""
    
    exit 1
}
finally {
    # Reset progress preference
    $ProgressPreference = 'Continue'
}

#endregion