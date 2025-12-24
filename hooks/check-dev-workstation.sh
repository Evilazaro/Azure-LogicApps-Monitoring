#!/usr/bin/env bash

###############################################################################
# check-dev-workstation.sh
#
# SYNOPSIS
#     Validates developer workstation prerequisites for Azure Logic Apps
#     Monitoring solution.
#
# DESCRIPTION
#     This script performs comprehensive validation of the development
#     environment to ensure all required tools, software dependencies, and
#     Azure configurations are properly set up before beginning development
#     work on the Azure Logic Apps Monitoring solution.
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
#     -h, --help       Display this help message
#
# EXAMPLES
#     ./check-dev-workstation.sh
#     ./check-dev-workstation.sh --verbose
#
# NOTES
#     File Name      : check-dev-workstation.sh
#     Author         : Azure-LogicApps-Monitoring Team
#     Version        : 1.0.0
#     Last Modified  : 2025-12-24
#     Prerequisite   : Bash 4.0+, preprovision.sh
#     Purpose        : Development environment validation wrapper
#     Copyright      : (c) 2025. All rights reserved.
#
# LINKS
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#     preprovision.sh - The underlying validation script
#
###############################################################################

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="check-dev-workstation.sh"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script configuration
VERBOSE=false

###############################################################################
# Function: print_error
# Description: Prints error message to stderr in red
# Arguments:
#   $@ - Error message
###############################################################################
print_error() {
    echo -e "\033[0;31mERROR: $*\033[0m" >&2
}

###############################################################################
# Function: print_warning
# Description: Prints warning message in yellow
# Arguments:
#   $@ - Warning message
###############################################################################
print_warning() {
    echo -e "\033[0;33mWARNING: $*\033[0m"
}

###############################################################################
# Function: print_success
# Description: Prints success message in green
# Arguments:
#   $@ - Success message
###############################################################################
print_success() {
    echo -e "\033[0;32m$*\033[0m"
}

###############################################################################
# Function: print_info
# Description: Prints informational message
# Arguments:
#   $@ - Info message
###############################################################################
print_info() {
    echo "$*"
}

###############################################################################
# Function: print_verbose
# Description: Prints verbose message if verbose mode is enabled
# Arguments:
#   $@ - Verbose message
###############################################################################
print_verbose() {
    if [[ "${VERBOSE}" == true ]]; then
        echo -e "\033[0;36m[VERBOSE] $*\033[0m"
    fi
}

###############################################################################
# Function: show_help
# Description: Displays usage information
###############################################################################
show_help() {
    cat << EOF
check-dev-workstation.sh - Developer Workstation Validation Tool

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS]

DESCRIPTION
    Validates developer workstation prerequisites for Azure Logic Apps
    Monitoring solution.

OPTIONS
    -v, --verbose    Display detailed diagnostic information
    -h, --help       Display this help message

EXAMPLES
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} --verbose

VERSION
    ${SCRIPT_VERSION}

EOF
}

###############################################################################
# Function: parse_arguments
# Description: Parses command-line arguments
# Arguments:
#   $@ - All command-line arguments
###############################################################################
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
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
# Function: validate_preprovision_script
# Description: Validates that preprovision.sh exists
# Returns:
#   0 - Script exists
#   1 - Script not found
###############################################################################
validate_preprovision_script() {
    local preprovision_path="${SCRIPT_DIR}/preprovision.sh"
    
    print_verbose "Checking for preprovision.sh at: ${preprovision_path}"
    
    if [[ ! -f "${preprovision_path}" ]]; then
        print_error "Required script not found: ${preprovision_path}"
        print_error "This script requires preprovision.sh to be in the same directory."
        return 1
    fi
    
    if [[ ! -x "${preprovision_path}" ]]; then
        print_warning "preprovision.sh is not executable, setting executable bit..."
        chmod +x "${preprovision_path}" || {
            print_error "Failed to make preprovision.sh executable"
            return 1
        }
    fi
    
    print_verbose "preprovision.sh found and is executable"
    return 0
}

###############################################################################
# Function: run_validation
# Description: Executes preprovision.sh in ValidateOnly mode
# Returns:
#   Exit code from preprovision.sh
###############################################################################
run_validation() {
    local preprovision_path="${SCRIPT_DIR}/preprovision.sh"
    local args=("--validate-only")
    
    if [[ "${VERBOSE}" == true ]]; then
        args+=("--verbose")
    fi
    
    print_verbose "Starting developer workstation validation..."
    print_verbose "Using validation script: ${preprovision_path}"
    print_verbose "Script version: ${SCRIPT_VERSION}"
    
    # Execute preprovision.sh in ValidateOnly mode
    # This performs all prerequisite checks without making any changes
    "${preprovision_path}" "${args[@]}"
    return $?
}

###############################################################################
# Main Execution
###############################################################################
main() {
    local exit_code=0
    
    # Parse command-line arguments
    parse_arguments "$@"
    
    print_verbose "Bash version: ${BASH_VERSION}"
    print_verbose "Script directory: ${SCRIPT_DIR}"
    
    # Validate prerequisites
    if ! validate_preprovision_script; then
        exit 1
    fi
    
    # Run validation
    if run_validation; then
        print_verbose "✓ Workstation validation completed successfully"
        print_verbose "Your development environment is properly configured for Azure deployment"
        exit_code=0
    else
        exit_code=$?
        print_warning "⚠ Workstation validation completed with issues"
        print_warning "Please address the warnings/errors above before proceeding with development"
    fi
    
    print_verbose "Workstation validation process completed"
    exit ${exit_code}
}

# Trap errors for cleanup
trap 'print_error "Unexpected error on line $LINENO"; exit 1' ERR

# Execute main function
main "$@"
