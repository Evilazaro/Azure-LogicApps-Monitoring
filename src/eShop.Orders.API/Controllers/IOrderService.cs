using eShop.Orders.API.Controllers;

namespace eShop.Orders.API.Services;

/// <summary>
/// Service for managing order operations
/// </summary>
public interface IOrderService
{
    /// <summary>
    /// Sends an order message to the Service Bus queue
    /// </summary>
    Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends multiple order messages to the Service Bus queue as a batch
    /// </summary>
    Task SendOrderBatchMessagesAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves all orders from storage
    /// </summary>
    Task<List<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// Retrieves a specific order by ID
    /// </summary>
    Task<Order?> GetOrderByIdAsync(int id, CancellationToken cancellationToken = default);
}