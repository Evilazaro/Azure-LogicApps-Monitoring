# Business Architecture Document

## TOGAF 10 - Business Layer (BDAT Model)

**Document Version:** 1.0  
**Last Updated:** January 30, 2026  
**Project:** Azure Logic Apps Monitoring Solution (eShop Orders Management)  
**Repository:** [Azure-LogicApps-Monitoring](https://github.com/Evilazaro/Azure-LogicApps-Monitoring)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Business Domain Overview](#2-business-domain-overview)
3. [Business Capabilities](#3-business-capabilities)
4. [Business Services](#4-business-services)
5. [Business Processes](#5-business-processes)
6. [Business Entities](#6-business-entities)
7. [Business Rules](#7-business-rules)
8. [Business Interfaces](#8-business-interfaces)
9. [Business Workflows](#9-business-workflows)
10. [Stakeholders and Actors](#10-stakeholders-and-actors)
11. [Traceability Matrix](#11-traceability-matrix)

---

## 1. Executive Summary

This document describes the **Business Architecture** of the Azure Logic Apps Monitoring Solution, following TOGAF 10 BDAT (Business, Data, Application, Technology) principles. The solution implements an **eShop Orders Management** platform that enables customers to place, track, and manage orders through a cloud-native architecture.

### 1.1 Business Purpose

The system provides comprehensive order management capabilities for an eShop platform, including:

- Order placement (single and batch)
- Order tracking and retrieval
- Order deletion and lifecycle management
- Asynchronous order processing via messaging
- Automated workflow orchestration

### 1.2 Business Scope

| Aspect                 | Description                 |
| ---------------------- | --------------------------- |
| **Domain**             | E-Commerce Order Management |
| **Primary Capability** | Order Lifecycle Management  |
| **Geographic Scope**   | Cloud-native (Azure-hosted) |
| **License**            | MIT License                 |

---

## 2. Business Domain Overview

### 2.1 Domain: eShop Orders Management

The business domain encompasses the complete lifecycle of customer orders within an e-commerce ecosystem.

**Source:** [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs)

```
┌─────────────────────────────────────────────────────────────────┐
│                    eShop Orders Management                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Order     │    │   Order     │    │   Order     │         │
│  │  Placement  │───▶│ Processing  │───▶│  Tracking   │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│         │                  │                  │                 │
│         ▼                  ▼                  ▼                 │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │   Batch     │    │  Workflow   │    │   Order     │         │
│  │ Operations  │    │ Automation  │    │  Deletion   │         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Business Capabilities

Business capabilities represent what the organization does to achieve its business objectives.

### 3.1 Capability Catalog

| Capability ID | Capability Name        | Description                                       | Source Reference                                                                                                                 |
| ------------- | ---------------------- | ------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| BC-001        | Order Placement        | Ability to create and submit new customer orders  | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                                       |
| BC-002        | Batch Order Processing | Ability to process multiple orders simultaneously | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                                       |
| BC-003        | Order Retrieval        | Ability to retrieve order details by identifier   | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                                       |
| BC-004        | Order Listing          | Ability to list all orders in the system          | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                                       |
| BC-005        | Order Deletion         | Ability to remove orders from the system          | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                                       |
| BC-006        | Batch Order Deletion   | Ability to delete multiple orders simultaneously  | [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs)                                                       |
| BC-007        | Order Messaging        | Ability to publish order events to message broker | [IOrdersMessageHandler.cs](../../src/eShop.Orders.API/Interfaces/IOrdersMessageHandler.cs)                                       |
| BC-008        | Workflow Orchestration | Ability to automate order processing workflows    | [OrdersPlacedProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json) |

### 3.2 Capability Details

#### BC-001: Order Placement

**Source:** [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs), Lines 18-22

```csharp
/// <summary>
/// Places a new order asynchronously.
/// </summary>
/// <param name="order">The order to be placed.</param>
/// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
/// <returns>The placed order.</returns>
Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default);
```

**Business Outcome:** A new customer order is created in the system with validation, persistence, and event publication.

#### BC-002: Batch Order Processing

**Source:** [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs), Lines 24-31

```csharp
/// <summary>
/// Places multiple orders in a batch operation asynchronously.
/// </summary>
/// <param name="orders">The collection of orders to be placed.</param>
/// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
/// <returns>A collection of successfully placed orders.</returns>
Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default);
```

**Business Outcome:** Multiple orders are processed in parallel with optimized throughput.

#### BC-003: Order Retrieval

**Source:** [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs), Lines 41-47

```csharp
/// <summary>
/// Retrieves a specific order by its unique identifier.
/// </summary>
/// <param name="orderId">The unique identifier of the order.</param>
/// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
/// <returns>The order if found; otherwise, null.</returns>
Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default);
```

**Business Outcome:** Authorized users can view complete order details for tracking purposes.

#### BC-005: Order Deletion

**Source:** [IOrderService.cs](../../src/eShop.Orders.API/Interfaces/IOrderService.cs), Lines 49-56

```csharp
/// <summary>
/// Deletes an order by its unique identifier.
/// </summary>
/// <param name="orderId">The unique identifier of the order to delete.</param>
/// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
/// <returns>True if the order was successfully deleted; otherwise, false.</returns>
Task<bool> DeleteOrderAsync(string orderId, CancellationToken cancellationToken = default);
```

**Business Outcome:** Orders can be removed from the system when no longer needed.

---

## 4. Business Services

Business services encapsulate business functionality and are exposed through defined interfaces.

### 4.1 Service Catalog

| Service ID | Service Name             | Description                                 | Exposed Operations                                                                | Source                                                                                 |
| ---------- | ------------------------ | ------------------------------------------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| BS-001     | Order Management Service | Core service for order lifecycle operations | PlaceOrder, GetOrders, GetOrderById, DeleteOrder                                  | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)                 |
| BS-002     | Order Messaging Service  | Service for publishing order events         | SendOrderMessage, SendOrdersBatchMessage, ListMessages                            | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs) |
| BS-003     | Order Data Service       | Service for order data persistence          | SaveOrder, GetAllOrders, GetOrderById, DeleteOrder                                | [OrderRepository.cs](../../src/eShop.Orders.API/Repositories/OrderRepository.cs)       |
| BS-004     | Order API Client Service | Client service for API communication        | PlaceOrder, PlaceOrdersBatch, GetOrder, GetOrders, DeleteOrder, DeleteOrdersBatch | [OrdersAPIService.cs](../../src/eShop.Web.App/Components/Services/OrdersAPIService.cs) |

### 4.2 Service Details

#### BS-001: Order Management Service

**Source:** [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs)

**Purpose:** Provides business logic for order management including placement, retrieval, and deletion operations with comprehensive observability through distributed tracing and metrics.

**Service Operations:**

| Operation                   | Input                  | Output                | Business Rule                                                     |
| --------------------------- | ---------------------- | --------------------- | ----------------------------------------------------------------- |
| PlaceOrderAsync             | Order                  | Order                 | Validates order, checks for duplicates, persists, publishes event |
| PlaceOrdersBatchAsync       | IEnumerable\<Order\>   | IEnumerable\<Order\>  | Processes in parallel batches of 50                               |
| GetOrdersAsync              | None                   | IEnumerable\<Order\>  | Returns all orders                                                |
| GetOrderByIdAsync           | OrderId                | Order?                | Returns order if found                                            |
| DeleteOrderAsync            | OrderId                | bool                  | Removes order from system                                         |
| DeleteOrdersBatchAsync      | IEnumerable\<OrderId\> | int                   | Deletes multiple orders, returns count                            |
| ListMessagesFromTopicsAsync | None                   | IEnumerable\<object\> | Lists messages from message broker                                |

#### BS-002: Order Messaging Service

**Source:** [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs)

**Purpose:** Handles publishing order messages to Azure Service Bus with distributed tracing support.

**Configuration:**

- Default Topic Name: `ordersplaced`
- Message Subject: `OrderPlaced`
- Content Type: `application/json`

**Service Operations:**

| Operation                   | Description                                           |
| --------------------------- | ----------------------------------------------------- |
| SendOrderMessageAsync       | Sends single order message with retry logic           |
| SendOrdersBatchMessageAsync | Sends multiple order messages for improved throughput |
| ListMessagesAsync           | Lists/peeks messages from subscriptions               |

---

## 5. Business Processes

Business processes describe the flow of activities to achieve business outcomes.

### 5.1 Process Catalog

| Process ID | Process Name           | Trigger                   | Outcome                        | Source                                                                                                                                           |
| ---------- | ---------------------- | ------------------------- | ------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| BP-001     | Place Single Order     | Customer submits order    | Order created, event published | [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                |
| BP-002     | Place Batch Orders     | Customer uploads orders   | Multiple orders processed      | [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                |
| BP-003     | View Order             | Customer searches by ID   | Order details displayed        | [ViewOrder.razor](../../src/eShop.Web.App/Components/Pages/ViewOrder.razor)                                                                      |
| BP-004     | List All Orders        | User requests order list  | All orders displayed           | [ListAllOrders.razor](../../src/eShop.Web.App/Components/Pages/ListAllOrders.razor)                                                              |
| BP-005     | Delete Order           | User deletes order        | Order removed from system      | [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)                                                                |
| BP-006     | Process Order Placed   | Message received on topic | Order processed, blob created  | [OrdersPlacedProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)                 |
| BP-007     | Complete Order Process | Scheduled recurrence      | Processed blobs cleaned up     | [OrdersPlacedCompleteProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json) |

### 5.2 Process Details

#### BP-001: Place Single Order Process

**Source:** [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs), Lines 42-119

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Customer  │────▶│  Validate   │────▶│   Check     │────▶│    Save     │
│   Request   │     │   Order     │     │  Duplicate  │     │   Order     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                   │
                    ┌─────────────┐     ┌─────────────┐            │
                    │   Return    │◀────│   Publish   │◀───────────┘
                    │   201/OK    │     │   Message   │
                    └─────────────┘     └─────────────┘
```

**Process Steps:**

1. **Receive Order Request** - API receives POST request with order payload
2. **Validate Order Data** - Check required fields and business rules
3. **Check Duplicate** - Verify order ID doesn't already exist
4. **Save to Database** - Persist order to SQL Azure Database
5. **Publish Message** - Send order event to Service Bus topic
6. **Return Response** - Return created order with 201 status

**Exception Handling:**

- **400 Bad Request** - Invalid order data
- **409 Conflict** - Order already exists
- **500 Internal Error** - Unexpected system failure

#### BP-002: Place Batch Orders Process

**Source:** [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs), Lines 159-207

**Process Configuration:**

- Process Batch Size: 50 orders
- Concurrent Database Operations: 10 (controlled by SemaphoreSlim)
- Internal Timeout: 5 minutes

**Process Steps:**

1. **Receive Batch Request** - API receives collection of orders
2. **Validate Collection** - Ensure collection is not empty
3. **Partition into Batches** - Split into groups of 50
4. **Process Parallel** - Process each batch with concurrency control
5. **Track Results** - Use ConcurrentBag for thread-safe result collection
6. **Return Successful Orders** - Return collection of processed orders

#### BP-006: Order Placed Workflow Process

**Source:** [OrdersPlacedProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)

**Trigger:** Service Bus topic message received on `ordersplaced` topic, subscription `orderprocessingsub`

**Workflow Steps:**

```
┌─────────────────────┐
│ Message Received    │
│ (ordersplaced)      │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│ Check Content Type  │
│ (application/json)  │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐  ┌─────────┐
│  Valid  │  │ Invalid │
└────┬────┘  └────┬────┘
     │            │
     ▼            ▼
┌─────────────┐  ┌─────────────────────┐
│ HTTP POST   │  │ Create Error Blob   │
│ /api/Orders │  │ /ordersprocessed    │
│ /process    │  │ witherrors          │
└─────────────┘  └─────────────────────┘
     │
     ▼
┌─────────────────────┐
│ Check Status = 201  │
└──────────┬──────────┘
           │
     ┌─────┴─────┐
     ▼           ▼
┌─────────┐  ┌─────────┐
│ Success │  │  Error  │
└────┬────┘  └────┬────┘
     │            │
     ▼            ▼
┌─────────────────┐  ┌─────────────────────┐
│ Create Success  │  │ Create Error Blob   │
│ Blob /orders    │  │ /ordersprocessed    │
│ processed       │  │ witherrors          │
│ successfully    │  │                     │
└─────────────────┘  └─────────────────────┘
```

#### BP-007: Order Process Completion Workflow

**Source:** [OrdersPlacedCompleteProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json)

**Trigger:** Scheduled recurrence every 3 seconds

**Workflow Steps:**

1. **List Blobs** - Retrieve all blobs from `/ordersprocessedsuccessfully`
2. **For Each Blob** - Iterate with concurrency of 20
3. **Get Metadata** - Retrieve blob metadata
4. **Delete Blob** - Remove processed blob

---

## 6. Business Entities

Business entities represent the core business objects with their attributes and relationships.

### 6.1 Entity Catalog

| Entity ID | Entity Name  | Description                                           | Source                                                     |
| --------- | ------------ | ----------------------------------------------------- | ---------------------------------------------------------- |
| BE-001    | Order        | Customer order with products and delivery information | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs) |
| BE-002    | OrderProduct | Product item within an order                          | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs) |

### 6.2 Entity Details

#### BE-001: Order

**Source:** [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Lines 67-105

**Definition:** Represents a customer order with products, delivery information, and total amount.

| Attribute       | Type                 | Required | Validation Rules    | Description                   |
| --------------- | -------------------- | -------- | ------------------- | ----------------------------- |
| Id              | string               | Yes      | Length: 1-100 chars | Unique order identifier       |
| CustomerId      | string               | Yes      | Length: 1-100 chars | Customer who placed the order |
| Date            | DateTime             | No       | Defaults to UTC now | Order placement timestamp     |
| DeliveryAddress | string               | Yes      | Length: 5-500 chars | Delivery location             |
| Total           | decimal              | Yes      | Must be > 0         | Order total amount            |
| Products        | List\<OrderProduct\> | Yes      | Min 1 item          | Products in the order         |

#### BE-002: OrderProduct

**Source:** [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Lines 107-155

**Definition:** Represents a product item within an order.

| Attribute          | Type    | Required | Validation Rules    | Description                   |
| ------------------ | ------- | -------- | ------------------- | ----------------------------- |
| Id                 | string  | Yes      | Required            | Unique order product entry ID |
| OrderId            | string  | Yes      | Required            | Parent order reference        |
| ProductId          | string  | Yes      | Required            | Product identifier            |
| ProductDescription | string  | Yes      | Length: 1-500 chars | Product description           |
| Quantity           | int     | Yes      | Min: 1              | Quantity ordered              |
| Price              | decimal | Yes      | Required            | Unit price                    |

### 6.3 Entity Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                         Order                                │
│  ┌─────────────────────────────────────────────────────┐    │
│  │ Id (PK)                                              │    │
│  │ CustomerId                                           │    │
│  │ Date                                                 │    │
│  │ DeliveryAddress                                      │    │
│  │ Total                                                │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           │ 1:N                              │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                   OrderProduct                       │    │
│  │  ┌───────────────────────────────────────────────┐  │    │
│  │  │ Id (PK)                                        │  │    │
│  │  │ OrderId (FK) ─────────────────────────────────┼──┘    │
│  │  │ ProductId                                      │       │
│  │  │ ProductDescription                             │       │
│  │  │ Quantity                                       │       │
│  │  │ Price                                          │       │
│  │  └───────────────────────────────────────────────┘       │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Relationship:** One Order contains many OrderProducts (1:N)  
**Cascade Behavior:** Deleting an Order deletes all associated OrderProducts

**Source:** [OrderDbContext.cs](../../src/eShop.Orders.API/data/OrderDbContext.cs), Lines 73-77

```csharp
entity.HasMany(e => e.Products)
    .WithOne(p => p.Order)
    .HasForeignKey(p => p.OrderId)
    .OnDelete(DeleteBehavior.Cascade);
```

---

## 7. Business Rules

Business rules define the constraints and policies governing business operations.

### 7.1 Rules Catalog

| Rule ID | Rule Name                   | Category    | Description                                      | Source                                                                                                                                    |
| ------- | --------------------------- | ----------- | ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| BR-001  | Order ID Required           | Validation  | Order must have a unique identifier              | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Line 74                                                                       |
| BR-002  | Customer ID Required        | Validation  | Order must identify the customer                 | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Line 80                                                                       |
| BR-003  | Delivery Address Required   | Validation  | Order must have delivery location                | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Line 92                                                                       |
| BR-004  | Positive Order Total        | Validation  | Order total must be greater than zero            | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Line 98                                                                       |
| BR-005  | Minimum One Product         | Validation  | Order must contain at least one product          | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Line 104                                                                      |
| BR-006  | No Duplicate Orders         | Business    | Cannot create order with existing ID             | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs), Lines 103-107                                                     |
| BR-007  | Minimum Product Quantity    | Validation  | Product quantity must be at least 1              | [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Line 144                                                                      |
| BR-008  | Batch Size Limit            | Operational | Batch operations process max 50 orders per batch | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs), Line 183                                                          |
| BR-009  | Concurrent Operations Limit | Operational | Max 10 concurrent database operations            | [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs), Line 196                                                          |
| BR-010  | Message Content Type        | Integration | Order messages must be application/json          | [OrdersPlacedProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json), Line 11 |

### 7.2 Rule Details

#### BR-001: Order ID Required

**Source:** [CommonTypes.cs](../../app.ServiceDefaults/CommonTypes.cs), Lines 73-75

```csharp
[Required(ErrorMessage = "Order ID is required")]
[StringLength(100, MinimumLength = 1, ErrorMessage = "Order ID must be between 1 and 100 characters")]
public required string Id { get; init; }
```

#### BR-006: No Duplicate Orders

**Source:** [OrderService.cs](../../src/eShop.Orders.API/Services/OrderService.cs), Lines 103-107

```csharp
// Check if order already exists
var existingOrder = await _orderRepository.GetOrderByIdAsync(order.Id, cancellationToken);
if (existingOrder != null)
{
    _logger.LogWarning("Order with ID {OrderId} already exists", order.Id);
    throw new InvalidOperationException($"Order with ID {order.Id} already exists");
}
```

---

## 8. Business Interfaces

Business interfaces define the external touchpoints for business services.

### 8.1 Interface Catalog

| Interface ID | Interface Name          | Type       | Description                                | Source                                                                                 |
| ------------ | ----------------------- | ---------- | ------------------------------------------ | -------------------------------------------------------------------------------------- |
| BI-001       | Orders REST API         | HTTP/REST  | RESTful API for order operations           | [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)      |
| BI-002       | Web Application UI      | Web/Blazor | Customer-facing order management interface | [eShop.Web.App](../../src/eShop.Web.App/)                                              |
| BI-003       | Service Bus Integration | Messaging  | Asynchronous order event publishing        | [OrdersMessageHandler.cs](../../src/eShop.Orders.API/Handlers/OrdersMessageHandler.cs) |

### 8.2 REST API Interface Details (BI-001)

**Source:** [OrdersController.cs](../../src/eShop.Orders.API/Controllers/OrdersController.cs)

**Base Path:** `/api/Orders`

| Endpoint                   | Method | Operation           | Request               | Response              | Status Codes            |
| -------------------------- | ------ | ------------------- | --------------------- | --------------------- | ----------------------- |
| `/api/Orders`              | POST   | Place Order         | Order                 | Order                 | 201, 400, 409, 500      |
| `/api/Orders/batch`        | POST   | Place Batch Orders  | IEnumerable\<Order\>  | IEnumerable\<Order\>  | 200, 400, 500           |
| `/api/Orders/process`      | POST   | Process Order       | Order                 | Order                 | 201, 204, 400, 409, 500 |
| `/api/Orders`              | GET    | Get All Orders      | None                  | IEnumerable\<Order\>  | 200, 500                |
| `/api/Orders/{id}`         | GET    | Get Order By ID     | None                  | Order                 | 200, 400, 404, 500      |
| `/api/Orders/{id}`         | DELETE | Delete Order        | None                  | None                  | 204, 400, 404, 500      |
| `/api/Orders/batch/delete` | POST   | Delete Orders Batch | IEnumerable\<string\> | int                   | 200, 400, 500           |
| `/api/Orders/messages`     | GET    | List Messages       | None                  | IEnumerable\<object\> | 200, 500                |

### 8.3 Web Application Interface Details (BI-002)

**Source:** [eShop.Web.App/Components/Pages/](../../src/eShop.Web.App/Components/Pages/)

| Page               | Route                                  | Capability                       | Source                                                                                    |
| ------------------ | -------------------------------------- | -------------------------------- | ----------------------------------------------------------------------------------------- |
| Home               | `/`                                    | Landing page with navigation     | [Home.razor](../../src/eShop.Web.App/Components/Pages/Home.razor)                         |
| Place Order        | `/placeorder`                          | Single order creation form       | [PlaceOrder.razor](../../src/eShop.Web.App/Components/Pages/PlaceOrder.razor)             |
| Place Orders Batch | `/placeordersbatch`                    | Batch order upload (manual/JSON) | [PlaceOrdersBatch.razor](../../src/eShop.Web.App/Components/Pages/PlaceOrdersBatch.razor) |
| View Order         | `/vieworder` or `/vieworder/{OrderId}` | Order search and details         | [ViewOrder.razor](../../src/eShop.Web.App/Components/Pages/ViewOrder.razor)               |
| List All Orders    | `/listallorders`                       | Order listing with batch delete  | [ListAllOrders.razor](../../src/eShop.Web.App/Components/Pages/ListAllOrders.razor)       |

---

## 9. Business Workflows

Business workflows represent the automated processes orchestrated through Azure Logic Apps.

### 9.1 Workflow Catalog

| Workflow ID | Workflow Name               | Trigger             | Purpose                         | Source                                                                                                                                           |
| ----------- | --------------------------- | ------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| BW-001      | OrdersPlacedProcess         | Service Bus Message | Process incoming order messages | [OrdersPlacedProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)                 |
| BW-002      | OrdersPlacedCompleteProcess | Scheduled (3 sec)   | Clean up processed order blobs  | [OrdersPlacedCompleteProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json) |

### 9.2 Workflow Details

#### BW-001: OrdersPlacedProcess

**Source:** [OrdersPlacedProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedProcess/workflow.json)

**Type:** Stateful Logic App Workflow

**Trigger Configuration:**

- **Type:** Service Bus Topic Subscription (auto-complete)
- **Topic:** `ordersplaced`
- **Subscription:** `orderprocessingsub`
- **Recurrence:** 1 second interval

**Actions:**

1. **Check_Order_Placed** - Validates content type is `application/json`
2. **HTTP** - Calls Orders API `/api/Orders/process` endpoint
3. **Check_Process_Worked** - Validates HTTP 201 response
4. **Create_Blob_Successfully** - Stores successful orders in `/ordersprocessedsuccessfully`
5. **Create_Blob_Errors** - Stores failed orders in `/ordersprocessedwitherrors`

**Connections:**

- Azure Service Bus (`servicebus`)
- Azure Blob Storage (`azureblob`)

#### BW-002: OrdersPlacedCompleteProcess

**Source:** [OrdersPlacedCompleteProcess/workflow.json](../../workflows/OrdersManagement/OrdersManagementLogicApp/OrdersPlacedCompleteProcess/workflow.json)

**Type:** Stateful Logic App Workflow

**Trigger Configuration:**

- **Type:** Recurrence
- **Interval:** 3 seconds
- **Timezone:** Central Standard Time

**Actions:**

1. **Lists*blobs*(V2)** - Lists blobs from `/ordersprocessedsuccessfully`
2. **For_each** - Iterates over blobs (concurrency: 20)
3. **Get*Blob_Metadata*(V2)** - Retrieves blob metadata
4. **Delete*blob*(V2)** - Removes processed blob

---

## 10. Stakeholders and Actors

### 10.1 Actor Catalog

| Actor ID | Actor Name           | Description                              | Interactions                             |
| -------- | -------------------- | ---------------------------------------- | ---------------------------------------- |
| A-001    | Customer             | End user placing orders                  | Place Order, View Order                  |
| A-002    | System Administrator | Manages order data                       | List Orders, Delete Orders, Batch Delete |
| A-003    | Integration System   | Automated systems receiving order events | Service Bus Consumer                     |

### 10.2 Actor-Capability Matrix

| Actor                | BC-001 | BC-002 | BC-003 | BC-004 | BC-005 | BC-006 | BC-007 | BC-008 |
| -------------------- | ------ | ------ | ------ | ------ | ------ | ------ | ------ | ------ |
| Customer             | ✓      | ✓      | ✓      | ✓      | ✗      | ✗      | ✗      | ✗      |
| System Administrator | ✓      | ✓      | ✓      | ✓      | ✓      | ✓      | ✓      | ✓      |
| Integration System   | ✗      | ✗      | ✗      | ✗      | ✗      | ✗      | ✓      | ✓      |

---

## 11. Traceability Matrix

### 11.1 Capability to Service Mapping

| Capability                    | Primary Service                 | Supporting Services           |
| ----------------------------- | ------------------------------- | ----------------------------- |
| BC-001 Order Placement        | BS-001 Order Management Service | BS-002 Messaging, BS-003 Data |
| BC-002 Batch Order Processing | BS-001 Order Management Service | BS-002 Messaging, BS-003 Data |
| BC-003 Order Retrieval        | BS-001 Order Management Service | BS-003 Data                   |
| BC-004 Order Listing          | BS-001 Order Management Service | BS-003 Data                   |
| BC-005 Order Deletion         | BS-001 Order Management Service | BS-003 Data                   |
| BC-006 Batch Order Deletion   | BS-001 Order Management Service | BS-003 Data                   |
| BC-007 Order Messaging        | BS-002 Order Messaging Service  | -                             |
| BC-008 Workflow Orchestration | BW-001, BW-002                  | BS-001, BS-003                |

### 11.2 Process to Entity Mapping

| Process                       | Primary Entity | Related Entities              |
| ----------------------------- | -------------- | ----------------------------- |
| BP-001 Place Single Order     | BE-001 Order   | BE-002 OrderProduct           |
| BP-002 Place Batch Orders     | BE-001 Order   | BE-002 OrderProduct           |
| BP-003 View Order             | BE-001 Order   | BE-002 OrderProduct           |
| BP-004 List All Orders        | BE-001 Order   | BE-002 OrderProduct           |
| BP-005 Delete Order           | BE-001 Order   | BE-002 OrderProduct (cascade) |
| BP-006 Process Order Placed   | BE-001 Order   | -                             |
| BP-007 Complete Order Process | -              | -                             |

### 11.3 Interface to Process Mapping

| Interface                      | Supported Processes                    |
| ------------------------------ | -------------------------------------- |
| BI-001 Orders REST API         | BP-001, BP-002, BP-003, BP-004, BP-005 |
| BI-002 Web Application UI      | BP-001, BP-002, BP-003, BP-004, BP-005 |
| BI-003 Service Bus Integration | BP-006, BP-007                         |

---

## Document Metadata

| Property           | Value                                |
| ------------------ | ------------------------------------ |
| **Author**         | Generated based on codebase analysis |
| **Methodology**    | TOGAF 10 BDAT Model                  |
| **Scope**          | Business Layer Architecture          |
| **Classification** | Internal                             |
| **Review Status**  | Draft                                |

---

_This document was generated by analyzing the source code in the Azure Logic Apps Monitoring Solution repository. All claims are verified against actual files in the codebase._
