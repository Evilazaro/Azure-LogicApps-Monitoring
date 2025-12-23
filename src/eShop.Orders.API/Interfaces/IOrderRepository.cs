using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Interfaces;

public interface IOrderRepository
{
    Task SaveOrderAsync(Order order, CancellationToken cancellationToken = default);
    Task<IEnumerable<Order>> GetAllOrdersAsync(CancellationToken cancellationToken = default);
    Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default);
    Task<bool> DeleteOrderAsync(string orderId, CancellationToken cancellationToken = default);
}