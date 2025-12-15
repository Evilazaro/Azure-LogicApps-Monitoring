import json
import random
from datetime import datetime, timedelta

# Configuration
NUM_ORDERS = 10000
START_ORDER_ID = 101
MIN_QUANTITY = 1
MAX_QUANTITY = 10
MIN_PRICE_PER_ITEM = 10.00
MAX_PRICE_PER_ITEM = 200.00

# Thank you messages variety
MESSAGES = [
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
]

# Generate orders
orders = []
current_date = datetime.now()

for i in range(NUM_ORDERS):
    # Generate unique OrderId
    order_id = START_ORDER_ID + i
    
    # Generate random date within the last year
    days_ago = random.randint(0, 365)
    order_date = (current_date - timedelta(days=days_ago)).strftime("%Y-%m-%d")
    
    # Generate random quantity
    quantity = random.randint(MIN_QUANTITY, MAX_QUANTITY)
    
    # Calculate total (price per item * quantity)
    price_per_item = round(random.uniform(MIN_PRICE_PER_ITEM, MAX_PRICE_PER_ITEM), 2)
    order_total = round(price_per_item * quantity, 2)
    
    # Select random message
    message = random.choice(MESSAGES)
    
    # Create order object
    order = {
        "OrderId": order_id,
        "OrderDate": order_date,
        "OrderQuantity": quantity,
        "OrderTotal": order_total,
        "OrderMessage": message
    }
    
    orders.append(order)

# Write to JSON file
output_file = "orders.json"
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(orders, f, indent=4, ensure_ascii=False)

print(f"Successfully generated {NUM_ORDERS} orders in {output_file}")
print(f"File size: {len(json.dumps(orders, indent=4))} bytes")
print(f"First OrderId: {orders[0]['OrderId']}")
print(f"Last OrderId: {orders[-1]['OrderId']}")
