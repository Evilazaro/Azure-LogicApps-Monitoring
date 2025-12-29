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
        _topicName = configuration["Azure:ServiceBus:TopicName"] ?? "OrdersPlaced";
    }

    /// <summary>
    /// Sends a single order message to the Service Bus topic asynchronously.
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
            }

            await sender.SendMessageAsync(message, cancellationToken);

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
}
