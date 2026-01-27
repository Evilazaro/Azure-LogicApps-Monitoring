#!/usr/bin/env bash

################################################################################
# Generate-Orders.sh
#
# SYNOPSIS
#     Generates sample order data for testing Azure Logic Apps monitoring.
#
# DESCRIPTION
#     This script generates random e-commerce orders with products, customer
#     information, and delivery addresses. The generated data is saved as JSON
#     for use in testing and demonstration scenarios.
#
#     Order IDs are generated using UUIDs to ensure uniqueness across multiple
#     runs. Each order contains a random selection of products from a built-in
#     catalog of 20 items, with configurable quantity ranges and price
#     variations (±20%) to simulate real-world pricing fluctuations.
#
#     The script includes a diverse set of global delivery addresses and
#     generates random order dates between 2024-01-01 and 2025-12-31.
#
# USAGE
#     ./Generate-Orders.sh [OPTIONS]
#
# OPTIONS
#     -c, --count <number>     Number of orders to generate (default: 2000)
#                              Valid range: 1-10000
#     -o, --output <path>      Output file path (default: ../infra/data/ordersBatch.json)
#     -m, --min-products <n>   Minimum products per order (default: 1)
#                              Valid range: 1-20
#     -M, --max-products <n>   Maximum products per order (default: 6)
#                              Valid range: 1-20
#     -f, --force              Force execution without prompting
#     -n, --dry-run            Show what would be executed without making changes
#     -v, --verbose            Display detailed diagnostic information
#     -h, --help               Display this help message and exit
#
# EXAMPLES
#     ./Generate-Orders.sh
#         Generates 2000 orders using default settings.
#
#     ./Generate-Orders.sh --count 100 --output "/tmp/orders.json"
#         Generates 100 orders and saves to a custom path.
#
#     ./Generate-Orders.sh --count 25 --min-products 2 --max-products 4
#         Generates 25 orders with 2-4 products each.
#
#     ./Generate-Orders.sh --dry-run --verbose
#         Preview what would be generated without making changes.
#
# EXIT CODES
#     0    Success - All operations completed successfully
#     1    Error - Fatal error occurred or validation failed
#     130  Interrupted - Script was interrupted by user (Ctrl+C)
#
# DEPENDENCIES
#     - Bash 4.0 or higher
#     - jq - Command-line JSON processor
#     - bc - Arbitrary precision calculator
#     - uuidgen or /proc/sys/kernel/random/uuid for UUID generation
#
# OUTPUT FORMAT
#     The script generates a JSON array of order objects with the following
#     structure:
#     {
#       "id": "ORD-<UUID>",
#       "customerId": "CUST-<UUID>",
#       "date": "<ISO 8601 timestamp>",
#       "deliveryAddress": "<address string>",
#       "total": <decimal>,
#       "products": [
#         {
#           "id": "OP-<UUID>",
#           "orderId": "ORD-<UUID>",
#           "productId": "PROD-<ID>",
#           "productDescription": "<description>",
#           "quantity": <integer>,
#           "price": <decimal>
#         }
#       ]
#     }
#
# NOTES
#     File Name      : Generate-Orders.sh
#     Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
#     Version        : 2.0.1
#     Last Modified  : 2026-01-06
#
# LINKS
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#
# COMPONENT
#     Azure Logic Apps Monitoring - Development Tools
#
# ROLE
#     Test Data Generation
#
# FUNCTIONALITY
#     Generates sample e-commerce order data for testing Logic Apps workflows
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

# Script name for consistent logging and error messages
readonly SCRIPT_NAME="Generate-Orders.sh"

# Resolve script directory for reliable path operations
# Using BASH_SOURCE[0] instead of $0 for sourcing compatibility
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#==============================================================================
# DEFAULT CONFIGURATION
#==============================================================================

# Default parameter values
DEFAULT_ORDER_COUNT=2000
DEFAULT_MIN_PRODUCTS=1
DEFAULT_MAX_PRODUCTS=6

#==============================================================================
# GLOBAL VARIABLES
#==============================================================================

# Command-line options
ORDER_COUNT="${DEFAULT_ORDER_COUNT}"
OUTPUT_PATH="${SCRIPT_DIR}/../infra/data/ordersBatch.json"
MIN_PRODUCTS="${DEFAULT_MIN_PRODUCTS}"
MAX_PRODUCTS="${DEFAULT_MAX_PRODUCTS}"
FORCE=false
DRY_RUN=false
VERBOSE=false

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
# PRODUCT CATALOG
#==============================================================================

# Product catalog data structure for order generation
# Each product has: Id, Description, BasePrice
# Price variation is applied during order generation to simulate
# real-world pricing fluctuations, promotions, and discounts.
declare -a PRODUCT_IDS=(
    "PROD-1001" "PROD-1002" "PROD-1003"
    "PROD-2001" "PROD-2002"
    "PROD-3001" "PROD-3002"
    "PROD-4001" "PROD-4002"
    "PROD-5001" "PROD-5002"
    "PROD-6001" "PROD-6002"
    "PROD-7001" "PROD-7002"
    "PROD-8001" "PROD-8002"
    "PROD-9001" "PROD-9002"
    "PROD-A001"
)

declare -a PRODUCT_DESCRIPTIONS=(
    "Wireless Mouse" "Mechanical Keyboard" "USB-C Hub"
    "Noise Cancelling Headphones" "Bluetooth Speaker"
    "External SSD 1TB" "Portable Charger"
    "Webcam 1080p" "Laptop Stand"
    "Cable Organizer" "Smartphone Holder"
    "Monitor 27\" 4K" "Monitor Arm"
    "Ergonomic Chair" "Standing Desk"
    "USB Microphone" "Ring Light"
    "Graphics Tablet" "Drawing Pen Set"
    "Wireless Earbuds"
)

declare -a PRODUCT_PRICES=(
    "25.99" "89.99" "34.99"
    "149.99" "79.99"
    "119.99" "49.99"
    "69.99" "39.99"
    "12.99" "19.99"
    "399.99" "89.99"
    "299.99" "499.99"
    "99.99" "44.99"
    "199.99" "29.99"
    "129.99"
)

#==============================================================================
# DELIVERY ADDRESSES
#==============================================================================

# Global delivery address pool for order generation
# Contains diverse addresses from major cities worldwide
declare -a ADDRESSES=(
    "221B Baker Street, London, UK"
    "350 Fifth Ave, New York, NY, USA"
    "88 Colin P Kelly Jr St, San Francisco, CA, USA"
    "1600 Amphitheatre Parkway, Mountain View, CA, USA"
    "1 Microsoft Way, Redmond, WA, USA"
    "410 Terry Ave N, Seattle, WA, USA"
    "1 Apple Park Way, Cupertino, CA, USA"
    "Platz der Republik 1, Berlin, Germany"
    "Champs-Élysées, Paris, France"
    "Shibuya Crossing, Tokyo, Japan"
    "123 Main St, Toronto, ON, Canada"
    "456 Queen St, Sydney, NSW, Australia"
    "789 King St, Melbourne, VIC, Australia"
    "10 Downing Street, London, UK"
    "Rua Oscar Freire, São Paulo, Brazil"
    "Passeig de Gràcia, Barcelona, Spain"
    "Unter den Linden, Berlin, Germany"
    "Via Montenapoleone, Milan, Italy"
    "Nanjing Road, Shanghai, China"
    "Gangnam District, Seoul, South Korea"
)

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
#------------------------------------------------------------------------------
log_error() {
    echo -e "${COLOR_RED}ERROR: $*${COLOR_RESET}" >&2
}

#------------------------------------------------------------------------------
# Function: log_warning
# Description: Outputs warning messages to stderr with WARNING prefix
# Arguments:
#   $@ - Warning message to display
#------------------------------------------------------------------------------
log_warning() {
    echo -e "${COLOR_YELLOW}WARNING: $*${COLOR_RESET}" >&2
}

#------------------------------------------------------------------------------
# Function: log_success
# Description: Outputs success messages with green color
# Arguments:
#   $@ - Success message to display
#------------------------------------------------------------------------------
log_success() {
    echo -e "${COLOR_GREEN}✓ $*${COLOR_RESET}"
}

#------------------------------------------------------------------------------
# Function: log_info
# Description: Outputs informational messages with cyan color
# Arguments:
#   $@ - Info message to display
#------------------------------------------------------------------------------
log_info() {
    echo -e "${COLOR_CYAN}  $*${COLOR_RESET}"
}

#------------------------------------------------------------------------------
# Function: log_verbose
# Description: Outputs verbose messages only when VERBOSE flag is set
# Arguments:
#   $@ - Verbose message to display
#------------------------------------------------------------------------------
log_verbose() {
    if [[ "${VERBOSE}" == true ]]; then
        echo -e "VERBOSE: $*"
    fi
}

#==============================================================================
# HELPER FUNCTIONS
#==============================================================================

#------------------------------------------------------------------------------
# Function: show_usage
# Description: Displays detailed help information and usage examples
# Arguments:
#   None
# Returns:
#   Exits with code 0
#------------------------------------------------------------------------------
show_usage() {
    cat << EOF
${SCRIPT_NAME} - Generate sample order data for testing

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

OPTIONS:
    -c, --count <number>       Number of orders to generate (default: ${DEFAULT_ORDER_COUNT})
                               Valid range: 1-10000
    -o, --output <path>        Output file path for generated orders
                               Default: ../infra/data/ordersBatch.json
    -m, --min-products <n>     Minimum products per order (default: ${DEFAULT_MIN_PRODUCTS})
                               Valid range: 1-20
    -M, --max-products <n>     Maximum products per order (default: ${DEFAULT_MAX_PRODUCTS})
                               Valid range: 1-20
    -f, --force                Force execution without prompting
    -n, --dry-run              Show what would be executed without making changes
    -v, --verbose              Display detailed diagnostic information
    -h, --help                 Display this help message and exit

EXAMPLES:
    # Generate 2000 orders using default settings
    ./${SCRIPT_NAME}

    # Generate 100 orders to a custom path
    ./${SCRIPT_NAME} --count 100 --output "/tmp/orders.json"

    # Generate 25 orders with 2-4 products each
    ./${SCRIPT_NAME} --count 25 --min-products 2 --max-products 4

    # Preview without generating (dry-run)
    ./${SCRIPT_NAME} --dry-run --verbose

VERSION: ${SCRIPT_VERSION}
EOF
    exit 0
}

#------------------------------------------------------------------------------
# Function: parse_arguments
# Description: Parses command-line arguments and sets global configuration
# Arguments:
#   $@ - All command-line arguments
#------------------------------------------------------------------------------
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--count)
                if [[ -z "${2:-}" ]]; then
                    log_error "Missing value for $1"
                    exit 1
                fi
                ORDER_COUNT="$2"
                shift 2
                ;;
            -o|--output)
                if [[ -z "${2:-}" ]]; then
                    log_error "Missing value for $1"
                    exit 1
                fi
                OUTPUT_PATH="$2"
                shift 2
                ;;
            -m|--min-products)
                if [[ -z "${2:-}" ]]; then
                    log_error "Missing value for $1"
                    exit 1
                fi
                MIN_PRODUCTS="$2"
                shift 2
                ;;
            -M|--max-products)
                if [[ -z "${2:-}" ]]; then
                    log_error "Missing value for $1"
                    exit 1
                fi
                MAX_PRODUCTS="$2"
                shift 2
                ;;
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
                show_usage
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information."
                exit 1
                ;;
        esac
    done
}

#------------------------------------------------------------------------------
# Function: validate_parameters
# Description: Validates all parameters are within acceptable ranges
#------------------------------------------------------------------------------
validate_parameters() {
    log_verbose "Validating parameters..."
    
    # Validate ORDER_COUNT is a number
    if ! [[ "${ORDER_COUNT}" =~ ^[0-9]+$ ]]; then
        log_error "Order count must be a positive integer: ${ORDER_COUNT}"
        exit 1
    fi
    
    # Validate ORDER_COUNT range
    if [[ "${ORDER_COUNT}" -lt 1 || "${ORDER_COUNT}" -gt 10000 ]]; then
        log_error "Order count must be between 1 and 10000: ${ORDER_COUNT}"
        exit 1
    fi
    
    # Validate MIN_PRODUCTS is a number
    if ! [[ "${MIN_PRODUCTS}" =~ ^[0-9]+$ ]]; then
        log_error "Min products must be a positive integer: ${MIN_PRODUCTS}"
        exit 1
    fi
    
    # Validate MIN_PRODUCTS range
    if [[ "${MIN_PRODUCTS}" -lt 1 || "${MIN_PRODUCTS}" -gt 20 ]]; then
        log_error "Min products must be between 1 and 20: ${MIN_PRODUCTS}"
        exit 1
    fi
    
    # Validate MAX_PRODUCTS is a number
    if ! [[ "${MAX_PRODUCTS}" =~ ^[0-9]+$ ]]; then
        log_error "Max products must be a positive integer: ${MAX_PRODUCTS}"
        exit 1
    fi
    
    # Validate MAX_PRODUCTS range
    if [[ "${MAX_PRODUCTS}" -lt 1 || "${MAX_PRODUCTS}" -gt 20 ]]; then
        log_error "Max products must be between 1 and 20: ${MAX_PRODUCTS}"
        exit 1
    fi
    
    # Validate MIN_PRODUCTS <= MAX_PRODUCTS
    if [[ "${MIN_PRODUCTS}" -gt "${MAX_PRODUCTS}" ]]; then
        log_error "Min products (${MIN_PRODUCTS}) cannot be greater than max products (${MAX_PRODUCTS})"
        exit 1
    fi
    
    # Validate output path is not empty
    if [[ -z "${OUTPUT_PATH}" ]]; then
        log_error "Output path cannot be empty"
        exit 1
    fi
    
    log_verbose "Parameters validated successfully"
}

#------------------------------------------------------------------------------
# Function: check_dependencies
# Description: Checks if required dependencies are available
#------------------------------------------------------------------------------
check_dependencies() {
    log_verbose "Checking dependencies..."
    
    # Check for jq (JSON processor)
    if ! command -v jq &> /dev/null; then
        log_error "jq is required but not installed. Install it with:"
        log_error "  Ubuntu/Debian: sudo apt-get install jq"
        log_error "  macOS: brew install jq"
        log_error "  RHEL/CentOS: sudo yum install jq"
        exit 1
    fi
    
    # Check for bc (arbitrary precision calculator)
    if ! command -v bc &> /dev/null; then
        log_error "bc is required but not installed. Install it with:"
        log_error "  Ubuntu/Debian: sudo apt-get install bc"
        log_error "  macOS: brew install bc"
        log_error "  RHEL/CentOS: sudo yum install bc"
        exit 1
    fi
    
    # Check for uuidgen or fall back to /proc/sys/kernel/random/uuid
    if ! command -v uuidgen &> /dev/null; then
        if [[ ! -f /proc/sys/kernel/random/uuid ]]; then
            log_error "Neither uuidgen nor /proc/sys/kernel/random/uuid available"
            exit 1
        fi
    fi
    
    log_verbose "Dependencies verified successfully"
}

#------------------------------------------------------------------------------
# Function: generate_uuid
# Description: Generates a UUID (GUID)
# Returns:
#   UUID string
#------------------------------------------------------------------------------
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen | tr '[:lower:]' '[:upper:]'
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        cat /proc/sys/kernel/random/uuid | tr '[:lower:]' '[:upper:]'
    else
        # Fallback using random hex
        printf '%04X%04X-%04X-%04X-%04X-%04X%04X%04X\n' \
            $((RANDOM)) $((RANDOM)) $((RANDOM)) \
            $(((RANDOM & 0x0FFF) | 0x4000)) \
            $(((RANDOM & 0x3FFF) | 0x8000)) \
            $((RANDOM)) $((RANDOM)) $((RANDOM))
    fi
}

#------------------------------------------------------------------------------
# Function: get_short_uuid
# Description: Generates a shortened UUID (first N characters)
# Arguments:
#   $1 - Number of characters to return (default: 12)
# Returns:
#   Shortened UUID string
#------------------------------------------------------------------------------
get_short_uuid() {
    local length="${1:-12}"
    local uuid
    uuid=$(generate_uuid | tr -d '-')
    echo "${uuid:0:${length}}"
}

#------------------------------------------------------------------------------
# Function: get_random_date
# Description: Generates a random date between 2024-01-01 and 2025-12-31
# Returns:
#   ISO 8601 formatted timestamp
#------------------------------------------------------------------------------
get_random_date() {
    # Start date: 2024-01-01 00:00:00 UTC
    local start_epoch=1704067200
    # End date: 2025-12-31 23:59:59 UTC
    local end_epoch=1767225599
    
    # Generate random epoch within range
    local range=$((end_epoch - start_epoch))
    local random_offset=$((RANDOM * 32768 + RANDOM))
    local random_epoch=$((start_epoch + (random_offset % range)))
    
    # Convert to ISO 8601 format
    if date --version &>/dev/null 2>&1; then
        # GNU date (Linux)
        date -u -d "@${random_epoch}" +"%Y-%m-%dT%H:%M:%SZ"
    else
        # BSD date (macOS)
        date -u -r "${random_epoch}" +"%Y-%m-%dT%H:%M:%SZ"
    fi
}

#------------------------------------------------------------------------------
# Function: get_random_number
# Description: Generates a random number within a range
# Arguments:
#   $1 - Minimum value (inclusive)
#   $2 - Maximum value (inclusive)
# Returns:
#   Random integer
#------------------------------------------------------------------------------
get_random_number() {
    local min=$1
    local max=$2
    local range=$((max - min + 1))
    echo $((RANDOM % range + min))
}

#------------------------------------------------------------------------------
# Function: get_random_decimal
# Description: Generates a random decimal multiplier for price variation
# Returns:
#   Decimal between 0.80 and 1.20
#------------------------------------------------------------------------------
get_random_decimal() {
    # Generate random percentage between 80 and 120
    local percentage=$((RANDOM % 41 + 80))
    # Convert to decimal with bc
    echo "scale=2; ${percentage} / 100" | bc
}

#------------------------------------------------------------------------------
# Function: round_price
# Description: Rounds a price to 2 decimal places
# Arguments:
#   $1 - Price value
# Returns:
#   Rounded price
#------------------------------------------------------------------------------
round_price() {
    printf "%.2f" "$1"
}

#------------------------------------------------------------------------------
# Function: escape_json_string
# Description: Escapes special characters for JSON string
# Arguments:
#   $1 - String to escape
# Returns:
#   JSON-safe escaped string
#------------------------------------------------------------------------------
escape_json_string() {
    local str="$1"
    # Escape backslashes first, then quotes
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    echo "${str}"
}

#------------------------------------------------------------------------------
# Function: generate_order
# Description: Generates a single order with random products
# Arguments:
#   None - Order IDs are generated using UUIDs
# Returns:
#   JSON object representing the order
#------------------------------------------------------------------------------
generate_order() {
    # Generate unique IDs
    local order_guid
    order_guid=$(get_short_uuid 12)
    local order_id="ORD-${order_guid}"
    
    local customer_guid
    customer_guid=$(get_short_uuid 8)
    local customer_id="CUST-${customer_guid}"
    
    # Generate random date
    local order_date
    order_date=$(get_random_date)
    
    # Select random address
    local address_index
    address_index=$(get_random_number 0 $((${#ADDRESSES[@]} - 1)))
    local delivery_address
    delivery_address=$(escape_json_string "${ADDRESSES[${address_index}]}")
    
    # Determine number of products
    local product_count
    product_count=$(get_random_number "${MIN_PRODUCTS}" "${MAX_PRODUCTS}")
    
    # Generate shuffled indices for product selection
    local product_indices=()
    local available_indices=()
    for i in "${!PRODUCT_IDS[@]}"; do
        available_indices+=("$i")
    done
    
    # Shuffle and select products
    for ((i=0; i<product_count && ${#available_indices[@]} > 0; i++)); do
        local rand_pos
        rand_pos=$(get_random_number 0 $((${#available_indices[@]} - 1)))
        product_indices+=("${available_indices[${rand_pos}]}")
        # Remove selected index
        unset "available_indices[${rand_pos}]"
        available_indices=("${available_indices[@]}")
    done
    
    # Build products array
    local products_json="["
    local order_total=0
    local first_product=true
    
    for idx in "${product_indices[@]}"; do
        local product_id="${PRODUCT_IDS[${idx}]}"
        local product_desc
        product_desc=$(escape_json_string "${PRODUCT_DESCRIPTIONS[${idx}]}")
        local base_price="${PRODUCT_PRICES[${idx}]}"
        
        # Generate random quantity (1-5)
        local quantity
        quantity=$(get_random_number 1 5)
        
        # Apply price variation (±20%)
        local variation
        variation=$(get_random_decimal)
        local price
        price=$(echo "scale=2; ${base_price} * ${variation}" | bc)
        price=$(round_price "${price}")
        
        # Calculate subtotal
        local subtotal
        subtotal=$(echo "scale=2; ${price} * ${quantity}" | bc)
        order_total=$(echo "scale=2; ${order_total} + ${subtotal}" | bc)
        
        # Generate order product ID
        local op_guid
        op_guid=$(get_short_uuid 12)
        local order_product_id="OP-${op_guid}"
        
        # Add comma separator if not first product
        if [[ "${first_product}" == true ]]; then
            first_product=false
        else
            products_json+=","
        fi
        
        # Build product JSON
        products_json+="
      {
        \"id\": \"${order_product_id}\",
        \"orderId\": \"${order_id}\",
        \"productId\": \"${product_id}\",
        \"productDescription\": \"${product_desc}\",
        \"quantity\": ${quantity},
        \"price\": ${price}
      }"
    done
    
    products_json+="
    ]"
    
    # Round order total
    order_total=$(round_price "${order_total}")
    
    # Build complete order JSON
    cat << EOF
  {
    "id": "${order_id}",
    "customerId": "${customer_id}",
    "date": "${order_date}",
    "deliveryAddress": "${delivery_address}",
    "total": ${order_total},
    "products": ${products_json}
  }
EOF
}

#------------------------------------------------------------------------------
# Function: generate_all_orders
# Description: Generates all orders and saves to file
#------------------------------------------------------------------------------
generate_all_orders() {
    local output_dir
    output_dir=$(dirname "${OUTPUT_PATH}")
    
    # Resolve to absolute path
    if [[ "${OUTPUT_PATH}" != /* ]]; then
        OUTPUT_PATH="${SCRIPT_DIR}/${OUTPUT_PATH}"
    fi
    output_dir=$(dirname "${OUTPUT_PATH}")
    
    log_verbose "Starting order generation process..."
    log_verbose "Parameters: OrderCount=${ORDER_COUNT}, MinProducts=${MIN_PRODUCTS}, MaxProducts=${MAX_PRODUCTS}"
    
    if [[ "${DRY_RUN}" == true ]]; then
        echo "What if: Would generate ${ORDER_COUNT} orders"
        echo "What if: Would save to ${OUTPUT_PATH}"
        echo "What if: Products per order: ${MIN_PRODUCTS}-${MAX_PRODUCTS}"
        echo ""
        echo "No changes were made. This was a simulation."
        return 0
    fi
    
    # Ensure output directory exists
    if [[ ! -d "${output_dir}" ]]; then
        log_verbose "Creating directory: ${output_dir}"
        mkdir -p "${output_dir}"
    fi
    
    # Start building JSON array
    local json_content="["
    local first_order=true
    
    # Generate orders with progress tracking
    for ((i=1; i<=ORDER_COUNT; i++)); do
        # Add comma separator if not first order
        if [[ "${first_order}" == true ]]; then
            first_order=false
        else
            json_content+=","
        fi
        
        # Generate order (no argument needed - IDs are UUID-based)
        json_content+=$(generate_order)
        
        # Show progress every 10 orders or on last order
        if [[ $((i % 10)) -eq 0 || "${i}" -eq "${ORDER_COUNT}" ]]; then
            local percent=$((i * 100 / ORDER_COUNT))
            printf "\rGenerating orders: %d/%d (%d%%)" "${i}" "${ORDER_COUNT}" "${percent}"
        fi
    done
    
    json_content+="
]"
    
    # Clear progress line
    echo ""
    
    # Write to file
    log_verbose "Writing orders to: ${OUTPUT_PATH}"
    echo "${json_content}" > "${OUTPUT_PATH}"
    
    # Get file size
    local file_size
    if [[ -f "${OUTPUT_PATH}" ]]; then
        file_size=$(du -k "${OUTPUT_PATH}" | cut -f1)
    else
        file_size=0
    fi
    
    # Display summary
    log_success "Successfully generated ${ORDER_COUNT} orders"
    log_info "Output file: ${OUTPUT_PATH}"
    log_info "File size: ${file_size} KB"
    log_info "Products per order: ${MIN_PRODUCTS}-${MAX_PRODUCTS}"
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    # Parse command-line arguments
    parse_arguments "$@"
    
    # Validate parameters
    validate_parameters
    
    # Check dependencies
    check_dependencies
    
    # Generate orders
    generate_all_orders
    
    log_verbose "Order generation process completed."
}

# Execute main function with all arguments
main "$@"
