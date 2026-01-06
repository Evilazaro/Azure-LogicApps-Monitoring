#!/usr/bin/env bash

################################################################################
# deploy-workflow.sh
#
# SYNOPSIS
#     Deploys an Azure Logic Apps Standard workflow with placeholder replacement.
#
# DESCRIPTION
#     This script performs the following operations:
#     1. Loads azd environment variables
#     2. Validates required environment variables
#     3. Replaces placeholders in workflow.json and connections.json
#     4. Deploys the workflow to Azure Logic Apps Standard using Azure CLI zip deploy
#
# USAGE
#     ./deploy-workflow.sh [OPTIONS]
#
# OPTIONS
#     -l, --logic-app-name <name>       The name of the Azure Logic Apps Standard resource
#     -g, --resource-group <name>       The name of the Azure resource group
#     -w, --workflow-name <name>        The name of the workflow to deploy (default: ProcessingOrdersPlaced)
#     -p, --workflow-base-path <path>   Base path to workflow files
#     -s, --skip-placeholder            Skip placeholder replacement
#     -n, --dry-run                     Show what would be deployed without making changes
#     -v, --verbose                     Display detailed diagnostic information
#     -h, --help                        Display this help message and exit
#
# EXAMPLES
#     ./deploy-workflow.sh
#         Deploys the workflow using environment variables from the active azd environment.
#
#     ./deploy-workflow.sh --logic-app-name 'my-logic-app' --resource-group 'my-rg'
#         Deploys to a specific Logic App in a specific resource group.
#
#     ./deploy-workflow.sh --dry-run
#         Shows what would be deployed without making changes.
#
# EXIT CODES
#     0    Success - Deployment completed successfully
#     1    Error - Deployment failed or validation error
#
# NOTES
#     File Name      : deploy-workflow.sh
#     Author         : Azure Logic Apps Monitoring Team
#     Version        : 1.1.0
#     Last Modified  : 2026-01-06
#     Prerequisite   : Bash 4.0+, Azure CLI (az), Azure Developer CLI (azd)
#     Purpose        : Deploy Logic Apps Standard workflows via zip deployment
#     Copyright      : (c) 2025-2026. All rights reserved.
#
# LINKS
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#
# COMPONENT
#     Azure Logic Apps Monitoring - Deployment Tools
#
# ROLE
#     Workflow Deployment
#
# FUNCTIONALITY
#     Deploys Logic Apps Standard workflows with placeholder replacement
#
################################################################################

#==============================================================================
# STRICT MODE AND ERROR HANDLING
#==============================================================================

# Enable Bash strict mode for robust error handling
# -e: Exit immediately if any command exits with non-zero status
# -u: Treat unset variables as errors
# -o pipefail: Propagate errors through pipes
set -euo pipefail

# Set Internal Field Separator to default (space, tab, newline)
IFS=$' \t\n'

#==============================================================================
# SCRIPT METADATA AND CONSTANTS
#==============================================================================

# Script version following semantic versioning (MAJOR.MINOR.PATCH)
readonly SCRIPT_VERSION="1.1.0"

# Script name for consistent logging and error messages
readonly SCRIPT_NAME="deploy-workflow.sh"

# Resolve script directory for reliable path operations
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# PLACEHOLDER CONFIGURATION
#==============================================================================

# Workflow placeholders (workflow.json)
readonly -a WORKFLOW_PLACEHOLDERS=(
    'ORDERS_API_URL'
    'AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW'
)

# Connection placeholders (connections.json)
readonly -a CONNECTION_PLACEHOLDERS=(
    'AZURE_SUBSCRIPTION_ID'
    'AZURE_RESOURCE_GROUP'
    'MANAGED_IDENTITY_NAME'
    'SERVICE_BUS_CONNECTION_RUNTIME_URL'
    'AZURE_BLOB_CONNECTION_RUNTIME_URL'
)

#==============================================================================
# GLOBAL VARIABLES
#==============================================================================

# Command-line options with defaults
LOGIC_APP_NAME=""
RESOURCE_GROUP_NAME=""
WORKFLOW_NAME="ProcessingOrdersPlaced"
WORKFLOW_BASE_PATH="${SCRIPT_DIR}/../workflows/OrdersManagement/OrdersManagementLogicApp"
SKIP_PLACEHOLDER_REPLACEMENT=false
DRY_RUN=false
VERBOSE=false

#==============================================================================
# COLOR CODES FOR OUTPUT
#==============================================================================

readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_GRAY='\033[0;90m'
readonly COLOR_BOLD='\033[1m'

#==============================================================================
# ERROR HANDLING AND CLEANUP
#==============================================================================

# Temporary directory for deployment package
TEMP_DIR=""
ZIP_PATH=""

cleanup() {
    local exit_code=$?
    
    # Remove temporary files
    if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}" 2>/dev/null || true
    fi
    if [[ -n "${ZIP_PATH}" && -f "${ZIP_PATH}" ]]; then
        rm -f "${ZIP_PATH}" 2>/dev/null || true
    fi
    
    return "${exit_code}"
}

trap cleanup EXIT

handle_interrupt() {
    echo "" >&2
    log_error "Script interrupted by user"
    exit 130
}

trap handle_interrupt INT TERM

#==============================================================================
# LOGGING FUNCTIONS
#==============================================================================

log_error() {
    echo -e "${COLOR_RED}ERROR: $*${COLOR_RESET}" >&2
}

log_warning() {
    echo -e "${COLOR_YELLOW}WARNING: $*${COLOR_RESET}" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}$*${COLOR_RESET}"
}

log_info() {
    echo -e "${COLOR_CYAN}$*${COLOR_RESET}"
}

log_gray() {
    echo -e "${COLOR_GRAY}  $*${COLOR_RESET}"
}

log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

#==============================================================================
# HELP AND USAGE
#==============================================================================

show_help() {
    cat << EOF
deploy-workflow.sh - Azure Logic Apps Workflow Deployment Tool

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS]

DESCRIPTION
    Deploys an Azure Logic Apps Standard workflow with placeholder replacement.
    Uses Azure Developer CLI (azd) for environment variables and Azure CLI
    for zip deployment.

    The script performs the following operations:
    1. Loads azd environment variables
    2. Validates required environment variables
    3. Replaces placeholders in workflow.json and connections.json
    4. Deploys the workflow to Azure Logic Apps Standard using Azure CLI zip deploy

OPTIONS
    -l, --logic-app-name <name>       The name of the Azure Logic Apps Standard resource
                                      (default: from LOGIC_APP_NAME env var)
    -g, --resource-group <name>       The name of the Azure resource group
                                      (default: from AZURE_RESOURCE_GROUP env var)
    -w, --workflow-name <name>        The name of the workflow to deploy
                                      (default: ProcessingOrdersPlaced)
    -p, --workflow-base-path <path>   Base path to the Logic App workflow files
                                      (default: ../workflows/OrdersManagement/OrdersManagementLogicApp)
    -s, --skip-placeholder            Skip placeholder replacement if files are already processed
    -n, --dry-run                     Show what would be deployed without making changes
    -v, --verbose                     Display detailed diagnostic information
    -h, --help                        Display this help message and exit

EXAMPLES
    ${SCRIPT_NAME}
        Deploys the workflow using environment variables from the active azd environment.

    ${SCRIPT_NAME} --logic-app-name 'my-logic-app' --resource-group 'my-rg'
        Deploys to a specific Logic App in a specific resource group.

    ${SCRIPT_NAME} --dry-run
        Shows what would be deployed without making changes.

    ${SCRIPT_NAME} --workflow-name 'MyCustomWorkflow' --verbose
        Deploys a custom workflow with verbose logging.

PLACEHOLDERS REPLACED
    Workflow Variables (workflow.json):
    • ORDERS_API_URL
    • AZURE_STORAGE_ACCOUNT_NAME_WORKFLOW

    Connection Variables (connections.json):
    • AZURE_SUBSCRIPTION_ID
    • AZURE_RESOURCE_GROUP
    • MANAGED_IDENTITY_NAME
    • SERVICE_BUS_CONNECTION_RUNTIME_URL
    • AZURE_BLOB_CONNECTION_RUNTIME_URL

EXIT CODES
    0    Success - Deployment completed successfully
    1    Error - Deployment failed or validation error

VERSION
    ${SCRIPT_VERSION}

AUTHOR
    Azure Logic Apps Monitoring Team

COPYRIGHT
    (c) 2025-2026. All rights reserved.

SEE ALSO
    deploy-workflow.ps1 - PowerShell version of this script
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring

EOF
    exit 0
}

#==============================================================================
# ARGUMENT PARSING
#==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l|--logic-app-name)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires an argument"
                    exit 1
                fi
                LOGIC_APP_NAME="$2"
                shift 2
                ;;
            -g|--resource-group)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires an argument"
                    exit 1
                fi
                RESOURCE_GROUP_NAME="$2"
                shift 2
                ;;
            -w|--workflow-name)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires an argument"
                    exit 1
                fi
                WORKFLOW_NAME="$2"
                shift 2
                ;;
            -p|--workflow-base-path)
                if [[ -z "${2:-}" ]]; then
                    log_error "Option $1 requires an argument"
                    exit 1
                fi
                WORKFLOW_BASE_PATH="$2"
                shift 2
                ;;
            -s|--skip-placeholder)
                SKIP_PLACEHOLDER_REPLACEMENT=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information." >&2
                exit 1
                ;;
        esac
    done
}

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: initialize_azd_environment
# Description: Loads azd environment variables into the current session.
# Returns:
#   0 - Variables loaded successfully
#   1 - Failed to load variables
#------------------------------------------------------------------------------
initialize_azd_environment() {
    log_gray "Loading azd environment variables..."
    
    local azd_output
    if ! azd_output=$(azd env get-values 2>/dev/null); then
        log_warning "Could not load azd environment variables. Ensure azd environment is configured."
        return 1
    fi
    
    if [[ -z "${azd_output}" ]]; then
        log_warning "azd environment returned empty output."
        return 1
    fi
    
    local loaded_count=0
    while IFS= read -r line; do
        if [[ "${line}" =~ ^([^=]+)=\"?([^\"]*)\"?$ ]]; then
            local var_name="${BASH_REMATCH[1]}"
            local var_value="${BASH_REMATCH[2]}"
            export "${var_name}=${var_value}"
            ((loaded_count++))
            log_verbose "Set environment variable: ${var_name}"
        fi
    done <<< "${azd_output}"
    
    log_success "  Loaded ${loaded_count} environment variables from azd."
    return 0
}

#------------------------------------------------------------------------------
# Function: test_required_environment_variables
# Description: Validates that all required environment variables are set.
# Arguments:
#   $@ - Array of variable names to check
# Returns:
#   0 - All variables are set
#   1 - One or more variables are missing
#------------------------------------------------------------------------------
test_required_environment_variables() {
    local -a var_names=("$@")
    local -a missing_vars=()
    
    for var_name in "${var_names[@]}"; do
        local var_value="${!var_name:-}"
        if [[ -z "${var_value}" ]]; then
            missing_vars+=("${var_name}")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_warning "Missing environment variables: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Function: get_masked_value
# Description: Returns a masked version of sensitive values for display.
# Arguments:
#   $1 - Value to mask
#   $2 - Variable name (for determining if masking is needed)
# Returns:
#   Masked or original value via stdout
#------------------------------------------------------------------------------
get_masked_value() {
    local value="${1:-}"
    local var_name="${2:-}"
    
    if [[ -z "${value}" ]]; then
        echo "[Not Set]"
        return
    fi
    
    if [[ "${var_name}" =~ URL|SECRET|KEY|PASSWORD|CONNECTION ]]; then
        local max_length=30
        if [[ ${#value} -lt ${max_length} ]]; then
            max_length=${#value}
        fi
        echo "${value:0:${max_length}}..."
    else
        echo "${value}"
    fi
}

#------------------------------------------------------------------------------
# Function: update_placeholder_content
# Description: Replaces placeholders in content with environment variable values.
# Arguments:
#   $1 - Content to process
#   $@ - Variable names for placeholders
# Returns:
#   Updated content via stdout
#------------------------------------------------------------------------------
update_placeholder_content() {
    local content="$1"
    shift
    local -a var_names=("$@")
    
    for var_name in "${var_names[@]}"; do
        local placeholder="\${${var_name}}"
        local env_value="${!var_name:-}"
        if [[ -n "${env_value}" ]]; then
            content="${content//\$\{${var_name}\}/${env_value}}"
            log_verbose "Replaced \${${var_name}} with value from ${var_name}"
        fi
    done
    
    echo "${content}"
}

#------------------------------------------------------------------------------
# Function: test_azure_cli_connection
# Description: Validates Azure CLI connection and returns account information.
# Returns:
#   0 - Connected and authenticated
#   1 - Not connected
#------------------------------------------------------------------------------
test_azure_cli_connection() {
    local account_json
    if ! account_json=$(az account show --output json 2>/dev/null); then
        log_error "Not connected to Azure. Please run 'az login' first."
        return 1
    fi
    
    # Parse account information
    AZURE_ACCOUNT_ID=$(echo "${account_json}" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "unknown")
    AZURE_USER_NAME=$(echo "${account_json}" | grep -o '"user"[[:space:]]*:[[:space:]]*{[^}]*}' | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "unknown")
    AZURE_SUBSCRIPTION_ID_CURRENT=$(echo "${account_json}" | grep -o '"id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "unknown")
    
    return 0
}

#------------------------------------------------------------------------------
# Function: deploy_logic_app_workflow
# Description: Deploys workflow to Azure Logic Apps Standard using zip deployment.
# Returns:
#   0 - Deployment successful
#   1 - Deployment failed
#------------------------------------------------------------------------------
deploy_logic_app_workflow() {
    local workflow_content="$1"
    local connections_content="$2"
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "  [DRY-RUN] Would deploy workflow '${WORKFLOW_NAME}' to Logic App '${LOGIC_APP_NAME}'"
        log_verbose "  [DRY-RUN] Resource Group: ${RESOURCE_GROUP_NAME}"
        log_verbose "  [DRY-RUN] Would create zip package and deploy via az logicapp deployment"
        return 0
    fi
    
    # Create temporary directory for deployment package
    TEMP_DIR=$(mktemp -d)
    log_verbose "Created temporary directory: ${TEMP_DIR}"
    
    # Create workflow directory structure
    local workflow_dir="${TEMP_DIR}/${WORKFLOW_NAME}"
    mkdir -p "${workflow_dir}"
    
    # Write workflow.json
    echo "${workflow_content}" > "${workflow_dir}/workflow.json"
    log_verbose "Created workflow file: ${workflow_dir}/workflow.json"
    
    # Write connections.json at root level
    echo "${connections_content}" > "${TEMP_DIR}/connections.json"
    log_verbose "Created connections file: ${TEMP_DIR}/connections.json"
    
    # Copy host.json if it exists
    local source_host_json="${WORKFLOW_BASE_PATH}/host.json"
    if [[ -f "${source_host_json}" ]]; then
        cp "${source_host_json}" "${TEMP_DIR}/host.json"
        log_verbose "Copied host.json"
    fi
    
    # Create zip file
    ZIP_PATH=$(mktemp).zip
    log_gray "Creating deployment package..."
    
    (cd "${TEMP_DIR}" && zip -r "${ZIP_PATH}" . >/dev/null 2>&1)
    log_verbose "Created zip file: ${ZIP_PATH}"
    
    # Deploy using Azure CLI
    log_gray "Deploying to Logic App via zip deploy..."
    
    local deploy_output
    if ! deploy_output=$(az logicapp deployment source config-zip \
        --resource-group "${RESOURCE_GROUP_NAME}" \
        --name "${LOGIC_APP_NAME}" \
        --src "${ZIP_PATH}" \
        --output json 2>&1); then
        
        # Try alternative deployment method
        log_verbose "Trying alternative deployment method..."
        if ! deploy_output=$(az webapp deployment source config-zip \
            --resource-group "${RESOURCE_GROUP_NAME}" \
            --name "${LOGIC_APP_NAME}" \
            --src "${ZIP_PATH}" \
            --output json 2>&1); then
            log_error "Deployment failed: ${deploy_output}"
            return 1
        fi
    fi
    
    log_verbose "Deployment output: ${deploy_output}"
    return 0
}

#------------------------------------------------------------------------------
# Function: write_deployment_summary
# Description: Displays deployment summary with environment variable values.
#------------------------------------------------------------------------------
write_deployment_summary() {
    echo ""
    log_info "=== Environment Variables Summary ==="
    
    echo -e "${COLOR_YELLOW}  Workflow Variables:${COLOR_RESET}"
    for var_name in "${WORKFLOW_PLACEHOLDERS[@]}"; do
        local env_value="${!var_name:-}"
        local display_value
        display_value=$(get_masked_value "${env_value}" "${var_name}")
        log_gray "  ${var_name}: ${display_value}"
    done
    
    echo -e "${COLOR_YELLOW}  Connection Variables:${COLOR_RESET}"
    for var_name in "${CONNECTION_PLACEHOLDERS[@]}"; do
        local env_value="${!var_name:-}"
        local display_value
        display_value=$(get_masked_value "${env_value}" "${var_name}")
        log_gray "  ${var_name}: ${display_value}"
    done
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Display header
    echo ""
    log_info "╔══════════════════════════════════════════════════════════════╗"
    log_info "║     Azure Logic Apps Workflow Deployment Script              ║"
    log_info "║     (Using Azure CLI and Azure Developer CLI)                ║"
    log_info "╚══════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Step 1: Load azd environment variables
    echo -e "${COLOR_YELLOW}[1/5] Loading azd environment...${COLOR_RESET}"
    if ! initialize_azd_environment; then
        log_warning "azd environment not loaded. Using existing environment variables."
    fi
    
    # Resolve LogicAppName and ResourceGroupName from environment if not provided
    if [[ -z "${LOGIC_APP_NAME}" ]]; then
        LOGIC_APP_NAME="${LOGIC_APP_NAME:-}"
        if [[ -z "${LOGIC_APP_NAME}" ]]; then
            log_error "LogicAppName parameter is required or LOGIC_APP_NAME environment variable must be set."
            exit 1
        fi
        log_gray "Using Logic App from environment: ${LOGIC_APP_NAME}"
    fi
    
    if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then
        RESOURCE_GROUP_NAME="${AZURE_RESOURCE_GROUP:-}"
        if [[ -z "${RESOURCE_GROUP_NAME}" ]]; then
            log_error "ResourceGroupName parameter is required or AZURE_RESOURCE_GROUP environment variable must be set."
            exit 1
        fi
        log_gray "Using Resource Group from environment: ${RESOURCE_GROUP_NAME}"
    fi
    
    # Step 2: Validate Azure CLI connection
    echo ""
    echo -e "${COLOR_YELLOW}[2/5] Validating Azure CLI connection...${COLOR_RESET}"
    if ! test_azure_cli_connection; then
        exit 1
    fi
    log_success "  Connected as: ${AZURE_USER_NAME}"
    log_success "  Subscription: ${AZURE_ACCOUNT_ID} (${AZURE_SUBSCRIPTION_ID_CURRENT})"
    
    # Step 3: Validate environment variables
    echo ""
    echo -e "${COLOR_YELLOW}[3/5] Validating environment variables...${COLOR_RESET}"
    
    if [[ "${SKIP_PLACEHOLDER_REPLACEMENT}" != "true" ]]; then
        local -a all_placeholders=("${WORKFLOW_PLACEHOLDERS[@]}" "${CONNECTION_PLACEHOLDERS[@]}")
        
        if ! test_required_environment_variables "${all_placeholders[@]}"; then
            log_error "Required environment variables are missing. Please set all required variables or run 'azd provision' first."
            exit 1
        fi
        log_success "  All required environment variables are set."
        write_deployment_summary
    else
        log_gray "Skipping environment variable validation (placeholder replacement disabled)."
    fi
    
    # Step 4: Resolve file paths and process placeholders
    echo ""
    echo -e "${COLOR_YELLOW}[4/5] Processing workflow files...${COLOR_RESET}"
    
    local workflow_file_path="${WORKFLOW_BASE_PATH}/${WORKFLOW_NAME}/workflow.json"
    local connections_file_path="${WORKFLOW_BASE_PATH}/connections.json"
    
    # Validate files exist
    if [[ ! -f "${workflow_file_path}" ]]; then
        log_error "Workflow file not found: ${workflow_file_path}"
        exit 1
    fi
    if [[ ! -f "${connections_file_path}" ]]; then
        log_error "Connections file not found: ${connections_file_path}"
        exit 1
    fi
    
    log_gray "Workflow file: ${workflow_file_path}"
    log_gray "Connections file: ${connections_file_path}"
    
    # Process files
    local workflow_content
    local connections_content
    
    if [[ "${SKIP_PLACEHOLDER_REPLACEMENT}" == "true" ]]; then
        log_gray "Reading files without placeholder replacement..."
        workflow_content=$(cat "${workflow_file_path}")
        connections_content=$(cat "${connections_file_path}")
    else
        log_gray "Replacing placeholders in workflow.json..."
        workflow_content=$(cat "${workflow_file_path}")
        workflow_content=$(update_placeholder_content "${workflow_content}" "${WORKFLOW_PLACEHOLDERS[@]}")
        
        log_gray "Replacing placeholders in connections.json..."
        connections_content=$(cat "${connections_file_path}")
        connections_content=$(update_placeholder_content "${connections_content}" "${CONNECTION_PLACEHOLDERS[@]}")
    fi
    
    log_success "  Files processed successfully."
    
    # Step 5: Deploy workflow via zip deploy
    echo ""
    echo -e "${COLOR_YELLOW}[5/5] Deploying workflow to Azure Logic Apps via zip deploy...${COLOR_RESET}"
    log_gray "Logic App: ${LOGIC_APP_NAME}"
    log_gray "Resource Group: ${RESOURCE_GROUP_NAME}"
    log_gray "Workflow: ${WORKFLOW_NAME}"
    
    if ! deploy_logic_app_workflow "${workflow_content}" "${connections_content}"; then
        echo ""
        echo -e "${COLOR_RED}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
        echo -e "${COLOR_RED}║                    Deployment Failed                         ║${COLOR_RESET}"
        echo -e "${COLOR_RED}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
        echo ""
        exit 1
    fi
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        log_success "  WhatIf: Workflow deployment would succeed."
    else
        log_success "  Workflow deployed successfully!"
    fi
    
    # Post-deployment notes
    echo ""
    log_info "=== Post-Deployment Notes ==="
    log_gray "- Connections are configured in connections.json"
    log_gray "- Ensure API connections are authorized in Azure Portal"
    log_gray "- Verify managed identity has required permissions"
    
    echo ""
    echo -e "${COLOR_GREEN}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║              Deployment Completed Successfully!              ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
}

#==============================================================================
# SCRIPT ENTRY POINT
#==============================================================================

log_verbose "Script started: ${SCRIPT_NAME} version ${SCRIPT_VERSION}"
main "$@"
