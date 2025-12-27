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

# Remove hard module requirement - check at runtime instead
# #Requires -Modules Az.Accounts

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
        # Check if Az.Accounts module is available
        if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
            Write-Log "Az.Accounts PowerShell module is not installed" -Level Error
            Write-Log "Install with: Install-Module -Name Az.Accounts -Scope CurrentUser -Repository PSGallery -Force" -Level Error
            Write-Log "Or use Azure CLI authentication instead by calling this script with Azure CLI authentication" -Level Warning
            return $false
        }
        
        # Import the module if not already loaded
        if (-not (Get-Module -Name Az.Accounts)) {
            Write-Log "Importing Az.Accounts module..." -Level Info
            Import-Module Az.Accounts -ErrorAction Stop
        }
        
        $context = Get-AzContext
        if (-not $context) {
            Write-Log "No Azure context found. Run 'Connect-AzAccount' or use 'az login' and try with Azure CLI token" -Level Error
            return $false
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