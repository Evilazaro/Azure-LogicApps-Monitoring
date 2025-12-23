using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Services.Interfaces;
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace eShop.Orders.API.Services;

public sealed class OrderService : IOrderService
{
    private readonly ILogger<OrderService> _logger;
    private readonly IOrderRepository _orderRepository;
    private readonly IOrdersMessageHandler _ordersMessageHandler;
    private static readonly ActivitySource ActivitySource = new("eShop.Orders.API");
    private static readonly Meter Meter = new("eShop.Orders.API");

    private readonly Counter<long> _ordersPlacedCounter;
    private readonly Histogram<double> _orderProcessingDuration;
    private readonly Counter<long> _orderProcessingErrors;

    public OrderService(
        ILogger<OrderService> logger,
        IOrderRepository orderRepository,
        IOrdersMessageHandler ordersMessageHandler)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _orderRepository = orderRepository ?? throw new ArgumentNullException(nameof(orderRepository));
        _ordersMessageHandler = ordersMessageHandler ?? throw new ArgumentNullException(nameof(ordersMessageHandler));

        // Initialize metrics
        _ordersPlacedCounter = Meter.CreateCounter<long>(
            "orders.placed",
            "orders",
            "Number of orders placed");
        _orderProcessingDuration = Meter.CreateHistogram<double>(
            "orders.processing.duration",
            "ms",
            "Duration of order processing");
        _orderProcessingErrors = Meter.CreateCounter<long>(
            "orders.processing.errors",
            "errors",
            "Number of order processing errors");
    }

    public async Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = ActivitySource.StartActivity("PlaceOrder", ActivityKind.Internal);
        var startTime = DateTime.UtcNow;

        try
        {
            activity?.SetTag("order.id", order.Id);
            activity?.SetTag("order.customer_id", order.CustomerId);
            activity?.SetTag("order.total", order.Total);

            _logger.LogInformation("Placing order with ID: {OrderId} for customer {CustomerId}", order.Id, order.CustomerId);

            // Validate order data
            ValidateOrder(order);

            // Check if order already exists
            var existingOrder = await _orderRepository.GetOrderByIdAsync(order.Id, cancellationToken).ConfigureAwait(false);
            if (existingOrder != null)
            {
                _logger.LogWarning("Order with ID {OrderId} already exists", order.Id);
                throw new InvalidOperationException($"Order with ID {order.Id} already exists");
            }

            // Save order to repository first
            await _orderRepository.SaveOrderAsync(order, cancellationToken).ConfigureAwait(false);

            // Send message to Service Bus
            await _ordersMessageHandler.SendOrderMessageAsync(order, cancellationToken).ConfigureAwait(false);

            // Record metrics
            var metricTags = new TagList
            {
                { "customer.id", order.CustomerId },
                { "order.status", "success" }
            };
            _ordersPlacedCounter.Add(1, metricTags);
            var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
            _orderProcessingDuration.Record(duration, metricTags);

            _logger.LogInformation("Order {OrderId} placed successfully in {Duration}ms", order.Id, duration);
            return order;
        }
        catch (Exception ex)
        {
            var errorTags = new TagList
            {
                { "error.type", ex.GetType().Name },
                { "order.status", "failed" }
            };
            _orderProcessingErrors.Add(1, errorTags);
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Failed to place order {OrderId}: {ErrorMessage}", order.Id, ex.Message);
            throw;
        }
    }

    public async Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(orders);

        using var activity = ActivitySource.StartActivity("PlaceOrdersBatch", ActivityKind.Internal);
        var startTime = DateTime.UtcNow;

        var ordersList = orders.ToList();
        if (ordersList.Count == 0)
        {
            throw new ArgumentException("Orders collection cannot be empty", nameof(orders));
        }

        activity?.SetTag("orders.count", ordersList.Count);
        _logger.LogInformation("Placing batch of {Count} orders", ordersList.Count);

        var placedOrders = new List<Order>();
        var failedOrders = new List<(string OrderId, string ErrorMessage)>();

        foreach (var order in ordersList)
        {
            try
            {
                var placedOrder = await PlaceOrderAsync(order, cancellationToken).ConfigureAwait(false);
                placedOrders.Add(placedOrder);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to place order {OrderId} in batch", order.Id);
                failedOrders.Add((order.Id, ex.Message));
            }
        }

        var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
        _logger.LogInformation(
            "Batch processing complete in {Duration}ms. {SuccessCount} orders placed successfully, {FailedCount} failed",
            duration, placedOrders.Count, failedOrders.Count);

        if (failedOrders.Count > 0)
        {
            activity?.AddEvent(new ActivityEvent("BatchPartialFailure",
                tags: new ActivityTagsCollection
                {
                    { "failed.count", failedOrders.Count },
                    { "success.count", placedOrders.Count }
                }));
        }

        return placedOrders;
    }

    public async Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        using var activity = ActivitySource.StartActivity("GetOrders", ActivityKind.Internal);

        try
        {
            _logger.LogInformation("Retrieving all orders");
            var orders = await _orderRepository.GetAllOrdersAsync(cancellationToken).ConfigureAwait(false);
            var ordersList = orders.ToList();

            activity?.SetTag("orders.retrieved.count", ordersList.Count);
            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Retrieved {Count} orders", ordersList.Count);

            return ordersList;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Failed to retrieve orders");
            throw;
        }
    }

    public async Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
        }

        using var activity = ActivitySource.StartActivity("GetOrderById", ActivityKind.Internal);
        activity?.SetTag("order.id", orderId);

        try
        {
            _logger.LogInformation("Retrieving order with ID: {OrderId}", orderId);
            var order = await _orderRepository.GetOrderByIdAsync(orderId, cancellationToken).ConfigureAwait(false);

            if (order == null)
            {
                activity?.SetStatus(ActivityStatusCode.Error, "Order not found");
                _logger.LogWarning("Order with ID {OrderId} not found", orderId);
            }
            else
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
            }

            return order;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Failed to retrieve order {OrderId}", orderId);
            throw;
        }
    }

    private static void ValidateOrder(Order order)
    {
        if (string.IsNullOrWhiteSpace(order.Id))
        {
            throw new ArgumentException("Order ID is required", nameof(order));
        }

        if (string.IsNullOrWhiteSpace(order.CustomerId))
        {
            throw new ArgumentException("Customer ID is required", nameof(order));
        }

        if (order.Total <= 0)
        {
            throw new ArgumentException("Order total must be greater than zero", nameof(order));
        }

        if (order.Products == null || order.Products.Count == 0)
        {
            throw new ArgumentException("Order must contain at least one product", nameof(order));
        }
    }
}