#!/usr/bin/env bash

###############################################################################
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
# PARAMETERS
#     --count COUNT
#         The number of orders to generate. Default is 50.
#         Valid range: 1-10000
#
#     --output-path PATH
#         The path where the JSON file will be saved.
#         Default is '../infra/data/ordersBatch.json' relative to script location.
#
#     --min-products NUM
#         Minimum number of products per order. Default is 1.
#         Valid range: 1-20
#
#     --max-products NUM
#         Maximum number of products per order. Default is 6.
#         Valid range: 1-20
#
#     --force
#         Force execution without prompting for confirmation.
#
#     --verbose
#         Enable verbose output for debugging.
#
#     --help
#         Display this help message.
#
# EXAMPLES
#     ./Generate-Orders.sh
#         Generates 50 orders using default settings.
#
#     ./Generate-Orders.sh --count 100 --output-path "/tmp/orders.json"
#         Generates 100 orders and saves to a custom path.
#
#     ./Generate-Orders.sh --count 25 --min-products 2 --max-products 4
#         Generates 25 orders with 2-4 products each.
#
#     ./Generate-Orders.sh --verbose
#         Generates orders with detailed logging.
#
# NOTES
#     File Name      : Generate-Orders.sh
#     Author         : Azure Logic Apps Monitoring Team
#     Prerequisite   : Bash 4.0 or higher
#     Optional       : jq (for optimized JSON generation)
#     Copyright      : (c) 2025. All rights reserved.
#
# LINK
#     https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#
###############################################################################

# Bash strict mode: exit on error, undefined variable, or pipe failure
set -euo pipefail

###############################################################################
# Global Variables
###############################################################################

# Script directory for relative path resolution
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default parameters
ORDER_COUNT=50
OUTPUT_PATH="${SCRIPT_DIR}/../infra/data/ordersBatch.json"
MIN_PRODUCTS=1
MAX_PRODUCTS=6
VERBOSE=false
FORCE=false

# Product Catalog
# Each product has: ID, Description, BasePrice
# Format: "ID|Description|BasePrice"
declare -a PRODUCTS=(
    "PROD-1001|Wireless Mouse|25.99"
    "PROD-1002|Mechanical Keyboard|89.99"
    "PROD-1003|USB-C Hub|34.99"
    "PROD-2001|Noise Cancelling Headphones|149.99"
    "PROD-2002|Bluetooth Speaker|79.99"
    "PROD-3001|External SSD 1TB|119.99"
    "PROD-3002|Portable Charger|49.99"
    "PROD-4001|Webcam 1080p|69.99"
    "PROD-4002|Laptop Stand|39.99"
    "PROD-5001|Cable Organizer|12.99"
    "PROD-5002|Smartphone Holder|19.99"
    "PROD-6001|Monitor 27\" 4K|399.99"
    "PROD-6002|Monitor Arm|89.99"
    "PROD-7001|Ergonomic Chair|299.99"
    "PROD-7002|Standing Desk|499.99"
    "PROD-8001|USB Microphone|99.99"
    "PROD-8002|Ring Light|44.99"
    "PROD-9001|Graphics Tablet|199.99"
    "PROD-9002|Drawing Pen Set|29.99"
    "PROD-A001|Wireless Earbuds|129.99"
)

# Global delivery address pool
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

###############################################################################
# Color Output Functions
###############################################################################

# Color codes
readonly RED='\033[0;31m'
readonly YELLOW='\033[1;33m'
readonly GREEN='\033[0;32m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

print_error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}WARNING: $*${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$*${NC}"
}

print_info() {
    echo -e "${CYAN}$*${NC}"
}

print_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${CYAN}VERBOSE: $*${NC}" >&2
    fi
}

###############################################################################
# Error Handling
###############################################################################

# Trap errors and cleanup
cleanup() {
    local exit_code=$?
    if [[ ${exit_code} -ne 0 ]]; then
        print_error "Script failed with exit code ${exit_code}"
    fi
    print_verbose "Cleanup completed."
}

trap cleanup EXIT

###############################################################################
# Helper Functions
###############################################################################

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generates sample order data for testing Azure Logic Apps monitoring.

OPTIONS:
    --count COUNT           Number of orders to generate (default: 50, range: 1-10000)
    --output-path PATH      Output file path (default: ../infra/data/ordersBatch.json)
    --min-products NUM      Minimum products per order (default: 1, range: 1-20)
    --max-products NUM      Maximum products per order (default: 6, range: 1-20)
    --force                 Force execution without prompting
    --verbose               Enable verbose output
    --help                  Display this help message

EXAMPLES:
    $(basename "$0")
    $(basename "$0") --count 100 --output-path "/tmp/orders.json"
    $(basename "$0") --count 25 --min-products 2 --max-products 4 --verbose

For more information, see the header documentation in this script.
EOF
}

validate_range() {
    local value=$1
    local min=$2
    local max=$3
    local param_name=$4
    
    if [[ ${value} -lt ${min} ]] || [[ ${value} -gt ${max} ]]; then
        print_error "${param_name} must be between ${min} and ${max} (got: ${value})"
        exit 1
    fi
}

# Generate a random number between min and max (inclusive)
random_range() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

# Generate a random floating point number between min and max
random_float() {
    local min=$1
    local max=$2
    local decimals=$3
    
    # Generate random integer in range and convert to float
    local range_int=$((max * 10**decimals - min * 10**decimals))
    local random_int=$((RANDOM % range_int + min * 10**decimals))
    
    # Use awk for floating point division
    awk "BEGIN {printf \"%.${decimals}f\", ${random_int} / (10^${decimals})}"
}

# Generate UUID-like identifier
generate_guid() {
    local length=$1
    # Generate random hex string
    if command -v openssl &> /dev/null; then
        openssl rand -hex $((length / 2)) | tr '[:lower:]' '[:upper:]' | cut -c1-${length}
    else
        # Fallback to /dev/urandom
        tr -dc 'A-F0-9' < /dev/urandom | head -c${length}
    fi
}

# Get random date between 2024-01-01 and 2025-12-31
get_random_date() {
    # Unix timestamps for the date range
    local start_date=$(date -d "2024-01-01 00:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "2024-01-01 00:00:00" +%s)
    local end_date=$(date -d "2025-12-31 23:59:59" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "2025-12-31 23:59:59" +%s)
    
    # Generate random timestamp
    local random_timestamp=$((RANDOM % (end_date - start_date) + start_date))
    
    # Convert to ISO 8601 format
    date -u -d "@${random_timestamp}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -r "${random_timestamp}" +"%Y-%m-%dT%H:%M:%SZ"
}

# Escape string for JSON
json_escape() {
    local str="$1"
    # Replace special characters with JSON escape sequences
    str="${str//\\/\\\\}"  # Backslash
    str="${str//\"/\\\"}"  # Double quote
    str="${str//$'\n'/\\n}" # Newline
    str="${str//$'\r'/\\r}" # Carriage return
    str="${str//$'\t'/\\t}" # Tab
    echo "${str}"
}

###############################################################################
# Order Generation Functions
###############################################################################

# Shuffle array and return first N elements
get_random_products() {
    local count=$1
    local -a shuffled=("${PRODUCTS[@]}")
    
    # Fisher-Yates shuffle
    for ((i=${#shuffled[@]}-1; i>0; i--)); do
        local j=$((RANDOM % (i + 1)))
        local tmp="${shuffled[i]}"
        shuffled[i]="${shuffled[j]}"
        shuffled[j]="${tmp}"
    done
    
    # Return first N elements
    for ((i=0; i<count && i<${#shuffled[@]}; i++)); do
        echo "${shuffled[i]}"
    done
}

# Generate a single order
generate_order() {
    local order_number=$1
    local min_products=$2
    local max_products=$3
    
    # Generate unique IDs
    local order_id="ORD-$(generate_guid 12)"
    local customer_id="CUST-$(generate_guid 8)"
    
    # Get random order date
    local order_date=$(get_random_date)
    
    # Get random delivery address
    local address_index=$((RANDOM % ${#ADDRESSES[@]}))
    local delivery_address="${ADDRESSES[${address_index}]}"
    
    # Determine number of products for this order
    local product_count=$(random_range ${min_products} ${max_products})
    
    # Get random products
    local -a selected_products
    mapfile -t selected_products < <(get_random_products ${product_count})
    
    # Generate order products and calculate total
    local order_products_json=""
    local order_total=0
    local is_first=true
    
    for product_line in "${selected_products[@]}"; do
        IFS='|' read -r product_id product_desc base_price <<< "${product_line}"
        
        # Generate random quantity (1-5)
        local quantity=$(random_range 1 5)
        
        # Apply price variation (±20%)
        local price_variation=$(random_float 0.8 1.2 2)
        local price=$(awk "BEGIN {printf \"%.2f\", ${base_price} * ${price_variation}}")
        
        # Calculate subtotal
        local subtotal=$(awk "BEGIN {printf \"%.2f\", ${price} * ${quantity}}")
        
        # Add to order total
        order_total=$(awk "BEGIN {printf \"%.2f\", ${order_total} + ${subtotal}}")
        
        # Generate order product ID
        local order_product_id="OP-$(generate_guid 12)"
        
        # Build JSON for this product (add comma separator after first item)
        if [[ "${is_first}" == "true" ]]; then
            is_first=false
        else
            order_products_json+=","
        fi
        
        # Escape description for JSON
        local escaped_desc=$(json_escape "${product_desc}")
        
        order_products_json+=$(cat << PRODUCT_JSON

      {
        "id": "${order_product_id}",
        "orderId": "${order_id}",
        "productId": "${product_id}",
        "productDescription": "${escaped_desc}",
        "quantity": ${quantity},
        "price": ${price}
      }
PRODUCT_JSON
)
    done
    
    # Build complete order JSON
    local escaped_address=$(json_escape "${delivery_address}")
    
    cat << ORDER_JSON
  {
    "id": "${order_id}",
    "customerId": "${customer_id}",
    "date": "${order_date}",
    "deliveryAddress": "${escaped_address}",
    "total": ${order_total},
    "products": [${order_products_json}
    ]
  }
ORDER_JSON
}

###############################################################################
# Main Script
###############################################################################

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --count)
                ORDER_COUNT="$2"
                shift 2
                ;;
            --output-path)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            --min-products)
                MIN_PRODUCTS="$2"
                shift 2
                ;;
            --max-products)
                MAX_PRODUCTS="$2"
                shift 2
                ;;
            --force)
                FORCE=true
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main() {
    parse_arguments "$@"
    
    print_verbose "Starting order generation process..."
    print_verbose "Parameters: OrderCount=${ORDER_COUNT}, MinProducts=${MIN_PRODUCTS}, MaxProducts=${MAX_PRODUCTS}"
    
    # Validate parameters
    validate_range "${ORDER_COUNT}" 1 10000 "OrderCount"
    validate_range "${MIN_PRODUCTS}" 1 20 "MinProducts"
    validate_range "${MAX_PRODUCTS}" 1 20 "MaxProducts"
    
    if [[ ${MIN_PRODUCTS} -gt ${MAX_PRODUCTS} ]]; then
        print_error "MinProducts (${MIN_PRODUCTS}) cannot be greater than MaxProducts (${MAX_PRODUCTS})"
        exit 1
    fi
    
    # Ensure output directory exists
    local output_dir=$(dirname "${OUTPUT_PATH}")
    if [[ ! -d "${output_dir}" ]]; then
        print_verbose "Creating directory: ${output_dir}"
        mkdir -p "${output_dir}"
    fi
    
    # Generate orders
    print_verbose "Generating ${ORDER_COUNT} orders..."
    
    local orders_json="["
    local progress_interval=$((ORDER_COUNT / 10))
    if [[ ${progress_interval} -lt 1 ]]; then
        progress_interval=1
    fi
    
    for ((i=1; i<=ORDER_COUNT; i++)); do
        # Add comma separator between orders
        if [[ ${i} -gt 1 ]]; then
            orders_json+=","
        fi
        
        # Generate order and append to JSON
        orders_json+=$(generate_order ${i} ${MIN_PRODUCTS} ${MAX_PRODUCTS})
        
        # Show progress
        if [[ $((i % progress_interval)) -eq 0 ]] || [[ ${i} -eq ${ORDER_COUNT} ]]; then
            local percent=$((i * 100 / ORDER_COUNT))
            print_verbose "Progress: ${i}/${ORDER_COUNT} orders (${percent}%)"
        fi
    done
    
    orders_json+=$'\n'"]"
    
    # Write to file
    print_verbose "Exporting ${ORDER_COUNT} orders to JSON..."
    echo "${orders_json}" > "${OUTPUT_PATH}"
    
    # Get file size
    local file_size
    if command -v stat &> /dev/null; then
        # Linux
        file_size=$(stat -c%s "${OUTPUT_PATH}" 2>/dev/null || stat -f%z "${OUTPUT_PATH}")
    else
        # Fallback
        file_size=$(wc -c < "${OUTPUT_PATH}")
    fi
    local file_size_kb=$(awk "BEGIN {printf \"%.2f\", ${file_size} / 1024}")
    
    # Display summary
    print_success "✓ Successfully generated ${ORDER_COUNT} orders"
    print_info "  Output file: ${OUTPUT_PATH}"
    print_info "  File size: ${file_size_kb} KB"
    print_info "  Products per order: ${MIN_PRODUCTS}-${MAX_PRODUCTS}"
    
    print_verbose "Order generation process completed."
}

# Execute main function with all arguments
main "$@"
