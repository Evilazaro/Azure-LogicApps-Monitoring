// =============================================================================
// No-Op Orders Message Handler
// Stub implementation for development environments without Service Bus
// =============================================================================

using app.ServiceDefaults.CommonTypes;
using eShop.Orders.API.Interfaces;

namespace eShop.Orders.API.Handlers;

/// <summary>
/// No-operation implementation of <see cref="IOrdersMessageHandler"/> for development environments without Service Bus.
/// Logs intended operations without actually sending messages to any message broker.
/// </summary>
/// <remarks>
/// This handler is automatically registered when Service Bus is not configured,
/// allowing the application to run in local development mode without a message broker.
/// </remarks>
public sealed class NoOpOrdersMessageHandler : IOrdersMessageHandler
{
    private readonly ILogger<NoOpOrdersMessageHandler> _logger;

    /// <summary>
    /// Initializes a new instance of the <see cref="NoOpOrdersMessageHandler"/> class.
    /// </summary>
    /// <param name="logger">The logger instance for structured logging.</param>
    /// <exception cref="ArgumentNullException">Thrown when logger is null.</exception>
    public NoOpOrdersMessageHandler(ILogger<NoOpOrdersMessageHandler> logger)
    {
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <inheritdoc />
    /// <remarks>Logs the order ID that would be sent without actually publishing to a message broker.</remarks>
    public Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(order);
        _logger.LogInformation("NoOp: Would send order message for order {OrderId}", order.Id);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    /// <remarks>Logs the count of orders that would be sent without actually publishing to a message broker.</remarks>
    public Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken)
    {
        ArgumentNullException.ThrowIfNull(orders);

        var count = orders is ICollection<Order> collection ? collection.Count : orders.Count();
        _logger.LogInformation("NoOp: Would send batch of {Count} order messages", count);
        return Task.CompletedTask;
    }

    /// <inheritdoc />
    /// <remarks>Returns an empty collection as no actual messages exist without a message broker.</remarks>
    public Task<IEnumerable<object>> ListMessagesAsync(CancellationToken cancellationToken)
    {
        _logger.LogInformation("NoOp: Would list messages from topics");
        return Task.FromResult(Enumerable.Empty<object>());
    }
}