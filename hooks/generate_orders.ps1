# PowerShell script to generate 10,000 orders
$NUM_ORDERS = 10000
$START_ORDER_ID = 101
$MIN_QUANTITY = 1
$MAX_QUANTITY = 10
$MIN_PRICE_PER_ITEM = 10.00
$MAX_PRICE_PER_ITEM = 200.00

# Thank you messages
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

Write-Host "Generating $NUM_ORDERS orders..."

for ($i = 0; $i -lt $NUM_ORDERS; $i++) {
    if ($i % 1000 -eq 0) {
        Write-Host "Progress: $i / $NUM_ORDERS orders generated..."
    }
    
    # Generate unique OrderId
    $orderId = $START_ORDER_ID + $i
    
    # Generate random date within the last year
    $daysAgo = Get-Random -Minimum 0 -Maximum 366
    $orderDate = $currentDate.AddDays(-$daysAgo).ToString("yyyy-MM-dd")
    
    # Generate random quantity
    $quantity = Get-Random -Minimum $MIN_QUANTITY -Maximum ($MAX_QUANTITY + 1)
    
    # Calculate total
    $pricePerItem = [Math]::Round((Get-Random -Minimum ($MIN_PRICE_PER_ITEM * 100) -Maximum ($MAX_PRICE_PER_ITEM * 100)) / 100, 2)
    $orderTotal = [Math]::Round($pricePerItem * $quantity, 2)
    
    # Select random message
    $message = $MESSAGES | Get-Random
    
    # Create order object
    $order = [PSCustomObject]@{
        OrderId = $orderId
        OrderDate = $orderDate
        OrderQuantity = $quantity
        OrderTotal = $orderTotal
        OrderMessage = $message
    }
    
    $orders += $order
}

Write-Host "Converting to JSON..."
$json = $orders | ConvertTo-Json -Depth 10

Write-Host "Writing to file..."
$outputFile = "orders.json"
$json | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Successfully generated $NUM_ORDERS orders in $outputFile"
Write-Host "First OrderId: $($orders[0].OrderId)"
Write-Host "Last OrderId: $($orders[$orders.Count - 1].OrderId)"
Write-Host "File size: $((Get-Item $outputFile).Length) bytes"
