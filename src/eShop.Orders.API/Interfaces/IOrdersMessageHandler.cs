using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Interfaces
{
    public interface IOrdersMessageHandler
    {
        Task CloseAsync();
        Task GetOrderMessageAsync();
        Task SendOrderMessageAsync(Order order, CancellationToken cancellationToken);
        Task SendOrdersBatchMessageAsync(IEnumerable<Order> orders, CancellationToken cancellationToken);
    }
}