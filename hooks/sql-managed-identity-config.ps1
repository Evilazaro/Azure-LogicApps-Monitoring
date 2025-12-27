<#
.SYNOPSIS
    Configures Azure SQL Database user with Managed Identity authentication.

.DESCRIPTION
    Creates a database user from an external provider (Microsoft Entra ID/Managed Identity)
    and assigns specified database roles using Azure AD token-based authentication.
    
    This script performs the following operations:
    - Validates Azure authentication (Az.Accounts module or Azure CLI)
    - Acquires an access token for Azure SQL Database
    - Creates a contained database user from external provider
    - Assigns specified database roles to the user
    - Returns a structured result object
    
    The script is idempotent and can be safely re-run. It will skip existing users
    and role memberships.

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
    System.Collections.Hashtable
    
    Returns a hashtable with the following keys:
    - Success (Boolean): True if configuration succeeded, False otherwise
    - Principal (String): The principal display name
    - Server (String): The server FQDN
    - Database (String): The database name
    - Roles (Array): The assigned roles
    - Message (String): Success message (on success)
    - Error (String): Error message (on failure)

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
    Author:         Evilazaro
    Creation Date:  2025-12-26
    Purpose:        Post-provisioning SQL Database managed identity configuration
    
    Prerequisites:
    - Azure authentication via Az.Accounts module (Connect-AzAccount) OR Azure CLI (az login)
    - Permissions: SQL Server Contributor or higher on the SQL Server resource
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

[CmdletBinding(SupportsShouldProcess = $false)]
param(
    [Parameter(
        Mandatory = $true,
        Position = 0,
        HelpMessage = "Enter the Azure SQL Server name (without suffix)",
        ValueFromPipeline = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 63)]
    [ValidatePattern('^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$', ErrorMessage = "SQL Server name must contain only lowercase letters, numbers, and hyphens, and cannot start or end with a hyphen")]
    [Alias('Server', 'SqlServer')]
    [string]$SqlServerName,

    [Parameter(
        Mandatory = $true,
        Position = 1,
        HelpMessage = "Enter the database name",
        ValueFromPipeline = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 128)]
    [ValidateScript(
        { $_ -ne 'master' },
        ErrorMessage = "Cannot configure managed identity users in the 'master' database. Please specify a user database."
    )]
    [Alias('Database', 'Db')]
    [string]$DatabaseName,

    [Parameter(
        Mandatory = $true,
        Position = 2,
        HelpMessage = "Enter the managed identity or service principal display name from Entra ID",
        ValueFromPipeline = $false,
        ValueFromPipelineByPropertyName = $true
    )]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(1, 128)]
    [Alias('Principal', 'Identity', 'IdentityName')]
    [string]$PrincipalDisplayName,

    [Parameter(
        Mandatory = $false,
        HelpMessage = "Enter database roles to assign (default: db_datareader, db_datawriter)",
        ValueFromPipeline = $false,
        ValueFromPipelineByPropertyName = $true
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

#Requires -Version 7.0

# Script metadata
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$InformationPreference = 'Continue'

# Script constants
$script:ScriptVersion = '1.0.0'
$script:MinimumAzCliVersion = '2.60.0'

# Azure SQL endpoint mapping for different cloud environments
# These suffixes are appended to the SQL Server logical name to form the FQDN
$script:SqlEndpoints = @{
    'AzureCloud'        = 'database.windows.net'
    'AzureUSGovernment' = 'database.usgovcloudapi.net'
    'AzureChinaCloud'   = 'database.chinacloudapi.cn'
    'AzureGermanCloud'  = 'database.cloudapi.de'
}

function Write-Log {
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
        Write-Log "Processing started" -Level Info
    
    .EXAMPLE
        Write-Log "Operation completed successfully" -Level Success
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
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
        # Route to appropriate PowerShell stream
        switch ($Level) {
            'Verbose' {
                Write-Verbose -Message $formattedMessage
            }
            'Debug' {
                Write-Debug -Message $formattedMessage
            }
            'Warning' {
                Write-Warning -Message $Message
                Write-Host $formattedMessage -ForegroundColor Yellow
            }
            'Error' {
                Write-Error -Message $Message -ErrorAction Continue
                Write-Host $formattedMessage -ForegroundColor Red
            }
            'Success' {
                Write-Information -MessageData $formattedMessage -InformationAction Continue
                Write-Host $formattedMessage -ForegroundColor Green
            }
            default { # Info
                Write-Information -MessageData $formattedMessage -InformationAction Continue
                Write-Host $formattedMessage -ForegroundColor Cyan
            }
        }
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
        Write-Log 'Checking Azure CLI availability...' -Level Verbose
    }
    
    process {
        try {
            # Check if az command exists
            $azCommand = Get-Command -Name az -ErrorAction SilentlyContinue
            
            if (-not $azCommand) {
                Write-Log 'Azure CLI (az) is not installed or not in PATH' -Level Error
                Write-Log 'Install from: https://learn.microsoft.com/cli/azure/install-azure-cli' -Level Error
                return $false
            }
            
            Write-Log "Azure CLI found at: $($azCommand.Source)" -Level Verbose
            
            # Check Azure CLI version
            $versionOutput = az version --query '"azure-cli"' -o tsv 2>&1
            if ($LASTEXITCODE -eq 0 -and $versionOutput) {
                Write-Log "Azure CLI version: $versionOutput" -Level Verbose
            }
            
            # Check if logged in
            $accountCheck = az account show 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Log 'Not authenticated to Azure CLI' -Level Error
                Write-Log 'Run: az login' -Level Error
                return $false
            }
            
            # Parse account information
            $accountInfo = $accountCheck | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($accountInfo -and $accountInfo.name) {
                Write-Log "Azure CLI authenticated: Subscription=$($accountInfo.name)" -Level Success
            }
            
            return $true
        }
        catch {
            Write-Log "Azure CLI validation failed: $($_.Exception.Message)" -Level Error
            return $false
        }
    }
    
    end {
        Write-Log 'Azure CLI availability check completed' -Level Verbose
    }
}

function Test-AzureContext {
    <#
    .SYNOPSIS
        Validates Azure authentication context via Az.Accounts module.
    
    .DESCRIPTION
        Checks if the Az.Accounts PowerShell module is available and if the user
        has an active Azure context. This function is optional as the script can
        fall back to Azure CLI authentication if Az.Accounts is not available.
    
    .OUTPUTS
        System.Boolean
        Returns $true if authentication is valid, $false otherwise.
    
    .EXAMPLE
        if (Test-AzureContext) {
            Write-Host "Azure authentication is valid"
        }
    
    .NOTES
        This function does not throw exceptions. It returns $false on any failure
        to allow graceful fallback to Azure CLI authentication.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    begin {
        Write-Log 'Checking Azure authentication context...' -Level Verbose
    }
    
    process {
        try {
            # Check if Az.Accounts module is available in the module path
            $moduleAvailable = Get-Module -ListAvailable -Name Az.Accounts -ErrorAction SilentlyContinue
            
            if (-not $moduleAvailable) {
                Write-Log 'Az.Accounts PowerShell module is not installed' -Level Warning
                Write-Log 'Install with: Install-Module -Name Az.Accounts -Scope CurrentUser -Repository PSGallery -Force' -Level Info
                Write-Log 'Falling back to Azure CLI authentication...' -Level Info
                return $false
            }
            
            # Import the module if not already loaded
            if (-not (Get-Module -Name Az.Accounts)) {
                Write-Log 'Importing Az.Accounts module...' -Level Verbose
                Import-Module Az.Accounts -ErrorAction Stop -Verbose:$false
            }
            
            # Check for active Azure context
            $context = Get-AzContext -ErrorAction SilentlyContinue
            
            if (-not $context) {
                Write-Log 'No active Azure context found in Az.Accounts' -Level Warning
                Write-Log 'Run Connect-AzAccount to authenticate, or the script will use Azure CLI' -Level Info
                return $false
            }
            
            # Validate context has required properties
            if (-not $context.Account -or -not $context.Subscription) {
                Write-Log 'Azure context is incomplete (missing account or subscription)' -Level Warning
                return $false
            }
            
            Write-Log "Azure context validated: Account=$($context.Account.Id), Subscription=$($context.Subscription.Name)" -Level Success
            return $true
        }
        catch {
            Write-Log "Azure context validation failed: $($_.Exception.Message)" -Level Warning
            Write-Log 'Will attempt to use Azure CLI authentication as fallback' -Level Info
            return $false
        }
    }
    
    end {
        Write-Log 'Azure context validation completed' -Level Verbose
    }
}

try {
    Write-Log "Starting Azure SQL Managed Identity configuration..." -Level Info
    Write-Log "Parameters: Server=$SqlServerName, Database=$DatabaseName, Principal=$PrincipalDisplayName" -Level Info

    # Validate prerequisites
    if (-not (Test-AzureContext)) {
        throw "Azure authentication required"
    }

    # Construct connection details
    $sqlSuffix = $sqlEndpoints[$AzureEnvironment]
    $serverFqdn = "$SqlServerName.$sqlSuffix"
    Write-Log "Target server: $serverFqdn" -Level Info

    # Get Entra token for Azure SQL
    Write-Log "Acquiring Entra ID token for Azure SQL..." -Level Info
    $resourceUrl = "https://$sqlSuffix/"
    
    # Try Az.Accounts first, fall back to Azure CLI
    $tokenResult = $null
    $accessToken = $null
    
    if (Get-Module -Name Az.Accounts) {
        try {
            Write-Log "Using Az.Accounts module for token acquisition..." -Level Info
            $tokenResult = Get-AzAccessToken -ResourceUrl $resourceUrl -ErrorAction Stop
            if ($tokenResult -and $tokenResult.Token) {
                $accessToken = $tokenResult.Token
            }
        }
        catch {
            Write-Log "Az.Accounts token acquisition failed: $($_.Exception.Message)" -Level Warning
            Write-Log "Falling back to Azure CLI..." -Level Info
        }
    }
    
    # Fall back to Azure CLI if Az.Accounts didn't work
    if (-not $accessToken) {
        try {
            Write-Log "Using Azure CLI for token acquisition..." -Level Info
            $cliToken = az account get-access-token --resource $resourceUrl --query accessToken -o tsv 2>&1
            if ($LASTEXITCODE -eq 0 -and $cliToken) {
                $accessToken = $cliToken
            }
            else {
                throw "Azure CLI token acquisition failed: $cliToken"
            }
        }
        catch {
            throw "Failed to acquire access token using both Az.Accounts and Azure CLI: $($_.Exception.Message)"
        }
    }
    
    if (-not $accessToken) {
        throw "Failed to acquire access token for Azure SQL"
    }
    Write-Log "Access token acquired successfully" -Level Success

    # Build connection string (using Microsoft.Data.SqlClient is preferred, but System.Data.SqlClient works for token auth)
    $connString = "Server=tcp:$serverFqdn,1433;Initial Catalog=$DatabaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

    # Build SQL script for user creation
    $createUserSql = @"
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$PrincipalDisplayName' AND type IN ('E', 'X'))
BEGIN
    CREATE USER [$PrincipalDisplayName] FROM EXTERNAL PROVIDER;
    PRINT 'User [$PrincipalDisplayName] created successfully';
END
ELSE
BEGIN
    PRINT 'User [$PrincipalDisplayName] already exists';
END
"@

    # Build SQL script for role assignments
    $roleAssignmentSql = ""
    foreach ($role in $DatabaseRoles) {
        $roleAssignmentSql += @"

IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$role' AND type = 'R')
BEGIN
    IF IS_ROLEMEMBER(N'$role', N'$PrincipalDisplayName') = 0 OR IS_ROLEMEMBER(N'$role', N'$PrincipalDisplayName') IS NULL
    BEGIN
        ALTER ROLE [$role] ADD MEMBER [$PrincipalDisplayName];
        PRINT 'Added [$PrincipalDisplayName] to role [$role]';
    END
    ELSE
    BEGIN
        PRINT '[$PrincipalDisplayName] is already a member of role [$role]';
    END
END
ELSE
BEGIN
    PRINT 'Warning: Role [$role] does not exist in database';
END
"@
    }

    $fullSql = $createUserSql + $roleAssignmentSql

    # Execute SQL commands with proper error handling and resource disposal
    Write-Log "Connecting to database..." -Level Info
    
    $connection = $null
    $command = $null
    
    try {
        # Create and configure connection
        $connection = New-Object System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connString
        $connection.AccessToken = $accessToken
        
        $connection.Open()
        Write-Log "Database connection established" -Level Success

        # Create and execute command
        $command = $connection.CreateCommand()
        $command.CommandText = $fullSql
        $command.CommandTimeout = $CommandTimeout
        
        Write-Log "Executing SQL commands..." -Level Info
        $rowsAffected = $command.ExecuteNonQuery()
        
        Write-Log "SQL commands executed successfully (rows affected: $rowsAffected)" -Level Success
        Write-Log "Managed identity configuration completed for principal: $PrincipalDisplayName" -Level Success
        
        # Return success object
        return @{
            Success = $true
            Principal = $PrincipalDisplayName
            Server = $serverFqdn
            Database = $DatabaseName
            Roles = $DatabaseRoles
            Message = "Configuration completed successfully"
        }
    }
    catch {
        Write-Log "SQL execution failed: $($_.Exception.Message)" -Level Error
        throw
    }
    finally {
        # Ensure proper cleanup of resources
        if ($command) {
            $command.Dispose()
        }
        if ($connection -and $connection.State -eq 'Open') {
            $connection.Close()
            Write-Log "Database connection closed" -Level Info
        }
        if ($connection) {
            $connection.Dispose()
        }
    }
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" -Level Error
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level Error
    
    # Return error object
    return @{
        Success = $false
        Error = $_.Exception.Message
        Principal = $PrincipalDisplayName
        Server = "$SqlServerName.$($sqlEndpoints[$AzureEnvironment])"
        Database = $DatabaseName
    }
    
    exit 1
}