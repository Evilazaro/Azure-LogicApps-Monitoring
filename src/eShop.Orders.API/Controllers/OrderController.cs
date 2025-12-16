using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Hosting;
using OpenTelemetry.Trace;
using System.Diagnostics;

namespace eShop.Orders.API.Controllers;

/// <summary>
/// API controller for managing orders with comprehensive distributed tracing.
/// Each endpoint automatically creates spans with detailed context propagation.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ILogger<OrdersController> _logger;
    private readonly ActivitySource _activitySource;

    /// <summary>
    /// Initializes a new instance of the OrdersController.
    /// </summary>
    /// <param name="logger">Logger for structured logging with trace correlation.</param>
    public OrdersController(ILogger<OrdersController> logger)
    {
        _logger = logger;
        // Create activity source for custom spans in this controller
        _activitySource = Extensions.CreateActivitySource();
    }

    /// <summary>
    /// Retrieves all orders with distributed tracing.
    /// Automatic span created by ASP.NET Core instrumentation.
    /// </summary>
    /// <returns>List of orders.</returns>
    [HttpGet]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders()
    {
        // Create a custom span for the business logic
        using var activity = _activitySource.StartActivity("GetOrders.BusinessLogic");

        try
        {
            // Add custom tags for filtering and analysis in Application Insights
            activity?.SetTag("orders.operation", "list");
            activity?.SetTag("orders.user", User?.Identity?.Name ?? "anonymous");

            _logger.LogInformation("Retrieving all orders");

            // Simulate business logic (replace with actual implementation)
            var orders = await GetOrdersFromDatabase();

            // Add result metrics to the span
            activity?.SetTag("orders.count", orders.Count());
            activity?.AddEvent(new ActivityEvent("Orders retrieved successfully"));

            return Ok(orders);
        }
        catch (Exception ex)
        {
            // Set span status to error and add exception details
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);

            _logger.LogError(ex, "Error retrieving orders");
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>
    /// Retrieves a specific order by ID with detailed tracing.
    /// </summary>
    /// <param name="id">The order identifier.</param>
    /// <returns>The requested order or 404 if not found.</returns>
    [HttpGet("{id}")]
    public async Task<ActionResult<Order>> GetOrder(string id)
    {
        using var activity = _activitySource.StartActivity("GetOrder.BusinessLogic");

        try
        {
            // Add order ID as a tag for trace filtering
            activity?.SetTag("orders.id", id);
            activity?.SetTag("orders.operation", "get");

            _logger.LogInformation("Retrieving order {OrderId}", id);

            var order = await GetOrderFromDatabase(id);

            if (order == null)
            {
                activity?.SetTag("orders.found", false);
                activity?.AddEvent(new ActivityEvent("Order not found"));

                _logger.LogWarning("Order {OrderId} not found", id);
                return NotFound();
            }

            activity?.SetTag("orders.found", true);
            activity?.SetTag("orders.status", order.Status);
            activity?.AddEvent(new ActivityEvent("Order retrieved successfully"));

            return Ok(order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);

            _logger.LogError(ex, "Error retrieving order {OrderId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>
    /// Creates a new order with distributed tracing across messaging.
    /// Demonstrates context propagation to Service Bus messages.
    /// </summary>
    /// <param name="order">The order to create.</param>
    /// <returns>The created order with location header.</returns>
    [HttpPost]
    public async Task<ActionResult<Order>> CreateOrder([FromBody] Order order)
    {
        using var activity = _activitySource.StartActivity("CreateOrder.BusinessLogic");

        try
        {
            // Add order details as tags
            activity?.SetTag("orders.operation", "create");
            activity?.SetTag("orders.customer_id", order.CustomerId);
            activity?.SetTag("orders.total_amount", order.TotalAmount);

            _logger.LogInformation("Creating new order for customer {CustomerId}", order.CustomerId);

            // Create a child span for database operation
            using (var dbActivity = _activitySource.StartActivity("CreateOrder.Database", ActivityKind.Internal))
            {
                dbActivity?.SetTag("db.operation", "insert");
                dbActivity?.SetTag("db.table", "Orders");

                // Simulate database insertion
                order.Id = Guid.NewGuid().ToString();
                order.Status = "Created";
                order.CreatedAt = DateTime.UtcNow;

                await SaveOrderToDatabase(order);

                dbActivity?.AddEvent(new ActivityEvent("Order saved to database"));
            }

            // Create a child span for messaging operation
            using (var messagingActivity = _activitySource.StartActivity("CreateOrder.PublishMessage", ActivityKind.Producer))
            {
                messagingActivity?.SetTag("messaging.system", "servicebus");
                messagingActivity?.SetTag("messaging.destination", "orders-queue");
                messagingActivity?.SetTag("messaging.operation", "publish");

                // Propagate trace context to Service Bus message
                await PublishOrderCreatedEvent(order, messagingActivity);

                messagingActivity?.AddEvent(new ActivityEvent("Order created event published"));
            }

            activity?.SetTag("orders.id", order.Id);
            activity?.AddEvent(new ActivityEvent("Order created successfully"));

            _logger.LogInformation("Order {OrderId} created successfully", order.Id);

            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);

            _logger.LogError(ex, "Error creating order");
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>
    /// Updates an existing order with distributed tracing.
    /// </summary>
    /// <param name="id">The order identifier.</param>
    /// <param name="order">The updated order data.</param>
    /// <returns>No content on success, 404 if order not found.</returns>
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateOrder(string id, [FromBody] Order order)
    {
        using var activity = _activitySource.StartActivity("UpdateOrder.BusinessLogic");

        try
        {
            activity?.SetTag("orders.id", id);
            activity?.SetTag("orders.operation", "update");

            _logger.LogInformation("Updating order {OrderId}", id);

            var existingOrder = await GetOrderFromDatabase(id);
            if (existingOrder == null)
            {
                activity?.SetTag("orders.found", false);
                _logger.LogWarning("Order {OrderId} not found for update", id);
                return NotFound();
            }

            // Create child span for database update
            using (var dbActivity = _activitySource.StartActivity("UpdateOrder.Database", ActivityKind.Internal))
            {
                dbActivity?.SetTag("db.operation", "update");
                dbActivity?.SetTag("db.table", "Orders");

                await UpdateOrderInDatabase(id, order);

                dbActivity?.AddEvent(new ActivityEvent("Order updated in database"));
            }

            activity?.AddEvent(new ActivityEvent("Order updated successfully"));
            _logger.LogInformation("Order {OrderId} updated successfully", id);

            return NoContent();
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);

            _logger.LogError(ex, "Error updating order {OrderId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>
    /// Deletes an order with distributed tracing.
    /// </summary>
    /// <param name="id">The order identifier.</param>
    /// <returns>No content on success, 404 if order not found.</returns>
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteOrder(string id)
    {
        using var activity = _activitySource.StartActivity("DeleteOrder.BusinessLogic");

        try
        {
            activity?.SetTag("orders.id", id);
            activity?.SetTag("orders.operation", "delete");

            _logger.LogInformation("Deleting order {OrderId}", id);

            var existingOrder = await GetOrderFromDatabase(id);
            if (existingOrder == null)
            {
                activity?.SetTag("orders.found", false);
                _logger.LogWarning("Order {OrderId} not found for deletion", id);
                return NotFound();
            }

            // Create child span for database deletion
            using (var dbActivity = _activitySource.StartActivity("DeleteOrder.Database", ActivityKind.Internal))
            {
                dbActivity?.SetTag("db.operation", "delete");
                dbActivity?.SetTag("db.table", "Orders");

                await DeleteOrderFromDatabase(id);

                dbActivity?.AddEvent(new ActivityEvent("Order deleted from database"));
            }

            activity?.AddEvent(new ActivityEvent("Order deleted successfully"));
            _logger.LogInformation("Order {OrderId} deleted successfully", id);

            return NoContent();
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.RecordException(ex);

            _logger.LogError(ex, "Error deleting order {OrderId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    // Private helper methods (replace with actual implementations)

    private Task<IEnumerable<Order>> GetOrdersFromDatabase()
    {
        // TODO: Implement actual database query
        return Task.FromResult(Enumerable.Empty<Order>());
    }

    private Task<Order?> GetOrderFromDatabase(string id)
    {
        // TODO: Implement actual database query
        return Task.FromResult<Order?>(null);
    }

    private Task SaveOrderToDatabase(Order order)
    {
        // TODO: Implement actual database insertion
        return Task.CompletedTask;
    }

    private Task UpdateOrderInDatabase(string id, Order order)
    {
        // TODO: Implement actual database update
        return Task.CompletedTask;
    }

    private Task DeleteOrderFromDatabase(string id)
    {
        // TODO: Implement actual database deletion
        return Task.CompletedTask;
    }

    private Task PublishOrderCreatedEvent(Order order, Activity? activity)
    {
        // TODO: Implement Service Bus message publishing with trace context propagation
        // Example: Include TraceId and SpanId in message properties for correlation
        // message.ApplicationProperties["Diagnostic-Id"] = Activity.Current?.Id;
        // message.ApplicationProperties["traceparent"] = Activity.Current?.TraceParent;
        return Task.CompletedTask;
    }
}

/// <summary>
/// Order data model.
/// </summary>
public class Order
{
    public string Id { get; set; } = string.Empty;
    public string CustomerId { get; set; } = string.Empty;
    public decimal TotalAmount { get; set; }
    public string Status { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
}