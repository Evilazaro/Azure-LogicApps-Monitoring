using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Models;
using System.Collections.Concurrent;
using System.Text.Json;

namespace eShop.Orders.API.Services;

/// <summary>
/// Service implementation for managing orders with Azure Service Bus integration
/// </summary>
public sealed class OrderService : IOrderService
{
    private readonly ServiceBusSender _sender;
    private readonly ILogger<OrderService> _logger;

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

        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        var queueName = configuration["ServiceBus:QueueName"] ?? "orders";
        _sender = serviceBusClient.CreateSender(queueName);

        _logger.LogInformation("OrderService initialized with queue: {QueueName}", queueName);
    }

    /// <inheritdoc/>
    public async Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        try
        {
            var messageBody = JsonSerializer.Serialize(order, _jsonOptions);
            var message = new ServiceBusMessage(messageBody)
            {
                MessageId = Guid.NewGuid().ToString(),
                ContentType = "application/json",
                Subject = "OrderPlaced"
            };

            // Add metadata for correlation and tracking
            message.ApplicationProperties.Add("OrderId", order.Id);
            message.ApplicationProperties.Add("Timestamp", DateTimeOffset.UtcNow.ToString("o"));

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

            _logger.LogInformation(
                "Successfully sent order message. OrderId: {OrderId}, MessageId: {MessageId}",
                order.Id,
                message.MessageId);
        }
        catch (ServiceBusException ex)
        {
            _logger.LogError(
                ex,
                "Service Bus error sending order message. OrderId: {OrderId}, Reason: {Reason}",
                order.Id,
                ex.Reason);
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

        try
        {
            using var messageBatch = await _sender.CreateMessageBatchAsync(cancellationToken);
            var messagesAdded = 0;

            foreach (var order in orders)
            {
                var messageBody = JsonSerializer.Serialize(order, _jsonOptions);
                var message = new ServiceBusMessage(messageBody)
                {
                    MessageId = Guid.NewGuid().ToString(),
                    ContentType = "application/json",
                    Subject = "OrderPlaced"
                };

                message.ApplicationProperties.Add("OrderId", order.Id);
                message.ApplicationProperties.Add("Timestamp", DateTimeOffset.UtcNow.ToString("o"));

                if (!messageBatch.TryAddMessage(message))
                {
                    _logger.LogWarning(
                        "Message batch is full. Sending {Count} messages before adding more",
                        messagesAdded);

                    // Send current batch
                    await _sender.SendMessagesAsync(messageBatch, cancellationToken);
                    messagesAdded = 0;

                    // Create new batch and retry adding the message
                    using var newBatch = await _sender.CreateMessageBatchAsync(cancellationToken);
                    if (!newBatch.TryAddMessage(message))
                    {
                        throw new InvalidOperationException(
                            $"Message for OrderId {order.Id} is too large for a single batch");
                    }
                }

                messagesAdded++;
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

            _logger.LogInformation(
                "Successfully sent batch of {Count} order messages",
                orders.Count);
        }
        catch (ServiceBusException ex)
        {
            _logger.LogError(
                ex,
                "Service Bus error sending order batch. OrderCount: {Count}, Reason: {Reason}",
                orders.Count,
                ex.Reason);
            throw;
        }
    }

    /// <inheritdoc/>
    public Task<IReadOnlyList<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        var orders = _orderStore.Values.OrderByDescending(o => o.Date).ToList();

        _logger.LogDebug("Retrieved {Count} orders from storage", orders.Count);

        return Task.FromResult<IReadOnlyList<Order>>(orders);
    }

    /// <inheritdoc/>
    public Task<Order?> GetOrderByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        cancellationToken.ThrowIfCancellationRequested();

        _orderStore.TryGetValue(id, out var order);

        if (order is not null)
        {
            _logger.LogDebug("Retrieved order {OrderId} from storage", id);
        }
        else
        {
            _logger.LogDebug("Order {OrderId} not found in storage", id);
        }

        return Task.FromResult(order);
    }
}