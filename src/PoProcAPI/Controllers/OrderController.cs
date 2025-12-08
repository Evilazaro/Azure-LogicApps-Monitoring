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
            using var activity = System.Diagnostics.Activity.Current?.Source.StartActivity("ProcessOrder");
            activity?.SetTag("order.id", orderRequest.OrderId);
            activity?.SetTag("operation.name", "ProcessOrder");

            try
            {
                // Process the order
                _logger.LogInformation("Processing order: {OrderId}", orderRequest.OrderId);

                activity?.SetStatus(System.Diagnostics.ActivityStatusCode.Ok);
                return Accepted();
            }
            catch (Exception ex)
            {
                activity?.SetStatus(System.Diagnostics.ActivityStatusCode.Error, ex.Message);
                _logger.LogError(ex, "Error processing order: {OrderId}", orderRequest.OrderId);
                throw;
            }
        }
    }
}
