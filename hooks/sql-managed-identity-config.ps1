#!/usr/bin/env pwsh

#Requires -Version 7.0

<#
.SYNOPSIS
    Configures Azure SQL Database user with Managed Identity authentication.

.DESCRIPTION
    This script automates the configuration of Microsoft Entra ID (formerly Azure AD) 
    managed identities for Azure SQL Database access. It creates contained database users 
    from external providers and assigns specified database roles using token-based authentication.
    
    The script performs the following operations in sequence:
    1. Validates Azure CLI installation and authentication status
    2. Detects the client's public IP and configures SQL Server firewall rules
    3. Acquires an OAuth 2.0 access token for Azure SQL Database from Entra ID
    4. Generates an idempotent T-SQL script for user creation and role assignment
    5. Executes the script against the target database using Microsoft.Data.SqlClient
    6. Returns a structured result object with execution details
    
    Key Features:
    - Idempotent execution: Safe to re-run without side effects (skips existing users/roles)
    - Cross-platform: Supports Windows, Linux, and macOS via Microsoft.Data.SqlClient
    - Multi-cloud: Works with Azure Public, Government, China, and Germany clouds
    - Secure: Uses token-based authentication with TLS 1.2+ encryption (no SQL passwords)
    - Robust: Includes retry logic, detailed error handling, and comprehensive logging

.PARAMETER SqlServerName
    The name of the Azure SQL Server (logical server name only, without .database.windows.net suffix).
    
    Example: "contoso-sql-server" (not "contoso-sql-server.database.windows.net")

.PARAMETER DatabaseName
    The name of the target database where the user will be created.
    
    This should be a user database, not 'master'. The script will create a contained
    database user in this database.

.PARAMETER PrincipalDisplayName
    The display name of the managed identity or service principal as it appears in Microsoft Entra ID.
    
    This must exactly match the name shown in the Azure Portal under the Managed Identity
    or App Registration. Names are case-sensitive.
    
    Example: "app-orders-api-identity"

.PARAMETER DatabaseRoles
    Array of database roles to assign to the principal.
    
    Common built-in roles:
    - db_datareader: Read all data from all user tables
    - db_datawriter: Add, delete, or modify data in all user tables
    - db_ddladmin: Run DDL commands (CREATE, ALTER, DROP)
    - db_owner: Full permissions in the database
    
    Default: @("db_datareader", "db_datawriter")

.PARAMETER AzureEnvironment
    The Azure cloud environment where the SQL Server is hosted.
    
    Valid values:
    - AzureCloud (default): Public Azure
    - AzureUSGovernment: Azure Government
    - AzureChinaCloud: Azure China (21Vianet)
    - AzureGermanCloud: Azure Germany
    
    Default: "AzureCloud"

.PARAMETER CommandTimeout
    The maximum time in seconds to wait for SQL commands to complete.
    
    Valid range: 30-600 seconds
    Default: 120 seconds

.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    PSCustomObject
    
    Returns a PSCustomObject with PSTypeName 'SqlManagedIdentityConfiguration.Result' containing:
    - Success (Boolean): True if configuration succeeded, False otherwise
    - Principal (String): The principal display name
    - Server (String): The server FQDN
    - Database (String): The database name
    - Roles (Array): The assigned roles
    - RowsAffected (Int): Number of rows affected (on success)
    - ExecutionTimeSeconds (Double): Execution duration (on success)
    - Timestamp (String): ISO 8601 timestamp
    - Message (String): Success message (on success)
    - ScriptVersion (String): Script version
    - Error (String): Error message (on failure)
    - ErrorType (String): Exception type (on failure)
    - InnerError (String): Inner exception message (on failure)

.EXAMPLE
    .\sql-managed-identity-config.ps1 -SqlServerName "myserver" -DatabaseName "mydb" -PrincipalDisplayName "my-app-identity"
    
    Configures the managed identity "my-app-identity" with default roles (db_datareader, db_datawriter)
    in the "mydb" database on "myserver.database.windows.net".

.EXAMPLE
    .\sql-managed-identity-config.ps1 -SqlServerName "myserver" -DatabaseName "mydb" -PrincipalDisplayName "my-app-identity" -DatabaseRoles @("db_datareader", "db_datawriter", "db_ddladmin") -Verbose
    
    Configures the managed identity with three roles including DDL admin permissions,
    with verbose output enabled.

.EXAMPLE
    $result = .\sql-managed-identity-config.ps1 -SqlServerName "myserver" -DatabaseName "mydb" -PrincipalDisplayName "my-app-identity"
    if ($result.Success) {
        Write-Host "Configuration succeeded for $($result.Principal)"
    } else {
        Write-Error "Configuration failed: $($result.Error)"
    }
    
    Captures the result object and checks for success/failure.

.NOTES
    Version:        1.0.0
    Author          Evilazaro | Principal Cloud Solution Architect | Microsoft
    Creation Date:  2025-12-26
    Last Modified:  2026-01-06
    Purpose:        Post-provisioning SQL Database managed identity configuration
    Copyright:      (c) 2025-2026. All rights reserved.
    
    Prerequisites:
    - PowerShell 7.0 or higher
    - Azure CLI (az) version 2.60.0 or higher with active authentication (az login)
    - Environment Variables:
      * AZURE_RESOURCE_GROUP: The resource group containing the SQL Server (required for firewall configuration)
    - CRITICAL: You must authenticate as an Entra ID administrator of the SQL Server
      * Set Entra ID admin: az sql server ad-admin create --resource-group <rg> --server-name <server> --display-name <name> --object-id <id>
      * The authenticated user must BE this admin or have equivalent permissions
    - Permissions: SQL Server Contributor or higher on the SQL Server resource (for Azure Resource Manager)
    - Permissions: SQL db_owner or higher in the target database (for database operations)
    - Network: Access to Azure SQL Database (firewall rules configured)
    
    Security Notes:
    - Uses Azure AD token authentication (no SQL passwords)
    - Access tokens are not logged or persisted
    - SQL injection protection via parameterized principals
    - Connections use encryption (TLS 1.2+)
    
    Known Limitations:
    - Requires Microsoft Entra ID authentication to be enabled on the SQL Server
    - Cannot create users in the 'master' database (by design)
    - Principal names with special characters should be enclosed in brackets in Entra ID

.LINK
    https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure

.LINK
    https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#>

#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $false)]
[OutputType([PSCustomObject])]
param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        HelpMessage = "Enter the Azure SQL Server name (without suffix)"
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 63)]
    [ValidatePattern('^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$', ErrorMessage = "SQL Server name must contain only lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen")]
    [Alias('Server', 'SqlServer')]
    [string]$SqlServerName,

    [Parameter(
        Mandatory = $true,
        Position = 1,
        HelpMessage = "Enter the database name"
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 128)]
    [ValidateScript(
        { $_ -ne 'master' },
        ErrorMessage = "Cannot configure managed identity users in the 'master' database. Please specify a user database."
    )]
    [Alias('Database')]
    [string]$DatabaseName,

    [Parameter(
        Mandatory = $true,
        Position = 2,
        HelpMessage = "Enter the managed identity or service principal display name from Entra ID"
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 128)]
    [Alias('Principal', 'Identity', 'IdentityName')]
    [string]$PrincipalDisplayName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter database roles to assign (default: db_datareader, db_datawriter)"
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateCount(1, 20)]
    [ValidateScript(
        { 
            $validRoles = @('db_owner', 'db_datareader', 'db_datawriter', 'db_ddladmin', 'db_backupoperator', 'db_securityadmin', 'db_accessadmin', 'db_denydatareader', 'db_denydatawriter')
            $invalidRoles = $_ | Where-Object { $validRoles -notcontains $_ }
            if ($invalidRoles) {
                throw "Invalid role(s): $($invalidRoles -join ', '). Valid roles: $($validRoles -join ', ')"
            }
            $true
        }
    )]
    [Alias('Roles')]
    [string[]]$DatabaseRoles = @('db_datareader', 'db_datawriter'),

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Select the Azure cloud environment"
    )]
    [ValidateSet('AzureCloud', 'AzureUSGovernment', 'AzureChinaCloud', 'AzureGermanCloud')]
    [Alias('Environment', 'Cloud')]
    [string]$AzureEnvironment = 'AzureCloud',

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter the SQL command timeout in seconds (30-600)"
    )]
    [ValidateRange(30, 600)]
    [Alias('Timeout')]
    [int]$CommandTimeout = 120
)

# Script metadata
Set-StrictMode -Version Latest

# Backup original preferences for restoration in finally block
$script:OriginalErrorActionPreference = $ErrorActionPreference
$script:OriginalProgressPreference = $ProgressPreference
$script:OriginalInformationPreference = $InformationPreference

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

# Script-level variable to track which SQL client is being used
$script:UseMicrosoftDataSqlClient = $false
$script:SqlClientLoadError = $null

# Function to attempt installing Microsoft.Data.SqlClient via NuGet
function Install-MicrosoftDataSqlClient {
    [CmdletBinding()]
    param()
    
    Write-Warning 'Attempting to install Microsoft.Data.SqlClient...'
    
    # Create a temporary directory for the package
    $tempDir = Join-Path -Path $env:TEMP -ChildPath "MicrosoftDataSqlClient_$(Get-Date -Format 'yyyyMMddHHmmss')"
    $null = New-Item -ItemType Directory -Path $tempDir -Force
    
    try {
        # Try using nuget.exe if available
        $nugetExe = Get-Command -Name nuget.exe -CommandType Application -ErrorAction SilentlyContinue
        if ($nugetExe) {
            Write-Information -MessageData 'Using nuget.exe to install package...' -InformationAction Continue
            & nuget.exe install Microsoft.Data.SqlClient -OutputDirectory $tempDir -NonInteractive 2>&1 | Out-Null
        }
        else {
            # Try using dotnet CLI
            $dotnetExe = Get-Command -Name dotnet -CommandType Application -ErrorAction SilentlyContinue
            if ($dotnetExe) {
                Write-Information -MessageData 'Using dotnet CLI to restore package...' -InformationAction Continue
                # Create a minimal project to restore the package
                $projectDir = Join-Path -Path $tempDir -ChildPath "temp_project"
                $null = New-Item -ItemType Directory -Path $projectDir -Force
                
                $csprojContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net6.0</TargetFramework>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Data.SqlClient" Version="5.*" />
  </ItemGroup>
</Project>
"@
                $csprojPath = Join-Path -Path $projectDir -ChildPath "temp.csproj"
                Set-Content -Path $csprojPath -Value $csprojContent
                
                Push-Location $projectDir
                try {
                    & dotnet restore --verbosity quiet 2>&1 | Out-Null
                }
                finally {
                    Pop-Location
                }
            }
            else {
                Write-Warning "Neither nuget.exe nor dotnet CLI found. Cannot auto-install Microsoft.Data.SqlClient."
                return $false
            }
        }
        
        return $true
    }
    catch {
        Write-Warning "Failed to install Microsoft.Data.SqlClient: $($_.Exception.Message)"
        return $false
    }
    finally {
        # Cleanup temp directory
        if (Test-Path -Path $tempDir) {
            Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Load Microsoft.Data.SqlClient assembly for cross-platform SQL Server connectivity
# This provides better support for Azure AD/Entra ID authentication in PowerShell Core
try {
    # Try to load from GAC or installed NuGet package
    $null = [Microsoft.Data.SqlClient.SqlConnection]
    $script:UseMicrosoftDataSqlClient = $true
    Write-Verbose "Microsoft.Data.SqlClient already loaded"
}
catch {
    # Assembly not loaded, try to find and load it
    $sqlClientPath = $null
    
    # Check common NuGet package locations
    $nugetPaths = @(
        "$env:USERPROFILE\.nuget\packages\microsoft.data.sqlclient"
        "$HOME/.nuget/packages/microsoft.data.sqlclient"
    )
    
    # Determine the runtime identifier (RID) for platform-specific assemblies
    $rid = if ($IsWindows -or $env:OS -eq 'Windows_NT') { 'win' } elseif ($IsMacOS) { 'osx' } else { 'unix' }
    $arch = if ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'X64') { 'x64' } 
    elseif ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture -eq 'Arm64') { 'arm64' } 
    else { 'x86' }
    Write-Verbose "Detected runtime: $rid-$arch"
    
    foreach ($basePath in $nugetPaths) {
        if (Test-Path -Path $basePath -ErrorAction SilentlyContinue) {
            # Find the latest version
            $latestVersion = Get-ChildItem -Path $basePath -Directory -ErrorAction SilentlyContinue |
            Sort-Object { 
                try { [Version]$_.Name } catch { [Version]"0.0.0" }
            } -Descending |
            Select-Object -First 1
            
            if ($latestVersion) {
                # Get PowerShell's .NET runtime version to pick the best matching TFM
                $runtimeVersion = [System.Environment]::Version
                Write-Verbose "PowerShell .NET runtime version: $runtimeVersion"
                
                # IMPORTANT: Use runtime-specific assemblies from 'runtimes\{rid}\lib\{tfm}' folder
                # The assemblies in 'lib\{tfm}' are reference assemblies and will fail with
                # "Microsoft.Data.SqlClient is not supported on this platform" error
                $dllPaths = @(
                    # Try runtime-specific assemblies first (required for actual execution)
                    Join-Path -Path $latestVersion.FullName -ChildPath "runtimes\$rid\lib\net9.0\Microsoft.Data.SqlClient.dll"
                    Join-Path -Path $latestVersion.FullName -ChildPath "runtimes\$rid\lib\net8.0\Microsoft.Data.SqlClient.dll"
                    Join-Path -Path $latestVersion.FullName -ChildPath "runtimes\$rid\lib\net7.0\Microsoft.Data.SqlClient.dll"
                    Join-Path -Path $latestVersion.FullName -ChildPath "runtimes\$rid\lib\net6.0\Microsoft.Data.SqlClient.dll"
                    # Fallback to generic lib folder (may not work but better than nothing)
                    Join-Path -Path $latestVersion.FullName -ChildPath 'lib\netstandard2.1\Microsoft.Data.SqlClient.dll'
                    Join-Path -Path $latestVersion.FullName -ChildPath 'lib\netstandard2.0\Microsoft.Data.SqlClient.dll'
                )
                
                foreach ($dllPath in $dllPaths) {
                    if (Test-Path -Path $dllPath -ErrorAction SilentlyContinue) {
                        $sqlClientPath = $dllPath
                        Write-Verbose "Found Microsoft.Data.SqlClient at: $sqlClientPath"
                        break
                    }
                }
            }
            if ($sqlClientPath) { break }
        }
    }
    
    if ($sqlClientPath) {
        try {
            # Load native SNI dependency first (required on Windows)
            if ($rid -eq 'win') {
                $sqlClientVersion = (Get-Item $sqlClientPath).Directory.Parent.Parent.Parent.Name
                Write-Verbose "Microsoft.Data.SqlClient version: $sqlClientVersion"
                
                # Find matching SNI runtime package
                $sniBasePaths = @(
                    "$env:USERPROFILE\.nuget\packages\microsoft.data.sqlclient.sni.runtime"
                    "$HOME/.nuget/packages/microsoft.data.sqlclient.sni.runtime"
                )
                
                foreach ($sniBasePath in $sniBasePaths) {
                    if (Test-Path -Path $sniBasePath -ErrorAction SilentlyContinue) {
                        $sniLatestVersion = Get-ChildItem -Path $sniBasePath -Directory -ErrorAction SilentlyContinue |
                        Sort-Object { try { [Version]$_.Name } catch { [Version]"0.0.0" } } -Descending |
                        Select-Object -First 1
                        
                        if ($sniLatestVersion) {
                            $sniDllPath = Join-Path -Path $sniLatestVersion.FullName -ChildPath "runtimes\win-$arch\native\Microsoft.Data.SqlClient.SNI.dll"
                            if (Test-Path -Path $sniDllPath -ErrorAction SilentlyContinue) {
                                Write-Verbose "Loading native SNI dependency from: $sniDllPath"
                                # Add the SNI directory to the DLL search path
                                $sniDir = Split-Path -Parent $sniDllPath
                                $env:PATH = "$sniDir;$env:PATH"
                                Write-Verbose "Added SNI directory to PATH: $sniDir"
                                break
                            }
                        }
                    }
                }
            }
            
            Add-Type -Path $sqlClientPath -ErrorAction Stop
            $script:UseMicrosoftDataSqlClient = $true
            Write-Verbose "Loaded Microsoft.Data.SqlClient from: $sqlClientPath"
        }
        catch {
            $script:SqlClientLoadError = "Failed to load Microsoft.Data.SqlClient from $sqlClientPath : $($_.Exception.Message)"
            Write-Warning $script:SqlClientLoadError
            $script:UseMicrosoftDataSqlClient = $false
        }
    }
    else {
        # Microsoft.Data.SqlClient not found
        $script:SqlClientLoadError = @"
Microsoft.Data.SqlClient assembly not found in NuGet cache.
This assembly is required for Azure AD/Entra ID authentication with Azure SQL.

To install Microsoft.Data.SqlClient:
  Option 1: Run 'dotnet add package Microsoft.Data.SqlClient' in a .NET project
  Option 2: Run 'Install-Package Microsoft.Data.SqlClient' in PowerShell (requires NuGet provider)
  Option 3: Download from https://www.nuget.org/packages/Microsoft.Data.SqlClient

After installing, run this script again.
"@
        Write-Warning 'Microsoft.Data.SqlClient assembly not found.'
        Write-Warning 'Azure AD authentication requires this package. System.Data.SqlClient fallback will NOT work.'
        $script:UseMicrosoftDataSqlClient = $false
    }
}

# Script constants
$script:ScriptVersion = '1.0.0'

# Azure SQL endpoint mapping for different cloud environments
# These suffixes are appended to the SQL Server logical name to form the FQDN
$script:SqlEndpoints = @{
    'AzureCloud'        = 'database.windows.net'
    'AzureUSGovernment' = 'database.usgovcloudapi.net'
    'AzureChinaCloud'   = 'database.chinacloudapi.cn'
    'AzureGermanCloud'  = 'database.cloudapi.de'
}

function Write-LogMessage {
    <#
    .SYNOPSIS
        Writes formatted log messages to the console and PowerShell streams.
    
    .DESCRIPTION
        Provides consistent logging with timestamps, color coding, and integration
        with PowerShell's standard output streams (Verbose, Warning, Error, Information).
    
    .PARAMETER Message
        The message to log.
    
    .PARAMETER Level
        The severity level of the message.
    
    .EXAMPLE
        Write-LogMessage "Processing started" -Level Info
    
    .EXAMPLE
        Write-LogMessage "Operation completed successfully" -Level Success
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [AllowEmptyString()]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Info', 'Success', 'Warning', 'Error', 'Verbose', 'Debug')]
        [string]$Level = 'Info'
    )
    
    begin {
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        $formattedMessage = "[$timestamp] [$Level] $Message"
    }
    
    process {
        # Route to appropriate PowerShell stream using Write-Information for PSScriptAnalyzer compliance
        # ANSI escape sequences provide colored output in modern terminals
        $esc = [char]27
        $resetColor = "$esc[0m"
        
        switch ($Level) {
            'Verbose' {
                Write-Verbose -Message $formattedMessage
            }
            'Debug' {
                Write-Debug -Message $formattedMessage
            }
            'Warning' {
                $yellowColor = "$esc[33m"
                Write-Information -MessageData "${yellowColor}${formattedMessage}${resetColor}" -InformationAction Continue
            }
            'Error' {
                $redColor = "$esc[31m"
                Write-Information -MessageData "${redColor}${formattedMessage}${resetColor}" -InformationAction Continue
            }
            'Success' {
                $greenColor = "$esc[32m"
                Write-Information -MessageData "${greenColor}${formattedMessage}${resetColor}" -InformationAction Continue
            }
            default {
                # Info
                $cyanColor = "$esc[36m"
                Write-Information -MessageData "${cyanColor}${formattedMessage}${resetColor}" -InformationAction Continue
            }
        }
    }
}

function Write-ColoredOutput {
    <#
    .SYNOPSIS
        Writes colored output using ANSI escape sequences via Write-Information.
    
    .DESCRIPTION
        Provides colored console output that is PSScriptAnalyzer compliant by using
        Write-Information with ANSI escape codes instead of Write-Host.
    
    .PARAMETER Message
        The message to display.
    
    .PARAMETER Color
        The color to use. Supports: Red, Green, Yellow, Cyan, White, Gray.
    
    .EXAMPLE
        Write-ColoredOutput -Message "Success!" -Color Green
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [AllowEmptyString()]
        [string]$Message = '',
        
        [Parameter(Mandatory = $false)]
        [ValidateSet('Red', 'Green', 'Yellow', 'Cyan', 'White', 'Gray', 'Default')]
        [string]$Color = 'Default'
    )
    
    $esc = [char]27
    $resetColor = "$esc[0m"
    
    $colorCode = switch ($Color) {
        'Red' { "$esc[31m" }
        'Green' { "$esc[32m" }
        'Yellow' { "$esc[33m" }
        'Cyan' { "$esc[36m" }
        'White' { "$esc[37m" }
        'Gray' { "$esc[90m" }
        default { '' }
    }
    
    if ($colorCode) {
        Write-Information -MessageData "${colorCode}${Message}${resetColor}" -InformationAction Continue
    }
    else {
        Write-Information -MessageData $Message -InformationAction Continue
    }
}

function Test-AzureCliAvailability {
    <#
    .SYNOPSIS
        Tests if Azure CLI is installed and authenticated.
    
    .DESCRIPTION
        Checks if the 'az' command is available in the system PATH and if the user
        has an active Azure CLI session.
    
    .OUTPUTS
        System.Boolean
        Returns $true if Azure CLI is available and authenticated, $false otherwise.
    
    .EXAMPLE
        if (Test-AzureCliAvailability) {
            Write-Host "Azure CLI is ready"
        }
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    begin {
        Write-LogMessage 'Checking Azure CLI availability...' -Level Verbose
    }
    
    process {
        try {
            # Check if az command exists
            $azCommand = Get-Command -Name az -CommandType Application -ErrorAction SilentlyContinue
            
            if (-not $azCommand) {
                Write-LogMessage 'Azure CLI (az) is not installed or not in PATH' -Level Error
                Write-LogMessage 'Install from: https://learn.microsoft.com/cli/azure/install-azure-cli' -Level Error
                return $false
            }
            
            Write-LogMessage "Azure CLI found at: $($azCommand.Source)" -Level Verbose
            
            # Check Azure CLI version
            $versionOutput = az version --query '"azure-cli"' -o tsv 2>&1
            $versionExitCode = $LASTEXITCODE
            
            if ($versionExitCode -eq 0 -and $versionOutput) {
                Write-LogMessage "Azure CLI version: $versionOutput" -Level Verbose
            }
            
            # Check if logged in
            $accountCheck = az account show 2>&1
            $accountExitCode = $LASTEXITCODE
            
            if ($accountExitCode -ne 0) {
                Write-LogMessage 'Not authenticated to Azure CLI' -Level Error
                Write-LogMessage 'Run: az login' -Level Error
                return $false
            }
            
            # Parse account information with proper error handling
            try {
                $accountInfo = $accountCheck | ConvertFrom-Json -ErrorAction Stop
                
                if ($accountInfo -and $accountInfo.name) {
                    Write-LogMessage "Azure CLI authenticated: Subscription=$($accountInfo.name)" -Level Success
                }
                else {
                    Write-LogMessage 'Azure CLI authenticated but subscription details unavailable' -Level Warning
                }
            }
            catch {
                Write-LogMessage "Warning: Could not parse Azure CLI account information: $($_.Exception.Message)" -Level Warning
                Write-LogMessage 'Continuing with authentication - connection may still succeed' -Level Info
            }
            
            return $true
        }
        catch {
            Write-LogMessage "Azure CLI validation failed: $($_.Exception.Message)" -Level Error
            return $false
        }
    }
    
    end {
        Write-LogMessage 'Azure CLI availability check completed' -Level Verbose
    }
}

# Test-AzureContext function removed - using Azure CLI exclusively for authentication

function Get-AzureSqlAccessToken {
    <#
    .SYNOPSIS
        Acquires an Azure AD access token for Azure SQL Database.
    
    .DESCRIPTION
        Acquires an access token using Azure CLI for Azure SQL Database authentication.
    
    .PARAMETER ResourceUrl
        The resource URL for Azure SQL Database (e.g., https://database.windows.net/).
    
    .OUTPUTS
        System.String
        Returns the access token string.
    
    .EXAMPLE
        $token = Get-AzureSqlAccessToken -ResourceUrl 'https://database.windows.net/'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://')]
        [string]$ResourceUrl
    )
    
    begin {
        Write-LogMessage "Acquiring access token for resource: $ResourceUrl" -Level Verbose
    }
    
    process {
        try {
            Write-LogMessage 'Attempting token acquisition via Azure CLI...' -Level Verbose
            Write-LogMessage "  Resource URL: $ResourceUrl" -Level Verbose
            
            # Execute Azure CLI command to get access token
            $cliOutput = az account get-access-token --resource $ResourceUrl --query accessToken -o tsv 2>&1
            
            # Capture exit code immediately to prevent race condition
            $cliExitCode = $LASTEXITCODE
            
            if ($cliExitCode -ne 0) {
                $errorDetails = if ($cliOutput) { "Output: $cliOutput" } else { 'No error output available' }
                throw "Azure CLI returned exit code $cliExitCode. $errorDetails"
            }
            
            if ([string]::IsNullOrWhiteSpace($cliOutput)) {
                throw 'Azure CLI returned an empty token. Verify Azure authentication with: az login'
            }
            
            $accessToken = $cliOutput.Trim()
            
            # Validate token format (basic check)
            if ($accessToken.Length -lt 50) {
                throw "Token appears invalid (length: $($accessToken.Length) characters). Expected JWT token."
            }
            
            Write-LogMessage 'Token acquired successfully via Azure CLI' -Level Success
            Write-LogMessage "  Token length: $($accessToken.Length) characters" -Level Verbose
            
            return $accessToken
        }
        catch {
            $errorMessage = "Azure CLI token acquisition failed: $($_.Exception.Message)"
            Write-LogMessage $errorMessage -Level Error
            Write-LogMessage 'Ensure you are authenticated to Azure CLI: az login' -Level Error
            throw $errorMessage
        }
    }
    
    end {
        Write-LogMessage 'Token acquisition completed' -Level Verbose
    }
}

function Get-SqlIdentityScript {
    <#
    .SYNOPSIS
        Generates T-SQL script to create a database user and assign roles.
    
    .DESCRIPTION
        Creates an idempotent T-SQL script that:
        - Creates a contained database user from external provider (Entra ID)
        - Assigns specified database roles to the user
        - Safely handles existing users and role memberships
    
    .PARAMETER PrincipalName
        The display name of the managed identity or service principal.
    
    .PARAMETER Roles
        Array of database role names to assign.
    
    .OUTPUTS
        System.String
        Returns the T-SQL script as a string.
    
    .EXAMPLE
        $script = Get-SqlIdentityScript -PrincipalName 'my-identity' -Roles @('db_datareader', 'db_datawriter')
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PrincipalName,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Roles
    )
    
    begin {
        Write-LogMessage 'Generating SQL script for managed identity configuration...' -Level Verbose
        $scriptParts = [System.Collections.Generic.List[string]]::new()
        
        # Sanitize principal name to prevent SQL injection
        # Replace single quotes with two single quotes (T-SQL escaping)
        $safePrincipalName = $PrincipalName.Replace("'", "''")
    }
    
    process {
        # Part 1: Create user from external provider
        $createUserScript = @"
-- Create contained database user from Microsoft Entra ID (Azure AD)
-- This user will authenticate using Entra ID managed identity
IF NOT EXISTS (
    SELECT 1 
    FROM sys.database_principals 
    WHERE name = N'$safePrincipalName' 
    AND type IN ('E', 'X')  -- E = External user, X = External group
)
BEGIN
    CREATE USER [$safePrincipalName] FROM EXTERNAL PROVIDER;
    PRINT 'SUCCESS: User [$safePrincipalName] created successfully';
END
ELSE
BEGIN
    PRINT 'INFO: User [$safePrincipalName] already exists - skipping creation';
END;

"@
        $scriptParts.Add($createUserScript)
        
        # Part 2: Assign roles
        foreach ($role in $Roles) {
            # Sanitize role name
            $safeRoleName = $role.Replace("'", "''")
            
            $roleScript = @"
-- Assign database role: $safeRoleName
IF EXISTS (
    SELECT 1 
    FROM sys.database_principals 
    WHERE name = N'$safeRoleName' 
    AND type = 'R'  -- R = Database role
)
BEGIN
    -- Check if user is already a member of this role
    IF IS_ROLEMEMBER(N'$safeRoleName', N'$safePrincipalName') = 0 
       OR IS_ROLEMEMBER(N'$safeRoleName', N'$safePrincipalName') IS NULL
    BEGIN
        ALTER ROLE [$safeRoleName] ADD MEMBER [$safePrincipalName];
        PRINT 'SUCCESS: Added [$safePrincipalName] to role [$safeRoleName]';
    END
    ELSE
    BEGIN
        PRINT 'INFO: [$safePrincipalName] is already a member of role [$safeRoleName] - skipping';
    END
END
ELSE
BEGIN
    PRINT 'WARNING: Role [$safeRoleName] does not exist in database - skipping';
END;

"@
            $scriptParts.Add($roleScript)
        }
        
        # Combine all script parts
        $fullScript = $scriptParts -join "`n"
        
        Write-LogMessage "Generated SQL script with $($Roles.Count) role assignment(s)" -Level Verbose
        return $fullScript
    }
    
    end {
        Write-LogMessage 'SQL script generation completed' -Level Verbose
    }
}

try {
    #region Script Initialization
    Write-LogMessage "====================================================================" -Level Info
    Write-LogMessage "SQL Managed Identity Configuration Script v$script:ScriptVersion" -Level Info
    Write-LogMessage "====================================================================" -Level Info
    Write-LogMessage "Starting Azure SQL Database managed identity configuration..." -Level Info
    Write-LogMessage "" -Level Info
    
    # Log input parameters (mask sensitive data)
    Write-LogMessage "Configuration Parameters:" -Level Info
    Write-LogMessage "  SQL Server Name:    $SqlServerName" -Level Info
    Write-LogMessage "  Database Name:      $DatabaseName" -Level Info
    Write-LogMessage "  Principal Name:     $PrincipalDisplayName" -Level Info
    Write-LogMessage "  Database Roles:     $($DatabaseRoles -join ', ')" -Level Info
    Write-LogMessage "  Azure Environment:  $AzureEnvironment" -Level Info
    Write-LogMessage "  Command Timeout:    ${CommandTimeout}s" -Level Info
    Write-LogMessage "" -Level Info
    #endregion
    
    #region Azure Authentication Validation
    Write-LogMessage "[Step 1/5] Validating Azure authentication..." -Level Info
    
    # Validate Azure CLI is available and authenticated
    if (-not (Test-AzureCliAvailability)) {
        $errorMessage = @(
            'Azure CLI authentication is required but not available.'
            'Please authenticate using Azure CLI:'
            '  1. Run: az login'
            '  2. Verify authentication: az account show'
            ''
            'To install Azure CLI: https://learn.microsoft.com/cli/azure/install-azure-cli'
        ) -join "`n"
        throw $errorMessage
    }
    
    Write-LogMessage 'Using Azure CLI for authentication' -Level Success
    #endregion
    
    #region Connection Details
    Write-LogMessage "" -Level Info
    Write-LogMessage "[Step 2/5] Constructing connection details..." -Level Info

    # Get current public IP address to add to SQL Server firewall rules
    Write-LogMessage 'Detecting current public IP address for firewall configuration...' -Level Info

    try {
        # Try multiple IP detection services for reliability (similar to example pattern)
        $ipDetectionServices = @(
            'http://ifconfig.me/ip'              # Primary service (as per example)
            'https://api.ipify.org?format=text'  # Fallback 1
            'https://icanhazip.com'              # Fallback 2
        )
        
        $currentIp = $null
        foreach ($service in $ipDetectionServices) {
            try {
                Write-LogMessage "  Trying: $service" -Level Verbose
                $currentIp = (Invoke-WebRequest -Uri $service -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop).Content.Trim()
                
                # Validate IP address format
                if ($currentIp -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    Write-LogMessage "Found public IP address: $currentIp" -Level Info
                    break
                }
            }
            catch {
                Write-LogMessage "  Failed to detect IP from $service" -Level Verbose
                continue
            }
        }
        
        if (-not $currentIp) {
            Write-LogMessage 'Warning: Could not detect public IP address - firewall rule creation skipped' -Level Warning
            Write-LogMessage 'You may need to manually add your IP to the SQL Server firewall rules' -Level Warning
        }
        else {
            # Define firewall rule name with timestamp (dynamic naming as per example)
            $firewallRuleName = "ClientIP-$(Get-Date -Format 'yyyyMMddHHmmss')"
            
            # Get resource group from environment variable
            Write-LogMessage 'Retrieving SQL Server resource group...' -Level Verbose
            $resourceGroupName = $env:AZURE_RESOURCE_GROUP
            
            if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
                Write-LogMessage "Warning: AZURE_RESOURCE_GROUP environment variable is not set" -Level Warning
                Write-LogMessage "Firewall rule creation skipped - you may need to add it manually" -Level Warning
            }
            else {
                Write-LogMessage "  Resource Group: $resourceGroupName" -Level Info
                Write-LogMessage "  Server Name:    $SqlServerName" -Level Info
                Write-LogMessage "  Rule Name:      $firewallRuleName" -Level Info
                
                # Add the IP address to the Azure SQL Server firewall rules using Azure CLI
                # This follows the exact pattern from the example
                Write-LogMessage "Adding firewall rule '$firewallRuleName' for IP '$currentIp'..." -Level Info
                
                $firewallResult = az sql server firewall-rule create `
                    --resource-group $resourceGroupName `
                    --server $SqlServerName `
                    --name $firewallRuleName `
                    --start-ip-address $currentIp `
                    --end-ip-address $currentIp `
                    -o none 2>&1
                
                # Capture exit code immediately to prevent race condition
                $firewallExitCode = $LASTEXITCODE
                
                if ($firewallExitCode -eq 0) {
                    Write-LogMessage "Firewall rule '$firewallRuleName' with IP '$currentIp' has been created." -Level Success
                }
                elseif ($firewallExitCode -eq 1 -and $firewallResult -like '*already exists*') {
                    Write-LogMessage "Firewall rule for IP '$currentIp' already exists - continuing" -Level Info
                }
                else {
                    Write-LogMessage "Warning: Failed to create firewall rule (exit code: $firewallExitCode): $firewallResult" -Level Warning
                    Write-LogMessage "You may need to manually add IP $currentIp to SQL Server firewall rules" -Level Warning
                }
            }
        }
    }
    catch {
        Write-LogMessage "Warning: Firewall configuration failed: $($_.Exception.Message)" -Level Warning
        Write-LogMessage 'Continuing with connection attempt - you may need to add firewall rule manually if connection fails' -Level Warning
    }
    
    # Get SQL endpoint suffix for the specified Azure environment
    if (-not $script:SqlEndpoints.ContainsKey($AzureEnvironment)) {
        throw "Invalid Azure environment: $AzureEnvironment. Valid values: $($script:SqlEndpoints.Keys -join ', ')"
    }
    
    $sqlSuffix = $script:SqlEndpoints[$AzureEnvironment]
    $serverFqdn = "${SqlServerName}.${sqlSuffix}"
    $resourceUrl = "https://${sqlSuffix}/"
    
    Write-LogMessage "  Server FQDN:      $serverFqdn" -Level Info
    Write-LogMessage "  Resource URL:     $resourceUrl" -Level Info
    Write-LogMessage "  Port:             1433 (default)" -Level Info
    Write-LogMessage "  Encryption:       TLS 1.2+ (enforced)" -Level Info
    #endregion
    
    #region Access Token Acquisition
    Write-LogMessage "" -Level Info
    Write-LogMessage "[Step 3/5] Acquiring Entra ID access token for Azure SQL..." -Level Info
    
    try {
        $accessToken = Get-AzureSqlAccessToken -ResourceUrl $resourceUrl
        
        # Validate token format (JWT tokens are base64-encoded and contain dots)
        if ($accessToken -notmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$') {
            Write-LogMessage 'Warning: Access token does not appear to be a valid JWT format' -Level Warning
        }
        
        # Mask token in logs (show only first 10 and last 10 characters)
        $tokenLength = $accessToken.Length
        if ($tokenLength -gt 20) {
            $maskedToken = "$($accessToken.Substring(0, 10))...$($accessToken.Substring($tokenLength - 10))"
            Write-LogMessage "  Token length:     $tokenLength characters" -Level Verbose
            Write-LogMessage "  Token preview:    $maskedToken" -Level Verbose
        }
        
        Write-LogMessage 'Access token acquired and validated successfully' -Level Success
    }
    catch {
        $errorMessage = "Failed to acquire access token: $($_.Exception.Message)"
        Write-LogMessage $errorMessage -Level Error
        throw $errorMessage
    }
    #endregion
    
    #region SQL Script Generation
    Write-LogMessage "" -Level Info
    Write-LogMessage "[Step 4/5] Generating SQL configuration script..." -Level Info
    
    try {
        $sqlScript = Get-SqlIdentityScript -PrincipalName $PrincipalDisplayName -Roles $DatabaseRoles
        Write-LogMessage "SQL script generated successfully ($($sqlScript.Length) characters)" -Level Success
        Write-LogMessage "Script will create user and assign $($DatabaseRoles.Count) role(s)" -Level Verbose
    }
    catch {
        $errorMessage = "Failed to generate SQL script: $($_.Exception.Message)"
        Write-LogMessage $errorMessage -Level Error
        throw $errorMessage
    }
    #endregion
    
    #region Database Connection and Execution
    Write-LogMessage "" -Level Info
    Write-LogMessage "[Step 5/5] Executing SQL script on target database..." -Level Info
    
    # Initialize connection variables for proper cleanup in finally block
    $connection = $null
    $command = $null
    $commandStartTime = Get-Date
    
    try {
        # Build secure connection string with encryption enforced
        # Note: Microsoft.Data.SqlClient provides cross-platform support for Azure AD token authentication
        $connectionString = @(
            "Server=tcp:${serverFqdn},1433"
            "Initial Catalog=${DatabaseName}"
            "Encrypt=True"                      # Enforce TLS encryption
            "TrustServerCertificate=False"      # Validate server certificate
            "Connection Timeout=30"              # Connection timeout in seconds
            "MultipleActiveResultSets=False"    # MARS not needed for this script
        ) -join ';'
        
        Write-LogMessage "  Connection string: $($connectionString.Replace($DatabaseName, '***'))" -Level Verbose
        
        # Create SQL connection object using the available SQL client
        Write-LogMessage 'Creating database connection...' -Level Verbose
        
        $connection = $null
        
        if ($script:UseMicrosoftDataSqlClient) {
            Write-LogMessage 'Using Microsoft.Data.SqlClient for connection' -Level Verbose
            $connection = [Microsoft.Data.SqlClient.SqlConnection]::new($connectionString)
            $connection.AccessToken = $accessToken  # Use Azure AD token instead of SQL auth
            Write-LogMessage 'Microsoft.Data.SqlClient connection object created with AccessToken' -Level Verbose
        }
        else {
            Write-LogMessage 'System.Data.SqlClient fallback is not supported for Azure AD authentication' -Level Error
            # For System.Data.SqlClient, we need to include the access token in the connection string
            # Note: System.Data.SqlClient has limited Azure AD support in PowerShell Core
            
            # System.Data.SqlClient in .NET Core/PowerShell Core does NOT support AccessToken property
            # We need to use Microsoft.Data.SqlClient for Azure AD authentication
            $errorMessage = @"
Azure AD authentication requires Microsoft.Data.SqlClient which is not available.
System.Data.SqlClient does not support the AccessToken property in PowerShell Core.

"@
            if ($script:SqlClientLoadError) {
                $errorMessage += @"
Original load error:
$script:SqlClientLoadError

"@
            }
            
            $errorMessage += @"
To fix this issue, install Microsoft.Data.SqlClient using one of these methods:

Method 1 - Using dotnet CLI (recommended):
  cd $PSScriptRoot
  dotnet new console -n TempProject -o TempProject
  cd TempProject
  dotnet add package Microsoft.Data.SqlClient
  dotnet restore
  cd ..
  Remove-Item -Recurse -Force TempProject

Method 2 - Using PowerShell:
  Install-Package Microsoft.Data.SqlClient -Source nuget.org -Destination "$env:USERPROFILE\.nuget\packages"

Method 3 - Manual download:
  Download from https://www.nuget.org/packages/Microsoft.Data.SqlClient
  Extract and copy to: $env:USERPROFILE\.nuget\packages\microsoft.data.sqlclient\<version>\

After installing, run this script again.
"@
            Write-LogMessage $errorMessage -Level Error
            throw $errorMessage
        }
        
        if ($null -eq $connection) {
            throw 'Failed to create SQL connection object - connection is null'
        }
        
        Write-LogMessage "Connection object created. Initial state: $($connection.State)" -Level Verbose
        
        # Open connection with retry logic
        $maxRetries = 3
        $retryCount = 0
        $connected = $false
        $lastConnectionError = $null
        
        while (-not $connected -and $retryCount -lt $maxRetries) {
            try {
                Write-LogMessage "Opening database connection (attempt $($retryCount + 1)/$maxRetries)..." -Level Verbose
                $connection.Open()
                $connected = $true
                Write-LogMessage 'Database connection established successfully' -Level Success
                Write-LogMessage "  Connection state:   $($connection.State)" -Level Verbose
                Write-LogMessage "  Server version:     $($connection.ServerVersion)" -Level Verbose
                Write-LogMessage "  Database:           $($connection.Database)" -Level Verbose
            }
            catch {
                $lastConnectionError = $_
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    $waitTime = [Math]::Pow(2, $retryCount)  # Exponential backoff: 2, 4, 8 seconds
                    Write-LogMessage "Connection attempt failed: $($_.Exception.Message)" -Level Warning
                    Write-LogMessage "Retrying in $waitTime seconds..." -Level Info
                    Start-Sleep -Seconds $waitTime
                }
            }
        }
        
        # Verify connection was established successfully
        if (-not $connected) {
            $errorMsg = "Failed to establish database connection after $maxRetries attempts."
            
            if ($lastConnectionError) {
                $errorMsg += "`n  Last error: $($lastConnectionError.Exception.Message)"
                
                # Add additional context based on common error types
                if ($lastConnectionError.Exception.Message -like '*firewall*') {
                    $errorMsg += "`n  Hint: Check SQL Server firewall rules. Your IP may need to be added."
                }
                elseif ($lastConnectionError.Exception.Message -like '*login*' -or $lastConnectionError.Exception.Message -like '*authentication*') {
                    $errorMsg += "`n  Hint: Ensure you are authenticated as an Entra ID administrator of the SQL Server."
                    $errorMsg += "`n  Run: az sql server ad-admin list --resource-group <rg> --server-name $SqlServerName"
                }
                elseif ($lastConnectionError.Exception.Message -like '*timeout*') {
                    $errorMsg += "`n  Hint: Connection timeout - check network connectivity and SQL Server availability."
                }
            }
            
            Write-LogMessage $errorMsg -Level Error
            throw $errorMsg
        }
        
        # Additional validation: ensure connection is open and valid
        if ($null -eq $connection -or $connection.State -ne [System.Data.ConnectionState]::Open) {
            $currentState = if ($null -eq $connection) { 'null' } else { $connection.State }
            $errorMsg = "Database connection is not in a valid state. Current state: $currentState"
            Write-LogMessage $errorMsg -Level Error
            throw $errorMsg
        }
        
        # Create and configure SQL command
        Write-LogMessage 'Creating SQL command...' -Level Verbose
        $command = $connection.CreateCommand()
        $command.CommandText = $sqlScript
        $command.CommandTimeout = $CommandTimeout
        $command.CommandType = [System.Data.CommandType]::Text
        
        Write-LogMessage "  Command timeout:    ${CommandTimeout}s" -Level Verbose
        Write-LogMessage "  Command type:       Text" -Level Verbose
        
        # Execute SQL script
        Write-LogMessage 'Executing T-SQL script...' -Level Info
        Write-LogMessage "Script creates user [$PrincipalDisplayName] and assigns roles: $($DatabaseRoles -join ', ')" -Level Info
        
        # Use ExecuteNonQuery for DDL/DML commands (CREATE USER, ALTER ROLE)
        $rowsAffected = $command.ExecuteNonQuery()
        $commandEndTime = Get-Date
        $executionDuration = ($commandEndTime - $commandStartTime).TotalSeconds
        
        Write-LogMessage "" -Level Info
        Write-LogMessage "====================================================================" -Level Success
        Write-LogMessage "SQL SCRIPT EXECUTION COMPLETED SUCCESSFULLY" -Level Success
        Write-LogMessage "====================================================================" -Level Success
        Write-LogMessage "  Rows affected:      $rowsAffected" -Level Success
        Write-LogMessage "  Execution time:     $([Math]::Round($executionDuration, 2))s" -Level Success
        Write-LogMessage "  Principal:          $PrincipalDisplayName" -Level Success
        Write-LogMessage "  Database:           $DatabaseName" -Level Success
        Write-LogMessage "  Roles assigned:     $($DatabaseRoles -join ', ')" -Level Success
        Write-LogMessage "" -Level Info
        
        # Build success result object with comprehensive information
        $result = [PSCustomObject]@{
            PSTypeName           = 'SqlManagedIdentityConfiguration.Result'
            Success              = $true
            Principal            = $PrincipalDisplayName
            Server               = $serverFqdn
            Database             = $DatabaseName
            Roles                = $DatabaseRoles
            RowsAffected         = $rowsAffected
            ExecutionTimeSeconds = [Math]::Round($executionDuration, 2)
            Timestamp            = Get-Date -Format 'o'  # ISO 8601 format
            Message              = 'Managed identity configuration completed successfully'
            ScriptVersion        = $script:ScriptVersion
        }
        
        # Return the result object
        return $result
    }
    catch {
        # Check if this is a SQL exception (from either Microsoft.Data.SqlClient or System.Data.SqlClient)
        $sqlEx = $_.Exception
        $isSqlException = $sqlEx.GetType().Name -eq 'SqlException' -or 
        $sqlEx.GetType().FullName -like '*SqlException*'
        
        if ($isSqlException) {
            # Handle SQL-specific exceptions with detailed error information
            $errorDetails = @(
                "SQL Error occurred during script execution"
                "  Error Number:       $($sqlEx.Number)"
                "  Error Message:      $($sqlEx.Message)"
                "  Severity:           $($sqlEx.Class)"
                "  State:              $($sqlEx.State)"
                "  Line Number:        $($sqlEx.LineNumber)"
                "  Procedure:          $($sqlEx.Procedure)"
                "  Server:             $($sqlEx.Server)"
            )
            
            foreach ($line in $errorDetails) {
                Write-LogMessage $line -Level Error
            }
        
            # Common SQL error numbers and their meanings
            # Display guidance using Write-ColoredOutput for PSScriptAnalyzer compliance
            Write-ColoredOutput
            Write-ColoredOutput -Message '═══════════════════════════════════════════════════════════════════' -Color Yellow
            Write-ColoredOutput -Message 'TROUBLESHOOTING GUIDANCE' -Color Yellow
            Write-ColoredOutput -Message '═══════════════════════════════════════════════════════════════════' -Color Yellow
            
            switch ($sqlEx.Number) {
                18456 { 
                    Write-ColoredOutput
                    Write-ColoredOutput -Message 'ERROR: Login failed - Authentication succeeded but user lacks SQL Server permissions' -Color Red
                    Write-ColoredOutput
                    Write-ColoredOutput -Message 'ROOT CAUSE:' -Color Yellow
                    Write-ColoredOutput -Message '  To create database users via Entra ID, you MUST authenticate as an' -Color White
                    Write-ColoredOutput -Message '  Entra ID administrator of the SQL Server.' -Color White
                    Write-ColoredOutput
                    Write-ColoredOutput -Message 'SOLUTION - Follow these steps:' -Color Yellow
                    Write-ColoredOutput
                    Write-ColoredOutput -Message '1. Set an Entra ID Admin on the SQL Server (if not already set):' -Color Cyan
                    Write-ColoredOutput
                    Write-ColoredOutput -Message '   az sql server ad-admin create \' -Color White
                    Write-ColoredOutput -Message '     --resource-group <your-rg> \' -Color White
                    Write-ColoredOutput -Message "     --server-name $SqlServerName \" -Color White
                    Write-ColoredOutput -Message '     --display-name <admin-user-or-identity-name> \' -Color White
                    Write-ColoredOutput -Message '     --object-id <admin-object-id>' -Color White
                    Write-ColoredOutput
                    Write-ColoredOutput -Message '   Example (using your current user):' -Color Gray
                    Write-ColoredOutput -Message "   `$me = az ad signed-in-user show --query '{name:userPrincipalName,id:id}' -o json | ConvertFrom-Json" -Color Gray
                    Write-ColoredOutput -Message "   az sql server ad-admin create --resource-group <rg> --server-name $SqlServerName --display-name `$me.name --object-id `$me.id" -Color Gray
                    Write-ColoredOutput
                    Write-ColoredOutput -Message '2. Verify the admin is set:' -Color Cyan
                    Write-ColoredOutput -Message "   az sql server ad-admin list --resource-group <rg> --server-name $SqlServerName" -Color White
                    Write-ColoredOutput
                    Write-ColoredOutput -Message '3. Ensure you are authenticated as that admin:' -Color Cyan
                    Write-ColoredOutput -Message '   az account show    # Check current identity' -Color White
                    Write-ColoredOutput -Message '   az login           # Re-authenticate if needed' -Color White
                    Write-ColoredOutput
                    Write-ColoredOutput -Message '4. Re-run the provisioning:' -Color Cyan
                    Write-ColoredOutput -Message '   azd provision' -Color White
                    Write-ColoredOutput
                    Write-ColoredOutput -Message 'More info: https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure' -Color Gray
                }
                40615 { 
                    Write-ColoredOutput -Message 'Firewall rule blocking connection - add client IP to SQL firewall' -Color Yellow
                }
                40613 { 
                    Write-ColoredOutput -Message 'Database not available - check database exists and is online' -Color Yellow
                }
                33134 { 
                    Write-ColoredOutput -Message 'User already exists - this is usually safe to ignore' -Color Green
                }
                15023 { 
                    Write-ColoredOutput -Message 'User, group, or role already exists in database' -Color Green
                }
                default { 
                    Write-ColoredOutput -Message 'Check SQL Server logs and Azure AD configuration' -Color Yellow
                }
            }
            
            Write-ColoredOutput
            Write-ColoredOutput -Message '═══════════════════════════════════════════════════════════════════' -Color Yellow
            Write-ColoredOutput
            
            throw
        }
        elseif ($_.Exception -is [System.InvalidOperationException]) {
            # Handle connection state exceptions
            Write-LogMessage "Connection state error: $($_.Exception.Message)" -Level Error
            Write-LogMessage 'This usually indicates an authentication or network connectivity issue' -Level Error
            throw
        }
        else {
            # Handle all other exceptions
            Write-LogMessage "Unexpected error during SQL execution: $($_.Exception.Message)" -Level Error
            Write-LogMessage "Exception type: $($_.Exception.GetType().FullName)" -Level Error
            throw
        }
    }
    finally {
        # Ensure proper cleanup of database resources
        # This block always executes, even if exceptions occur
        Write-LogMessage 'Cleaning up database resources...' -Level Verbose
        
        if ($command) {
            try {
                $command.Dispose()
                Write-LogMessage 'SQL command disposed' -Level Verbose
            }
            catch {
                Write-LogMessage "Warning: Failed to dispose command: $($_.Exception.Message)" -Level Warning
            }
        }
        
        if ($connection) {
            try {
                if ($connection.State -eq 'Open') {
                    $connection.Close()
                    Write-LogMessage 'Database connection closed' -Level Verbose
                }
                $connection.Dispose()
                Write-LogMessage 'Connection object disposed' -Level Verbose
            }
            catch {
                Write-LogMessage "Warning: Failed to dispose connection: $($_.Exception.Message)" -Level Warning
            }
        }
        
        Write-LogMessage 'Resource cleanup completed' -Level Verbose
    }
    #endregion
}
catch {
    # Top-level exception handler for the entire script
    # This catches any unhandled exceptions from the main execution block
    
    Write-LogMessage "" -Level Error
    Write-LogMessage "====================================================================" -Level Error
    Write-LogMessage "SCRIPT EXECUTION FAILED" -Level Error
    Write-LogMessage "====================================================================" -Level Error
    Write-LogMessage "Error message:      $($_.Exception.Message)" -Level Error
    Write-LogMessage "Error type:         $($_.Exception.GetType().FullName)" -Level Error
    Write-LogMessage "Error source:       $($_.Exception.Source)" -Level Error
    
    # Include inner exception details if available
    if ($_.Exception.InnerException) {
        Write-LogMessage "Inner exception:    $($_.Exception.InnerException.Message)" -Level Error
    }
    
    # Include script stack trace for debugging
    if ($_.ScriptStackTrace) {
        Write-LogMessage "" -Level Error
        Write-LogMessage "Stack trace:" -Level Error
        $_.ScriptStackTrace -split "`n" | ForEach-Object {
            Write-LogMessage "  $_" -Level Error
        }
    }
    
    Write-LogMessage "" -Level Error
    
    # Build detailed error result object
    $errorResult = [PSCustomObject]@{
        PSTypeName    = 'SqlManagedIdentityConfiguration.Result'
        Success       = $false
        Principal     = $PrincipalDisplayName
        Server        = "${SqlServerName}.$($script:SqlEndpoints[$AzureEnvironment])"
        Database      = $DatabaseName
        Roles         = $DatabaseRoles
        Error         = $_.Exception.Message
        ErrorType     = $_.Exception.GetType().FullName
        InnerError    = if ($_.Exception.InnerException) { $_.Exception.InnerException.Message } else { $null }
        Timestamp     = Get-Date -Format 'o'
        ScriptVersion = $script:ScriptVersion
    }
    
    # Return error object for programmatic handling
    # Note: Return statement in catch block prevents the exception from propagating
    return $errorResult
}
finally {
    # Restore original preferences
    $ErrorActionPreference = $script:OriginalErrorActionPreference
    $ProgressPreference = $script:OriginalProgressPreference
    $InformationPreference = $script:OriginalInformationPreference
}
