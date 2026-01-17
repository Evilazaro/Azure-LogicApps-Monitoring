// =============================================================================
// No-Op Orders Message Handler
// Stub implementation for development environments without Service Bus
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;

namespace eShop.Orders.API.Handlers;

/// <summary>
/// No-operation message handler for development environments without Service Bus.
/// </summary>
public sealed class NoOpOrdersMessageHandler : IOrdersMessageHandler
{
    private readonly ILogger<NoOpOrdersMessageHandler> _logger;

    public NoOpOrdersMessageHandler(ILogger<NoOpOrdersMessageHandler> logger)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    public Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(order);
        _logger.LogInformation("NoOp: Would send order message for order {OrderId}", order.Id);
        return Task.CompletedTask;
    }

    public Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(orders);

        var count = orders is ICollection<Order> collection ? collection.Count : orders.Count();
        _logger.LogInformation("NoOp: Would send batch of {Count} order messages", count);
        return Task.CompletedTask;
    }

    public Task<IEnumerable<object>> ListMessagesAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("NoOp: Would list messages from topics");
        return Task.FromResult(Enumerable.Empty<object>());
    }
}