using Azure.Messaging.ServiceBus;
using eShop.Orders.API.Controllers;
using System.Text;
using System.Text.Json;

namespace eShop.Orders.API.Services;

/// <summary>
/// Implementation of order service for managing order operations
/// </summary>
public sealed class OrderService : IOrderService
{
    private readonly ServiceBusClient _serviceBusClient;
    private readonly IConfiguration _configuration;
    private readonly ILogger<OrderService> _logger;
    private readonly string _queueName;
    private readonly string _ordersFilePath;

    public OrderService(
        ServiceBusClient serviceBusClient,
        IConfiguration configuration,
        ILogger<OrderService> logger)
    {
        _serviceBusClient = serviceBusClient ?? throw new ArgumentNullException(nameof(serviceBusClient));
        _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));

        _queueName = _configuration.GetValue<string>("ServiceBus:QueueName")
            ?? throw new InvalidOperationException("ServiceBus:QueueName configuration is required");

        _ordersFilePath = _configuration.GetValue<string>("Orders:FilePath") ?? "allOrders.json";
    }

    public async Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        await using var sender = _serviceBusClient.CreateSender(_queueName);

        try
        {
            var messageBody = JsonSerializer.Serialize(order);
            var serviceBusMessage = new ServiceBusMessage(Encoding.UTF8.GetBytes(messageBody))
            {
                ContentType = "application/json",
                MessageId = Guid.NewGuid().ToString(),
                Subject = "OrderPlaced",
                ApplicationProperties =
                {
                    ["OrderId"] = order.Id,
                    ["Timestamp"] = DateTime.UtcNow
                }
            };

            await sender.SendMessageAsync(serviceBusMessage, cancellationToken);
            _logger.LogInformation("Order {OrderId} sent to queue {QueueName} successfully", order.Id, _queueName);
        }
        catch (ServiceBusException ex)
        {
            _logger.LogError(ex, "Failed to send order {OrderId} to Service Bus queue {QueueName}", order.Id, _queueName);
            throw;
        }
    }

    public async Task SendOrderBatchMessagesAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(orders);

        var orderList = orders.ToList();
        if (orderList.Count == 0)
        {
            _logger.LogWarning("Attempted to send empty order batch");
            return;
        }

        await using var sender = _serviceBusClient.CreateSender(_queueName);

        try
        {
            using var messageBatch = await sender.CreateMessageBatchAsync(cancellationToken);
            var addedCount = 0;

            foreach (var order in orderList)
            {
                var messageBody = JsonSerializer.Serialize(order);
                var serviceBusMessage = new ServiceBusMessage(Encoding.UTF8.GetBytes(messageBody))
                {
                    ContentType = "application/json",
                    MessageId = Guid.NewGuid().ToString(),
                    Subject = "OrderPlaced",
                    ApplicationProperties =
                    {
                        ["OrderId"] = order.Id,
                        ["Timestamp"] = DateTime.UtcNow
                    }
                };

                if (!messageBatch.TryAddMessage(serviceBusMessage))
                {
                    _logger.LogWarning("Order {OrderId} could not be added to batch due to size constraints", order.Id);
                }
                else
                {
                    addedCount++;
                }
            }

            if (addedCount > 0)
            {
                await sender.SendMessagesAsync(messageBatch, cancellationToken);
                _logger.LogInformation("Batch of {Count} orders sent to queue {QueueName} successfully", addedCount, _queueName);
            }
            else
            {
                _logger.LogWarning("No orders were added to batch");
            }
        }
        catch (ServiceBusException ex)
        {
            _logger.LogError(ex, "Failed to send order batch to Service Bus queue {QueueName}", _queueName);
            throw;
        }
    }

    public async Task<List<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default)
    {
        return await ReadOrdersFromJsonFileAsync(cancellationToken);
    }

    public async Task<Order?> GetOrderByIdAsync(int id, CancellationToken cancellationToken = default)
    {
        var orders = await ReadOrdersFromJsonFileAsync(cancellationToken);
        return orders.FirstOrDefault(o => o.Id == id);
    }

    private async Task<List<Order>> ReadOrdersFromJsonFileAsync(CancellationToken cancellationToken = default)
    {
        if (!File.Exists(_ordersFilePath))
        {
            _logger.LogInformation("Orders file {FilePath} does not exist, returning empty list", _ordersFilePath);
            return [];
        }

        try
        {
            await using var fileStream = File.OpenRead(_ordersFilePath);
            var orders = await JsonSerializer.DeserializeAsync<List<Order>>(fileStream, cancellationToken: cancellationToken);
            return orders ?? [];
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to deserialize orders from file {FilePath}", _ordersFilePath);
            return [];
        }
        catch (IOException ex)
        {
            _logger.LogError(ex, "IO error reading orders file {FilePath}", _ordersFilePath);
            throw;
        }
    }
}