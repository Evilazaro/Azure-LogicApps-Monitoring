using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;
using eShop.Orders.API.Services.Interfaces;
using System.Diagnostics;
using System.Diagnostics.Metrics;

namespace eShop.Orders.API.Services;

/// <summary>
/// Provides business logic for order management including placement, retrieval, and deletion operations.
/// Implements comprehensive observability through distributed tracing and metrics.
/// </summary>
public sealed class OrderService : IOrderService
{
    private readonly ILogger<OrderService> _logger;
    private readonly IOrderRepository _orderRepository;
    private readonly IOrdersMessageHandler _ordersMessageHandler;
    private readonly ActivitySource _activitySource;
    private readonly Meter _meter;

    private readonly Counter<long> _ordersPlacedCounter;
    private readonly Histogram<double> _orderProcessingDuration;
    private readonly Counter<long> _orderProcessingErrors;

    /// <summary>
    /// Initializes a new instance of the <see cref=\"OrderService\"/> class.
    /// </summary>
    /// <param name=\"logger\">The logger instance for structured logging.</param>
    /// <param name=\"orderRepository\">The repository for order data persistence.</param>
    /// <param name=\"ordersMessageHandler\">The handler for publishing order messages.</param>
    /// <param name=\"activitySource\">The activity source for distributed tracing.</param>
    /// <param name=\"meter\">The meter for recording metrics.</param>
    /// <exception cref=\"ArgumentNullException\">Thrown when any parameter is null.</exception>
    public OrderService(
        ILogger<OrderService> logger,
        IOrderRepository orderRepository,
        IOrdersMessageHandler ordersMessageHandler,
        ActivitySource activitySource,
        Meter meter)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _orderRepository = orderRepository ?? throw new ArgumentNullException(nameof(orderRepository));
        _ordersMessageHandler = ordersMessageHandler ?? throw new ArgumentNullException(nameof(ordersMessageHandler));
        _activitySource = activitySource ?? throw new ArgumentNullException(nameof(activitySource));
        _meter = meter ?? throw new ArgumentNullException(nameof(meter));

        // Initialize metrics with semantic naming conventions
        _ordersPlacedCounter = _meter.CreateCounter<long>(
            \"orders.placed\",
            \"orders\",
            \"Number of orders successfully placed\");
        _orderProcessingDuration = _meter.CreateHistogram<double>(
            \"orders.processing.duration\",
            \"ms\",
            \"Duration of order processing operations\");
        _orderProcessingErrors = _meter.CreateCounter<long>(
            \"orders.processing.errors\",
            \"errors\",
            \"Number of order processing errors by error type\");
    }

    /// <summary>\n    /// Places a new order asynchronously with validation, persistence, and message publishing.\n    /// </summary>\n    /// <param name=\"order\">The order to be placed.</param>\n    /// <param name=\"cancellationToken\">Cancellation token to cancel the operation.</param>\n    /// <returns>The placed order.</returns>\n    /// <exception cref=\"ArgumentNullException\">Thrown when order is null.</exception>\n    /// <exception cref=\"ArgumentException\">Thrown when order validation fails.</exception>\n    /// <exception cref=\"InvalidOperationException\">Thrown when order already exists.</exception>\n    public async Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = _activitySource.StartActivity(\"PlaceOrder\", ActivityKind.Internal);
        var startTime = DateTime.UtcNow;

        try
        {
            activity?.SetTag(\"order.id\", order.Id);
            activity?.SetTag(\"order.customer_id\", order.CustomerId);
            activity?.SetTag(\"order.total\", order.Total);
            activity?.SetTag(\"order.products.count\", order.Products?.Count ?? 0);

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

    /// <summary>
    /// Places multiple orders asynchronously in a batch operation.
    /// Continues processing remaining orders if individual orders fail.
    /// </summary>
    /// <param name="orders">The collection of orders to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of successfully placed orders.</returns>
    /// <exception cref="ArgumentNullException">Thrown when orders is null.</exception>
    /// <exception cref="ArgumentException">Thrown when orders collection is empty.</exception>
    public async Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default)
{
    ArgumentNullException.ThrowIfNull(orders);

    using var activity = _activitySource.StartActivity("PlaceOrdersBatch", ActivityKind.Internal);
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

/// <summary>
/// Retrieves all orders from the repository asynchronously.
/// </summary>
/// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
/// <returns>A collection of all orders.</returns>
public async Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
{
    using var activity = _activitySource.StartActivity("GetOrders", ActivityKind.Internal);

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

/// <summary>
/// Retrieves a specific order by its unique identifier.
/// </summary>
/// <param name="orderId">The unique identifier of the order.</param>
/// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
/// <returns>The order if found; otherwise, null.</returns>
/// <exception cref="ArgumentException">Thrown when orderId is null or empty.</exception>
public async Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
{
    if (string.IsNullOrWhiteSpace(orderId))
    {
        throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
    }

    using var activity = _activitySource.StartActivity("GetOrderById", ActivityKind.Internal);
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

/// <summary>
/// Deletes an order from the repository by its unique identifier.
/// </summary>
/// <param name="orderId">The unique identifier of the order to delete.</param>
/// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
/// <returns>True if the order was successfully deleted; otherwise, false.</returns>
/// <exception cref="ArgumentException">Thrown when orderId is null or empty.</exception>
public async Task<bool> DeleteOrderAsync(string orderId, CancellationToken cancellationToken = default)
{
    if (string.IsNullOrWhiteSpace(orderId))
    {
        throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
    }

    using var activity = _activitySource.StartActivity("DeleteOrder", ActivityKind.Internal);
    activity?.SetTag("order.id", orderId);

    try
    {
        _logger.LogInformation("Deleting order with ID: {OrderId}", orderId);

        // First verify the order exists
        var order = await _orderRepository.GetOrderByIdAsync(orderId, cancellationToken).ConfigureAwait(false);
        if (order == null)
        {
            _logger.LogWarning("Order with ID {OrderId} not found for deletion", orderId);
            return false;
        }

        // Delete the order from repository
        var deleted = await _orderRepository.DeleteOrderAsync(orderId, cancellationToken).ConfigureAwait(false);

        if (deleted)
        {
            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Order {OrderId} deleted successfully", orderId);
        }
        else
        {
            activity?.SetStatus(ActivityStatusCode.Error, "Failed to delete order");
            _logger.LogWarning("Failed to delete order {OrderId}", orderId);
        }

        return deleted;
    }
    catch (Exception ex)
    {
        activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
        _logger.LogError(ex, "Failed to delete order {OrderId}", orderId);
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