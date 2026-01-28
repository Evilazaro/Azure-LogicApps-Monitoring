/*
  ============================================================================
  Module:       SQL User Configuration Deployment Script
  Repository:   Evilazaro/Azure-LogicApps-Monitoring
  ============================================================================

  Description:
    This Bicep module deploys an Azure Deployment Script that configures a
    managed identity user in Azure SQL Database. The script runs INSIDE Azure's
    network, allowing it to access SQL Server even when public network access
    is disabled by Azure Policy.

  Why Deployment Script?
    - SQL Server has public network access disabled (Azure Policy)
    - GitHub Actions runners cannot connect from the public internet
    - Deployment scripts run inside Azure Container Instances within the VNet
    - Can access SQL Server via private endpoint or Azure backbone

  Operations:
    1. Creates a contained database user from the managed identity
    2. Assigns db_owner role for Entity Framework migrations
    3. Uses SID-based creation (Client ID) to bypass MS Graph lookup

  Security:
    - Uses managed identity authentication (no passwords)
    - Runs inside Azure's trusted network
    - Script container is ephemeral and deleted after execution

  Parameters:
    - sqlServerName: Name of the Azure SQL Server
    - sqlServerFqdn: Fully qualified domain name of SQL Server
    - databaseName: Name of the target database
    - managedIdentityName: Display name of the managed identity
    - managedIdentityClientId: Client ID of the managed identity
    - userAssignedIdentityId: Identity for the deployment script to use
    - location: Azure region for the deployment script
    - tags: Resource tags

  ============================================================================
*/

metadata name = 'SQL User Configuration'
metadata description = 'Deployment script to configure managed identity user in SQL Database'

// ========== Parameters ==========

@description('Name of the Azure SQL Server (without .database.windows.net)')
param sqlServerName string

@description('Fully qualified domain name of the SQL Server')
param sqlServerFqdn string

@description('Name of the database to configure')
param databaseName string

@description('Display name of the managed identity to add as user')
param managedIdentityName string

@description('Client ID (Application ID) of the managed identity')
param managedIdentityClientId string

@description('Resource ID of the user-assigned identity for the deployment script')
param userAssignedIdentityId string

@description('Azure region for the deployment script')
param location string

@description('Resource tags')
param tags object = {}

@description('Timestamp for force update (defaults to current UTC time)')
param forceUpdateTag string = utcNow()

@description('Name of the storage account for deployment script artifacts')
param storageAccountName string

// ========== Variables ==========

// Unique name for the deployment script
var deploymentScriptName = 'ds-sql-user-${uniqueString(resourceGroup().id, sqlServerName, databaseName)}'

// SQL Database resource URL for token acquisition (cloud-agnostic)
var sqlDatabaseResourceUrl = 'https://${environment().suffixes.sqlServerHostname}/'

// ========== Deployment Script ==========

@description('Deployment script to configure SQL database user')
resource sqlUserConfigScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: deploymentScriptName
  location: location
  tags: tags
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    azPowerShellVersion: '11.0'
    forceUpdateTag: forceUpdateTag
    retentionInterval: 'PT1H' // Retain logs for 1 hour
    timeout: 'PT30M' // 30 minute timeout
    cleanupPreference: 'OnSuccess'
    // Use managed identity authentication for storage account (required when key-based auth is disabled by policy)
    storageAccountSettings: {
      storageAccountName: storageAccountName
    }
    arguments: '-SqlServerFqdn "${sqlServerFqdn}" -DatabaseName "${databaseName}" -ManagedIdentityName "${managedIdentityName}" -ManagedIdentityClientId "${managedIdentityClientId}" -SqlResourceUrl "${sqlDatabaseResourceUrl}"'
    scriptContent: '''
      param(
        [string]$SqlServerFqdn,
        [string]$DatabaseName,
        [string]$ManagedIdentityName,
        [string]$ManagedIdentityClientId,
        [string]$SqlResourceUrl
      )

      $ErrorActionPreference = 'Stop'
      
      Write-Output "=============================================="
      Write-Output "SQL Database User Configuration"
      Write-Output "=============================================="
      Write-Output "Server: $SqlServerFqdn"
      Write-Output "Database: $DatabaseName"
      Write-Output "Managed Identity: $ManagedIdentityName"
      Write-Output "Client ID: $ManagedIdentityClientId"
      Write-Output "SQL Resource URL: $SqlResourceUrl"
      Write-Output ""

      # Get access token for Azure SQL using the deployment script's managed identity
      # Using the parameterized SQL resource URL for cloud-agnostic compatibility
      Write-Output "Acquiring access token for Azure SQL..."
      $encodedResource = [System.Uri]::EscapeDataString($SqlResourceUrl)
      $tokenResponse = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$encodedResource" -Headers @{Metadata='true'}
      $accessToken = $tokenResponse.access_token
      Write-Output "Access token acquired successfully"

      # Build connection string (using access token authentication)
      $connectionString = "Server=tcp:$SqlServerFqdn,1433;Database=$DatabaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

      # SQL script to create user with SID from Client ID
      # The SID must be derived from the Client ID (not Object ID) for managed identities
      $sqlScript = @"
      -- Calculate SID from Client ID
      DECLARE @expectedSid VARBINARY(16);
      SET @expectedSid = CAST(CAST('$ManagedIdentityClientId' AS UNIQUEIDENTIFIER) AS VARBINARY(16));

      -- Check if user exists
      IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'$ManagedIdentityName')
      BEGIN
          -- Verify SID matches
          DECLARE @existingSid VARBINARY(85);
          SELECT @existingSid = sid FROM sys.database_principals WHERE name = N'$ManagedIdentityName';
          
          IF @existingSid <> @expectedSid
          BEGIN
              PRINT 'Recreating user with correct SID...';
              DROP USER [$ManagedIdentityName];
              
              DECLARE @createSql NVARCHAR(MAX);
              SET @createSql = N'CREATE USER [$ManagedIdentityName] WITH SID = 0x' + 
                           CONVERT(VARCHAR(64), @expectedSid, 2) + 
                           N', TYPE = E';
              EXEC sp_executesql @createSql;
              PRINT 'User recreated with correct SID';
          END
          ELSE
          BEGIN
              PRINT 'User already exists with correct SID';
          END
      END
      ELSE
      BEGIN
          -- Create new user
          DECLARE @sql NVARCHAR(MAX);
          SET @sql = N'CREATE USER [$ManagedIdentityName] WITH SID = 0x' + 
                     CONVERT(VARCHAR(64), @expectedSid, 2) + 
                     N', TYPE = E';
          EXEC sp_executesql @sql;
          PRINT 'User created successfully';
      END;

      -- Add to db_owner role if not already a member
      IF NOT EXISTS (
          SELECT 1 FROM sys.database_role_members rm 
          JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id 
          JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id 
          WHERE r.name = 'db_owner' AND m.name = '$ManagedIdentityName'
      )
      BEGIN
          ALTER ROLE [db_owner] ADD MEMBER [$ManagedIdentityName];
          PRINT 'Added to db_owner role';
      END
      ELSE
      BEGIN
          PRINT 'Already member of db_owner role';
      END;

      -- Output verification
      SELECT 
          name,
          type_desc,
          authentication_type_desc,
          CONVERT(VARCHAR(64), sid, 2) as sid_hex
      FROM sys.database_principals 
      WHERE name = '$ManagedIdentityName';
"@

      Write-Output ""
      Write-Output "Executing SQL script..."
      Write-Output ""

      # Execute using SqlClient with access token
      try {
          $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
          $connection.AccessToken = $accessToken
          $connection.Open()
          
          $command = $connection.CreateCommand()
          $command.CommandText = $sqlScript
          $command.CommandTimeout = 120
          
          # Execute and capture output
          $reader = $command.ExecuteReader()
          
          # Read messages
          while ($reader.Read()) {
              Write-Output "User: $($reader['name']) | Type: $($reader['type_desc']) | Auth: $($reader['authentication_type_desc']) | SID: $($reader['sid_hex'])"
          }
          
          $reader.Close()
          $connection.Close()
          
          Write-Output ""
          Write-Output "=============================================="
          Write-Output "SQL user configuration completed successfully"
          Write-Output "=============================================="
          
          # Set output for Bicep
          $DeploymentScriptOutputs = @{}
          $DeploymentScriptOutputs['userCreated'] = $true
          $DeploymentScriptOutputs['managedIdentityName'] = $ManagedIdentityName
          $DeploymentScriptOutputs['database'] = $DatabaseName
      }
      catch {
          Write-Error "SQL execution failed: $_"
          throw
      }
    '''
  }
}

// ========== Outputs ==========

@description('Indicates whether the SQL user was configured successfully')
output userConfigured bool = true

@description('Name of the deployment script resource')
output deploymentScriptName string = sqlUserConfigScript.name
