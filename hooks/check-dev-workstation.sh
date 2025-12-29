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
#     >1   Validation failed - see preprovision.sh exit codes
#
# NOTES
#     File Name      : check-dev-workstation.sh
#     Author         : Azure-LogicApps-Monitoring Team
#     Version        : 1.0.0
#     Last Modified  : 2025-12-29
#     Prerequisite   : Bash 4.0+, preprovision.sh
#     Purpose        : Development environment validation wrapper
#     Copyright      : (c) 2025. All rights reserved.
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
# SCRIPT METADATA AND CONSTANTS
#==============================================================================

# Script version following semantic versioning (MAJOR.MINOR.PATCH)
readonly SCRIPT_VERSION="1.0.0"

# Script name for consistent logging and error messages
readonly SCRIPT_NAME="check-dev-workstation.sh"

# Resolve script directory for reliable path operations
# Using BASH_SOURCE[0] instead of $0 for sourcing compatibility
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# GLOBAL VARIABLES
#==============================================================================

# Verbose mode flag - controls diagnostic output verbosity
VERBOSE=false

# Error action preference - mimics PowerShell behavior
# "Continue" allows script to complete even with warnings from preprovision
readonly ERROR_ACTION_PREFERENCE="Continue"

#==============================================================================
# ERROR HANDLING AND CLEANUP
#==============================================================================

# Trap function for graceful exit and cleanup
# Executes on script exit (normal or error)
# Parameters:
#   $?: Exit code from the last command
cleanup() {
    local exit_code=$?
    
    # Perform any necessary cleanup here
    # Currently no cleanup needed, but structure is in place for future use
    
    # Preserve the original exit code
    return "${exit_code}"
}

# Register cleanup function to run on EXIT signal
trap cleanup EXIT

# Trap function for interruption signals (SIGINT, SIGTERM)
# Provides clean shutdown when user presses Ctrl+C or process is terminated
handle_interrupt() {
    echo "" >&2
    echo "ERROR: Script interrupted by user" >&2
    exit 130  # Standard exit code for SIGINT (128 + 2)
}

# Register interrupt handler
trap handle_interrupt INT TERM

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: log_verbose
# Description: Outputs verbose logging messages to stderr when verbose mode
#              is enabled. Uses stderr to avoid polluting stdout with
#              diagnostic information.
# Arguments:
#   $@ - Message to log
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
#              consistent error reporting across the script.
# Arguments:
#   $@ - Error message to log
# Returns:
#   None
# Example:
#   log_error "Required script not found: ${script_path}"
#------------------------------------------------------------------------------
log_error() {
    echo "ERROR: $*" >&2
}

#------------------------------------------------------------------------------
# Function: show_help
# Description: Displays comprehensive help information including usage,
#              options, examples, and exit codes. Follows standard Unix
#              conventions for help output.
# Arguments:
#   None
# Returns:
#   None (exits with code 0)
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
    (c) 2025. All rights reserved.

SEE ALSO
    preprovision.sh - The underlying validation script
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring

EOF
    exit 0
}

#------------------------------------------------------------------------------
# Function: validate_preprovision_script
# Description: Validates that the required preprovision.sh script exists and
#              is executable. Attempts to set execute permissions if needed.
# Arguments:
#   None
# Returns:
#   0 - Script exists and is executable
#   1 - Script not found or cannot be made executable
# Example:
#   validate_preprovision_script || exit 1
#------------------------------------------------------------------------------
validate_preprovision_script() {
    local preprovision_path="${SCRIPT_DIR}/preprovision.sh"
    
    log_verbose "Validating preprovision.sh script..."
    log_verbose "Expected path: ${preprovision_path}"
    
    # Check if script file exists
    if [[ ! -f "${preprovision_path}" ]]; then
        log_error "Required script not found: ${preprovision_path}"
        log_error "This script requires preprovision.sh to be in the same directory."
        log_error "Current directory: ${SCRIPT_DIR}"
        return 1
    fi
    
    log_verbose "Script file found: ${preprovision_path}"
    
    # Check if script is executable
    if [[ ! -x "${preprovision_path}" ]]; then
        log_verbose "Script is not executable, attempting to set execute permission..."
        
        # Attempt to make script executable
        if chmod +x "${preprovision_path}" 2>/dev/null; then
            log_verbose "Execute permission set successfully"
        else
            log_error "Failed to set execute permission on: ${preprovision_path}"
            log_error "Please run: chmod +x ${preprovision_path}"
            return 1
        fi
    else
        log_verbose "Script is executable"
    fi
    
    # Export the validated path for use in main execution
    echo "${preprovision_path}"
    return 0
}

#------------------------------------------------------------------------------
# Function: parse_arguments
# Description: Parses command-line arguments and sets global configuration
#              variables. Validates argument format and provides error
#              messages for unknown options.
# Arguments:
#   $@ - All command-line arguments
# Returns:
#   0 - Arguments parsed successfully
#   1 - Invalid argument encountered
# Example:
#   parse_arguments "$@" || exit 1
#------------------------------------------------------------------------------
parse_arguments() {
    # Process all command-line arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose)
                # Enable verbose logging
                VERBOSE=true
                log_verbose "Verbose mode enabled"
                shift
                ;;
            -h|--help)
                # Display help and exit
                show_help
                # show_help exits, but return here for clarity
                return 0
                ;;
            *)
                # Unknown option encountered
                log_error "Unknown option: $1"
                echo "Use --help for usage information." >&2
                return 1
                ;;
        esac
    done
    
    return 0
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

#------------------------------------------------------------------------------
# Function: main
# Description: Main execution function that orchestrates the validation
#              workflow. Handles argument parsing, script validation, and
#              execution of preprovision.sh in validation-only mode.
# Arguments:
#   $@ - All command-line arguments
# Returns:
#   0 - Validation successful
#   1 - Validation failed or error occurred
# Example:
#   main "$@"
#------------------------------------------------------------------------------
main() {
    log_verbose "Starting developer workstation validation..."
    log_verbose "Script: ${SCRIPT_NAME}"
    log_verbose "Version: ${SCRIPT_VERSION}"
    log_verbose "Script directory: ${SCRIPT_DIR}"
    
    # Parse and validate command-line arguments
    log_verbose "Parsing command-line arguments..."
    if ! parse_arguments "$@"; then
        return 1
    fi
    
    # Validate and locate preprovision.sh script
    log_verbose "Validating preprovision.sh script..."
    local preprovision_path
    if ! preprovision_path=$(validate_preprovision_script); then
        return 1
    fi
    
    log_verbose "Using validation script: ${preprovision_path}"
    
    # Build argument array for preprovision.sh
    # --validate-only: Skips secret clearing, only performs validation
    # --verbose: Forwards verbose mode to preprovision (if enabled)
    local validation_args=("--validate-only")
    
    if [[ "${VERBOSE}" == "true" ]]; then
        validation_args+=("--verbose")
        log_verbose "Forwarding verbose flag to preprovision.sh"
    fi
    
    log_verbose "Executing preprovision.sh with arguments: ${validation_args[*]}"
    
    # Execute preprovision.sh and capture exit code
    # Run in subshell to capture all output (stdout and stderr)
    # Store exit code immediately to prevent it from being overwritten
    local validation_output
    local validation_exit_code=0
    
    # Execute and capture output, preserving exit code
    if validation_output=$("${preprovision_path}" "${validation_args[@]}" 2>&1); then
        validation_exit_code=0
    else
        validation_exit_code=$?
    fi
    
    log_verbose "preprovision.sh exit code: ${validation_exit_code}"
    
    # Display captured output to user
    # This ensures clean output separation from verbose logging
    if [[ -n "${validation_output}" ]]; then
        echo "${validation_output}"
    fi
    
    # Evaluate validation results and provide summary
    if [[ ${validation_exit_code} -eq 0 ]]; then
        log_verbose "✓ Workstation validation completed successfully"
        log_verbose "Your development environment is properly configured for Azure deployment"
        return 0
    else
        log_verbose "⚠ Workstation validation completed with issues"
        log_verbose "Please address the warnings/errors above before proceeding with development"
        log_verbose "For detailed diagnostics, run with --verbose flag"
        return "${validation_exit_code}"
    fi
}

#==============================================================================
# SCRIPT ENTRY POINT
#==============================================================================

# Execute main function with all command-line arguments
# Exit with the return code from main
main "$@"
exit $?
