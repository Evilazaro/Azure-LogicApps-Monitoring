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
    }
}
