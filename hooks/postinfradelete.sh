#!/usr/bin/env bash

# ==============================================================================
# Post-Infrastructure Delete Hook for Azure Developer CLI (azd)
# ==============================================================================
#
# SYNOPSIS:
#   Purges soft-deleted Logic Apps Standard resources after infrastructure deletion.
#
# DESCRIPTION:
#   When Azure Logic Apps Standard are deleted, they enter a soft-delete state
#   and must be explicitly purged to fully remove them. This script handles
#   the purge operation to ensure complete cleanup.
#
#   The script performs the following operations:
#   - Validates required environment variables (subscription, location)
#   - Authenticates to Azure using the current session
#   - Retrieves the list of soft-deleted Logic Apps in the specified location
#   - Purges any Logic Apps that match the resource group naming pattern
#
# USAGE:
#   ./postinfradelete.sh [OPTIONS]
#
# OPTIONS:
#   --force, -f     Skip confirmation prompts
#   --verbose, -v   Enable verbose output
#   --help, -h      Show this help message
#
# ENVIRONMENT VARIABLES:
#   AZURE_SUBSCRIPTION_ID   - Required: Azure subscription ID
#   AZURE_LOCATION         - Required: Azure region
#   AZURE_RESOURCE_GROUP   - Optional: Filter by resource group name
#   LOGIC_APP_NAME         - Optional: Filter by Logic App name pattern
#
# PREREQUISITES:
#   - Azure CLI 2.50+ installed and in PATH
#   - Logged in to Azure CLI (az login)
#   - jq installed for JSON parsing
#
# EXAMPLES:
#   ./postinfradelete.sh
#   ./postinfradelete.sh --force --verbose
#
# AUTHOR:
#   Evilazaro | Principal Cloud Solution Architect | Microsoft
#
# VERSION:
#   1.0.0
#
# LAST MODIFIED:
#   2026-01-09
#
# LINK:
#   https://github.com/Evilazaro/Azure-LogicApps-Monitoring
# ==============================================================================

set -euo pipefail

# Script version
readonly SCRIPT_VERSION="1.0.0"

# Default options
FORCE=false
VERBOSE=false

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# Exit codes
readonly EXIT_SUCCESS=0
readonly EXIT_ERROR=1

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "$(date '+%H:%M:%S') ${CYAN}[i]${NC} $1"
}

log_success() {
    echo -e "$(date '+%H:%M:%S') ${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "$(date '+%H:%M:%S') ${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "$(date '+%H:%M:%S') ${RED}[✗]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "$(date '+%H:%M:%S') ${CYAN}[v]${NC} $1"
    fi
}

show_help() {
    cat << EOF
Post-Infrastructure Delete Hook v${SCRIPT_VERSION}
Purges soft-deleted Logic Apps Standard resources.

Usage: $(basename "$0") [OPTIONS]

Options:
    --force, -f     Skip confirmation prompts
    --verbose, -v   Enable verbose output
    --help, -h      Show this help message

Environment Variables:
    AZURE_SUBSCRIPTION_ID   Required: Azure subscription ID
    AZURE_LOCATION         Required: Azure region
    AZURE_RESOURCE_GROUP   Optional: Filter by resource group
    LOGIC_APP_NAME         Optional: Filter by Logic App name

Examples:
    $(basename "$0")
    $(basename "$0") --force --verbose
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                FORCE=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit $EXIT_SUCCESS
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit $EXIT_ERROR
                ;;
        esac
    done
}

check_azure_cli() {
    if ! command -v az &> /dev/null; then
        log_error "Azure CLI (az) is not installed or not in PATH"
        return 1
    fi
    log_verbose "Azure CLI found at: $(command -v az)"
    return 0
}

check_jq() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed or not in PATH"
        log_info "Install jq: https://stedolan.github.io/jq/download/"
        return 1
    fi
    log_verbose "jq found at: $(command -v jq)"
    return 0
}

check_azure_login() {
    if ! az account show --output none 2>/dev/null; then
        log_error "Not logged in to Azure CLI. Run 'az login' first."
        return 1
    fi
    return 0
}

check_required_env_var() {
    local var_name=$1
    local var_value="${!var_name:-}"
    
    if [[ -z "$var_value" ]]; then
        log_warning "Environment variable '$var_name' is not set or empty"
        return 1
    fi
    log_verbose "Environment variable '$var_name' is set"
    return 0
}

get_env_value() {
    local var_name=$1
    local default_value="${2:-}"
    local var_value="${!var_name:-}"
    
    if [[ -n "$var_value" ]]; then
        echo "$var_value"
    else
        echo "$default_value"
    fi
}

get_deleted_logic_apps() {
    local subscription_id=$1
    local location=$2
    
    log_info "Querying for soft-deleted Logic Apps in location '$location'..."
    
    local uri="https://management.azure.com/subscriptions/${subscription_id}/providers/Microsoft.Web/locations/${location}/deletedSites?api-version=2023-12-01"
    log_verbose "Calling REST API: $uri"
    
    local response
    if ! response=$(az rest --method GET --uri "$uri" --output json 2>&1); then
        log_warning "Failed to query deleted sites: $response"
        echo "[]"
        return
    fi
    
    # Filter for Logic Apps (kind contains 'workflowapp')
    local logic_apps
    logic_apps=$(echo "$response" | jq '[.value[]? | select(.properties.kind | test("workflowapp"; "i"))]')
    
    local count
    count=$(echo "$logic_apps" | jq 'length')
    
    if [[ "$count" -eq 0 ]]; then
        log_info "No soft-deleted Logic Apps found in location '$location'"
        echo "[]"
        return
    fi
    
    log_info "Found $count soft-deleted Logic App(s)"
    echo "$logic_apps"
}

purge_logic_app() {
    local deleted_site_id=$1
    local site_name=$2
    
    log_info "Purging Logic App: $site_name"
    log_verbose "Deleted site ID: $deleted_site_id"
    
    local uri="https://management.azure.com${deleted_site_id}?api-version=2023-12-01"
    log_verbose "Calling REST API: DELETE $uri"
    
    if ! az rest --method DELETE --uri "$uri" 2>&1; then
        log_error "Failed to purge Logic App '$site_name'"
        return 1
    fi
    
    log_success "Successfully purged Logic App: $site_name"
    return 0
}

# ==============================================================================
# Main Function
# ==============================================================================

main() {
    log_info "========================================"
    log_info "Post-Infrastructure Delete Hook v${SCRIPT_VERSION}"
    log_info "Logic Apps Purge Script"
    log_info "========================================"
    
    # Validate prerequisites
    log_info "Validating prerequisites..."
    
    if ! check_azure_cli; then
        return $EXIT_ERROR
    fi
    
    if ! check_jq; then
        return $EXIT_ERROR
    fi
    
    if ! check_azure_login; then
        return $EXIT_ERROR
    fi
    
    log_success "Prerequisites validated"
    
    # Check required environment variables
    local all_valid=true
    
    if ! check_required_env_var "AZURE_SUBSCRIPTION_ID"; then
        all_valid=false
    fi
    
    if ! check_required_env_var "AZURE_LOCATION"; then
        all_valid=false
    fi
    
    if [[ "$all_valid" != "true" ]]; then
        log_warning "Missing required environment variables. Skipping purge."
        log_info "Hint: This script is designed to run as an azd hook where environment variables are set."
        return $EXIT_SUCCESS  # Don't fail the hook, just skip
    fi
    
    # Get environment values
    local subscription_id
    subscription_id=$(get_env_value "AZURE_SUBSCRIPTION_ID")
    
    local location
    location=$(get_env_value "AZURE_LOCATION")
    
    local resource_group
    resource_group=$(get_env_value "AZURE_RESOURCE_GROUP")
    
    local logic_app_name
    logic_app_name=$(get_env_value "LOGIC_APP_NAME")
    
    log_info "Configuration:"
    log_info "  Subscription: $subscription_id"
    log_info "  Location: $location"
    [[ -n "$resource_group" ]] && log_info "  Resource Group Filter: $resource_group"
    [[ -n "$logic_app_name" ]] && log_info "  Logic App Name Filter: $logic_app_name"
    
    # Get deleted Logic Apps
    log_info "Starting Logic App purge process..."
    
    local deleted_logic_apps
    deleted_logic_apps=$(get_deleted_logic_apps "$subscription_id" "$location")
    
    local count
    count=$(echo "$deleted_logic_apps" | jq 'length')
    
    if [[ "$count" -eq 0 ]]; then
        log_success "No Logic Apps to purge"
        return $EXIT_SUCCESS
    fi
    
    # Filter by resource group if specified
    if [[ -n "$resource_group" ]]; then
        log_verbose "Filtering by resource group: $resource_group"
        deleted_logic_apps=$(echo "$deleted_logic_apps" | jq --arg rg "$resource_group" '[.[] | select(.properties.resourceGroup == $rg)]')
        count=$(echo "$deleted_logic_apps" | jq 'length')
        
        if [[ "$count" -eq 0 ]]; then
            log_info "No deleted Logic Apps found matching resource group '$resource_group'"
            return $EXIT_SUCCESS
        fi
    fi
    
    # Filter by Logic App name if specified
    if [[ -n "$logic_app_name" ]]; then
        log_verbose "Filtering by Logic App name: $logic_app_name"
        deleted_logic_apps=$(echo "$deleted_logic_apps" | jq --arg name "$logic_app_name" '[.[] | select(.properties.deletedSiteName | test($name; "i"))]')
        count=$(echo "$deleted_logic_apps" | jq 'length')
        
        if [[ "$count" -eq 0 ]]; then
            log_info "No deleted Logic Apps found matching name pattern '$logic_app_name'"
            return $EXIT_SUCCESS
        fi
    fi
    
    log_info "Found $count Logic App(s) to purge:"
    
    # List Logic Apps to be purged
    echo "$deleted_logic_apps" | jq -r '.[] | "  - \(.properties.deletedSiteName) (Resource Group: \(.properties.resourceGroup), Deleted: \(.properties.deletedTimestamp))"' | while read -r line; do
        log_info "$line"
    done
    
    # Confirmation prompt (unless --force)
    if [[ "$FORCE" != "true" ]]; then
        echo ""
        read -r -p "Do you want to purge these Logic Apps? [y/N] " response
        case "$response" in
            [yY][eE][sS]|[yY])
                log_info "Proceeding with purge..."
                ;;
            *)
                log_info "Purge cancelled by user"
                return $EXIT_SUCCESS
                ;;
        esac
    fi
    
    # Purge each Logic App
    local purged_count=0
    
    while IFS= read -r logic_app; do
        local name
        name=$(echo "$logic_app" | jq -r '.properties.deletedSiteName')
        
        local deleted_site_id
        deleted_site_id=$(echo "$logic_app" | jq -r '.id')
        
        if purge_logic_app "$deleted_site_id" "$name"; then
            ((purged_count++))
        fi
    done < <(echo "$deleted_logic_apps" | jq -c '.[]')
    
    log_info "========================================"
    log_info "Purge Summary"
    log_info "========================================"
    log_success "Logic Apps purged: $purged_count"
    
    return $EXIT_SUCCESS
}

# ==============================================================================
# Script Entry Point
# ==============================================================================

parse_arguments "$@"
main
exit_code=$?
log_info "Script completed with exit code: $exit_code"
exit $exit_code
