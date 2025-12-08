using Microsoft.AspNetCore.Mvc;

namespace PoProcAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class OrderController : ControllerBase
    {
        private readonly ILogger<OrderController> _logger;

        public OrderController(ILogger<OrderController> logger)
        {
            _logger = logger;
        }

        [HttpPost(Name = "ProcessOrder")]
        public IActionResult ProcessOrder([FromBody] OrderRequest orderRequest)
        {
            // Process the order
            _logger.LogInformation("Processing order: {OrderId}", orderRequest.OrderId);
            return Accepted();
        }
    }
}
