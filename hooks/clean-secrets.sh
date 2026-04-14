#!/usr/bin/env bash
# shellcheck disable=SC2034

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
#     Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
#     Version        : 2.0.1
#     Last Modified  : 2026-01-06
#     Prerequisite   : .NET SDK 10.0 or higher
#     Purpose        : Clean .NET user secrets before deployment
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
readonly SCRIPT_VERSION="2.0.1"

# Minimum .NET SDK major version required (matches PowerShell script)
readonly MINIMUM_DOTNET_MAJOR_VERSION=10

# Script name for consistent logging and help text
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

#==============================================================================
# HELP AND USAGE
#==============================================================================

#------------------------------------------------------------------------------
# Function: show_help
# Description: Displays comprehensive usage information and examples.
#              Matches PowerShell Get-Help output format.
# Arguments:
#   None
# Returns:
#   Exits with code 0
# Example:
#   show_help
#------------------------------------------------------------------------------
show_help() {
    cat << EOF
clean-secrets.sh - .NET User Secrets Clearing Tool

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS]

DESCRIPTION
    Clears all .NET user secrets from configured projects to ensure a clean
    state. This is useful before re-provisioning or when troubleshooting
    configuration issues.
    
    The script performs the following operations:
    - Validates .NET SDK availability
    - Validates project paths and .csproj file existence
    - Clears user secrets for app.AppHost project
    - Clears user secrets for eShop.Orders.API project
    - Clears user secrets for eShop.Web.App project
    - Provides detailed logging and execution summary

OPTIONS
    -f, --force      Skip confirmation prompts and force execution
    -n, --dry-run    Show what would be executed without making changes
    -v, --verbose    Display detailed diagnostic information
    -h, --help       Display this help message and exit

EXAMPLES
    ${SCRIPT_NAME}
        Clears all user secrets with confirmation prompt.
    
    ${SCRIPT_NAME} --force
        Clears all user secrets without confirmation.
    
    ${SCRIPT_NAME} --dry-run --verbose
        Shows what would be cleared without making changes, with verbose output.

TARGET PROJECTS
    • app.AppHost
    • eShop.Orders.API
    • eShop.Web.App

EXIT CODES
    0    Success - All operations completed successfully
    1    Error - Fatal error occurred or some operations failed

VERSION
    ${SCRIPT_VERSION}

AUTHOR
    Azure-LogicApps-Monitoring Team

COPYRIGHT
    (c) 2025-2026. All rights reserved.

SEE ALSO
    clean-secrets.ps1 - PowerShell version of this script
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring

EOF
    exit 0
}

#==============================================================================
# ARGUMENT PARSING
#==============================================================================

#------------------------------------------------------------------------------
# Function: parse_arguments
# Description: Parses command-line arguments and sets global flags.
#              Validates arguments and provides error messages for unknown
#              options.
# Arguments:
#   $@ - All command-line arguments
# Returns:
#   0 - Arguments parsed successfully
#   1 - Invalid argument encountered
# Example:
#   parse_arguments "$@"
#------------------------------------------------------------------------------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                FORCE=true
                log_verbose "Force mode enabled - confirmation prompts will be skipped"
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                log_verbose "Dry-run mode enabled - no changes will be made"
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                log_verbose "Verbose mode enabled"
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
    
    return 0
}

#==============================================================================
# VALIDATION FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: test_dotnet_availability
# Description: Checks if .NET SDK is available and executable.
#              Validates that dotnet command exists in PATH and can run.
# Arguments:
#   None
# Returns:
#   0 - .NET SDK is available and functional
#   1 - .NET SDK is not available or not functional
# Example:
#   test_dotnet_availability || exit 1
#------------------------------------------------------------------------------
test_dotnet_availability() {
    log_verbose "Starting .NET SDK availability check..."
    
    # Check if dotnet command exists in PATH
    if ! command -v dotnet &> /dev/null; then
        log_verbose ".NET command not found in PATH"
        return 1
    fi
    
    local dotnet_path
    dotnet_path=$(command -v dotnet)
    log_verbose "dotnet command found at: ${dotnet_path}"
    
    # Verify dotnet can execute and return version
    local dotnet_version
    if ! dotnet_version=$(dotnet --version 2>&1); then
        log_verbose "dotnet command failed to execute"
        return 1
    fi
    
    # Validate version meets minimum requirement (matches PowerShell logic)
    local major_version
    major_version=$(echo "${dotnet_version}" | cut -d'.' -f1)
    
    if ! [[ "${major_version}" =~ ^[0-9]+$ ]]; then
        log_verbose "Unable to parse dotnet major version from: ${dotnet_version}"
        return 1
    fi
    
    if [[ ${major_version} -lt ${MINIMUM_DOTNET_MAJOR_VERSION} ]]; then
        log_verbose "dotnet SDK major version ${major_version} is less than required ${MINIMUM_DOTNET_MAJOR_VERSION}"
        return 1
    fi
    
    log_verbose ".NET SDK is available and functional (version: ${dotnet_version})"
    return 0
}

#------------------------------------------------------------------------------
# Function: test_project_path
# Description: Validates that a project path exists and contains a valid
#              .NET project file (.csproj). Mimics PowerShell's Test-ProjectPath.
# Arguments:
#   $1 - Project name for logging purposes
#   $2 - Project path relative to script directory
# Returns:
#   0 - Path is valid and contains .csproj file
#   1 - Path is invalid or missing .csproj file
# Example:
#   test_project_path "app.AppHost" "../app.AppHost/"
#------------------------------------------------------------------------------
test_project_path() {
    local project_name="$1"
    local project_path="$2"
    
    log_verbose "Validating project path for: ${project_name}"
    
    # Resolve absolute path
    local abs_path="${SCRIPT_DIR}/${project_path}"
    log_verbose "Resolved absolute path: ${abs_path}"
    
    # Check if directory exists
    if [[ ! -d "${abs_path}" ]]; then
        log_verbose "Project directory not found: ${abs_path}"
        return 1
    fi
    
    # Check if directory contains at least one .csproj file
    local csproj_count=0
    while IFS= read -r -d '' file; do
        ((csproj_count++))
    done < <(find "${abs_path}" -maxdepth 1 -name "*.csproj" -print0 2>/dev/null)
    
    if [[ ${csproj_count} -eq 0 ]]; then
        log_verbose "No .csproj file found in: ${abs_path}"
        return 1
    fi
    
    log_verbose "Project path validated successfully (found ${csproj_count} .csproj file(s))"
    return 0
}

#==============================================================================
# OPERATIONS FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: clear_project_user_secrets
# Description: Clears user secrets for a specific project using 'dotnet
#              user-secrets clear' command. Handles dry-run mode and provides
#              detailed logging. Mimics PowerShell's Clear-ProjectUserSecrets.
# Arguments:
#   $1 - Project name for logging purposes
#   $2 - Project path relative to script directory
# Returns:
#   0 - Secrets cleared successfully (or dry-run completed)
#   1 - Failed to clear secrets
# Example:
#   clear_project_user_secrets "app.AppHost" "../app.AppHost/"
#------------------------------------------------------------------------------
clear_project_user_secrets() {
    local project_name="$1"
    local project_path="$2"
    local abs_path="${SCRIPT_DIR}/${project_path}"
    
    log_verbose "Preparing to clear user secrets for: ${project_name}"
    log_verbose "Project path: ${abs_path}"
    
    # Handle dry-run mode (equivalent to PowerShell's -WhatIf)
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "  [DRY-RUN] Would clear user secrets for: ${project_name}"
        log_verbose "  [DRY-RUN] Command: dotnet user-secrets clear --project ${abs_path}"
        return 0
    fi
    
    log_info "Clearing user secrets for project: ${project_name}"
    
    # Execute dotnet user-secrets clear command
    local output
    local exit_code=0
    
    # Capture both stdout and stderr, preserving exit code
    if output=$(dotnet user-secrets clear --project "${abs_path}" 2>&1); then
        exit_code=0
        log_success "✓ Successfully cleared user secrets for: ${project_name}"
        log_verbose "Command output: ${output}"
        return 0
    else
        exit_code=$?
        log_warning "Failed to clear user secrets for ${project_name}. Exit code: ${exit_code}"
        log_verbose "Error output: ${output}"
        return 1
    fi
}

#==============================================================================
# DISPLAY FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: write_script_header
# Description: Displays the script header with version information and title.
#              Mimics PowerShell's informational output format.
# Arguments:
#   None
# Returns:
#   None
# Example:
#   write_script_header
#------------------------------------------------------------------------------
write_script_header() {
    log_info ""
    log_info "================================================================="
    log_info "  Clean .NET User Secrets - Version ${SCRIPT_VERSION}"
    log_info "  Azure Logic Apps Monitoring Project"
    log_info "================================================================="
    log_info ""
}

#------------------------------------------------------------------------------
# Function: write_script_summary
# Description: Displays the execution summary with statistics showing total
#              projects processed, successfully cleared, and failed operations.
#              Mimics PowerShell's Write-ScriptSummary output.
# Arguments:
#   $1 - Success count
#   $2 - Failure count
#   $3 - Total count
# Returns:
#   None
# Example:
#   write_script_summary 3 0 3
#------------------------------------------------------------------------------
write_script_summary() {
    local success_count=$1
    local failure_count=$2
    local total_count=$3
    
    log_info ""
    log_info "================================================================="
    log_info "  Execution Summary"
    log_info "================================================================="
    log_info "  Total projects:       ${total_count}"
    log_info "  Successfully cleared: ${success_count}"
    log_info "  Failed:               ${failure_count}"
    log_info "================================================================="
    log_info ""
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

#------------------------------------------------------------------------------
# Function: main
# Description: Main execution function that orchestrates the secret clearing
#              workflow. Implements try-catch-finally pattern using trap and
#              conditional execution. Matches PowerShell script flow.
# Arguments:
#   $@ - All command-line arguments
# Returns:
#   0 - All operations completed successfully
#   1 - Fatal error occurred or some operations failed
# Exit Codes:
#   0 - Success (all secrets cleared or dry-run completed)
#   1 - Error (validation failed or some clear operations failed)
# Notes:
#   Uses trap for error handling to mimic PowerShell's try-catch-finally
#------------------------------------------------------------------------------
main() {
    local exit_code=0
    local success_count=0
    local failure_count=0
    local total_count=0
    
    # Parse command-line arguments
    log_verbose "Parsing command-line arguments..."
    parse_arguments "$@"
    
    # Try block equivalent - main execution logic
    {
        # Display script header
        write_script_header
        
        # Step 1: Validate .NET SDK availability
        log_info "Step 1: Validating .NET SDK availability..."
        if ! test_dotnet_availability; then
            log_error ".NET SDK is not installed, not accessible, or does not meet requirements."
            log_error "Required: .NET SDK ${MINIMUM_DOTNET_MAJOR_VERSION}.0 or higher."
            log_error "Download from: https://dotnet.microsoft.com/download/dotnet/${MINIMUM_DOTNET_MAJOR_VERSION}.0"
            exit 1
        fi
        
        # Display .NET SDK version information
        local dotnet_version
        dotnet_version=$(dotnet --version 2>&1 || echo "unknown")
        log_success "✓ .NET SDK is available (version: ${dotnet_version})"
        log_info ""
        
        # Step 2: Validate project paths
        log_info "Step 2: Validating project paths..."
        
        # Arrays to store valid projects (mimics PowerShell's List[hashtable])
        declare -a valid_projects=()
        declare -a valid_paths=()
        
        # Iterate through all configured projects and validate
        for project_name in "${!PROJECTS[@]}"; do
            local project_path="${PROJECTS[$project_name]}"
            log_verbose "Checking project: ${project_name} at ${project_path}"
            
            if test_project_path "${project_name}" "${project_path}"; then
                valid_projects+=("${project_name}")
                valid_paths+=("${project_path}")
                log_info "  ✓ ${project_name}"
            else
                log_warning "  ✗ ${project_name} - Path not found or invalid"
            fi
        done
        
        # Check if we found any valid projects
        total_count=${#valid_projects[@]}
        
        if [[ ${total_count} -eq 0 ]]; then
            log_error "No valid project paths found."
            log_error "Please ensure the script is run from the correct directory."
            log_error "Expected script location: <repo-root>/hooks/"
            exit 1
        fi
        
        log_info ""
        log_info "Found ${total_count} valid project(s)"
        log_info ""
        
        # Step 3: Confirm action (unless --force or --dry-run is specified)
        # Mimics PowerShell's -Force parameter and ShouldProcess/WhatIf
        if [[ "${FORCE}" == false ]] && [[ "${DRY_RUN}" == false ]]; then
            log_verbose "Prompting user for confirmation..."
            read -rp "Are you sure you want to clear user secrets for ${total_count} project(s)? (yes/no): " confirmation
            
            if [[ "${confirmation}" != "yes" ]]; then
                log_info "Operation cancelled by user."
                exit 0
            fi
            
            log_verbose "User confirmed operation"
        else
            if [[ "${FORCE}" == true ]]; then
                log_verbose "Force mode enabled - skipping confirmation"
            fi
            if [[ "${DRY_RUN}" == true ]]; then
                log_verbose "Dry-run mode enabled - no confirmation needed"
            fi
        fi
        
        # Step 4: Clear user secrets for each valid project
        log_info "Step 4: Clearing user secrets..."
        log_info ""
        
        # Process each valid project
        for i in "${!valid_projects[@]}"; do
            local project_name="${valid_projects[$i]}"
            local project_path="${valid_paths[$i]}"
            
            log_verbose "Processing project ${i+1}/${total_count}: ${project_name}"
            
            # Execute clear operation and track results
            if clear_project_user_secrets "${project_name}" "${project_path}"; then
                ((success_count++))
                log_verbose "Success count: ${success_count}"
            else
                ((failure_count++))
                log_verbose "Failure count: ${failure_count}"
            fi
        done
        
        # Display execution summary
        write_script_summary "${success_count}" "${failure_count}" "${total_count}"
        
        # Determine final exit code based on results
        if [[ ${failure_count} -gt 0 ]]; then
            log_warning "Script completed with errors."
            log_warning "Please review the error messages above and retry failed operations."
            exit_code=1
        else
            if [[ "${DRY_RUN}" == true ]]; then
                log_success "Dry-run completed successfully."
                log_verbose "No changes were made - this was a simulation"
            else
                log_success "Script completed successfully."
                log_verbose "All user secrets have been cleared"
            fi
            exit_code=0
        fi
        
    } || {
        # Catch block equivalent - handle unexpected errors
        local error_code=$?
        log_error "Fatal error occurred during execution"
        log_verbose "Error code: ${error_code}"
        log_verbose "Script exiting with error status"
        exit_code=1
    }
    
    # Finally block equivalent - cleanup and exit
    log_verbose "Main function completed with exit code: ${exit_code}"
    exit ${exit_code}
}

#==============================================================================
# SCRIPT ENTRY POINT
#==============================================================================

# Execute main function with all command-line arguments
# Error trap is already registered at the top of the script
log_verbose "Script started: ${SCRIPT_NAME} version ${SCRIPT_VERSION}"
main "$@"
