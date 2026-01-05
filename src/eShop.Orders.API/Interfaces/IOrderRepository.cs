// =============================================================================
// Order Repository Interface
// Defines the contract for order data persistence operations
// =============================================================================

using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Interfaces;

/// <summary>
/// Defines the contract for order data persistence operations.
/// </summary>
public interface IOrderRepository
{
    /// <summary>
    /// Saves an order to the data store asynchronously.
    /// </summary>
    /// <param name="order">The order to save.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A task representing the asynchronous operation.</returns>
    Task SaveOrderAsync(Order order, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all orders from the data store asynchronously.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of all orders.</returns>
    Task<IEnumerable<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a specific order by its unique identifier.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The order if found; otherwise, null.</returns>
    Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default);

    /// <summary>
    /// Deletes an order from the data store by its unique identifier.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order to delete.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>True if the order was successfully deleted; otherwise, false.</returns>
    Task<bool> DeleteOrderAsync(string orderId, CancellationToken cancellationToken = default);
}