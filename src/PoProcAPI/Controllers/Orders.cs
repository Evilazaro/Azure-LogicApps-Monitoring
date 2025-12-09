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
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public IActionResult ProcessOrder(Order order)
        {
            try
            {
                _logger.LogInformation("Processing order with ID: {OrderId}", order.Id);

                // Simulate order processing logic here

                _logger.LogInformation("Order with ID: {OrderId} processed successfully", order.Id);

                return Ok();
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing order with ID: {OrderId}", order.Id);
                return BadRequest(ex.Message);
            }
        }
    }
}
