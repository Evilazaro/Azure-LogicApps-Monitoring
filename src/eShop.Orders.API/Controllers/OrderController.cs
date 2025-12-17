using eShop.Orders.API.Models;
using eShop.Orders.API.Services;
using Microsoft.AspNetCore.Mvc;
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
    private readonly IOrderService _orderService;
    private static readonly ActivitySource _activitySource = Extensions.CreateActivitySource();

    /// <summary>
    /// Initializes a new instance of the OrdersController.
    /// </summary>
    /// <param name="logger">Logger for structured logging with trace correlation.</param>
    /// <param name="orderService">Service for managing order operations.</param>
    /// <exception cref="ArgumentNullException">Thrown when required dependencies are null.</exception>
    public OrdersController(ILogger<OrdersController> logger, IOrderService orderService)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _orderService = orderService ?? throw new ArgumentNullException(nameof(orderService));
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

            var orders = await _orderService.GetAllOrdersAsync();

            // Add result metrics to the span
            activity?.SetTag("orders.count", orders.Count);
            activity?.AddEvent(new ActivityEvent("Orders retrieved successfully"));

            return Ok(orders);
        }
        catch (Exception ex)
        {
            // Set span status to error and add exception details
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "Error retrieving orders");
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>
    /// Retrieves a specific order by ID with detailed tracing.
    /// </summary>
    /// <param name="id">The order identifier.</param>
    /// <returns>The requested order or 404 if not found.</returns>
    [HttpGet("{id:int}")]
    public async Task<ActionResult<Order>> GetOrder(int id)
    {
        using var activity = _activitySource.StartActivity("GetOrder.BusinessLogic");

        try
        {
            // Add order ID as a tag for trace filtering
            activity?.SetTag("orders.id", id);
            activity?.SetTag("orders.operation", "get");

            _logger.LogInformation("Retrieving order {OrderId}", id);

            var order = await _orderService.GetOrderByIdAsync(id);

            if (order == null)
            {
                activity?.SetTag("orders.found", false);
                activity?.AddEvent(new ActivityEvent("Order not found"));

                _logger.LogWarning("Order {OrderId} not found", id);
                return NotFound();
            }

            activity?.SetTag("orders.found", true);
            activity?.AddEvent(new ActivityEvent("Order retrieved successfully"));

            return Ok(order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

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
    [Route("PlaceOrder")]
    public async Task<ActionResult<Order>> PlaceOrder([FromBody] Order order)
    {
        using var activity = _activitySource.StartActivity("PlaceOrder.BusinessLogic");

        try
        {
            // Add order details as tags
            activity?.SetTag("orders.operation", "create");
            activity?.SetTag("orders.total_amount", order.Total);

            _logger.LogInformation("Creating new order for customer {OrderId}", order.Id);

            // Generate ID if not provided
            if (string.IsNullOrEmpty(order.Id))
            {
                order.Id = Guid.NewGuid().ToString(); // or use your ID generation logic
            }

            // Create a child span for messaging operation
            using (var messagingActivity = _activitySource.StartActivity("PlaceOrder.SendMessage", ActivityKind.Producer))
            {
                messagingActivity?.SetTag("messaging.system", "servicebus");
                messagingActivity?.SetTag("messaging.destination", "OrderPlaced");
                messagingActivity?.SetTag("messaging.operation", "publish");

                // Send order to Service Bus - this includes database persistence
                await _orderService.SendOrderMessageAsync(order);

                messagingActivity?.AddEvent(new ActivityEvent("Order created event published"));
            }

            activity?.SetTag("orders.id", order.Id);
            activity?.AddEvent(new ActivityEvent("Order created successfully"));

            _logger.LogInformation("Order {OrderId} created successfully", order.Id);

            // Return 201 Created with location header pointing to the created resource
            // Parse the ID to int for the route parameter, default to 0 if parsing fails
            int.TryParse(order.Id, out var orderId);
            return CreatedAtAction(nameof(GetOrder), new { id = orderId }, order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

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
    [HttpPut("{id:int}")]
    public async Task<IActionResult> UpdateOrder(int id, [FromBody] Order order)
    {
        using var activity = _activitySource.StartActivity("UpdateOrder.BusinessLogic");

        try
        {
            activity?.SetTag("orders.id", id);
            activity?.SetTag("orders.operation", "update");

            _logger.LogInformation("Updating order {OrderId}", id);

            var existingOrder = await _orderService.GetOrderByIdAsync(id);
            if (existingOrder == null)
            {
                activity?.SetTag("orders.found", false);
                _logger.LogWarning("Order {OrderId} not found for update", id);
                return NotFound();
            }

            // Update order and send message
            order.Id = id.ToString();
            await _orderService.SendOrderMessageAsync(order);

            activity?.AddEvent(new ActivityEvent("Order updated successfully"));
            _logger.LogInformation("Order {OrderId} updated successfully", id);

            return NoContent();
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "Error updating order {OrderId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

    /// <summary>
    /// Deletes an order with distributed tracing.
    /// </summary>
    /// <param name="id">The order identifier.</param>
    /// <returns>No content on success, 404 if order not found.</returns>
    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteOrder(int id)
    {
        using var activity = _activitySource.StartActivity("DeleteOrder.BusinessLogic");

        try
        {
            activity?.SetTag("orders.id", id);
            activity?.SetTag("orders.operation", "delete");

            _logger.LogInformation("Deleting order {OrderId}", id);

            var existingOrder = await _orderService.GetOrderByIdAsync(id);
            if (existingOrder == null)
            {
                activity?.SetTag("orders.found", false);
                _logger.LogWarning("Order {OrderId} not found for deletion", id);
                return NotFound();
            }

            // Delete the order
            await _orderService.DeleteOrderAsync(id);

            activity?.SetTag("orders.deleted", true);
            activity?.AddEvent(new ActivityEvent("Order deleted successfully"));
            _logger.LogInformation("Order {OrderId} deleted successfully", id);

            return NoContent();
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "Error deleting order {OrderId}", id);
            return StatusCode(500, "Internal server error");
        }
    }

}

