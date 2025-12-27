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
        _logger.LogInformation("NoOp: Would send order message for order {OrderId}", order.Id);
        return Task.CompletedTask;
    }

    public Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        var ordersList = orders?.ToList() ?? new List<Order>();
        _logger.LogInformation("NoOp: Would send batch of {Count} order messages", ordersList.Count);
        return Task.CompletedTask;
    }
}