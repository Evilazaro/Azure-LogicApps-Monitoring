using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Services.Interfaces;

/// <summary>
/// Defines the contract for order service operations including placement, retrieval, and deletion.
/// </summary>
public interface IOrderService
{
    /// <summary>
    /// Places a new order asynchronously.
    /// </summary>
    /// <param name="order">The order to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The placed order.</returns>
    Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default);

    /// <summary>
    /// Places multiple orders in a batch operation asynchronously.
    /// </summary>
    /// <param name="orders">The collection of orders to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of successfully placed orders.</returns>
    Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all orders asynchronously.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of all orders.</returns>
    Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a specific order by its unique identifier.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The order if found; otherwise, null.</returns>
    Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Deletes an order by its unique identifier.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order to delete.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>True if the order was successfully deleted; otherwise, false.</returns>
    Task<bool> DeleteOrderAsync(string orderId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Deletes multiple orders in batch.
    /// </summary>
    /// <param name="orderIds">The collection of order IDs to delete.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The number of successfully deleted orders.</returns>
    Task<int> DeleteOrdersBatchAsync(IEnumerable<string> orderIds, CancellationToken cancellationToken);
}