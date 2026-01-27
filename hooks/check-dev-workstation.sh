#!/usr/bin/env bash

################################################################################
# check-dev-workstation.sh
#
# SYNOPSIS
#     Validates developer workstation prerequisites for Azure Logic Apps 
#     Monitoring solution.
#
# DESCRIPTION
#     This script performs comprehensive validation of the development environment
#     to ensure all required tools, software dependencies, and Azure configurations
#     are properly set up before beginning development work on the Azure Logic Apps
#     Monitoring solution.
#     
#     The script acts as a wrapper around preprovision.sh in ValidateOnly mode,
#     providing a developer-friendly way to check workstation readiness without
#     performing any modifications to the environment.
#     
#     Validations performed include:
#     - Bash version (4.0+)
#     - .NET SDK version (10.0+)
#     - Azure Developer CLI (azd)
#     - Azure CLI (2.60.0+) with active authentication
#     - Bicep CLI (0.30.0+)
#     - Azure Resource Provider registrations
#     - Azure subscription quota requirements
#
# USAGE
#     ./check-dev-workstation.sh [OPTIONS]
#
# OPTIONS
#     -v, --verbose    Display detailed diagnostic information during validation
#     -h, --help       Display this help message and exit
#
# EXAMPLES
#     ./check-dev-workstation.sh
#         Performs standard workstation validation with normal output.
#
#     ./check-dev-workstation.sh --verbose
#         Performs validation with detailed diagnostic output for troubleshooting.
#
# EXIT CODES
#     0    Validation successful - all prerequisites met
#     1    General error - missing script or invalid arguments
#     130  Script interrupted by user (SIGINT)
#     >1   Validation failed - see preprovision.sh exit codes
#
# OUTPUTS
#     Formatted output string containing validation results to stdout.
#     Verbose diagnostic messages to stderr when --verbose flag is used.
#
# DEPENDENCIES
#     preprovision.sh - Must exist in the same directory as this script
#
# NOTES
#     File Name      : check-dev-workstation.sh
#     Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
#     Version        : 1.0.0
#     Last Modified  : 2026-01-07
#     Prerequisite   : Bash 4.0+, preprovision.sh
#     Purpose        : Development environment validation wrapper
#
# LINKS
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#     preprovision.sh - The underlying validation script
#
# COMPONENT
#     Azure Logic Apps Monitoring - Development Tools
#
# ROLE
#     Development Environment Validation
#
# FUNCTIONALITY
#     Validates development workstation prerequisites for Azure deployment
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
# SCRIPT METADATA AND CONFIGURATION
#==============================================================================

# Script version following semantic versioning (MAJOR.MINOR.PATCH)
readonly SCRIPT_VERSION="1.0.0"

# Resolve script directory for reliable path operations
# Using BASH_SOURCE[0] instead of $0 for sourcing compatibility
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# GLOBAL VARIABLES
#==============================================================================

# Verbose mode flag - controls diagnostic output verbosity
VERBOSE=false

#==============================================================================
# ERROR HANDLING AND CLEANUP
#==============================================================================

#------------------------------------------------------------------------------
# Function: cleanup
# Description: Cleanup function executed on script exit (normal or error).
#              Ensures proper resource cleanup and preserves exit codes.
# Arguments:
#   None (implicitly uses $? for exit code)
# Returns:
#   Preserved exit code from last command
# Notes:
#   Registered via trap to execute on EXIT signal
#------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    
    # Restore error action preference (currently no-op, structure for future use)
    # No additional cleanup needed for this wrapper script
    
    return "${exit_code}"
}

# Register cleanup function to run on EXIT signal
trap cleanup EXIT

#------------------------------------------------------------------------------
# Function: handle_interrupt
# Description: Handles interruption signals (SIGINT, SIGTERM) gracefully.
#              Provides clean shutdown when user presses Ctrl+C or process
#              is terminated.
# Arguments:
#   None
# Returns:
#   Exits with standard SIGINT exit code (130)
# Notes:
#   Registered via trap for INT and TERM signals
#------------------------------------------------------------------------------
handle_interrupt() {
    echo "" >&2
    echo "ERROR: Script interrupted by user" >&2
    exit 130  # Standard exit code for SIGINT (128 + 2)
}

# Register interrupt handler for INT and TERM signals
trap handle_interrupt INT TERM

#==============================================================================
# LOGGING FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: log_verbose
# Description: Outputs verbose diagnostic messages to stderr when verbose mode
#              is enabled. Uses stderr to avoid polluting stdout with
#              diagnostic information.
# Arguments:
#   $@ - Message components to log
# Returns:
#   None
# Example:
#   log_verbose "Starting validation process..."
#------------------------------------------------------------------------------
log_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

#------------------------------------------------------------------------------
# Function: log_error
# Description: Outputs error messages to stderr with ERROR prefix for
#              consistent error reporting.
# Arguments:
#   $@ - Error message components
# Returns:
#   None
# Example:
#   log_error "Required script not found: ${script_path}"
#------------------------------------------------------------------------------
log_error() {
    echo "ERROR: $*" >&2
}

#------------------------------------------------------------------------------
# Function: log_warning
# Description: Outputs warning messages to stderr with WARNING prefix.
# Arguments:
#   $@ - Warning message components
# Returns:
#   None
# Example:
#   log_warning "Validation completed with issues"
#------------------------------------------------------------------------------
log_warning() {
    echo "WARNING: $*" >&2
}

#==============================================================================
# HELP AND USAGE
#==============================================================================

#------------------------------------------------------------------------------
# Function: show_help
# Description: Displays comprehensive help information including synopsis,
#              description, usage, options, examples, and exit codes.
#              Follows standard Unix conventions for help output.
# Arguments:
#   None
# Returns:
#   Exits with code 0
# Example:
#   show_help
#------------------------------------------------------------------------------
show_help() {
    cat << 'EOF'
check-dev-workstation.sh - Developer Workstation Validation Tool

SYNOPSIS
    check-dev-workstation.sh [OPTIONS]

DESCRIPTION
    Validates developer workstation prerequisites for Azure Logic Apps
    Monitoring solution. This script acts as a wrapper around preprovision.sh
    in validation-only mode, checking all required tools and configurations
    without making any system modifications.

OPTIONS
    -v, --verbose    Display detailed diagnostic information during validation
    -h, --help       Display this help message and exit

EXAMPLES
    check-dev-workstation.sh
        Performs standard workstation validation with normal output.

    check-dev-workstation.sh --verbose
        Performs validation with detailed diagnostic output for troubleshooting.

EXIT CODES
    0    Validation successful - all prerequisites met
    1    General error - missing script or invalid arguments
    >1   Validation failed - see preprovision.sh for specific error codes

VALIDATIONS PERFORMED
    • Bash version (4.0+)
    • .NET SDK version (10.0+)
    • Azure Developer CLI (azd)
    • Azure CLI (2.60.0+) with active authentication
    • Bicep CLI (0.30.0+)
    • Azure Resource Provider registrations
    • Azure subscription quota requirements

VERSION
    1.0.0

AUTHOR
    Azure-LogicApps-Monitoring Team

COPYRIGHT
    (c) 2025-2026. All rights reserved.

SEE ALSO
    preprovision.sh - The underlying validation script
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring

EOF
    exit 0
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

#------------------------------------------------------------------------------
# Function: main
# Description: Main execution function that orchestrates the validation
#              workflow. Validates prerequisites, executes preprovision.sh
#              in ValidateOnly mode, captures output, and reports results.
# Arguments:
#   $@ - All command-line arguments
# Returns:
#   0 - Validation successful
#   1 - Validation failed or error occurred
# Exit Codes:
#   Propagates exit code from preprovision.sh on validation failure
# Notes:
#   Uses try-catch-finally pattern via conditional execution and trap
#------------------------------------------------------------------------------
main() {
    # Parse command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
    
    # Validate preprovision.sh exists in the same directory
    local preprovision_path="${SCRIPT_DIR}/preprovision.sh"
    
    if [[ ! -f "${preprovision_path}" ]]; then
        log_error "Required script not found: ${preprovision_path}"
        log_error "This script requires preprovision.sh to be in the same directory."
        exit 1
    fi
    
    log_verbose "Starting developer workstation validation..."
    log_verbose "Using validation script: ${preprovision_path}"
    log_verbose "Script version: ${SCRIPT_VERSION}"
    
    # Execute preprovision.sh in ValidateOnly mode
    # This performs all prerequisite checks without making any changes
    # Parameters:
    #   --validate-only: Skips secret clearing, only performs validation
    #   --verbose: Forwards verbose flag if enabled (conditional)
    #   2>&1: Redirects error stream to output stream for complete capture
    
    local validation_args=("--validate-only")
    if [[ "${VERBOSE}" == "true" ]]; then
        validation_args+=("--verbose")
    fi
    
    # Capture validation output and exit code
    local validation_output
    local validation_exit_code=0
    
    # Execute preprovision.sh and capture all output (stdout + stderr)
    # Preserve exit code for later evaluation
    if validation_output=$("${preprovision_path}" "${validation_args[@]}" 2>&1); then
        validation_exit_code=0
    else
        validation_exit_code=$?
    fi
    
    # Display validation results to stdout
    echo "${validation_output}"
    
    # Check if validation was successful by examining the exit code
    if [[ ${validation_exit_code} -eq 0 ]]; then
        log_verbose "✓ Workstation validation completed successfully"
        log_verbose "Your development environment is properly configured for Azure deployment"
        exit 0
    else
        log_warning "⚠ Workstation validation completed with issues"
        log_warning "Please address the warnings/errors above before proceeding with development"
        exit "${validation_exit_code}"
    fi
}

#==============================================================================
# SCRIPT ENTRY POINT
#==============================================================================

# Execute main function with all command-line arguments
# The cleanup trap will ensure proper exit code handling
main "$@"
