using app.ServiceDefaults.CommonTypes;
using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Interfaces;
using System.Diagnostics;
using System.Text.Json;

namespace eShop.Orders.API.Handlers;

public sealed class OrdersMessageHandler : IOrdersMessageHandler
{
    private readonly ILogger<OrdersMessageHandler> _logger;
    private readonly ServiceBusClient _serviceBusClient;
    private readonly string _topicName;
    private static readonly ActivitySource ActivitySource = new("eShop.Orders.API");
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public OrdersMessageHandler(
        ILogger<OrdersMessageHandler> logger,
        ServiceBusClient serviceBusClient,
        IConfiguration configuration)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _serviceBusClient = serviceBusClient ?? throw new ArgumentNullException(nameof(serviceBusClient));
        _topicName = configuration["Azure:ServiceBus:TopicName"] ?? "OrdersPlaced";
    }

    public async Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = ActivitySource.StartActivity("SendOrderMessage", ActivityKind.Producer);
        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("messaging.destination.name", _topicName);
        activity?.SetTag("messaging.operation", "publish");
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
            }

            await sender.SendMessageAsync(message, cancellationToken).ConfigureAwait(false);

            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Successfully sent order message for order {OrderId} to topic {TopicName}",
                order.Id, _topicName);
        }
        catch (ServiceBusException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Failed to send order message for order {OrderId} to topic {TopicName}",
                order.Id, _topicName);
            throw;
        }
    }

    public async Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(orders);

        using var activity = ActivitySource.StartActivity("SendOrdersBatchMessage", ActivityKind.Producer);

        var ordersList = orders.ToList();
        if (ordersList.Count == 0)
        {
            _logger.LogWarning("Empty orders collection provided for batch send");
            return;
        }

        activity?.SetTag("messaging.system", "servicebus");
        activity?.SetTag("messaging.destination.name", _topicName);
        activity?.SetTag("messaging.operation", "publish");
        activity?.SetTag("messaging.batch.message_count", ordersList.Count);

        await using var sender = _serviceBusClient.CreateSender(_topicName);

        try
        {
            var messages = new List<ServiceBusMessage>();

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
                }

                messages.Add(message);
            }

            await sender.SendMessagesAsync(messages, cancellationToken).ConfigureAwait(false);
            _logger.LogInformation("Successfully sent batch of {Count} order messages to topic {TopicName}",
                messages.Count, _topicName);
        }
        catch (ServiceBusException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Failed to send batch of order messages to topic {TopicName}", _topicName);
            throw;
        }
    }
}
