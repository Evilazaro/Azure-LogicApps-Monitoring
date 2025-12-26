#!/usr/bin/env bash

<#
.SYNOPSIS
    Validates developer workstation prerequisites for Azure Logic Apps Monitoring solution.

.DESCRIPTION
    This script performs comprehensive validation of the development environment to ensure
    all required tools, software dependencies, and Azure configurations are properly set up
    before beginning development work on the Azure Logic Apps Monitoring solution.
    
    The script acts as a wrapper around preprovision.sh in ValidateOnly mode, providing
    a developer-friendly way to check workstation readiness without performing any
    modifications to the environment.
    
    Validations performed include:
    - Bash version (4.0+)
    - .NET SDK version (10.0+)
    - Azure Developer CLI (azd)
    - Azure CLI (2.60.0+) with active authentication
    - Bicep CLI (0.30.0+)
    - Azure Resource Provider registrations
    - Azure subscription quota requirements
    
.PARAMETER Verbose
    Displays detailed diagnostic information during validation.

.EXAMPLE
    ./check-dev-workstation.sh
    Performs standard workstation validation with normal output.

.EXAMPLE
    ./check-dev-workstation.sh --verbose
    Performs validation with detailed diagnostic output for troubleshooting.

.OUTPUTS
    System.String
    Formatted output string containing validation results.

.NOTES
    File Name      : check-dev-workstation.sh
    Author         : Azure-LogicApps-Monitoring Team
    Version        : 1.0.0
    Last Modified  : 2025-12-26
    Prerequisite   : Bash 4.0+, preprovision.sh
    Purpose        : Development environment validation wrapper
    Copyright      : (c) 2025. All rights reserved.

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring

.LINK
    preprovision.sh - The underlying validation script

.COMPONENT
    Azure Logic Apps Monitoring - Development Tools

.ROLE
    Development Environment Validation

.FUNCTIONALITY
    Validates development workstation prerequisites for Azure deployment
#>

# Bash strict mode
set -euo pipefail

# Bash strict mode
set -euo pipefail

# Script metadata
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="check-dev-workstation.sh"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Script configuration
VERBOSE=false
ERROR_ACTION_PREFERENCE="Continue"  # Allow script to complete even if preprovision has warnings

#region Main Execution

# Trap for error handling and cleanup
trap 'error_code=$?; exit $error_code' EXIT

# Validate preprovision.sh exists
preprovision_path="${SCRIPT_DIR}/preprovision.sh"
if [[ ! -f "${preprovision_path}" ]]; then
    echo "ERROR: Required script not found: ${preprovision_path}" >&2
    echo "ERROR: This script requires preprovision.sh to be in the same directory." >&2
    exit 1
fi

# Make executable if needed
if [[ ! -x "${preprovision_path}" ]]; then
    chmod +x "${preprovision_path}" 2>/dev/null || true
fi

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            cat << 'EOF'
check-dev-workstation.sh - Developer Workstation Validation Tool

SYNOPSIS
    check-dev-workstation.sh [OPTIONS]

DESCRIPTION
    Validates developer workstation prerequisites for Azure Logic Apps
    Monitoring solution.

OPTIONS
    -v, --verbose    Display detailed diagnostic information
    -h, --help       Display this help message

EXAMPLES
    check-dev-workstation.sh
    check-dev-workstation.sh --verbose

VERSION
    1.0.0

EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option: $1" >&2
            echo "Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

if [[ "${VERBOSE}" == true ]]; then
    echo "[VERBOSE] Starting developer workstation validation..." >&2
    echo "[VERBOSE] Using validation script: ${preprovision_path}" >&2
    echo "[VERBOSE] Script version: ${SCRIPT_VERSION}" >&2
fi

# Execute preprovision.sh in ValidateOnly mode
# This performs all prerequisite checks without making any changes
# Parameters:
#   --validate-only: Skips secret clearing, only performs validation
#   --verbose: Ensures all diagnostic messages are displayed (if requested)

validation_args=("--validate-only")
if [[ "${VERBOSE}" == true ]]; then
    validation_args+=("--verbose")
fi

# Run validation and capture all output
validation_output=$("${preprovision_path}" "${validation_args[@]}" 2>&1) || validation_exit_code=$?
validation_exit_code=${validation_exit_code:-0}

# Display validation results
echo "${validation_output}"

# Check if validation was successful by examining the exit code
if [[ ${validation_exit_code} -eq 0 ]]; then
    if [[ "${VERBOSE}" == true ]]; then
        echo "[VERBOSE] ✓ Workstation validation completed successfully" >&2
        echo "[VERBOSE] Your development environment is properly configured for Azure deployment" >&2
    fi
    exit 0
else
    if [[ "${VERBOSE}" == true ]]; then
        echo "[VERBOSE] ⚠ Workstation validation completed with issues" >&2
        echo "[VERBOSE] Please address the warnings/errors above before proceeding with development" >&2
    fi
    exit ${validation_exit_code}
fi

#endregion
