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
#   - Configures SQL Database managed identity access
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
#   Last Modified  : 2026-01-06
#   Version        : 2.0.1
#
#============================================================================

# Bash strict mode for robust error handling
# -e: Exit on error
# -u: Exit on undefined variable
# -o pipefail: Catch errors in pipelines
set -euo pipefail

# Set Internal Field Separator to default (space, tab, newline)
# Protects against word splitting vulnerabilities
IFS=$' \t\n'

# Script configuration constants
# These values define script versioning and location for relative path resolution
readonly SCRIPT_VERSION="2.0.1"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Required environment variables that must be present before script execution
# These are validated at script startup to ensure provisioning has completed successfully
readonly REQUIRED_ENV_VARS=(
    "AZURE_SUBSCRIPTION_ID"     # Azure subscription GUID
    "AZURE_RESOURCE_GROUP"      # Resource group containing deployed resources
    "AZURE_LOCATION"            # Azure region where resources are deployed
)

# Global variables for script state and execution tracking
# These maintain state across function calls for comprehensive reporting
VERBOSE=false                   # Enable detailed logging output
DRY_RUN=false                   # Simulate operations without making changes
FORCE=false                     # Skip confirmation prompts
EXECUTION_START_TIME=""         # Track script execution duration
TOTAL_SECRETS=0                 # Total number of secrets to configure
SUCCESS_COUNT=0                 # Successfully configured secrets
SKIPPED_COUNT=0                 # Skipped secrets (empty values)
FAILED_COUNT=0                  # Failed secret configuration attempts

# ANSI color codes for formatted console output
# These provide visual distinction for different message types
# Color support is standard in modern terminals (bash, zsh, etc.)
readonly COLOR_RESET='\033[0m'      # Reset to default color
readonly COLOR_RED='\033[0;31m'     # Error messages
readonly COLOR_GREEN='\033[0;32m'   # Success messages
readonly COLOR_YELLOW='\033[0;33m'  # Warning messages
readonly COLOR_BLUE='\033[0;34m'    # Verbose/debug messages
readonly COLOR_CYAN='\033[0;36m'    # Info messages
readonly COLOR_BOLD='\033[1m'       # Bold text for emphasis

#============================================================================
# Helper Functions
#============================================================================

#----------------------------------------------------------------------------
# Output Functions
#----------------------------------------------------------------------------
# These functions provide consistent, colored output for different message types
# All output respects the --verbose flag for debug information

# Display informational message in cyan
# Used for general progress updates and status information
info() {
    echo -e "${COLOR_CYAN}$*${COLOR_RESET}"
}

# Display success message in green
# Used to indicate successful completion of operations
success() {
    echo -e "${COLOR_GREEN}$*${COLOR_RESET}"
}

# Display warning message in yellow (sent to stderr)
# Used for non-fatal issues that may require attention
warning() {
    echo -e "${COLOR_YELLOW}WARNING: $*${COLOR_RESET}" >&2
}

# Display error message in red (sent to stderr)
# Used for fatal errors that prevent script execution
error() {
    echo -e "${COLOR_RED}ERROR: $*${COLOR_RESET}" >&2
}

# Display verbose/debug message in blue (sent to stderr)
# Only shown when --verbose flag is enabled
# Used for detailed execution information during troubleshooting
verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${COLOR_BLUE}[VERBOSE] $*${COLOR_RESET}" >&2
    fi
}

# Display formatted section headers for visual organization
# Supports three types: main (double line), sub (single line), info (simple)
# Parameters:
#   $1 - Message to display
#   $2 - Type: 'main', 'sub', or 'info' (default: info)
write_section_header() {
    local message="$1"
    local type="${2:-info}"
    
    case "$type" in
        main)
            # Main sections use double-line borders for emphasis
            echo ""
            info "═══════════════════════════════════════════════════════════"
            info "$message"
            info "═══════════════════════════════════════════════════════════"
            ;;
        sub)
            # Sub-sections use single-line borders
            echo ""
            info "───────────────────────────────────────────────────────────"
            info "$message"
            info "───────────────────────────────────────────────────────────"
            ;;
        info)
            # Info headers are simple with spacing
            echo ""
            info "$message"
            ;;
    esac
}

#----------------------------------------------------------------------------
# Error Handling
#----------------------------------------------------------------------------
# Comprehensive error handling and cleanup functions
# These ensure graceful script termination and resource cleanup

# Cleanup function called on script exit (success or failure)
# Registered via 'trap cleanup EXIT' to ensure it always executes
# Reports execution time and performs any necessary cleanup
cleanup() {
    local exit_code=$?
    
    # Calculate and display execution duration if timer was started
    if [[ -n "$EXECUTION_START_TIME" ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - EXECUTION_START_TIME))
        verbose "Total execution time: ${duration} seconds"
    fi
    
    verbose "Script execution completed."
    return $exit_code
}

# Register cleanup to run on script exit
# This ensures cleanup happens whether script exits normally or abnormally
trap cleanup EXIT

# Exit with error message and optional exit code
# Parameters:
#   $1 - Error message to display
#   $2 - Exit code (default: 1)
# This function never returns
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
# Functions for safe environment variable access and validation
# These ensure consistent handling of missing or empty variables

# Validate that a required environment variable is set and non-empty
# Parameters:
#   $1 - Name of the environment variable to check
# Returns:
#   0 if variable is set and non-empty, 1 otherwise
# Note: Uses bash indirect expansion (${!var_name}) to access variable by name
test_required_env_var() {
    local var_name="$1"
    
    verbose "Validating environment variable: $var_name"
    
    # Check if variable is set and non-empty using indirect expansion
    if [[ -z "${!var_name:-}" ]]; then
        warning "Required environment variable '$var_name' is not set or is empty."
        return 1
    fi
    
    # Get value length using indirect expansion (two-step to avoid syntax error)
    local var_value="${!var_name}"
    verbose "Environment variable '$var_name' is set with value length: ${#var_value}"
    return 0
}

# Safely retrieve an environment variable with optional default value
# Parameters:
#   $1 - Name of the environment variable to retrieve
#   $2 - Default value to return if variable is empty (optional)
# Returns:
#   Variable value if set, default value if provided, or empty string
# Note: Does not fail if variable is missing - returns default or empty
get_env_var_safe() {
    local var_name="$1"
    local default_value="${2:-}"
    
    # Use indirect expansion to access variable by name
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
# Functions for resolving project file paths
# These use relative paths from the script location for portability

# Get the path to the AppHost .csproj file
# Returns:
#   Absolute path to app.AppHost/app.AppHost.csproj
# Note: Uses script directory as reference point for relative path resolution
get_apphost_project_path() {
    verbose "Determining AppHost project path..."
    
    local project_path
    # Navigate from hooks/ to root, then to app.AppHost/
    project_path="$(cd "$SCRIPT_DIR/.." && pwd)/app.AppHost/app.AppHost.csproj"
    
    verbose "Resolved AppHost project path: $project_path"
    echo "$project_path"
}

# Get the path to the API .csproj file
# Returns:
#   Absolute path to src/eShop.Orders.API/eShop.Orders.API.csproj
# Note: Uses script directory as reference point for relative path resolution
get_api_project_path() {
    verbose "Determining API project path..."
    
    local project_path
    # Navigate from hooks/ to root, then to src/eShop.Orders.API/
    project_path="$(cd "$SCRIPT_DIR/.." && pwd)/src/eShop.Orders.API/eShop.Orders.API.csproj"
    
    verbose "Resolved API project path: $project_path"
    echo "$project_path"
}

# Get the path to the Web App .csproj file
# Returns:
#   Absolute path to src/eShop.Web.App/eShop.Web.App.csproj
# Note: Uses script directory as reference point for relative path resolution
get_webapp_project_path() {
    verbose "Determining Web App project path..."
    
    local project_path
    # Navigate from hooks/ to root, then to src/eShop.Web.App/
    project_path="$(cd "$SCRIPT_DIR/.." && pwd)/src/eShop.Web.App/eShop.Web.App.csproj"
    
    verbose "Resolved Web App project path: $project_path"
    echo "$project_path"
}

#----------------------------------------------------------------------------
# Azure Container Registry Authentication
#----------------------------------------------------------------------------
# Handles authentication to Azure Container Registry for container operations
# This is optional - some deployments use managed identities instead

# Authenticate to Azure Container Registry using Azure CLI
# Parameters:
#   $1 - Registry endpoint (e.g., myregistry.azurecr.io)
# Returns:
#   0 on success or if ACR login is not needed, doesn't exit on failure
# Note: Non-blocking operation - script continues even if ACR login fails
#       ACR authentication may not be required if using managed identities
invoke_acr_login() {
    local registry_endpoint="${1:-}"
    
    verbose "Starting Azure Container Registry authentication process..."
    
    # ACR login is optional - some deployments use managed identities
    if [[ -z "$registry_endpoint" ]]; then
        warning "Azure Container Registry endpoint not configured. Skipping ACR login."
        verbose "Set AZURE_CONTAINER_REGISTRY_ENDPOINT environment variable if ACR authentication is required."
        return 0
    fi
    
    # Normalize registry endpoint by removing .azurecr.io suffix if present
    # Azure CLI expects just the registry name, not the full FQDN
    local registry_name="${registry_endpoint%.azurecr.io}"
    
    info "Authenticating to Azure Container Registry: $registry_endpoint"
    verbose "Using registry name: $registry_name"
    
    # Verify Azure CLI is installed before attempting authentication
    if ! command -v az &> /dev/null; then
        warning "Azure CLI (az) not found in PATH. Skipping ACR authentication."
        info "  Install Azure CLI from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        return 0
    fi
    
    verbose "Azure CLI found at: $(command -v az)"
    
    # Get Azure CLI version for diagnostic purposes
    local az_version
    if az_version=$(az version --output json 2>&1); then
        verbose "Azure CLI version information retrieved"
    else
        verbose "Could not determine Azure CLI version"
    fi
    
    # Check if logged into Azure CLI
    # ACR operations require an authenticated Azure CLI session
    verbose "Checking Azure CLI authentication status..."
    if ! az account show --output json &> /dev/null; then
        warning "Not authenticated with Azure CLI. Skipping ACR authentication."
        info "  Run 'az login' to authenticate with Azure."
        return 0
    fi
    
    verbose "Azure CLI authenticated successfully"
    
    # Perform ACR login using Azure CLI
    # Suppress output to avoid cluttering logs with token information
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
# Functions for managing .NET user secrets
# User secrets provide secure local storage for sensitive configuration

# Set a single .NET user secret for a project
# Parameters:
#   $1 - Secret key name
#   $2 - Secret value
#   $3 - Path to .csproj file
# Returns:
#   0 on success, 1 on failure
# Note: Skips silently if value is empty or whitespace
#       Updates global counters (SUCCESS_COUNT, SKIPPED_COUNT, FAILED_COUNT)
set_dotnet_user_secret() {
    local key="$1"
    local value="$2"
    local project_path="$3"
    
    verbose "Attempting to set user secret for key: $key"
    
    # Skip empty values gracefully - they're not errors, just no-ops
    # Empty values occur when optional environment variables aren't set
    if [[ -z "$value" ]]; then
        verbose "Skipping secret '$key' - value is null or empty"
        return 0
    fi
    
    # Check for dry-run mode - simulate operation without making changes
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would set secret: $key"
        return 0
    fi
    
    verbose "Executing: dotnet user-secrets set \"$key\" <value> -p \"$project_path\""
    
    # Execute dotnet command and capture both output and exit code
    # Output is captured for error reporting if command fails
    local output
    local exit_code
    
    if output=$(dotnet user-secrets set "$key" "$value" -p "$project_path" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Check for command failure and provide detailed error information
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

# Clear all user secrets for a project
# Parameters:
#   $1 - Path to .csproj file
#   $2 - Project display name (for logging)
# Returns:
#   0 on success, 1 on failure
# Note: This removes all existing secrets to ensure clean slate
#       Useful when secrets structure changes between deployments
clear_user_secrets() {
    local project_path="$1"
    local project_name="$2"
    
    verbose "Clearing user secrets for: $project_name"
    
    # Check for dry-run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        info "[DRY-RUN] Would clear user secrets for: $project_name"
        return 0
    fi
    
    verbose "Executing: dotnet user-secrets clear -p \"$project_path\""
    
    # Execute dotnet command and capture both output and exit code
    local output
    local exit_code
    
    if output=$(dotnet user-secrets clear -p "$project_path" 2>&1); then
        exit_code=0
    else
        exit_code=$?
    fi
    
    # Check for command failure and provide detailed error information
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
# Functions for validating environment and prerequisites before execution
# These implement fail-fast pattern to catch configuration issues early

# Validate all required environment variables are set
# Returns:
#   0 if all required variables are set, 1 if any are missing
# Note: Collects all missing variables before failing to provide complete feedback
validate_environment_variables() {
    write_section_header "Validating Environment Variables" "sub"
    
    local validation_errors=()
    
    # Check each required environment variable
    # Collect all failures before reporting to provide complete error context
    for var_name in "${REQUIRED_ENV_VARS[@]}"; do
        verbose "Validating: $var_name"
        if test_required_env_var "$var_name"; then
            verbose "  ✓ $var_name is set"
        else
            validation_errors+=("$var_name")
        fi
    done
    
    # If any validation failed, build comprehensive error message and terminate
    # Provides user with complete list of missing variables
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

# Verify required tools are installed and accessible
# Returns:
#   0 if all prerequisites are met, 1 if any are missing
# Note: Checks for .NET CLI which is required for user secrets management
verify_prerequisites() {
    write_section_header "Verifying Prerequisites" "sub"
    
    # Check for .NET CLI availability
    # User secrets management requires dotnet CLI to be installed and in PATH
    if ! command -v dotnet &> /dev/null; then
        error ".NET CLI (dotnet) not found in PATH."
        error "Please install .NET SDK from: https://dotnet.microsoft.com/download"
        error "Required for managing user secrets."
        return 1
    fi
    
    verbose ".NET CLI found at: $(command -v dotnet)"
    
    # Get .NET version for diagnostic purposes and verification
    # This confirms not just presence but that dotnet CLI is functional
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
# Functions for configuring user secrets across multiple projects
# These track success/failure/skip statistics for comprehensive reporting

# Configure user secrets for a specific project
# Parameters:
#   $1 - Path to .csproj file
#   $2 - Project display name (for logging)
#   $@ - Remaining arguments are secret pairs in "key=value" format
# Returns:
#   Nothing (updates global counters)
# Note: Updates SUCCESS_COUNT, SKIPPED_COUNT, and FAILED_COUNT globals
#       Processes all secrets even if some fail to maximize configuration
configure_user_secrets() {
    local project_path="$1"
    local project_name="$2"
    shift 2
    local secrets=("$@")
    
    info ""
    info "Configuring $project_name project secrets..."
    verbose "Target project: $project_path"
    
    # Track statistics per-project for detailed logging
    local project_success=0
    local project_skipped=0
    local project_failed=0
    
    # Process secrets in pairs (key=value)
    # Secrets array contains strings in "key=value" format
    for secret_pair in "${secrets[@]}"; do
        # Only process strings containing '=' separator
        if [[ "$secret_pair" == *"="* ]]; then
            # Split on first '=' to handle values that contain '='
            local key="${secret_pair%%=*}"
            local value="${secret_pair#*=}"
            
            # Skip secrets with empty values (non-error condition)
            # This happens when optional environment variables aren't set
            if [[ -z "$value" ]]; then
                verbose "  Skipping secret '$key' - value is null or empty"
                project_skipped=$((project_skipped + 1))
                SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
                continue
            fi
            
            # Attempt to set the secret and track result
            verbose "  Processing secret: $key"
            if set_dotnet_user_secret "$key" "$value" "$project_path"; then
                project_success=$((project_success + 1))
                SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
                success "  ✓ Set: $key"
            else
                project_failed=$((project_failed + 1))
                FAILED_COUNT=$((FAILED_COUNT + 1))
                warning "  Failed to set secret '$key'"
            fi
        fi
    done
    
    # Log per-project statistics for troubleshooting
    verbose "$project_name: Success=$project_success, Skipped=$project_skipped, Failed=$project_failed"
}

#============================================================================
# Main Script Execution
#============================================================================
# Entry point for script execution
# Orchestrates all provisioning steps in proper sequence

main() {
    # Parse command-line arguments
    # Supports --force, --verbose, --dry-run, and --help flags
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
    
    # Initialize execution timer for performance tracking and reporting
    # Used in cleanup function to calculate total execution duration
    EXECUTION_START_TIME=$(date +%s)
    
    # Display script initialization banner with version and environment info
    # Provides context for troubleshooting and audit logging
    write_section_header "Post-Provisioning Script Started" "main"
    info "Script Version: $SCRIPT_VERSION"
    info "Execution Time: $(date '+%Y-%m-%d %H:%M:%S')"
    info "Bash Version: $BASH_VERSION"
    info "Operating System: $(uname -s) $(uname -r)"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warning "DRY-RUN MODE: No changes will be made"
    fi
    
    # Validate all required environment variables before proceeding
    # Fail-fast approach ensures we don't attempt provisioning with incomplete configuration
    validate_environment_variables || error_exit "Environment validation failed"
    
    # Retrieve all Azure configuration from environment variables
    # Using get_env_var_safe for consistent null handling and default values
    write_section_header "Reading Environment Variables" "info"
    verbose "Using safe retrieval for all environment variables..."
    
    # Core Azure configuration (required)
    # These values identify the Azure tenant, subscription, and resource location
    local azure_tenant_id
    local azure_subscription_id
    local azure_resource_group
    local azure_location
    azure_tenant_id=$(get_env_var_safe "AZURE_TENANT_ID")
    azure_subscription_id=$(get_env_var_safe "AZURE_SUBSCRIPTION_ID")
    azure_resource_group=$(get_env_var_safe "AZURE_RESOURCE_GROUP")
    azure_location=$(get_env_var_safe "AZURE_LOCATION")
    
    # Application Insights configuration
    # Enables telemetry and monitoring for deployed applications
    local enable_app_insights="true"
    local app_insights_name
    local app_insights_conn_str
    app_insights_name=$(get_env_var_safe "APPLICATION_INSIGHTS_NAME")
    app_insights_conn_str=$(get_env_var_safe "APPLICATIONINSIGHTS_CONNECTION_STRING")
    
    # Managed Identity configuration
    # Used for passwordless authentication to Azure resources
    local azure_client_id
    local azure_managed_identity_name
    azure_client_id=$(get_env_var_safe "MANAGED_IDENTITY_CLIENT_ID")
    azure_managed_identity_name=$(get_env_var_safe "MANAGED_IDENTITY_NAME")
    
    # Service Bus messaging configuration
    # Provides reliable async messaging between application components
    local azure_servicebus_hostname
    local azure_servicebus_topic
    local azure_servicebus_subscription
    local azure_servicebus_endpoint
    azure_servicebus_hostname=$(get_env_var_safe "MESSAGING_SERVICEBUSHOSTNAME")
    # Provide default values for Service Bus topic/subscription names
    azure_servicebus_topic=$(get_env_var_safe "AZURE_SERVICE_BUS_TOPIC_NAME" "ordersplaced")
    azure_servicebus_subscription=$(get_env_var_safe "AZURE_SERVICE_BUS_SUBSCRIPTION_NAME" "orderprocessingsub")
    azure_servicebus_endpoint=$(get_env_var_safe "MESSAGING_SERVICEBUSENDPOINT")
    
    # SQL Database configuration (new in current infrastructure)
    # Provides relational data storage for application state
    local azure_sql_server_fqdn
    local azure_sql_server_name
    local azure_sql_database_name
    azure_sql_server_fqdn=$(get_env_var_safe "ORDERSDATABASE_SQLSERVERFQDN")
    azure_sql_server_name=$(get_env_var_safe "AZURE_SQL_SERVER_NAME")
    azure_sql_database_name=$(get_env_var_safe "AZURE_SQL_DATABASE_NAME")
    
    # Container Services configuration
    # Manages container images and runtime environment
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
    # Provides centralized logging and analytics
    local azure_log_analytics_workspace
    azure_log_analytics_workspace=$(get_env_var_safe "AZURE_LOG_ANALYTICS_WORKSPACE_NAME")
    
    # Environment and deployment configuration
    # Identifies the deployment environment (dev, staging, prod, etc.)
    local azure_env_name
    azure_env_name=$(get_env_var_safe "AZURE_ENV_NAME")
    
    # Storage configuration for Logic Apps and Orders
    # Provides blob storage for workflow state and artifacts
    local azure_storage_account
    azure_storage_account=$(get_env_var_safe "AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW")
    
    # Display complete Azure configuration for verification and troubleshooting
    # Using bash parameter expansion with :- for null-coalescing behavior
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
    # Non-blocking operation - script continues even if ACR login fails
    # Some deployments may not require ACR authentication (e.g., using managed identities)
    invoke_acr_login "$azure_acr_endpoint"
    
    # Verify that required tools are installed before proceeding
    # .NET CLI is required for managing user secrets
    verify_prerequisites || error_exit "Prerequisites verification failed"
    
    # Get and verify project paths
    verbose "Resolving project paths..."
    
    local apphost_project_path
    local api_project_path
    local webapp_project_path
    apphost_project_path=$(get_apphost_project_path)
    api_project_path=$(get_api_project_path)
    webapp_project_path=$(get_webapp_project_path)
    
    info "  AppHost Project: $apphost_project_path"
    
    if [[ ! -f "$apphost_project_path" ]]; then
        warning "AppHost project file not found at: $apphost_project_path"
    else
        verbose "✓ AppHost project file verified"
    fi
    
    info "  API Project: $api_project_path"
    
    if [[ ! -f "$api_project_path" ]]; then
        error "API project file not found at: $api_project_path"
        error "Please ensure the project structure is correct."
        error "Expected location: <script-root>/../src/eShop.Orders.API/eShop.Orders.API.csproj"
        exit 1
    fi
    
    verbose "✓ API project file verified"
    
    info "  Web App Project: $webapp_project_path"
    
    if [[ ! -f "$webapp_project_path" ]]; then
        warning "Web App project file not found at: $webapp_project_path"
        warning "Web App secrets will be skipped."
        webapp_project_path=""
    else
        verbose "✓ Web App project file verified"
    fi
    
    success "✓ All project paths verified."
    
    # Configure SQL Database Managed Identity
    # IMPORTANT: The managed identity requires appropriate database roles for:
    # - Entity Framework migrations and schema creation (requires db_owner)
    # - Creating tables, indexes, and foreign key constraints (requires db_owner)
    # - Running EnsureCreatedAsync() operations (requires db_owner)
    # - Basic read/write operations (requires db_datareader and db_datawriter)
    # Without proper permissions, the application will fail with access denied errors
    write_section_header "Configuring SQL Database Managed Identity" "sub"
    
    # Only configure SQL managed identity if all required parameters are available
    # This section is critical for database access and matches PowerShell implementation
    if [[ -n "$azure_sql_server_name" ]] && [[ -n "$azure_sql_database_name" ]] && [[ -n "$azure_managed_identity_name" ]]; then
        info "SQL Database configuration detected..."
        info "  Server: $azure_sql_server_name"
        info "  Database: $azure_sql_database_name"
        info "  Managed Identity: $azure_managed_identity_name"
        
        # Check if sqlcmd (go-sqlcmd) is available in PATH
        # go-sqlcmd is required for Azure AD authentication via --authentication-method
        if ! command -v sqlcmd &> /dev/null; then
            warning "sqlcmd (go-sqlcmd) not found in PATH"
            warning "Please install go-sqlcmd: https://github.com/microsoft/go-sqlcmd"
            warning "Skipping SQL database user configuration."
        fi
        
        # Locate the SQL configuration script
        # This script performs the actual database user creation and role assignment
        local sql_config_script="$SCRIPT_DIR/sql-managed-identity-config.sh"
        
        if [[ ! -f "$sql_config_script" ]]; then
            warning "SQL managed identity configuration script not found at: $sql_config_script"
            warning "Skipping SQL database user configuration. The API may not have database access."
            info ""
            info "IMPORTANT: The managed identity will not be configured for database access."
            info "You may need to manually grant database permissions for the application to function."
            info ""
            info "Manual configuration steps:"
            info "  1. Connect to SQL Server: $azure_sql_server_name"
            info "  2. Connect to Database: $azure_sql_database_name"
            info "  3. Create user from external provider: CREATE USER [$azure_managed_identity_name] FROM EXTERNAL PROVIDER"
            info "  4. Grant appropriate roles based on application needs:"
            info "     - For basic read/write: EXEC sp_addrolemember 'db_datareader', '$azure_managed_identity_name'"
            info "                              EXEC sp_addrolemember 'db_datawriter', '$azure_managed_identity_name'"
            info "     - For EF migrations:    EXEC sp_addrolemember 'db_owner', '$azure_managed_identity_name'"
            info ""
        else
            verbose "SQL configuration script found at: $sql_config_script"
            
            # Execute SQL configuration unless in dry-run mode
            if [[ "$DRY_RUN" == "false" ]]; then
                info "Executing SQL managed identity configuration..."
                info "  Granting database role: db_owner"
                info ""
                info "NOTE: Using db_owner role for full schema management and CRUD operations."
                info "This is required for Entity Framework migrations and EnsureCreatedAsync operations."
                info ""
                
                # Make script executable if needed
                chmod +x "$sql_config_script" 2>/dev/null || true
                
                # Execute with database roles
                # Using db_owner for full schema management and CRUD operations
                # Required for Entity Framework migrations and EnsureCreatedAsync operations
                if bash "$sql_config_script" \
                    --sql-server-name "$azure_sql_server_name" \
                    --database-name "$azure_sql_database_name" \
                    --principal-name "$azure_managed_identity_name" \
                    --database-roles "db_owner" 2>&1 | tee >(cat >&2); then
                    
                    # Check if command actually succeeded (script may have warnings)
                    local sql_exit_code=${PIPESTATUS[0]}
                    if [[ $sql_exit_code -eq 0 ]]; then
                        success "✓ SQL Database managed identity configured successfully"
                        verbose "Assigned role: db_owner"
                    else
                        warning "SQL configuration script completed with warnings or errors (exit code: $sql_exit_code)"
                        warning "The application may not have database access. Manual configuration may be required."
                        info ""
                    fi
                else
                    warning "Failed to configure SQL database managed identity"
                    warning "The application may not have database access. Manual configuration may be required."
                    info ""
                    info "To manually configure database access, run:"
                    info "  $sql_config_script --sql-server-name '$azure_sql_server_name' --database-name '$azure_sql_database_name' --principal-name '$azure_managed_identity_name' --database-roles 'db_owner'"
                    info ""
                fi
            else
                info "[DRY-RUN] Would configure SQL managed identity with the following parameters:"
                info "  Server: $azure_sql_server_name"
                info "  Database: $azure_sql_database_name"
                info "  Principal: $azure_managed_identity_name"
                info "  Role: db_owner"
            fi
        fi
    else
        info "SQL Database configuration parameters not available - skipping managed identity setup"
        info ""
        
        # Show which parameters are missing for troubleshooting
        [[ -z "$azure_sql_server_name" ]] && verbose "  Missing: AZURE_SQL_SERVER_NAME"
        [[ -z "$azure_sql_database_name" ]] && verbose "  Missing: AZURE_SQL_DATABASE_NAME"
        [[ -z "$azure_managed_identity_name" ]] && verbose "  Missing: MANAGED_IDENTITY_NAME"
        
        info "If SQL Database is part of your infrastructure, ensure the following environment variables are set:"
        info "  - AZURE_SQL_SERVER_NAME"
        info "  - AZURE_SQL_DATABASE_NAME"
        info "  - MANAGED_IDENTITY_NAME"
        info ""
        info "Database connection secrets will still be configured if available."
    fi
    
    # Clear existing user secrets
    # This ensures a clean slate and removes any stale configuration from previous deployments
    write_section_header "Clearing Existing User Secrets" "sub"
    
    # Clear API secrets (required for application functionality)
    clear_user_secrets "$api_project_path" "API" || {
        error "Error clearing user secrets for API project"
        error "This may indicate the project doesn't have user secrets initialized."
        error ""
        error "To initialize user secrets, run:"
        error "  dotnet user-secrets init -p $api_project_path"
        error ""
        exit 1
    }
    
    # Clear AppHost secrets (optional - orchestrator project)
    clear_user_secrets "$apphost_project_path" "AppHost" || {
        warning "Could not clear AppHost user secrets (may not be initialized yet)"
        info "  AppHost user secrets may not be initialized - this is not an error."
        info "  The AppHost project is used for local orchestration and development."
    }
    
    # Clear Web App secrets (if project exists)
    if [[ -n "$webapp_project_path" ]] && [[ -f "$webapp_project_path" ]]; then
        clear_user_secrets "$webapp_project_path" "Web App" || {
            warning "Could not clear Web App user secrets (may not be initialized yet)"
            info "  Web App user secrets may not be initialized - this is not an error."
        }
    fi
    
    # Configure user secrets for all projects
    # Secrets are organized per project based on what each project needs to function
    # AppHost needs full Azure configuration for orchestration
    # API needs minimal configuration for runtime operations
    # Web App needs minimal configuration for frontend
    write_section_header "Configuring User Secrets" "sub"
    
    # Define AppHost secrets (EXACTLY matches PowerShell configuration)
    # AppHost is the orchestrator project that manages the application lifecycle
    # It requires comprehensive Azure configuration for provisioning and management
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
    
    # Define API secrets (EXACTLY matches PowerShell configuration)
    # API only needs minimal secrets for runtime operations
    # Most Azure resource access is handled via managed identity
    local api_secrets=(
        "Azure:TenantId=$azure_tenant_id"
        "Azure:ClientId=$azure_client_id"
        "ApplicationInsights:ConnectionString=$app_insights_conn_str"
    )
    
    # Add SQL connection string if Azure SQL is configured (matches PowerShell logic)
    # IMPORTANT: Connection string key must match Program.cs: 'ConnectionStrings:OrderDb'
    # Uses Azure Active Directory authentication with the managed identity
    if [[ -n "$azure_sql_server_fqdn" ]] && [[ -n "$azure_sql_database_name" ]]; then
        local sql_connection_string="Server=tcp:$azure_sql_server_fqdn,1433;Initial Catalog=$azure_sql_database_name;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;Authentication=Active Directory Default;"
        api_secrets+=("ConnectionStrings:OrderDb=$sql_connection_string")
        verbose "Added SQL connection string for standalone API execution (Key: ConnectionStrings:OrderDb)"
    fi
    
    # Define Web App secrets (EXACTLY matches PowerShell configuration)
    # Web App only needs minimal secrets for frontend operations
    local webapp_secrets=(
        "ApplicationInsights:ConnectionString=$app_insights_conn_str"
    )
    
    # Calculate total secrets for progress tracking and reporting
    local webapp_secret_count=0
    if [[ -n "$webapp_project_path" ]]; then
        webapp_secret_count=${#webapp_secrets[@]}
    fi
    TOTAL_SECRETS=$((${#apphost_secrets[@]} + ${#api_secrets[@]} + webapp_secret_count))
    
    info "Preparing to configure user secrets for all projects..."
    info "  - AppHost: ${#apphost_secrets[@]} secret(s)"
    info "  - API: ${#api_secrets[@]} secret(s)"
    info "  - Web App: ${webapp_secret_count} secret(s)"
    echo ""
    
    # Configure AppHost secrets first (orchestrator project)
    # This configures the development environment orchestration
    configure_user_secrets "$apphost_project_path" "AppHost" "${apphost_secrets[@]}"
    
    # Configure API secrets second (application project)
    # This configures the runtime application secrets
    configure_user_secrets "$api_project_path" "API" "${api_secrets[@]}"
    
    # Configure Web App secrets (if project exists)
    if [[ -n "$webapp_project_path" ]]; then
        configure_user_secrets "$webapp_project_path" "Web App" "${webapp_secrets[@]}"
    else
        info ""
        info "Skipping Web App secrets configuration (project not found)"
        ((SKIPPED_COUNT += ${#webapp_secrets[@]}))
    fi
    
    # Report comprehensive results with statistics
    # This provides visibility into what was configured and any issues
    write_section_header "Configuration Results" "sub"
    info "User Secrets Configuration Summary:"
    success "  ✓ Successfully configured: $SUCCESS_COUNT / $TOTAL_SECRETS"
    
    # Report skipped secrets (non-error condition)
    # Skipped secrets are those with empty values (unset optional environment variables)
    if [[ $SKIPPED_COUNT -gt 0 ]]; then
        info "  ⊘ Skipped (empty values): $SKIPPED_COUNT"
        verbose "Skipped secrets are typically optional configuration that wasn't provided."
    fi
    
    # Report failed secrets (error condition)
    # Failed secrets indicate problems with .NET CLI or project configuration
    if [[ $FAILED_COUNT -gt 0 ]]; then
        warning "  ✗ Failed: $FAILED_COUNT"
        echo ""
        warning "Some secrets failed to configure. Review the errors above for details."
        
        # Don't fail the entire script if some secrets were successfully set
        # Partial configuration may be sufficient for basic functionality
        if [[ $SUCCESS_COUNT -eq 0 ]]; then
            error ""
            error "CRITICAL: All user secrets failed to configure."
            error "This likely indicates a problem with .NET CLI or project configuration."
            error "Please review the errors above and ensure:"
            error "  1. .NET SDK is properly installed and accessible"
            error "  2. Project files exist at the expected locations"
            error "  3. Projects have user secrets initialized (dotnet user-secrets init)"
            error ""
            error_exit "All user secrets failed to configure. Please review errors above."
        else
            warning ""
            warning "Partial configuration completed. The application may have limited functionality."
            warning "Review failed secrets and consider manual configuration if needed."
            warning ""
        fi
    fi
    
    # Display comprehensive success summary with timing information
    # This provides a clear overview of what was accomplished
    write_section_header "Post-Provisioning Completed Successfully!" "main"
    info "Configuration Summary:"
    info "  • Total secrets defined   : $TOTAL_SECRETS"
    info "  • Successfully configured : $SUCCESS_COUNT"
    info "  • Skipped (empty)         : $SKIPPED_COUNT"
    info "  • Failed                  : $FAILED_COUNT"
    echo ""
    
    # Calculate success percentage for quick assessment
    if [[ $TOTAL_SECRETS -gt 0 ]]; then
        local success_percentage=$(( (SUCCESS_COUNT * 100) / TOTAL_SECRETS ))
        info "  Success Rate: ${success_percentage}%"
        echo ""
    fi
    
    # Display timing information for performance analysis
    info "Completion Time: $(date '+%Y-%m-%d %H:%M:%S')"
    
    local execution_end_time
    execution_end_time=$(date +%s)
    local duration=$((execution_end_time - EXECUTION_START_TIME))
    info "Duration: ${duration} seconds"
    echo ""
    
    # Provide next steps guidance
    info "Next Steps:"
    info "  1. Run 'azd up' or 'azd deploy' to deploy your application"
    info "  2. Use 'dotnet run' in your project directory for local development"
    info "  3. Review Application Insights for telemetry and diagnostics"
    echo ""
    
    verbose "Exiting with success code 0"
    exit 0
}

# Execute main function with all command-line arguments
# This is the entry point that starts script execution
main "$@"
