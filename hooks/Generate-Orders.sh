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
# VERSION
#     2.0.1
#
# LAST MODIFIED
#     2026-01-06
#
# PARAMETERS
#     --count COUNT
#         The number of orders to generate. Default is 2000.
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
#         Generates 2000 orders using default settings.
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
#     Author         : Evilazaro | Principal Cloud Solution Architect | Microsoft
#     Prerequisite   : Bash 4.0 or higher
#     Optional       : jq (for optimized JSON generation)
#     
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
ORDER_COUNT=2000
OUTPUT_PATH="${SCRIPT_DIR}/../infra/data/ordersBatch.json"
MIN_PRODUCTS=1
MAX_PRODUCTS=6
VERBOSE=false
FORCE=false
DRY_RUN=false

# Product Catalog
# Each product has: ID, Description, BasePrice
# Format: "ID|Description|BasePrice"
#
# Product Catalog Data Structure
# ==============================
# Structure: Array of product entries in pipe-delimited format
#     Format: "ProductID|Description|BasePrice"
#
# Fields:
#     - ProductID: Unique identifier (PROD-XXXX format)
#     - Description: Human-readable product name
#     - BasePrice: Starting price in USD (subject to ±20% variation)
#
# Price Variation Logic:
#     - During order generation, each product price varies by ±20%
#     - Variation range: 0.8x to 1.2x of base price
#     - Simulates: promotions, discounts, market fluctuations, dynamic pricing
#
# Product Categories (20 total):
#     - Peripherals: Mouse, Keyboard, Hub
#     - Audio: Headphones, Speaker, Microphone, Earbuds
#     - Storage: External SSD, Portable Charger
#     - Video: Webcam, Ring Light
#     - Furniture: Laptop Stand, Monitor Arm, Chair, Desk
#     - Organization: Cable Organizer, Smartphone Holder
#     - Displays: 4K Monitor (27")
#     - Creative: Graphics Tablet, Drawing Pen Set
#
# Usage: Products are randomly selected using Fisher-Yates shuffle
#        to ensure uniform distribution and no duplicates per order
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

# Global Delivery Address Pool
# =============================
# Contains diverse addresses from major cities worldwide to simulate
# international e-commerce operations and realistic order distribution.
#
# Coverage:
#     - United States: 5 locations (NY, SF, Mountain View, Redmond, Seattle)
#     - United Kingdom: 2 locations (Baker Street London, Downing Street)
#     - Germany: 2 locations (Berlin locations)
#     - Europe: France, Spain, Italy
#     - Asia-Pacific: Japan, China, South Korea, Australia (2 locations)
#     - Americas: Canada, Brazil
#
# Total Addresses: 20 locations across 15 countries
#
# Selection Logic:
#     - Addresses are randomly selected during order generation
#     - Uses modulo arithmetic to ensure even distribution
#     - Each order gets exactly one delivery address
#     - Simulates global e-commerce reach
#
# Special Characters:
#     - Addresses may contain quotes (") which are JSON-escaped
#     - International characters handled via json_escape function
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

# ANSI color codes for terminal output formatting
# These codes enable colored text output for better visual feedback
# Compatible with most modern terminals (Linux, macOS, Windows 10+)
readonly RED='\033[0;31m'      # Error messages
readonly YELLOW='\033[1;33m'   # Warning messages
readonly GREEN='\033[0;32m'    # Success messages
readonly CYAN='\033[0;36m'     # Info and verbose messages
readonly NC='\033[0m'          # No Color (reset)

###############################################################################
# FUNCTION: print_error
#
# SYNOPSIS
#     Prints an error message to stderr in red color.
#
# DESCRIPTION
#     Outputs formatted error messages to standard error stream with red
#     color highlighting for immediate visibility. All error messages are
#     prefixed with "ERROR:" for consistent formatting.
#
# PARAMETERS
#     $* - Error message text (accepts multiple arguments)
#
# OUTPUTS
#     Formatted error message to stderr
#
# EXAMPLES
#     print_error "Failed to create directory"
#     print_error "Invalid parameter value: ${value}"
###############################################################################
print_error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
}

###############################################################################
# FUNCTION: print_warning
#
# SYNOPSIS
#     Prints a warning message to stderr in yellow color.
#
# DESCRIPTION
#     Outputs formatted warning messages to standard error stream with yellow
#     color highlighting. Warnings indicate potential issues that don't prevent
#     execution but require user attention.
#
# PARAMETERS
#     $* - Warning message text (accepts multiple arguments)
#
# OUTPUTS
#     Formatted warning message to stderr
#
# EXAMPLES
#     print_warning "File already exists, will be overwritten"
#     print_warning "Using default value for missing parameter"
###############################################################################
print_warning() {
    echo -e "${YELLOW}WARNING: $*${NC}" >&2
}

###############################################################################
# FUNCTION: print_success
#
# SYNOPSIS
#     Prints a success message to stdout in green color.
#
# DESCRIPTION
#     Outputs formatted success messages with green color highlighting to
#     indicate successful completion of operations or validation.
#
# PARAMETERS
#     $* - Success message text (accepts multiple arguments)
#
# OUTPUTS
#     Formatted success message to stdout
#
# EXAMPLES
#     print_success "✓ Successfully generated 50 orders"
#     print_success "✓ File saved successfully"
###############################################################################
print_success() {
    echo -e "${GREEN}$*${NC}"
}

###############################################################################
# FUNCTION: print_info
#
# SYNOPSIS
#     Prints an informational message to stdout in cyan color.
#
# DESCRIPTION
#     Outputs formatted informational messages with cyan color highlighting.
#     Used for general information, status updates, and non-critical notices.
#
# PARAMETERS
#     $* - Info message text (accepts multiple arguments)
#
# OUTPUTS
#     Formatted informational message to stdout
#
# EXAMPLES
#     print_info "Processing order batch..."
#     print_info "Output file: ${OUTPUT_PATH}"
###############################################################################
print_info() {
    echo -e "${CYAN}$*${NC}"
}

###############################################################################
# FUNCTION: print_verbose
#
# SYNOPSIS
#     Prints verbose debug messages when verbose mode is enabled.
#
# DESCRIPTION
#     Conditionally outputs detailed diagnostic messages to stderr when the
#     VERBOSE flag is set to true. Used for debugging and detailed progress
#     tracking without cluttering normal output.
#
# PARAMETERS
#     $* - Verbose message text (accepts multiple arguments)
#
# OUTPUTS
#     Formatted verbose message to stderr (only when VERBOSE=true)
#
# EXAMPLES
#     print_verbose "Validating parameter ranges..."
#     print_verbose "Generated GUID: ${guid}"
###############################################################################
print_verbose() {
    if [[ "${VERBOSE}" == "true" ]]; then
        echo -e "${CYAN}VERBOSE: $*${NC}" >&2
    fi
}

###############################################################################
# Error Handling and Cleanup
###############################################################################

###############################################################################
# FUNCTION: cleanup
#
# SYNOPSIS
#     Cleanup handler executed on script exit.
#
# DESCRIPTION
#     Trap handler that executes when the script exits (normally or due to
#     error). Provides cleanup operations and reports exit status. This
#     function is automatically called by the EXIT trap.
#
# PARAMETERS
#     None (reads $? for exit code)
#
# OUTPUTS
#     Error message if exit code is non-zero
#     Verbose cleanup confirmation message
#
# NOTES
#     - Automatically triggered by EXIT trap
#     - Non-zero exit codes indicate errors
#     - Verbose output controlled by VERBOSE flag
#
# EXAMPLES
#     trap cleanup EXIT  # Already set in script
###############################################################################
cleanup() {
    local exit_code=$?
    
    # Report abnormal termination
    if [[ ${exit_code} -ne 0 ]]; then
        print_error "Script failed with exit code ${exit_code}"
        print_verbose "Check error messages above for details"
    fi
    
    print_verbose "Cleanup completed."
}

# Register cleanup handler for script exit
# Handles both normal termination and errors
trap cleanup EXIT

###############################################################################
# Helper Functions
###############################################################################

###############################################################################
# FUNCTION: show_help
#
# SYNOPSIS
#     Displays comprehensive usage information and examples.
#
# DESCRIPTION
#     Outputs detailed help text including script purpose, all available
#     command-line options with descriptions, valid ranges, and practical
#     usage examples. Designed to match PowerShell's Get-Help output style.
#
# PARAMETERS
#     None
#
# OUTPUTS
#     Multi-line help text to stdout
#
# EXAMPLES
#     show_help
#     ./Generate-Orders.sh --help
###############################################################################
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Generates sample order data for testing Azure Logic Apps monitoring.

OPTIONS:
    --count COUNT           Number of orders to generate (default: 2000, range: 1-10000)
    --output-path PATH      Output file path (default: ../infra/data/ordersBatch.json)
    --min-products NUM      Minimum products per order (default: 1, range: 1-20)
    --max-products NUM      Maximum products per order (default: 6, range: 1-20)
    --force                 Force execution without prompting
    --dry-run               Preview what would be generated without making changes
    --verbose               Enable verbose output
    --help                  Display this help message

EXAMPLES:
    $(basename "$0")
        Generate 2000 orders with default settings

    $(basename "$0") --count 100 --output-path "/tmp/orders.json"
        Generate 100 orders to custom location

    $(basename "$0") --count 25 --min-products 2 --max-products 4 --verbose
        Generate 25 orders with 2-4 products each, verbose output

    $(basename "$0") --dry-run
        Preview generation without creating files

For more information, see the header documentation in this script.
EOF
}

###############################################################################
# FUNCTION: validate_range
#
# SYNOPSIS
#     Validates that a numeric value falls within specified range.
#
# DESCRIPTION
#     Performs range validation on numeric parameters to ensure they meet
#     specified constraints. Exits with error code 1 if validation fails,
#     providing clear error messages with expected range and actual value.
#
# PARAMETERS
#     $1 - value        The numeric value to validate
#     $2 - min          Minimum allowed value (inclusive)
#     $3 - max          Maximum allowed value (inclusive)
#     $4 - param_name   Parameter name for error messages
#
# OUTPUTS
#     Error message and exits if validation fails
#
# EXAMPLES
#     validate_range "${ORDER_COUNT}" 1 10000 "OrderCount"
#     validate_range "${MIN_PRODUCTS}" 1 20 "MinProducts"
###############################################################################
validate_range() {
    local value=$1
    local min=$2
    local max=$3
    local param_name=$4
    
    # Check if value is within valid range (inclusive)
    if [[ ${value} -lt ${min} ]] || [[ ${value} -gt ${max} ]]; then
        print_error "${param_name} must be between ${min} and ${max}. Got: ${value}"
        print_error "Please provide a value within the valid range and try again."
        exit 1
    fi
    
    print_verbose "${param_name} validation passed: ${value} is within [${min}, ${max}]"
}

###############################################################################
# FUNCTION: random_range
#
# SYNOPSIS
#     Generates a random integer within specified range.
#
# DESCRIPTION
#     Produces a uniformly distributed random integer between min and max
#     (inclusive). Uses Bash's $RANDOM built-in variable with modulo
#     arithmetic to ensure even distribution across the range.
#
# PARAMETERS
#     $1 - min   Minimum value (inclusive)
#     $2 - max   Maximum value (inclusive)
#
# OUTPUTS
#     Random integer to stdout
#
# NOTES
#     - Range is inclusive on both ends: [min, max]
#     - Uses $RANDOM which provides values 0-32767
#     - Suitable for most order generation needs
#
# EXAMPLES
#     product_count=$(random_range 1 6)
#     quantity=$(random_range 1 10)
###############################################################################
random_range() {
    local min=$1
    local max=$2
    
    # Calculate random value using modulo arithmetic
    # Formula: RANDOM % (max - min + 1) + min
    # +1 makes the range inclusive on both ends
    echo $((RANDOM % (max - min + 1) + min))
}

###############################################################################
# FUNCTION: random_float
#
# SYNOPSIS
#     Generates a random floating-point number within specified range.
#
# DESCRIPTION
#     Produces a random decimal number between min and max with specified
#     decimal precision. Implements floating-point randomization by generating
#     a random integer in the scaled range and dividing back to float.
#
# PARAMETERS
#     $1 - min       Minimum value
#     $2 - max       Maximum value
#     $3 - decimals  Number of decimal places
#
# OUTPUTS
#     Random floating-point number to stdout
#
# NOTES
#     - Used for price variations (±20% of base price)
#     - Requires awk for floating-point arithmetic
#     - Output formatted with specified decimal places
#
# EXAMPLES
#     variation=$(random_float 0.8 1.2 2)  # Returns 0.80 to 1.20
#     price=$(random_float 10.00 50.00 2)  # Returns 10.00 to 50.00
###############################################################################
random_float() {
    local min=$1
    local max=$2
    local decimals=$3
    
    # Use awk for all floating-point arithmetic since bash only supports integers
    # Generate a random number using $RANDOM (0-32767) scaled to the desired range
    awk -v min="$min" -v max="$max" -v decimals="$decimals" -v seed="$RANDOM" \
        'BEGIN {
            # Scale RANDOM (0-32767) to range [0,1), then to [min,max)
            range = max - min
            value = min + (seed / 32768.0) * range
            # Build format string using sprintf for dynamic decimal precision
            fmt = sprintf("%%.%df", decimals)
            printf fmt, value
        }'
}

###############################################################################
# FUNCTION: generate_guid
#
# SYNOPSIS
#     Generates a UUID-like hexadecimal identifier.
#
# DESCRIPTION
#     Creates a random hexadecimal string of specified length for use as
#     unique identifiers (order IDs, customer IDs). Prefers OpenSSL for
#     cryptographic randomness but falls back to /dev/urandom if unavailable.
#
# PARAMETERS
#     $1 - length   Length of the hex string to generate
#
# OUTPUTS
#     Uppercase hexadecimal string to stdout
#
# NOTES
#     - OpenSSL method provides cryptographic randomness
#     - Fallback uses /dev/urandom (available on Unix systems)
#     - Output is always uppercase (A-F, 0-9)
#     - Used for: orderId (12 chars), customerId (8 chars)
#
# EXAMPLES
#     order_id="ORD-$(generate_guid 12)"      # ORD-A1B2C3D4E5F6
#     customer_id="CUST-$(generate_guid 8)"   # CUST-12345678
###############################################################################
generate_guid() {
    local length=$1
    
    # Prefer OpenSSL for cryptographic quality random data
    if command -v openssl &> /dev/null; then
        # Generate random bytes and convert to hex
        # Cut to exact length needed
        openssl rand -hex $((length / 2)) | tr '[:lower:]' '[:upper:]' | cut -c1-${length}
    else
        # Fallback to /dev/urandom if OpenSSL not available
        # Filter to only hexadecimal characters
        print_verbose "OpenSSL not found, using /dev/urandom for GUID generation"
        tr -dc 'A-F0-9' < /dev/urandom | head -c${length}
    fi
}

###############################################################################
# FUNCTION: get_random_date
#
# SYNOPSIS
#     Generates a random date between 2024-01-01 and 2025-12-31.
#
# DESCRIPTION
#     Creates a random timestamp within the defined date range and formats
#     it in ISO 8601 format (yyyy-MM-ddTHH:mm:ssZ). Uses Unix epoch
#     timestamps for calculation with platform-specific date command syntax
#     for Linux and macOS compatibility.
#
# PARAMETERS
#     None
#
# OUTPUTS
#     ISO 8601 formatted timestamp to stdout
#
# NOTES
#     - Date range: 2024-01-01 00:00:00 to 2025-12-31 23:59:59 UTC
#     - Two-stage randomization: random day + random second
#     - Ensures even distribution across entire range
#     - Handles both GNU date (Linux) and BSD date (macOS)
#     - Output always in UTC timezone (Z suffix)
#
# EXAMPLES
#     order_date=$(get_random_date)
#     # Returns: "2024-06-15T14:23:45Z"
###############################################################################
get_random_date() {
    # Define date range using Unix timestamps
    # Try GNU date format first (Linux), fall back to BSD date (macOS)
    local start_date=$(date -d "2024-01-01 00:00:00" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "2024-01-01 00:00:00" +%s)
    local end_date=$(date -d "2025-12-31 23:59:59" +%s 2>/dev/null || date -j -f "%Y-%m-%d %H:%M:%S" "2025-12-31 23:59:59" +%s)
    
    # Calculate total time span in seconds
    local time_span=$((end_date - start_date))
    print_verbose "Date range span: ${time_span} seconds (~$((time_span / 86400)) days)"
    
    # Generate random timestamp within range
    local random_timestamp=$((RANDOM % time_span + start_date))
    
    # Convert Unix timestamp to ISO 8601 format
    # Try GNU date format first, fall back to BSD date
    date -u -d "@${random_timestamp}" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -r "${random_timestamp}" +"%Y-%m-%dT%H:%M:%SZ"
}

###############################################################################
# FUNCTION: json_escape
#
# SYNOPSIS
#     Escapes special characters in strings for JSON output.
#
# DESCRIPTION
#     Sanitizes strings by replacing special characters with their JSON
#     escape sequences. Handles backslashes, quotes, newlines, carriage
#     returns, and tabs to ensure valid JSON output.
#
# PARAMETERS
#     $1 - str   String to escape
#
# OUTPUTS
#     JSON-safe escaped string to stdout
#
# NOTES
#     - Order of replacements matters (backslash must be first)
#     - Handles multi-line strings (\n, \r)
#     - Essential for addresses and product descriptions
#     - Prevents JSON parsing errors
#
# EXAMPLES
#     escaped=$(json_escape 'He said "Hello"')
#     # Returns: He said \"Hello\"
###############################################################################
json_escape() {
    local str="$1"
    
    # Replace special characters with JSON escape sequences
    # Order matters: escape backslashes first to avoid double-escaping
    str="${str//\\/\\\\}"     # Backslash: \ -> \\
    str="${str//\"/\\\"}"     # Double quote: " -> \"
    str="${str//$'\n'/\\n}"  # Newline: <LF> -> \n
    str="${str//$'\r'/\\r}"  # Carriage return: <CR> -> \r
    str="${str//$'\t'/\\t}"  # Tab: <TAB> -> \t
    
    echo "${str}"
}

###############################################################################
# Order Generation Functions
###############################################################################

###############################################################################
# FUNCTION: get_random_products
#
# SYNOPSIS
#     Randomly selects N unique products from the product catalog.
#
# DESCRIPTION
#     Implements Fisher-Yates shuffle algorithm to randomly select a
#     specified number of unique products from the global PRODUCTS array.
#     Ensures no duplicate products within a single order while maintaining
#     uniform distribution probability.
#
# PARAMETERS
#     $1 - count   Number of products to select
#
# OUTPUTS
#     Selected product lines to stdout (one per line)
#     Format: "PROD-ID|Description|BasePrice"
#
# ALGORITHM
#     1. Create local copy of PRODUCTS array
#     2. Apply Fisher-Yates shuffle for O(n) randomization
#     3. Return first N elements from shuffled array
#     4. Ensures uniform distribution of all permutations
#
# NOTES
#     - Fisher-Yates shuffle provides unbiased randomization
#     - Complexity: O(n) time, O(n) space
#     - Handles edge cases: count > array size
#     - No duplicate products in output
#
# EXAMPLES
#     mapfile -t products < <(get_random_products 3)
#     # Returns 3 random unique products
###############################################################################
get_random_products() {
    local count=$1
    
    # Create local copy of products array to avoid modifying global
    local -a shuffled=("${PRODUCTS[@]}")
    
    print_verbose "Shuffling product catalog (${#shuffled[@]} products) to select ${count} items"
    
    # Fisher-Yates shuffle algorithm
    # Iterates backwards, swapping each element with a random earlier position
    # This ensures uniform distribution of all possible permutations
    for ((i=${#shuffled[@]}-1; i>0; i--)); do
        # Select random index from 0 to i (inclusive)
        local j=$((RANDOM % (i + 1)))
        
        # Swap elements at positions i and j
        local tmp="${shuffled[i]}"
        shuffled[i]="${shuffled[j]}"
        shuffled[j]="${tmp}"
    done
    
    # Return first N elements from shuffled array
    # Using && to handle case where count > array size
    for ((i=0; i<count && i<${#shuffled[@]}; i++)); do
        echo "${shuffled[i]}"
    done
    
    print_verbose "Selected ${count} unique products from catalog"
}

###############################################################################
# FUNCTION: generate_order
#
# SYNOPSIS
#     Generates a complete order with random products and customer data.
#
# DESCRIPTION
#     Creates a comprehensive order object with unique identifiers, random
#     products, calculated pricing, and delivery information. Applies price
#     variations, quantity randomization, and formats output as valid JSON.
#
# PARAMETERS
#     $1 - order_number   Sequential order number (not used in output)
#     $2 - min_products   Minimum products in order
#     $3 - max_products   Maximum products in order
#
# OUTPUTS
#     Complete order JSON object to stdout
#
# DATA STRUCTURE
#     {
#       "orderId": "ORD-XXXXXXXXXXXX",
#       "customerId": "CUST-XXXXXXXX",
#       "orderDate": "YYYY-MM-DDTHH:MM:SSZ",
#       "totalAmount": 999.99,
#       "deliveryAddress": "address string",
#       "products": [
#         {
#           "productId": "PROD-XXXX",
#           "description": "Product Name",
#           "quantity": N,
#           "unitPrice": 99.99,
#           "totalPrice": 999.99
#         }
#       ]
#     }
#
# PRICING LOGIC
#     - Base price from product catalog
#     - Apply ±20% variation (0.8 to 1.2 multiplier)
#     - Random quantity: 1-10 units
#     - Line total: unitPrice × quantity
#     - Order total: sum of all line totals
#
# NOTES
#     - Generates unique order and customer IDs using GUIDs
#     - Random date within 2024-2025 range
#     - Random delivery address from global pool
#     - Products are unique within each order
#     - All prices formatted to 2 decimal places
#
# EXAMPLES
#     generate_order 1 2 4
#     # Generates order with 2-4 products
###############################################################################
generate_order() {
    local order_number=$1
    local min_products=$2
    local max_products=$3
    
    print_verbose "Generating order #${order_number} with ${min_products}-${max_products} products"
    
    # Generate unique identifiers using GUID-based approach
    # Format: ORD-XXXXXXXXXXXX (12 hex chars) for orders
    #         CUST-XXXXXXXX (8 hex chars) for customers
    local order_id="ORD-$(generate_guid 12)"
    local customer_id="CUST-$(generate_guid 8)"
    print_verbose "Generated IDs: ${order_id}, ${customer_id}"
    
    # Generate random order date within defined range (2024-2025)
    local order_date=$(get_random_date)
    print_verbose "Order date: ${order_date}"
    
    # Select random delivery address from global address pool
    # Using modulo to ensure index is within array bounds
    local address_index=$((RANDOM % ${#ADDRESSES[@]}))
    local delivery_address="${ADDRESSES[${address_index}]}"
    print_verbose "Delivery address: ${delivery_address}"
    
    # Determine number of products for this order within specified range
    # Range is inclusive on both ends
    local product_count=$(random_range ${min_products} ${max_products})
    print_verbose "Selecting ${product_count} products for order"
    
    # Get random unique products using Fisher-Yates shuffle
    # mapfile reads output into array, one line per element
    local -a selected_products
    mapfile -t selected_products < <(get_random_products ${product_count})
    
    # Initialize order line items and running total
    local order_products_json=""
    local order_total=0
    local is_first=true  # Flag for JSON comma management
    
    print_verbose "Processing ${#selected_products[@]} products..."
    
    # Process each selected product to create order line items
    for product_line in "${selected_products[@]}"; do
        # Parse product data: ID|Description|BasePrice
        # IFS temporarily set to pipe character for field splitting
        IFS='|' read -r product_id product_desc base_price <<< "${product_line}"
        
        # Apply random price variation (±20% of base price)
        # Simulates promotions, discounts, and market fluctuations
        # Range: 0.8 to 1.2 (80% to 120% of base price)
        local variation=$(random_float 0.8 1.2 2)
        local actual_price=$(awk "BEGIN {printf \"%.2f\", ${base_price} * ${variation}}")
        
        # Generate random quantity (1-10 units)
        # Simulates realistic order quantities
        local quantity=$(random_range 1 10)
        
        # Calculate line total (unit price × quantity)
        # All monetary values formatted to 2 decimal places
        local line_total=$(awk "BEGIN {printf \"%.2f\", ${actual_price} * ${quantity}}")
        
        # Accumulate order total
        # Using awk for accurate floating-point arithmetic
        order_total=$(awk "BEGIN {printf \"%.2f\", ${order_total} + ${line_total}}")
        
        print_verbose "  Product: ${product_id} - ${product_desc}: ${quantity} × \$${actual_price} = \$${line_total}"
        
        
        # Build JSON for this product line item
        # Handle comma placement for valid JSON array syntax
        if [[ "${is_first}" == "true" ]]; then
            is_first=false
        else
            order_products_json+=","  # Add comma before all items except first
        fi
        
        # Append product JSON with proper indentation
        # Note: No escaping needed for product_desc as it comes from controlled catalog
        order_products_json+=$(cat << PRODUCT_JSON

      {
        "productId": "${product_id}",
        "description": "${product_desc}",
        "quantity": ${quantity},
        "unitPrice": ${actual_price},
        "totalPrice": ${line_total}
      }
PRODUCT_JSON
)
    done
    
    print_verbose "Order total: \$${order_total} (${#selected_products[@]} products)"
    
    # Escape delivery address for safe JSON embedding
    # Handles special characters like quotes, newlines, etc.
    local escaped_address=$(json_escape "${delivery_address}")
    
    # Build complete order JSON object
    # Format follows Azure Logic Apps expected schema
    cat << ORDER_JSON
  {
    "orderId": "${order_id}",
    "customerId": "${customer_id}",
    "orderDate": "${order_date}",
    "totalAmount": ${order_total},
    "deliveryAddress": "${escaped_address}",
    "products": [${order_products_json}
    ]
  }
ORDER_JSON
}

###############################################################################
# Main Script Execution
###############################################################################

###############################################################################
# FUNCTION: parse_arguments
#
# SYNOPSIS
#     Parses and validates command-line arguments.
#
# DESCRIPTION
#     Processes all command-line arguments and sets corresponding global
#     variables. Handles both long-form GNU-style options (--option) and
#     displays help for unknown options. Implements parameter validation
#     and provides verbose logging of parsed values.
#
# PARAMETERS
#     $@ - All command-line arguments passed to script
#
# OUTPUTS
#     Updates global variables: ORDER_COUNT, OUTPUT_PATH, MIN_PRODUCTS,
#     MAX_PRODUCTS, FORCE, VERBOSE, DRY_RUN
#
# OPTIONS
#     --count COUNT           Set order count (1-10000)
#     --output-path PATH      Set output file path
#     --min-products NUM      Set minimum products per order (1-20)
#     --max-products NUM      Set maximum products per order (1-20)
#     --force                 Force execution without prompts
#     --dry-run               Preview without making changes
#     --verbose               Enable verbose output
#     --help                  Display help and exit
#
# NOTES
#     - Uses shift to consume processed arguments
#     - Exits with code 0 for --help
#     - Exits with code 1 for unknown options
#     - Verbose logging enabled with --verbose flag
#
# EXAMPLES
#     parse_arguments --count 100 --verbose
#     parse_arguments --help
###############################################################################
parse_arguments() {
    print_verbose "Parsing command-line arguments..."
    
    # Process all arguments using shift to consume them
    while [[ $# -gt 0 ]]; do
        case $1 in
            --count)
                ORDER_COUNT="$2"
                print_verbose "  ORDER_COUNT set to: ${ORDER_COUNT}"
                shift 2
                ;;
            --output-path)
                OUTPUT_PATH="$2"
                print_verbose "  OUTPUT_PATH set to: ${OUTPUT_PATH}"
                shift 2
                ;;
            --min-products)
                MIN_PRODUCTS="$2"
                print_verbose "  MIN_PRODUCTS set to: ${MIN_PRODUCTS}"
                shift 2
                ;;
            --max-products)
                MAX_PRODUCTS="$2"
                print_verbose "  MAX_PRODUCTS set to: ${MAX_PRODUCTS}"
                shift 2
                ;;
            --force)
                FORCE=true
                print_verbose "  FORCE mode enabled"
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                print_verbose "  DRY-RUN mode enabled (simulation only)"
                shift
                ;;
            --verbose)
                VERBOSE=true
                # Verbose logging starts here
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo ""
                show_help
                exit 1
                ;;
        esac
    done
    
    print_verbose "Argument parsing completed successfully"
}

###############################################################################
# FUNCTION: main
#
# SYNOPSIS
#     Main script execution coordinator.
#
# DESCRIPTION
#     Orchestrates the complete order generation workflow including argument
#     parsing, validation, directory creation, order generation, file output,
#     and summary statistics. Implements comprehensive error handling and
#     provides detailed progress feedback.
#
# PARAMETERS
#     $@ - All command-line arguments (passed to parse_arguments)
#
# WORKFLOW
#     1. Parse command-line arguments
#     2. Log execution parameters
#     3. Validate parameter ranges and relationships
#     4. Create output directory if needed
#     5. Handle dry-run mode (simulation)
#     6. Generate orders with progress tracking
#     7. Write JSON to output file
#     8. Calculate and display statistics
#     9. Display execution summary
#
# EXIT CODES
#     0 - Success
#     1 - Parameter validation failure
#     1 - Directory creation failure
#     1 - File write failure
#
# OUTPUTS
#     - Progress updates during generation
#     - Success messages with file details
#     - Summary statistics (orders, file size, products)
#     - Detailed statistics (revenue, average order value) in verbose mode
#     - Verbose logging when --verbose flag is set
#
# NOTES
#     - Progress shown at 10% intervals (minimum every order)
#     - File size calculated in KB with 2 decimal precision
#     - Supports dry-run mode for testing without file output
#     - Creates output directory automatically if missing
#     - All monetary values formatted to 2 decimal places
#
# EXAMPLES
#     main --count 50 --verbose
#     main --count 100 --output-path "/tmp/orders.json"
#     main --dry-run --verbose
###############################################################################
main() {
    # Parse command-line arguments and set global variables
    parse_arguments "$@"
    
    # Log script startup with parameters
    print_verbose "==========================================================="
    print_verbose "Starting order generation process..."
    print_verbose "==========================================================="
    print_verbose "Execution Parameters:"
    print_verbose "  Order Count: ${ORDER_COUNT}"
    print_verbose "  Min Products per Order: ${MIN_PRODUCTS}"
    print_verbose "  Max Products per Order: ${MAX_PRODUCTS}"
    print_verbose "  Output Path: ${OUTPUT_PATH}"
    print_verbose "  Force Mode: ${FORCE}"
    print_verbose "  Dry-Run Mode: ${DRY_RUN}"
    print_verbose "  Verbose Mode: ${VERBOSE}"
    print_verbose "==========================================================="
    
    # Phase 1: Parameter Validation
    print_verbose "Phase 1: Validating parameters..."
    
    # Validate numeric parameter ranges
    validate_range "${ORDER_COUNT}" 1 10000 "OrderCount"
    validate_range "${MIN_PRODUCTS}" 1 20 "MinProducts"
    validate_range "${MAX_PRODUCTS}" 1 20 "MaxProducts"
    
    # Validate logical relationship between min and max products
    if [[ ${MIN_PRODUCTS} -gt ${MAX_PRODUCTS} ]]; then
        print_error "MinProducts (${MIN_PRODUCTS}) cannot be greater than MaxProducts (${MAX_PRODUCTS})"
        print_error "Please adjust parameters so MinProducts ≤ MaxProducts"
        exit 1
    fi
    
    print_verbose "All parameter validations passed"
    
    # Phase 2: Output Directory Setup
    print_verbose "Phase 2: Preparing output directory..."
    
    # Resolve output directory path
    local output_dir=$(dirname "${OUTPUT_PATH}")
    print_verbose "Output directory: ${output_dir}"
    
    # Create directory if it doesn't exist
    if [[ ! -d "${output_dir}" ]]; then
        print_verbose "Output directory does not exist, creating..."
        
        if [[ "${DRY_RUN}" == "true" ]]; then
            print_info "[DRY-RUN] Would create directory: ${output_dir}"
        else
            if mkdir -p "${output_dir}"; then
                print_verbose "✓ Created output directory successfully"
            else
                print_error "Failed to create output directory: ${output_dir}"
                print_error "Check permissions and path validity"
                exit 1
            fi
        fi
    else
        print_verbose "Output directory exists: ${output_dir}"
    fi
    
    # Handle dry-run mode (simulation without file creation)
    if [[ "${DRY_RUN}" == "true" ]]; then
        print_info ""
        print_info "==========================================================="
        print_info "DRY-RUN MODE: Simulating order generation"
        print_info "==========================================================="
        print_info "What if: Generating ${ORDER_COUNT} orders with parameters:"
        print_info "  Min Products: ${MIN_PRODUCTS}"
        print_info "  Max Products: ${MAX_PRODUCTS}"
        print_info "  Output Path: ${OUTPUT_PATH}"
        print_info ""
        
        # Calculate estimated statistics
        local avg_products=$(awk "BEGIN {printf \"%.1f\", (${MIN_PRODUCTS} + ${MAX_PRODUCTS}) / 2}")
        local min_total_products=$((ORDER_COUNT * MIN_PRODUCTS))
        local max_total_products=$((ORDER_COUNT * MAX_PRODUCTS))
        
        print_info "Estimated Results:"
        print_info "  Total Products: ${min_total_products}-${max_total_products} (avg: ~$((ORDER_COUNT * (MIN_PRODUCTS + MAX_PRODUCTS) / 2)))"
        print_info "  Average Products/Order: ${avg_products}"
        print_info "  Estimated File Size: 40-60 KB (varies with product count)"
        print_info ""
        print_info "No files were created or modified."
        print_info "This was a simulation only."
        print_info "==========================================================="
        exit 0
    fi
    
    # Phase 3: Order Generation
    print_verbose "Phase 3: Generating ${ORDER_COUNT} orders..."
    print_info ""
    print_info "Generating ${ORDER_COUNT} orders..."
    
    # Initialize JSON array structure
    local orders_json="["
    
    # Calculate progress reporting interval (10% of total)
    # Minimum interval is 1 to ensure progress shown for small batches
    local progress_interval=$((ORDER_COUNT / 10))
    if [[ ${progress_interval} -lt 1 ]]; then
        progress_interval=1
    fi
    
    print_verbose "Progress will be reported every ${progress_interval} orders"
    
    # Generate orders with progress tracking
    local start_time=$(date +%s)
    
    for ((i=1; i<=ORDER_COUNT; i++)); do
        # Add comma separator between JSON objects (not before first)
        if [[ ${i} -gt 1 ]]; then
            orders_json+=","
        fi
        
        # Generate single order and append to JSON array
        orders_json+=$(generate_order ${i} ${MIN_PRODUCTS} ${MAX_PRODUCTS})
        
        # Display progress at calculated intervals and at completion
        if [[ $((i % progress_interval)) -eq 0 ]] || [[ ${i} -eq ${ORDER_COUNT} ]]; then
            local percent=$((i * 100 / ORDER_COUNT))
            print_info "Progress: ${i}/${ORDER_COUNT} (${percent}%)"
        fi
    done
    
    # Close JSON array structure
    orders_json+=$'\n'"]"
    
    local end_time=$(date +%s)
    local elapsed=$((end_time - start_time))
    print_verbose "Order generation completed in ${elapsed} seconds"
    
    # Phase 4: File Output
    print_verbose "Phase 4: Writing JSON to file..."
    print_info ""
    
    # Write generated JSON to output file
    if echo "${orders_json}" > "${OUTPUT_PATH}"; then
        print_verbose "✓ Successfully wrote JSON to file"
    else
        print_error "Failed to write JSON to file: ${OUTPUT_PATH}"
        print_error "Check disk space and write permissions"
        exit 1
    fi
    
    # Phase 5: Calculate Statistics
    print_verbose "Phase 5: Calculating summary statistics..."
    
    # Get file size using platform-appropriate stat command
    local file_size
    if command -v stat &> /dev/null; then
        # Try GNU stat (Linux) first, then BSD stat (macOS)
        file_size=$(stat -c%s "${OUTPUT_PATH}" 2>/dev/null || stat -f%z "${OUTPUT_PATH}")
    else
        # Fallback to wc if stat not available
        file_size=$(wc -c < "${OUTPUT_PATH}")
    fi
    
    # Convert bytes to KB with 2 decimal precision
    local file_size_kb=$(awk "BEGIN {printf \"%.2f\", ${file_size} / 1024}")
    print_verbose "File size: ${file_size} bytes (${file_size_kb} KB)"
    
    # Parse JSON to calculate additional statistics (when jq available)
    if command -v jq &> /dev/null; then
        print_verbose "jq detected, calculating detailed statistics..."
        
        # Calculate total revenue across all orders
        local total_revenue=$(jq '[.[].totalAmount] | add' "${OUTPUT_PATH}" 2>/dev/null || echo "0")
        
        # Calculate average order value
        local avg_order_value=$(awk "BEGIN {printf \"%.2f\", ${total_revenue} / ${ORDER_COUNT}}")
        
        # Count total products across all orders
        local total_products=$(jq '[.[].products | length] | add' "${OUTPUT_PATH}" 2>/dev/null || echo "0")
        
        print_verbose "Statistics calculated: Revenue=\$${total_revenue}, Avg=\$${avg_order_value}, Products=${total_products}"
    fi
    
    # Phase 6: Display Summary
    print_info ""
    print_success "✓ Successfully generated ${ORDER_COUNT} orders"
    print_info ""
    print_info "Summary:"
    print_info "  Output file: ${OUTPUT_PATH}"
    print_info "  File size: ${file_size_kb} KB"
    print_info "  Products per order: ${MIN_PRODUCTS}-${MAX_PRODUCTS}"
    
    # Display detailed statistics if jq is available
    if command -v jq &> /dev/null && [[ -n "${total_revenue:-}" ]]; then
        print_info "  Total revenue: \$${total_revenue}"
        print_info "  Average order value: \$${avg_order_value}"
        print_info "  Total products: ${total_products}"
    fi
    
    print_info ""
    print_verbose "==========================================================="
    print_verbose "Order generation completed successfully in ${elapsed} seconds"
    print_verbose "==========================================================="
}

# Execute main function with all command-line arguments
# Script entry point
main "$@"
