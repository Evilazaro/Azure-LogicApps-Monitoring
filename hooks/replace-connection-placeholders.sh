#!/usr/bin/env bash

################################################################################
# Replace Connection Placeholders Script
#
# SYNOPSIS:
#     Replaces placeholder tokens in connections.json with environment variable
#     values.
#
# DESCRIPTION:
#     This script reads the connections.json file and replaces all ${VARIABLE_NAME}
#     placeholders with the corresponding environment variable values.
#     
#     The script integrates with Azure Developer CLI (azd) to automatically load
#     environment variables from the active azd environment.
#
# PARAMETERS:
#     -f, --file <path>       Path to the connections.json file (optional)
#     -o, --output <path>     Output file path (optional, overwrites input if not specified)
#     -n, --dry-run           Show what changes would be made without modifying files
#     -v, --verbose           Enable verbose output
#     -h, --help              Display this help message
#
# EXAMPLES:
#     ./replace-connection-placeholders.sh
#         Replaces placeholders using environment variables from active azd environment.
#
#     ./replace-connection-placeholders.sh -f "./custom/connections.json" -o "./output/connections.json"
#         Processes a custom connections file and outputs to a specified location.
#
#     ./replace-connection-placeholders.sh --dry-run
#         Shows what changes would be made without actually modifying any files.
#
# NOTES:
#     File Name      : replace-connection-placeholders.sh
#     Author         :Evilazaro | Principal Cloud Solution Architect | Microsoft
#     Version        : 1.1.0
#     Last Modified  : 2026-01-06
#     Prerequisite   : Bash 4.0 or higher
#     Prerequisite   : Azure Developer CLI (azd)
#     Copyright      : (c) 2025-2026. All rights reserved.
#
# LINK:
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
################################################################################

#==============================================================================
# STRICT MODE AND ERROR HANDLING
#==============================================================================

# Enable Bash strict mode for robust error handling
# -e: Exit immediately if any command exits with non-zero status
# -u: Treat unset variables as errors
# -o pipefail: Propagate errors through pipes
set -euo pipefail

# Set Internal Field Separator to default
IFS=$' \t\n'

#==============================================================================
# SCRIPT METADATA AND CONFIGURATION
#==============================================================================

readonly SCRIPT_VERSION="1.1.0"
readonly SCRIPT_NAME="replace-connection-placeholders.sh"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default connections file path (relative to script directory)
readonly DEFAULT_CONNECTIONS_FILE="${SCRIPT_DIR}/../workflows/OrdersManagement/OrdersManagementLogicApp/connections.json"

# Define required environment variables (associative array)
declare -A PLACEHOLDER_MAP=(
    ['${AZURE_SUBSCRIPTION_ID}']='AZURE_SUBSCRIPTION_ID'
    ['${AZURE_RESOURCE_GROUP}']='AZURE_RESOURCE_GROUP'
    ['${MANAGED_IDENTITY_NAME}']='MANAGED_IDENTITY_NAME'
    ['${SERVICE_BUS_CONNECTION_RUNTIME_URL}']='SERVICE_BUS_CONNECTION_RUNTIME_URL'
    ['${AZURE_BLOB_CONNECTION_RUNTIME_URL}']='AZURE_BLOB_CONNECTION_RUNTIME_URL'
)

#==============================================================================
# GLOBAL VARIABLES
#==============================================================================

CONNECTIONS_FILE=""
OUTPUT_FILE=""
DRY_RUN=false
VERBOSE=false

#==============================================================================
# COLOR CODES FOR OUTPUT
#==============================================================================

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly GRAY='\033[0;37m'
readonly NC='\033[0m' # No Color

#==============================================================================
# ERROR HANDLING AND CLEANUP
#==============================================================================

cleanup() {
    local exit_code=$?
    # Cleanup temporary files if any
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

log_info() {
    echo -e "${CYAN}$*${NC}"
}

log_success() {
    echo -e "${GREEN}$*${NC}"
}

log_warning() {
    echo -e "${YELLOW}WARNING: $*${NC}" >&2
}

log_error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
}

log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${GRAY}[VERBOSE] $*${NC}" >&2
    fi
}

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: show_help
# Description: Displays usage information and exits
#------------------------------------------------------------------------------
show_help() {
    cat << EOF
${SCRIPT_NAME} v${SCRIPT_VERSION}

Replaces placeholder tokens in connections.json with environment variable values.

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

OPTIONS:
    -f, --file <path>       Path to the connections.json file
                            Default: ${DEFAULT_CONNECTIONS_FILE}
    -o, --output <path>     Output file path (overwrites input if not specified)
    -n, --dry-run           Show what changes would be made without modifying files
    -v, --verbose           Enable verbose output
    -h, --help              Display this help message

EXAMPLES:
    ${SCRIPT_NAME}
        Process default connections.json with azd environment variables.

    ${SCRIPT_NAME} -f ./custom/connections.json -o ./output/connections.json
        Process custom file and output to specified location.

    ${SCRIPT_NAME} --dry-run --verbose
        Preview changes with detailed output.

ENVIRONMENT VARIABLES:
    The following environment variables are replaced:
    - AZURE_SUBSCRIPTION_ID
    - AZURE_RESOURCE_GROUP
    - MANAGED_IDENTITY_NAME
    - SERVICE_BUS_CONNECTION_RUNTIME_URL
    - AZURE_BLOB_CONNECTION_RUNTIME_URL

EOF
    exit 0
}

#------------------------------------------------------------------------------
# Function: load_azd_environment
# Description: Loads environment variables from Azure Developer CLI
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
load_azd_environment() {
    log_info "Loading azd environment variables..."
    
    local azd_output
    local loaded_count=0
    
    if ! command -v azd &> /dev/null; then
        log_warning "Azure Developer CLI (azd) is not installed."
        return 1
    fi
    
    if ! azd_output=$(azd env get-values 2>/dev/null); then
        log_warning "Could not load azd environment variables. Ensure 'azd env' is configured."
        return 1
    fi
    
    while IFS='=' read -r key value; do
        # Skip empty lines
        [[ -z "${key}" ]] && continue
        
        # Remove quotes from value if present
        value="${value%\"}"
        value="${value#\"}"
        
        # Only set if not already in environment
        if [[ -z "${!key:-}" ]]; then
            export "${key}=${value}"
            log_verbose "Set environment variable: ${key}"
            ((loaded_count++))
        fi
    done <<< "${azd_output}"
    
    log_success "Loaded ${loaded_count} environment variables from azd."
    return 0
}

#------------------------------------------------------------------------------
# Function: validate_environment_variables
# Description: Validates that all required environment variables are set
# Returns: 0 if all variables are set, 1 otherwise
#------------------------------------------------------------------------------
validate_environment_variables() {
    local missing_vars=()
    
    for placeholder in "${!PLACEHOLDER_MAP[@]}"; do
        local env_var="${PLACEHOLDER_MAP[${placeholder}]}"
        local value="${!env_var:-}"
        
        if [[ -z "${value}" ]]; then
            missing_vars+=("${env_var}")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "The following required environment variables are not set: ${missing_vars[*]}"
        return 1
    fi
    
    return 0
}

#------------------------------------------------------------------------------
# Function: get_masked_value
# Description: Returns a masked version of sensitive values
# Arguments:
#   $1 - The value to mask
#   $2 - The variable name (used to determine if masking is needed)
# Returns: Masked or original value via stdout
#------------------------------------------------------------------------------
get_masked_value() {
    local value="${1:-}"
    local var_name="${2}"
    
    if [[ -z "${value}" ]]; then
        echo "[Not Set]"
        return
    fi
    
    # Mask sensitive values (URLs, secrets, keys, passwords, connections)
    if [[ "${var_name}" =~ URL|SECRET|KEY|PASSWORD|CONNECTION ]]; then
        local max_length=20
        if [[ ${#value} -lt ${max_length} ]]; then
            max_length=${#value}
        fi
        echo "${value:0:${max_length}}..."
        return
    fi
    
    echo "${value}"
}

#------------------------------------------------------------------------------
# Function: write_replacement_summary
# Description: Displays a summary of the placeholder replacements
#------------------------------------------------------------------------------
write_replacement_summary() {
    log_info "=== Replacement Summary ==="
    
    for placeholder in "${!PLACEHOLDER_MAP[@]}"; do
        local env_var="${PLACEHOLDER_MAP[${placeholder}]}"
        local value="${!env_var:-}"
        local display_value
        display_value=$(get_masked_value "${value}" "${env_var}")
        echo -e "  ${GRAY}${env_var}: ${display_value}${NC}"
    done
}

#------------------------------------------------------------------------------
# Function: replace_placeholders
# Description: Replaces placeholders in the content with environment variable values
# Arguments:
#   $1 - Input file path
#   $2 - Output file path
# Returns: 0 on success, 1 on failure
#------------------------------------------------------------------------------
replace_placeholders() {
    local input_file="${1}"
    local output_file="${2}"
    
    log_info "Reading connections file..."
    
    if [[ ! -f "${input_file}" ]]; then
        log_error "Connections file not found: ${input_file}"
        return 1
    fi
    
    local content
    content=$(cat "${input_file}")
    
    log_info "Replacing placeholders with environment variable values..."
    
    for placeholder in "${!PLACEHOLDER_MAP[@]}"; do
        local env_var="${PLACEHOLDER_MAP[${placeholder}]}"
        local value="${!env_var:-}"
        
        if [[ -n "${value}" ]]; then
            # Escape special characters in placeholder for sed
            local escaped_placeholder
            escaped_placeholder=$(printf '%s\n' "${placeholder}" | sed 's/[[\.*^$()+?{|]/\\&/g')
            
            # Escape special characters in value for sed
            local escaped_value
            escaped_value=$(printf '%s\n' "${value}" | sed 's/[&/\]/\\&/g')
            
            content=$(echo "${content}" | sed "s|${escaped_placeholder}|${escaped_value}|g")
            log_verbose "Replaced ${placeholder} with value from ${env_var}"
        fi
    done
    
    if [[ "${DRY_RUN}" == "true" ]]; then
        echo ""
        log_warning "Dry-run: No changes were made to the file."
        return 0
    fi
    
    # Ensure output directory exists
    local output_dir
    output_dir=$(dirname "${output_file}")
    if [[ -n "${output_dir}" && ! -d "${output_dir}" ]]; then
        mkdir -p "${output_dir}"
    fi
    
    # Write the updated content
    log_info "Writing updated connections file to: ${output_file}"
    echo -n "${content}" > "${output_file}"
    
    echo ""
    log_success "Successfully replaced all placeholders in connections.json"
    echo ""
    
    write_replacement_summary
    
    return 0
}

#==============================================================================
# ARGUMENT PARSING
#==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "${1}" in
            -f|--file)
                CONNECTIONS_FILE="${2}"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="${2}"
                shift 2
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
                log_error "Unknown option: ${1}"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
    
    # Set defaults if not provided
    if [[ -z "${CONNECTIONS_FILE}" ]]; then
        CONNECTIONS_FILE="${DEFAULT_CONNECTIONS_FILE}"
    fi
    
    if [[ -z "${OUTPUT_FILE}" ]]; then
        OUTPUT_FILE="${CONNECTIONS_FILE}"
    fi
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    log_info "=== Connection Placeholders Replacement Script ==="
    echo ""
    
    # Load azd environment variables
    load_azd_environment || true
    
    # Resolve the connections file path
    local resolved_path
    if [[ ! -f "${CONNECTIONS_FILE}" ]]; then
        log_error "Connections file not found: ${CONNECTIONS_FILE}"
        exit 1
    fi
    resolved_path=$(realpath "${CONNECTIONS_FILE}")
    
    echo -e "${YELLOW}Input file: ${resolved_path}${NC}"
    
    # Validate environment variables
    echo -e "${YELLOW}Validating required environment variables...${NC}"
    if ! validate_environment_variables; then
        log_error "Required environment variables are missing"
        exit 1
    fi
    log_success "All required environment variables are set."
    
    # Resolve output path
    local output_path
    if [[ -n "${OUTPUT_FILE}" && "${OUTPUT_FILE}" != "${CONNECTIONS_FILE}" ]]; then
        output_path="${OUTPUT_FILE}"
    else
        output_path="${resolved_path}"
    fi
    
    # Replace placeholders
    if ! replace_placeholders "${resolved_path}" "${output_path}"; then
        log_error "Script execution failed"
        exit 1
    fi
}

# Parse command line arguments
parse_arguments "$@"

# Run main function
main
