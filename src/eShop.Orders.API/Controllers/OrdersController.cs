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
        using var activity = ActivitySource.StartActivity("PlaceOrder", ActivityKind.Server);
        activity?.SetTag("order.id", order.Id);

        if (order == null)
        {
            return BadRequest("Order cannot be null");
        }

        try
        {
            var placedOrder = await _orderService.PlaceOrderAsync(order, cancellationToken);
            return CreatedAtAction(nameof(GetOrderById), new { id = placedOrder.Id }, placedOrder);
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning(ex, "Invalid order data for order {OrderId}", order.Id);
            return BadRequest(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "Order {OrderId} already exists", order.Id);
            return Conflict(ex.Message);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while placing order {OrderId}", order.Id);
            return StatusCode(StatusCodes.Status500InternalServerError, "An error occurred while processing your request");
        }
    }

    [HttpPost("batch")]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<Order>>> PlaceOrdersBatch([FromBody] IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        using var activity = ActivitySource.StartActivity("PlaceOrdersBatch", ActivityKind.Server);

        if (orders == null || !orders.Any())
        {
            return BadRequest("Orders collection cannot be null or empty");
        }

        var ordersList = orders.ToList();
        activity?.SetTag("orders.count", ordersList.Count);

        try
        {
            var placedOrders = await _orderService.PlaceOrdersBatchAsync(ordersList, cancellationToken);
            return Ok(placedOrders);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while placing batch of orders");
            return StatusCode(StatusCodes.Status500InternalServerError, "An error occurred while processing your request");
        }
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders(CancellationToken cancellationToken)
    {
        using var activity = ActivitySource.StartActivity("GetOrders", ActivityKind.Server);

        try
        {
            var orders = await _orderService.GetOrdersAsync(cancellationToken);
            return Ok(orders);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving orders");
            return StatusCode(StatusCodes.Status500InternalServerError, "An error occurred while processing your request");
        }
    }

    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Order), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<ActionResult<Order>> GetOrderById(string id, CancellationToken cancellationToken)
    {
        using var activity = ActivitySource.StartActivity("GetOrderById", ActivityKind.Server);
        activity?.SetTag("order.id", id);

        if (string.IsNullOrWhiteSpace(id))
        {
            return BadRequest("Order ID cannot be empty");
        }

        try
        {
            var order = await _orderService.GetOrderByIdAsync(id, cancellationToken);

            if (order == null)
            {
                return NotFound($"Order with ID {id} not found");
            }

            return Ok(order);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while retrieving order {OrderId}", id);
            return StatusCode(StatusCodes.Status500InternalServerError, "An error occurred while processing your request");
        }
    }
}