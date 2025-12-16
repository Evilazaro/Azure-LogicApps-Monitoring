using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Models;
using eShop.Orders.API.Services;
using Microsoft.AspNetCore.Mvc;
using System.Net.Mime;

namespace eShop.Orders.API.Controllers;

/// <summary>
/// API controller for managing orders with comprehensive error handling and validation
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Produces(MediaTypeNames.Application.Json)]
[Consumes(MediaTypeNames.Application.Json)]
public sealed class OrderController : ControllerBase
{
    private readonly IOrderService _orderService;
    private readonly ILogger<OrderController> _logger;

    /// <summary>
    /// Initializes a new instance of the OrderController
    /// </summary>
    /// <param name="orderService">Service for order operations</param>
    /// <param name="logger">Logger for diagnostics</param>
    /// <exception cref="ArgumentNullException">Thrown when required dependencies are null</exception>
    public OrderController(
        IOrderService orderService,
        ILogger<OrderController> logger)
    {
        _orderService = orderService ?? throw new ArgumentNullException(nameof(orderService));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Places a new order
    /// </summary>
    /// <param name="order">The order details with validated properties</param>
    /// <param name="cancellationToken">Cancellation token for async operations</param>
    /// <returns>Accepted response with order details and location header</returns>
    /// <response code="202">Order accepted for processing</response>
    /// <response code="400">Invalid order data - validation errors</response>
    /// <response code="503">Service Bus unavailable - temporary issue</response>
    /// <response code="500">Internal server error - unexpected issue</response>
    [HttpPost(Name = nameof(PlaceOrder))]
    [ProducesResponseType(typeof(Order), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status503ServiceUnavailable)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<Order>> PlaceOrder(
        [FromBody] Order order,
        CancellationToken cancellationToken)
    {
        // Model validation is handled by [ApiController] attribute automatically
        if (!ModelState.IsValid)
        {
            _logger.LogWarning("Invalid order data received for OrderId: {OrderId}", order?.Id);
            return ValidationProblem(ModelState);
        }

        try
        {
            await _orderService.SendOrderMessageAsync(order, cancellationToken);

            _logger.LogInformation(
                "Order placed successfully. OrderId: {OrderId}, CustomerId: {CustomerId}, Amount: {Amount:C}",
                order.Id,
                order.CustomerId,
                order.TotalAmount);

            return AcceptedAtAction(
                nameof(GetOrderById),
                new { id = order.Id },
                order);
        }
        catch (ServiceBusException ex) when (
            ex.Reason == ServiceBusFailureReason.ServiceTimeout ||
            ex.Reason == ServiceBusFailureReason.ServiceCommunicationProblem)
        {
            _logger.LogError(
                ex,
                "Service Bus temporarily unavailable. OrderId: {OrderId}, Reason: {Reason}",
                order.Id,
                ex.Reason);

            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Service Unavailable",
                detail: "The messaging service is temporarily unavailable. Please try again later.",
                instance: HttpContext.Request.Path);
        }
        catch (ServiceBusException ex)
        {
            _logger.LogError(
                ex,
                "Service Bus error occurred. OrderId: {OrderId}, Reason: {Reason}",
                order.Id,
                ex.Reason);

            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Messaging Error",
                detail: "An error occurred with the messaging service.",
                instance: HttpContext.Request.Path);
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("Order placement cancelled. OrderId: {OrderId}", order.Id);

            return Problem(
                statusCode: StatusCodes.Status499ClientClosedRequest,
                title: "Request Cancelled",
                detail: "The request was cancelled by the client.",
                instance: HttpContext.Request.Path);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error placing order. OrderId: {OrderId}", order.Id);

            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while processing your request.",
                instance: HttpContext.Request.Path);
        }
    }

    /// <summary>
    /// Retrieves all orders sorted by date descending
    /// </summary>
    /// <param name="cancellationToken">Cancellation token for async operations</param>
    /// <returns>List of all orders</returns>
    /// <response code="200">Returns the list of orders</response>
    /// <response code="500">Internal server error</response>
    [HttpGet(Name = nameof(GetAllOrders))]
    [ProducesResponseType(typeof(IReadOnlyList<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IReadOnlyList<Order>>> GetAllOrders(CancellationToken cancellationToken)
    {
        try
        {
            var orders = await _orderService.GetAllOrdersAsync(cancellationToken);

            _logger.LogInformation("Retrieved {OrderCount} orders", orders.Count);

            return Ok(orders);
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("Get all orders request cancelled");

            return Problem(
                statusCode: StatusCodes.Status499ClientClosedRequest,
                title: "Request Cancelled",
                detail: "The request was cancelled by the client.",
                instance: HttpContext.Request.Path);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error retrieving all orders");

            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while retrieving orders.",
                instance: HttpContext.Request.Path);
        }
    }

    /// <summary>
    /// Retrieves a specific order by its unique identifier
    /// </summary>
    /// <param name="id">The order ID (must be positive integer)</param>
    /// <param name="cancellationToken">Cancellation token for async operations</param>
    /// <returns>The requested order</returns>
    /// <response code="200">Returns the order</response>
    /// <response code="400">Invalid order ID (not positive)</response>
    /// <response code="404">Order not found</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("{id:int}", Name = nameof(GetOrderById))]
    [ProducesResponseType(typeof(Order), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<Order>> GetOrderById(int id, CancellationToken cancellationToken)
    {
        if (id <= 0)
        {
            _logger.LogWarning("GetOrderById called with invalid ID: {OrderId}", id);

            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid Request",
                detail: "Order ID must be greater than 0",
                instance: HttpContext.Request.Path);
        }

        try
        {
            var order = await _orderService.GetOrderByIdAsync(id, cancellationToken);

            if (order is null)
            {
                _logger.LogInformation("Order not found. OrderId: {OrderId}", id);

                return Problem(
                    statusCode: StatusCodes.Status404NotFound,
                    title: "Not Found",
                    detail: $"Order with ID {id} was not found",
                    instance: HttpContext.Request.Path);
            }

            _logger.LogDebug("Order retrieved successfully. OrderId: {OrderId}", id);

            return Ok(order);
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("Get order by ID request cancelled. OrderId: {OrderId}", id);

            return Problem(
                statusCode: StatusCodes.Status499ClientClosedRequest,
                title: "Request Cancelled",
                detail: "The request was cancelled by the client.",
                instance: HttpContext.Request.Path);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error retrieving order. OrderId: {OrderId}", id);

            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while retrieving the order.",
                instance: HttpContext.Request.Path);
        }
    }

    /// <summary>
    /// Places multiple orders in a batch operation for improved throughput
    /// </summary>
    /// <param name="orders">List of orders to place (must not be empty)</param>
    /// <param name="cancellationToken">Cancellation token for async operations</param>
    /// <returns>Accepted response with batch summary</returns>
    /// <response code="202">Orders accepted for processing</response>
    /// <response code="400">Invalid order data or empty list</response>
    /// <response code="503">Service Bus unavailable</response>
    /// <response code="500">Internal server error</response>
    [HttpPost("batch", Name = nameof(PlaceOrdersBatch))]
    [ProducesResponseType(typeof(BatchOrderResponse), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status503ServiceUnavailable)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<BatchOrderResponse>> PlaceOrdersBatch(
        [FromBody] IReadOnlyList<Order> orders,
        CancellationToken cancellationToken)
    {
        if (orders is null || orders.Count == 0)
        {
            _logger.LogWarning("PlaceOrdersBatch called with null or empty orders list");

            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid Request",
                detail: "Orders list cannot be null or empty",
                instance: HttpContext.Request.Path);
        }

        // Validate each order in the batch
        if (!ModelState.IsValid)
        {
            _logger.LogWarning("Invalid order data in batch request");
            return ValidationProblem(ModelState);
        }

        try
        {
            await _orderService.SendOrderBatchMessagesAsync(orders, cancellationToken);

            _logger.LogInformation(
                "Batch of {OrderCount} orders placed successfully. OrderIds: [{OrderIds}]",
                orders.Count,
                string.Join(", ", orders.Select(o => o.Id)));

            var response = new BatchOrderResponse
            {
                Message = $"{orders.Count} orders accepted for processing",
                OrderCount = orders.Count,
                OrderIds = orders.Select(o => o.Id).ToList()
            };

            return Accepted(response);
        }
        catch (ServiceBusException ex) when (
            ex.Reason == ServiceBusFailureReason.ServiceTimeout ||
            ex.Reason == ServiceBusFailureReason.ServiceCommunicationProblem)
        {
            _logger.LogError(
                ex,
                "Service Bus temporarily unavailable during batch operation. OrderCount: {Count}",
                orders.Count);

            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Service Unavailable",
                detail: "The messaging service is temporarily unavailable. Please try again later.",
                instance: HttpContext.Request.Path);
        }
        catch (ServiceBusException ex)
        {
            _logger.LogError(
                ex,
                "Service Bus error during batch operation. OrderCount: {Count}, Reason: {Reason}",
                orders.Count,
                ex.Reason);

            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Messaging Error",
                detail: "An error occurred with the messaging service.",
                instance: HttpContext.Request.Path);
        }
        catch (OperationCanceledException)
        {
            _logger.LogWarning("Batch order placement cancelled. OrderCount: {Count}", orders.Count);

            return Problem(
                statusCode: StatusCodes.Status499ClientClosedRequest,
                title: "Request Cancelled",
                detail: "The request was cancelled by the client.",
                instance: HttpContext.Request.Path);
        }
        catch (Exception ex)
        {
            _logger.LogError(
                ex,
                "Unexpected error placing order batch. OrderCount: {Count}",
                orders.Count);

            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while processing your request.",
                instance: HttpContext.Request.Path);
        }
    }
}

/// <summary>
/// Response model for batch order operations
/// </summary>
public sealed record BatchOrderResponse
{
    /// <summary>
    /// Gets the response message indicating batch status
    /// </summary>
    public required string Message { get; init; }

    /// <summary>
    /// Gets the number of orders in the batch
    /// </summary>
    public required int OrderCount { get; init; }

    /// <summary>
    /// Gets the list of order IDs that were processed
    /// </summary>
    public required List<int> OrderIds { get; init; }
}