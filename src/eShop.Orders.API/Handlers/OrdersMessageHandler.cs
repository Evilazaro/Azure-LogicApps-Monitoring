// =============================================================================
// Orders Message Handler - Messaging Layer
// Handles publishing order messages to Azure Service Bus with distributed tracing
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Interfaces;
using System.Diagnostics;
using System.Text.Json;

namespace eShop.Orders.API.Handlers;

/// <summary>
/// Handles publishing order messages to Azure Service Bus with distributed tracing support.
/// </summary>
public sealed class OrdersMessageHandler : IOrdersMessageHandler
{
    private readonly ILogger<OrdersMessageHandler> _logger;
    private readonly ServiceBusClient _serviceBusClient;
    private readonly string _topicName;
    private readonly ActivitySource _activitySource;

    private const string DefaultTopicName = "ordersplaced";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = false,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
    };

    /// <summary>
    /// Initializes a new instance of the <see cref="OrdersMessageHandler"/> class.
    /// </summary>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <param name="serviceBusClient">The Service Bus client for message publishing.</param>
    /// <param name="configuration">The configuration to retrieve Service Bus topic name.</param>
    /// <param name="activitySource">The activity source for distributed tracing.</param>
    /// <exception cref="ArgumentNullException">Thrown when any parameter is null.</exception>
    public OrdersMessageHandler(
        ILogger<OrdersMessageHandler> logger,
        ServiceBusClient serviceBusClient,
        IConfiguration configuration,
        ActivitySource activitySource)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _serviceBusClient = serviceBusClient ?? throw new ArgumentNullException(nameof(serviceBusClient));
        _activitySource = activitySource ?? throw new ArgumentNullException(nameof(activitySource));

        ArgumentNullException.ThrowIfNull(configuration);
        var configuredTopicName = configuration["Azure:ServiceBus:TopicName"];
        _topicName = string.IsNullOrWhiteSpace(configuredTopicName) ? DefaultTopicName : configuredTopicName;
    }

    /// <summary>
    /// Sends a single order message to the Service Bus topic asynchronously.
    /// Uses an independent timeout to prevent HTTP request cancellation from affecting message delivery.
    /// </summary>
    /// <param name="order">The order to be published.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    /// <exception cref="ArgumentNullException">Thrown when order is null.</exception>
    /// <exception cref="ServiceBusException">Thrown when Service Bus operation fails.</exception>
    public async Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = _activitySource.StartActivity("SendOrderMessage", ActivityKind.Producer);
        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("messaging.destination.name", _topicName);
        activity?.SetTag("messaging.operation", "publish");
        activity?.SetTag("messaging.destination.kind", "topic");
        activity?.SetTag("order.id", order.Id);
        activity?.SetTag("order.customer_id", order.CustomerId);

        await using var sender = _serviceBusClient.CreateSender(_topicName);

        try
        {
            var messageBody = JsonSerializer.Serialize(order, JsonOptions);
            var message = new ServiceBusMessage(messageBody)
            {
                ContentType = "application/json",
                MessageId = order.Id,
                Subject = "OrderPlaced"
            };

            // Add trace context to message for distributed tracing
            if (activity != null)
            {
                message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
                message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();
                message.ApplicationProperties["TraceParent"] = activity.Id ?? string.Empty;
                message.ApplicationProperties["traceparent"] = activity.Id ?? string.Empty;
                if (!string.IsNullOrWhiteSpace(activity.TraceStateString))
                {
                    message.ApplicationProperties["tracestate"] = activity.TraceStateString;
                }
            }

            // Use independent timeout to prevent HTTP cancellation from interrupting Service Bus operations
            // This ensures messages are sent even if the HTTP request is cancelled by client/load balancer
            using var sendCts = new CancellationTokenSource(TimeSpan.FromSeconds(30));
            
            const int maxRetries = 3;
            var retryDelayMs = 500;
            
            for (var attempt = 1; attempt <= maxRetries; attempt++)
            {
                try
                {
                    await sender.SendMessageAsync(message, sendCts.Token);
                    break; // Success, exit retry loop
                }
                catch (ServiceBusException sbEx) when (sbEx.IsTransient && attempt < maxRetries)
                {
                    _logger.LogWarning("Transient Service Bus error on attempt {Attempt}/{MaxRetries} for order {OrderId}: {Message}",
                        attempt, maxRetries, order.Id, sbEx.Message);
                    await Task.Delay(retryDelayMs, CancellationToken.None);
                    retryDelayMs *= 2; // Exponential backoff
                }
                catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested && !sendCts.IsCancellationRequested)
                {
                    // HTTP request was cancelled, but our send timeout hasn't expired - continue sending
                    _logger.LogWarning("HTTP request cancelled during Service Bus send for order {OrderId}, continuing with internal timeout", order.Id);
                    await sender.SendMessageAsync(message, sendCts.Token);
                    break;
                }
            }

            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Successfully sent order message for order {OrderId} to topic {TopicName}",
                order.Id, _topicName);
        }
        catch (ServiceBusException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            activity?.SetTag("error.type", nameof(ServiceBusException));
            activity?.SetTag("exception.message", ex.Message);
            _logger.LogError(ex, "Failed to send order message for order {OrderId} to topic {TopicName}. Reason: {Reason}",
                order.Id, _topicName, ex.Reason);
            throw;
        }
        catch (OperationCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            // Internal timeout expired
            activity?.SetStatus(ActivityStatusCode.Error, "Service Bus send timeout");
            activity?.SetTag("error.type", "Timeout");
            _logger.LogError(ex, "Timeout sending order message for order {OrderId} to topic {TopicName} after 30 seconds",
                order.Id, _topicName);
            throw new TimeoutException($"Timeout sending order message for order {order.Id}", ex);
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            activity?.SetTag("error.type", ex.GetType().Name);
            _logger.LogError(ex, "Unexpected error sending order message for order {OrderId} to topic {TopicName}",
                order.Id, _topicName);
            throw;
        }
    }

    /// <summary>
    /// Sends multiple order messages to the Service Bus topic in a single batch operation.
    /// </summary>
    /// <param name="orders">The collection of orders to be published.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    /// <exception cref="ArgumentNullException">Thrown when orders is null.</exception>
    /// <exception cref="ServiceBusException">Thrown when Service Bus operation fails.</exception>
    public async Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(orders);

        using var activity = _activitySource.StartActivity("SendOrdersBatchMessage", ActivityKind.Producer);

        var ordersList = orders.ToList();
        if (ordersList.Count == 0)
        {
            _logger.LogWarning("Empty orders collection provided for batch send");
            return;
        }

        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("messaging.destination.name", _topicName);
        activity?.SetTag("messaging.operation", "publish");
        activity?.SetTag("messaging.destination.kind", "topic");
        activity?.SetTag("messaging.batch.message_count", ordersList.Count);

        await using var sender = _serviceBusClient.CreateSender(_topicName);

        try
        {
            var messages = new List<ServiceBusMessage>(ordersList.Count);

            foreach (var order in ordersList)
            {
                activity?.AddEvent(new ActivityEvent("OrderInBatch",
                    tags: new ActivityTagsCollection
                    {
                        { "order.id", order.Id }
                    }));

                var messageBody = JsonSerializer.Serialize(order, JsonOptions);
                var message = new ServiceBusMessage(messageBody)
                {
                    ContentType = "application/json",
                    MessageId = order.Id,
                    Subject = "OrderPlaced"
                };

                // Add trace context to message for distributed tracing
                if (activity != null)
                {
                    message.ApplicationProperties["TraceId"] = activity.TraceId.ToString();
                    message.ApplicationProperties["SpanId"] = activity.SpanId.ToString();
                    message.ApplicationProperties["TraceParent"] = activity.Id ?? string.Empty;
                    message.ApplicationProperties["traceparent"] = activity.Id ?? string.Empty;
                    if (!string.IsNullOrWhiteSpace(activity.TraceStateString))
                    {
                        message.ApplicationProperties["tracestate"] = activity.TraceStateString;
                    }
                }

                messages.Add(message);
            }

            await sender.SendMessagesAsync(messages, cancellationToken);

            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Successfully sent batch of {Count} order messages to topic {TopicName}",
                messages.Count, _topicName);
        }
        catch (ServiceBusException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            activity?.SetTag("error.type", nameof(ServiceBusException));
            activity?.SetTag("exception.message", ex.Message);
            _logger.LogError(ex, "Failed to send batch of order messages to topic {TopicName}. Reason: {Reason}",
                _topicName, ex.Reason);
            throw;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            activity?.SetTag("error.type", ex.GetType().Name);
            _logger.LogError(ex, "Unexpected error sending batch of order messages to topic {TopicName}",
                _topicName);
            throw;
        }
    }

    /// <summary>
    /// Lists all messages from a Service Bus subscription for testing purposes only.
    /// WARNING: This method is intended for development/testing scenarios only.
    /// </summary>
    /// <param name="subscriptionName">The name of the subscription to peek messages from.</param>
    /// <param name="maxMessages">Maximum number of messages to retrieve (default: 100).</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of orders with metadata retrieved from the subscription.</returns>
    /// <exception cref="ArgumentException">Thrown when subscriptionName is null or whitespace.</exception>
    /// <exception cref="ServiceBusException">Thrown when Service Bus operation fails.</exception>
    public async Task<IEnumerable<OrderMessageWithMetadata>> ListMessagesFromTopicAsync(
        string subscriptionName,
        int maxMessages = 100,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(subscriptionName))
        {
            throw new ArgumentException("Subscription name cannot be null or empty.", nameof(subscriptionName));
        }

        using var activity = _activitySource.StartActivity("ListMessagesFromTopic", ActivityKind.Consumer);
        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("messaging.destination.name", _topicName);
        activity?.SetTag("messaging.operation", "peek");
        activity?.SetTag("messaging.subscription.name", subscriptionName);
        activity?.SetTag("max.messages", maxMessages);

        // Create receiver with PeekLock mode (default) to allow abandoning messages
        await using var receiver = _serviceBusClient.CreateReceiver(_topicName, subscriptionName);
        try
        {
            // Use ReceiveMessagesAsync instead of PeekMessagesAsync for emulator compatibility
            // Messages will be locked but not removed, then abandoned to return them to the queue
            var receivedMessages = await receiver.ReceiveMessagesAsync(
                maxMessages: maxMessages,
                maxWaitTime: TimeSpan.FromSeconds(5),
                cancellationToken: cancellationToken);

            var ordersWithMetadata = new List<OrderMessageWithMetadata>();

            foreach (var message in receivedMessages)
            {
                try
                {
                    var messageBody = message.Body.ToString();
                    var order = JsonSerializer.Deserialize<Order>(messageBody, JsonOptions);

                    if (order != null)
                    {
                        var orderWithMetadata = new OrderMessageWithMetadata
                        {
                            Order = order,
                            MessageId = message.MessageId,
                            SequenceNumber = message.SequenceNumber,
                            EnqueuedTime = message.EnqueuedTime,
                            ContentType = message.ContentType,
                            Subject = message.Subject,
                            CorrelationId = message.CorrelationId,
                            MessageSize = message.Body.ToMemory().Length,
                            ApplicationProperties = message.ApplicationProperties.ToDictionary(kvp => kvp.Key, kvp => kvp.Value)
                        };

                        ordersWithMetadata.Add(orderWithMetadata);
                        activity?.AddEvent(new ActivityEvent("MessageReceived",
                            tags: new ActivityTagsCollection
                            {
                                { "message.id", message.MessageId },
                                { "order.id", order.Id },
                                { "sequence.number", message.SequenceNumber }
                            }));

                        // Abandon the message to return it to the queue for other consumers
                        // This simulates peek behavior - read without consuming
                        await receiver.AbandonMessageAsync(message, cancellationToken: cancellationToken);
                    }
                }
                catch (JsonException ex)
                {
                    _logger.LogWarning(ex,
                        "Failed to deserialize message {MessageId} from subscription {SubscriptionName}",
                        message.MessageId, subscriptionName);

                    // Still abandon malformed messages
                    try
                    {
                        await receiver.AbandonMessageAsync(message, cancellationToken: cancellationToken);
                    }
                    catch (Exception abandonEx)
                    {
                        _logger.LogWarning(abandonEx, "Failed to abandon message {MessageId}", message.MessageId);
                    }
                }
                catch (ServiceBusException ex)
                {
                    _logger.LogWarning(ex,
                        "Failed to abandon message {MessageId} from subscription {SubscriptionName}",
                        message.MessageId, subscriptionName);
                }
            }

            activity?.SetStatus(ActivityStatusCode.Ok);
            activity?.SetTag("messages.retrieved", ordersWithMetadata.Count);

            _logger.LogInformation(
                "Retrieved {Count} order messages from subscription {SubscriptionName} on topic {TopicName}",
                ordersWithMetadata.Count, subscriptionName, _topicName);

            return ordersWithMetadata;
        }
        catch (ServiceBusException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            activity?.SetTag("error.type", nameof(ServiceBusException));
            activity?.SetTag("exception.message", ex.Message);

            _logger.LogError(ex,
                "Failed to list messages from subscription {SubscriptionName} on topic {TopicName}. Reason: {Reason}",
                subscriptionName, _topicName, ex.Reason);
            throw;
        }
    }

    /// <summary>
    /// Lists all messages from all subscriptions for the configured topic.
    /// This is a simplified version that retrieves messages from a default subscription.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of message metadata from all topics.</returns>
    public async Task<IEnumerable<object>> ListMessagesAsync(CancellationToken cancellationToken)
    {
        using var activity = _activitySource.StartActivity("ListMessages", ActivityKind.Consumer);
        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("messaging.destination.name", _topicName);
        activity?.SetTag("messaging.operation", "peek");

        try
        {
            // For this implementation, we'll use a default subscription name
            // In production, you might want to make this configurable or query all subscriptions
            const string defaultSubscriptionName = "orderprocessingsub";

            var messages = await ListMessagesFromTopicAsync(
                defaultSubscriptionName,
                maxMessages: 100,
                cancellationToken);

            activity?.SetStatus(ActivityStatusCode.Ok);
            return messages.Cast<object>();
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            _logger.LogError(ex, "Failed to list messages from topic {TopicName}", _topicName);
            throw;
        }
    }
}
