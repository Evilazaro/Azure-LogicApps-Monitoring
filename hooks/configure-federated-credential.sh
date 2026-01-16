#!/usr/bin/env bash
#
# configure-federated-credential.sh
#
# SYNOPSIS
#     Configures federated identity credentials for GitHub Actions OIDC authentication.
#
# DESCRIPTION
#     This script adds or updates federated identity credentials in an Azure AD App Registration
#     to enable GitHub Actions workflows to authenticate using OIDC (OpenID Connect).
#
#     This script is designed to be run as an Azure Developer CLI (azd) hook, where environment
#     variables are automatically loaded during the provisioning process.
#
# PARAMETERS
#     --app-name          The display name of the Azure AD App Registration.
#     --app-object-id     The Object ID of the Azure AD App Registration.
#     --github-org        The GitHub organization or username. Default: Evilazaro
#     --github-repo       The GitHub repository name. Default: Azure-LogicApps-Monitoring
#     --environment       The GitHub Environment name to configure. Default: dev
#
# EXAMPLES
#     ./configure-federated-credential.sh --app-name "my-app-registration"
#     ./configure-federated-credential.sh --app-object-id "00000000-0000-0000-0000-000000000000" --environment "prod"
#
# NOTES
#     Author: Azure Developer CLI Hook
#     Requires: Azure CLI, Bash 4.0+
#

set -euo pipefail

# Validate required dependencies
if ! command -v jq &> /dev/null; then
    echo "ERROR: 'jq' is required but not installed. Please install jq first." >&2
    echo "  - macOS: brew install jq" >&2
    echo "  - Ubuntu/Debian: sudo apt-get install jq" >&2
    echo "  - RHEL/CentOS: sudo yum install jq" >&2
    exit 1
fi

#region Constants
readonly GITHUB_OIDC_ISSUER="https://token.actions.githubusercontent.com"
readonly AZURE_AD_AUDIENCE="api://AzureADTokenExchange"
#endregion Constants

#region Default Values
APP_NAME=""
APP_OBJECT_ID=""
GITHUB_ORG="Evilazaro"
GITHUB_REPO="Azure-LogicApps-Monitoring"
ENVIRONMENT="dev"
#endregion Default Values

#region Helper Functions
write_info() {
    local message="$1"
    local color="${2:-white}"

    case "$color" in
        cyan)    echo -e "\033[36m${message}\033[0m" ;;
        green)   echo -e "\033[32m${message}\033[0m" ;;
        yellow)  echo -e "\033[33m${message}\033[0m" ;;
        red)     echo -e "\033[31m${message}\033[0m" ;;
        gray)    echo -e "\033[90m${message}\033[0m" ;;
        *)       echo "$message" ;;
    esac
}

write_section_header() {
    local title="$1"
    write_info "========================================" "cyan"
    write_info "$title" "cyan"
    write_info "========================================" "cyan"
}

test_azure_cli_login() {
    write_info "\nChecking Azure CLI login status..." "yellow"

    local account_json
    if ! account_json=$(az account show --output json 2>&1); then
        write_info "Not logged in to Azure CLI. Please run 'az login' first." "red"
        exit 1
    fi

    local user_name subscription_name subscription_id
    user_name=$(echo "$account_json" | jq -r '.user.name')
    subscription_name=$(echo "$account_json" | jq -r '.name')
    subscription_id=$(echo "$account_json" | jq -r '.id')

    write_info "Logged in as: $user_name" "green"
    write_info "Subscription: $subscription_name ($subscription_id)" "green"
}

get_app_registration() {
    local name="$1"
    local object_id="$2"

    if [[ -n "$object_id" ]]; then
        echo "$object_id"
        return 0
    fi

    if [[ -z "$name" ]]; then
        write_info "\nNo AppName or AppObjectId provided. Listing available App Registrations..." "yellow"

        local apps_json
        if ! apps_json=$(az ad app list --all --query "[].{DisplayName:displayName, AppId:appId, ObjectId:id}" --output json 2>&1); then
            write_info "Failed to list App Registrations." "red"
            exit 1
        fi

        local app_count
        app_count=$(echo "$apps_json" | jq 'length')

        if [[ "$app_count" -eq 0 ]]; then
            write_info "No App Registrations found in this tenant." "red"
            exit 1
        fi

        write_info "\nAvailable App Registrations:" "cyan"
        echo "$apps_json" | jq -r '.[] | "\(.DisplayName)\t\(.AppId)\t\(.ObjectId)"' | column -t -s $'\t'

        read -rp "Enter the App Registration display name: " name
    fi

    write_info "\nLooking up App Registration: $name" "yellow"

    local app_json
    if ! app_json=$(az ad app list --display-name "$name" --query '[0]' --output json 2>&1); then
        write_info "Failed to look up App Registration '$name'." "red"
        exit 1
    fi

    if [[ "$app_json" == "null" || -z "$app_json" ]]; then
        write_info "App Registration '$name' not found." "red"
        exit 1
    fi

    local display_name app_id resolved_object_id
    display_name=$(echo "$app_json" | jq -r '.displayName')
    app_id=$(echo "$app_json" | jq -r '.appId')
    resolved_object_id=$(echo "$app_json" | jq -r '.id')

    write_info "Found App Registration:" "green"
    write_info "  Display Name: $display_name" "white"
    write_info "  App ID (Client ID): $app_id" "white"
    write_info "  Object ID: $resolved_object_id" "white"

    echo "$resolved_object_id"
}

get_federated_credentials() {
    local app_object_id="$1"

    write_info "\nChecking existing federated credentials..." "yellow"

    local credentials_json
    if ! credentials_json=$(az ad app federated-credential list --id "$app_object_id" --output json 2>&1); then
        echo "[]"
        return 0
    fi

    echo "$credentials_json"
}

create_federated_credential() {
    local app_object_id="$1"
    local credential_name="$2"
    local subject="$3"
    local description="$4"

    write_info "\nCreating federated credential..." "yellow"
    write_info "  Name: $credential_name" "white"
    write_info "  Issuer: $GITHUB_OIDC_ISSUER" "white"
    write_info "  Subject: $subject" "white"
    write_info "  Audience: $AZURE_AD_AUDIENCE" "white"

    # Create a temporary file for JSON parameters
    local temp_file
    temp_file=$(mktemp)

    cat > "$temp_file" << EOF
{
    "name": "$credential_name",
    "issuer": "$GITHUB_OIDC_ISSUER",
    "subject": "$subject",
    "audiences": ["$AZURE_AD_AUDIENCE"],
    "description": "$description"
}
EOF

    local result_json
    if ! result_json=$(az ad app federated-credential create --id "$app_object_id" --parameters "@$temp_file" --output json 2>&1); then
        write_info "Failed to create federated credential: $result_json" "red"
        rm -f "$temp_file"
        exit 1
    fi

    rm -f "$temp_file"

    local result_id result_name
    result_id=$(echo "$result_json" | jq -r '.id')
    result_name=$(echo "$result_json" | jq -r '.name')

    write_info "\nFederated credential created successfully!" "green"
    write_info "  ID: $result_id" "white"
    write_info "  Name: $result_name" "white"
}

show_workflow_guidance() {
    write_section_header "Setup Complete!"
    write_info "\nYour GitHub Actions workflow should now be able to authenticate using OIDC." "white"
    write_info "Make sure your workflow has the following permissions:" "white"
    write_info "
permissions:
  id-token: write
  contents: read
" "gray"

    write_info "And uses the azure/login action like this:" "white"
    write_info '
- uses: azure/login@v2
  with:
    client-id: ${{ secrets.AZURE_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
' "gray"
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Configure federated identity credentials for GitHub Actions OIDC authentication.

Options:
    --app-name          The display name of the Azure AD App Registration
    --app-object-id     The Object ID of the Azure AD App Registration
    --github-org        The GitHub organization or username (default: Evilazaro)
    --github-repo       The GitHub repository name (default: Azure-LogicApps-Monitoring)
    --environment       The GitHub Environment name (default: dev)
    -h, --help          Show this help message

Examples:
    $(basename "$0") --app-name "my-app-registration"
    $(basename "$0") --app-object-id "00000000-0000-0000-0000-000000000000" --environment "prod"
EOF
}
#endregion Helper Functions

#region Parse Arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-name)
            APP_NAME="$2"
            shift 2
            ;;
        --app-object-id)
            APP_OBJECT_ID="$2"
            shift 2
            ;;
        --github-org)
            GITHUB_ORG="$2"
            shift 2
            ;;
        --github-repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            write_info "Unknown option: $1" "red"
            show_usage
            exit 1
            ;;
    esac
done
#endregion Parse Arguments

#region Main Script
write_section_header "Federated Identity Credential Setup"

# Verify Azure CLI login
test_azure_cli_login

# Get the App Registration Object ID
resolved_app_object_id=$(get_app_registration "$APP_NAME" "$APP_OBJECT_ID")

# Get existing federated credentials
existing_credentials=$(get_federated_credentials "$resolved_app_object_id")

credentials_count=$(echo "$existing_credentials" | jq 'length')
if [[ "$credentials_count" -gt 0 ]]; then
    write_info "Existing federated credentials:" "cyan"
    echo "$existing_credentials" | jq -r '.[] | "  - Name: \(.name)\n    Subject: \(.subject)\n"'
fi

# Define the subject claim for the GitHub environment
subject_claim="repo:${GITHUB_ORG}/${GITHUB_REPO}:environment:${ENVIRONMENT}"
credential_name="github-actions-${ENVIRONMENT}-environment"

# Check if credential already exists
existing_cred=$(echo "$existing_credentials" | jq -r --arg subject "$subject_claim" '.[] | select(.subject == $subject) | .name')

if [[ -n "$existing_cred" ]]; then
    write_info "Federated credential for subject '$subject_claim' already exists." "green"
    write_info "Credential Name: $existing_cred" "white"
    exit 0
fi

# Create the environment federated credential
create_federated_credential \
    "$resolved_app_object_id" \
    "$credential_name" \
    "$subject_claim" \
    "GitHub Actions OIDC for $GITHUB_ORG/$GITHUB_REPO $ENVIRONMENT environment"
#endregion Main Script

#region Optional Credentials
write_section_header "Additional Credential Options"

read -rp $'\nDo you want to create a credential for the \'main\' branch? (y/N) ' create_branch
if [[ "$create_branch" =~ ^[Yy]$ ]]; then
    branch_subject="repo:${GITHUB_ORG}/${GITHUB_REPO}:ref:refs/heads/main"
    branch_cred_name="github-actions-main-branch"

    branch_exists=$(echo "$existing_credentials" | jq -r --arg subject "$branch_subject" '.[] | select(.subject == $subject) | .name')
    if [[ -z "$branch_exists" ]]; then
        create_federated_credential \
            "$resolved_app_object_id" \
            "$branch_cred_name" \
            "$branch_subject" \
            "GitHub Actions OIDC for $GITHUB_ORG/$GITHUB_REPO main branch"
        write_info "Created credential for main branch." "green"
    else
        write_info "Credential for main branch already exists." "yellow"
    fi
fi

read -rp "Do you want to create a credential for pull requests? (y/N) " create_pr
if [[ "$create_pr" =~ ^[Yy]$ ]]; then
    pr_subject="repo:${GITHUB_ORG}/${GITHUB_REPO}:pull_request"
    pr_cred_name="github-actions-pull-request"

    pr_exists=$(echo "$existing_credentials" | jq -r --arg subject "$pr_subject" '.[] | select(.subject == $subject) | .name')
    if [[ -z "$pr_exists" ]]; then
        create_federated_credential \
            "$resolved_app_object_id" \
            "$pr_cred_name" \
            "$pr_subject" \
            "GitHub Actions OIDC for $GITHUB_ORG/$GITHUB_REPO pull requests"
        write_info "Created credential for pull requests." "green"
    else
        write_info "Credential for pull requests already exists." "yellow"
    fi
fi
#endregion Optional Credentials

# Show workflow guidance
show_workflow_guidance
