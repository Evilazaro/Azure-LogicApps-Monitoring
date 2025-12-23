using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace eShop.Orders.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ILogger<OrdersController> _logger;
    private readonly IOrderService _orderService;
    private static readonly ActivitySource ActivitySource = new("eShop.Orders.API");

    public OrdersController(ILogger<OrdersController> logger, IOrderService orderService)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _orderService = orderService ?? throw new ArgumentNullException(nameof(orderService));
    }

    [HttpPost]
    [ProducesResponseType(typeof(Order), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<Order>> PlaceOrder([FromBody] Order order, CancellationToken cancellationToken)
    {
        if (order == null)
        {
            return BadRequest("Order cannot be null");
        }

        using var activity = ActivitySource.StartActivity("PlaceOrder", ActivityKind.Server);
        activity?.SetTag("order.id", order.Id);
        activity?.SetTag("order.customer_id", order.CustomerId);
        activity?.SetTag("order.total", order.Total);
        activity?.SetTag("order.products.count", order.Products?.Count ?? 0);
        activity?.SetTag("http.method", "POST");
        activity?.SetTag("http.route", "/api/orders");

        // Add trace ID to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none"
        });

        try
        {
            var placedOrder = await _orderService.PlaceOrderAsync(order, cancellationToken);
            activity?.SetStatus(ActivityStatusCode.Ok);
            return CreatedAtAction(nameof(GetOrderById), new { id = placedOrder.Id }, placedOrder);
        }
        catch (ArgumentException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, "Validation failed");
            _logger.LogWarning(ex, "Invalid order data for order {OrderId}", order.Id);
            return BadRequest(new { error = ex.Message, orderId = order.Id });
        }
        catch (InvalidOperationException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, "Order already exists");
            _logger.LogWarning(ex, "Order {OrderId} already exists", order.Id);
            return Conflict(new { error = ex.Message, orderId = order.Id });
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while placing order {OrderId}", order.Id);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", orderId = order.Id });
        }
    }

    [HttpPost("batch")]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<Order>>> PlaceOrdersBatch([FromBody] IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        if (orders == null || !orders.Any())
        {
            return BadRequest("Orders collection cannot be null or empty");
        }

        using var activity = ActivitySource.StartActivity("PlaceOrdersBatch", ActivityKind.Server);
        var ordersList = orders.ToList();
        activity?.SetTag("orders.count", ordersList.Count);
        activity?.SetTag("http.method", "POST");
        activity?.SetTag("http.route", "/api/orders/batch");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none"
        });

        try
        {
            var placedOrders = await _orderService.PlaceOrdersBatchAsync(ordersList, cancellationToken);
            activity?.SetStatus(ActivityStatusCode.Ok);
            return Ok(placedOrders);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while placing batch of orders");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request" });
        }
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders(CancellationToken cancellationToken)
    {
        using var activity = ActivitySource.StartActivity("GetOrders", ActivityKind.Server);
        activity?.SetTag("http.method", "GET");
        activity?.SetTag("http.route", "/api/orders");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none"
        });

        try
        {
            var orders = await _orderService.GetOrdersAsync(cancellationToken);
            activity?.SetStatus(ActivityStatusCode.Ok);
            return Ok(orders);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while retrieving orders");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request" });
        }
    }

    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Order), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<Order>> GetOrderById(string id, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return BadRequest(new { error = "Order ID cannot be empty" });
        }

        using var activity = ActivitySource.StartActivity("GetOrderById", ActivityKind.Server);
        activity?.SetTag("order.id", id);
        activity?.SetTag("http.method", "GET");
        activity?.SetTag("http.route", "/api/orders/{id}");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["OrderId"] = id
        });

        try
        {
            var order = await _orderService.GetOrderByIdAsync(id, cancellationToken);

            if (order == null)
            {
                activity?.SetStatus(ActivityStatusCode.Error, "Order not found");
                return NotFound(new { error = $"Order with ID {id} not found", orderId = id });
            }

            activity?.SetStatus(ActivityStatusCode.Ok);
            return Ok(order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while retrieving order {OrderId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", orderId = id });
        }
    }

    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult> DeleteOrder(string id, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            return BadRequest(new { error = "Order ID cannot be empty" });
        }

        using var activity = ActivitySource.StartActivity("DeleteOrder", ActivityKind.Server);
        activity?.SetTag("order.id", id);
        activity?.SetTag("http.method", "DELETE");
        activity?.SetTag("http.route", "/api/orders/{id}");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["OrderId"] = id
        });

        try
        {
            // First check if order exists
            var order = await _orderService.GetOrderByIdAsync(id, cancellationToken);
            if (order == null)
            {
                activity?.SetStatus(ActivityStatusCode.Error, "Order not found");
                return NotFound(new { error = $"Order with ID {id} not found", orderId = id });
            }

            // Delete the order
            var deleted = await _orderService.DeleteOrderAsync(id, cancellationToken);
            
            if (deleted)
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
                _logger.LogInformation("Successfully deleted order {OrderId}", id);
                return NoContent();
            }
            else
            {
                activity?.SetStatus(ActivityStatusCode.Error, "Failed to delete order");
                return StatusCode(StatusCodes.Status500InternalServerError,
                    new { error = "Failed to delete order", orderId = id });
            }
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while deleting order {OrderId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", orderId = id });
        }
    }
}