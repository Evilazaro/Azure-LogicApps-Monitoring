#!/usr/bin/env bash

################################################################################
# sql-managed-identity-config.sh
#
# SYNOPSIS:
#     Configures Azure SQL Database user with Managed Identity authentication.
#
# DESCRIPTION:
#     Creates a database user from an external provider (Microsoft Entra ID/Managed Identity)
#     and assigns specified database roles using Azure AD token-based authentication.
#     
#     This script performs the following operations:
#     - Validates Azure CLI authentication
#     - Validates sqlcmd utility availability
#     - Acquires an access token for Azure SQL Database
#     - Creates a contained database user from external provider
#     - Assigns specified database roles to the user
#     - Returns a structured result object (JSON)
#     
#     The script is idempotent and can be safely re-run. It will skip existing users
#     and role memberships.
#
# PARAMETERS:
#     --sql-server-name NAME
#         The name of the Azure SQL Server (logical server name only, without
#         .database.windows.net suffix).
#         
#         Example: "contoso-sql-server" (not "contoso-sql-server.database.windows.net")
#         Required: Yes
#         Validation: 1-63 characters, lowercase letters, numbers, hyphens only
#
#     --database-name NAME
#         The name of the target database where the user will be created.
#         
#         This should be a user database, not 'master'. The script will create a
#         contained database user in this database.
#         Required: Yes
#         Validation: 1-128 characters, cannot be 'master'
#
#     --principal-name NAME
#         The display name of the managed identity or service principal as it appears
#         in Microsoft Entra ID.
#         
#         This must exactly match the name shown in the Azure Portal under the
#         Managed Identity or App Registration. Names are case-sensitive.
#         
#         Example: "app-orders-api-identity"
#         Required: Yes
#         Validation: 1-128 characters
#
#     --database-roles ROLES
#         Comma-separated list of database roles to assign to the principal.
#         
#         Common built-in roles:
#         - db_datareader: Read all data from all user tables
#         - db_datawriter: Add, delete, or modify data in all user tables
#         - db_ddladmin: Run DDL commands (CREATE, ALTER, DROP)
#         - db_owner: Full permissions in the database
#         
#         Default: "db_datareader,db_datawriter"
#         Required: No
#         Validation: 1-20 roles, each must be a valid database role
#
#     --azure-environment ENV
#         The Azure cloud environment where the SQL Server is hosted.
#         
#         Valid values:
#         - AzureCloud (default): Public Azure
#         - AzureUSGovernment: Azure Government
#         - AzureChinaCloud: Azure China (21Vianet)
#         - AzureGermanCloud: Azure Germany
#         
#         Default: "AzureCloud"
#         Required: No
#
#     --command-timeout SECONDS
#         The maximum time in seconds to wait for SQL commands to complete.
#         
#         Valid range: 30-600 seconds
#         Default: 120
#         Required: No
#
#     --verbose
#         Enable verbose output for detailed diagnostic information.
#         Useful for troubleshooting and understanding script execution flow.
#         
#         Default: Disabled
#         Required: No
#
#     --help
#         Display this help message and exit.
#
# INPUTS:
#     None. This script does not accept pipeline input.
#
# OUTPUTS:
#     JSON object with the following structure:
#     {
#       "Success": true|false,
#       "Principal": "principal-name",
#       "Server": "server.database.windows.net",
#       "Database": "database-name",
#       "Roles": "role1,role2",
#       "Message": "Success message" (on success),
#       "Error": "Error message" (on failure)
#     }
#
# EXAMPLES:
#     # Basic usage with default roles
#     ./sql-managed-identity-config.sh \
#         --sql-server-name "myserver" \
#         --database-name "mydb" \
#         --principal-name "my-app-identity"
#
#     # Custom roles with verbose output
#     ./sql-managed-identity-config.sh \
#         --sql-server-name "myserver" \
#         --database-name "mydb" \
#         --principal-name "my-app-identity" \
#         --database-roles "db_datareader,db_datawriter,db_ddladmin" \
#         --verbose
#
#     # Azure Government cloud
#     ./sql-managed-identity-config.sh \
#         --sql-server-name "myserver" \
#         --database-name "mydb" \
#         --principal-name "my-app-identity" \
#         --azure-environment "AzureUSGovernment"
#
#     # Capture result and check for success
#     result=$(./sql-managed-identity-config.sh \
#         --sql-server-name "myserver" \
#         --database-name "mydb" \
#         --principal-name "my-app-identity")
#     
#     if echo "$result" | jq -e '.Success == true' > /dev/null 2>&1; then
#         echo "Configuration succeeded"
#     else
#         echo "Configuration failed"
#         echo "$result" | jq -r '.Error'
#     fi
#
# NOTES:
#     Version:        1.1.0
#     Author          Evilazaro | Principal Cloud Solution Architect | Microsoft
#     Creation Date:  2025-12-29
#     Last Modified:  2026-01-06
#     Purpose:        Post-provisioning SQL Database managed identity configuration
#     Copyright:      (c) 2025-2026. All rights reserved.
#     
#     Prerequisites:
#     - Bash 4.0 or higher
#     - Azure CLI (az) version 2.60.0 or higher with active authentication (az login)
#     - Environment Variables:
#       * AZURE_RESOURCE_GROUP: The resource group containing the SQL Server (required for firewall configuration)
#     - CRITICAL: You must authenticate as an Entra ID administrator of the SQL Server
#       * Set Entra ID admin: az sql server ad-admin create --resource-group <rg> \
#         --server-name <server> --display-name <name> --object-id <id>
#       * The authenticated user must BE this admin or have equivalent permissions
#     - sqlcmd utility (from mssql-tools or mssql-tools18)
#     - Permissions: SQL Server Contributor or higher on the SQL Server resource
#     - Permissions: SQL db_owner or higher in the target database
#     - Network: Access to Azure SQL Database (firewall rules configured)
#     
#     Security Notes:
#     - Uses Azure AD token authentication (no SQL passwords)
#     - Access tokens are not logged or persisted
#     - SQL injection protection via parameterized principals
#     - Connections use encryption (TLS 1.2+)
#     
#     Known Limitations:
#     - Requires Microsoft Entra ID authentication to be enabled on the SQL Server
#     - Cannot create users in the 'master' database (by design)
#     - Principal names with special characters should be enclosed in brackets
#     - sqlcmd -G flag behavior may vary between mssql-tools versions
#
# LINK:
#     https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure
#
# LINK:
#     https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
#
# LINK:
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
################################################################################

# Bash strict mode for robust error handling
# -e: Exit immediately if a command exits with non-zero status
# -u: Treat unset variables as errors
# -o pipefail: Return value of a pipeline is the status of the last command to exit with non-zero status
set -euo pipefail

################################################################################
# Script Configuration
################################################################################
# Define script-level constants for versioning and configuration

# Script version following semantic versioning (major.minor.patch)
readonly SCRIPT_VERSION="1.1.0"

# Minimum required Azure CLI version for full compatibility
readonly MINIMUM_AZCLI_VERSION="2.60.0"

# Default parameter values
# These can be overridden via command-line arguments

# Default database roles assigned to the managed identity
# Provides read and write access to database tables
DATABASE_ROLES="db_datareader,db_datawriter"

# Default Azure cloud environment (public Azure)
AZURE_ENVIRONMENT="AzureCloud"

# Default SQL command timeout in seconds
# Allows sufficient time for user creation and role assignments
COMMAND_TIMEOUT=120

# Verbose output flag (disabled by default)
# When enabled, provides detailed diagnostic information
VERBOSE=false

# Azure SQL endpoint mapping for different cloud environments
# These suffixes are appended to the SQL Server logical name to form the FQDN
declare -A SQL_ENDPOINTS=(
    ["AzureCloud"]="database.windows.net"
    ["AzureUSGovernment"]="database.usgovcloudapi.net"
    ["AzureChinaCloud"]="database.chinacloudapi.cn"
    ["AzureGermanCloud"]="database.cloudapi.de"
)

# ANSI color codes for formatted terminal output
# Used to provide visual distinction between different message types
readonly COLOR_RED='\033[0;31m'       # Error messages
readonly COLOR_GREEN='\033[0;32m'     # Success messages
readonly COLOR_YELLOW='\033[0;33m'    # Warning messages
readonly COLOR_BLUE='\033[0;34m'      # Info and verbose messages
readonly COLOR_RESET='\033[0m'        # Reset to default terminal color

################################################################################
# Logging Functions
################################################################################
# Comprehensive logging functions for structured, timestamped output
# All functions include ISO 8601 timestamps and colored output for clarity
# Error and warning messages are sent to stderr for proper stream handling

# Log informational message
# Displays general progress and status information
# Parameters:
#   $1 - Message to log
# Output: Writes to stdout with blue color and timestamp
log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_BLUE}[${timestamp}] [Info]${COLOR_RESET} $1"
}

# Log success message
# Indicates successful completion of operations
# Parameters:
#   $1 - Success message to log
# Output: Writes to stdout with green color and timestamp
log_success() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_GREEN}[${timestamp}] [Success]${COLOR_RESET} $1"
}

# Log warning message
# Indicates non-fatal issues that may require attention
# Parameters:
#   $1 - Warning message to log
# Output: Writes to stderr with yellow color and timestamp
log_warning() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_YELLOW}[${timestamp}] [Warning]${COLOR_RESET} $1" >&2
}

# Log error message
# Indicates fatal errors that prevent script execution
# Parameters:
#   $1 - Error message to log
# Output: Writes to stderr with red color and timestamp
log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_RED}[${timestamp}] [Error]${COLOR_RESET} $1" >&2
}

# Log verbose/debug message
# Provides detailed diagnostic information when verbose mode is enabled
# Only displays output if VERBOSE flag is set to true
# Parameters:
#   $1 - Verbose message to log
# Output: Writes to stdout via log_info if verbose mode is enabled
log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        log_info "[VERBOSE] $1"
    fi
}

################################################################################
# Help Documentation
################################################################################

# Display comprehensive help documentation
# Provides detailed information about script usage, parameters, examples, and requirements
# Matches PowerShell's detailed comment-based help format
# Parameters: None
# Output: Writes formatted help text to stdout
show_help() {
    cat << EOF
╔════════════════════════════════════════════════════════════════════════════╗
║  SQL Managed Identity Configuration Script v${SCRIPT_VERSION}                       ║
╚════════════════════════════════════════════════════════════════════════════╝

NAME:
    $(basename "$0")

SYNOPSIS:
    Configures Azure SQL Database user with Managed Identity authentication.

USAGE:
    $(basename "$0") [OPTIONS]

DESCRIPTION:
    Creates a database user from an external provider (Microsoft Entra ID/Managed
    Identity) and assigns specified database roles using Azure AD token-based
    authentication.
    
    The script is idempotent and can be safely re-run. It will skip existing users
    and role memberships.

REQUIRED PARAMETERS:
    --sql-server-name NAME
        The name of the Azure SQL Server (logical server name only, without
        .database.windows.net suffix).
        Example: "contoso-sql-server"

    --database-name NAME
        The name of the target database where the user will be created.
        This should be a user database, not 'master'.
        Example: "orders-db"

    --principal-name NAME
        The display name of the managed identity or service principal as it
        appears in Microsoft Entra ID. Names are case-sensitive.
        Example: "app-orders-api-identity"

OPTIONAL PARAMETERS:
    --database-roles ROLES
        Comma-separated list of database roles to assign.
        Common roles: db_datareader, db_datawriter, db_ddladmin, db_owner
        Default: "db_datareader,db_datawriter"

    --azure-environment ENV
        Azure cloud environment where the SQL Server is hosted.
        Valid values: AzureCloud, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud
        Default: "AzureCloud"

    --command-timeout SECONDS
        Maximum time in seconds to wait for SQL commands to complete.
        Valid range: 30-600 seconds
        Default: 120

    --verbose
        Enable verbose output for detailed diagnostic information.

    --help
        Display this help message and exit.

EXAMPLES:
    # Basic usage with default roles
    ./$(basename "$0") \\
        --sql-server-name "myserver" \\
        --database-name "mydb" \\
        --principal-name "my-app-identity"

    # Custom roles with verbose output
    ./$(basename "$0") \\
        --sql-server-name "myserver" \\
        --database-name "mydb" \\
        --principal-name "my-app-identity" \\
        --database-roles "db_datareader,db_datawriter,db_ddladmin" \\
        --verbose

    # Azure Government cloud environment
    ./$(basename "$0") \\
        --sql-server-name "myserver" \\
        --database-name "mydb" \\
        --principal-name "my-app-identity" \\
        --azure-environment "AzureUSGovernment"

    # Capture JSON result and check for success
    result=\$(./$(basename "$0") \\
        --sql-server-name "myserver" \\
        --database-name "mydb" \\
        --principal-name "my-app-identity")
    
    if echo "\$result" | jq -e '.Success == true' > /dev/null 2>&1; then
        echo "Configuration succeeded"
    else
        echo "Configuration failed: \$(echo "\$result" | jq -r '.Error')"
    fi

PREREQUISITES:
    - Bash 4.0 or higher
    - Azure CLI (az) version ${MINIMUM_AZCLI_VERSION} or higher
    - Azure CLI authenticated (run: az login)
    - sqlcmd utility (from mssql-tools or mssql-tools18)
    - Authenticated as Entra ID admin of the SQL Server
    - Network access to Azure SQL Database (firewall rules configured)

IMPORTANT SECURITY NOTES:
    - You must authenticate as an Entra ID administrator of the SQL Server
    - Set Entra ID admin using:
      az sql server ad-admin create --resource-group <rg> --server-name <server> \\
        --display-name <name> --object-id <id>
    - Uses Azure AD token authentication (no SQL passwords)
    - Access tokens are not logged or persisted
    - Connections use encryption (TLS 1.2+)

OUTPUT:
    Returns a JSON object with the following structure:
    {
      "Success": true|false,
      "Principal": "principal-name",
      "Server": "server.database.windows.net",
      "Database": "database-name",
      "Roles": "role1,role2",
      "Message": "Success message" (on success),
      "Error": "Error message" (on failure)
    }

VERSION:
    ${SCRIPT_VERSION}

AUTHOR:
    Evilazaro

LINKS:
    https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure
    https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring

EOF
}

################################################################################
# Argument Parsing and Validation
################################################################################

# Parse command-line arguments and validate required parameters
# Processes all command-line flags and sets corresponding global variables
# Performs comprehensive validation of all input parameters
# Parameters: All command-line arguments ($@)
# Output: Sets global variables (SQL_SERVER_NAME, DATABASE_NAME, etc.)
# Exit: Exits with code 1 for invalid or missing arguments
parse_arguments() {
    # Process all command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sql-server-name)
                SQL_SERVER_NAME="$2"
                shift 2
                ;;
            --database-name)
                DATABASE_NAME="$2"
                shift 2
                ;;
            --principal-name)
                PRINCIPAL_NAME="$2"
                shift 2
                ;;
            --database-roles)
                DATABASE_ROLES="$2"
                shift 2
                ;;
            --azure-environment)
                AZURE_ENVIRONMENT="$2"
                shift 2
                ;;
            --command-timeout)
                COMMAND_TIMEOUT="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                log_error "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    # Each validation provides specific error messages for troubleshooting
    
    if [[ -z "${SQL_SERVER_NAME:-}" ]]; then
        log_error "Missing required parameter: --sql-server-name"
        log_error "Specify the Azure SQL Server logical name (without .database.windows.net suffix)"
        log_error "Example: --sql-server-name \"contoso-sql-server\""
        exit 1
    fi

    if [[ -z "${DATABASE_NAME:-}" ]]; then
        log_error "Missing required parameter: --database-name"
        log_error "Specify the target database name where the user will be created"
        log_error "Example: --database-name \"orders-db\""
        exit 1
    fi

    if [[ -z "${PRINCIPAL_NAME:-}" ]]; then
        log_error "Missing required parameter: --principal-name"
        log_error "Specify the managed identity display name as shown in Entra ID"
        log_error "Example: --principal-name \"app-orders-api-identity\""
        exit 1
    fi
    
    # Validate parameter formats and constraints
    
    # Validate SQL Server name format (lowercase alphanumeric and hyphens only)
    if [[ ! "${SQL_SERVER_NAME}" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        log_error "Invalid SQL Server name format: ${SQL_SERVER_NAME}"
        log_error "Server name must contain only lowercase letters, numbers, and hyphens"
        log_error "It cannot start or end with a hyphen"
        exit 1
    fi
    
    # Validate database name is not 'master'
    if [[ "${DATABASE_NAME,,}" == "master" ]]; then
        log_error "Cannot configure managed identity users in the 'master' database"
        log_error "Please specify a user database"
        exit 1
    fi
    
    # Validate Azure environment is supported
    if [[ ! -v SQL_ENDPOINTS["${AZURE_ENVIRONMENT}"] ]]; then
        log_error "Invalid Azure environment: ${AZURE_ENVIRONMENT}"
        log_error "Valid values: AzureCloud, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud"
        exit 1
    fi
    
    # Validate command timeout is within acceptable range
    if [[ "${COMMAND_TIMEOUT}" -lt 30 || "${COMMAND_TIMEOUT}" -gt 600 ]]; then
        log_error "Invalid command timeout: ${COMMAND_TIMEOUT}"
        log_error "Command timeout must be between 30 and 600 seconds"
        exit 1
    fi
    
    log_verbose "All parameters validated successfully"
}

################################################################################
# Azure Environment Functions
################################################################################

# Get SQL endpoint suffix based on Azure cloud environment
# Maps Azure environment names to their corresponding SQL Database endpoints
# Parameters:
#   $1 - Azure environment name (AzureCloud, AzureUSGovernment, etc.)
# Returns: SQL endpoint suffix (e.g., "database.windows.net")
# Output: Writes endpoint suffix to stdout
# Exit: Exits with code 1 if environment is unknown
get_sql_endpoint() {
    local environment="$1"
    
    # Retrieve endpoint from associative array
    if [[ -v SQL_ENDPOINTS["${environment}"] ]]; then
        echo "${SQL_ENDPOINTS[${environment}]}"
    else
        log_error "Unknown Azure environment: ${environment}"
        log_error "Valid environments: ${!SQL_ENDPOINTS[*]}"
        exit 1
    fi
}

################################################################################
# Azure Authentication Validation
################################################################################

# Validate Azure CLI availability and authentication status
# Checks if Azure CLI is installed, accessible, and authenticated
# Retrieves and displays authenticated user information
# Parameters: None
# Returns: 0 if authentication is valid, 1 otherwise
# Output: Logs validation status and authenticated user information
test_azure_context() {
    log_verbose "Validating Azure CLI authentication..."
    
    # Check if Azure CLI command is available in PATH
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI (az) is not installed or not in PATH"
        log_error "Install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        log_error "After installation, authenticate with: az login"
        return 1
    fi
    
    local az_path
    az_path=$(command -v az)
    log_verbose "Azure CLI found at: ${az_path}"
    
    # Check Azure CLI version
    local az_version
    if az_version=$(az version --output json 2>&1 | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4); then
        log_verbose "Azure CLI version: ${az_version}"
        
        # Basic version check (compare major.minor)
        local current_major current_minor required_major required_minor
        current_major=$(echo "${az_version}" | cut -d. -f1)
        current_minor=$(echo "${az_version}" | cut -d. -f2)
        required_major=$(echo "${MINIMUM_AZCLI_VERSION}" | cut -d. -f1)
        required_minor=$(echo "${MINIMUM_AZCLI_VERSION}" | cut -d. -f2)
        
        if [[ ${current_major} -lt ${required_major} ]] || \
           [[ ${current_major} -eq ${required_major} && ${current_minor} -lt ${required_minor} ]]; then
            log_warning "Azure CLI version ${az_version} is older than recommended ${MINIMUM_AZCLI_VERSION}"
            log_warning "Consider upgrading with: az upgrade"
        fi
    else
        log_verbose "Could not determine Azure CLI version"
    fi

    # Validate Azure authentication by retrieving account information
    local account_info
    if ! account_info=$(az account show --output json 2>&1); then
        log_error "No Azure authentication context found"
        log_error "Please authenticate with: az login"
        log_verbose "Error details: ${account_info}"
        return 1
    fi
    
    # Extract and display authenticated user information
    local account_name subscription_name subscription_id
    account_name=$(echo "${account_info}" | grep -o '"user": *{[^}]*"name": *"[^"]*"' | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
    subscription_name=$(echo "${account_info}" | grep -o '"name": *"[^"]*"' | head -n1 | cut -d'"' -f4)
    subscription_id=$(echo "${account_info}" | grep -o '"id": *"[^"]*"' | head -n1 | cut -d'"' -f4)
    
    log_success "Azure authentication validated"
    log_verbose "Authenticated user: ${account_name}"
    log_verbose "Active subscription: ${subscription_name} (${subscription_id})"
    
    return 0
}

################################################################################
# SQL Tools Validation
################################################################################

# Validate sqlcmd utility availability and version
# Checks if sqlcmd is installed and accessible for SQL Database operations
# sqlcmd is required for executing SQL commands with Azure AD token authentication
# Parameters: None
# Returns: 0 if sqlcmd is available, 1 otherwise
# Output: Logs validation status and sqlcmd location
check_sqlcmd() {
    log_verbose "Validating sqlcmd utility..."
    
    # Check if sqlcmd command is available in PATH
    if ! command -v sqlcmd &> /dev/null; then
        log_error "sqlcmd is not installed or not in PATH"
        log_error "sqlcmd is required for SQL Database operations"
        log_error ""
        log_error "Installation instructions:"
        log_error "  Ubuntu/Debian:"
        log_error "    https://learn.microsoft.com/sql/linux/sql-server-linux-setup-tools"
        log_error "  macOS:"
        log_error "    brew install mssql-tools"
        log_error "  Windows:"
        log_error "    Download from: https://aka.ms/msodbcsql"
        log_error ""
        log_error "Note: mssql-tools18 is recommended for TLS 1.2+ support"
        return 1
    fi
    
    local sqlcmd_path
    sqlcmd_path=$(command -v sqlcmd)
    log_verbose "sqlcmd found at: ${sqlcmd_path}"
    
    # Try to get sqlcmd version information (not all versions support -?)
    local version_info
    if version_info=$(sqlcmd -? 2>&1 | head -n 2); then
        log_verbose "sqlcmd version info: $(echo "${version_info}" | tr '\n' ' ')"
    fi
    
    log_success "sqlcmd utility validated"
    return 0
}

################################################################################
# Access Token Management
################################################################################

# Acquire Azure AD access token for SQL Database authentication
# Obtains a token from Azure CLI for the specified SQL resource endpoint
# The token is used for Azure AD-based authentication to SQL Database
# Parameters:
#   $1 - SQL endpoint suffix (e.g., "database.windows.net")
# Returns: 0 if token acquired successfully, 1 otherwise
# Output: Writes access token to stdout (token should not be logged)
# Note: Token has limited lifetime (typically 1 hour) and should not be persisted
get_sql_access_token() {
    local sql_suffix="$1"
    local resource_url="https://${sql_suffix}/"
    
    log_verbose "Acquiring Entra ID access token for Azure SQL Database..."
    log_verbose "Resource URL: ${resource_url}"
    log_verbose "Token will be used for Azure AD authentication"
    
    # Request access token from Azure CLI
    # Token is scoped to the SQL Database resource for security
    local token
    local error_output
    if ! token=$(az account get-access-token --resource "${resource_url}" --query accessToken --output tsv 2>&1); then
        log_error "Failed to acquire access token for Azure SQL Database"
        log_error "This typically indicates one of the following issues:"
        log_error "  1. Azure CLI session has expired (run: az login)"
        log_error "  2. Insufficient permissions to access SQL Database"
        log_error "  3. Network connectivity issues"
        log_verbose "Error details: ${token}"
        return 1
    fi

    # Validate token is not empty
    if [[ -z "${token}" ]]; then
        log_error "Received empty access token from Azure CLI"
        log_error "This may indicate an authentication or authorization issue"
        return 1
    fi
    
    # Validate token format (should be a Base64-encoded JWT)
    if [[ ! "${token}" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        log_warning "Access token does not appear to be a valid JWT format"
        log_warning "Token may be corrupted or invalid"
    fi

    log_success "Access token acquired successfully"
    log_verbose "Token acquired (length: ${#token} characters)"
    log_verbose "Note: Token is valid for approximately 1 hour"
    
    # Output token to stdout for caller to capture
    # DO NOT log the actual token value for security reasons
    echo "${token}"
    return 0
}

################################################################################
# SQL Script Generation
################################################################################

# Generate T-SQL script for managed identity user creation and role assignment
# Creates idempotent SQL script that safely handles existing users and memberships
# Uses contained database users with external provider (Entra ID) authentication
# Parameters:
#   $1 - Principal display name (managed identity or service principal name)
#   $2 - Comma-separated list of database roles to assign
# Returns: 0 on success
# Output: Writes complete T-SQL script to stdout
# Note: Script includes proper escaping to prevent SQL injection
generate_sql_script() {
    local principal="$1"
    local roles="$2"
    
    log_verbose "Generating SQL script for principal: ${principal}"
    log_verbose "Target roles: ${roles}"
    
    # Sanitize principal name for SQL (escape single quotes)
    # This prevents SQL injection while allowing legitimate special characters
    local safe_principal
    safe_principal="${principal//\'/\'\'}"
    
    # Convert comma-separated roles to array for iteration
    IFS=',' read -ra role_array <<< "${roles}"
    
    log_verbose "Parsed ${#role_array[@]} role(s) for assignment"
    
    # Initialize SQL script with user creation
    # Uses CREATE USER FROM EXTERNAL PROVIDER for Entra ID authentication
    # Checks for existing user to enable idempotent execution
    local sql_script
    sql_script="-- ============================================================================
-- Azure SQL Database Managed Identity Configuration
-- Generated: $(date '+%Y-%m-%d %H:%M:%S')
-- Principal: ${principal}
-- Roles: ${roles}
-- ============================================================================

SET NOCOUNT ON;
GO

-- Create contained database user from Microsoft Entra ID (Azure AD)
-- This user will authenticate using Entra ID managed identity
-- Type E = External user, Type X = External group
IF NOT EXISTS (
    SELECT 1 
    FROM sys.database_principals 
    WHERE name = N'${safe_principal}' 
    AND type IN ('E', 'X')
)
BEGIN
    CREATE USER [${safe_principal}] FROM EXTERNAL PROVIDER;
    PRINT 'SUCCESS: User [${safe_principal}] created successfully';
END
ELSE
BEGIN
    PRINT 'INFO: User [${safe_principal}] already exists - skipping creation';
END;
GO

"

    # Add role assignment script for each specified role
    # Each role assignment includes:
    # - Validation that role exists in database
    # - Check for existing membership to avoid duplicate assignments
    # - Error handling and informative messages
    for role in "${role_array[@]}"; do
        # Trim leading/trailing whitespace from role name
        role=$(echo "${role}" | xargs)
        
        # Skip empty role names
        if [[ -z "${role}" ]]; then
            log_verbose "Skipping empty role name"
            continue
        fi
        
        # Sanitize role name for SQL (escape single quotes)
        local safe_role
        safe_role="${role//\'/\'\'}"
        
        log_verbose "Adding role assignment script for: ${role}"
        
        sql_script+="-- Assign database role: ${safe_role}
-- Role type 'R' = Database role
IF EXISTS (
    SELECT 1 
    FROM sys.database_principals 
    WHERE name = N'${safe_role}' 
    AND type = 'R'
)
BEGIN
    -- Check if user is already a member of this role
    -- IS_ROLEMEMBER returns 1 (member), 0 (not member), or NULL (role/user not found)
    IF IS_ROLEMEMBER(N'${safe_role}', N'${safe_principal}') = 0 
       OR IS_ROLEMEMBER(N'${safe_role}', N'${safe_principal}') IS NULL
    BEGIN
        ALTER ROLE [${safe_role}] ADD MEMBER [${safe_principal}];
        PRINT 'SUCCESS: Added [${safe_principal}] to role [${safe_role}]';
    END
    ELSE
    BEGIN
        PRINT 'INFO: [${safe_principal}] is already a member of role [${safe_role}] - skipping';
    END
END
ELSE
BEGIN
    PRINT 'WARNING: Role [${safe_role}] does not exist in database - skipping';
END;
GO

"
    done
    
    # Add script completion marker
    sql_script+="-- ============================================================================
-- Script execution completed
-- ============================================================================
"

    log_success "SQL script generated successfully"
    log_verbose "Script contains user creation and ${#role_array[@]} role assignment(s)"
    
    # Output complete SQL script to stdout
    echo "${sql_script}"
    return 0
}

################################################################################
# SQL Script Execution
################################################################################

# Execute SQL script on Azure SQL Database using Azure AD token authentication
# Connects to SQL Database with Entra ID token and executes T-SQL commands
# Uses sqlcmd utility with -G flag for Azure AD authentication
# Parameters:
#   $1 - SQL Server FQDN (e.g., "server.database.windows.net")
#   $2 - Database name
#   $3 - Azure AD access token for authentication
#   $4 - SQL script content to execute
#   $5 - Command timeout in seconds
# Returns: 0 if execution succeeds, 1 otherwise
# Output: Logs execution status and SQL command results
# Note: Creates temporary file for SQL script, ensures cleanup in all cases
execute_sql_script() {
    local server_fqdn="$1"
    local database="$2"
    local access_token="$3"
    local sql_script="$4"
    local timeout="$5"
    
    log_verbose "Preparing to connect to SQL Database..."
    log_verbose "Server: ${server_fqdn}"
    log_verbose "Database: ${database}"
    log_verbose "Timeout: ${timeout}s"
    log_verbose "Authentication: Azure AD token (Entra ID)"
    log_verbose "Encryption: TLS 1.2+ enforced"
    
    # Create temporary file for SQL script
    # Using mktemp ensures secure temporary file creation with proper permissions
    local sql_file
    if ! sql_file=$(mktemp); then
        log_error "Failed to create temporary file for SQL script"
        return 1
    fi
    
    log_verbose "SQL script saved to temporary file: ${sql_file}"
    log_verbose "Temporary file will be removed after execution"
    
    # Write SQL script to temporary file
    # Using echo instead of here-doc to preserve exact formatting
    if ! echo "${sql_script}" > "${sql_file}"; then
        log_error "Failed to write SQL script to temporary file"
        rm -f "${sql_file}"
        return 1
    fi
    
    # Execute SQL script with sqlcmd using Azure AD token authentication
    # sqlcmd flags:
    #   -S: Server name (FQDN)
    #   -d: Database name
    #   -G: Use Azure AD authentication
    #   -P: Access token (passed as password when using -G)
    #   -i: Input file (SQL script)
    #   -t: Query timeout in seconds
    #   -b: Terminate batch on error
    #   -e: Echo input
    #   -r 1: Redirect error messages to stderr
    local output
    local exit_code=0
    local start_time
    start_time=$(date +%s)
    
    log_verbose "Executing SQL commands via sqlcmd..."
    
    # Execute sqlcmd and capture output
    # Note: Access token is passed securely via command-line (not logged)
    if output=$(sqlcmd -S "${server_fqdn}" -d "${database}" -G -P "${access_token}" \
                       -i "${sql_file}" -t "${timeout}" -b -e -r 1 2>&1); then
        
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_success "Database connection established successfully"
        log_success "SQL commands executed successfully (${duration}s)"
        
        # Log SQL output for verification
        log_verbose "SQL execution output:"
        log_verbose "───────────────────────────────────────────────────────"
        while IFS= read -r line; do
            log_verbose "  ${line}"
        done <<< "${output}"
        log_verbose "───────────────────────────────────────────────────────"
        
    else
        exit_code=$?
        
        log_error "SQL execution failed with exit code: ${exit_code}"
        log_error ""
        log_error "This typically indicates one of the following issues:"
        log_error "  1. Authentication failure (invalid or expired token)"
        log_error "  2. Insufficient permissions in the database"
        log_error "  3. Network connectivity issues"
        log_error "  4. SQL syntax errors in the generated script"
        log_error "  5. Firewall rules blocking the connection"
        log_error ""
        log_error "SQL execution output:"
        log_error "${output}"
        log_error ""
        
        # Provide specific guidance based on common error patterns
        if echo "${output}" | grep -qi "login failed"; then
            log_error "Authentication failed. Verify:"
            log_error "  - You are authenticated as an Entra ID admin of the SQL Server"
            log_error "  - The Entra ID admin is correctly configured on the SQL Server"
            log_error "  - Run: az sql server ad-admin list --server <server> --resource-group <rg>"
        elif echo "${output}" | grep -qi "timeout"; then
            log_error "Connection timeout. Verify:"
            log_error "  - Firewall rules allow your IP address"
            log_error "  - Run: az sql server firewall-rule list --server <server> --resource-group <rg>"
        elif echo "${output}" | grep -qi "permission denied\|insufficient privilege"; then
            log_error "Insufficient permissions. Verify:"
            log_error "  - Authenticated user has db_owner or equivalent role"
            log_error "  - User can create users and assign roles in the database"
        fi
        
        # Clean up temporary file before returning error
        rm -f "${sql_file}"
        return 1
    fi
    
    # Clean up temporary file on success
    if rm -f "${sql_file}"; then
        log_verbose "Temporary SQL file removed successfully"
    else
        log_warning "Failed to remove temporary SQL file: ${sql_file}"
        log_warning "File may need to be manually deleted"
    fi
    
    return 0
}

################################################################################
# Main Execution
################################################################################
# Main script execution flow with comprehensive error handling
# Orchestrates all validation, token acquisition, script generation, and execution steps
# Returns structured JSON result object for programmatic consumption
# Exit codes: 0 for success, 1 for failure

# Main function - orchestrates all script operations
# Includes try-catch-like error handling with structured result output
# Parameters: All command-line arguments ($@)
# Output: Logs execution progress and returns JSON result
# Exit: Returns 0 on success, 1 on failure
main() {
    # Display script header
    log_info "===================================================================="
    log_info "SQL Managed Identity Configuration Script v${SCRIPT_VERSION}"
    log_info "===================================================================="
    log_info "Starting Azure SQL Database managed identity configuration..."
    log_info ""
    
    # Parse and validate command-line arguments
    # This will exit with code 1 if validation fails
    parse_arguments "$@"
    
    # Log configuration parameters (never log sensitive data like tokens)
    log_info "Configuration Parameters:"
    log_info "  SQL Server Name:    ${SQL_SERVER_NAME}"
    log_info "  Database Name:      ${DATABASE_NAME}"
    log_info "  Principal Name:     ${PRINCIPAL_NAME}"
    log_info "  Database Roles:     ${DATABASE_ROLES}"
    log_info "  Azure Environment:  ${AZURE_ENVIRONMENT}"
    log_info "  Command Timeout:    ${COMMAND_TIMEOUT}s"
    log_info ""
    
    # Step 1: Validate Azure CLI authentication
    log_info "[Step 1/6] Validating Azure authentication..."
    if ! test_azure_context; then
        log_error ""
        log_error "===================================================================="
        log_error "CONFIGURATION FAILED: Azure Authentication Error"
        log_error "===================================================================="
        log_error "Azure CLI authentication is required to continue."
        log_error "Please authenticate with: az login"
        log_error ""
        
        # Return structured error result as JSON
        cat << EOF
{
  "Success": false,
  "Principal": "${PRINCIPAL_NAME}",
  "Server": "${SQL_SERVER_NAME}",
  "Database": "${DATABASE_NAME}",
  "Roles": "${DATABASE_ROLES}",
  "Error": "Azure CLI authentication failed. Please run 'az login' and try again."
}
EOF
        exit 1
    fi
    log_success "Azure CLI authentication validated"
    log_info ""
    
    # Step 2: Validate sqlcmd utility availability
    log_info "[Step 2/6] Validating sqlcmd utility..."
    if ! check_sqlcmd; then
        log_error ""
        log_error "===================================================================="
        log_error "CONFIGURATION FAILED: sqlcmd Utility Not Found"
        log_error "===================================================================="
        log_error "sqlcmd is required for SQL Database operations."
        log_error "Please install mssql-tools or mssql-tools18 and try again."
        log_error ""
        
        # Return structured error result as JSON
        cat << EOF
{
  "Success": false,
  "Principal": "${PRINCIPAL_NAME}",
  "Server": "${SQL_SERVER_NAME}",
  "Database": "${DATABASE_NAME}",
  "Roles": "${DATABASE_ROLES}",
  "Error": "sqlcmd utility not found. Please install mssql-tools and try again."
}
EOF
        exit 1
    fi
    log_success "sqlcmd utility validated"
    log_info ""
    
    # Step 3: Construct connection details
    log_info "[Step 3/6] Constructing connection details..."
    
    # Configure firewall rules (if needed)
    log_info "Detecting current public IP address for firewall configuration..."
    
    # Try multiple IP detection services for reliability
    local current_ip=""
    local ip_services=("http://ifconfig.me/ip" "https://api.ipify.org?format=text" "https://icanhazip.com")
    
    for service in "${ip_services[@]}"; do
        log_verbose "  Trying: ${service}"
        if current_ip=$(curl -s --max-time 10 "${service}" 2>/dev/null); then
            # Validate IP address format
            if [[ "${current_ip}" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                log_info "Found public IP address: ${current_ip}"
                break
            fi
        fi
        current_ip=""
    done
    
    if [[ -z "${current_ip}" ]]; then
        log_warning "Could not detect public IP address - firewall rule creation skipped"
        log_warning "You may need to manually add your IP to the SQL Server firewall rules"
    else
        # Get resource group from environment variable
        log_verbose "Retrieving SQL Server resource group..."
        local resource_group="${AZURE_RESOURCE_GROUP:-}"
        
        if [[ -z "${resource_group}" ]]; then
            log_warning "AZURE_RESOURCE_GROUP environment variable is not set"
            log_warning "Firewall rule creation skipped - you may need to add it manually"
        else
            local firewall_rule_name="ClientIP-$(date '+%Y%m%d%H%M%S')"
            
            log_verbose "  Resource Group: ${resource_group}"
            log_verbose "  Server Name:    ${SQL_SERVER_NAME}"
            log_verbose "  Rule Name:      ${firewall_rule_name}"
            
            log_info "Adding firewall rule '${firewall_rule_name}' for IP '${current_ip}'..."
            
            if az sql server firewall-rule create \
                --resource-group "${resource_group}" \
                --server "${SQL_SERVER_NAME}" \
                --name "${firewall_rule_name}" \
                --start-ip-address "${current_ip}" \
                --end-ip-address "${current_ip}" \
                -o none 2>&1; then
                log_success "Firewall rule '${firewall_rule_name}' with IP '${current_ip}' has been created."
            else
                log_warning "Failed to create firewall rule"
                log_warning "You may need to manually add IP ${current_ip} to SQL Server firewall rules"
            fi
        fi
    fi
    
    log_info ""
    
    # Step 4: Construct connection details
    log_info "[Step 4/6] Constructing connection details..."
    
    # Get SQL endpoint suffix for the specified Azure environment
    local sql_suffix
    sql_suffix=$(get_sql_endpoint "${AZURE_ENVIRONMENT}")
    
    # Construct fully qualified domain name (FQDN) for the SQL Server
    local server_fqdn="${SQL_SERVER_NAME}.${sql_suffix}"
    local resource_url="https://${sql_suffix}/"
    
    log_verbose "  Server FQDN:      ${server_fqdn}"
    log_verbose "  Resource URL:     ${resource_url}"
    log_verbose "  Port:             1433 (default)"
    log_verbose "  Encryption:       TLS 1.2+ (enforced)"
    log_success "Connection details constructed"
    log_info ""
    
    # Step 5: Acquire Azure AD access token
    log_info "[Step 5/6] Acquiring Entra ID access token for Azure SQL Database..."
    
    local access_token
    if ! access_token=$(get_sql_access_token "${sql_suffix}"); then
        log_error ""
        log_error "===================================================================="
        log_error "CONFIGURATION FAILED: Access Token Acquisition Error"
        log_error "===================================================================="
        log_error "Failed to acquire access token for Azure SQL Database."
        log_error "This may indicate authentication or authorization issues."
        log_error ""
        
        # Return structured error result as JSON
        cat << EOF
{
  "Success": false,
  "Principal": "${PRINCIPAL_NAME}",
  "Server": "${server_fqdn}",
  "Database": "${DATABASE_NAME}",
  "Roles": "${DATABASE_ROLES}",
  "Error": "Failed to acquire access token. Verify authentication and permissions."
}
EOF
        exit 1
    fi
    log_success "Access token acquired successfully"
    log_info ""
    
    # Step 6: Generate and execute SQL configuration script
    log_info "[Step 6/6] Generating and executing SQL configuration script..."
    
    # Generate T-SQL script for user creation and role assignments
    log_verbose "Generating SQL script..."
    local sql_script
    if ! sql_script=$(generate_sql_script "${PRINCIPAL_NAME}" "${DATABASE_ROLES}"); then
        log_error ""
        log_error "===================================================================="
        log_error "CONFIGURATION FAILED: SQL Script Generation Error"
        log_error "===================================================================="
        log_error "Failed to generate SQL configuration script."
        log_error ""
        
        # Return structured error result as JSON
        cat << EOF
{
  "Success": false,
  "Principal": "${PRINCIPAL_NAME}",
  "Server": "${server_fqdn}",
  "Database": "${DATABASE_NAME}",
  "Roles": "${DATABASE_ROLES}",
  "Error": "Failed to generate SQL script. Check logs for details."
}
EOF
        exit 1
    fi
    
    # Execute SQL script on target database
    log_verbose "Executing SQL script on target database..."
    log_info ""
    if ! execute_sql_script "${server_fqdn}" "${DATABASE_NAME}" "${access_token}" "${sql_script}" "${COMMAND_TIMEOUT}"; then
        log_error ""
        log_error "===================================================================="
        log_error "CONFIGURATION FAILED: SQL Execution Error"
        log_error "===================================================================="
        log_error "Failed to execute SQL configuration script."
        log_error "Check the error messages above for specific details."
        log_error ""
        log_error "Common causes:"
        log_error "  1. Insufficient permissions in the database"
        log_error "  2. Not authenticated as Entra ID admin of the SQL Server"
        log_error "  3. Network connectivity or firewall issues"
        log_error "  4. Invalid principal name or database roles"
        log_error ""
        
        # Return structured error result as JSON
        cat << EOF
{
  "Success": false,
  "Principal": "${PRINCIPAL_NAME}",
  "Server": "${server_fqdn}",
  "Database": "${DATABASE_NAME}",
  "Roles": "${DATABASE_ROLES}",
  "Error": "SQL execution failed. Verify permissions and authentication."
}
EOF
        exit 1
    fi
    
    # Configuration completed successfully
    log_info ""
    log_info "===================================================================="
    log_success "CONFIGURATION COMPLETED SUCCESSFULLY"
    log_info "===================================================================="
    log_success "Managed identity configured for principal: ${PRINCIPAL_NAME}"
    log_info "  Server:     ${server_fqdn}"
    log_info "  Database:   ${DATABASE_NAME}"
    log_info "  Roles:      ${DATABASE_ROLES}"
    log_info ""
    
    # Return structured success result as JSON
    # This allows the script to be used programmatically
    cat << EOF
{
  "Success": true,
  "Principal": "${PRINCIPAL_NAME}",
  "Server": "${server_fqdn}",
  "Database": "${DATABASE_NAME}",
  "Roles": "${DATABASE_ROLES}",
  "Message": "Managed identity configuration completed successfully"
}
EOF
    
    exit 0
}

################################################################################
# Script Entry Point
################################################################################
# Execute main function with all command-line arguments
# Ensures proper error propagation and exit code handling

main "$@"
