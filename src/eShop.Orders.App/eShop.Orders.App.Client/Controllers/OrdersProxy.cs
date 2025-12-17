using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

public class OrdersProxy
{
    private readonly HttpClient _httpClient;

    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true
    };

    public OrdersProxy(HttpClient httpClient)
    {
        _httpClient = httpClient;
    }

    public async Task<HttpResponseMessage> PlaceOrder(string orderJson)
    {
        var content = new StringContent(orderJson, Encoding.UTF8, "application/json");
        return await _httpClient.PostAsync("/api/orders", content);
    }
}