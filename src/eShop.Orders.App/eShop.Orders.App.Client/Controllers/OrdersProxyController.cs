using Microsoft.AspNetCore.Mvc;
using System.Net.Http;
using System.Text;
using System.Text.Json;

public class OrdersProxy
{
    private readonly HttpClient _ordersApiClient;

    public OrdersProxy(HttpClient httpClient)
    {
        _ordersApiClient = httpClient;
    }

    public async Task<IActionResult> CreateOrder(string orderData)
    {
        var content = new StringContent(orderData, Encoding.UTF8, "application/json");
        var response = await _ordersApiClient.PostAsync("api/orders", content);

        var responseContent = await response.Content.ReadAsStringAsync();
        return new ContentResult
        {
            Content = responseContent,
            StatusCode = (int)response.StatusCode,
            ContentType = "application/json"
        };
    }
}