#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Generates test order data for the eShop Orders API.

.DESCRIPTION
    Creates a JSON file containing test orders that match the eShop.Orders.API.Models.Order schema.
    Each order includes Id, Date, Quantity, Total, and Message properties with realistic test data.
    
    The generated orders have:
    - Unique sequential IDs starting from ORD-101
    - Random dates within the last year
    - Random quantities between 1-10 items
    - Calculated totals based on quantity and price
    - Random thank you messages

.PARAMETER NumberOfOrders
    The number of orders to generate. Default is 10,000.

.PARAMETER OutputPath
    The output file path for the generated JSON. Default is 'orders.json'.

.PARAMETER StartOrderId
    The starting order ID number. Default is 101.

.EXAMPLE
    .\generate_orders.ps1
    Generates 10,000 orders in orders.json

.EXAMPLE
    .\generate_orders.ps1 -NumberOfOrders 1000 -OutputPath 'test-orders.json'
    Generates 1,000 orders in test-orders.json

.EXAMPLE
    .\generate_orders.ps1 -NumberOfOrders 50000 -StartOrderId 1 -Verbose
    Generates 50,000 orders starting from ORD-1 with verbose output

.NOTES
    File Name      : generate_orders.ps1
    Author         : Azure-LogicApps-Monitoring Team
    Version        : 2.0.0
    Last Modified  : 2025-12-18
    Schema         : Matches eShop.Orders.API.Models.Order
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'Number of orders to generate')]
    [ValidateRange(1, 1000000)]
    [int]$NumberOfOrders = 10000,
    
    [Parameter(Mandatory = $false, HelpMessage = 'Output file path for generated JSON')]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = 'orders.json',
    
    [Parameter(Mandatory = $false, HelpMessage = 'Starting order ID number')]
    [ValidateRange(1, [int]::MaxValue)]
    [int]$StartOrderId = 101
)

# Set strict mode and preferences for robust error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Script constants for order generation parameters
$script:MinQuantity = 1
$script:MaxQuantity = 10
$script:MinPricePerItem = 10.00
$script:MaxPricePerItem = 200.00

# Thank you messages aligned with Order.Message property (500 char max)
$script:Messages = @(
    'Thank you for your order!',
    'We appreciate your business!',
    'Your order has been received!',
    'Thanks for shopping with us!',
    'Order confirmed - thank you!',
    'We''re processing your order now!',
    'Thank you for choosing us!',
    'Your purchase is appreciated!',
    'Order received - thanks!',
    'We value your business!',
    'Your order is being prepared for shipment.',
    'Thank you for being a valued customer!'
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
    Write-Information "  Starting ID      : ORD-$StartOrderId"
    Write-Information ''
    
    # Initialize collection with pre-allocated capacity for optimal performance
    # Using List<T> prevents array reallocation overhead for large datasets
    $orders = [System.Collections.Generic.List[PSCustomObject]]::new($NumberOfOrders)
    $currentDate = Get-Date
    
    Write-Information "Generating $NumberOfOrders orders with schema-aligned properties..."
    Write-Verbose "Price range: $($script:MinPricePerItem) - $($script:MaxPricePerItem)"
    Write-Verbose "Quantity range: $($script:MinQuantity) - $($script:MaxQuantity)"
    
    # Generate orders with realistic random data
    for ($i = 0; $i -lt $NumberOfOrders; $i++) {
        # Display progress indicator every 1000 orders for user feedback
        if ($i % 1000 -eq 0 -and $i -gt 0) {
            $percentComplete = [Math]::Round(($i / $NumberOfOrders) * 100, 1)
            Write-Information "Progress: $i / $NumberOfOrders orders ($percentComplete%) generated..."
        }
        
        # Generate unique Id (matches Order.Id property - max 50 chars)
        $orderId = "ORD-$($StartOrderId + $i)"
        
        # Generate random Date within the last year (matches Order.Date property)
        # Creates realistic order distribution across time
        $daysAgo = Get-Random -Minimum 0 -Maximum 366
        $hoursAgo = Get-Random -Minimum 0 -Maximum 24
        $minutesAgo = Get-Random -Minimum 0 -Maximum 60
        $orderDate = $currentDate.AddDays(-$daysAgo).AddHours(-$hoursAgo).AddMinutes(-$minutesAgo)
        # Convert to ISO 8601 format for JSON serialization compatibility
        $orderDateString = $orderDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        
        # Generate random Quantity (matches Order.Quantity property - min 1)
        $quantity = Get-Random -Minimum $script:MinQuantity -Maximum ($script:MaxQuantity + 1)
        
        # Calculate Total based on quantity and random price per item
        # Matches Order.Total property (decimal, >= 0.01)
        $pricePerItem = Get-Random -Minimum $script:MinPricePerItem -Maximum $script:MaxPricePerItem
        $orderTotal = [Math]::Round($quantity * $pricePerItem, 2)
        
        # Select random Message (matches Order.Message property - max 500 chars)
        $message = $script:Messages | Get-Random
        
        # Create order object with property names matching C# Order model exactly
        # Property order and types must align with API schema for validation
        $order = [PSCustomObject]@{
            Id       = $orderId          # String, 1-50 chars, required
            Date     = $orderDateString  # DateTime (ISO 8601), required
            Quantity = $quantity         # Int, >= 1, required
            Total    = $orderTotal       # Decimal, >= 0.01, required
            Message  = $message          # String, 1-500 chars, required
        }
        
        # Add to collection using $null assignment to suppress output
        $null = $orders.Add($order)
    }
    
    Write-Information ''
    Write-Information 'Converting to JSON...'
    Write-Verbose 'Using ConvertTo-Json with Depth 10 for proper serialization'
    
    # Convert to JSON with sufficient depth and readable formatting
    # Depth 10 ensures nested properties are fully serialized
    $json = $orders | ConvertTo-Json -Depth 10 -Compress:$false
    
    Write-Information "Writing to file: $OutputPath"
    Write-Verbose 'Using UTF-8 encoding without BOM for cross-platform compatibility'
    
    # Write with UTF-8 encoding (no BOM) for cross-platform compatibility
    # Using .NET method for precise encoding control
    [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))
    
    # Verify file was created successfully
    if (-not (Test-Path -Path $OutputPath -PathType Leaf)) {
        throw "Failed to create output file: $OutputPath"
    }
    
    # Gather file statistics for reporting
    $fileInfo = Get-Item -Path $OutputPath
    $fileSizeMB = [Math]::Round($fileInfo.Length / 1MB, 2)
    
    # Display success summary with detailed metrics
    Write-Information ''
    Write-Information '═══════════════════════════════════════════════════════════'
    Write-Information 'Order Generation Completed Successfully!'
    Write-Information '═══════════════════════════════════════════════════════════'
    Write-Information 'Results:'
    Write-Information "  • Total orders generated : $NumberOfOrders"
    Write-Information "  • First Order ID         : $($orders[0].Id)"
    Write-Information "  • Last Order ID          : $($orders[$orders.Count - 1].Id)"
    Write-Information "  • Output file            : $OutputPath"
    Write-Information "  • File size              : $fileSizeMB MB"
    Write-Information ''
    
    # Calculate and display performance metrics
    $executionDuration = (New-TimeSpan -Start $executionStart -End (Get-Date)).TotalSeconds
    Write-Information "Generation Time: $([Math]::Round($executionDuration, 2)) seconds"
    Write-Information "Orders per second: $([Math]::Round($NumberOfOrders / $executionDuration, 0))"
    Write-Information ''
    
    # Display sample order for verification
    Write-Information 'Sample Order (first record):'
    $orders[0] | Format-List | Out-String | ForEach-Object { Write-Information $_.TrimEnd() }
    
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
