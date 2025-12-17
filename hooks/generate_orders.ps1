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
    Last Modified  : 2025-12-17
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

# Set strict mode and preferences
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Script constants
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
    'Thank you for being a valued customer!',
#region Order Generation

try {
    $executionStart = Get-Date
    
    Write-Information "═══════════════════════════════════════════════════════════"
    Write-Information "Order Generation Script Started"
    Write-Information "═══════════════════════════════════════════════════════════"
    Write-Information "Configuration:"
    Write-Information "  Number of Orders : $NumberOfOrders"
    Write-Information "  Output File      : $OutputPath"
    Write-Information "  Starting ID      : ORD-$StartOrderId"
    Write-Information ""
    
    # Initialize collection with pre-allocated capacity for performance
    $orders = [System.Collections.Generic.List[PSCustomObject]]::new($NumberOfOrders)
    $currentDate = Get-Date
    
    Write-Information "Generating $NumberOfOrders orders with schema-aligned properties..."
    Write-Verbose "Price range: $($script:MinPricePerItem) - $($script:MaxPricePerItem)"
    Write-Verbose "Quantity range: $($script:MinQuantity) - $($script:MaxQuantity)"
    
    for ($i = 0; $i -lt $NumberOfOrders; $i++) {
        # Progress indicator every 1000 orders
        if ($i % 1000 -eq 0 -and $i -gt 0) {
            $percentComplete = [Math]::Round(($i / $NumberOfOrders) * 100, 1)
            Write-Information "Progress: $i / $NumberOfOrders orders ($percentComplete%) generated..."
        }
        
        # Generate unique Id (matches Order.Id property - max 50 chars)
        $orderId = "ORD-$($StartOrderId + $i)"
        
        # Generate random Date within the last year (matches Order.Date property)
        $daysAgo = Get-Random -Minimum 0 -Maximum 366
        $hoursAgo = Get-Random -Minimum 0 -Maximum 24
        $minutesAgo = Get-Random -Minimum 0 -Maximum 60
        $orderDate = $currentDate.AddDays(-$daysAgo).AddHours(-$hoursAgo).AddMinutes(-$minutesAgo)
        $orderDateString = $orderDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ss.fffZ')
        
    Write-Information ""
    Write-Information "Converting to JSON..."
    Write-Verbose "Using ConvertTo-Json with Depth 10 for proper serialization"
    
    $json = $orders | ConvertTo-Json -Depth 10 -Compress:$false
    
    Write-Information "Writing to file: $OutputPath"
    Write-Verbose "Using UTF-8 encoding without BOM"
    
    # Write with UTF-8 encoding (no BOM) for cross-platform compatibility
    [System.IO.File]::WriteAllText($OutputPath, $json, [System.Text.UTF8Encoding]::new($false))
    
    # Verify file was created
    if (-not (Test-Path -Path $OutputPath)) {
        throw "Failed to create output file: $OutputPath"
    }
    
    $fileInfo = Get-Item -Path $OutputPath
    $fileSizeMB = [Math]::Round($fileInfo.Length / 1MB, 2)
    
    Write-Information ""
    Write-Information "═══════════════════════════════════════════════════════════"
    Write-Information "Order Generation Completed Successfully!"
    Write-Information "═══════════════════════════════════════════════════════════"
    Write-Information "Results:"
    Write-Information "  • Total orders generated : $NumberOfOrders"
    Write-Information "  • First Order ID         : $($orders[0].Id)"
    Write-Information "  • Last Order ID          : $($orders[$orders.Count - 1].Id)"
    Write-Information "  • Output file            : $OutputPath"
    Write-Information "  • File size              : $fileSizeMB MB"
    Write-Information ""
    
    $executionDuration = (New-TimeSpan -Start $executionStart -End (Get-Date)).TotalSeconds
    Write-Information "Generation Time: $([Math]::Round($executionDuration, 2)) seconds"
    Write-Information "Orders per second: $([Math]::Round($NumberOfOrders / $executionDuration, 0))"
    Write-Information ""
    
    Write-Information "Sample Order (first record):"
    $orders[0] | Format-List | Out-String | ForEach-Object { Write-Information $_.TrimEnd() }
    
    Write-Verbose "Exiting with success code 0"
    exit 0
}
catch {
    Write-Error "═══════════════════════════════════════════════════════════"
    Write-Error "Order Generation Failed!"
    Write-Error "═══════════════════════════════════════════════════════════"
    Write-Error "Error: $($_.Exception.Message)"
    Write-Error ""
    
    if ($_.InvocationInfo) {
        Write-Error "Location: Line $($_.InvocationInfo.ScriptLineNumber), Column $($_.InvocationInfo.OffsetInLine)"
    }
    
    if ($_.ScriptStackTrace) {
        Write-Verbose "Stack Trace:"
        Write-Verbose $_.ScriptStackTrace
    }
    
    exit 1
}

#endregionMessage (matches Order.Message property - max 500 chars)
        $message = $script:Messages | Get-Random
        
        # Create order object with property names matching C# Order model
        $order = [PSCustomObject]@{
            Id       = $orderId          # String, 1-50 chars, required
            Date     = $orderDateString  # DateTime, required
            Quantity = $quantity         # Int, >= 1, required
            Total    = $orderTotal       # Decimal, >= 0.01, required
            Message  = $message          # String, 1-500 chars, required
        }
        
        $null = $orders.Add($order)
            Total = $orderTotal        # Changed from OrderTotal
        Message = $message         # Changed from OrderMessage
    }
    
    $orders += $order
}

Write-Host "Converting to JSON..." -ForegroundColor Cyan
$json = $orders | ConvertTo-Json -Depth 10

Write-Host "Writing to file..." -ForegroundColor Cyan
$outputFile = "orders.json"
$json | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "`nSuccessfully generated $NUM_ORDERS orders in $outputFile" -ForegroundColor Green
Write-Host "First Order ID: $($orders[0].Id)" -ForegroundColor Gray
Write-Host "Last Order ID: $($orders[$orders.Count - 1].Id)" -ForegroundColor Gray
Write-Host "File size: $((Get-Item $outputFile).Length / 1MB) MB" -ForegroundColor Gray
Write-Host "`nSample Order (first record):" -ForegroundColor Cyan
$orders[0] | Format-List
