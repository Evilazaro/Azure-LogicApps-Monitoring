#!/usr/bin/env bash

################################################################################
# Pre-provisioning script for Azure Developer CLI (azd) deployment
#
# SYNOPSIS:
#     Pre-provisioning script for Azure Developer CLI (azd) deployment.
#
# DESCRIPTION:
#     This script performs pre-provisioning tasks before Azure resources are 
#     provisioned. It ensures a clean state by clearing user secrets and 
#     validates the development environment.
#     
#     The script performs the following operations:
#     - Validates Bash version compatibility (4.0+)
#     - Validates required tools (.NET SDK 10.0+)
#     - Validates Azure Developer CLI (azd)
#     - Validates Azure CLI (2.60.0+) with authentication
#     - Validates Bicep CLI (0.30.0+)
#     - Validates Azure Resource Provider registration
#     - Checks Azure subscription quotas (informational)
#     - Clears .NET user secrets for all projects
#     - Provides detailed logging and error handling
#
# PARAMETERS:
#     --force                 Skip confirmation prompts and force execution
#     --skip-secrets-clear    Skip the user secrets clearing step
#     --validate-only         Only validate prerequisites without making changes
#     --verbose               Enable verbose output
#     --help                  Display this help message
#
# EXAMPLES:
#     ./preprovision.sh
#         Runs standard pre-provisioning with confirmation prompts.
#
#     ./preprovision.sh --force
#         Runs pre-provisioning without confirmation prompts.
#
#     ./preprovision.sh --validate-only
#         Only validates prerequisites without clearing secrets.
#
#     ./preprovision.sh --skip-secrets-clear --verbose
#         Skips secret clearing and shows verbose output.
#
# NOTES:
#     File Name      : preprovision.sh
#     Author         : Azure-LogicApps-Monitoring Team
#     Version        : 2.0.0
#     Last Modified  : 2025-12-29
#     Prerequisite   : Bash 4.0 or higher
#     Prerequisite   : .NET SDK 10.0 or higher
#     Prerequisite   : Azure Developer CLI (azd)
#     Prerequisite   : Azure CLI 2.60.0 or higher
#     Prerequisite   : Bicep CLI 0.30.0 or higher
#     Copyright      : (c) 2025. All rights reserved.
#
# LINK:
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
################################################################################

# Bash strict mode for robust error handling
# -e: Exit immediately if a command exits with non-zero status
# -u: Treat unset variables as errors
# -o pipefail: Return value of a pipeline is the status of the last command to exit with non-zero status
set -euo pipefail

################################################################################
# Script Configuration
################################################################################
# Define script-level constants for versioning and minimum requirements
# These values are used for validation and compatibility checks

# Script version following semantic versioning (major.minor.patch)
readonly SCRIPT_VERSION="2.0.0"

# Minimum Bash version required (4.0 for associative arrays and other features)
readonly MINIMUM_BASH_VERSION="4.0"

# Minimum .NET SDK version required (10.0 for latest features and LTS support)
readonly MINIMUM_DOTNET_VERSION="10.0"

# Minimum Azure CLI version required (2.60.0 for latest Bicep and ACA support)
readonly MINIMUM_AZURE_CLI_VERSION="2.60.0"

# Minimum Bicep CLI version required (0.30.0 for latest language features)
readonly MINIMUM_BICEP_VERSION="0.30.0"

# Script directory path resolved to absolute path for reliable file references
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Path to clean-secrets.sh script used for clearing .NET user secrets
readonly CLEAN_SECRETS_SCRIPT="${SCRIPT_DIR}/clean-secrets.sh"

# Required Azure Resource Providers
# These providers must be registered in the Azure subscription for successful deployment
# Each provider enables specific Azure services used by the application
readonly REQUIRED_RESOURCE_PROVIDERS=(
    "Microsoft.App"                    # Azure Container Apps for serverless containers
    "Microsoft.ServiceBus"             # Azure Service Bus for reliable messaging
    "Microsoft.Storage"                # Azure Storage for blobs, queues, and tables
    "Microsoft.Web"                    # Azure App Service and Logic Apps
    "Microsoft.ContainerRegistry"      # Azure Container Registry for Docker images
    "Microsoft.Insights"               # Application Insights for telemetry and monitoring
    "Microsoft.OperationalInsights"    # Log Analytics for centralized logging
    "Microsoft.ManagedIdentity"        # Managed identities for Azure resources authentication
)

# Script options - command-line flags that control script behavior
# These are set via command-line arguments and affect execution flow

# Skip confirmation prompts and force execution of all operations
OPT_FORCE=false

# Skip the user secrets clearing step (useful when secrets are already clean)
OPT_SKIP_SECRETS_CLEAR=false

# Only validate prerequisites without making any changes (dry-run mode)
OPT_VALIDATE_ONLY=false

# Enable verbose output for detailed diagnostic information
OPT_VERBOSE=false

# Execution tracking variables
# Used to track script execution time and validation status

# Timestamp when script execution started (Unix epoch seconds)
EXECUTION_START_TIME=""

# Flag indicating if any prerequisite validation failed
PREREQUISITES_FAILED=false

################################################################################
# Color Output Functions
################################################################################
# These functions provide consistent, colored output for different message types
# ANSI color codes are used for terminal color support
# All functions use echo -e to interpret escape sequences

# ANSI color code constants
# These define the color codes used throughout the script for formatted output
readonly COLOR_RED='\033[0;31m'       # Red color for error messages
readonly COLOR_GREEN='\033[0;32m'     # Green color for success messages
readonly COLOR_YELLOW='\033[1;33m'    # Yellow color for warning messages
readonly COLOR_BLUE='\033[0;34m'      # Blue color for verbose/debug messages
readonly COLOR_CYAN='\033[0;36m'      # Cyan color for informational messages
readonly COLOR_RESET='\033[0m'        # Reset to default terminal color

# Print error message in red and send to stderr
# Used for fatal errors that prevent script execution
# Parameters:
#   $* - Error message to display
# Output: Writes to stderr (file descriptor 2)
print_error() {
    echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2
}

# Print success message in green
# Used to indicate successful completion of operations
# Parameters:
#   $* - Success message to display
# Output: Writes to stdout
print_success() {
    echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

# Print warning message in yellow and send to stderr
# Used for non-fatal issues that may require attention
# Parameters:
#   $* - Warning message to display
# Output: Writes to stderr (file descriptor 2)
print_warning() {
    echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}" >&2
}

# Print informational message in cyan
# Used for general progress updates and status information
# Parameters:
#   $* - Info message to display
# Output: Writes to stdout
print_info() {
    echo -e "${COLOR_CYAN}ℹ $*${COLOR_RESET}"
}

# Print verbose/debug message in blue and send to stderr
# Only displayed when OPT_VERBOSE flag is enabled
# Used for detailed execution information during troubleshooting
# Parameters:
#   $* - Verbose message to display
# Output: Writes to stderr only if verbose mode is enabled
print_verbose() {
    if [[ "${OPT_VERBOSE}" == "true" ]]; then
        echo -e "${COLOR_BLUE}[VERBOSE] $*${COLOR_RESET}" >&2
    fi
}

################################################################################
# Error Handling
################################################################################
# Comprehensive error handling and cleanup functions
# These ensure graceful script termination and proper cleanup on exit

# Cleanup function called on script exit (success or failure)
# Registered via 'trap cleanup EXIT' to ensure it always executes
# Calculates and displays execution duration
# Parameters: None (uses global variables)
# Exit code: Preserves the original exit code of the script
cleanup() {
    local exit_code=$?
    
    # Calculate execution duration if timer was started
    if [[ -n "${EXECUTION_START_TIME}" ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - EXECUTION_START_TIME))
        
        # Only display duration in verbose mode during cleanup
        if [[ "${OPT_VERBOSE}" == "true" ]]; then
            print_verbose "Script execution completed in ${duration} seconds"
        fi
    fi
    
    exit "${exit_code}"
}

# Register cleanup function to run on script exit
# This ensures cleanup happens whether script exits normally or abnormally
trap cleanup EXIT

# Handle user interruption (Ctrl+C) gracefully
# Exit with code 130 (128 + 2 for SIGINT) following shell conventions
trap 'echo "Script interrupted by user" >&2; exit 130' INT TERM

################################################################################
# Help Documentation
################################################################################

show_help() {
    cat << EOF
Pre-provisioning script for Azure Developer CLI (azd) deployment

USAGE:
    ${0##*/} [OPTIONS]

DESCRIPTION:
    This script performs pre-provisioning tasks before Azure resources are 
    provisioned. It validates the development environment and ensures a clean 
    state by clearing user secrets.

OPTIONS:
    --force                 Skip confirmation prompts and force execution
    --skip-secrets-clear    Skip the user secrets clearing step
    --validate-only         Only validate prerequisites without making changes
    --verbose               Enable verbose output
    --help                  Display this help message

EXAMPLES:
    ${0##*/}
        Runs standard pre-provisioning with confirmation prompts.

    ${0##*/} --force
        Runs pre-provisioning without confirmation prompts.

    ${0##*/} --validate-only
        Only validates prerequisites without clearing secrets.

    ${0##*/} --skip-secrets-clear --verbose
        Skips secret clearing and shows verbose output.

PREREQUISITES:
    - Bash 4.0 or higher
    - .NET SDK 10.0 or higher
    - Azure Developer CLI (azd)
    - Azure CLI 2.60.0 or higher
    - Bicep CLI 0.30.0 or higher

VERSION:
    ${SCRIPT_VERSION}

AUTHOR:
    Azure-LogicApps-Monitoring Team

COPYRIGHT:
    (c) 2025. All rights reserved.

EOF
}

################################################################################
# Version Comparison Functions
################################################################################
# Utility functions for comparing semantic version strings
# These functions are used to validate that installed tools meet minimum version requirements
# Supports standard semantic versioning format (major.minor.patch)

# Compare two version strings numerically
# Parameters:
#   $1 - First version string (e.g., "10.0.1")
#   $2 - Second version string (e.g., "10.0.0")
# Returns:
#   0 if versions are equal
#   1 if version1 is greater than version2
#   2 if version1 is less than version2
# Note: Treats missing components as zero (e.g., "10.0" = "10.0.0")
version_compare() {
    local version1=$1
    local version2=$2
    
    if [[ "${version1}" == "${version2}" ]]; then
        return 0
    fi
    
    local IFS=.
    local i
    local ver1=($version1)
    local ver2=($version2)
    
    # Fill empty positions with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++)); do
        ver1[i]=0
    done
    
    # Compare each version component numerically
    for ((i=0; i<${#ver1[@]}; i++)); do
        # Handle missing elements in ver2 by treating them as zero
        if [[ -z ${ver2[i]:-} ]]; then
            ver2[i]=0
        fi
        
        # Compare individual version components numerically
        # Use 10# prefix to force base-10 interpretation (avoid octal issues with leading zeros)
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1  # version1 is greater
        fi
        
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2  # version1 is less
        fi
    done
    
    return 0  # Versions are equal
}

# Check if version1 is greater than or equal to version2
# Returns: 0 (true) if version1 >= version2, 1 (false) otherwise
# Parameters:
#   $1 - First version string (e.g., "10.0.1")
#   $2 - Second version string (e.g., "10.0.0")
# Usage: if version_greater_equal "10.0.1" "10.0.0"; then ...; fi
version_greater_equal() {
    version_compare "$1" "$2"
    local result=$?
    [[ ${result} -eq 0 || ${result} -eq 1 ]]
}

################################################################################
# Validation Functions
################################################################################
# Comprehensive validation functions for all required prerequisites
# Each function validates a specific tool or configuration requirement
# Returns: 0 for success (valid), 1 for failure (invalid or missing)
# Note: Functions use print_verbose for diagnostic output and print_warning for user-facing errors

# Validate Bash version meets minimum requirements
# Checks if current Bash version is compatible with script requirements
# Returns: 0 if version is acceptable, 1 otherwise
# Note: Uses BASH_VERSION environment variable provided by Bash shell
validate_bash_version() {
    print_verbose "Validating Bash version..."
    
    # Extract numeric version from BASH_VERSION (e.g., "5.1.16" from "5.1.16(1)-release")
    local bash_version="${BASH_VERSION%%[^0-9.]*}"
    print_verbose "Detected Bash version: ${bash_version}"
    
    # Compare with minimum required version
    if ! version_greater_equal "${bash_version}" "${MINIMUM_BASH_VERSION}"; then
        print_error "Bash version ${bash_version} is not supported"
        print_error "Minimum required version: ${MINIMUM_BASH_VERSION}"
        print_error "Please upgrade Bash to continue"
        return 1
    fi
    
    print_verbose "Bash version ${bash_version} is compatible"
    return 0
}

# Validate .NET SDK availability and version
# Checks if .NET SDK is installed and meets minimum version requirement
# Returns: 0 if .NET SDK is available and compatible, 1 otherwise
# Note: .NET SDK is required for building and managing .NET projects
validate_dotnet_sdk() {
    print_verbose "Validating .NET SDK..."
    
    # Check if dotnet command exists in PATH
    if ! command -v dotnet &> /dev/null; then
        print_error ".NET SDK not found"
        print_error "Install .NET SDK ${MINIMUM_DOTNET_VERSION} or higher from: https://dotnet.microsoft.com/download"
        return 1
    fi
    
    # Get full path to dotnet executable for diagnostics
    local dotnet_path
    dotnet_path=$(command -v dotnet)
    print_verbose "dotnet found at: ${dotnet_path}"
    
    # Get .NET SDK version
    local version_output
    if ! version_output=$(dotnet --version 2>&1); then
        print_error "Failed to get .NET SDK version"
        print_error "Command output: ${version_output}"
        return 1
    fi
    
    # Parse version string and remove whitespace
    local dotnet_version
    dotnet_version=$(echo "${version_output}" | head -n1 | tr -d '[:space:]')
    print_verbose "Detected .NET SDK version: ${dotnet_version}"
    
    # Extract major version for comparison
    # Using major version only for flexibility with minor/patch versions
    local major_version
    major_version=$(echo "${dotnet_version}" | cut -d. -f1)
    local min_major_version
    min_major_version=$(echo "${MINIMUM_DOTNET_VERSION}" | cut -d. -f1)
    
    # Compare major versions numerically
    if [[ ${major_version} -lt ${min_major_version} ]]; then
        print_error ".NET SDK version ${dotnet_version} is not supported"
        print_error "Minimum required version: ${MINIMUM_DOTNET_VERSION}"
        print_error "Download from: https://dotnet.microsoft.com/download/dotnet/${min_major_version}.0"
        return 1
    fi
    
    print_verbose ".NET SDK version ${dotnet_version} is compatible"
    return 0
}

# Validate Azure Developer CLI (azd) availability
# Checks if Azure Developer CLI is installed and accessible
# Returns: 0 if azd is available, 1 otherwise
# Note: azd is required for Azure deployment automation
validate_azure_developer_cli() {
    print_verbose "Validating Azure Developer CLI..."
    
    # Check if azd command exists in PATH
    if ! command -v azd &> /dev/null; then
        print_error "Azure Developer CLI (azd) not found"
        print_error "Install azd from: https://aka.ms/azd/install"
        return 1
    fi
    
    # Get full path to azd executable for diagnostics
    local azd_path
    azd_path=$(command -v azd)
    print_verbose "azd found at: ${azd_path}"
    
    # Get Azure Developer CLI version for validation
    local version_output
    if ! version_output=$(azd version 2>&1); then
        print_error "Failed to get Azure Developer CLI version"
        print_error "Command output: ${version_output}"
        return 1
    fi
    
    # Display version information (azd version output format varies)
    print_verbose "Azure Developer CLI version: $(echo "${version_output}" | head -n1)"
    return 0
}

# Validate Azure CLI availability, version, and authentication
# Checks if Azure CLI is installed, meets version requirements, and user is authenticated
# Returns: 0 if Azure CLI is available, compatible, and authenticated, 1 otherwise
# Note: Azure CLI is required for Azure resource management operations
validate_azure_cli() {
    print_verbose "Validating Azure CLI..."
    
    # Check if az command exists in PATH
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI not found"
        print_error "Install Azure CLI ${MINIMUM_AZURE_CLI_VERSION} or higher from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        return 1
    fi
    
    # Get full path to az executable for diagnostics
    local az_path
    az_path=$(command -v az)
    print_verbose "az found at: ${az_path}"
    
    # Get Azure CLI version information as JSON
    local version_json
    if ! version_json=$(az version --output json 2>&1); then
        print_error "Failed to get Azure CLI version"
        print_error "Command output: ${version_json}"
        return 1
    fi
    
    # Extract Azure CLI version from JSON output
    local az_version
    az_version=$(echo "${version_json}" | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
    print_verbose "Detected Azure CLI version: ${az_version}"
    
    # Compare version with minimum requirement
    if ! version_greater_equal "${az_version}" "${MINIMUM_AZURE_CLI_VERSION}"; then
        print_error "Azure CLI version ${az_version} is not supported"
        print_error "Minimum required version: ${MINIMUM_AZURE_CLI_VERSION}"
        print_error "Upgrade with: az upgrade"
        return 1
    fi
    
    # Check if user is authenticated to Azure
    print_verbose "Checking Azure authentication..."
    local account_info
    if ! account_info=$(az account show --output json 2>&1); then
        print_error "Not authenticated to Azure"
        print_error "Please run: az login"
        return 1
    fi
    
    # Extract authentication details for verification
    local user_name
    local subscription_name
    local subscription_id
    user_name=$(echo "${account_info}" | grep -o '"name": "[^"]*"' | head -n1 | cut -d'"' -f4)
    subscription_name=$(echo "${account_info}" | grep -o '"name": "[^"]*"' | sed -n '2p' | cut -d'"' -f4)
    subscription_id=$(echo "${account_info}" | grep -o '"id": "[^"]*"' | head -n1 | cut -d'"' -f4)
    
    print_verbose "Authenticated as: ${user_name}"
    print_verbose "Active subscription: ${subscription_name} (${subscription_id})"
    
    return 0
}

# Validate Bicep CLI availability and version
# Checks if Bicep CLI is installed (standalone or via Azure CLI) and meets version requirements
# Returns: 0 if Bicep CLI is available and compatible, 1 otherwise
# Note: Bicep is used for Azure infrastructure-as-code deployments
validate_bicep_cli() {
    print_verbose "Validating Bicep CLI..."
    
    local version_output=""
    
    # Check if bicep command exists (standalone installation)
    if command -v bicep &> /dev/null; then
        local bicep_path
        bicep_path=$(command -v bicep)
        print_verbose "bicep found at: ${bicep_path}"
        
        if ! version_output=$(bicep --version 2>&1); then
            print_error "Failed to get Bicep version from standalone CLI"
            return 1
        fi
        print_verbose "Retrieved Bicep version from standalone CLI"
    else
        # Try Azure CLI bicep integration
        print_verbose "Standalone bicep not found, trying Azure CLI integration..."
        if ! version_output=$(az bicep version 2>&1); then
            print_error "Bicep CLI not found (standalone or via Azure CLI)"
            print_error "Install with: az bicep install"
            return 1
        fi
        print_verbose "Retrieved Bicep version from Azure CLI"
    fi
    
    # Parse version from output (format: "Bicep CLI version x.y.z" or just "x.y.z")
    local bicep_version
    if bicep_version=$(echo "${version_output}" | grep -oP '\d+\.\d+\.\d+' | head -n1); then
        print_verbose "Detected Bicep CLI version: ${bicep_version}"
        
        # Compare version with minimum requirement
        if ! version_greater_equal "${bicep_version}" "${MINIMUM_BICEP_VERSION}"; then
            print_error "Bicep CLI version ${bicep_version} is not supported"
            print_error "Minimum required version: ${MINIMUM_BICEP_VERSION}"
            print_error "Upgrade with: az bicep upgrade"
            return 1
        fi
        
        return 0
    else
        print_error "Failed to parse Bicep version from output: ${version_output}"
        print_error "Please ensure Bicep CLI is properly installed"
        return 1
    fi
}

# Validate required Azure resource providers are registered
# Checks if all required Azure resource providers are registered in active subscription
# Returns: 0 if all providers are registered, 1 otherwise
# Note: Unregistered providers will prevent resource deployment
validate_azure_resource_providers() {
    print_verbose "Validating Azure resource provider registration..."
    
    local all_registered=true
    local unregistered_providers=()
    
    # Check registration status for each required provider
    for provider in "${REQUIRED_RESOURCE_PROVIDERS[@]}"; do
        print_verbose "Checking provider: ${provider}"
        
        # Query provider registration state via Azure CLI
        local provider_info
        if ! provider_info=$(az provider show --namespace "${provider}" --output json 2>&1); then
            print_verbose "Failed to retrieve provider info for: ${provider}"
            unregistered_providers+=("${provider}")
            all_registered=false
            continue
        fi
        
        # Extract registration state from JSON output
        local registration_state
        registration_state=$(echo "${provider_info}" | grep -o '"registrationState": "[^"]*"' | cut -d'"' -f4)
        
        # Check if provider is registered
        if [[ "${registration_state}" != "Registered" ]]; then
            print_verbose "Provider ${provider} is not registered (State: ${registration_state})"
            unregistered_providers+=("${provider}")
            all_registered=false
        else
            print_verbose "Provider ${provider} is registered"
        fi
    done
    
    # Report unregistered providers with instructions
    if [[ "${all_registered}" != "true" ]]; then
        print_warning "Some required Azure resource providers are not registered:"
        for provider in "${unregistered_providers[@]}"; do
            echo "    - ${provider}"
        done
        echo ""
        print_info "To register providers, run:"
        for provider in "${unregistered_providers[@]}"; do
            echo "    az provider register --namespace ${provider}"
        done
        echo ""
        print_warning "Provider registration may take a few minutes to complete"
        return 1
    fi
    
    return 0
}

# Check Azure subscription quotas (informational only)
# Provides informational guidance about common quota limits
# Returns: Always returns 0 (does not fail validation)
# Note: This is a best-effort check and doesn't prevent deployment
check_azure_quota() {
    print_verbose "Checking Azure subscription quotas..."
    
    # Display informational message about quota requirements
    # This is informational only - we don't fail based on quotas
    # Actual quota checks would require querying Azure usage APIs
    print_info "Quota check: Ensure your subscription has sufficient quota for:"
    echo "     - Container Apps (minimum 2 apps)"
    echo "     - Storage Accounts (minimum 3 accounts)"
    echo "     - Service Bus namespaces (minimum 1)"
    echo "     - Logic Apps Standard (minimum 1)"
    echo "     - Container Registry (minimum 1)"
    echo ""
    print_info "To check current quotas, visit Azure Portal > Subscriptions > Usage + quotas"
    echo ""
    
    return 0
}

################################################################################
# User Secrets Functions
################################################################################
# Functions for managing .NET user secrets
# User secrets provide secure configuration storage for development environments
# These functions integrate with clean-secrets.sh to clear all project secrets

# Invoke clean-secrets.sh script to clear .NET user secrets
# Executes the clean-secrets.sh script with appropriate parameters
# Returns: 0 if successful, 1 otherwise
# Note: Passes force and verbose flags from parent script to child script
invoke_clean_secrets() {
    print_verbose "Preparing to clear user secrets..."
    
    # Validate clean-secrets.sh script exists before attempting to execute
    if [[ ! -f "${CLEAN_SECRETS_SCRIPT}" ]]; then
        print_error "clean-secrets.sh script not found at: ${CLEAN_SECRETS_SCRIPT}"
        print_error "Please ensure the script exists in the hooks directory"
        return 1
    fi
    
    echo "Clearing user secrets for all projects..."
    print_verbose "Executing: ${CLEAN_SECRETS_SCRIPT}"
    
    # Build command arguments array based on script options
    local clean_args=()
    if [[ "${OPT_FORCE}" == "true" ]]; then
        clean_args+=("--force")
    fi
    if [[ "${OPT_VERBOSE}" == "true" ]]; then
        clean_args+=("--verbose")
    fi
    
    # Execute clean-secrets.sh with constructed arguments
    # Script output is displayed directly to user
    if bash "${CLEAN_SECRETS_SCRIPT}" "${clean_args[@]}"; then
        print_success "User secrets cleared successfully"
        print_verbose "clean-secrets.sh completed successfully"
        return 0
    else
        print_error "Failed to clear user secrets"
        print_error "Check clean-secrets.sh output above for details"
        return 1
    fi
}

################################################################################
# Output Functions
################################################################################

# Display formatted script header with version and environment information
# Outputs script metadata including version, timestamp, Bash version, and OS details
# Parameters: None
# Output: Formatted header to stdout
write_header() {
    # Get current timestamp in ISO 8601 format
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Extract numeric Bash version (e.g., "5.1.16" from full version string)
    local bash_version="${BASH_VERSION%%[^0-9.]*}"
    
    # Get OS description including kernel version
    local os_description
    os_description=$(uname -s -r)
    
    # Output formatted header with box drawing characters
    cat << EOF

╔════════════════════════════════════════════════════════════════╗
║          Azure Pre-Provisioning Script                        ║
╚════════════════════════════════════════════════════════════════╝

  Version:          ${SCRIPT_VERSION}
  Execution Time:   ${timestamp}
  Bash:             ${bash_version}
  OS:               ${os_description}

────────────────────────────────────────────────────────────────

EOF
}

# Display formatted execution summary with results
# Outputs execution status, duration, and completion message
# Parameters:
#   $1 - Execution duration in seconds
#   $2 - Success status ("true" or "false")
# Output: Formatted summary to stdout
write_summary() {
    local duration=$1
    local success=$2
    
    # Display separator line
    cat << EOF

────────────────────────────────────────────────────────────────

EOF
    
    # Display status with color coding
    if [[ "${success}" == "true" ]]; then
        echo -e "  Status:           ${COLOR_GREEN}✓ SUCCESS${COLOR_RESET}"
    else
        echo -e "  Status:           ${COLOR_RED}✗ FAILED${COLOR_RESET}"
    fi
    
    # Display execution duration
    echo "  Duration:         ${duration} seconds"
    echo ""
    
    # Display completion message box
    cat << EOF
╔════════════════════════════════════════════════════════════════╗
EOF
    
    # Display appropriate completion message based on success status
    if [[ "${success}" == "true" ]]; then
        echo "║   Pre-provisioning completed successfully!                    ║"
    else
        echo "║   Pre-provisioning completed with errors.                     ║"
    fi
    
    # Close completion message box
    cat << EOF
╚════════════════════════════════════════════════════════════════╝

EOF
}

################################################################################
# Argument Parsing
################################################################################
# Parse command-line arguments and configure script behavior
# Supports multiple flags that control validation, execution, and output verbosity
# Unknown arguments trigger an error and display usage information

# Parse command-line arguments and set script options
# Processes all command-line flags and sets corresponding global variables
# Parameters: All command-line arguments ($@)
# Output: None (sets global OPT_* variables)
# Exit: Exits with code 2 for invalid arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force)
                OPT_FORCE=true
                shift
                ;;
            --skip-secrets-clear)
                OPT_SKIP_SECRETS_CLEAR=true
                shift
                ;;
            --validate-only)
                OPT_VALIDATE_ONLY=true
                shift
                ;;
            --verbose)
                OPT_VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help for usage information." >&2
                exit 2
                ;;
        esac
    done
}

################################################################################
# Main Execution
################################################################################
# Main script execution flow
# Orchestrates all validation steps and secret clearing operations
# Provides detailed progress reporting and error handling
# Exit codes: 0 for success, 1 for failure, 2 for invalid arguments, 130 for user interruption

main() {
    # Parse command-line arguments and set script options
    parse_arguments "$@"
    
    # Start execution timer
    EXECUTION_START_TIME=$(date +%s)
    
    # Display header
    write_header
    
    # Step 1: Validate Bash version
    # This is a critical check that must pass before proceeding
    echo "Step 1: Validating Bash version..."
    if ! validate_bash_version; then
        print_error "Bash version validation failed"
        
        # Calculate execution duration for summary
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - EXECUTION_START_TIME))
        
        write_summary "${duration}" "false"
        exit 1
    fi
    print_success "Bash ${BASH_VERSION%%[^0-9.]*} is compatible"
    echo ""
    
    # Step 2: Validate prerequisites
    echo "Step 2: Validating prerequisites..."
    echo ""
    
    # Check .NET SDK
    echo "  • Checking .NET SDK..."
    if ! validate_dotnet_sdk; then
        print_warning "    ✗ .NET SDK ${MINIMUM_DOTNET_VERSION} or higher is required"
        print_warning "      Download from: https://dotnet.microsoft.com/download/dotnet/10.0"
        PREREQUISITES_FAILED=true
    else
        echo "    ✓ .NET SDK is available and compatible"
    fi
    echo ""
    
    # Check Azure Developer CLI
    echo "  • Checking Azure Developer CLI..."
    if ! validate_azure_developer_cli; then
        print_warning "    ✗ Azure Developer CLI (azd) is required"
        print_warning "      Install from: https://aka.ms/azd/install"
        PREREQUISITES_FAILED=true
    else
        echo "    ✓ Azure Developer CLI is available"
    fi
    echo ""
    
    # Check Azure CLI
    echo "  • Checking Azure CLI..."
    if ! validate_azure_cli; then
        print_warning "    ✗ Azure CLI ${MINIMUM_AZURE_CLI_VERSION} or higher is required"
        print_warning "      Install from: https://docs.microsoft.com/cli/azure/install-azure-cli"
        print_warning "      After installation, authenticate with: az login"
        PREREQUISITES_FAILED=true
    else
        echo "    ✓ Azure CLI is available and authenticated"
    fi
    echo ""
    
    # Check Bicep CLI
    echo "  • Checking Bicep CLI..."
    if ! validate_bicep_cli; then
        print_warning "    ✗ Bicep CLI ${MINIMUM_BICEP_VERSION} or higher is required"
        print_warning "      Install with Azure CLI: az bicep install"
        print_warning "      Or upgrade: az bicep upgrade"
        PREREQUISITES_FAILED=true
    else
        echo "    ✓ Bicep CLI is available and compatible"
    fi
    echo ""
    
    # Check Azure Resource Providers
    if [[ "${PREREQUISITES_FAILED}" != "true" ]]; then
        echo "  • Checking Azure Resource Provider registration..."
        if ! validate_azure_resource_providers; then
            print_warning "    ✗ Some required Azure resource providers are not registered"
            print_warning "      See warnings above for registration commands"
            PREREQUISITES_FAILED=true
        else
            echo "    ✓ All required resource providers are registered"
        fi
        echo ""
        
        # Check quotas (informational only)
        echo "  • Checking Azure subscription quotas..."
        check_azure_quota
        echo ""
    else
        echo "  • Skipping Azure resource provider check (previous validations failed)"
        echo ""
    fi
    
    # If any prerequisites failed, display error and exit
    if [[ "${PREREQUISITES_FAILED}" == "true" ]]; then
        print_error "One or more required prerequisites are missing or not configured"
        print_error "Please address the issues above and run the script again"
        echo ""
        
        # Calculate execution duration for summary
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - EXECUTION_START_TIME))
        
        write_summary "${duration}" "false"
        exit 1
    fi
    
    print_success "All prerequisites validated successfully"
    echo ""
    
    # Step 3: Clear user secrets (unless skipped or validate-only)
    if [[ "${OPT_VALIDATE_ONLY}" == "true" ]]; then
        print_info "Step 3: Skipping user secrets clearing (validate-only mode)"
        echo ""
    elif [[ "${OPT_SKIP_SECRETS_CLEAR}" == "true" ]]; then
        print_info "Step 3: Skipping user secrets clearing (--skip-secrets-clear flag set)"
        echo ""
    else
        echo "Step 3: Clearing user secrets..."
        echo ""
        
        # Execute clean-secrets.sh script
        if ! invoke_clean_secrets; then
            print_error "Failed to clear user secrets"
            
            # Calculate execution duration for summary
            local end_time
            end_time=$(date +%s)
            local duration=$((end_time - EXECUTION_START_TIME))
            
            write_summary "${duration}" "false"
            exit 1
        fi
        
        echo ""
    fi
    
    # Calculate final execution duration
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - EXECUTION_START_TIME))
    
    # Display success summary
    write_summary "${duration}" "true"
    
    print_verbose "Pre-provisioning completed successfully"
    exit 0
}

################################################################################
# Script Entry Point
################################################################################

main "$@"
