using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Mvc;

namespace eShop.Orders.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class OrdersController : ControllerBase
    {
        private readonly ILogger<OrdersController> _logger;
        public OrdersController(ILogger<OrdersController> logger)
        {
            _logger = logger;
        }
        [HttpPost(Name = "PlaceOrder")]
        public IActionResult PlaceOrder([FromBody] Order order)
        {
            if (order == null)
            {
                return BadRequest();
            }

            // Logic to place the order
            return Ok(new
            {
                order.Id,
                order.Date,
                order.Quantity,
                order.Total,
                Message = "Order placed successfully"
            });
        }

        [HttpGet(Name = "GetAllOrders")]
        public IEnumerable<Order> GetAllOrders()
        {
            // Logic to retrieve all orders
            var orders = new List<Order>
                {
                    new Order { Id = 1, Date = DateTime.Now, Quantity = 1, Total = 100.0 },
                    new Order { Id = 2, Date = DateTime.Now, Quantity = 2, Total = 200.0 }
                };

           return orders;
        }

        [HttpGet("{id}", Name = "GetOrder")]
        public IActionResult GetOrder(int id)
        {
            // Logic to retrieve the order

            return Ok(new
            {
                Id = id,
                Date = DateTime.Now,
                Quantity = 1,
                Total = 100.0,
                Message = "Order retrieved successfully"
            });
        }

        [HttpPost(Name = "PlaceOrdersBatch")]
        public IActionResult PlaceOrdersBatch([FromBody] List<Order> orders)
        {
            if (orders == null || orders.Count == 0)
            {
                return BadRequest();
            }

            // Logic to place the batch of orders

            return Ok( new
            {
                Message = "All orders placed successfully"
            });
        }
    }
}
