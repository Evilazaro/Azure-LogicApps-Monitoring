using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Services.Interfaces;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text.Json;

namespace eShop.Orders.API.Services;

public class OrderService : IOrderService
{
    private readonly ILogger<OrderService> _logger;
    private readonly ConcurrentDictionary<string, Order> _orders = new();
    private readonly IOrdersMessageHandler _ordersMessageHandler;
    private readonly IWebHostEnvironment _environment;
    private static readonly ActivitySource ActivitySource = new("eShop.Orders.API");

    public OrderService(
        ILogger<OrderService> logger,
        IOrdersMessageHandler ordersMessageHandler,
        IWebHostEnvironment environment)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _ordersMessageHandler = ordersMessageHandler ?? throw new ArgumentNullException(nameof(ordersMessageHandler));
        _environment = environment ?? throw new ArgumentNullException(nameof(environment));
    }

    public async Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity("PlaceOrder", ActivityKind.Internal);
        activity?.SetTag("order.id", order.Id);

        _logger.LogInformation("Placing order with ID: {OrderId}", order.Id);

        if (string.IsNullOrWhiteSpace(order.Id))
        {
            throw new ArgumentException("Order ID is required", nameof(order));
        }

        if (!_orders.TryAdd(order.Id, order))
        {
            throw new InvalidOperationException($"Order with ID {order.Id} already exists");
        }

        try
        {
            await _ordersMessageHandler.SendOrderMessageAsync(order, cancellationToken).ConfigureAwait(false);
            _logger.LogInformation("Order {OrderId} placed successfully", order.Id);
            return order;
        }
        catch (Exception ex)
        {
            // Rollback the order addition if message sending fails
            _orders.TryRemove(order.Id, out _);
            _logger.LogError(ex, "Failed to send order message for order {OrderId}", order.Id);
            throw;
        }
    }

    public async Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity("PlaceOrdersBatch", ActivityKind.Internal);
        
        var ordersList = orders.ToList();
        activity?.SetTag("orders.count", ordersList.Count);

        _logger.LogInformation("Placing batch of {Count} orders", ordersList.Count);

        var placedOrders = new List<Order>();

        foreach (var order in ordersList)
        {
            if (string.IsNullOrWhiteSpace(order.Id))
            {
                _logger.LogWarning("Skipping order with empty ID");
                continue;
            }

            if (!_orders.TryAdd(order.Id, order))
            {
                _logger.LogWarning("Order with ID {OrderId} already exists, skipping", order.Id);
                continue;
            }

            placedOrders.Add(order);
        }

        if (placedOrders.Count > 0)
        {
            try
            {
                await _ordersMessageHandler.SendOrdersBatchMessageAsync(placedOrders, cancellationToken).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to send batch order messages");
                // Rollback orders
                foreach (var order in placedOrders)
                {
                    _orders.TryRemove(order.Id, out _);
                }
                throw;
            }
        }

        _logger.LogInformation("Batch processing complete. {Count} orders placed successfully", placedOrders.Count);

        return placedOrders;
    }

    public async Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity("GetOrders", ActivityKind.Internal);

        _logger.LogInformation("Retrieving all orders. Total count: {Count}", _orders.Count);

        var filePath = Path.Combine(_environment.ContentRootPath, "Files", "getOrders.json");

        if (!File.Exists(filePath))
        {
            _logger.LogWarning("Orders file not found at {FilePath}", filePath);
            return Enumerable.Empty<Order>();
        }

        try
        {
            var ordersJson = await File.ReadAllTextAsync(filePath, cancellationToken).ConfigureAwait(false);

            var options = new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            };

            var result = JsonSerializer.Deserialize<List<Order>>(ordersJson, options) ?? new List<Order>();
            activity?.SetTag("orders.retrieved.count", result.Count);
            return result;
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to deserialize orders from file {FilePath}", filePath);
            throw;
        }
    }

    public async Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity("GetOrderById", ActivityKind.Internal);
        activity?.SetTag("order.id", orderId);

        _logger.LogInformation("Retrieving order with ID: {OrderId}", orderId);

        var orders = await GetOrdersAsync(cancellationToken).ConfigureAwait(false);
        var order = orders.FirstOrDefault(o => o.Id == orderId);

        if (order == null)
        {
            _logger.LogWarning("Order with ID {OrderId} not found", orderId);
        }

        return order;
    }
}