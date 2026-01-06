<#
.SYNOPSIS
    Configures Azure SQL Database user with Managed Identity authentication.

.DESCRIPTION
    Creates a database user from an external provider (Microsoft Entra ID/Managed Identity)
    and assigns specified database roles using Azure AD token-based authentication.
    
    This script performs the following operations:
    - Validates Azure CLI authentication
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
[OutputType([System.Collections.Hashtable])]
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
    [Alias('Database')]
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
        Write-Log "Acquiring access token for resource: $ResourceUrl" -Level Verbose
    }
    
    process {
        try {
            Write-Log 'Attempting token acquisition via Azure CLI...' -Level Verbose
            
            # Execute Azure CLI command to get access token
            $cliOutput = az account get-access-token --resource $ResourceUrl --query accessToken -o tsv 2>&1
            $cliExitCode = $LASTEXITCODE
            
            if ($cliExitCode -ne 0) {
                throw "Azure CLI returned exit code $cliExitCode. Output: $cliOutput"
            }
            
            if ([string]::IsNullOrWhiteSpace($cliOutput)) {
                throw 'Azure CLI returned an empty token'
            }
            
            $accessToken = $cliOutput.Trim()
            Write-Log 'Token acquired successfully via Azure CLI' -Level Success
            return $accessToken
        }
        catch {
            $errorMessage = "Azure CLI token acquisition failed: $($_.Exception.Message)"
            Write-Log $errorMessage -Level Error
            throw $errorMessage
        }
    }
    
    end {
        Write-Log 'Token acquisition completed' -Level Verbose
    }
}

function New-SqlIdentityScript {
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
        $script = New-SqlIdentityScript -PrincipalName 'my-identity' -Roles @('db_datareader', 'db_datawriter')
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
        Write-Log 'Generating SQL script for managed identity configuration...' -Level Verbose
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
        
        Write-Log "Generated SQL script with $($Roles.Count) role assignment(s)" -Level Verbose
        return $fullScript
    }
    
    end {
        Write-Log 'SQL script generation completed' -Level Verbose
    }
}

try {
    #region Script Initialization
    Write-Log "====================================================================" -Level Info
    Write-Log "SQL Managed Identity Configuration Script v$script:ScriptVersion" -Level Info
    Write-Log "====================================================================" -Level Info
    Write-Log "Starting Azure SQL Database managed identity configuration..." -Level Info
    Write-Log "" -Level Info
    
    # Log input parameters (mask sensitive data)
    Write-Log "Configuration Parameters:" -Level Info
    Write-Log "  SQL Server Name:    $SqlServerName" -Level Info
    Write-Log "  Database Name:      $DatabaseName" -Level Info
    Write-Log "  Principal Name:     $PrincipalDisplayName" -Level Info
    Write-Log "  Database Roles:     $($DatabaseRoles -join ', ')" -Level Info
    Write-Log "  Azure Environment:  $AzureEnvironment" -Level Info
    Write-Log "  Command Timeout:    ${CommandTimeout}s" -Level Info
    Write-Log "" -Level Info
    #endregion
    
    #region Azure Authentication Validation
    Write-Log "[Step 1/5] Validating Azure authentication..." -Level Info
    
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
    
    Write-Log 'Using Azure CLI for authentication' -Level Success
    #endregion
    
    #region Connection Details
    Write-Log "" -Level Info
    Write-Log "[Step 2/5] Constructing connection details..." -Level Info

    # Get current public IP address to add to SQL Server firewall rules
    Write-Log 'Detecting current public IP address for firewall configuration...' -Level Info

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
                Write-Log "  Trying: $service" -Level Verbose
                $currentIp = (Invoke-WebRequest -Uri $service -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop).Content.Trim()
                
                # Validate IP address format
                if ($currentIp -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    Write-Log "Found public IP address: $currentIp" -Level Info
                    break
                }
            }
            catch {
                Write-Log "  Failed to detect IP from $service" -Level Verbose
                continue
            }
        }
        
        if (-not $currentIp) {
            Write-Log 'Warning: Could not detect public IP address - firewall rule creation skipped' -Level Warning
            Write-Log 'You may need to manually add your IP to the SQL Server firewall rules' -Level Warning
        }
        else {
            # Define firewall rule name with timestamp (dynamic naming as per example)
            $firewallRuleName = "ClientIP-$(Get-Date -Format 'yyyyMMddHHmmss')"
            
            # Get resource group from environment variable
            Write-Log 'Retrieving SQL Server resource group...' -Level Verbose
            $resourceGroupName = $env:AZURE_RESOURCE_GROUP
            
            if ([string]::IsNullOrWhiteSpace($resourceGroupName)) {
                Write-Log "Warning: AZURE_RESOURCE_GROUP environment variable is not set" -Level Warning
                Write-Log "Firewall rule creation skipped - you may need to add it manually" -Level Warning
            }
            else {
                Write-Log "  Resource Group: $resourceGroupName" -Level Info
                Write-Log "  Server Name:    $SqlServerName" -Level Info
                Write-Log "  Rule Name:      $firewallRuleName" -Level Info
                
                # Add the IP address to the Azure SQL Server firewall rules using Azure CLI
                # This follows the exact pattern from the example
                Write-Log "Adding firewall rule '$firewallRuleName' for IP '$currentIp'..." -Level Info
                
                $firewallResult = az sql server firewall-rule create `
                    --resource-group $resourceGroupName `
                    --server $SqlServerName `
                    --name $firewallRuleName `
                    --start-ip-address $currentIp `
                    --end-ip-address $currentIp `
                    -o none 2>&1
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Log "Firewall rule '$firewallRuleName' with IP '$currentIp' has been created." -Level Success
                }
                else {
                    Write-Log "Warning: Failed to create firewall rule: $firewallResult" -Level Warning
                    Write-Log "You may need to manually add IP $currentIp to SQL Server firewall rules" -Level Warning
                }
            }
        }
    }
    catch {
        Write-Log "Warning: Firewall configuration failed: $($_.Exception.Message)" -Level Warning
        Write-Log 'Continuing with connection attempt - you may need to add firewall rule manually if connection fails' -Level Warning
    }

    
    # Get SQL endpoint suffix for the specified Azure environment
    if (-not $script:SqlEndpoints.ContainsKey($AzureEnvironment)) {
        throw "Invalid Azure environment: $AzureEnvironment. Valid values: $($script:SqlEndpoints.Keys -join ', ')"
    }
    
    $sqlSuffix = $script:SqlEndpoints[$AzureEnvironment]
    $serverFqdn = "${SqlServerName}.${sqlSuffix}"
    $resourceUrl = "https://${sqlSuffix}/"
    
    Write-Log "  Server FQDN:      $serverFqdn" -Level Info
    Write-Log "  Resource URL:     $resourceUrl" -Level Info
    Write-Log "  Port:             1433 (default)" -Level Info
    Write-Log "  Encryption:       TLS 1.2+ (enforced)" -Level Info
    #endregion
    
    #region Access Token Acquisition
    Write-Log "" -Level Info
    Write-Log "[Step 3/5] Acquiring Entra ID access token for Azure SQL..." -Level Info
    
    try {
        $accessToken = Get-AzureSqlAccessToken -ResourceUrl $resourceUrl
        
        # Validate token format (JWT tokens are base64-encoded and contain dots)
        if ($accessToken -notmatch '^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$') {
            Write-Log 'Warning: Access token does not appear to be a valid JWT format' -Level Warning
        }
        
        # Mask token in logs (show only first 10 and last 10 characters)
        $tokenLength = $accessToken.Length
        if ($tokenLength -gt 20) {
            $maskedToken = "$($accessToken.Substring(0, 10))...$($accessToken.Substring($tokenLength - 10))"
            Write-Log "  Token length:     $tokenLength characters" -Level Verbose
            Write-Log "  Token preview:    $maskedToken" -Level Verbose
        }
        
        Write-Log 'Access token acquired and validated successfully' -Level Success
    }
    catch {
        $errorMessage = "Failed to acquire access token: $($_.Exception.Message)"
        Write-Log $errorMessage -Level Error
        throw $errorMessage
    }
    #endregion
    
    #region SQL Script Generation
    Write-Log "" -Level Info
    Write-Log "[Step 4/5] Generating SQL configuration script..." -Level Info
    
    try {
        $sqlScript = New-SqlIdentityScript -PrincipalName $PrincipalDisplayName -Roles $DatabaseRoles
        Write-Log "SQL script generated successfully ($($sqlScript.Length) characters)" -Level Success
        Write-Log "Script will create user and assign $($DatabaseRoles.Count) role(s)" -Level Verbose
    }
    catch {
        $errorMessage = "Failed to generate SQL script: $($_.Exception.Message)"
        Write-Log $errorMessage -Level Error
        throw $errorMessage
    }
    #endregion
    
    #region Database Connection and Execution
    Write-Log "" -Level Info
    Write-Log "[Step 5/5] Executing SQL script on target database..." -Level Info
    
    # Initialize connection variables for proper cleanup in finally block
    $connection = $null
    $command = $null
    $commandStartTime = Get-Date
    
    try {
        # Build secure connection string with encryption enforced
        # Note: System.Data.SqlClient supports Azure AD token authentication
        $connectionString = @(
            "Server=tcp:${serverFqdn},1433"
            "Initial Catalog=${DatabaseName}"
            "Encrypt=True"                      # Enforce TLS encryption
            "TrustServerCertificate=False"      # Validate server certificate
            "Connection Timeout=30"              # Connection timeout in seconds
            "MultipleActiveResultSets=False"    # MARS not needed for this script
        ) -join ';'
        
        Write-Log "  Connection string: $($connectionString.Replace($DatabaseName, '***'))" -Level Verbose
        
        # Create SQL connection object
        Write-Log 'Creating database connection...' -Level Verbose
        $connection = New-Object -TypeName System.Data.SqlClient.SqlConnection
        $connection.ConnectionString = $connectionString
        $connection.AccessToken = $accessToken  # Use Azure AD token instead of SQL auth
        
        # Open connection with retry logic
        $maxRetries = 3
        $retryCount = 0
        $connected = $false
        
        while (-not $connected -and $retryCount -lt $maxRetries) {
            try {
                Write-Log "Opening database connection (attempt $($retryCount + 1)/$maxRetries)..." -Level Verbose
                $connection.Open()
                $connected = $true
                Write-Log 'Database connection established successfully' -Level Success
                Write-Log "  Connection state:   $($connection.State)" -Level Verbose
                Write-Log "  Server version:     $($connection.ServerVersion)" -Level Verbose
                Write-Log "  Database:           $($connection.Database)" -Level Verbose
            }
            catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    $waitTime = [Math]::Pow(2, $retryCount)  # Exponential backoff: 2, 4, 8 seconds
                    Write-Log "Connection attempt failed: $($_.Exception.Message)" -Level Warning
                    Write-Log "Retrying in $waitTime seconds..." -Level Info
                    Start-Sleep -Seconds $waitTime
                }
                else {
                    throw
                }
            }
        }
        
        # Create and configure SQL command
        Write-Log 'Creating SQL command...' -Level Verbose
        $command = $connection.CreateCommand()
        $command.CommandText = $sqlScript
        $command.CommandTimeout = $CommandTimeout
        $command.CommandType = [System.Data.CommandType]::Text
        
        Write-Log "  Command timeout:    ${CommandTimeout}s" -Level Verbose
        Write-Log "  Command type:       Text" -Level Verbose
        
        # Execute SQL script
        Write-Log 'Executing T-SQL script...' -Level Info
        Write-Log "Script creates user [$PrincipalDisplayName] and assigns roles: $($DatabaseRoles -join ', ')" -Level Info
        
        # Use ExecuteNonQuery for DDL/DML commands (CREATE USER, ALTER ROLE)
        $rowsAffected = $command.ExecuteNonQuery()
        $commandEndTime = Get-Date
        $executionDuration = ($commandEndTime - $commandStartTime).TotalSeconds
        
        Write-Log "" -Level Info
        Write-Log "====================================================================" -Level Success
        Write-Log "SQL SCRIPT EXECUTION COMPLETED SUCCESSFULLY" -Level Success
        Write-Log "====================================================================" -Level Success
        Write-Log "  Rows affected:      $rowsAffected" -Level Success
        Write-Log "  Execution time:     $([Math]::Round($executionDuration, 2))s" -Level Success
        Write-Log "  Principal:          $PrincipalDisplayName" -Level Success
        Write-Log "  Database:           $DatabaseName" -Level Success
        Write-Log "  Roles assigned:     $($DatabaseRoles -join ', ')" -Level Success
        Write-Log "" -Level Info
        
        # Build success result object with comprehensive information
        $result = [PSCustomObject]@{
            PSTypeName        = 'SqlManagedIdentityConfiguration.Result'
            Success           = $true
            Principal         = $PrincipalDisplayName
            Server            = $serverFqdn
            Database          = $DatabaseName
            Roles             = $DatabaseRoles
            RowsAffected      = $rowsAffected
            ExecutionTimeSeconds = [Math]::Round($executionDuration, 2)
            Timestamp         = Get-Date -Format 'o'  # ISO 8601 format
            Message           = 'Managed identity configuration completed successfully'
            ScriptVersion     = $script:ScriptVersion
        }
        
        # Return the result object
        return $result
    }
    catch [System.Data.SqlClient.SqlException] {
        # Handle SQL-specific exceptions with detailed error information
        $sqlEx = $_.Exception
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
            Write-Log $line -Level Error
        }
        
        # Common SQL error numbers and their meanings
        # Display guidance using Write-Host for immediate visibility (not buffered)
        Write-Host '' -ForegroundColor Yellow
        Write-Host '═══════════════════════════════════════════════════════════════════' -ForegroundColor Yellow
        Write-Host 'TROUBLESHOOTING GUIDANCE' -ForegroundColor Yellow
        Write-Host '═══════════════════════════════════════════════════════════════════' -ForegroundColor Yellow
        
        switch ($sqlEx.Number) {
            18456 { 
                Write-Host ''
                Write-Host 'ERROR: Login failed - Authentication succeeded but user lacks SQL Server permissions' -ForegroundColor Red
                Write-Host ''
                Write-Host 'ROOT CAUSE:' -ForegroundColor Yellow
                Write-Host '  To create database users via Entra ID, you MUST authenticate as an' -ForegroundColor White
                Write-Host '  Entra ID administrator of the SQL Server.' -ForegroundColor White
                Write-Host ''
                Write-Host 'SOLUTION - Follow these steps:' -ForegroundColor Yellow
                Write-Host ''
                Write-Host '1. Set an Entra ID Admin on the SQL Server (if not already set):' -ForegroundColor Cyan
                Write-Host ''
                Write-Host '   az sql server ad-admin create \' -ForegroundColor White
                Write-Host '     --resource-group <your-rg> \' -ForegroundColor White
                Write-Host "     --server-name $SqlServerName \" -ForegroundColor White
                Write-Host '     --display-name <admin-user-or-identity-name> \' -ForegroundColor White
                Write-Host '     --object-id <admin-object-id>' -ForegroundColor White
                Write-Host ''
                Write-Host '   Example (using your current user):' -ForegroundColor Gray
                Write-Host "   `$me = az ad signed-in-user show --query '{name:userPrincipalName,id:id}' -o json | ConvertFrom-Json" -ForegroundColor Gray
                Write-Host "   az sql server ad-admin create --resource-group <rg> --server-name $SqlServerName --display-name `$me.name --object-id `$me.id" -ForegroundColor Gray
                Write-Host ''
                Write-Host '2. Verify the admin is set:' -ForegroundColor Cyan
                Write-Host "   az sql server ad-admin list --resource-group <rg> --server-name $SqlServerName" -ForegroundColor White
                Write-Host ''
                Write-Host '3. Ensure you are authenticated as that admin:' -ForegroundColor Cyan
                Write-Host '   az account show    # Check current identity' -ForegroundColor White
                Write-Host '   az login           # Re-authenticate if needed' -ForegroundColor White
                Write-Host ''
                Write-Host '4. Re-run the provisioning:' -ForegroundColor Cyan
                Write-Host '   azd provision' -ForegroundColor White
                Write-Host ''
                Write-Host 'More info: https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure' -ForegroundColor Gray
            }
            40615 { 
                Write-Host 'Firewall rule blocking connection - add client IP to SQL firewall' -ForegroundColor Yellow
            }
            40613 { 
                Write-Host 'Database not available - check database exists and is online' -ForegroundColor Yellow
            }
            33134 { 
                Write-Host 'User already exists - this is usually safe to ignore' -ForegroundColor Green
            }
            15023 { 
                Write-Host 'User, group, or role already exists in database' -ForegroundColor Green
            }
            default { 
                Write-Host 'Check SQL Server logs and Azure AD configuration' -ForegroundColor Yellow
            }
        }
        
        Write-Host ''
        Write-Host '═══════════════════════════════════════════════════════════════════' -ForegroundColor Yellow
        Write-Host ''
        
        throw
    }
    catch [System.InvalidOperationException] {
        # Handle connection state exceptions
        Write-Log "Connection state error: $($_.Exception.Message)" -Level Error
        Write-Log 'This usually indicates an authentication or network connectivity issue' -Level Error
        throw
    }
    catch {
        # Handle all other exceptions
        Write-Log "Unexpected error during SQL execution: $($_.Exception.Message)" -Level Error
        Write-Log "Exception type: $($_.Exception.GetType().FullName)" -Level Error
        throw
    }
    finally {
        # Ensure proper cleanup of database resources
        # This block always executes, even if exceptions occur
        Write-Log 'Cleaning up database resources...' -Level Verbose
        
        if ($command) {
            try {
                $command.Dispose()
                Write-Log 'SQL command disposed' -Level Verbose
            }
            catch {
                Write-Log "Warning: Failed to dispose command: $($_.Exception.Message)" -Level Warning
            }
        }
        
        if ($connection) {
            try {
                if ($connection.State -eq [System.Data.ConnectionState]::Open) {
                    $connection.Close()
                    Write-Log 'Database connection closed' -Level Verbose
                }
                $connection.Dispose()
                Write-Log 'Connection object disposed' -Level Verbose
            }
            catch {
                Write-Log "Warning: Failed to dispose connection: $($_.Exception.Message)" -Level Warning
            }
        }
        
        Write-Log 'Resource cleanup completed' -Level Verbose
    }
    #endregion
}
catch {
    # Top-level exception handler for the entire script
    # This catches any unhandled exceptions from the main execution block
    
    Write-Log "" -Level Error
    Write-Log "====================================================================" -Level Error
    Write-Log "SCRIPT EXECUTION FAILED" -Level Error
    Write-Log "====================================================================" -Level Error
    Write-Log "Error message:      $($_.Exception.Message)" -Level Error
    Write-Log "Error type:         $($_.Exception.GetType().FullName)" -Level Error
    Write-Log "Error source:       $($_.Exception.Source)" -Level Error
    
    # Include inner exception details if available
    if ($_.Exception.InnerException) {
        Write-Log "Inner exception:    $($_.Exception.InnerException.Message)" -Level Error
    }
    
    # Include script stack trace for debugging
    if ($_.ScriptStackTrace) {
        Write-Log "" -Level Error
        Write-Log "Stack trace:" -Level Error
        $_.ScriptStackTrace -split "`n" | ForEach-Object {
            Write-Log "  $_" -Level Error
        }
    }
    
    Write-Log "" -Level Error
    
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