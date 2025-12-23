using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Services.Interfaces;

public interface IOrderService
{
    Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default);
    Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default);
    Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default);
    Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default);
    Task<bool> DeleteOrderAsync(string orderId, CancellationToken cancellationToken = default);
}