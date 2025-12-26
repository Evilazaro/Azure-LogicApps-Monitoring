<#
.SYNOPSIS
    Configures Azure SQL Database user with Managed Identity authentication.

.DESCRIPTION
    Creates a database user from an external provider (Entra ID/Managed Identity)
    and assigns specified database roles using Azure AD token authentication.

.PARAMETER SqlServerName
    The name of the Azure SQL Server (without suffix).

.PARAMETER DatabaseName
    The name of the target database.

.PARAMETER PrincipalDisplayName
    The display name of the managed identity or service principal.

.PARAMETER DatabaseRoles
    Array of database roles to assign to the principal.

.PARAMETER AzureEnvironment
    Azure environment (AzureCloud, AzureUSGovernment, etc.). Default: AzureCloud

.PARAMETER CommandTimeout
    SQL command timeout in seconds. Default: 120

.EXAMPLE
    .\sql-managed-identity-config.ps1 -SqlServerName "myserver" -DatabaseName "mydb" -PrincipalDisplayName "my-app-identity" -DatabaseRoles @("db_datareader", "db_datawriter")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Azure SQL Server name")]
    [ValidateNotNullOrEmpty()]
    [string]$SqlServerName,

    [Parameter(Mandatory = $true, HelpMessage = "Database name")]
    [ValidateNotNullOrEmpty()]
    [string]$DatabaseName,

    [Parameter(Mandatory = $true, HelpMessage = "Managed identity or service principal display name")]
    [ValidateNotNullOrEmpty()]
    [string]$PrincipalDisplayName,

    [Parameter(Mandatory = $false, HelpMessage = "Database roles to assign")]
    [ValidateNotNullOrEmpty()]
    [string[]]$DatabaseRoles = @("db_datareader", "db_datawriter"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("AzureCloud", "AzureUSGovernment", "AzureChinaCloud", "AzureGermanCloud")]
    [string]$AzureEnvironment = "AzureCloud",

    [Parameter(Mandatory = $false)]
    [ValidateRange(30, 600)]
    [int]$CommandTimeout = 120
)

#Requires -Modules Az.Accounts

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Azure SQL endpoint mapping
$sqlEndpoints = @{
    "AzureCloud"        = "database.windows.net"
    "AzureUSGovernment" = "database.usgovcloudapi.net"
    "AzureChinaCloud"   = "database.chinacloudapi.cn"
    "AzureGermanCloud"  = "database.cloudapi.de"
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Level = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
        default   { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureContext {
    try {
        $context = Get-AzContext
        if (-not $context) {
            throw "No Azure context found. Please run Connect-AzAccount first."
        }
        Write-Log "Azure context validated: $($context.Account.Id)" -Level Success
        return $true
    }
    catch {
        Write-Log "Azure context validation failed: $_" -Level Error
        return $false
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
    
    $tokenResult = Get-AzAccessToken -ResourceUrl $resourceUrl -ErrorAction Stop
    if (-not $tokenResult -or -not $tokenResult.Token) {
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
        $connection.AccessToken = $tokenResult.Token
        
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