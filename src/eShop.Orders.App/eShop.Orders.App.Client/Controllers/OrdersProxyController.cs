using System.Text;

public class OrdersProxy
{
    private readonly HttpClient _ordersApiClient;

    public OrdersProxy(HttpClient httpClient)
    {
        _ordersApiClient = httpClient;
    }

    public async Task<HttpResponseMessage> CreateOrder(string orderData)
    {
        var content = new StringContent(orderData, Encoding.UTF8, "application/json");
        var response = await _ordersApiClient.PostAsync("api/orders", content);
        return response;
    }
}