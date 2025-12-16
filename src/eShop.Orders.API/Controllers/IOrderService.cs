using eShop.Orders.API.Models;

namespace eShop.Orders.API.Services;

/// <summary>
/// Defines operations for managing orders
/// </summary>
public interface IOrderService
{
    /// <summary>
    /// Sends an order message to the message queue
    /// </summary>
    /// <param name="order">The order to send</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A task representing the asynchronous operation</returns>
    Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends multiple order messages to the message queue in a batch
    /// </summary>
    /// <param name="orders">The collection of orders to send</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A task representing the asynchronous operation</returns>
    Task SendOrderBatchMessagesAsync(IReadOnlyList<Order> orders, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all orders from storage
    /// </summary>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>A read-only list of all orders</returns>
    Task<IReadOnlyList<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a specific order by its identifier
    /// </summary>
    /// <param name="id">The order identifier</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>The order if found; otherwise, null</returns>
    Task<Order?> GetOrderByIdAsync(int id, CancellationToken cancellationToken = default);
}