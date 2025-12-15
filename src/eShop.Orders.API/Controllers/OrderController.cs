using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Services;
using Microsoft.AspNetCore.Mvc;
using System.Net.Mime;

namespace eShop.Orders.API.Controllers;

/// <summary>
/// API controller for managing orders
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
    /// <param name="order">The order details</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Accepted response with order details</returns>
    /// <response code="202">Order accepted for processing</response>
    /// <response code="400">Invalid order data</response>
    /// <response code="503">Service Bus unavailable</response>
    [HttpPost(Name = nameof(PlaceOrder))]
    [ProducesResponseType(typeof(Order), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status503ServiceUnavailable)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> PlaceOrder(
        [FromBody] Order order,
        CancellationToken cancellationToken)
    {
        if (order is null)
        {
            _logger.LogWarning("PlaceOrder called with null order");
            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid Request",
                detail: "Order cannot be null");
        }

        if (!ModelState.IsValid)
        {
            _logger.LogWarning("PlaceOrder called with invalid model state");
            return ValidationProblem(ModelState);
        }

        try
        {
            await _orderService.SendOrderMessageAsync(order, cancellationToken);
            _logger.LogInformation("Order {OrderId} placed successfully", order.Id);
            return Accepted(order);
        }
        catch (ServiceBusException ex) when (ex.Reason == ServiceBusFailureReason.ServiceTimeout ||
                                              ex.Reason == ServiceBusFailureReason.ServiceCommunicationProblem)
        {
            _logger.LogError(ex, "Service Bus unavailable while placing order {OrderId}", order.Id);
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Service Unavailable",
                detail: "The messaging service is temporarily unavailable. Please try again later.");
        }
        catch (ServiceBusException ex) when (ex.Reason == ServiceBusFailureReason.GeneralError)
        {
            _logger.LogError(ex, "General error occurred while placing order {OrderId}", order.Id);
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Configuration Error",
                detail: "There is a configuration issue with the messaging service.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while placing order {OrderId}", order.Id);
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while processing your request.");
        }
    }

    /// <summary>
    /// Retrieves all orders
    /// </summary>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of all orders</returns>
    /// <response code="200">Returns the list of orders</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("all", Name = nameof(GetAllOrders))]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<Order>>> GetAllOrders(CancellationToken cancellationToken)
    {
        try
        {
            var orders = await _orderService.GetAllOrdersAsync(cancellationToken);
            _logger.LogInformation("Retrieved {OrderCount} orders", orders.Count);
            return Ok(orders);
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "IO error while retrieving orders");
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Storage Error",
                detail: "An error occurred while accessing order storage.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving orders");
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while retrieving orders.");
        }
    }

    /// <summary>
    /// Retrieves a specific order by ID
    /// </summary>
    /// <param name="id">The order ID</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>The requested order</returns>
    /// <response code="200">Returns the order</response>
    /// <response code="404">Order not found</response>
    /// <response code="500">Internal server error</response>
    [HttpGet("{id:int}", Name = nameof(GetOrderById))]
    [ProducesResponseType(typeof(Order), StatusCodes.Status200OK)]
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
                detail: "Order ID must be greater than 0");
        }

        try
        {
            var order = await _orderService.GetOrderByIdAsync(id, cancellationToken);

            if (order is null)
            {
                _logger.LogWarning("Order {OrderId} not found", id);
                return Problem(
                    statusCode: StatusCodes.Status404NotFound,
                    title: "Not Found",
                    detail: $"Order with ID {id} was not found");
            }

            _logger.LogInformation("Order {OrderId} retrieved successfully", id);
            return Ok(order);
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "IO error while retrieving order {OrderId}", id);
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Storage Error",
                detail: "An error occurred while accessing order storage.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving order {OrderId}", id);
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while retrieving the order.");
        }
    }

    /// <summary>
    /// Places multiple orders in a batch
    /// </summary>
    /// <param name="orders">List of orders to place</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Accepted response</returns>
    /// <response code="202">Orders accepted for processing</response>
    /// <response code="400">Invalid order data</response>
    /// <response code="503">Service Bus unavailable</response>
    [HttpPost("batch", Name = nameof(PlaceOrdersBatch))]
    [ProducesResponseType(typeof(BatchOrderResponse), StatusCodes.Status202Accepted)]
    [ProducesResponseType(typeof(ValidationProblemDetails), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status503ServiceUnavailable)]
    [ProducesResponseType(typeof(ProblemDetails), StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> PlaceOrdersBatch(
        [FromBody] List<Order> orders,
        CancellationToken cancellationToken)
    {
        if (orders is null || orders.Count == 0)
        {
            _logger.LogWarning("PlaceOrdersBatch called with null or empty orders list");
            return Problem(
                statusCode: StatusCodes.Status400BadRequest,
                title: "Invalid Request",
                detail: "Orders list cannot be null or empty");
        }

        if (!ModelState.IsValid)
        {
            _logger.LogWarning("PlaceOrdersBatch called with invalid model state");
            return ValidationProblem(ModelState);
        }

        try
        {
            await _orderService.SendOrderBatchMessagesAsync(orders, cancellationToken);
            _logger.LogInformation("Batch of {OrderCount} orders placed successfully", orders.Count);

            var response = new BatchOrderResponse
            {
                Message = $"{orders.Count} orders accepted for processing",
                OrderCount = orders.Count,
                OrderIds = orders.Select(o => o.Id).ToList()
            };

            return Accepted(response);
        }
        catch (ServiceBusException ex) when (ex.Reason == ServiceBusFailureReason.ServiceTimeout ||
                                              ex.Reason == ServiceBusFailureReason.ServiceCommunicationProblem)
        {
            _logger.LogError(ex, "Service Bus unavailable while placing order batch");
            return Problem(
                statusCode: StatusCodes.Status503ServiceUnavailable,
                title: "Service Unavailable",
                detail: "The messaging service is temporarily unavailable. Please try again later.");
        }
        catch (ServiceBusException ex) when (ex.Reason == ServiceBusFailureReason.GeneralError)
        {
            _logger.LogError(ex, "Unauthorized access to Service Bus while placing order batch");
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Configuration Error",
                detail: "There is a configuration issue with the messaging service.");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while placing order batch");
            return Problem(
                statusCode: StatusCodes.Status500InternalServerError,
                title: "Internal Server Error",
                detail: "An unexpected error occurred while processing your request.");
        }
    }
}

/// <summary>
/// Response model for batch order operations
/// </summary>
public sealed record BatchOrderResponse
{
    /// <summary>
    /// Response message
    /// </summary>
    public required string Message { get; init; }

    /// <summary>
    /// Number of orders in the batch
    /// </summary>
    public required int OrderCount { get; init; }

    /// <summary>
    /// List of order IDs in the batch
    /// </summary>
    public required List<int> OrderIds { get; init; }
}
