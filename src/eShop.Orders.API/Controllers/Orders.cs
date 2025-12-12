using Microsoft.AspNetCore.Mvc;

namespace eShop.Orders.API.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class Orders : ControllerBase
    {
        private readonly ILogger<Orders> _logger;
        public Orders(ILogger<Orders> logger)
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
            return CreatedAtAction(nameof(GetOrder), new { id = order.Id }, order);
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

            return CreatedAtAction(nameof(GetOrder), new { id = orders.First().Id }, orders);
        }
    }
}
