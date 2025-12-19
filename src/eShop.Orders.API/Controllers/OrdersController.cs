using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Services.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace eShop.Orders.API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OrdersController : ControllerBase
{
    private readonly ILogger<OrdersController> _logger;
    private readonly IOrderService _orderService;

    public OrdersController(ILogger<OrdersController> logger, IOrderService orderService)
    {
        _logger = logger;
        _orderService = orderService;
    }

    [HttpPost]
    [ProducesResponseType(typeof(Order), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<Order>> PlaceOrder([FromBody] Order order, CancellationToken cancellationToken)
    {
        try
        {
            var placedOrder = await _orderService.PlaceOrderAsync(order, cancellationToken);
            return CreatedAtAction(nameof(GetOrderById), new { id = placedOrder.Id }, placedOrder);
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning(ex, "Invalid order data");
            return BadRequest(ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            _logger.LogWarning(ex, "Order already exists");
            return Conflict(ex.Message);
        }
    }

    [HttpPost("batch")]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<IEnumerable<Order>>> PlaceOrdersBatch([FromBody] IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        if (orders == null || !orders.Any())
        {
            return BadRequest("Orders collection cannot be empty");
        }

        var placedOrders = await _orderService.PlaceOrdersBatchAsync(orders, cancellationToken);
        return Ok(placedOrders);
    }

    [HttpGet]
    [ProducesResponseType(typeof(IEnumerable<Order>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IEnumerable<Order>>> GetOrders(CancellationToken cancellationToken)
    {
        var orders = await _orderService.GetOrdersAsync(cancellationToken);
        return Ok(orders);
    }

    [HttpGet("{id}")]
    [ProducesResponseType(typeof(Order), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<Order>> GetOrderById(string id, CancellationToken cancellationToken)
    {
        var order = await _orderService.GetOrderByIdAsync(id, cancellationToken);

        if (order == null)
        {
            return NotFound($"Order with ID {id} not found");
        }

        return Ok(order);
    }
}