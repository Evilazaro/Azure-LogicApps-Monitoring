using Microsoft.AspNetCore.Mvc;

namespace eShop.Orders.API.Controllers
{
    public class OrdersController : ControllerBase
    {
        private readonly ILogger<OrdersController> _logger;

        public OrdersController(ILogger<OrdersController> logger)
        {
            _logger = logger;
        }
    }
}
