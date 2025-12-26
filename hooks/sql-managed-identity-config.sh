#!/usr/bin/env bash
#
# sql-managed-identity-config.sh
#
# Configures Azure SQL Database user with Managed Identity authentication.
#
# DESCRIPTION:
#   Creates a database user from an external provider (Entra ID/Managed Identity)
#   and assigns specified database roles using Azure AD token authentication.
#
# PARAMETERS:
#   --sql-server-name       The name of the Azure SQL Server (without suffix)
#   --database-name         The name of the target database
#   --principal-name        The display name of the managed identity or service principal
#   --database-roles        Comma-separated list of database roles (default: db_datareader,db_datawriter)
#   --azure-environment     Azure environment (default: AzureCloud)
#   --command-timeout       SQL command timeout in seconds (default: 120)
#   --verbose               Enable verbose output
#   --help                  Show this help message
#
# EXAMPLE:
#   ./sql-managed-identity-config.sh \
#     --sql-server-name "myserver" \
#     --database-name "mydb" \
#     --principal-name "my-app-identity" \
#     --database-roles "db_datareader,db_datawriter"
#
# REQUIREMENTS:
#   - Azure CLI (az) installed and authenticated
#   - sqlcmd installed (from mssql-tools or mssql-tools18)
#

set -euo pipefail

# Default values
DATABASE_ROLES="db_datareader,db_datawriter"
AZURE_ENVIRONMENT="AzureCloud"
COMMAND_TIMEOUT=120
VERBOSE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[$timestamp] [Info]${NC} $1"
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[$timestamp] [Success]${NC} $1"
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[$timestamp] [Warning]${NC} $1" >&2
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[$timestamp] [Error]${NC} $1" >&2
}

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "$1"
    fi
}

# Show help message
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Configures Azure SQL Database user with Managed Identity authentication.

OPTIONS:
    --sql-server-name NAME      Azure SQL Server name (required)
    --database-name NAME        Database name (required)
    --principal-name NAME       Managed identity display name (required)
    --database-roles ROLES      Comma-separated database roles (default: db_datareader,db_datawriter)
    --azure-environment ENV     Azure environment (default: AzureCloud)
    --command-timeout SECONDS   SQL command timeout (default: 120)
    --verbose                   Enable verbose output
    --help                      Show this help message

EXAMPLES:
    # Basic usage
    ./sql-managed-identity-config.sh \\
        --sql-server-name "myserver" \\
        --database-name "mydb" \\
        --principal-name "my-app-identity"

    # Custom roles
    ./sql-managed-identity-config.sh \\
        --sql-server-name "myserver" \\
        --database-name "mydb" \\
        --principal-name "my-app-identity" \\
        --database-roles "db_datareader,db_datawriter,db_ddladmin"

REQUIREMENTS:
    - Azure CLI (az) installed and authenticated
    - sqlcmd installed (mssql-tools or mssql-tools18)

EOF
}

# Parse command line arguments
parse_arguments() {
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
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown parameter: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Validate required parameters
    if [[ -z "${SQL_SERVER_NAME:-}" ]]; then
        log_error "Missing required parameter: --sql-server-name"
        show_help
        exit 1
    fi

    if [[ -z "${DATABASE_NAME:-}" ]]; then
        log_error "Missing required parameter: --database-name"
        show_help
        exit 1
    fi

    if [[ -z "${PRINCIPAL_NAME:-}" ]]; then
        log_error "Missing required parameter: --principal-name"
        show_help
        exit 1
    fi
}

# Get SQL endpoint suffix based on Azure environment
get_sql_endpoint() {
    case "$AZURE_ENVIRONMENT" in
        AzureCloud)
            echo "database.windows.net"
            ;;
        AzureUSGovernment)
            echo "database.usgovcloudapi.net"
            ;;
        AzureChinaCloud)
            echo "database.chinacloudapi.cn"
            ;;
        AzureGermanCloud)
            echo "database.cloudapi.de"
            ;;
        *)
            log_error "Unknown Azure environment: $AZURE_ENVIRONMENT"
            exit 1
            ;;
    esac
}

# Test Azure CLI authentication
test_azure_context() {
    verbose "Validating Azure CLI authentication..."
    
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI (az) is not installed or not in PATH"
        return 1
    fi

    local account_info
    if ! account_info=$(az account show 2>&1); then
        log_error "No Azure context found. Please run 'az login' first."
        verbose "Error details: $account_info"
        return 1
    fi

    local account_name
    account_name=$(echo "$account_info" | grep -o '"user": *{[^}]*"name": *"[^"]*"' | grep -o '"name": *"[^"]*"' | cut -d'"' -f4)
    log_success "Azure context validated: $account_name"
    return 0
}

# Check if sqlcmd is available
check_sqlcmd() {
    verbose "Checking for sqlcmd utility..."
    
    if ! command -v sqlcmd &> /dev/null; then
        log_error "sqlcmd is not installed or not in PATH"
        log_error "Please install mssql-tools or mssql-tools18:"
        log_error "  Ubuntu/Debian: https://learn.microsoft.com/sql/linux/sql-server-linux-setup-tools"
        log_error "  macOS: brew install mssql-tools"
        return 1
    fi

    verbose "sqlcmd found: $(which sqlcmd)"
    return 0
}

# Get Azure AD access token for SQL
get_sql_access_token() {
    local sql_suffix="$1"
    local resource_url="https://${sql_suffix}/"
    
    verbose "Acquiring Entra ID token for Azure SQL..."
    verbose "Resource URL: $resource_url"
    
    local token
    if ! token=$(az account get-access-token --resource "$resource_url" --query accessToken -o tsv 2>&1); then
        log_error "Failed to acquire access token for Azure SQL"
        verbose "Error details: $token"
        return 1
    fi

    if [[ -z "$token" ]]; then
        log_error "Received empty access token"
        return 1
    fi

    log_success "Access token acquired successfully"
    echo "$token"
    return 0
}

# Generate SQL script for user creation and role assignment
generate_sql_script() {
    local principal="$1"
    local roles="$2"
    
    # Convert comma-separated roles to array
    IFS=',' read -ra role_array <<< "$roles"
    
    # Create user script
    local sql_script="
-- Create user from external provider
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'${principal}' AND type IN ('E', 'X'))
BEGIN
    CREATE USER [${principal}] FROM EXTERNAL PROVIDER;
    PRINT 'User [${principal}] created successfully';
END
ELSE
BEGIN
    PRINT 'User [${principal}] already exists';
END
GO
"

    # Add role assignment scripts
    for role in "${role_array[@]}"; do
        # Trim whitespace
        role=$(echo "$role" | xargs)
        
        sql_script+="
-- Assign role: ${role}
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'${role}' AND type = 'R')
BEGIN
    IF IS_ROLEMEMBER(N'${role}', N'${principal}') = 0 OR IS_ROLEMEMBER(N'${role}', N'${principal}') IS NULL
    BEGIN
        ALTER ROLE [${role}] ADD MEMBER [${principal}];
        PRINT 'Added [${principal}] to role [${role}]';
    END
    ELSE
    BEGIN
        PRINT '[${principal}] is already a member of role [${role}]';
    END
END
ELSE
BEGIN
    PRINT 'Warning: Role [${role}] does not exist in database';
END
GO
"
    done

    echo "$sql_script"
}

# Execute SQL script with token authentication
execute_sql_script() {
    local server_fqdn="$1"
    local database="$2"
    local access_token="$3"
    local sql_script="$4"
    local timeout="$5"
    
    verbose "Connecting to database..."
    verbose "Server: $server_fqdn"
    verbose "Database: $database"
    verbose "Timeout: ${timeout}s"
    
    # Create temporary file for SQL script
    local sql_file
    sql_file=$(mktemp)
    echo "$sql_script" > "$sql_file"
    
    verbose "SQL script saved to temporary file: $sql_file"
    
    # Execute SQL with sqlcmd using access token
    # -G flag enables Azure AD authentication
    # -P flag is used to pass the access token
    local output
    local exit_code=0
    
    if output=$(sqlcmd -S "$server_fqdn" -d "$database" -G -P "$access_token" -i "$sql_file" -t "$timeout" 2>&1); then
        log_success "Database connection established"
        verbose "SQL output:"
        verbose "$output"
        log_success "SQL commands executed successfully"
    else
        exit_code=$?
        log_error "SQL execution failed with exit code: $exit_code"
        log_error "Output: $output"
        rm -f "$sql_file"
        return 1
    fi
    
    # Clean up temporary file
    rm -f "$sql_file"
    verbose "Temporary SQL file removed"
    
    return 0
}

# Main execution
main() {
    log_info "Starting Azure SQL Managed Identity configuration..."
    
    # Parse arguments
    parse_arguments "$@"
    
    log_info "Parameters: Server=$SQL_SERVER_NAME, Database=$DATABASE_NAME, Principal=$PRINCIPAL_NAME"
    verbose "Roles: $DATABASE_ROLES"
    verbose "Azure Environment: $AZURE_ENVIRONMENT"
    verbose "Command Timeout: ${COMMAND_TIMEOUT}s"
    
    # Validate prerequisites
    if ! test_azure_context; then
        log_error "Azure authentication required"
        exit 1
    fi
    
    if ! check_sqlcmd; then
        log_error "sqlcmd utility required"
        exit 1
    fi
    
    # Get SQL endpoint
    local sql_suffix
    sql_suffix=$(get_sql_endpoint)
    local server_fqdn="${SQL_SERVER_NAME}.${sql_suffix}"
    log_info "Target server: $server_fqdn"
    
    # Get access token
    local access_token
    if ! access_token=$(get_sql_access_token "$sql_suffix"); then
        log_error "Failed to acquire access token"
        exit 1
    fi
    
    # Generate SQL script
    verbose "Generating SQL script..."
    local sql_script
    sql_script=$(generate_sql_script "$PRINCIPAL_NAME" "$DATABASE_ROLES")
    verbose "SQL script generated"
    
    # Execute SQL script
    log_info "Executing SQL commands..."
    if ! execute_sql_script "$server_fqdn" "$DATABASE_NAME" "$access_token" "$sql_script" "$COMMAND_TIMEOUT"; then
        log_error "SQL execution failed"
        exit 1
    fi
    
    log_success "Managed identity configuration completed for principal: $PRINCIPAL_NAME"
    
    # Output success JSON (for script consumption)
    cat << EOF
{
  "Success": true,
  "Principal": "$PRINCIPAL_NAME",
  "Server": "$server_fqdn",
  "Database": "$DATABASE_NAME",
  "Roles": "$DATABASE_ROLES",
  "Message": "Configuration completed successfully"
}
EOF
    
    exit 0
}

# Run main function with all arguments
main "$@"
