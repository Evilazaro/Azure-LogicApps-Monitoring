#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Generates test order data for the eShop Orders API.

.DESCRIPTION
    Creates a JSON file containing test orders with customers, products, and delivery addresses.
    Each order includes:
    - Unique order ID (ORD-XXXX format)
    - Customer ID (CUST-XXXX format)
    - Order date
    - Delivery address
    - Array of products with details (productId, description, quantity, price)
    - Calculated total

.PARAMETER NumberOfOrders
    The number of orders to generate. Default is 100.

.PARAMETER OutputPath
    The output file path for the generated JSON. Default is 'orders.json'.

.PARAMETER StartOrderId
    The starting order ID number. Default is 1.

.EXAMPLE
    .\generate_orders.ps1
    Generates 100 orders in orders.json

.EXAMPLE
    .\generate_orders.ps1 -NumberOfOrders 50 -OutputPath 'test-orders.json'
    Generates 50 orders in test-orders.json

.EXAMPLE
    .\generate_orders.ps1 -NumberOfOrders 200 -StartOrderId 1 -Verbose
    Generates 200 orders starting from ORD-0001 with verbose output

.NOTES
    File Name      : generate_orders.ps1
    Author         : Azure-LogicApps-Monitoring Team
    Version        : 3.0.0
    Last Modified  : 2025-12-19
    Schema         : Matches eShop.Orders.API with products and customers
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Number of orders to generate')]
    [ValidateRange(1, 10000)]
    [int]$NumberOfOrders = 5000,
    
    [Parameter(Mandatory = $false, HelpMessage = 'Output file path for generated JSON')]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = '..\infra\data\orders.json',
    
    [Parameter(Mandatory = $false, HelpMessage = 'Starting order ID number')]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$StartOrderId = 1
)

# Set strict mode and preferences for robust error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Script constants
$script:MinProductsPerOrder = 1
$script:MaxProductsPerOrder = 5
$script:MinQuantity = 1
$script:MaxQuantity = 3

# Product catalog with realistic items
$script:Products = @(
    @{ Id = 'PROD-1001'; Description = 'Wireless Mouse'; MinPrice = 29.99; MaxPrice = 79.99 },
    @{ Id = 'PROD-1002'; Description = 'Mechanical Keyboard'; MinPrice = 89.99; MaxPrice = 199.99 },
    @{ Id = 'PROD-1003'; Description = 'USB-C Hub'; MinPrice = 29.99; MaxPrice = 59.99 },
    @{ Id = 'PROD-2001'; Description = 'Noise Cancelling Headphones'; MinPrice = 79.99; MaxPrice = 349.99 },
    @{ Id = 'PROD-2002'; Description = 'Webcam 1080p'; MinPrice = 49.99; MaxPrice = 129.99 },
    @{ Id = 'PROD-3001'; Description = 'External SSD 1TB'; MinPrice = 89.99; MaxPrice = 179.99 },
    @{ Id = 'PROD-3002'; Description = 'Portable Charger'; MinPrice = 24.99; MaxPrice = 79.99 },
    @{ Id = 'PROD-4001'; Description = 'Laptop Stand'; MinPrice = 29.99; MaxPrice = 89.99 },
    @{ Id = 'PROD-4002'; Description = 'Cable Management Kit'; MinPrice = 14.99; MaxPrice = 34.99 },
    @{ Id = 'PROD-5001'; Description = 'Wireless Earbuds'; MinPrice = 49.99; MaxPrice = 249.99 },
    @{ Id = 'PROD-5002'; Description = 'Smartphone Holder'; MinPrice = 12.99; MaxPrice = 39.99 },
    @{ Id = 'PROD-6001'; Description = 'Monitor 27" 4K'; MinPrice = 299.99; MaxPrice = 799.99 },
    @{ Id = 'PROD-6002'; Description = 'HDMI 2.1 Cable'; MinPrice = 19.99; MaxPrice = 49.99 },
    @{ Id = 'PROD-7001'; Description = 'Desk Lamp LED'; MinPrice = 34.99; MaxPrice = 89.99 },
    @{ Id = 'PROD-7002'; Description = 'Ergonomic Mouse Pad'; MinPrice = 19.99; MaxPrice = 49.99 },
    @{ Id = 'PROD-8001'; Description = 'USB Microphone'; MinPrice = 59.99; MaxPrice = 199.99 },
    @{ Id = 'PROD-8002'; Description = 'Ring Light'; MinPrice = 39.99; MaxPrice = 129.99 },
    @{ Id = 'PROD-9001'; Description = 'Graphics Tablet'; MinPrice = 79.99; MaxPrice = 399.99 },
    @{ Id = 'PROD-9002'; Description = 'Stylus Pen'; MinPrice = 29.99; MaxPrice = 99.99 },
    @{ Id = 'PROD-9003'; Description = 'Docking Station'; MinPrice = 89.99; MaxPrice = 299.99 }
)

# Delivery addresses for variety
$script:Addresses = @(
    '742 Evergreen Terrace, Springfield, USA',
    '1600 Amphitheatre Parkway, Mountain View, CA, USA',
    '1 Infinite Loop, Cupertino, CA, USA',
    '410 Terry Ave N, Seattle, WA, USA',
    '1 Microsoft Way, Redmond, WA, USA',
    '350 Fifth Ave, New York, NY, USA',
    '1455 Market St, San Francisco, CA, USA',
    '100 Main St, Cambridge, MA, USA',
    '221B Baker Street, London, UK',
    '1 Apple Park Way, Cupertino, CA, USA',
    '1601 Willow Rd, Menlo Park, CA, USA',
    '2500 Colorado Ave, Santa Monica, CA, USA',
    '1355 Market St, San Francisco, CA, USA',
    '747 Howard St, San Francisco, CA, USA',
    '88 Colin P Kelly Jr St, San Francisco, CA, USA'
)

#region Order Generation

try {
    # Track execution time for performance metrics
    $executionStart = Get-Date
    
    # Display script header and configuration
    Write-Information '═══════════════════════════════════════════════════════════'
    Write-Information 'Order Generation Script Started'
    Write-Information '═══════════════════════════════════════════════════════════'
    Write-Information 'Configuration:'
    Write-Information "  Number of Orders : $NumberOfOrders"
    Write-Information "  Output File      : $OutputPath"
    Write-Information "  Starting ID      : ORD-$('{0:D4}' -f $StartOrderId)"
    Write-Information ''
    
    # Initialize collection with pre-allocated capacity for optimal performance
    $orders = [System.Collections.Generic.List[PSCustomObject]]::new($NumberOfOrders)
    $baseDate = Get-Date -Year 2024 -Month 1 -Day 1
    
    Write-Information "Generating $NumberOfOrders orders with products and customer data..."
    Write-Verbose "Products per order range: $($script:MinProductsPerOrder) - $($script:MaxProductsPerOrder)"
    Write-Verbose "Available products: $($script:Products.Count)"
    
    # Generate orders with realistic random data
    for ($i = 0; $i -lt $NumberOfOrders; $i++) {
        # Display progress indicator
        if (($i % 25 -eq 0) -and ($i -gt 0)) {
            $percentComplete = [Math]::Round(($i / $NumberOfOrders) * 100, 1)
            Write-Information "Progress: $i / $NumberOfOrders orders ($percentComplete%) generated..."
        }
        
        # Generate unique order ID with padding (ORD-0001 format)
        $orderNumber = $StartOrderId + $i
        $orderId = "ORD-$('{0:D4}' -f $orderNumber)"
        
        # Generate random customer ID
        $customerId = "CUST-$('{0:D4}' -f (Get-Random -Minimum 1 -Maximum 10000))"
        
        # Generate random date (spread across 2024-2025)
        $daysFromBase = Get-Random -Minimum 0 -Maximum 600
        $hoursOffset = Get-Random -Minimum 0 -Maximum 24
        $minutesOffset = Get-Random -Minimum 0 -Maximum 60
        $orderDate = $baseDate.AddDays($daysFromBase).AddHours($hoursOffset).AddMinutes($minutesOffset)
        $orderDateString = $orderDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        
        # Select random delivery address
        $deliveryAddress = $script:Addresses | Get-Random
        
        # Generate products for this order
        $numProducts = Get-Random -Minimum $script:MinProductsPerOrder -Maximum ($script:MaxProductsPerOrder + 1)
        $orderProducts = [System.Collections.Generic.List[PSCustomObject]]::new($numProducts)
        $orderTotal = 0.0
        
        # Select random unique products for this order
        # Ensure result is always an array by wrapping in @()
        $selectedProducts = @($script:Products | Get-Random -Count $numProducts)
        
        for ($p = 0; $p -lt $numProducts; $p++) {
            $productInfo = $selectedProducts[$p]
            
            # Generate order product ID (OP-XXXX-Y format)
            $orderProductId = "OP-$('{0:D4}' -f $orderNumber)-$($p + 1)"
            
            # Random quantity and price for this product
            $quantity = Get-Random -Minimum $script:MinQuantity -Maximum ($script:MaxQuantity + 1)
            $price = [Math]::Round((Get-Random -Minimum $productInfo.MinPrice -Maximum $productInfo.MaxPrice), 2)
            
            # Create product entry
            $product = [PSCustomObject]@{
                id                 = $orderProductId
                orderId            = $orderId
                productId          = $productInfo.Id
                productDescription = $productInfo.Description
                quantity           = $quantity
                price              = $price
            }
            
            $null = $orderProducts.Add($product)
            $orderTotal += ($quantity * $price)
        }
        
        # Round total to 2 decimal places
        $orderTotal = [Math]::Round($orderTotal, 2)
        
        # Create order object
        $order = [PSCustomObject]@{
            id              = $orderId
            customerId      = $customerId
            date            = $orderDateString
            deliveryAddress = $deliveryAddress
            total           = $orderTotal
            products        = $orderProducts.ToArray()
        }
        
        # Add to collection
        $null = $orders.Add($order)
    }
    
    Write-Information ''
    Write-Information 'Converting to JSON...'
    Write-Verbose 'Using ConvertTo-Json with Depth 10 for proper serialization'
    
    # Create the root object with orders array
    $rootObject = [PSCustomObject]@{
        orders = $orders.ToArray()
    }
    
    # Convert to JSON with sufficient depth and readable formatting
    $json = $rootObject | ConvertTo-Json -Depth 10 -Compress:$false
    
    Write-Information "Writing to file: $OutputPath"
    Write-Verbose 'Using UTF-8 encoding without BOM for cross-platform compatibility'
    
    # Resolve full path
    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    Write-Verbose "Full path: $fullPath"
    
    # Write with UTF-8 encoding (no BOM) for cross-platform compatibility
    try {
        [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
    }
    catch {
        throw "Failed to write file: $_"
    }
    
    # Verify file was created successfully
    if (-not (Test-Path -Path $fullPath -PathType Leaf)) {
        throw "Failed to create output file: $fullPath"
    }
    
    # Gather file statistics for reporting
    $fileInfo = Get-Item -Path $fullPath
    $fileSizeKB = [Math]::Round($fileInfo.Length / 1KB, 2)
    
    # Calculate total products
    $totalProducts = ($orders | ForEach-Object { $_.products.Count } | Measure-Object -Sum).Sum
    
    # Display success summary with detailed metrics
    Write-Information ''
    Write-Information '═══════════════════════════════════════════════════════════'
    Write-Information 'Order Generation Completed Successfully!'
    Write-Information '═══════════════════════════════════════════════════════════'
    Write-Information 'Results:'
    Write-Information "  • Total orders generated : $NumberOfOrders"
    Write-Information "  • Total products         : $totalProducts"
    Write-Information "  • First Order ID         : $($orders[0].id)"
    Write-Information "  • Last Order ID          : $($orders[$orders.Count - 1].id)"
    Write-Information "  • Output file            : $OutputPath"
    Write-Information "  • File size              : $fileSizeKB KB"
    Write-Information ''
    
    # Calculate and display performance metrics
    $executionDuration = (New-TimeSpan -Start $executionStart -End (Get-Date)).TotalSeconds
    Write-Information "Generation Time: $([Math]::Round($executionDuration, 2)) seconds"
    Write-Information "Orders per second: $([Math]::Round($NumberOfOrders / $executionDuration, 0))"
    Write-Information ''
    
    # Display sample order for verification
    Write-Information 'Sample Order (first record):'
    Write-Information "  Order ID: $($orders[0].id)"
    Write-Information "  Customer: $($orders[0].customerId)"
    Write-Information "  Date: $($orders[0].date)"
    Write-Information "  Address: $($orders[0].deliveryAddress)"
    Write-Information "  Total: `$$($orders[0].total)"
    Write-Information "  Products: $($orders[0].products.Count)"
    foreach ($prod in $orders[0].products) {
        Write-Information "    - $($prod.productDescription) (x$($prod.quantity)) @ `$$($prod.price)"
    }
    
    Write-Verbose 'Exiting with success code 0'
    exit 0
}
catch {
    # Comprehensive error reporting with actionable information
    Write-Host '═══════════════════════════════════════════════════════════' -ForegroundColor Red
    Write-Host 'Order Generation Failed!' -ForegroundColor Red
    Write-Host '═══════════════════════════════════════════════════════════' -ForegroundColor Red
    Write-Host ''
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ''
    
    # Display error location for troubleshooting
    if ($_.InvocationInfo) {
        Write-Host "Location: Line $($_.InvocationInfo.ScriptLineNumber), Column $($_.InvocationInfo.OffsetInLine)" -ForegroundColor Red
    }
    
    # Include stack trace in verbose mode for detailed debugging
    if ($_.ScriptStackTrace) {
        Write-Verbose 'Stack Trace:'
        Write-Verbose $_.ScriptStackTrace
    }
    
    # Exit with error code
    exit 1
}

#endregion
