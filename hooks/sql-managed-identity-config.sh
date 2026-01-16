#!/usr/bin/env bash

#============================================================================
# SQL Managed Identity Configuration Script for Azure SQL Database
#============================================================================
#
# SYNOPSIS
#   Configures Azure SQL Database user with Managed Identity authentication.
#
# DESCRIPTION
#   Creates a database user from an external provider (Microsoft Entra ID/Managed Identity)
#   and assigns specified database roles using Azure AD token-based authentication.
#   
#   This script performs the following operations:
#   - Validates Azure CLI authentication
#   - Acquires an access token for Azure SQL Database
#   - Creates a contained database user from external provider
#   - Assigns specified database roles to the user
#   - Returns a structured result
#   
#   The script is idempotent and can be safely re-run. It will skip existing users
#   and role memberships.
#
# PARAMETERS
#   --sql-server-name, -s  The Azure SQL Server name (without suffix) [Required]
#   --database-name, -d    The database name [Required]
#   --principal-name, -p   The managed identity display name [Required]
#   --database-roles, -r   Comma-separated database roles (default: db_datareader,db_datawriter)
#   --environment, -e      Azure environment (default: AzureCloud)
#   --timeout, -t          SQL command timeout in seconds (default: 120)
#   --verbose, -v          Enable verbose output
#   --help, -h             Display help message
#
# EXAMPLES
#   ./sql-managed-identity-config.sh --sql-server-name myserver --database-name mydb --principal-name my-app-identity
#   
#   ./sql-managed-identity-config.sh -s myserver -d mydb -p my-app-identity -r "db_datareader,db_datawriter,db_ddladmin" -v
#
# NOTES
#   File Name      : sql-managed-identity-config.sh
#   Version        : 1.0.0
#   Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
#   Creation Date  : 2025-12-26
#   Last Modified  : 2026-01-06
#   
#   Prerequisites:
#   - Bash 4.0 or higher
#   - Azure CLI (az) version 2.60.0 or higher with active authentication
#   - sqlcmd utility (mssql-tools) for SQL Server connectivity
#   - AZURE_RESOURCE_GROUP environment variable set
#   
#   Security Notes:
#   - Uses Azure AD token authentication (no SQL passwords)
#   - Access tokens are not logged or persisted
#   - Connections use encryption (TLS 1.2+)
#
# LINKS
#   https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure
#   https://learn.microsoft.com/azure/active-directory/managed-identities-azure-resources/overview
#   https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#
#============================================================================

# Bash strict mode for robust error handling
set -euo pipefail

#============================================================================
# Script Constants
#============================================================================
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Azure SQL endpoint mapping for different cloud environments
declare -A SQL_ENDPOINTS=(
    ["AzureCloud"]="database.windows.net"
    ["AzureUSGovernment"]="database.usgovcloudapi.net"
    ["AzureChinaCloud"]="database.chinacloudapi.cn"
    ["AzureGermanCloud"]="database.cloudapi.de"
)

# Valid database roles
readonly VALID_ROLES="db_owner db_datareader db_datawriter db_ddladmin db_backupoperator db_securityadmin db_accessadmin db_denydatareader db_denydatawriter"

#============================================================================
# Global Variables
#============================================================================
VERBOSE=false
SQL_SERVER_NAME=""
DATABASE_NAME=""
PRINCIPAL_DISPLAY_NAME=""
DATABASE_ROLES="db_datareader,db_datawriter"
AZURE_ENVIRONMENT="AzureCloud"
COMMAND_TIMEOUT=120

# ANSI color codes
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_CYAN='\033[0;36m'

#============================================================================
# Helper Functions
#============================================================================

# Display informational message
log_info() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_CYAN}[${timestamp}] [Info] $*${COLOR_RESET}"
}

# Display success message
log_success() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_GREEN}[${timestamp}] [Success] $*${COLOR_RESET}"
}

# Display warning message
log_warning() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_YELLOW}[${timestamp}] [Warning] $*${COLOR_RESET}" >&2
}

# Display error message
log_error() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${COLOR_RED}[${timestamp}] [Error] $*${COLOR_RESET}" >&2
}

# Display verbose message
log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        local timestamp
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "[${timestamp}] [Verbose] $*" >&2
    fi
}

# Display usage information
show_usage() {
    cat << EOF
SQL Managed Identity Configuration Script v${SCRIPT_VERSION}

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

REQUIRED OPTIONS:
    --sql-server-name, -s <name>    Azure SQL Server name (without .database.windows.net suffix)
    --database-name, -d <name>      Database name (cannot be 'master')
    --principal-name, -p <name>     Managed identity or service principal display name

OPTIONAL OPTIONS:
    --database-roles, -r <roles>    Comma-separated database roles
                                    (default: db_datareader,db_datawriter)
                                    Valid roles: ${VALID_ROLES}
    --environment, -e <env>         Azure environment
                                    (default: AzureCloud)
                                    Valid: AzureCloud, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud
    --timeout, -t <seconds>         SQL command timeout (30-600, default: 120)
    --verbose, -v                   Enable verbose output
    --help, -h                      Display this help message

EXAMPLES:
    # Basic usage with default roles
    ${SCRIPT_NAME} --sql-server-name myserver --database-name mydb --principal-name my-app-identity

    # With custom roles and verbose output
    ${SCRIPT_NAME} -s myserver -d mydb -p my-app-identity -r "db_datareader,db_datawriter,db_ddladmin" -v

    # Azure Government cloud
    ${SCRIPT_NAME} -s myserver -d mydb -p my-app-identity -e AzureUSGovernment

PREREQUISITES:
    - Azure CLI (az) installed and authenticated (az login)
    - sqlcmd utility (mssql-tools) for SQL Server connectivity
    - AZURE_RESOURCE_GROUP environment variable set (for firewall configuration)

NOTES:
    - The authenticated user must be an Entra ID administrator of the SQL Server
    - The script is idempotent and can be safely re-run
    - Access tokens are not logged or persisted

EOF
}

# Validate required parameters
validate_parameters() {
    local errors=0

    if [[ -z "$SQL_SERVER_NAME" ]]; then
        log_error "SQL Server name is required (--sql-server-name, -s)"
        errors=$((errors + 1))
    elif ! [[ "$SQL_SERVER_NAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
        log_error "SQL Server name must contain only lowercase letters, numbers, and hyphens"
        errors=$((errors + 1))
    fi

    if [[ -z "$DATABASE_NAME" ]]; then
        log_error "Database name is required (--database-name, -d)"
        errors=$((errors + 1))
    elif [[ "$DATABASE_NAME" == "master" ]]; then
        log_error "Cannot configure managed identity users in the 'master' database"
        errors=$((errors + 1))
    fi

    if [[ -z "$PRINCIPAL_DISPLAY_NAME" ]]; then
        log_error "Principal display name is required (--principal-name, -p)"
        errors=$((errors + 1))
    fi

    # Validate roles
    IFS=',' read -ra ROLE_ARRAY <<< "$DATABASE_ROLES"
    for role in "${ROLE_ARRAY[@]}"; do
        role=$(echo "$role" | xargs)  # Trim whitespace
        if ! echo "$VALID_ROLES" | grep -qw "$role"; then
            log_error "Invalid role: $role. Valid roles: $VALID_ROLES"
            errors=$((errors + 1))
        fi
    done

    # Validate environment
    if [[ -z "${SQL_ENDPOINTS[$AZURE_ENVIRONMENT]+x}" ]]; then
        log_error "Invalid Azure environment: $AZURE_ENVIRONMENT"
        errors=$((errors + 1))
    fi

    # Validate timeout
    if [[ "$COMMAND_TIMEOUT" -lt 30 || "$COMMAND_TIMEOUT" -gt 600 ]]; then
        log_error "Command timeout must be between 30 and 600 seconds"
        errors=$((errors + 1))
    fi

    if [[ $errors -gt 0 ]]; then
        echo ""
        show_usage
        exit 1
    fi
}

# Check if Azure CLI is available and authenticated
check_azure_cli() {
    log_verbose "Checking Azure CLI availability..."

    # Check if az command exists
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI (az) is not installed or not in PATH"
        log_error "Install from: https://learn.microsoft.com/cli/azure/install-azure-cli"
        return 1
    fi

    log_verbose "Azure CLI found at: $(command -v az)"

    # Check Azure CLI version
    local version
    version=$(az version --query '"azure-cli"' -o tsv 2>/dev/null || echo "unknown")
    log_verbose "Azure CLI version: $version"

    # Check if logged in
    if ! az account show &> /dev/null; then
        log_error "Not authenticated to Azure CLI"
        log_error "Run: az login"
        return 1
    fi

    # Get account information
    local subscription_name
    subscription_name=$(az account show --query 'name' -o tsv 2>/dev/null || echo "unknown")
    log_success "Azure CLI authenticated: Subscription=$subscription_name"

    return 0
}

# Check if sqlcmd is available
check_sqlcmd() {
    log_verbose "Checking sqlcmd availability..."

    if ! command -v sqlcmd &> /dev/null; then
        log_error "sqlcmd utility is not installed"
        log_error "Install mssql-tools package:"
        log_error "  Ubuntu/Debian: curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add - && sudo apt-get update && sudo apt-get install mssql-tools"
        log_error "  macOS: brew install mssql-tools"
        log_error "  More info: https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-utility"
        return 1
    fi

    log_verbose "sqlcmd found at: $(command -v sqlcmd)"
    return 0
}

# Acquire Azure SQL access token
get_sql_access_token() {
    local resource_url="$1"
    
    log_verbose "Acquiring access token for resource: $resource_url"
    log_verbose "  Using Azure CLI authentication"

    local token
    token=$(az account get-access-token --resource "$resource_url" --query accessToken -o tsv 2>&1)
    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        local error_details
        if [[ -n "$token" ]]; then
            error_details="Output: $token"
        else
            error_details="No error output available"
        fi
        log_error "Azure CLI returned exit code $exit_code. $error_details"
        log_error "Ensure you are authenticated to Azure CLI: az login"
        return 1
    fi

    if [[ -z "$token" ]]; then
        log_error "Azure CLI returned an empty token. Verify Azure authentication with: az login"
        return 1
    fi
    
    # Validate token format (basic check)
    if [[ ${#token} -lt 50 ]]; then
        log_error "Token appears invalid (length: ${#token} characters). Expected JWT token."
        return 1
    fi

    log_success "Token acquired successfully via Azure CLI"
    log_verbose "  Token length: ${#token} characters"
    echo "$token"
}

# Generate T-SQL script for managed identity configuration
generate_sql_script() {
    local principal_name="$1"
    local roles="$2"

    log_verbose "Generating SQL script for managed identity configuration..."

    # Escape single quotes in principal name for SQL injection protection
    local safe_principal_name="${principal_name//\'/\'\'}"

    # Start with user creation script
    local sql_script=""
    sql_script+="-- Create contained database user from Microsoft Entra ID (Azure AD)
-- This user will authenticate using Entra ID managed identity
IF NOT EXISTS (
    SELECT 1 
    FROM sys.database_principals 
    WHERE name = N'${safe_principal_name}' 
    AND type IN ('E', 'X')  -- E = External user, X = External group
)
BEGIN
    CREATE USER [${safe_principal_name}] FROM EXTERNAL PROVIDER;
    PRINT 'SUCCESS: User [${safe_principal_name}] created successfully';
END
ELSE
BEGIN
    PRINT 'INFO: User [${safe_principal_name}] already exists - skipping creation';
END;

"

    # Add role assignment scripts
    IFS=',' read -ra ROLE_ARRAY <<< "$roles"
    for role in "${ROLE_ARRAY[@]}"; do
        role=$(echo "$role" | xargs)  # Trim whitespace
        local safe_role_name="${role//\'/\'\'}"
        
        sql_script+="-- Assign database role: ${safe_role_name}
IF EXISTS (
    SELECT 1 
    FROM sys.database_principals 
    WHERE name = N'${safe_role_name}' 
    AND type = 'R'  -- R = Database role
)
BEGIN
    -- Check if user is already a member of this role
    IF IS_ROLEMEMBER(N'${safe_role_name}', N'${safe_principal_name}') = 0 
       OR IS_ROLEMEMBER(N'${safe_role_name}', N'${safe_principal_name}') IS NULL
    BEGIN
        ALTER ROLE [${safe_role_name}] ADD MEMBER [${safe_principal_name}];
        PRINT 'SUCCESS: Added [${safe_principal_name}] to role [${safe_role_name}]';
    END
    ELSE
    BEGIN
        PRINT 'INFO: [${safe_principal_name}] is already a member of role [${safe_role_name}] - skipping';
    END
END
ELSE
BEGIN
    PRINT 'WARNING: Role [${safe_role_name}] does not exist in database - skipping';
END;

"
    done

    log_verbose "Generated SQL script with $(echo "$roles" | tr ',' '\n' | wc -l | xargs) role assignment(s)"
    echo "$sql_script"
}

# Configure firewall rule for current IP
configure_firewall() {
    log_info "Detecting current public IP address for firewall configuration..."

    local current_ip=""
    local ip_services=(
        "http://ifconfig.me/ip"
        "https://api.ipify.org?format=text"
        "https://icanhazip.com"
    )

    for service in "${ip_services[@]}"; do
        log_verbose "  Trying: $service"
        current_ip=$(curl -s --max-time 10 "$service" 2>/dev/null | tr -d '[:space:]' || true)
        
        # Validate IP address format
        if [[ "$current_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            log_info "Found public IP address: $current_ip"
            break
        fi
        current_ip=""
    done

    if [[ -z "$current_ip" ]]; then
        log_warning "Could not detect public IP address - firewall rule creation skipped"
        log_warning "You may need to manually add your IP to the SQL Server firewall rules"
        return 0
    fi

    # Get resource group from environment variable
    local resource_group="${AZURE_RESOURCE_GROUP:-}"
    
    if [[ -z "$resource_group" ]]; then
        log_warning "AZURE_RESOURCE_GROUP environment variable is not set"
        log_warning "Firewall rule creation skipped - you may need to add it manually"
        return 0
    fi

    local firewall_rule_name="ClientIP-$(date +%Y%m%d%H%M%S)"
    
    log_info "  Resource Group: $resource_group"
    log_info "  Server Name:    $SQL_SERVER_NAME"
    log_info "  Rule Name:      $firewall_rule_name"
    log_info "Adding firewall rule '$firewall_rule_name' for IP '$current_ip'..."

    # Create firewall rule and capture output for better error handling
    local firewall_output
    firewall_output=$(az sql server firewall-rule create \
        --resource-group "$resource_group" \
        --server "$SQL_SERVER_NAME" \
        --name "$firewall_rule_name" \
        --start-ip-address "$current_ip" \
        --end-ip-address "$current_ip" \
        -o none 2>&1)
    local firewall_exit_code=$?
    
    if [[ $firewall_exit_code -eq 0 ]]; then
        log_success "Firewall rule '$firewall_rule_name' with IP '$current_ip' has been created."
    elif [[ $firewall_exit_code -eq 1 ]] && [[ "$firewall_output" == *"already exists"* ]]; then
        log_info "Firewall rule for IP '$current_ip' already exists - continuing"
    else
        log_warning "Failed to create firewall rule (exit code: $firewall_exit_code): $firewall_output"
        log_warning "You may need to manually add IP $current_ip to SQL Server firewall rules"
    fi
}

# Display troubleshooting guidance for SQL errors
show_troubleshooting_guidance() {
    local error_message="$1"
    
    echo ""
    echo -e "${COLOR_YELLOW}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}TROUBLESHOOTING GUIDANCE${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"

    if [[ "$error_message" == *"18456"* ]] || [[ "$error_message" == *"Login failed"* ]]; then
        echo ""
        echo -e "${COLOR_RED}ERROR: Login failed - Authentication succeeded but user lacks SQL Server permissions${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_YELLOW}ROOT CAUSE:${COLOR_RESET}"
        echo "  To create database users via Entra ID, you MUST authenticate as an"
        echo "  Entra ID administrator of the SQL Server."
        echo ""
        echo -e "${COLOR_YELLOW}SOLUTION - Follow these steps:${COLOR_RESET}"
        echo ""
        echo -e "${COLOR_CYAN}1. Set an Entra ID Admin on the SQL Server (if not already set):${COLOR_RESET}"
        echo ""
        echo "   az sql server ad-admin create \\"
        echo "     --resource-group <your-rg> \\"
        echo "     --server-name $SQL_SERVER_NAME \\"
        echo "     --display-name <admin-user-or-identity-name> \\"
        echo "     --object-id <admin-object-id>"
        echo ""
        echo -e "${COLOR_CYAN}2. Verify the admin is set:${COLOR_RESET}"
        echo "   az sql server ad-admin list --resource-group <rg> --server-name $SQL_SERVER_NAME"
        echo ""
        echo -e "${COLOR_CYAN}3. Ensure you are authenticated as that admin:${COLOR_RESET}"
        echo "   az account show    # Check current identity"
        echo "   az login           # Re-authenticate if needed"
        echo ""
        echo -e "${COLOR_CYAN}4. Re-run the provisioning:${COLOR_RESET}"
        echo "   azd provision"
        echo ""
        echo "More info: https://learn.microsoft.com/azure/azure-sql/database/authentication-aad-configure"
    elif [[ "$error_message" == *"40615"* ]]; then
        echo -e "${COLOR_YELLOW}Firewall rule blocking connection - add client IP to SQL firewall${COLOR_RESET}"
    elif [[ "$error_message" == *"40613"* ]]; then
        echo -e "${COLOR_YELLOW}Database not available - check database exists and is online${COLOR_RESET}"
    elif [[ "$error_message" == *"33134"* ]] || [[ "$error_message" == *"already exists"* ]]; then
        echo -e "${COLOR_GREEN}User already exists - this is usually safe to ignore${COLOR_RESET}"
    else
        echo -e "${COLOR_YELLOW}Check SQL Server logs and Azure AD configuration${COLOR_RESET}"
    fi

    echo ""
    echo -e "${COLOR_YELLOW}═══════════════════════════════════════════════════════════════════${COLOR_RESET}"
    echo ""
}

# Output JSON result
output_result() {
    local success="$1"
    local message="$2"
    local error="${3:-}"
    local execution_time="${4:-0}"
    local rows_affected="${5:-0}"

    local timestamp
    timestamp=$(date -Iseconds)
    
    local sql_suffix="${SQL_ENDPOINTS[$AZURE_ENVIRONMENT]}"
    local server_fqdn="${SQL_SERVER_NAME}.${sql_suffix}"

    if [[ "$success" == "true" ]]; then
        cat << EOF
{
    "Success": true,
    "Principal": "$PRINCIPAL_DISPLAY_NAME",
    "Server": "$server_fqdn",
    "Database": "$DATABASE_NAME",
    "Roles": "$(echo "$DATABASE_ROLES" | tr ',' ' ')",
    "RowsAffected": $rows_affected,
    "ExecutionTimeSeconds": $execution_time,
    "Timestamp": "$timestamp",
    "Message": "$message",
    "ScriptVersion": "$SCRIPT_VERSION"
}
EOF
    else
        cat << EOF
{
    "Success": false,
    "Principal": "$PRINCIPAL_DISPLAY_NAME",
    "Server": "$server_fqdn",
    "Database": "$DATABASE_NAME",
    "Roles": "$(echo "$DATABASE_ROLES" | tr ',' ' ')",
    "Error": "$error",
    "Timestamp": "$timestamp",
    "ScriptVersion": "$SCRIPT_VERSION"
}
EOF
    fi
}

#============================================================================
# Main Execution
#============================================================================

main() {
    local start_time
    start_time=$(date +%s)

    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --sql-server-name|--server|-s)
                SQL_SERVER_NAME="$2"
                shift 2
                ;;
            --database-name|--database|-d)
                DATABASE_NAME="$2"
                shift 2
                ;;
            --principal-name|--principal|-p)
                PRINCIPAL_DISPLAY_NAME="$2"
                shift 2
                ;;
            --database-roles|--roles|-r)
                DATABASE_ROLES="$2"
                shift 2
                ;;
            --environment|-e)
                AZURE_ENVIRONMENT="$2"
                shift 2
                ;;
            --timeout|-t)
                COMMAND_TIMEOUT="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Display script header
    log_info "===================================================================="
    log_info "SQL Managed Identity Configuration Script v${SCRIPT_VERSION}"
    log_info "===================================================================="
    log_info "Starting Azure SQL Database managed identity configuration..."
    echo ""

    # Validate parameters
    validate_parameters

    # Log configuration parameters
    log_info "Configuration Parameters:"
    log_info "  SQL Server Name:    $SQL_SERVER_NAME"
    log_info "  Database Name:      $DATABASE_NAME"
    log_info "  Principal Name:     $PRINCIPAL_DISPLAY_NAME"
    log_info "  Database Roles:     $DATABASE_ROLES"
    log_info "  Azure Environment:  $AZURE_ENVIRONMENT"
    log_info "  Command Timeout:    ${COMMAND_TIMEOUT}s"
    echo ""

    #region Step 1: Validate Azure Authentication
    log_info "[Step 1/5] Validating Azure authentication..."
    
    if ! check_azure_cli; then
        output_result "false" "" "Azure CLI authentication is required but not available"
        exit 1
    fi

    log_success "Using Azure CLI for authentication"
    #endregion

    #region Step 2: Construct Connection Details
    echo ""
    log_info "[Step 2/5] Constructing connection details..."

    # Configure firewall
    configure_firewall

    # Get SQL endpoint suffix
    local sql_suffix="${SQL_ENDPOINTS[$AZURE_ENVIRONMENT]}"
    local server_fqdn="${SQL_SERVER_NAME}.${sql_suffix}"
    local resource_url="https://${sql_suffix}/"

    log_info "  Server FQDN:      $server_fqdn"
    log_info "  Resource URL:     $resource_url"
    log_info "  Port:             1433 (default)"
    log_info "  Encryption:       TLS 1.2+ (enforced)"
    #endregion

    #region Step 3: Acquire Access Token
    echo ""
    log_info "[Step 3/5] Acquiring Entra ID access token for Azure SQL..."

    local access_token
    access_token=$(get_sql_access_token "$resource_url")
    
    if [[ -z "$access_token" ]]; then
        output_result "false" "" "Failed to acquire access token"
        exit 1
    fi

    # Mask token in verbose logs
    if [[ "$VERBOSE" == "true" ]]; then
        local token_length=${#access_token}
        if [[ $token_length -gt 20 ]]; then
            local masked_token="${access_token:0:10}...${access_token: -10}"
            log_verbose "  Token length:     $token_length characters"
            log_verbose "  Token preview:    $masked_token"
        fi
    fi

    log_success "Access token acquired and validated successfully"
    #endregion

    #region Step 4: Generate SQL Script
    echo ""
    log_info "[Step 4/5] Generating SQL configuration script..."

    local sql_script
    sql_script=$(generate_sql_script "$PRINCIPAL_DISPLAY_NAME" "$DATABASE_ROLES")

    log_success "SQL script generated successfully (${#sql_script} characters)"
    log_verbose "Script will create user and assign $(echo "$DATABASE_ROLES" | tr ',' '\n' | wc -l | xargs) role(s)"
    #endregion

    #region Step 5: Execute SQL Script
    echo ""
    log_info "[Step 5/5] Executing SQL script on target database..."

    # Check sqlcmd availability
    if ! check_sqlcmd; then
        output_result "false" "" "sqlcmd utility is required but not installed"
        exit 1
    fi

    log_verbose "Creating database connection..."
    log_info "Executing T-SQL script..."
    log_info "Script creates user [$PRINCIPAL_DISPLAY_NAME] and assigns roles: $DATABASE_ROLES"

    local command_start_time
    command_start_time=$(date +%s)

    # Create temporary file for SQL script
    local sql_file
    sql_file=$(mktemp)
    echo "$sql_script" > "$sql_file"

    # Execute SQL script with sqlcmd
    local sql_output
    local sql_exit_code=0
    
    # Use Azure CLI authentication with go-sqlcmd
    # Since Azure CLI is already authenticated (via OIDC in GitHub Actions),
    # go-sqlcmd can use it directly with --authentication-method ActiveDirectoryAzCli
    # This avoids needing to pass tokens manually
    # Reference: https://github.com/microsoft/go-sqlcmd
    # Note: -N requires a value in go-sqlcmd (true/false/strict), -l is login timeout
    sql_output=$(sqlcmd \
        -S "tcp:${server_fqdn},1433" \
        -d "$DATABASE_NAME" \
        --authentication-method ActiveDirectoryAzCli \
        -N true \
        -l "$COMMAND_TIMEOUT" \
        -i "$sql_file" \
        2>&1) || sql_exit_code=$?

    # Clean up temporary file
    rm -f "$sql_file"

    local command_end_time
    command_end_time=$(date +%s)
    local execution_duration=$((command_end_time - command_start_time))

    if [[ $sql_exit_code -ne 0 ]]; then
        log_error "SQL script execution failed"
        log_error "$sql_output"
        
        show_troubleshooting_guidance "$sql_output"
        
        output_result "false" "" "SQL script execution failed: $sql_output" "$execution_duration"
        exit 1
    fi

    echo ""
    log_success "===================================================================="
    log_success "SQL SCRIPT EXECUTION COMPLETED SUCCESSFULLY"
    log_success "===================================================================="
    log_success "  Execution time:     ${execution_duration}s"
    log_success "  Principal:          $PRINCIPAL_DISPLAY_NAME"
    log_success "  Database:           $DATABASE_NAME"
    log_success "  Roles assigned:     $DATABASE_ROLES"
    echo ""

    # Calculate total execution time
    local end_time
    end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    output_result "true" "Managed identity configuration completed successfully" "" "$total_duration" "0"
    #endregion
}

# Entry point
main "$@"
