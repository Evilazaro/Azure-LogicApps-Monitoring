// =============================================================================
// Orders Message Handler Interface
// Defines the contract for order message publishing operations
// =============================================================================

using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Interfaces;

/// <summary>
/// Defines the contract for publishing order messages to a message broker.
/// </summary>
public interface IOrdersMessageHandler
{
    /// <summary>
    /// Sends a single order message asynchronously.
    /// </summary>
    /// <param name="order">The order to be published.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken);

    /// <summary>
    /// Sends multiple order messages in a batch asynchronously.
    /// </summary>
    /// <param name="orders">The collection of orders to be published.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken);

    /// <summary>
    /// Lists all messages from topics asynchronously.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of message metadata from all topics.</returns>
    Task<IEnumerable<object>> ListMessagesAsync(CancellationToken cancellationToken);
}