using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace eShop.Orders.API.Controllers;

/// <summary>
/// API controller for managing customer orders including placement, retrieval, and deletion.
/// </summary>
[ApiController]
[Route("api/[controller]")]
public sealed class OrdersController : ControllerBase
{
    private readonly ILogger<OrdersController> _logger;
    private readonly IOrderService _orderService;
    private readonly ActivitySource _activitySource;

    /// <summary>
    /// Initializes a new instance of the <see cref="OrdersController"/> class.
    /// </summary>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <param name="orderService">The service for order operations.</param>
    /// <param name="activitySource">The activity source for distributed tracing.</param>
    /// <exception cref="ArgumentNullException">Thrown when any parameter is null.</exception>
    public OrdersController(
        ILogger<OrdersController> logger,
        IOrderService orderService,
        ActivitySource activitySource)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _orderService = orderService ?? throw new ArgumentNullException(nameof(orderService));
        _activitySource = activitySource ?? throw new ArgumentNullException(nameof(activitySource));
    }

    /// <summary>
    /// Places a new order in the system.
    /// </summary>
    /// <param name="order">The order details to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The created order with status information.</returns>
    /// <response code="201">Returns the newly created order.</response>
    /// <response code="400">If the order data is invalid.</response>
    /// <response code="409">If an order with the same ID already exists.</response>
    /// <response code="500">If an internal server error occurs.</response>
    [HttpPost]
    [ProducesResponseType(typeof(Order), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<Order>> PlaceOrder([FromBody] Order? order, CancellationToken cancellationToken)
    {
        if (order is null)
        {
            return BadRequest(new { error = "Order payload is required", type = "ValidationError" });
        }

        // ModelState validation is automatically handled by [ApiController] attribute
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        using var activity = _activitySource.StartActivity("PlaceOrder", ActivityKind.Server);
        activity?.SetTag("order.id", order.Id);
        activity?.SetTag("order.total", order.Total);
        activity?.SetTag("order.products.count", order.Products?.Count ?? 0);
        activity?.SetTag("http.method", "POST");
        activity?.SetTag("http.route", "/api/orders");
        activity?.SetTag("http.request.method", "POST");
        activity?.SetTag("url.path", "/api/orders");

        // Add trace ID to log scope for correlation
        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none",
            ["OrderId"] = order.Id
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
            activity?.SetTag("error.type", nameof(ArgumentException));
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogWarning(ex, "Invalid order data for order {OrderId}", order.Id);
            return BadRequest(new { error = ex.Message, orderId = order.Id, type = "ValidationError" });
        }
        catch (InvalidOperationException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, "Order already exists");
            activity?.SetTag("error.type", nameof(InvalidOperationException));
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogWarning(ex, "Order {OrderId} already exists", order.Id);
            return Conflict(new { error = ex.Message, orderId = order.Id, type = "ConflictError" });
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.SetTag("error.type", ex.GetType().Name);
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Unexpected error while placing order {OrderId}", order.Id);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", orderId = order.Id, type = "InternalError" });
        }
    }

    /// <summary>
    /// Places multiple orders in a single batch operation.
    /// </summary>
    /// <param name="orders">The collection of orders to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The collection of successfully placed orders.</returns>
    /// <response code="200">Returns the successfully placed orders.</response>
    /// <response code="400">If the orders collection is invalid.</response>
    /// <response code="500">If an internal server error occurs.</response>
    [HttpPost("batch")]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<Order>>> PlaceOrdersBatch([FromBody] IEnumerable<Order>? orders, CancellationToken cancellationToken)
    {
        if (orders is null)
        {
            return BadRequest(new { error = "Orders collection is required", type = "ValidationError" });
        }

        var ordersList = orders.ToList();
        if (ordersList.Count == 0)
        {
            return BadRequest(new { error = "Orders collection cannot be empty", type = "ValidationError" });
        }

        using var activity = _activitySource.StartActivity("PlaceOrdersBatch", ActivityKind.Server);
        activity?.SetTag("orders.count", ordersList.Count);
        activity?.SetTag("http.method", "POST");
        activity?.SetTag("http.route", "/api/orders/batch");
        activity?.SetTag("http.request.method", "POST");
        activity?.SetTag("url.path", "/api/orders/batch");

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
            activity?.SetTag("error.type", ex.GetType().Name);
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Unexpected error while placing batch of orders");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", type = "InternalError" });
        }
    }

    [HttpPost]
    [ProducesResponseType(typeof(Order), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public Task<ActionResult<Order>> ProcessOrder([FromBody] Order? order, CancellationToken cancellationToken)
    {
        return Task.FromResult<ActionResult<Order>>(Ok(order));
    }

    /// <summary>
    /// Retrieves all orders from the system.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of all orders.</returns>
    /// <response code="200">Returns all orders in the system.</response>
    /// <response code="500">If an internal server error occurs.</response>
    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders(CancellationToken cancellationToken)
    {
        using var activity = _activitySource.StartActivity("GetOrders", ActivityKind.Server);
        activity?.SetTag("http.method", "GET");
        activity?.SetTag("http.route", "/api/orders");
        activity?.SetTag("http.request.method", "GET");
        activity?.SetTag("url.path", "/api/orders");

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
            activity?.SetTag("error.type", ex.GetType().Name);
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Unexpected error while retrieving orders");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", type = "InternalError" });
        }
    }

    /// <summary>
    /// Retrieves a specific order by its unique identifier.
    /// </summary>
    /// <param name="id">The unique identifier of the order.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The order matching the specified ID, or 404 if not found.</returns>
    /// <response code="200">Returns the requested order.</response>
    /// <response code="400">If the order ID is invalid.</response>
    /// <response code="404">If the order is not found.</response>
    /// <response code="500">If an internal server error occurs.</response>
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

        using var activity = _activitySource.StartActivity("GetOrderById", ActivityKind.Server);
        activity?.SetTag("order.id", id);
        activity?.SetTag("http.method", "GET");
        activity?.SetTag("http.route", "/api/orders/{id}");
        activity?.SetTag("http.request.method", "GET");
        activity?.SetTag("url.path", $"/api/orders/{id}");

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
                return NotFound(new { error = $"Order with ID {id} not found", orderId = id, type = "NotFoundError" });
            }

            activity?.SetStatus(ActivityStatusCode.Ok);
            return Ok(order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.SetTag("error.type", ex.GetType().Name);
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Unexpected error while retrieving order {OrderId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", orderId = id, type = "InternalError" });
        }
    }

    /// <summary>
    /// Deletes an order from the system.
    /// </summary>
    /// <param name="id">The unique identifier of the order to delete.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>No content on successful deletion.</returns>
    /// <response code="204">If the order was successfully deleted.</response>
    /// <response code="400">If the order ID is invalid.</response>
    /// <response code="404">If the order is not found.</response>
    /// <response code="500">If an internal server error occurs.</response>
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

        using var activity = _activitySource.StartActivity("DeleteOrder", ActivityKind.Server);
        activity?.SetTag("order.id", id);
        activity?.SetTag("http.method", "DELETE");
        activity?.SetTag("http.route", "/api/orders/{id}");
        activity?.SetTag("http.request.method", "DELETE");
        activity?.SetTag("url.path", $"/api/orders/{id}");

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
                return NotFound(new { error = $"Order with ID {id} not found", orderId = id, type = "NotFoundError" });
            }

            // Delete the order
            var deleted = await _orderService.DeleteOrderAsync(id, cancellationToken);

            if (deleted)
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
                _logger.LogInformation("Successfully deleted order {OrderId}", id);
                return NoContent();
            }

            activity?.SetStatus(ActivityStatusCode.Error, "Failed to delete order");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "Failed to delete order", orderId = id, type = "InternalError" });
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.SetTag("error.type", ex.GetType().Name);
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Unexpected error while deleting order {OrderId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", orderId = id, type = "InternalError" });
        }
    }

    /// <summary>
    /// Deletes multiple orders in batch.
    /// </summary>
    /// <param name="orderIds">The collection of order IDs to delete.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    /// <returns>The number of successfully deleted orders.</returns>
    [HttpPost("batch/delete")]
    [ProducesResponseType(typeof(int), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<int>> DeleteOrdersBatch([FromBody] IEnumerable<string>? orderIds, CancellationToken cancellationToken)
    {
        if (orderIds is null)
        {
            return BadRequest(new { error = "Order IDs collection is required", type = "ValidationError" });
        }

        var orderIdsList = orderIds.ToList();
        if (orderIdsList.Count == 0)
        {
            return BadRequest(new { error = "Order IDs collection cannot be empty", type = "ValidationError" });
        }

        using var activity = _activitySource.StartActivity("DeleteOrdersBatch", ActivityKind.Server);
        activity?.SetTag("orders.count", orderIdsList.Count);
        activity?.SetTag("http.method", "POST");
        activity?.SetTag("http.route", "/api/orders/batch/delete");
        activity?.SetTag("http.request.method", "POST");
        activity?.SetTag("url.path", "/api/orders/batch/delete");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none"
        });

        try
        {
            var deletedCount = await _orderService.DeleteOrdersBatchAsync(orderIdsList, cancellationToken);
            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Successfully deleted {DeletedCount} orders out of {TotalCount}", deletedCount, orderIdsList.Count);
            return Ok(deletedCount);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.SetTag("error.type", ex.GetType().Name);
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Failed to delete orders batch");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "Failed to delete orders", message = ex.Message, type = "InternalError" });
        }
    }

    /// <summary>
    /// Retrieves all messages metadata from topics.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of message metadata from all topics.</returns>
    /// <response code="200">Returns all messages metadata from topics.</response>
    /// <response code="500">If an internal server error occurs.</response>
    [HttpGet("messages")]
    [ProducesResponseType(typeof(IEnumerable<object>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<object>>> ListMessagesFromTopics(CancellationToken cancellationToken)
    {
        using var activity = _activitySource.StartActivity("ListMessagesFromTopics", ActivityKind.Server);
        activity?.SetTag("http.method", "GET");
        activity?.SetTag("http.route", "/api/orders/messages");
        activity?.SetTag("http.request.method", "GET");
        activity?.SetTag("url.path", "/api/orders/messages");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "none"
        });

        try
        {
            var messages = await _orderService.ListMessagesFromTopicsAsync(cancellationToken);
            activity?.SetStatus(ActivityStatusCode.Ok);
            int messageCount = messages is ICollection<object> coll ? coll.Count : (messages is not null ? messages.Count() : 0);
            _logger.LogInformation(
                "Successfully retrieved {MessageCount} messages from topics",
                messageCount);
            return Ok(messages);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.SetTag("error.type", ex.GetType().Name);
            activity?.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "exception.message", ex.Message }
            }));
            _logger.LogError(ex, "Unexpected error while retrieving messages from topics");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { error = "An error occurred while processing your request", type = "InternalError" });
        }
    }
}