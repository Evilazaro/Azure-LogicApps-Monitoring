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
#     Last Modified  : 2025-12-24
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

# Bash strict mode
set -euo pipefail

################################################################################
# Script Configuration
################################################################################

readonly SCRIPT_VERSION="2.0.0"
readonly MINIMUM_BASH_VERSION="4.0"
readonly MINIMUM_DOTNET_VERSION="10.0"
readonly MINIMUM_AZURE_CLI_VERSION="2.60.0"
readonly MINIMUM_BICEP_VERSION="0.30.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLEAN_SECRETS_SCRIPT="${SCRIPT_DIR}/clean-secrets.sh"

# Required Azure Resource Providers
readonly REQUIRED_RESOURCE_PROVIDERS=(
    "Microsoft.App"
    "Microsoft.ServiceBus"
    "Microsoft.Storage"
    "Microsoft.Web"
    "Microsoft.ContainerRegistry"
    "Microsoft.Insights"
    "Microsoft.OperationalInsights"
    "Microsoft.ManagedIdentity"
)

# Script options
OPT_FORCE=false
OPT_SKIP_SECRETS_CLEAR=false
OPT_VALIDATE_ONLY=false
OPT_VERBOSE=false

# Execution tracking
EXECUTION_START_TIME=""
PREREQUISITES_FAILED=false

################################################################################
# Color Output Functions
################################################################################

# Color codes
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_RESET='\033[0m'

# Print functions
print_error() {
    echo -e "${COLOR_RED}✗ $*${COLOR_RESET}" >&2
}

print_success() {
    echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠ $*${COLOR_RESET}" >&2
}

print_info() {
    echo -e "${COLOR_CYAN}ℹ $*${COLOR_RESET}"
}

print_verbose() {
    if [[ "${OPT_VERBOSE}" == "true" ]]; then
        echo -e "${COLOR_BLUE}[VERBOSE] $*${COLOR_RESET}" >&2
    fi
}

################################################################################
# Error Handling
################################################################################

cleanup() {
    local exit_code=$?
    
    if [[ -n "${EXECUTION_START_TIME}" ]]; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - EXECUTION_START_TIME))
        
        if [[ ${exit_code} -eq 0 ]]; then
            write_summary "${duration}" "true"
        else
            write_summary "${duration}" "false"
        fi
    fi
    
    exit "${exit_code}"
}

trap cleanup EXIT
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

version_compare() {
    # Compares two version strings
    # Returns: 0 if equal, 1 if version1 > version2, 2 if version1 < version2
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
    
    for ((i=0; i<${#ver1[@]}; i++)); do
        if [[ -z ${ver2[i]:-} ]]; then
            ver2[i]=0
        fi
        
        if ((10#${ver1[i]} > 10#${ver2[i]})); then
            return 1
        fi
        
        if ((10#${ver1[i]} < 10#${ver2[i]})); then
            return 2
        fi
    done
    
    return 0
}

version_greater_equal() {
    # Returns 0 if version1 >= version2
    version_compare "$1" "$2"
    local result=$?
    [[ ${result} -eq 0 || ${result} -eq 1 ]]
}

################################################################################
# Validation Functions
################################################################################

validate_bash_version() {
    print_verbose "Validating Bash version..."
    
    local bash_version="${BASH_VERSION%%[^0-9.]*}"
    print_verbose "Detected Bash version: ${bash_version}"
    
    if ! version_greater_equal "${bash_version}" "${MINIMUM_BASH_VERSION}"; then
        print_error "Current Bash version: ${bash_version}"
        print_error "Minimum required version: ${MINIMUM_BASH_VERSION}"
        return 1
    fi
    
    print_verbose "Bash version ${bash_version} is compatible"
    return 0
}

validate_dotnet_sdk() {
    print_verbose "Validating .NET SDK..."
    
    if ! command -v dotnet &> /dev/null; then
        print_verbose ".NET SDK not found in PATH"
        return 1
    fi
    
    local dotnet_path
    dotnet_path=$(command -v dotnet)
    print_verbose "dotnet found at: ${dotnet_path}"
    
    local version_output
    if ! version_output=$(dotnet --version 2>&1); then
        print_verbose "Failed to retrieve .NET version"
        return 1
    fi
    
    local dotnet_version
    dotnet_version=$(echo "${version_output}" | head -n1 | tr -d '[:space:]')
    print_verbose "Detected .NET SDK version: ${dotnet_version}"
    
    # Extract major version for comparison
    local major_version
    major_version=$(echo "${dotnet_version}" | cut -d. -f1)
    local min_major_version
    min_major_version=$(echo "${MINIMUM_DOTNET_VERSION}" | cut -d. -f1)
    
    if [[ ${major_version} -lt ${min_major_version} ]]; then
        print_warning "Current .NET SDK version: ${dotnet_version}"
        print_warning "Minimum required version: ${MINIMUM_DOTNET_VERSION}"
        return 1
    fi
    
    print_verbose ".NET SDK version ${dotnet_version} is compatible"
    return 0
}

validate_azure_developer_cli() {
    print_verbose "Validating Azure Developer CLI..."
    
    if ! command -v azd &> /dev/null; then
        print_verbose "Azure Developer CLI not found in PATH"
        return 1
    fi
    
    local azd_path
    azd_path=$(command -v azd)
    print_verbose "azd found at: ${azd_path}"
    
    local version_output
    if ! version_output=$(azd version 2>&1); then
        print_verbose "Failed to execute azd version command"
        return 1
    fi
    
    print_verbose "Azure Developer CLI version: $(echo "${version_output}" | head -n1)"
    return 0
}

validate_azure_cli() {
    print_verbose "Validating Azure CLI..."
    
    if ! command -v az &> /dev/null; then
        print_verbose "Azure CLI not found in PATH"
        return 1
    fi
    
    local az_path
    az_path=$(command -v az)
    print_verbose "az found at: ${az_path}"
    
    # Get Azure CLI version
    local version_json
    if ! version_json=$(az version --output json 2>&1); then
        print_verbose "Failed to retrieve Azure CLI version"
        return 1
    fi
    
    local az_version
    az_version=$(echo "${version_json}" | grep -o '"azure-cli": "[^"]*"' | cut -d'"' -f4)
    print_verbose "Detected Azure CLI version: ${az_version}"
    
    if ! version_greater_equal "${az_version}" "${MINIMUM_AZURE_CLI_VERSION}"; then
        print_warning "Current Azure CLI version: ${az_version}"
        print_warning "Minimum required version: ${MINIMUM_AZURE_CLI_VERSION}"
        return 1
    fi
    
    # Check if user is authenticated
    print_verbose "Checking Azure authentication..."
    local account_info
    if ! account_info=$(az account show --output json 2>&1); then
        print_verbose "User is not authenticated to Azure"
        return 1
    fi
    
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

validate_bicep_cli() {
    print_verbose "Validating Bicep CLI..."
    
    local version_output=""
    
    # Check if bicep command exists (standalone)
    if command -v bicep &> /dev/null; then
        local bicep_path
        bicep_path=$(command -v bicep)
        print_verbose "bicep found at: ${bicep_path}"
        
        if ! version_output=$(bicep --version 2>&1); then
            print_verbose "Failed to retrieve Bicep version"
            return 1
        fi
    else
        # Try Azure CLI bicep
        print_verbose "Standalone Bicep CLI not found, checking via Azure CLI..."
        if ! version_output=$(az bicep version 2>&1); then
            print_verbose "Bicep CLI not available via Azure CLI"
            return 1
        fi
    fi
    
    # Parse version from output (format: "Bicep CLI version x.y.z")
    local bicep_version
    if bicep_version=$(echo "${version_output}" | grep -oP '\d+\.\d+\.\d+' | head -n1); then
        print_verbose "Detected Bicep CLI version: ${bicep_version}"
        
        if ! version_greater_equal "${bicep_version}" "${MINIMUM_BICEP_VERSION}"; then
            print_warning "Current Bicep CLI version: ${bicep_version}"
            print_warning "Minimum required version: ${MINIMUM_BICEP_VERSION}"
            return 1
        fi
        
        return 0
    else
        print_verbose "Failed to parse Bicep version"
        return 1
    fi
}

validate_azure_resource_providers() {
    print_verbose "Validating Azure resource provider registration..."
    
    local all_registered=true
    local unregistered_providers=()
    
    for provider in "${REQUIRED_RESOURCE_PROVIDERS[@]}"; do
        print_verbose "Checking provider: ${provider}"
        
        local provider_info
        if ! provider_info=$(az provider show --namespace "${provider}" --output json 2>&1); then
            print_verbose "Failed to retrieve provider info for: ${provider}"
            unregistered_providers+=("${provider}")
            all_registered=false
            continue
        fi
        
        local registration_state
        registration_state=$(echo "${provider_info}" | grep -o '"registrationState": "[^"]*"' | cut -d'"' -f4)
        
        if [[ "${registration_state}" != "Registered" ]]; then
            print_verbose "Provider ${provider} is not registered (State: ${registration_state})"
            unregistered_providers+=("${provider}")
            all_registered=false
        else
            print_verbose "Provider ${provider} is registered"
        fi
    done
    
    if [[ "${all_registered}" != "true" ]]; then
        print_warning "Some required resource providers are not registered:"
        for provider in "${unregistered_providers[@]}"; do
            print_warning "  - ${provider}"
        done
        echo ""
        print_warning "To register these providers, run:"
        for provider in "${unregistered_providers[@]}"; do
            print_warning "  az provider register --namespace ${provider} --wait"
        done
        return 1
    fi
    
    return 0
}

check_azure_quota() {
    print_verbose "Checking Azure subscription quotas..."
    
    # This is informational only - we don't fail based on quotas
    print_info "Quota check: Ensure your subscription has sufficient quota for:"
    echo "     - Container Apps (minimum 2 apps)"
    echo "     - Storage Accounts (minimum 3 accounts)"
    echo "     - Service Bus namespaces (minimum 1)"
    echo "     - Logic Apps Standard (minimum 1)"
    echo "     - Container Registry (minimum 1)"
    echo ""
    
    return 0
}

################################################################################
# User Secrets Functions
################################################################################

invoke_clean_secrets() {
    print_verbose "Preparing to clear user secrets..."
    
    # Validate clean-secrets.sh exists
    if [[ ! -f "${CLEAN_SECRETS_SCRIPT}" ]]; then
        print_warning "clean-secrets.sh not found at: ${CLEAN_SECRETS_SCRIPT}"
        return 1
    fi
    
    echo "Clearing user secrets for all projects..."
    print_verbose "Executing: ${CLEAN_SECRETS_SCRIPT}"
    
    # Build command arguments
    local clean_args=()
    if [[ "${OPT_FORCE}" == "true" ]]; then
        clean_args+=("--force")
    fi
    if [[ "${OPT_VERBOSE}" == "true" ]]; then
        clean_args+=("--verbose")
    fi
    
    # Execute clean-secrets.sh
    if bash "${CLEAN_SECRETS_SCRIPT}" "${clean_args[@]}"; then
        print_success "User secrets cleared successfully"
        return 0
    else
        print_warning "clean-secrets.sh exited with code: $?"
        return 1
    fi
}

################################################################################
# Output Functions
################################################################################

write_header() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local bash_version="${BASH_VERSION%%[^0-9.]*}"
    local os_description
    os_description=$(uname -s -r)
    
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

write_summary() {
    local duration=$1
    local success=$2
    
    cat << EOF

────────────────────────────────────────────────────────────────

EOF
    
    if [[ "${success}" == "true" ]]; then
        echo -e "  Status:           ${COLOR_GREEN}✓ SUCCESS${COLOR_RESET}"
    else
        echo -e "  Status:           ${COLOR_RED}✗ FAILED${COLOR_RESET}"
    fi
    
    echo "  Duration:         ${duration} seconds"
    echo ""
    
    cat << EOF
╔════════════════════════════════════════════════════════════════╗
EOF
    
    if [[ "${success}" == "true" ]]; then
        echo "║   Pre-provisioning completed successfully!                    ║"
    else
        echo "║   Pre-provisioning completed with errors.                     ║"
    fi
    
    cat << EOF
╚════════════════════════════════════════════════════════════════╝

EOF
}

################################################################################
# Argument Parsing
################################################################################

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
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
}

################################################################################
# Main Execution
################################################################################

main() {
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Start execution timer
    EXECUTION_START_TIME=$(date +%s)
    
    # Display header
    write_header
    
    # Step 1: Validate Bash version
    echo "Step 1: Validating Bash version..."
    if ! validate_bash_version; then
        print_error "Bash version ${BASH_VERSION%%[^0-9.]*} is not supported. Minimum required: ${MINIMUM_BASH_VERSION}"
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
    
    if [[ "${PREREQUISITES_FAILED}" == "true" ]]; then
        print_error "One or more required prerequisites are missing or not configured. Please address the issues above."
        exit 1
    fi
    
    print_success "All prerequisites validated successfully"
    echo ""
    
    # Step 3: Clear user secrets (unless skipped or validate-only)
    if [[ "${OPT_VALIDATE_ONLY}" == "true" ]]; then
        echo "Step 3: Skipping user secrets clearing (ValidateOnly mode)"
        echo ""
    elif [[ "${OPT_SKIP_SECRETS_CLEAR}" == "true" ]]; then
        echo "Step 3: Skipping user secrets clearing (SkipSecretsClear flag set)"
        echo ""
    else
        echo "Step 3: Clearing user secrets..."
        echo ""
        
        if ! invoke_clean_secrets; then
            print_warning "User secrets clearing completed with warnings."
            print_warning "This may not affect deployment, but should be investigated."
        fi
        
        echo ""
    fi
    
    print_verbose "Pre-provisioning completed successfully"
}

################################################################################
# Script Entry Point
################################################################################

main "$@"
