#!/usr/bin/env bash

################################################################################
# clean-secrets.sh
#
# SYNOPSIS
#     Clears .NET user secrets for all projects in the solution.
#
# DESCRIPTION
#     This script clears all .NET user secrets from the configured projects to
#     ensure a clean state. This is useful before re-provisioning or when
#     troubleshooting configuration issues.
#
#     The script performs the following operations:
#     - Validates .NET SDK availability and version
#     - Validates project paths and structure
#     - Clears user secrets for app.AppHost project
#     - Clears user secrets for eShop.Orders.API project
#     - Clears user secrets for eShop.Web.App project
#     - Provides comprehensive logging and error handling
#     - Generates execution summary with statistics
#
# USAGE
#     ./clean-secrets.sh [OPTIONS]
#
# OPTIONS
#     -f, --force      Skip confirmation prompts and force execution
#     -n, --dry-run    Show what would be executed without making changes
#     -v, --verbose    Display detailed diagnostic information
#     -h, --help       Display this help message and exit
#
# EXAMPLES
#     ./clean-secrets.sh
#         Clears all user secrets with confirmation prompt.
#
#     ./clean-secrets.sh --force
#         Clears all user secrets without confirmation.
#
#     ./clean-secrets.sh --dry-run --verbose
#         Shows what would be cleared without making changes, with verbose output.
#
# EXIT CODES
#     0    Success - All operations completed successfully
#     1    Error - Fatal error occurred or validation failed
#
# NOTES
#     File Name      : clean-secrets.sh
#     Author         : Azure-LogicApps-Monitoring Team
#     Version        : 2.0.0
#     Last Modified  : 2025-12-29
#     Prerequisite   : .NET SDK 10.0 or higher
#     Purpose        : Clean .NET user secrets before deployment
#     Copyright      : (c) 2025. All rights reserved.
#
# LINKS
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#
# COMPONENT
#     Azure Logic Apps Monitoring - Development Tools
#
# ROLE
#     Development Environment Preparation
#
# FUNCTIONALITY
#     Clears .NET user secrets to ensure clean state before provisioning
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
# Protects against word splitting vulnerabilities
IFS=$' \t\n'

#==============================================================================
# SCRIPT METADATA AND CONSTANTS
#==============================================================================

# Script version following semantic versioning (MAJOR.MINOR.PATCH)
readonly SCRIPT_VERSION="2.0.0"

# Script name for consistent logging and error messages
readonly SCRIPT_NAME="clean-secrets.sh"

# Resolve script directory for reliable path operations
# Using BASH_SOURCE[0] instead of $0 for sourcing compatibility
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# PROJECT CONFIGURATION
#==============================================================================

# Project paths relative to script directory
# These projects will have their user secrets cleared
declare -A PROJECTS=(
    ["app.AppHost"]="../app.AppHost/"
    ["eShop.Orders.API"]="../src/eShop.Orders.API/"
    ["eShop.Web.App"]="../src/eShop.Web.App/"
)

#==============================================================================
# GLOBAL VARIABLES
#==============================================================================

# Command-line options
FORCE=false
DRY_RUN=false
VERBOSE=false

# Execution statistics
SUCCESS_COUNT=0
FAILURE_COUNT=0
TOTAL_COUNT=0

#==============================================================================
# COLOR CODES FOR OUTPUT
#==============================================================================

# ANSI color codes for enhanced terminal output
readonly COLOR_RESET='\033[0m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[0;33m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_BOLD='\033[1m'

#==============================================================================
# ERROR HANDLING AND CLEANUP
#==============================================================================

#------------------------------------------------------------------------------
# Function: cleanup
# Description: Performs cleanup operations before script exit. Called
#              automatically via trap on EXIT signal.
# Arguments:
#   None
# Returns:
#   Preserves exit code from script execution
# Example:
#   trap cleanup EXIT
#------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    
    # Perform any necessary cleanup operations
    # Currently no cleanup needed, but structure is in place
    
    return "${exit_code}"
}

# Register cleanup function to run on EXIT signal
trap cleanup EXIT

#------------------------------------------------------------------------------
# Function: handle_interrupt
# Description: Handles user interruption (Ctrl+C) and termination signals
#              gracefully, ensuring proper cleanup and exit.
# Arguments:
#   None
# Returns:
#   Exits with code 130 (128 + SIGINT)
# Example:
#   trap handle_interrupt INT TERM
#------------------------------------------------------------------------------
handle_interrupt() {
    echo "" >&2
    log_error "Script interrupted by user"
    exit 130
}

# Register interrupt handler for SIGINT and SIGTERM
trap handle_interrupt INT TERM

#==============================================================================
# LOGGING FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: log_error
# Description: Outputs error messages to stderr with ERROR prefix and red color
# Arguments:
#   $@ - Error message to display
# Returns:
#   None
# Example:
#   log_error "Failed to clear secrets for project: ${project_name}"
#------------------------------------------------------------------------------
log_error() {
    echo -e "${COLOR_RED}ERROR: $*${COLOR_RESET}" >&2
}

#------------------------------------------------------------------------------
# Function: log_warning
# Description: Outputs warning messages with WARNING prefix and yellow color
# Arguments:
#   $@ - Warning message to display
# Returns:
#   None
# Example:
#   log_warning "Project path not found: ${path}"
#------------------------------------------------------------------------------
log_warning() {
    echo -e "${COLOR_YELLOW}WARNING: $*${COLOR_RESET}" >&2
}

#------------------------------------------------------------------------------
# Function: log_success
# Description: Outputs success messages with green color
# Arguments:
#   $@ - Success message to display
# Returns:
#   None
# Example:
#   log_success "✓ Successfully cleared secrets for: ${project_name}"
#------------------------------------------------------------------------------
log_success() {
    echo -e "${COLOR_GREEN}$*${COLOR_RESET}"
}

#------------------------------------------------------------------------------
# Function: log_info
# Description: Outputs informational messages with cyan color
# Arguments:
#   $@ - Information message to display
# Returns:
#   None
# Example:
#   log_info "Processing project: ${project_name}"
#------------------------------------------------------------------------------
log_info() {
    echo -e "${COLOR_CYAN}$*${COLOR_RESET}"
}

#------------------------------------------------------------------------------
# Function: log_verbose
# Description: Outputs verbose diagnostic messages when verbose mode is enabled
# Arguments:
#   $@ - Verbose message to display
# Returns:
#   None
# Example:
#   log_verbose "Executing: dotnet user-secrets clear -p ${project_path}"
#------------------------------------------------------------------------------
log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

###############################################################################
# Function: show_help
# Description: Displays usage information
###############################################################################
show_help() {
    cat << EOF
clean-secrets.sh - .NET User Secrets Clearing Tool

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS]

DESCRIPTION
    Clears all .NET user secrets from configured projects to ensure a clean
    state. Useful before re-provisioning or troubleshooting configuration issues.

OPTIONS
    -f, --force      Skip confirmation prompts
    -n, --dry-run    Show what would be executed without making changes
    -v, --verbose    Display detailed diagnostic information
    -h, --help       Display this help message

EXAMPLES
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} --force
    ${SCRIPT_NAME} --dry-run --verbose

TARGET PROJECTS
    • app.AppHost
    • eShop.Orders.API
    • eShop.Web.App

VERSION
    ${SCRIPT_VERSION}

EOF
}

###############################################################################
# Function: parse_arguments
# Description: Parses command-line arguments
###############################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                FORCE=true
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
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
}

###############################################################################
# Function: test_dotnet_availability
# Description: Checks if .NET SDK is available
# Returns:
#   0 - .NET SDK available
#   1 - .NET SDK not available
###############################################################################
test_dotnet_availability() {
    print_verbose "Checking .NET SDK availability..."
    
    if ! command -v dotnet &> /dev/null; then
        print_verbose ".NET command not found in PATH"
        return 1
    fi
    
    local dotnet_path
    dotnet_path=$(command -v dotnet)
    print_verbose "dotnet command found at: ${dotnet_path}"
    
    # Verify dotnet can execute
    if ! dotnet --version &> /dev/null; then
        print_verbose "dotnet command failed to execute"
        return 1
    fi
    
    print_verbose ".NET SDK is available and functional"
    return 0
}

###############################################################################
# Function: test_project_path
# Description: Validates that a project path exists
# Arguments:
#   $1 - Project name
#   $2 - Project path
# Returns:
#   0 - Path is valid
#   1 - Path is invalid
###############################################################################
test_project_path() {
    local project_name="$1"
    local project_path="$2"
    
    print_verbose "Validating project path for: ${project_name}"
    
    # Resolve absolute path
    local abs_path="${SCRIPT_DIR}/${project_path}"
    
    if [[ ! -d "${abs_path}" ]]; then
        print_warning "Project path not found: ${abs_path}"
        return 1
    fi
    
    # Check if directory contains a .csproj file
    if ! ls "${abs_path}"/*.csproj &> /dev/null; then
        print_warning "No .csproj file found in: ${abs_path}"
        return 1
    fi
    
    print_verbose "Project path validated: ${abs_path}"
    return 0
}

###############################################################################
# Function: clear_project_user_secrets
# Description: Clears user secrets for a specific project
# Arguments:
#   $1 - Project name
#   $2 - Project path
# Returns:
#   0 - Success
#   1 - Failure
###############################################################################
clear_project_user_secrets() {
    local project_name="$1"
    local project_path="$2"
    local abs_path="${SCRIPT_DIR}/${project_path}"
    
    print_verbose "Preparing to clear user secrets for: ${project_name}"
    
    if [[ "${DRY_RUN}" == true ]]; then
        print_info "  [DRY-RUN] Would clear user secrets for: ${project_name}"
        print_verbose "  [DRY-RUN] Command: dotnet user-secrets clear --project ${abs_path}"
        return 0
    fi
    
    print_info "Clearing user secrets for project: ${project_name}"
    
    # Execute dotnet user-secrets clear
    local output
    local exit_code
    
    if output=$(dotnet user-secrets clear --project "${abs_path}" 2>&1); then
        exit_code=$?
        if [[ ${exit_code} -eq 0 ]]; then
            print_success "✓ Successfully cleared user secrets for: ${project_name}"
            print_verbose "Output: ${output}"
            return 0
        fi
    fi
    
    exit_code=$?
    print_warning "Failed to clear user secrets for ${project_name}. Exit code: ${exit_code}"
    print_verbose "Error output: ${output}"
    return 1
}

###############################################################################
# Function: write_script_header
# Description: Displays the script header with version information
###############################################################################
write_script_header() {
    print_info ""
    print_info "================================================================="
    print_info "  Clean .NET User Secrets - Version ${SCRIPT_VERSION}"
    print_info "  Azure Logic Apps Monitoring Project"
    print_info "================================================================="
    print_info ""
}

###############################################################################
# Function: write_script_summary
# Description: Displays the execution summary
# Arguments:
#   $1 - Success count
#   $2 - Failure count
#   $3 - Total count
###############################################################################
write_script_summary() {
    local success_count=$1
    local failure_count=$2
    local total_count=$3
    
    print_info ""
    print_info "================================================================="
    print_info "  Execution Summary"
    print_info "================================================================="
    print_info "  Total projects:       ${total_count}"
    print_info "  Successfully cleared: ${success_count}"
    print_info "  Failed:               ${failure_count}"
    print_info "================================================================="
    print_info ""
}

###############################################################################
# Main Execution
###############################################################################
main() {
    local exit_code=0
    local success_count=0
    local failure_count=0
    local total_count=0
    
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Display script header
    write_script_header
    
    # Step 1: Validate .NET SDK availability
    print_info "Step 1: Validating .NET SDK availability..."
    if ! test_dotnet_availability; then
        print_error ".NET SDK is not installed or not accessible."
        print_error "Please install .NET SDK 10.0 or higher."
        print_error "Download from: https://dotnet.microsoft.com/download/dotnet/10.0"
        exit 1
    fi
    
    local dotnet_version
    dotnet_version=$(dotnet --version 2>&1 || echo "unknown")
    print_success "✓ .NET SDK is available (version: ${dotnet_version})"
    print_info ""
    
    # Step 2: Validate project paths
    print_info "Step 2: Validating project paths..."
    
    declare -a valid_projects=()
    declare -a valid_paths=()
    
    for project_name in "${!PROJECTS[@]}"; do
        local project_path="${PROJECTS[$project_name]}"
        if test_project_path "${project_name}" "${project_path}"; then
            valid_projects+=("${project_name}")
            valid_paths+=("${project_path}")
            print_info "  ✓ ${project_name}"
        else
            print_warning "  ✗ ${project_name} - Path not found or invalid"
        fi
    done
    
    total_count=${#valid_projects[@]}
    
    if [[ ${total_count} -eq 0 ]]; then
        print_error "No valid project paths found."
        print_error "Please ensure the script is run from the repository root."
        exit 1
    fi
    
    print_info ""
    print_info "Found ${total_count} valid project(s)"
    print_info ""
    
    # Step 3: Confirm action (unless --force or --dry-run is specified)
    if [[ "${FORCE}" == false ]] && [[ "${DRY_RUN}" == false ]]; then
        read -rp "Are you sure you want to clear user secrets for ${total_count} project(s)? (yes/no): " confirmation
        if [[ "${confirmation}" != "yes" ]]; then
            print_info "Operation cancelled by user."
            exit 0
        fi
    fi
    
    # Step 4: Clear user secrets
    print_info "Step 3: Clearing user secrets..."
    print_info ""
    
    for i in "${!valid_projects[@]}"; do
        local project_name="${valid_projects[$i]}"
        local project_path="${valid_paths[$i]}"
        
        if clear_project_user_secrets "${project_name}" "${project_path}"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
    done
    
    # Display summary
    write_script_summary "${success_count}" "${failure_count}" "${total_count}"
    
    # Exit with appropriate code
    if [[ ${failure_count} -gt 0 ]]; then
        print_warning "Script completed with errors."
        exit_code=1
    else
        if [[ "${DRY_RUN}" == true ]]; then
            print_success "Dry-run completed successfully."
        else
            print_success "Script completed successfully."
        fi
        exit_code=0
    fi
    
    exit ${exit_code}
}

# Trap errors for cleanup
trap 'print_error "Fatal error on line $LINENO: $BASH_COMMAND"; exit 1' ERR

# Execute main function
main "$@"
