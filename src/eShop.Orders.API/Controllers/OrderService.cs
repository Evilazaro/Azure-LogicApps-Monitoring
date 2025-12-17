using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Models;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text.Json;

namespace eShop.Orders.API.Services;

/// <summary>
/// Service implementation for managing orders with Azure Service Bus integration.
/// Implements IAsyncDisposable to properly release Service Bus resources.
/// Includes comprehensive distributed tracing for all messaging operations.
/// </summary>
public sealed class OrderService : IOrderService, IAsyncDisposable
{
    private readonly ServiceBusSender _sender;
    private readonly ILogger<OrderService> _logger;
    private static readonly ActivitySource _activitySource = Extensions.CreateActivitySource();

    // In-memory store for demo purposes - replace with proper database in production
    private static readonly ConcurrentDictionary<int, Order> _orderStore = new();

    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };

    /// <summary>
    /// Initializes a new instance of the OrderService
    /// </summary>
    /// <param name="serviceBusClient">The Service Bus client for messaging</param>
    /// <param name="configuration">Application configuration</param>
    /// <param name="logger">Logger instance</param>
    /// <exception cref="ArgumentNullException">Thrown when required dependencies are null</exception>
    /// <exception cref="InvalidOperationException">Thrown when queue name is not configured</exception>
    public OrderService(
        ServiceBusClient serviceBusClient,
        IConfiguration configuration,
        ILogger<OrderService> logger)
    {
        ArgumentNullException.ThrowIfNull(serviceBusClient);
        ArgumentNullException.ThrowIfNull(configuration);
        ArgumentNullException.ThrowIfNull(logger);

        _logger = logger;

        var topicName = configuration["Azure:ServiceBus:TopicName"] ?? "orders";
        _sender = serviceBusClient.CreateSender(topicName);

        _logger.LogInformation("OrderService initialized with topic: {TopicName}", topicName);
    }

    /// <inheritdoc/>
    public async Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        // Create activity for message sending operation
        using var activity = _activitySource.StartActivity(
            "OrderService.SendMessage",
            ActivityKind.Producer);

        try
        {
            // Add order details to activity tags
            activity?.SetTag("messaging.system", "servicebus");
            activity?.SetTag("messaging.destination", "OrdersPlaced");
            activity?.SetTag("messaging.operation", "publish");
            activity?.SetTag("order.id", order.Id);
            activity?.SetTag("order.total", order.Total);
            activity?.SetTag("order.quantity", order.Quantity);

            var messageBody = JsonSerializer.Serialize(order, _jsonOptions);
            var message = new ServiceBusMessage(messageBody)
            {
                MessageId = Guid.NewGuid().ToString(),
                ContentType = "application/json",
                Subject = "OrdersPlaced"
            };

            // Add metadata for correlation and tracking
            message.ApplicationProperties.Add("OrderId", order.Id);
            message.ApplicationProperties.Add("Timestamp", DateTimeOffset.UtcNow.ToString("o"));

            // Propagate W3C Trace Context for distributed tracing
            if (activity != null)
            {
                // Add traceparent header (W3C Trace Context standard)
                message.ApplicationProperties.Add("traceparent", activity.Id ?? string.Empty);

                // Add diagnostic context
                message.ApplicationProperties.Add("TraceId", activity.TraceId.ToString());
                message.ApplicationProperties.Add("SpanId", activity.SpanId.ToString());

                // Add tracestate if present (for vendor-specific context)
                if (!string.IsNullOrEmpty(activity.TraceStateString))
                {
                    message.ApplicationProperties.Add("tracestate", activity.TraceStateString);
                }

                activity.AddEvent(new ActivityEvent("Trace context added to message"));
            }

            activity?.SetTag("messaging.message_id", message.MessageId);

            await _sender.SendMessageAsync(message, cancellationToken);

            // Store order for retrieval
            if (int.TryParse(order.Id, out var orderId))
            {
                _orderStore.AddOrUpdate(orderId, order, (_, _) => order);
            }
            else
            {
                _logger.LogWarning("Order Id '{OrderId}' could not be parsed to int. Order not stored.", order.Id);
            }

            activity?.SetStatus(ActivityStatusCode.Ok);
            activity?.AddEvent(new ActivityEvent("Order message sent successfully"));

            _logger.LogInformation(
                "Successfully sent order message. OrderId: {OrderId}, MessageId: {MessageId}, TraceId: {TraceId}",
                order.Id,
                message.MessageId,
                activity?.TraceId.ToString() ?? "none");
        }
        catch (ServiceBusException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            activity?.SetTag("error.type", ex.Reason.ToString());

            _logger.LogError(
                ex,
                "Service Bus error sending order message. OrderId: {OrderId}, Reason: {Reason}",
                order.Id,
                ex.Reason);
            throw;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "Error sending order message. OrderId: {OrderId}", order.Id);
            throw;
        }
    }

    /// <inheritdoc/>
    public async Task SendOrderBatchMessagesAsync(
        IReadOnlyList<Order> orders,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(orders);

        if (orders.Count == 0)
        {
            _logger.LogWarning("SendOrderBatchMessagesAsync called with empty orders collection");
            return;
        }

        // Create activity for batch message sending
        using var activity = _activitySource.StartActivity(
            "OrderService.SendMessageBatch",
            ActivityKind.Producer);

        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("messaging.destination", "OrdersPlaced");
        activity?.SetTag("messaging.operation", "publish_batch");
        activity?.SetTag("messaging.batch_size", orders.Count);

        try
        {
            var messageBatch = await _sender.CreateMessageBatchAsync(cancellationToken);
            var messagesAdded = 0;

            foreach (var order in orders)
            {
                var messageBody = JsonSerializer.Serialize(order, _jsonOptions);
                var message = new ServiceBusMessage(messageBody)
                {
                    MessageId = Guid.NewGuid().ToString(),
                    ContentType = "application/json",
                    Subject = "OrdersPlaced"
                };

                message.ApplicationProperties.Add("OrderId", order.Id);
                message.ApplicationProperties.Add("Timestamp", DateTimeOffset.UtcNow.ToString("o"));

                // Propagate W3C Trace Context to each message in batch
                if (activity != null)
                {
                    message.ApplicationProperties.Add("traceparent", activity.Id ?? string.Empty);
                    message.ApplicationProperties.Add("TraceId", activity.TraceId.ToString());
                    message.ApplicationProperties.Add("SpanId", activity.SpanId.ToString());

                    if (!string.IsNullOrEmpty(activity.TraceStateString))
                    {
                        message.ApplicationProperties.Add("tracestate", activity.TraceStateString);
                    }
                }

                if (!messageBatch.TryAddMessage(message))
                {
                    // Batch is full - send current batch and start a new one
                    if (messagesAdded > 0)
                    {
                        _logger.LogInformation(
                            "Message batch is full. Sending {Count} messages before adding more",
                            messagesAdded);

                        await _sender.SendMessagesAsync(messageBatch, cancellationToken);
                        activity?.AddEvent(new ActivityEvent($"Sent batch of {messagesAdded} messages"));
                    }

                    // Cannot reuse batch after sending - recreate messageBatch for remaining messages
                    messageBatch = await _sender.CreateMessageBatchAsync(cancellationToken);
                    messagesAdded = 0;

                    // Try adding the current message to the new batch
                    if (!messageBatch.TryAddMessage(message))
                    {
                        // Single message is too large for any batch
                        _logger.LogError(
                            "Single message exceeds maximum batch size. OrderId: {OrderId}, MessageSize: {Size} bytes",
                            order.Id,
                            messageBody.Length);
                        throw new InvalidOperationException(
                            $"Message for order {order.Id} exceeds maximum allowed size");
                    }

                    messagesAdded++;
                }
                else
                {
                    messagesAdded++;
                }

                // Store order in memory for retrieval
                if (int.TryParse(order.Id, out var orderId))
                {
                    _orderStore.AddOrUpdate(orderId, order, (_, _) => order);
                }
                else
                {
                    _logger.LogWarning("Order Id '{OrderId}' could not be parsed to int. Order not stored.", order.Id);
                }
            }

            // Send remaining messages
            if (messagesAdded > 0)
            {
                await _sender.SendMessagesAsync(messageBatch, cancellationToken);
            }

            activity?.SetStatus(ActivityStatusCode.Ok);
            activity?.SetTag("messaging.messages_sent", orders.Count);
            activity?.AddEvent(new ActivityEvent("Batch messages sent successfully"));

            _logger.LogInformation(
                "Successfully sent batch of {Count} order messages. TraceId: {TraceId}",
                orders.Count,
                activity?.TraceId.ToString() ?? "none");
        }
        catch (ServiceBusException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            activity?.SetTag("error.type", ex.Reason.ToString());

            _logger.LogError(
                ex,
                "Service Bus error sending order batch. OrderCount: {Count}, Reason: {Reason}",
                orders.Count,
                ex.Reason);
            throw;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "Error sending order batch. OrderCount: {Count}", orders.Count);
            throw;
        }
    }

    /// <inheritdoc/>
    public Task<IReadOnlyList<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        // Create activity for data retrieval operation
        using var activity = _activitySource.StartActivity(
            "OrderService.GetAllOrders",
            ActivityKind.Internal);

        try
        {
            activity?.SetTag("db.operation", "select");
            activity?.SetTag("db.collection", "orders");

            var orders = _orderStore.Values.OrderByDescending(o => o.Date).ToList();

            activity?.SetTag("db.result_count", orders.Count);
            activity?.SetStatus(ActivityStatusCode.Ok);
            activity?.AddEvent(new ActivityEvent("Orders retrieved successfully"));

            _logger.LogDebug("Retrieved {Count} orders from storage. TraceId: {TraceId}",
                orders.Count,
                activity?.TraceId.ToString() ?? "none");

            return Task.FromResult<IReadOnlyList<Order>>(orders);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            throw;
        }
    }

    /// <inheritdoc/>
    public Task<Order?> GetOrderByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        // Create activity for single order retrieval
        using var activity = _activitySource.StartActivity(
            "OrderService.GetOrderById",
            ActivityKind.Internal);

        try
        {
            activity?.SetTag("db.operation", "select");
            activity?.SetTag("db.collection", "orders");
            activity?.SetTag("order.id", id);

            _orderStore.TryGetValue(id, out var order);

            if (order is not null)
            {
                activity?.SetTag("order.found", true);
                activity?.SetStatus(ActivityStatusCode.Ok);
                activity?.AddEvent(new ActivityEvent("Order found"));

                _logger.LogDebug("Retrieved order {OrderId} from storage. TraceId: {TraceId}",
                    id,
                    activity?.TraceId.ToString() ?? "none");
            }
            else
            {
                activity?.SetTag("order.found", false);
                activity?.SetStatus(ActivityStatusCode.Ok);
                activity?.AddEvent(new ActivityEvent("Order not found"));

                _logger.LogDebug("Order {OrderId} not found in storage. TraceId: {TraceId}",
                    id,
                    activity?.TraceId.ToString() ?? "none");
            }

            return Task.FromResult(order);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            throw;
        }
    }

    /// <inheritdoc/>
    public Task DeleteOrderAsync(int id, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        // Create activity for delete operation
        using var activity = _activitySource.StartActivity(
            "OrderService.DeleteOrder",
            ActivityKind.Internal);

        try
        {
            activity?.SetTag("db.operation", "delete");
            activity?.SetTag("db.collection", "orders");
            activity?.SetTag("order.id", id);

            var removed = _orderStore.TryRemove(id, out var removedOrder);

            if (removed)
            {
                activity?.SetTag("order.deleted", true);
                activity?.SetStatus(ActivityStatusCode.Ok);
                activity?.AddEvent(new ActivityEvent("Order deleted successfully"));

                _logger.LogInformation("Deleted order {OrderId} from storage. TraceId: {TraceId}",
                    id,
                    activity?.TraceId.ToString() ?? "none");
            }
            else
            {
                activity?.SetTag("order.deleted", false);
                activity?.SetStatus(ActivityStatusCode.Ok);
                activity?.AddEvent(new ActivityEvent("Order not found for deletion"));

                _logger.LogWarning("Order {OrderId} not found in storage for deletion. TraceId: {TraceId}",
                    id,
                    activity?.TraceId.ToString() ?? "none");
            }

            return Task.CompletedTask;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            throw;
        }
    }

    /// <summary>
    /// Disposes the Service Bus sender asynchronously.
    /// </summary>
    public async ValueTask DisposeAsync()
    {
        await _sender.DisposeAsync();
    }
}