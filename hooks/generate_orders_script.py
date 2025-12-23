import json
import random
from datetime import datetime, timedelta
import os

# Product catalog
products = [
    {"id": "PROD-1001", "description": "Wireless Mouse", "basePrice": 25.99},
    {"id": "PROD-1002", "description": "Mechanical Keyboard", "basePrice": 89.99},
    {"id": "PROD-1003", "description": "USB-C Hub", "basePrice": 34.99},
    {"id": "PROD-2001", "description": "Noise Cancelling Headphones", "basePrice": 149.99},
    {"id": "PROD-2002", "description": "Bluetooth Speaker", "basePrice": 79.99},
    {"id": "PROD-3001", "description": "External SSD 1TB", "basePrice": 119.99},
    {"id": "PROD-3002", "description": "Portable Charger", "basePrice": 49.99},
    {"id": "PROD-4001", "description": "Webcam 1080p", "basePrice": 69.99},
    {"id": "PROD-4002", "description": "Laptop Stand", "basePrice": 39.99},
    {"id": "PROD-5001", "description": "Cable Organizer", "basePrice": 12.99},
    {"id": "PROD-5002", "description": "Smartphone Holder", "basePrice": 19.99},
    {"id": "PROD-6001", "description": "Monitor 27\" 4K", "basePrice": 399.99},
    {"id": "PROD-6002", "description": "Monitor Arm", "basePrice": 89.99},
    {"id": "PROD-7001", "description": "Ergonomic Chair", "basePrice": 299.99},
    {"id": "PROD-7002", "description": "Standing Desk", "basePrice": 499.99},
    {"id": "PROD-8001", "description": "USB Microphone", "basePrice": 99.99},
    {"id": "PROD-8002", "description": "Ring Light", "basePrice": 44.99},
    {"id": "PROD-9001", "description": "Graphics Tablet", "basePrice": 199.99},
    {"id": "PROD-9002", "description": "Drawing Pen Set", "basePrice": 29.99},
    {"id": "PROD-A001", "description": "Wireless Earbuds", "basePrice": 129.99},
]

# Delivery addresses
addresses = [
    "221B Baker Street, London, UK",
    "350 Fifth Ave, New York, NY, USA",
    "88 Colin P Kelly Jr St, San Francisco, CA, USA",
    "1600 Amphitheatre Parkway, Mountain View, CA, USA",
    "1 Microsoft Way, Redmond, WA, USA",
    "410 Terry Ave N, Seattle, WA, USA",
    "1 Apple Park Way, Cupertino, CA, USA",
    "Platz der Republik 1, Berlin, Germany",
    "Champs-Élysées, Paris, France",
    "Shibuya Crossing, Tokyo, Japan",
    "123 Main St, Toronto, ON, Canada",
    "456 Queen St, Sydney, NSW, Australia",
    "789 King St, Melbourne, VIC, Australia",
    "10 Downing Street, London, UK",
    "Rua Oscar Freire, São Paulo, Brazil",
    "Passeig de Gràcia, Barcelona, Spain",
    "Unter den Linden, Berlin, Germany",
    "Via Montenapoleone, Milan, Italy",
    "Nanjing Road, Shanghai, China",
    "Gangnam District, Seoul, South Korea",
]

def random_date():
    """Generate a random date within the last year"""
    start_date = datetime(2024, 1, 1)
    end_date = datetime(2025, 12, 31)
    time_between = end_date - start_date
    days_between = time_between.days
    random_days = random.randrange(days_between)
    random_seconds = random.randrange(86400)
    return (start_date + timedelta(days=random_days, seconds=random_seconds)).strftime("%Y-%m-%dT%H:%M:%SZ")

def generate_order(order_num):
    """Generate a single order with random products"""
    order_id = f"ORD-{order_num:04d}"
    customer_id = f"CUST-{random.randint(50, 9999)}"
    date = random_date()
    address = random.choice(addresses)
    
    # Random number of products (1-6)
    num_products = random.randint(1, 6)
    selected_products = random.sample(products, num_products)
    
    order_products = []
    order_total = 0
    
    for idx, product in enumerate(selected_products, 1):
        quantity = random.randint(1, 5)
        # Add some price variation (±20%)
        price_variation = random.uniform(0.8, 1.2)
        price = round(product["basePrice"] * price_variation, 2)
        subtotal = round(price * quantity, 2)
        
        order_products.append({
            "id": f"OP-{order_num:04d}-{idx}",
            "orderId": order_id,
            "productId": product["id"],
            "productDescription": product["description"],
            "quantity": quantity,
            "price": price
        })
        
        order_total += subtotal
    
    return {
        "id": order_id,
        "customerId": customer_id,
        "date": date,
        "deliveryAddress": address,
        "total": round(order_total, 2),
        "products": order_products
    }

# Generate 50 orders
orders = [generate_order(i + 1) for i in range(50)]

# Write to file
output_path = r"..\infra\data\ordersBatch.json"
# Create the directory if it doesn't exist
os.makedirs(os.path.dirname(output_path), exist_ok=True)
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(orders, f, indent=4, ensure_ascii=False)

print(f"Successfully generated 50 orders in {output_path}")
print(f"Total file size: {len(json.dumps(orders, indent=4))} bytes")
