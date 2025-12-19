using app.ServiceDefaults.CommonTypes;

namespace eShop.Orders.API.Services;

public class OrdersWrapper
{
    public List<Order> Orders { get; set; } = [];
}