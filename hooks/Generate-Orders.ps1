<#
.SYNOPSIS
    Generates sample order data for testing Azure Logic Apps monitoring.

.DESCRIPTION
    This script generates random e-commerce orders with products, customer information, 
    and delivery addresses. The generated data is saved as JSON for use in testing 
    and demonstration scenarios.

.PARAMETER OrderCount
    The number of orders to generate. Default is 50.

.PARAMETER OutputPath
    The path where the JSON file will be saved. 
    Default is '..\infra\data\ordersBatch.json' relative to the script location.

.PARAMETER MinProducts
    Minimum number of products per order. Default is 1.

.PARAMETER MaxProducts
    Maximum number of products per order. Default is 6.

.EXAMPLE
    .\Generate-Orders.ps1
    Generates 50 orders using default settings.

.EXAMPLE
    .\Generate-Orders.ps1 -OrderCount 100 -OutputPath "C:\temp\orders.json"
    Generates 100 orders and saves to a custom path.

.EXAMPLE
    .\Generate-Orders.ps1 -OrderCount 25 -MinProducts 2 -MaxProducts 4
    Generates 25 orders with 2-4 products each.

.NOTES
    File Name      : Generate-Orders.ps1
    Author         : Azure Logic Apps Monitoring Team
    Prerequisite   : PowerShell 7.0 or higher
    Copyright      : (c) 2025. All rights reserved.

.LINK
    https://github.com/Evilazaro/Azure-LogicApps-Monitoring
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Number of orders to generate")]
    [ValidateRange(1, 10000)]
    [int]$OrderCount = 50,

    [Parameter(Mandatory = $false, HelpMessage = "Output file path for generated orders")]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\infra\data\ordersBatch.json'),

    [Parameter(Mandatory = $false, HelpMessage = "Minimum products per order")]
    [ValidateRange(1, 20)]
    [int]$MinProducts = 1,

    [Parameter(Mandatory = $false, HelpMessage = "Maximum products per order")]
    [ValidateRange(1, 20)]
    [int]$MaxProducts = 6
)

#Requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Product Catalog

$script:Products = @(
    [PSCustomObject]@{ Id = 'PROD-1001'; Description = 'Wireless Mouse'; BasePrice = 25.99 }
    [PSCustomObject]@{ Id = 'PROD-1002'; Description = 'Mechanical Keyboard'; BasePrice = 89.99 }
    [PSCustomObject]@{ Id = 'PROD-1003'; Description = 'USB-C Hub'; BasePrice = 34.99 }
    [PSCustomObject]@{ Id = 'PROD-2001'; Description = 'Noise Cancelling Headphones'; BasePrice = 149.99 }
    [PSCustomObject]@{ Id = 'PROD-2002'; Description = 'Bluetooth Speaker'; BasePrice = 79.99 }
    [PSCustomObject]@{ Id = 'PROD-3001'; Description = 'External SSD 1TB'; BasePrice = 119.99 }
    [PSCustomObject]@{ Id = 'PROD-3002'; Description = 'Portable Charger'; BasePrice = 49.99 }
    [PSCustomObject]@{ Id = 'PROD-4001'; Description = 'Webcam 1080p'; BasePrice = 69.99 }
    [PSCustomObject]@{ Id = 'PROD-4002'; Description = 'Laptop Stand'; BasePrice = 39.99 }
    [PSCustomObject]@{ Id = 'PROD-5001'; Description = 'Cable Organizer'; BasePrice = 12.99 }
    [PSCustomObject]@{ Id = 'PROD-5002'; Description = 'Smartphone Holder'; BasePrice = 19.99 }
    [PSCustomObject]@{ Id = 'PROD-6001'; Description = 'Monitor 27" 4K'; BasePrice = 399.99 }
    [PSCustomObject]@{ Id = 'PROD-6002'; Description = 'Monitor Arm'; BasePrice = 89.99 }
    [PSCustomObject]@{ Id = 'PROD-7001'; Description = 'Ergonomic Chair'; BasePrice = 299.99 }
    [PSCustomObject]@{ Id = 'PROD-7002'; Description = 'Standing Desk'; BasePrice = 499.99 }
    [PSCustomObject]@{ Id = 'PROD-8001'; Description = 'USB Microphone'; BasePrice = 99.99 }
    [PSCustomObject]@{ Id = 'PROD-8002'; Description = 'Ring Light'; BasePrice = 44.99 }
    [PSCustomObject]@{ Id = 'PROD-9001'; Description = 'Graphics Tablet'; BasePrice = 199.99 }
    [PSCustomObject]@{ Id = 'PROD-9002'; Description = 'Drawing Pen Set'; BasePrice = 29.99 }
    [PSCustomObject]@{ Id = 'PROD-A001'; Description = 'Wireless Earbuds'; BasePrice = 129.99 }
)

#endregion

#region Delivery Addresses

$script:Addresses = @(
    '221B Baker Street, London, UK'
    '350 Fifth Ave, New York, NY, USA'
    '88 Colin P Kelly Jr St, San Francisco, CA, USA'
    '1600 Amphitheatre Parkway, Mountain View, CA, USA'
    '1 Microsoft Way, Redmond, WA, USA'
    '410 Terry Ave N, Seattle, WA, USA'
    '1 Apple Park Way, Cupertino, CA, USA'
    'Platz der Republik 1, Berlin, Germany'
    'Champs-Élysées, Paris, France'
    'Shibuya Crossing, Tokyo, Japan'
    '123 Main St, Toronto, ON, Canada'
    '456 Queen St, Sydney, NSW, Australia'
    '789 King St, Melbourne, VIC, Australia'
    '10 Downing Street, London, UK'
    'Rua Oscar Freire, São Paulo, Brazil'
    'Passeig de Gràcia, Barcelona, Spain'
    'Unter den Linden, Berlin, Germany'
    'Via Montenapoleone, Milan, Italy'
    'Nanjing Road, Shanghai, China'
    'Gangnam District, Seoul, South Korea'
)

#endregion

#region Functions

function Get-RandomDate {
    <#
    .SYNOPSIS
        Generates a random date within the last year.
    
    .DESCRIPTION
        Creates a random timestamp between January 1, 2024 and December 31, 2025
        in ISO 8601 format (yyyy-MM-ddTHH:mm:ssZ).
    
    .OUTPUTS
        System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $startDate = Get-Date -Year 2024 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0
    $endDate = Get-Date -Year 2025 -Month 12 -Day 31 -Hour 23 -Minute 59 -Second 59
    
    $timeSpan = $endDate - $startDate
    $randomDays = Get-Random -Minimum 0 -Maximum $timeSpan.Days
    $randomSeconds = Get-Random -Minimum 0 -Maximum 86400
    
    $randomDate = $startDate.AddDays($randomDays).AddSeconds($randomSeconds)
    
    return $randomDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
}

function New-Order {
    <#
    .SYNOPSIS
        Generates a single order with random products.
    
    .DESCRIPTION
        Creates an order object with a unique ID, random customer, products,
        delivery address, and calculated total price.
    
    .PARAMETER OrderNumber
        The sequential order number used to generate the order ID.
    
    .PARAMETER MinProductCount
        Minimum number of products in the order.
    
    .PARAMETER MaxProductCount
        Maximum number of products in the order.
    
    .OUTPUTS
        System.Collections.Hashtable
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 99999)]
        [int]$OrderNumber,

        [Parameter(Mandatory)]
        [ValidateRange(1, 20)]
        [int]$MinProductCount,

        [Parameter(Mandatory)]
        [ValidateRange(1, 20)]
        [int]$MaxProductCount
    )

    # Validate that min is not greater than max
    if ($MinProductCount -gt $MaxProductCount) {
        throw "MinProductCount ($MinProductCount) cannot be greater than MaxProductCount ($MaxProductCount)"
    }

    # Generate unique GUID-based order ID
    $orderGuid = (New-Guid).ToString('N').Substring(0, 12).ToUpper()
    $orderId = "ORD-$orderGuid"
    
    # Generate unique customer ID
    $customerGuid = (New-Guid).ToString('N').Substring(0, 8).ToUpper()
    $customerId = "CUST-$customerGuid"
    
    $orderDate = Get-RandomDate
    $deliveryAddress = $script:Addresses | Get-Random
    
    # Determine number of products for this order
    $productCount = Get-Random -Minimum $MinProductCount -Maximum ($MaxProductCount + 1)
    $selectedProducts = $script:Products | Get-Random -Count $productCount
    
    $orderProducts = @()
    $orderTotal = 0.0
    
    foreach ($index in 1..$selectedProducts.Count) {
        $product = $selectedProducts[$index - 1]
        $quantity = Get-Random -Minimum 1 -Maximum 6
        
        # Add price variation (±20%)
        $priceVariation = Get-Random -Minimum 0.8 -Maximum 1.2
        $price = [Math]::Round($product.BasePrice * $priceVariation, 2)
        $subtotal = [Math]::Round($price * $quantity, 2)
        
        # Generate unique GUID-based order product ID
        $productGuid = (New-Guid).ToString('N').Substring(0, 12).ToUpper()
        $orderProductId = "OP-$productGuid"
        
        $orderProducts += @{
            id                 = $orderProductId
            orderId            = $orderId
            productId          = $product.Id
            productDescription = $product.Description
            quantity           = $quantity
            price              = $price
        }
        
        $orderTotal += $subtotal
    }
    
    return @{
        id              = $orderId
        customerId      = $customerId
        date            = $orderDate
        deliveryAddress = $deliveryAddress
        total           = [Math]::Round($orderTotal, 2)
        products        = $orderProducts
    }
}

function Export-OrdersToJson {
    <#
    .SYNOPSIS
        Exports orders to a JSON file.
    
    .DESCRIPTION
        Serializes an array of order objects to JSON format and saves to the specified path.
        Creates the output directory if it doesn't exist.
    
    .PARAMETER Orders
        Array of order objects to export.
    
    .PARAMETER Path
        File path where the JSON will be saved.
    
    .OUTPUTS
        System.IO.FileInfo
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.IO.FileInfo])]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowEmptyCollection()]
        [object[]]$Orders,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    begin {
        $allOrders = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($order in $Orders) {
            $allOrders.Add($order)
        }
    }

    end {
        try {
            # Resolve the full path
            $resolvedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
            $directory = Split-Path -Path $resolvedPath -Parent
            
            # Create directory if it doesn't exist
            if (-not (Test-Path -Path $directory -PathType Container)) {
                if ($PSCmdlet.ShouldProcess($directory, 'Create directory')) {
                    $null = New-Item -Path $directory -ItemType Directory -Force
                    Write-Verbose "Created directory: $directory"
                }
            }
            
            # Convert to JSON
            $jsonContent = $allOrders | ConvertTo-Json -Depth 10 -Compress:$false
            
            # Write to file
            if ($PSCmdlet.ShouldProcess($resolvedPath, 'Write orders to JSON file')) {
                $jsonContent | Out-File -FilePath $resolvedPath -Encoding utf8 -Force
                Write-Verbose "Successfully wrote orders to: $resolvedPath"
                
                return Get-Item -Path $resolvedPath
            }
        }
        catch {
            Write-Error "Failed to export orders to JSON: $_"
            throw
        }
    }
}

#endregion

#region Main Script

try {
    Write-Verbose "Starting order generation process..."
    Write-Verbose "Parameters: OrderCount=$OrderCount, MinProducts=$MinProducts, MaxProducts=$MaxProducts"
    
    # Validate parameters
    if ($MinProducts -gt $MaxProducts) {
        throw "MinProducts ($MinProducts) cannot be greater than MaxProducts ($MaxProducts)"
    }
    
    # Generate orders with progress tracking
    $orders = @()
    $progressParams = @{
        Activity        = 'Generating Orders'
        Status          = 'Creating order data'
        PercentComplete = 0
    }
    
    Write-Progress @progressParams
    
    for ($i = 1; $i -le $OrderCount; $i++) {
        $orders += New-Order -OrderNumber $i -MinProductCount $MinProducts -MaxProductCount $MaxProducts
        
        # Update progress every 10 orders or on the last order
        if (($i % 10 -eq 0) -or ($i -eq $OrderCount)) {
            $progressParams.PercentComplete = [int](($i / $OrderCount) * 100)
            $progressParams.Status = "Created $i of $OrderCount orders"
            Write-Progress @progressParams
        }
    }
    
    Write-Progress -Activity 'Generating Orders' -Completed
    
    # Export to JSON
    Write-Verbose "Exporting $($orders.Count) orders to JSON..."
    $outputFile = Export-OrdersToJson -Orders $orders -Path $OutputPath
    
    # Display summary
    $fileSizeKB = [Math]::Round($outputFile.Length / 1KB, 2)
    
    Write-Host "✓ Successfully generated $OrderCount orders" -ForegroundColor Green
    Write-Host "  Output file: $($outputFile.FullName)" -ForegroundColor Cyan
    Write-Host "  File size: $fileSizeKB KB" -ForegroundColor Cyan
    Write-Host "  Products per order: $MinProducts-$MaxProducts" -ForegroundColor Cyan
}
catch {
    Write-Error "Order generation failed: $_"
    exit 1
}
finally {
    Write-Verbose "Order generation process completed."
}

#endregion
