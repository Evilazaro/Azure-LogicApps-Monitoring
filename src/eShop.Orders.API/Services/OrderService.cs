// =============================================================================
// Order Service - Business Logic Layer
// Implements order management operations with comprehensive observability
// =============================================================================

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
    private readonly IServiceScopeFactory _serviceScopeFactory;
    private readonly ActivitySource _activitySource;

    private static readonly Meter Meter = new("eShop.Orders.API");
    private static readonly Counter<long> OrdersPlacedCounter = Meter.CreateCounter<long>(
        "eShop.orders.placed",
        unit: "order",
        description: "Total number of orders successfully placed in the system");
    private static readonly Histogram<double> OrderProcessingDuration = Meter.CreateHistogram<double>(
        "eShop.orders.processing.duration",
        unit: "ms",
        description: "Time taken to process order operations in milliseconds");
    private static readonly Counter<long> OrderProcessingErrors = Meter.CreateCounter<long>(
        "eShop.orders.processing.errors",
        unit: "error",
        description: "Total number of order processing errors categorized by error type");
    private static readonly Counter<long> OrdersDeletedCounter = Meter.CreateCounter<long>(
        "eShop.orders.deleted",
        unit: "order",
        description: "Total number of orders successfully deleted from the system");

    /// <summary>
    /// Initializes a new instance of the <see cref="OrderService"/> class.
    /// </summary>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <param name="orderRepository">The repository for order data persistence.</param>
    /// <param name="ordersMessageHandler">The handler for publishing order messages.</param>
    /// <param name="serviceScopeFactory">The service scope factory for creating isolated scopes.</param>
    /// <param name="activitySource">The activity source for distributed tracing.</param>
    /// <exception cref="ArgumentNullException">Thrown when any parameter is null.</exception>
    public OrderService(
        ILogger<OrderService> logger,
        IOrderRepository orderRepository,
        IOrdersMessageHandler ordersMessageHandler,
        IServiceScopeFactory serviceScopeFactory,
        ActivitySource activitySource)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _orderRepository = orderRepository ?? throw new ArgumentNullException(nameof(orderRepository));
        _ordersMessageHandler = ordersMessageHandler ?? throw new ArgumentNullException(nameof(ordersMessageHandler));
        _serviceScopeFactory = serviceScopeFactory ?? throw new ArgumentNullException(nameof(serviceScopeFactory));
        _activitySource = activitySource ?? throw new ArgumentNullException(nameof(activitySource));
    }

    /// <summary>
    /// Places a new order asynchronously with validation, persistence, and message publishing.
    /// </summary>
    /// <param name="order">The order to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The placed order.</returns>
    /// <exception cref="ArgumentNullException">Thrown when order is null.</exception>
    /// <exception cref="ArgumentException">Thrown when order validation fails.</exception>
    /// <exception cref="InvalidOperationException">Thrown when order already exists.</exception>
    public async Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = _activitySource.StartActivity("PlaceOrder", ActivityKind.Internal);
        var stopwatch = Stopwatch.StartNew();

        try
        {
            activity?.SetTag("order.id", order.Id);
            activity?.SetTag("order.total", order.Total);
            activity?.SetTag("order.products.count", order.Products?.Count ?? 0);

            _logger.LogInformation("Placing order with ID: {OrderId} for customer {CustomerId}", order.Id, order.CustomerId);

            // Validate order data
            ValidateOrder(order);

            // Check if order already exists
            var existingOrder = await _orderRepository.GetOrderByIdAsync(order.Id, cancellationToken);
            if (existingOrder != null)
            {
                _logger.LogWarning("Order with ID {OrderId} already exists", order.Id);
                throw new InvalidOperationException($"Order with ID {order.Id} already exists");
            }

            // Save order to repository first
            await _orderRepository.SaveOrderAsync(order, cancellationToken);

            // Send message to Service Bus
            await _ordersMessageHandler.SendOrderMessageAsync(order, cancellationToken);

            // Record metrics
            var metricTags = new TagList
            {
                { "order.status", "success" }
            };
            OrdersPlacedCounter.Add(1, metricTags);
            stopwatch.Stop();
            var duration = stopwatch.Elapsed.TotalMilliseconds;
            OrderProcessingDuration.Record(duration, metricTags);

            _logger.LogInformation("Order {OrderId} placed successfully in {Duration:F2}ms", order.Id, duration);
            return order;
        }
        catch (Exception ex)
        {
            var errorTags = new TagList
            {
                { "error.type", ex.GetType().Name },
                { "order.status", "failed" }
            };
            OrderProcessingErrors.Add(1, errorTags);

            // Record exception with full details in activity
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddEvent(new ActivityEvent("PlaceOrderFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "order.id", order.Id }
            }));

            _logger.LogError(ex, "Failed to place order {OrderId}: {ErrorMessage}", order.Id, ex.Message);
            throw;
        }
    }

    /// <summary>
    /// Places multiple orders asynchronously in a batch operation with parallel processing.
    /// Processes orders in parallel while maintaining observability and error handling.
    /// Creates a new service scope for each order to ensure thread-safe DbContext usage.
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
        _logger.LogInformation("Placing batch of {Count} orders with parallel processing", ordersList.Count);

        var placedOrders = new System.Collections.Concurrent.ConcurrentBag<Order>();
        var skippedOrders = new System.Collections.Concurrent.ConcurrentBag<Order>();
        var failedOrders = new System.Collections.Concurrent.ConcurrentBag<(string OrderId, string ErrorMessage)>();

        // Use conservative parallelism for database-intensive operations to avoid connection pool exhaustion
        // and reduce pressure on the database during batch processing
        var options = new ParallelOptions
        {
            MaxDegreeOfParallelism = Math.Min(Environment.ProcessorCount, 4),
            CancellationToken = cancellationToken
        };

        try
        {
            await Parallel.ForEachAsync(ordersList, options, async (order, ct) =>
            {
                try
                {
                    // Validate order data first (no DB access, thread-safe)
                    ValidateOrder(order);

                    // Create a new scope for this order to get a fresh DbContext instance
                    await using var scope = _serviceScopeFactory.CreateAsyncScope();
                    var scopedRepository = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
                    var scopedMessageHandler = scope.ServiceProvider.GetRequiredService<IOrdersMessageHandler>();

                    using var orderActivity = _activitySource.StartActivity("PlaceOrderInBatch", ActivityKind.Internal);
                    orderActivity?.SetTag("order.id", order.Id);
                    orderActivity?.SetTag("order.customer_id", order.CustomerId);

                    var orderStartTime = DateTime.UtcNow;

                    // Use a separate timeout for individual order operations to prevent cascade failures
                    // This prevents one slow query from cancelling the entire batch
                    using var orderCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
                    orderCts.CancelAfter(TimeSpan.FromSeconds(30)); // 30 second timeout per order

                    // Check if order already exists using scoped repository (idempotency check)
                    var existingOrder = await scopedRepository.GetOrderByIdAsync(order.Id, orderCts.Token);
                    if (existingOrder != null)
                    {
                        // Order already exists - treat as idempotent success, skip processing
                        _logger.LogInformation("Order {OrderId} already exists, skipping (idempotent)", order.Id);
                        orderActivity?.SetTag("order.skipped", true);
                        orderActivity?.SetTag("order.skip_reason", "duplicate");
                        skippedOrders.Add(existingOrder);

                        var skipTags = new TagList
                        {
                            { "order.status", "skipped" },
                            { "order.skip_reason", "duplicate" }
                        };
                        OrdersPlacedCounter.Add(1, skipTags);
                        orderActivity?.SetStatus(ActivityStatusCode.Ok);
                        return;
                    }

                    // Save order using scoped repository
                    await scopedRepository.SaveOrderAsync(order, orderCts.Token);

                    // Send message using scoped handler
                    await scopedMessageHandler.SendOrderMessageAsync(order, orderCts.Token);

                    // Record metrics
                    var metricTags = new TagList
                    {
                        { "order.status", "success" }
                    };
                    OrdersPlacedCounter.Add(1, metricTags);
                    var orderDuration = (DateTime.UtcNow - orderStartTime).TotalMilliseconds;
                    OrderProcessingDuration.Record(orderDuration, metricTags);

                    placedOrders.Add(order);
                    orderActivity?.SetStatus(ActivityStatusCode.Ok);
                }
                catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
                {
                    // This is a per-order timeout, not a batch cancellation - log as warning and continue
                    _logger.LogWarning("Order {OrderId} processing timed out after 30 seconds", order.Id);

                    var errorTags = new TagList
                    {
                        { "error.type", "Timeout" },
                        { "order.status", "failed" }
                    };
                    OrderProcessingErrors.Add(1, errorTags);

                    failedOrders.Add((order.Id, "Processing timed out"));
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Failed to place order {OrderId} in batch: {ErrorMessage}", order.Id, ex.Message);

                    var errorTags = new TagList
                    {
                        { "error.type", ex.GetType().Name },
                        { "order.status", "failed" }
                    };
                    OrderProcessingErrors.Add(1, errorTags);

                    failedOrders.Add((order.Id, ex.Message));
                }
            }).ConfigureAwait(false);
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning("Batch processing was cancelled by user after processing {Count} orders", placedOrders.Count + skippedOrders.Count);
            throw;
        }

        var duration = (DateTime.UtcNow - startTime).TotalMilliseconds;
        _logger.LogInformation(
            "Batch processing complete in {Duration}ms. {SuccessCount} orders placed, {SkippedCount} skipped (duplicates), {FailedCount} failed",
            duration, placedOrders.Count, skippedOrders.Count, failedOrders.Count);

        if (failedOrders.Count > 0)
        {
            activity?.AddEvent(new ActivityEvent("BatchPartialFailure",
                tags: new ActivityTagsCollection
                {
                    { "failed.count", failedOrders.Count },
                    { "success.count", placedOrders.Count },
                    { "skipped.count", skippedOrders.Count },
                    { "failed.orders", string.Join(", ", failedOrders.Select(f => f.OrderId)) }
                }));
        }

        // Return both newly placed and skipped (already existing) orders as successful results
        return placedOrders.Concat(skippedOrders).ToList();
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
            var orders = await _orderRepository.GetAllOrdersAsync(cancellationToken);
            var ordersList = orders.ToList();

            activity?.SetTag("orders.retrieved.count", ordersList.Count);
            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Retrieved {Count} orders", ordersList.Count);

            return ordersList;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddEvent(new ActivityEvent("GetOrdersFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
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
            var order = await _orderRepository.GetOrderByIdAsync(orderId, cancellationToken);

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
            activity?.AddEvent(new ActivityEvent("GetOrderByIdFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "order.id", orderId }
            }));
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
            var order = await _orderRepository.GetOrderByIdAsync(orderId, cancellationToken);
            if (order == null)
            {
                _logger.LogWarning("Order with ID {OrderId} not found for deletion", orderId);
                return false;
            }

            // Delete the order from repository
            var deleted = await _orderRepository.DeleteOrderAsync(orderId, cancellationToken);

            if (deleted)
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
                _logger.LogInformation("Order {OrderId} deleted successfully", orderId);
                OrdersDeletedCounter.Add(1, new TagList { { "order.status", "success" } });
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
            activity?.AddEvent(new ActivityEvent("DeleteOrderFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name },
                { "order.id", orderId }
            }));
            _logger.LogError(ex, "Failed to delete order {OrderId}", orderId);
            throw;
        }
    }

    /// <summary>
    /// Deletes multiple orders in batch with parallel processing.
    /// Creates a new service scope for each order to ensure thread-safe DbContext usage.
    /// </summary>
    /// <param name="orderIds">The collection of order IDs to delete.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The number of successfully deleted orders.</returns>
    public async Task<int> DeleteOrdersBatchAsync(IEnumerable<string> orderIds, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(orderIds);

        var orderIdsList = orderIds.ToList();
        if (orderIdsList.Count == 0)
        {
            return 0;
        }

        var deletedCount = 0;
        var lockObject = new object();

        var options = new ParallelOptions
        {
            MaxDegreeOfParallelism = Math.Min(Environment.ProcessorCount, 10),
            CancellationToken = cancellationToken
        };

        await Parallel.ForEachAsync(orderIdsList, options, async (orderId, ct) =>
        {
            try
            {
                // Create a new scope for thread-safe DbContext usage
                await using var scope = _serviceScopeFactory.CreateAsyncScope();
                var scopedRepository = scope.ServiceProvider.GetRequiredService<IOrderRepository>();

                // First verify the order exists
                var order = await scopedRepository.GetOrderByIdAsync(orderId, ct);
                if (order == null)
                {
                    _logger.LogWarning("Order with ID {OrderId} not found for deletion", orderId);
                    return;
                }

                // Delete the order
                var deleted = await scopedRepository.DeleteOrderAsync(orderId, ct);
                if (deleted)
                {
                    lock (lockObject)
                    {
                        deletedCount++;
                    }
                    OrdersDeletedCounter.Add(1, new TagList { { "order.status", "success" } });
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to delete order {OrderId} in batch operation: {ErrorMessage}", orderId, ex.Message);
                // Continue with next order instead of failing entire batch
            }
        }).ConfigureAwait(false);

        return deletedCount;
    }

    /// <summary>
    /// Validates the order data to ensure it meets all business requirements.
    /// </summary>
    /// <param name="order">The order to validate.</param>
    /// <exception cref="ArgumentException">Thrown when validation fails.</exception>
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

    /// <inheritdoc />
    public async Task<IEnumerable<object>> ListMessagesFromTopicsAsync(CancellationToken cancellationToken)
    {
        using var activity = _activitySource.StartActivity("ListMessagesFromTopics", ActivityKind.Internal);

        try
        {
            _logger.LogInformation("Retrieving messages from topics");
            var messages = await _ordersMessageHandler.ListMessagesAsync(cancellationToken);
            var messagesList = messages.ToList();

            activity?.SetTag("messages.retrieved.count", messagesList.Count);
            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Retrieved {Count} messages from topics", messagesList.Count);

            return messagesList;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddEvent(new ActivityEvent("ListMessagesFromTopicsFailed", tags: new ActivityTagsCollection
            {
                { "error.type", ex.GetType().Name },
                { "exception.message", ex.Message },
                { "exception.type", ex.GetType().FullName ?? ex.GetType().Name }
            }));
            _logger.LogError(ex, "Failed to retrieve messages from topics");
            throw;
        }
    }
}