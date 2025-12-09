using Microsoft.AspNetCore.Mvc;

namespace PoProcAPI.Controllers
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

        [HttpPost(Name = "ProcessOrder")]
        public void processOrder(Order order)
        {
            _logger.LogInformation("Processing order with ID: {OrderId}", order.Id);
            
            // Simulate order processing logic here
            _logger.LogInformation("Order with ID: {OrderId} processed successfully", order.Id);

        }
    }
}
