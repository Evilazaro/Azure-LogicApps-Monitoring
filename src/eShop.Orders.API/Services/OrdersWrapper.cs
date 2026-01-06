using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Services;

public sealed class OrdersWrapper
{
    public required List<Order> Orders { get; init; } = [];
}