using Microsoft.AspNetCore.Mvc;
using System.Text;
using System.Text.Json;

[ApiController]
[Route("api/orders")]
public class OrdersProxyController : ControllerBase
{
    private readonly HttpClient _ordersApiClient;

    public OrdersProxyController(IHttpClientFactory httpClientFactory)
    {
        _ordersApiClient = httpClientFactory.CreateClient("orders-api");
    }

    [HttpPost]
    public async Task<IActionResult> CreateOrder([FromBody] JsonElement orderData)
    {
        var content = new StringContent(orderData.ToString(), Encoding.UTF8, "application/json");
        var response = await _ordersApiClient.PostAsync("api/orders", content);
        
        var responseContent = await response.Content.ReadAsStringAsync();
        return StatusCode((int)response.StatusCode, responseContent);
    }
}