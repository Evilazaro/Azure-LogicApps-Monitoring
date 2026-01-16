#!/usr/bin/env bash
#
# deploy-workflow.sh
#
# SYNOPSIS
#   Deploys Logic Apps Standard workflows to Azure.
#
# DESCRIPTION
#   Deploys workflow definitions from OrdersManagement Logic App to Azure.
#   Runs as azd predeploy hook - environment variables are already loaded.
#
# USAGE
#   ./deploy-workflow.sh [workflow_path]
#
# PARAMETERS
#   workflow_path   Optional path to the workflow project directory.
#
# NOTES
#   Version: 2.0.1
#   Requires: Azure CLI 2.50+, Bash 4.0+, jq
#

set -euo pipefail

# Script directory for relative path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Placeholder pattern for ${VARIABLE} substitution
readonly PLACEHOLDER_PATTERN='\$\{([A-Z_][A-Z0-9_]*)\}'

# Files to exclude from deployment (per .funcignore)
readonly EXCLUDE_PATTERNS=('.debug' '.git*' '.vscode' '__azurite*' '__blobstorage__' '__queuestorage__' 'local.settings.json' 'test' 'workflow-designtime')

#region Helper Functions

write_log() {
    local message="$1"
    local level="${2:-Info}"
    local prefix color reset
    
    reset='\033[0m'
    
    case "$level" in
        Info)
            prefix="[i]"
            color='\033[0;36m' # Cyan
            ;;
        Success)
            prefix="[✓]"
            color='\033[0;32m' # Green
            ;;
        Warning)
            prefix="[!]"
            color='\033[0;33m' # Yellow
            ;;
        Error)
            prefix="[✗]"
            color='\033[0;31m' # Red
            ;;
        *)
            prefix="[i]"
            color='\033[0;36m'
            ;;
    esac
    
    echo -e "${color}$(date '+%H:%M:%S') ${prefix} ${message}${reset}"
}

get_environment_value() {
    local name="$1"
    local default="${2:-}"
    local value
    
    value="${!name:-}"
    if [[ -n "$value" ]]; then
        echo "$value"
    else
        echo "$default"
    fi
}

set_workflow_environment_aliases() {
    # Map WORKFLOWS_* variables to AZURE_* equivalents for connections.json compatibility
    # Also export AZURE_* variables that may come from azd environment
    declare -A mappings=(
        ["WORKFLOWS_SUBSCRIPTION_ID"]="AZURE_SUBSCRIPTION_ID"
        ["WORKFLOWS_RESOURCE_GROUP_NAME"]="AZURE_RESOURCE_GROUP"
        ["WORKFLOWS_LOCATION_NAME"]="AZURE_LOCATION"
    )
    
    for key in "${!mappings[@]}"; do
        local source_key="${mappings[$key]}"
        if [[ -z "${!key:-}" ]] && [[ -n "${!source_key:-}" ]]; then
            export "$key"="${!source_key}"
            write_log "Set ${key}=${!source_key}" Success
        fi
    done
    
    # Debug: Show all relevant environment variables
    write_log "Environment variables for deployment:"
    write_log "  AZURE_SUBSCRIPTION_ID=${AZURE_SUBSCRIPTION_ID:-<not set>}"
    write_log "  AZURE_RESOURCE_GROUP=${AZURE_RESOURCE_GROUP:-<not set>}"
    write_log "  AZURE_LOCATION=${AZURE_LOCATION:-<not set>}"
    write_log "  MANAGED_IDENTITY_NAME=${MANAGED_IDENTITY_NAME:-<not set>}"
    write_log "  WORKFLOWS_SUBSCRIPTION_ID=${WORKFLOWS_SUBSCRIPTION_ID:-<not set>}"
    write_log "  WORKFLOWS_RESOURCE_GROUP_NAME=${WORKFLOWS_RESOURCE_GROUP_NAME:-<not set>}"
}

resolve_placeholders() {
    local content="$1"
    local filename="$2"
    local resolved="$content"
    local unresolved=()
    
    # Find all ${VARIABLE} patterns and replace them
    while IFS= read -r match; do
        if [[ -n "$match" ]]; then
            # Extract variable name from ${VAR_NAME}
            local var_name="${match:2:-1}"
            local var_value="${!var_name:-}"
            
            if [[ -n "$var_value" ]]; then
                resolved="${resolved//$match/$var_value}"
                write_log "  Resolved \${${var_name}} in ${filename}" Success
            else
                unresolved+=("$var_name")
            fi
        fi
    done < <(grep -oE '\$\{[A-Z_][A-Z0-9_]*\}' <<< "$content" | sort -u)
    
    if [[ ${#unresolved[@]} -gt 0 ]]; then
        write_log "Unresolved in ${filename}: $(IFS=', '; echo "${unresolved[*]}")" Warning
    fi
    
    echo "$resolved"
}

get_connection_runtime_url() {
    local connection_name="$1"
    local resource_group="$2"
    local subscription_id="$3"
    
    local uri="https://management.azure.com/subscriptions/${subscription_id}/resourceGroups/${resource_group}/providers/Microsoft.Web/connections/${connection_name}/listConnectionKeys?api-version=2016-06-01"
    
    local result
    if result=$(az rest --method POST --uri "$uri" --output json 2>/dev/null); then
        local runtime_url
        runtime_url=$(echo "$result" | jq -r '.runtimeUrls[0] // empty' 2>/dev/null)
        if [[ -n "$runtime_url" ]]; then
            echo "$runtime_url"
            return 0
        fi
    fi
    
    return 1
}

cleanup() {
    local exit_code=$?
    
    # Clean up staging directory if it exists
    if [[ -n "${STAGING_DIR:-}" ]] && [[ -d "$STAGING_DIR" ]]; then
        rm -rf "$STAGING_DIR"
    fi
    
    # Clean up zip file if it exists
    if [[ -n "${ZIP_PATH:-}" ]] && [[ -f "$ZIP_PATH" ]]; then
        rm -f "$ZIP_PATH"
    fi
    
    exit $exit_code
}

#endregion

#region Main

main() {
    local workflow_path="${1:-}"
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    echo ""
    echo -e '\033[0;36m╔════════════════════════════════════════════════════════╗\033[0m'
    echo -e '\033[0;36m║     Logic Apps Standard Workflow Deployment            ║\033[0m'
    echo -e '\033[0;36m╚════════════════════════════════════════════════════════╝\033[0m'
    echo ""
    
    # Set up environment variable aliases for connections.json compatibility
    set_workflow_environment_aliases
    
    # Load required configuration from environment
    local subscription_id resource_group logic_app_name location
    local service_bus_runtime_url blob_runtime_url
    
    subscription_id=$(get_environment_value 'AZURE_SUBSCRIPTION_ID')
    resource_group=$(get_environment_value 'AZURE_RESOURCE_GROUP')
    logic_app_name=$(get_environment_value 'LOGIC_APP_NAME')
    location=$(get_environment_value 'AZURE_LOCATION' 'westus3')
    service_bus_runtime_url=$(get_environment_value 'SERVICE_BUS_CONNECTION_RUNTIME_URL')
    blob_runtime_url=$(get_environment_value 'AZURE_BLOB_CONNECTION_RUNTIME_URL')
    
    # Validate required values
    local missing=()
    [[ -z "$subscription_id" ]] && missing+=('AZURE_SUBSCRIPTION_ID')
    [[ -z "$resource_group" ]] && missing+=('AZURE_RESOURCE_GROUP')
    [[ -z "$logic_app_name" ]] && missing+=('LOGIC_APP_NAME')
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        write_log "Missing environment variables: $(IFS=', '; echo "${missing[*]}")" Error
        exit 1
    fi
    
    write_log "Target: ${logic_app_name} in ${resource_group}"
    
    # Find workflow project
    local project_path
    if [[ -n "$workflow_path" ]] && [[ -d "$workflow_path" ]]; then
        project_path="$workflow_path"
    else
        local search_path="${SCRIPT_DIR}/../workflows/OrdersManagement/OrdersManagementLogicApp"
        if [[ -d "$search_path" ]]; then
            project_path="$(cd "$search_path" && pwd)"
        else
            write_log "Workflow project not found" Error
            exit 1
        fi
    fi
    
    write_log "Source: ${project_path}"
    
    # Discover workflows
    local workflows=()
    while IFS= read -r -d '' dir; do
        local dir_name
        dir_name="$(basename "$dir")"
        
        # Check if workflow.json exists
        if [[ ! -f "${dir}/workflow.json" ]]; then
            continue
        fi
        
        # Check against exclude patterns
        local excluded=false
        for pattern in "${EXCLUDE_PATTERNS[@]}"; do
            # shellcheck disable=SC2053
            if [[ "$dir_name" == $pattern ]]; then
                excluded=true
                break
            fi
        done
        
        if [[ "$excluded" == false ]]; then
            workflows+=("$dir")
        fi
    done < <(find "$project_path" -mindepth 1 -maxdepth 1 -type d -print0)
    
    if [[ ${#workflows[@]} -eq 0 ]]; then
        write_log "No workflows found" Error
        exit 1
    fi
    
    local workflow_names=()
    for wf in "${workflows[@]}"; do
        workflow_names+=("$(basename "$wf")")
    done
    write_log "Workflows: $(IFS=', '; echo "${workflow_names[*]}")" Success
    
    # Get connection runtime URLs if not in environment
    if [[ -z "$service_bus_runtime_url" ]]; then
        write_log "Fetching Service Bus connection runtime URL..."
        service_bus_runtime_url=$(get_connection_runtime_url 'servicebus' "$resource_group" "$subscription_id" || true)
    fi
    
    if [[ -z "$blob_runtime_url" ]]; then
        write_log "Fetching Azure Blob connection runtime URL..."
        blob_runtime_url=$(get_connection_runtime_url 'azureblob' "$resource_group" "$subscription_id" || true)
    fi
    
    # Create staging directory
    STAGING_DIR=$(mktemp -d)
    
    # Copy host.json
    cp "${project_path}/host.json" "${STAGING_DIR}/"
    
    # Process connections.json
    local connections_file="${project_path}/connections.json"
    if [[ -f "$connections_file" ]]; then
        local content
        content=$(<"$connections_file")
        local resolved
        resolved=$(resolve_placeholders "$content" "connections.json")
        echo "$resolved" > "${STAGING_DIR}/connections.json"
    fi
    
    # Process parameters.json
    local parameters_file="${project_path}/parameters.json"
    if [[ -f "$parameters_file" ]]; then
        local content
        content=$(<"$parameters_file")
        local resolved
        resolved=$(resolve_placeholders "$content" "parameters.json")
        echo "$resolved" > "${STAGING_DIR}/parameters.json"
    fi
    
    # Process workflow folders
    for wf in "${workflows[@]}"; do
        local wf_name
        wf_name="$(basename "$wf")"
        local dest_dir="${STAGING_DIR}/${wf_name}"
        mkdir -p "$dest_dir"
        
        local wf_file="${wf}/workflow.json"
        local content
        content=$(<"$wf_file")
        local resolved
        resolved=$(resolve_placeholders "$content" "${wf_name}/workflow.json")
        echo "$resolved" > "${dest_dir}/workflow.json"
    done
    
    # Create zip package
    # mktemp creates an empty file; we need to remove it first so zip can create a fresh archive
    local temp_base
    temp_base=$(mktemp)
    rm -f "$temp_base"
    ZIP_PATH="${temp_base}.zip"
    (cd "$STAGING_DIR" && zip -r -q "$ZIP_PATH" .)
    
    local zip_size
    zip_size=$(du -k "$ZIP_PATH" | cut -f1)
    write_log "Package: ${zip_size} KB" Success
    
    # Update app settings with connection runtime URLs
    write_log "Updating application settings..."
    local settings=()
    [[ -n "$service_bus_runtime_url" ]] && settings+=("servicebus-ConnectionRuntimeUrl=${service_bus_runtime_url}")
    [[ -n "$blob_runtime_url" ]] && settings+=("azureblob-ConnectionRuntimeUrl=${blob_runtime_url}")
    
    if [[ ${#settings[@]} -gt 0 ]]; then
        if ! az functionapp config appsettings set \
            --name "$logic_app_name" \
            --resource-group "$resource_group" \
            --subscription "$subscription_id" \
            --settings "${settings[@]}" \
            --output none 2>/dev/null; then
            write_log "Failed to update application settings" Warning
        fi
    fi
    
    # Deploy
    write_log "Deploying workflows..."
    local start_time
    start_time=$(date +%s)
    
    if ! az functionapp deployment source config-zip \
        --name "$logic_app_name" \
        --resource-group "$resource_group" \
        --subscription "$subscription_id" \
        --src "$ZIP_PATH" \
        --output none; then
        write_log "Deployment failed" Error
        
        # Fetch deployment logs to help diagnose the issue
        write_log "Fetching deployment logs..." Warning
        az webapp log deployment show \
            --name "$logic_app_name" \
            --resource-group "$resource_group" \
            --subscription "$subscription_id" \
            --output table 2>/dev/null || true
        
        exit 1
    fi
    
    local end_time duration
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    write_log "Deployed in ${duration} seconds" Success
    
    echo ""
    echo -e '\033[0;32m╔════════════════════════════════════════════════════════╗\033[0m'
    echo -e '\033[0;32m║              Deployment Complete                       ║\033[0m'
    echo -e '\033[0;32m╚════════════════════════════════════════════════════════╝\033[0m'
    echo ""
}

#endregion

# Run main with all arguments
main "$@"
