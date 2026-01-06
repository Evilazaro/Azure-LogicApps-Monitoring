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
    public async Task<IEnumerable<Order>> PlaceOrdersBatchAsync(
        IEnumerable<Order> orders,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(orders);

        var ordersList = orders.ToList();
        if (ordersList.Count == 0)
        {
            throw new ArgumentException("Orders collection cannot be empty", nameof(orders));
        }

        _logger.LogInformation("Placing batch of {Count} orders with parallel processing", ordersList.Count);

        var successfulOrders = new List<Order>();
        var skippedOrders = new List<Order>();
        var lockObject = new object();

        // Process in smaller batches to avoid overwhelming the database
        const int processBatchSize = 50;
        var processBatches = ordersList
            .Select((order, index) => new { order, index })
            .GroupBy(x => x.index / processBatchSize)
            .Select(g => g.Select(x => x.order).ToList())
            .ToList();

        _logger.LogInformation("Processing {Count} orders in {BatchCount} batches of max {BatchSize} orders",
            ordersList.Count, processBatches.Count, processBatchSize);

        // Use SemaphoreSlim to limit concurrent database operations - created once for all batches
        using var semaphore = new SemaphoreSlim(10);

        // Create a longer timeout for internal operations (5 minutes) to handle Service Bus latency
        using var internalCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        internalCts.CancelAfter(TimeSpan.FromMinutes(5));
        var internalToken = internalCts.Token;

        foreach (var (batch, batchIndex) in processBatches.Select((b, i) => (b, i)))
        {
            if (cancellationToken.IsCancellationRequested)
            {
                _logger.LogWarning("Batch processing was cancelled by user after processing {Count} orders",
                    successfulOrders.Count);
                break;
            }

            _logger.LogInformation("Processing batch {Current}/{Total} with {Count} orders",
                batchIndex + 1, processBatches.Count, batch.Count);

            var tasks = batch.Select(async order =>
            {
                try
                {
                    await semaphore.WaitAsync(internalToken);
                }
                catch (OperationCanceledException)
                {
                    _logger.LogWarning("Semaphore wait cancelled for order {OrderId}", order.Id);
                    return OrderProcessResult.Failure;
                }

                try
                {
                    // Create a new scope for each order to ensure thread-safe DbContext usage
                    await using var scope = _serviceScopeFactory.CreateAsyncScope();
                    var scopedRepository = scope.ServiceProvider.GetRequiredService<IOrderRepository>();
                    var scopedMessageHandler = scope.ServiceProvider.GetRequiredService<IOrdersMessageHandler>();

                    var result = await ProcessSingleOrderAsync(order, scopedRepository, scopedMessageHandler, internalToken);
                    lock (lockObject)
                    {
                        if (result == OrderProcessResult.Success)
                        {
                            successfulOrders.Add(order);
                        }
                        else if (result == OrderProcessResult.AlreadyExists)
                        {
                            skippedOrders.Add(order);
                        }
                    }
                    return result;
                }
                finally
                {
                    semaphore.Release();
                }
            }).ToList();

            await Task.WhenAll(tasks);
        }

        var failureCount = ordersList.Count - successfulOrders.Count - skippedOrders.Count;

        _logger.LogInformation(
            "Batch processing completed. Success: {Success}, Failed: {Failed}, Skipped (already existed): {Skipped}",
            successfulOrders.Count, failureCount, skippedOrders.Count);

        // Return both successful and skipped orders for idempotency
        return successfulOrders.Concat(skippedOrders);
    }

    private async Task<OrderProcessResult> ProcessSingleOrderAsync(
        Order order,
        IOrderRepository repository,
        IOrdersMessageHandler messageHandler,
        CancellationToken cancellationToken)
    {
        try
        {
            // Validate the order
            ValidateOrder(order);

            // Check if order already exists before attempting to save (idempotency check)
            var existingOrder = await repository.GetOrderByIdAsync(order.Id, cancellationToken);
            if (existingOrder != null)
            {
                _logger.LogDebug("Order {OrderId} already exists in database, skipping (idempotent)", order.Id);
                return OrderProcessResult.AlreadyExists;
            }

            // Save to database - the repository handles duplicate key violations as backup
            await repository.SaveOrderAsync(order, cancellationToken);

            // Publish event via message handler - the handler manages its own timeout and retry
            // Pass CancellationToken.None to allow completion even if HTTP request is cancelled
            try
            {
                await messageHandler.SendOrderMessageAsync(order, CancellationToken.None);
            }
            catch (TimeoutException)
            {
                // Message send timed out, but order was saved - log warning but consider success
                _logger.LogWarning("Service Bus message send timed out for order {OrderId}, but order was saved to database", order.Id);
            }
            catch (Exception msgEx) when (msgEx is not OperationCanceledException)
            {
                // Non-cancellation message errors - order was saved, log warning
                _logger.LogWarning(msgEx, "Failed to send Service Bus message for order {OrderId}, but order was saved to database", order.Id);
            }

            return OrderProcessResult.Success;
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("already exists", StringComparison.OrdinalIgnoreCase))
        {
            // Order already exists - this is expected for idempotent operations
            _logger.LogDebug("Order {OrderId} already exists, skipping (idempotent)", order.Id);
            return OrderProcessResult.AlreadyExists;
        }
        catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
        {
            _logger.LogWarning("Order {OrderId} processing was cancelled", order.Id);
            return OrderProcessResult.Failure;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to place order {OrderId} in batch: {Message}",
                order.Id, ex.Message);
            return OrderProcessResult.Failure;
        }
    }

    private enum OrderProcessResult
    {
        Success,
        Failure,
        AlreadyExists
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