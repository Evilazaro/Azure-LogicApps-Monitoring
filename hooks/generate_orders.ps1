# PowerShell script to generate 10,000 orders matching the Order model schema
# This script generates test data that aligns with eShop.Orders.API.Models.Order

$NUM_ORDERS = 10000
$START_ORDER_ID = 101
$MIN_QUANTITY = 1
$MAX_QUANTITY = 10
$MIN_PRICE_PER_ITEM = 10.00
$MAX_PRICE_PER_ITEM = 200.00

# Thank you messages aligned with Order.Message property
$MESSAGES = @(
    "Thank you for your order!",
    "We appreciate your business!",
    "Your order has been received!",
    "Thanks for shopping with us!",
    "Order confirmed - thank you!",
    "We're processing your order now!",
    "Thank you for choosing us!",
    "Your purchase is appreciated!",
    "Order received - thanks!",
    "We value your business!"
)

$orders = @()
$currentDate = Get-Date

Write-Host "Generating $NUM_ORDERS orders with schema-aligned properties..." -ForegroundColor Cyan

for ($i = 0; $i -lt $NUM_ORDERS; $i++) {
    if ($i % 1000 -eq 0) {
        Write-Host "Progress: $i / $NUM_ORDERS orders generated..." -ForegroundColor Yellow
    }
    
    # Generate unique Id (matches Order.Id property)
    $orderId = "ORD-$($START_ORDER_ID + $i)"
    
    # Generate random Date within the last year (matches Order.Date property)
    $daysAgo = Get-Random -Minimum 0 -Maximum 366
    $orderDate = $currentDate.AddDays(-$daysAgo).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    
    # Generate random Quantity (matches Order.Quantity property)
    $quantity = Get-Random -Minimum $MIN_QUANTITY -Maximum ($MAX_QUANTITY + 1)
    
    # Calculate Total (matches Order.Total property)
    $pricePerItem = [Math]::Round((Get-Random -Minimum ($MIN_PRICE_PER_ITEM * 100) -Maximum ($MAX_PRICE_PER_ITEM * 100)) / 100, 2)
    $orderTotal = [Math]::Round($pricePerItem * $quantity, 2)
    
    # Select random Message (matches Order.Message property)
    $message = $MESSAGES | Get-Random
    
    # Create order object with property names matching C# Order model
    $order = [PSCustomObject]@{
        Id = $orderId              # Changed from OrderId
        Date = $orderDate          # Changed from OrderDate
        Quantity = $quantity       # Changed from OrderQuantity
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
