using app.ServiceDefaults.CommonTypes;
namespace eShop.Web.App.Components.Services;

public class OrdersService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<OrdersService> _logger;

    public OrdersService(HttpClient httpClient, ILogger<OrdersService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task<IEnumerable<Order>?> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Fetching orders from orders-api");
            var orders = await _httpClient.GetFromJsonAsync<IEnumerable<Order>>("api/orders", cancellationToken);
            _logger.LogInformation("Successfully retrieved {Count} orders", orders?.Count() ?? 0);
            return orders;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error fetching orders from orders-api");
            throw;
        }
    }

    public async Task<IEnumerable<WeatherForecast>?> GetWeatherForecastAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Fetching weather forecasts from orders-api");
            var forecasts = await _httpClient.GetFromJsonAsync<IEnumerable<WeatherForecast>>("WeatherForecast", cancellationToken);
            _logger.LogInformation("Successfully retrieved {Count} weather forecasts", forecasts?.Count() ?? 0);
            return forecasts;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error fetching weather forecasts from orders-api");
            throw;
        }
    }

    public async Task<Order?> GetOrderByIdAsync(string id, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Fetching order {OrderId} from orders-api", id);
            var order = await _httpClient.GetFromJsonAsync<Order>($"api/orders/{id}", cancellationToken);
            _logger.LogInformation("Successfully retrieved order {OrderId}", id);
            return order;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error fetching order {OrderId} from orders-api", id);
            throw;
        }
    }

    public async Task<Order?> CreateOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Creating new order");
            var response = await _httpClient.PostAsJsonAsync("api/orders", order, cancellationToken);
            response.EnsureSuccessStatusCode();
            var createdOrder = await response.Content.ReadFromJsonAsync<Order>(cancellationToken: cancellationToken);
            _logger.LogInformation("Successfully created order {OrderId}", createdOrder?.Id);
            return createdOrder;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error creating order");
            throw;
        }
    }

    public async Task<bool> UpdateOrderAsync(string id, Order order, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Updating order {OrderId}", id);
            var response = await _httpClient.PutAsJsonAsync($"api/orders/{id}", order, cancellationToken);
            var success = response.IsSuccessStatusCode;
            if (success)
            {
                _logger.LogInformation("Successfully updated order {OrderId}", id);
            }
            else
            {
                _logger.LogWarning("Failed to update order {OrderId}. Status code: {StatusCode}", id, response.StatusCode);
            }
            return success;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error updating order {OrderId}", id);
            throw;
        }
    }

    public async Task<bool> DeleteOrderAsync(string id, CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Deleting order {OrderId}", id);
            var response = await _httpClient.DeleteAsync($"api/orders/{id}", cancellationToken);
            var success = response.IsSuccessStatusCode;
            if (success)
            {
                _logger.LogInformation("Successfully deleted order {OrderId}", id);
            }
            else
            {
                _logger.LogWarning("Failed to delete order {OrderId}. Status code: {StatusCode}", id, response.StatusCode);
            }
            return success;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error deleting order {OrderId}", id);
            throw;
        }
    }
}

public record Order
{
    public string Id { get; init; } = string.Empty;
    public DateTime Date { get; init; }
    public int Quantity { get; init; }
    public decimal Total { get; init; }
    public string Message { get; init; } = string.Empty;
}