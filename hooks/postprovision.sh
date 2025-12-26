#!/usr/bin/env bash

#============================================================================
# Post-Provisioning Script for Azure Developer CLI (azd)
#============================================================================
#
# SYNOPSIS
#   Post-provisioning script for Azure Developer CLI (azd).
#
# DESCRIPTION
#   Configures .NET user secrets with Azure resource information after
#   provisioning. This script is automatically executed by azd after
#   infrastructure provisioning completes.
#   
#   The script performs the following operations:
#   - Validates required environment variables
#   - Authenticates to Azure Container Registry (if configured)
#   - Clears existing .NET user secrets
#   - Configures new user secrets with Azure resource information
#
# OPTIONS
#   --force       Skip confirmation prompts and force execution
#   --verbose     Enable verbose output for debugging
#   --dry-run     Show what the script would do without making changes
#   --help        Display this help message
#
# EXAMPLES
#   ./postprovision.sh
#     Runs the post-provisioning script with default settings.
#
#   ./postprovision.sh --verbose
#     Runs the script with verbose output for debugging.
#
#   ./postprovision.sh --dry-run
#     Shows what the script would do without making changes.
#
# NOTES
#   File Name      : postprovision.sh
#   Prerequisite   : .NET SDK, Azure Developer CLI, Azure CLI
#   Required Env   : AZURE_SUBSCRIPTION_ID, AZURE_RESOURCE_GROUP, AZURE_LOCATION
#   Author         : Azure DevOps Team
#   Last Modified  : 2025-12-26
#   Version        : 2.0.0
#
#============================================================================

# Bash strict mode for robust error handling
set -euo pipefail

# Script configuration
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Required environment variables
readonly REQUIRED_ENV_VARS=(
    "AZURE_SUBSCRIPTION_ID"
    "AZURE_RESOURCE_GROUP"
    "AZURE_LOCATION"
)

# Global variables for script state
VERBOSE=false
DRY_RUN=false
FORCE=false
EXECUTION_START_TIME=""
TOTAL_SECRETS=0
SUCCESS_COUNT=0
SKIPPED_COUNT=0
FAILED_COUNT=0

# Color codes for output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'

#============================================================================
# Helper Functions
#============================================================================

#----------------------------------------------------------------------------
# Output Functions
#----------------------------------------------------------------------------

info() {
    echo -e "${COLOR_CYAN}$*${COLOR_RESET}"
}

success() {
    echo -e "${COLOR_GREEN}$*${COLOR_RESET}"
}

warning() {
    echo -e "${COLOR_YELLOW}WARNING: $*${COLOR_RESET}" >&2
}

error() {
    echo -e "${COLOR_RED}ERROR: $*${COLOR_RESET}" >&2
}

verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${COLOR_BLUE}[VERBOSE] $*${COLOR_RESET}" >&2
    fi
}

write_section_header() {
    local message="$1"
    local type="${2:-info}"
    
    case "$type" in
        main)
            echo ""
            info "═══════════════════════════════════════════════════════════"
            info "$message"
            info "═══════════════════════════════════════════════════════════"
            ;;
        sub)
            echo ""
            info "───────────────────────────────────────────────────────────"
            info "$message"
            info "───────────────────────────────────────────────────────────"
            ;;
        info)
            echo ""
            info "$message"
            ;;
    esac
}

#----------------------------------------------------------------------------
# Error Handling
#----------------------------------------------------------------------------

cleanup() {
    local exit_code=$?
    
    if [[ -n "$EXECUTION_START_TIME" ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - EXECUTION_START_TIME))
        verbose "Total execution time: ${duration} seconds"
    fi
    
    verbose "Script execution completed."
    return $exit_code
}

trap cleanup EXIT

error_exit() {
    error "$1"
    exit "${2:-1}"
}

#----------------------------------------------------------------------------
# Help Documentation
#----------------------------------------------------------------------------

show_help() {
    cat << EOF
${COLOR_BOLD}Post-Provisioning Script for Azure Developer CLI (azd)${COLOR_RESET}
Version: ${SCRIPT_VERSION}

${COLOR_BOLD}DESCRIPTION:${COLOR_RESET}
    Configures .NET user secrets with Azure resource information after
    provisioning. This script is automatically executed by azd after
    infrastructure provisioning completes.

${COLOR_BOLD}USAGE:${COLOR_RESET}
    ./postprovision.sh [OPTIONS]

${COLOR_BOLD}OPTIONS:${COLOR_RESET}
    --force       Skip confirmation prompts and force execution
    --verbose     Enable verbose output for debugging
    --dry-run     Show what the script would do without making changes
    --help        Display this help message

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
    ./postprovision.sh
        Runs the post-provisioning script with default settings.

    ./postprovision.sh --verbose
        Runs the script with verbose output for debugging.

    ./postprovision.sh --dry-run
        Shows what the script would do without making changes.

${COLOR_BOLD}REQUIRED ENVIRONMENT VARIABLES:${COLOR_RESET}
    AZURE_SUBSCRIPTION_ID     - Azure subscription ID
    AZURE_RESOURCE_GROUP      - Azure resource group name
    AZURE_LOCATION            - Azure region/location

${COLOR_BOLD}OPTIONAL ENVIRONMENT VARIABLES:${COLOR_RESET}
    AZURE_TENANT_ID                          - Azure tenant ID
    APPLICATION_INSIGHTS_NAME                - Application Insights name
    APPLICATIONINSIGHTS_CONNECTION_STRING    - Application Insights connection string
    MANAGED_IDENTITY_CLIENT_ID               - Managed identity client ID
    MANAGED_IDENTITY_NAME                    - Managed identity name
    MESSAGING_SERVICEBUSHOSTNAME             - Service Bus hostname
    AZURE_SERVICE_BUS_TOPIC_NAME             - Service Bus topic name
    AZURE_SERVICE_BUS_SUBSCRIPTION_NAME      - Service Bus subscription name
    MESSAGING_SERVICEBUSENDPOINT             - Service Bus endpoint
    ORDERSDATABASE_SQLSERVERFQDN             - SQL Server fully qualified domain name
    AZURE_SQL_SERVER_NAME                    - SQL Server name
    AZURE_SQL_DATABASE_NAME                  - SQL Database name
    AZURE_CONTAINER_REGISTRY_ENDPOINT        - Container registry endpoint
    AZURE_CONTAINER_REGISTRY_NAME            - Container registry name
    AZURE_CONTAINER_APPS_ENVIRONMENT_NAME    - Container Apps environment name
    AZURE_LOG_ANALYTICS_WORKSPACE_NAME       - Log Analytics workspace name
    AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW      - Workflow storage account name

${COLOR_BOLD}EXIT CODES:${COLOR_RESET}
    0    Success
    1    General error
    2    Invalid arguments

EOF
    exit 0
}

#----------------------------------------------------------------------------
# Environment Variable Functions
#----------------------------------------------------------------------------

test_required_env_var() {
    local var_name="$1"
    
    verbose "Validating environment variable: $var_name"
    
    if [[ -z "${!var_name:-}" ]]; then
        warning "Required environment variable '$var_name' is not set or is empty."
        return 1
    fi
    
    verbose "Environment variable '$var_name' is set with value length: ${#!var_name}"
    return 0
}

get_env_var_safe() {
    local var_name="$1"
    local default_value="${2:-}"
    
    if [[ -n "${!var_name:-}" ]]; then
        echo "${!var_name}"
    else
        verbose "Environment variable '$var_name' is not set or empty."
        echo "$default_value"
    fi
}

#----------------------------------------------------------------------------
# Project Path Functions
#----------------------------------------------------------------------------

get_apphost_project_path() {
    verbose "Determining AppHost project path..."
    
    local project_path
    project_path="$(cd "$SCRIPT_DIR/.." && pwd)/app.AppHost/app.AppHost.csproj"
    
    verbose "Resolved AppHost project path: $project_path"
    echo "$project_path"
}

get_api_project_path() {
    verbose "Determining API project path..."
    
    local project_path
    project_path="$(cd "$SCRIPT_DIR/.." && pwd)/src/eShop.Orders.API/eShop.Orders.API.csproj"
    
    verbose "Resolved API project path: $project_path"
    echo "$project_path"
}

#----------------------------------------------------------------------------
# Azure Container Registry Authentication
#----------------------------------------------------------------------------

invoke_acr_login() {
    local registry_endpoint="${1:-}"
    
    verbose "Starting Azure Container Registry authentication process..."
    
    # ACR login is optional - some deployments use managed identities
    if [[ -z "$registry_endpoint" ]]; then
        warning "Azure Container Registry endpoint not configured. Skipping ACR login."
        verbose "Set AZURE_CONTAINER_REGISTRY_ENDPOINT environment variable if ACR authentication is required."
        return 0
    fi
    
    # Normalize registry endpoint by removing .azurecr.io suffix
    local registry_name="${registry_endpoint%.azurecr.io}"
    
    info "Authenticating to Azure Container Registry: $registry_endpoint"
    verbose "Using registry name: $registry_name"
    
    # Verify Azure CLI is installed
    if ! command -v az &> /dev/null; then
        warning "Azure CLI (az) not found in PATH. Skipping ACR authentication."
        info "  Install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        return 0
    fi
    
    verbose "Azure CLI found at: $(command -v az)"
    
    # Get Azure CLI version
    local az_version
    if az_version=$(az version --output json 2>&1); then
        verbose "Azure CLI version information retrieved"
    else
        verbose "Could not determine Azure CLI version"
    fi
    
    # Check if logged into Azure CLI
    verbose "Checking Azure CLI authentication status..."
    if ! az account show --output json &> /dev/null; then
        warning "Not authenticated with Azure CLI. Skipping ACR authentication."
        info "  Run 'az login' to authenticate with Azure."
        return 0
    fi
    
    verbose "Azure CLI authenticated successfully"
    
    # Perform ACR login
    verbose "Executing: az acr login --name $registry_name"
    if az acr login --name "$registry_name" &> /dev/null; then
        success "✓ Successfully authenticated to Azure Container Registry: $registry_name"
    else
        warning "Failed to login to Azure Container Registry '$registry_name'."
        info "  This may not affect deployment if using managed identity."
    fi
}

#----------------------------------------------------------------------------
# .NET User Secrets Functions
#----------------------------------------------------------------------------

set_dotnet_user_secret() {
    local key="$1"
    local value="$2"
    local project_path="$3"
    
    verbose "Attempting to set user secret for key: $key"
    
    # Skip empty values gracefully
    if [[ -z "$value" ]]; then
        verbose "Skipping secret '$key' - value is null or empty"
        return 0
    fi
    
    # Check for dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would set secret: $key"
        return 0
    fi
    
    verbose "Executing: dotnet user-secrets set \"$key\" <value> -p \"$project_path\""
    
    # Execute dotnet command and capture output
    local output
    local exit_code
    
    if output=$(dotnet user-secrets set "$key" "$value" -p "$project_path" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        error "Failed to set secret '$key'. Exit code: $exit_code"
        if [[ -n "$output" ]]; then
            error "Output: $output"
        fi
        return 1
    fi
    
    verbose "Successfully set secret: $key"
    return 0
}

clear_user_secrets() {
    local project_path="$1"
    local project_name="$2"
    
    verbose "Clearing user secrets for: $project_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would clear user secrets for: $project_name"
        return 0
    fi
    
    verbose "Executing: dotnet user-secrets clear -p \"$project_path\""
    
    local output
    local exit_code
    
    if output=$(dotnet user-secrets clear -p "$project_path" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    if [[ $exit_code -ne 0 ]]; then
        error "Failed to clear user secrets for $project_name. Exit code: $exit_code"
        if [[ -n "$output" ]]; then
            error "Output: $output"
        fi
        return 1
    fi
    
    success "✓ User secrets cleared successfully for: $project_name"
    return 0
}

#----------------------------------------------------------------------------
# Validation Functions
#----------------------------------------------------------------------------

validate_environment_variables() {
    write_section_header "Validating Environment Variables" "sub"
    
    local validation_errors=()
    
    for var_name in "${REQUIRED_ENV_VARS[@]}"; do
        verbose "Validating: $var_name"
        if test_required_env_var "$var_name"; then
            verbose "  ✓ $var_name is set"
        else
            validation_errors+=("$var_name")
        fi
    done
    
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        error "The following required environment variables are missing or empty:"
        for var_name in "${validation_errors[@]}"; do
            error "  - $var_name"
        done
        echo ""
        error "Please ensure these environment variables are set before running this script."
        return 1
    fi
    
    success "✓ All ${#REQUIRED_ENV_VARS[@]} required environment variables are set."
    return 0
}

verify_prerequisites() {
    write_section_header "Verifying Prerequisites" "sub"
    
    # Check for .NET CLI
    if ! command -v dotnet &> /dev/null; then
        error ".NET CLI (dotnet) not found in PATH."
        error "Please install .NET SDK from: https://dotnet.microsoft.com/download"
        error "Required for managing user secrets."
        return 1
    fi
    
    verbose ".NET CLI found at: $(command -v dotnet)"
    
    # Get .NET version
    local dotnet_version
    if dotnet_version=$(dotnet --version 2>&1); then
        success "✓ .NET SDK Version: $dotnet_version"
        verbose ".NET SDK successfully verified"
    else
        error "Error verifying .NET SDK"
        error "Please ensure .NET SDK is properly installed and accessible."
        return 1
    fi
    
    return 0
}

#----------------------------------------------------------------------------
# Configuration Functions
#----------------------------------------------------------------------------

configure_user_secrets() {
    local project_path="$1"
    local project_name="$2"
    shift 2
    local secrets=("$@")
    
    info ""
    info "Configuring $project_name project secrets..."
    verbose "Target project: $project_path"
    
    local project_success=0
    local project_skipped=0
    local project_failed=0
    
    # Process secrets in pairs (key=value)
    for secret_pair in "${secrets[@]}"; do
        if [[ "$secret_pair" == *"="* ]]; then
            local key="${secret_pair%%=*}"
            local value="${secret_pair#*=}"
            
            if [[ -z "$value" ]]; then
                verbose "  Skipping secret '$key' - value is null or empty"
                ((project_skipped++))
                ((SKIPPED_COUNT++))
                continue
            fi
            
            verbose "  Processing secret: $key"
            if set_dotnet_user_secret "$key" "$value" "$project_path"; then
                ((project_success++))
                ((SUCCESS_COUNT++))
                success "  ✓ Set: $key"
            else
                ((project_failed++))
                ((FAILED_COUNT++))
                warning "  Failed to set secret '$key'"
            fi
        fi
    done
    
    verbose "$project_name: Success=$project_success, Skipped=$project_skipped, Failed=$project_failed"
}

#============================================================================
# Main Script Execution
#============================================================================

main() {
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 2
                ;;
        esac
    done
    
    # Initialize execution timer
    EXECUTION_START_TIME=$(date +%s)
    
    # Display script initialization banner
    write_section_header "Post-Provisioning Script Started" "main"
    info "Script Version: $SCRIPT_VERSION"
    info "Execution Time: $(date '+%Y-%m-%d %H:%M:%S')"
    info "Bash Version: $BASH_VERSION"
    info "Operating System: $(uname -s) $(uname -r)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warning "DRY-RUN MODE: No changes will be made"
    fi
    
    # Validate environment variables
    validate_environment_variables || error_exit "Environment validation failed"
    
    # Read environment variables
    write_section_header "Reading Environment Variables" "info"
    verbose "Using safe retrieval for all environment variables..."
    
    # Core Azure configuration
    local azure_tenant_id
    local azure_subscription_id
    local azure_resource_group
    local azure_location
    azure_tenant_id=$(get_env_var_safe "AZURE_TENANT_ID")
    azure_subscription_id=$(get_env_var_safe "AZURE_SUBSCRIPTION_ID")
    azure_resource_group=$(get_env_var_safe "AZURE_RESOURCE_GROUP")
    azure_location=$(get_env_var_safe "AZURE_LOCATION")
    
    # Application Insights configuration
    local enable_app_insights="true"
    local app_insights_name
    local app_insights_conn_str
    app_insights_name=$(get_env_var_safe "APPLICATION_INSIGHTS_NAME")
    app_insights_conn_str=$(get_env_var_safe "APPLICATIONINSIGHTS_CONNECTION_STRING")
    
    # Managed Identity configuration
    local azure_client_id
    local azure_managed_identity_name
    azure_client_id=$(get_env_var_safe "MANAGED_IDENTITY_CLIENT_ID")
    azure_managed_identity_name=$(get_env_var_safe "MANAGED_IDENTITY_NAME")
    
    # Service Bus messaging configuration
    local azure_servicebus_hostname
    local azure_servicebus_topic
    local azure_servicebus_subscription
    local azure_servicebus_endpoint
    azure_servicebus_hostname=$(get_env_var_safe "MESSAGING_SERVICEBUSHOSTNAME")
    azure_servicebus_topic=$(get_env_var_safe "AZURE_SERVICE_BUS_TOPIC_NAME" "OrdersPlaced")
    azure_servicebus_subscription=$(get_env_var_safe "AZURE_SERVICE_BUS_SUBSCRIPTION_NAME" "OrderProcessingSubscription")
    azure_servicebus_endpoint=$(get_env_var_safe "MESSAGING_SERVICEBUSENDPOINT")
    
    # SQL Database configuration (new in current infrastructure)
    local azure_sql_server_fqdn
    local azure_sql_server_name
    local azure_sql_database_name
    azure_sql_server_fqdn=$(get_env_var_safe "ORDERSDATABASE_SQLSERVERFQDN")
    azure_sql_server_name=$(get_env_var_safe "AZURE_SQL_SERVER_NAME")
    azure_sql_database_name=$(get_env_var_safe "AZURE_SQL_DATABASE_NAME")
    
    # Container Services configuration
    local azure_acr_endpoint
    local azure_acr_name
    local azure_container_apps_env_name
    local azure_container_apps_env_id
    local azure_container_apps_domain
    azure_acr_endpoint=$(get_env_var_safe "AZURE_CONTAINER_REGISTRY_ENDPOINT")
    azure_acr_name=$(get_env_var_safe "AZURE_CONTAINER_REGISTRY_NAME")
    azure_container_apps_env_name=$(get_env_var_safe "AZURE_CONTAINER_APPS_ENVIRONMENT_NAME")
    azure_container_apps_env_id=$(get_env_var_safe "AZURE_CONTAINER_APPS_ENVIRONMENT_ID")
    azure_container_apps_domain=$(get_env_var_safe "AZURE_CONTAINER_APPS_ENVIRONMENT_DEFAULT_DOMAIN")
    
    # Monitoring configuration
    local azure_log_analytics_workspace
    azure_log_analytics_workspace=$(get_env_var_safe "AZURE_LOG_ANALYTICS_WORKSPACE_NAME")
    
    # Environment and deployment configuration
    local azure_env_name
    azure_env_name=$(get_env_var_safe "AZURE_ENV_NAME")
    
    # Storage configuration
    local azure_storage_account
    azure_storage_account=$(get_env_var_safe "AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW")
    
    # Display Azure configuration
    write_section_header "Azure Configuration" "sub"
    local not_set="<not set>"
    info "Azure Tenant ID          : ${azure_tenant_id:-$not_set}"
    info "  Subscription ID        : ${azure_subscription_id:-$not_set}"
    info "  Resource Group         : ${azure_resource_group:-$not_set}"
    info "  Location               : ${azure_location:-$not_set}"
    info "  Environment Name       : ${azure_env_name:-$not_set}"
    info "  Client ID              : ${azure_client_id:-$not_set}"
    info "  Enable App Insights    : $enable_app_insights"
    info "  App Insights Name      : ${app_insights_name:-$not_set}"
    info "  App Insights Conn Str  : ${app_insights_conn_str:-$not_set}"
    info "  Service Bus Host Name  : ${azure_servicebus_hostname:-$not_set}"
    info "  Service Bus Topic Name : ${azure_servicebus_topic:-$not_set}"
    info "  Service Bus Subscription: ${azure_servicebus_subscription:-$not_set}"
    info "  Service Bus Endpoint   : ${azure_servicebus_endpoint:-$not_set}"
    info "  SQL Server FQDN        : ${azure_sql_server_fqdn:-$not_set}"
    info "  SQL Server Name        : ${azure_sql_server_name:-$not_set}"
    info "  SQL Database Name      : ${azure_sql_database_name:-$not_set}"
    info "  ACR Endpoint           : ${azure_acr_endpoint:-$not_set}"
    info "  ACR Name               : ${azure_acr_name:-$not_set}"
    info "  Container Apps Env     : ${azure_container_apps_env_name:-$not_set}"
    info "  Container Apps Domain  : ${azure_container_apps_domain:-$not_set}"
    info "  Log Analytics Workspace: ${azure_log_analytics_workspace:-$not_set}"
    info "  Storage Account Name   : ${azure_storage_account:-$not_set}"
    
    # Attempt Azure Container Registry authentication
    invoke_acr_login "$azure_acr_endpoint"
    
    # Verify prerequisites
    verify_prerequisites || error_exit "Prerequisites verification failed"
    
    # Get and verify project paths
    verbose "Resolving project paths..."
    
    local apphost_project_path
    local api_project_path
    apphost_project_path=$(get_apphost_project_path)
    api_project_path=$(get_api_project_path)
    
    info "  AppHost Project: $apphost_project_path"
    
    if [[ ! -f "$apphost_project_path" ]]; then
        warning "AppHost project file not found at: $apphost_project_path"
    else
        verbose "✓ AppHost project file verified"
    fi
    
    success "✓ API Project Path: $api_project_path"
    
    if [[ ! -f "$api_project_path" ]]; then
        error "API project file not found at: $api_project_path"
        error "Please ensure the project structure is correct."
        error "Expected location: <script-root>/../src/eShop.Orders.API/eShop.Orders.API.csproj"
        exit 1
    fi
    
    success "✓ API project file verified."
    
    # Clear existing user secrets
    write_section_header "Clearing Existing User Secrets" "sub"
    
    clear_user_secrets "$api_project_path" "API" || {
        error "Error clearing user secrets for API project"
        error "This may indicate the project doesn't have user secrets initialized."
        exit 1
    }
    
    clear_user_secrets "$apphost_project_path" "AppHost" || {
        warning "Could not clear AppHost user secrets (may not be initialized yet)"
    }
    
    # Configure user secrets
    write_section_header "Configuring User Secrets" "sub"
    
    # Configure SQL Database Managed Identity (if configured)
    write_section_header "Configuring SQL Database Managed Identity" "sub"
    
    if [[ -n "$azure_sql_server_name" ]] && [[ -n "$azure_sql_database_name" ]] && [[ -n "$azure_managed_identity_name" ]]; then
        info "SQL Database configuration detected..."
        info "  Server: $azure_sql_server_name"
        info "  Database: $azure_sql_database_name"
        info "  Managed Identity: $azure_managed_identity_name"
        
        local sql_config_script="$SCRIPT_DIR/sql-managed-identity-config.sh"
        
        if [[ ! -f "$sql_config_script" ]]; then
            warning "SQL managed identity configuration script not found at: $sql_config_script"
            warning "Skipping SQL database user configuration. The API may not have database access."
        else
            verbose "SQL configuration script found at: $sql_config_script"
            
            if [[ "$DRY_RUN" == "false" ]]; then
                info "Executing SQL managed identity configuration..."
                
                # Make executable if needed
                chmod +x "$sql_config_script" 2>/dev/null || true
                
                # Execute with database roles
                if bash "$sql_config_script" \
                    --server-name "$azure_sql_server_name" \
                    --database-name "$azure_sql_database_name" \
                    --principal-name "$azure_managed_identity_name" \
                    --roles "db_datareader,db_datawriter"; then
                    success "✓ SQL Database managed identity configured successfully"
                    verbose "Assigned roles: db_datareader, db_datawriter"
                else
                    warning "Failed to configure SQL database managed identity"
                    warning "The application may not have database access. Manual configuration may be required."
                    info ""
                    info "To manually configure database access, run:"
                    info "  ./sql-managed-identity-config.sh --server-name '$azure_sql_server_name' --database-name '$azure_sql_database_name' --principal-name '$azure_managed_identity_name'"
                    info ""
                fi
            else
                info "[DRY-RUN] Would configure SQL managed identity"
            fi
        fi
    else
        info "SQL Database configuration parameters not available - skipping managed identity setup"
        
        [[ -z "$azure_sql_server_name" ]] && verbose "  Missing: AZURE_SQL_SERVER_NAME"
        [[ -z "$azure_sql_database_name" ]] && verbose "  Missing: AZURE_SQL_DATABASE_NAME"
        [[ -z "$azure_managed_identity_name" ]] && verbose "  Missing: MANAGED_IDENTITY_NAME"
        
        info "Database user secrets will still be configured if connection string is available."
    fi
    
    # Define AppHost secrets (EXACTLY matches PowerShell configuration)
    local apphost_secrets=(
        "Azure:TenantId=$azure_tenant_id"
        "Azure:SubscriptionId=$azure_subscription_id"
        "Azure:Location=$azure_location"
        "Azure:ResourceGroup=$azure_resource_group"
        "ApplicationInsights:Enabled=$enable_app_insights"
        "Azure:ApplicationInsights:Name=$app_insights_name"
        "ApplicationInsights:ConnectionString=$app_insights_conn_str"
        "Azure:ClientId=$azure_client_id"
        "Azure:ManagedIdentity:Name=$azure_managed_identity_name"
        "Azure:ServiceBus:HostName=$azure_servicebus_hostname"
        "Azure:ServiceBus:TopicName=$azure_servicebus_topic"
        "Azure:ServiceBus:SubscriptionName=$azure_servicebus_subscription"
        "Azure:ServiceBus:Endpoint=$azure_servicebus_endpoint"
        "Azure:SqlServer:Fqdn=$azure_sql_server_fqdn"
        "Azure:SqlServer:Name=$azure_sql_server_name"
        "Azure:SqlDatabase:Name=$azure_sql_database_name"
        "Azure:Storage:AccountName=$azure_storage_account"
        "Azure:ContainerRegistry:Endpoint=$azure_acr_endpoint"
        "Azure:ContainerRegistry:Name=$azure_acr_name"
        "Azure:ContainerApps:EnvironmentName=$azure_container_apps_env_name"
        "Azure:ContainerApps:EnvironmentId=$azure_container_apps_env_id"
        "Azure:ContainerApps:DefaultDomain=$azure_container_apps_domain"
        "Azure:LogAnalytics:WorkspaceName=$azure_log_analytics_workspace"
    )
    
    # Define API secrets (EXACTLY matches PowerShell configuration - only 3 secrets!)
    local api_secrets=(
        "Azure:TenantId=$azure_tenant_id"
        "Azure:ClientId=$azure_client_id"
        "ApplicationInsights:ConnectionString=$app_insights_conn_str"
    )
    
    TOTAL_SECRETS=$((${#apphost_secrets[@]} + ${#api_secrets[@]}))
    
    info "Preparing to configure user secrets for both projects..."
    info "  - AppHost: ${#apphost_secrets[@]} secret(s)"
    info "  - API: ${#api_secrets[@]} secret(s)"
    
    # Configure AppHost secrets
    configure_user_secrets "$apphost_project_path" "AppHost" "${apphost_secrets[@]}"
    
    # Configure API secrets
    configure_user_secrets "$api_project_path" "API" "${api_secrets[@]}"
    
    # Report results
    write_section_header "Configuration Results" "sub"
    info "User Secrets Configuration Summary:"
    success "  ✓ Successfully configured: $SUCCESS_COUNT / $TOTAL_SECRETS"
    
    if [[ $SKIPPED_COUNT -gt 0 ]]; then
        info "  ⊘ Skipped (empty values): $SKIPPED_COUNT"
    fi
    
    if [[ $FAILED_COUNT -gt 0 ]]; then
        warning "  ✗ Failed: $FAILED_COUNT"
        
        # Don't fail if some secrets were set
        if [[ $SUCCESS_COUNT -eq 0 ]]; then
            error_exit "All user secrets failed to configure. Please review errors above."
        fi
    fi
    
    # Success summary
    write_section_header "Post-Provisioning Completed Successfully!" "main"
    info "Results:"
    info "  • Total secrets defined   : $TOTAL_SECRETS"
    info "  • Successfully configured : $SUCCESS_COUNT"
    info "  • Skipped (empty)         : $SKIPPED_COUNT"
    info "  • Failed                  : $FAILED_COUNT"
    echo ""
    info "Completion Time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    local execution_end_time
    execution_end_time=$(date +%s)
    local duration=$((execution_end_time - EXECUTION_START_TIME))
    info "Duration: ${duration} seconds"
    echo ""
    verbose "Exiting with success code 0"
    
    exit 0
}

# Execute main function
main "$@"
