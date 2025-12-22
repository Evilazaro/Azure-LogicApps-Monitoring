using app.ServiceDefaults.CommonTypes;
using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Handlers;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Services.Interfaces;
using System.Text.Json;

namespace eShop.Orders.API.Services;

public class OrderService : IOrderService
{
    private readonly ILogger<OrderService> _logger;
    private static readonly List<Order> _orders = new();
    private readonly OrdersMessageHandler _ordersMessageHandler;

    public OrderService(ILogger<OrderService> logger, ServiceBusClient serviceBusClient)
    {
        _logger = logger;
        var _loggerHandler = new LoggerFactory().CreateLogger<IOrdersMessageHandler>();
        _ordersMessageHandler = new OrdersMessageHandler(_loggerHandler, serviceBusClient);
    }

    public Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Placing order with ID: {OrderId}", order.Id);

        if (string.IsNullOrWhiteSpace(order.Id))
        {
            throw new ArgumentException("Order ID is required", nameof(order));
        }

        if (_orders.Any(o => o.Id == order.Id))
        {
            throw new InvalidOperationException($"Order with ID {order.Id} already exists");
        }

        _orders.Add(order);
        _ordersMessageHandler.SendOrderMessageAsync(order,cancellationToken).GetAwaiter().GetResult();
        _logger.LogInformation("Order {OrderId} placed successfully", order.Id);

        return Task.FromResult(order);
    }

    public Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Placing batch of {Count} orders", orders.Count());

        var placedOrders = new List<Order>();

        foreach (var order in orders)
        {
            if (string.IsNullOrWhiteSpace(order.Id))
            {
                _logger.LogWarning("Skipping order with empty ID");
                continue;
            }

            if (_orders.Any(o => o.Id == order.Id))
            {
                _logger.LogWarning("Order with ID {OrderId} already exists, skipping", order.Id);
                continue;
            }

            _orders.Add(order);
            placedOrders.Add(order);
        }

        _logger.LogInformation("Batch processing complete. {Count} orders placed successfully", placedOrders.Count);

        return Task.FromResult<IEnumerable<Order>>(placedOrders);
    }

    public Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving all orders. Total count: {Count}", _orders.Count);
        var ordersReader = new StreamReader(Directory.GetCurrentDirectory() + "/Files/getOrders.json");
        var ordersJson = ordersReader.ReadToEnd();

        var options = new JsonSerializerOptions
        {
            PropertyNameCaseInsensitive = true
        };

        var result = JsonSerializer.Deserialize<List<Order>>(ordersJson, options) ?? [];
        return Task.FromResult<IEnumerable<Order>>(result);
    }

    public Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving order with ID: {OrderId}", orderId);

        var order = GetOrdersAsync(cancellationToken).Result.FirstOrDefault(o => o.Id == orderId);

        if (order == null)
        {
            _logger.LogWarning("Order with ID {OrderId} not found", orderId);
        }

        return Task.FromResult(order);
    }
}