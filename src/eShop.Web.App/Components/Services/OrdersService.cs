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

    public async Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Placing order with ID: {OrderId}", order.Id);

        if (string.IsNullOrWhiteSpace(order.Id))
        {
            throw new ArgumentException("Order ID is required", nameof(order));
        }

        try
        {
            var response = await _httpClient.PostAsJsonAsync("api/orders", order, cancellationToken);
            response.EnsureSuccessStatusCode();
            var createdOrder = await response.Content.ReadFromJsonAsync<Order>(cancellationToken: cancellationToken);
            
            _logger.LogInformation("Order {OrderId} placed successfully", createdOrder?.Id);
            return createdOrder!;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error placing order with ID: {OrderId}", order.Id);
            throw;
        }
    }

    public async Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Placing batch of {Count} orders", orders.Count());

        try
        {
            var response = await _httpClient.PostAsJsonAsync("api/orders/batch", orders, cancellationToken);
            response.EnsureSuccessStatusCode();
            var placedOrders = await response.Content.ReadFromJsonAsync<IEnumerable<Order>>(cancellationToken: cancellationToken);
            
            _logger.LogInformation("Batch processing complete. {Count} orders placed successfully", placedOrders?.Count() ?? 0);
            return placedOrders ?? Enumerable.Empty<Order>();
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error placing batch of orders");
            throw;
        }
    }

    public async Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            _logger.LogInformation("Retrieving all orders from orders-api");
            var orders = await _httpClient.GetFromJsonAsync<IEnumerable<Order>>("api/orders", cancellationToken);
            _logger.LogInformation("Successfully retrieved {Count} orders", orders?.Count() ?? 0);
            return orders ?? Enumerable.Empty<Order>();
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error fetching orders from orders-api");
            throw;
        }
    }

    public async Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Retrieving order with ID: {OrderId}", orderId);

        try
        {
            var order = await _httpClient.GetFromJsonAsync<Order>($"api/orders/{orderId}", cancellationToken);
            
            if (order == null)
            {
                _logger.LogWarning("Order with ID {OrderId} not found", orderId);
            }

            return order;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error fetching order {OrderId} from orders-api", orderId);
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
