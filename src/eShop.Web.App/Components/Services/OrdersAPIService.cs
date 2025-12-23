using app.ServiceDefaults.CommonTypes;
using System.Diagnostics;

namespace eShop.Web.App.Components.Services;

/// <summary>
/// Provides HTTP client-based service for communicating with the Orders API.
/// Implements distributed tracing and structured logging for all operations.
/// </summary>
public sealed class OrdersAPIService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<OrdersAPIService> _logger;
    private readonly ActivitySource _activitySource;

    /// <summary>
    /// Initializes a new instance of the <see cref=\"OrdersAPIService\"/> class.
    /// </summary>
    /// <param name=\"httpClient\">The HTTP client for API communication.</param>
    /// <param name=\"logger\">The logger instance for structured logging.</param>
    /// <param name=\"activitySource\">The activity source for distributed tracing.</param>
    /// <exception cref=\"ArgumentNullException\">Thrown when any parameter is null.</exception>
    public OrdersAPIService(
        HttpClient httpClient,
        ILogger<OrdersAPIService> logger,
        ActivitySource activitySource)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _activitySource = activitySource ?? throw new ArgumentNullException(nameof(activitySource));
    }

    /// <summary>
    /// Places a new order through the Orders API.
    /// </summary>
    /// <param name="order">The order to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The created order.</returns>
    /// <exception cref="ArgumentNullException">Thrown when order is null.</exception>
    /// <exception cref="ArgumentException">Thrown when order ID is invalid.</exception>
    /// <exception cref="HttpRequestException">Thrown when API request fails.</exception>
    public async Task<Order> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        if (string.IsNullOrWhiteSpace(order.Id))
        {
            throw new ArgumentException("Order ID is required", nameof(order));
        }

        using var activity = _activitySource.StartActivity("PlaceOrder", ActivityKind.Client);
        activity?.SetTag("order.id", order.Id);
        activity?.SetTag("order.customer_id", order.CustomerId);
        activity?.SetTag("http.method", "POST");
        activity?.SetTag("http.url", $"{_httpClient.BaseAddress}api/orders");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["OrderId"] = order.Id
        });

        try
        {
            _logger.LogInformation("Placing order with ID: {OrderId}", order.Id);

            var response = await _httpClient.PostAsJsonAsync("api/orders", order, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            var createdOrder = await response.Content.ReadFromJsonAsync<Order>(cancellationToken: cancellationToken).ConfigureAwait(false);

            if (createdOrder == null)
            {
                throw new InvalidOperationException("Failed to deserialize created order response");
            }

            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Order {OrderId} placed successfully", createdOrder.Id);
            return createdOrder;
        }
        catch (HttpRequestException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, $"HTTP error: {ex.StatusCode}");
            _logger.LogError(ex, "HTTP error while placing order with ID: {OrderId}. Status: {StatusCode}",
                order.Id, ex.StatusCode);
            throw;
        }
        catch (Exception ex) when (ex is not ArgumentException)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while placing order with ID: {OrderId}", order.Id);
            throw;
        }
    }

    /// <summary>
    /// Places multiple orders in a batch operation through the Orders API.
    /// </summary>
    /// <param name="orders">The collection of orders to be placed.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of successfully placed orders.</returns>
    /// <exception cref="ArgumentNullException">Thrown when orders is null.</exception>
    /// <exception cref="ArgumentException">Thrown when orders collection is empty.</exception>
    /// <exception cref="HttpRequestException">Thrown when API request fails.</exception>
    public async Task<IEnumerable<Order>> PlaceOrdersBatchAsync(IEnumerable<Order> orders, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(orders);

        using var activity = _activitySource.StartActivity("PlaceOrdersBatch", ActivityKind.Client);

        var ordersList = orders.ToList();
        if (ordersList.Count == 0)
        {
            throw new ArgumentException("Orders collection cannot be empty", nameof(orders));
        }

        activity?.SetTag("orders.count", ordersList.Count);
        activity?.SetTag("http.method", "POST");
        activity?.SetTag("http.url", $"{_httpClient.BaseAddress}api/orders/batch");

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["OrdersCount"] = ordersList.Count
        });

        try
        {
            _logger.LogInformation("Placing batch of {Count} orders", ordersList.Count);

            var response = await _httpClient.PostAsJsonAsync("api/orders/batch", ordersList, cancellationToken).ConfigureAwait(false);
            response.EnsureSuccessStatusCode();

            var placedOrders = await response.Content.ReadFromJsonAsync<IEnumerable<Order>>(cancellationToken: cancellationToken).ConfigureAwait(false);

            var result = placedOrders ?? Enumerable.Empty<Order>();
            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Batch processing complete. {Count} orders placed successfully", result.Count());
            return result;
        }
        catch (HttpRequestException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, $"HTTP error: {ex.StatusCode}");
            _logger.LogError(ex, "HTTP error while placing batch of orders. Status: {StatusCode}", ex.StatusCode);
            throw;
        }
        catch (Exception ex) when (ex is not ArgumentException)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while placing batch of orders");
            throw;
        }
    }

    /// <summary>
    /// Retrieves all orders from the Orders API.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of all orders.</returns>
    /// <exception cref="HttpRequestException">Thrown when API request fails.</exception>
    public async Task<IEnumerable<Order>> GetOrdersAsync(CancellationToken cancellationToken = default)
    {
        using var activity = _activitySource.StartActivity("GetOrders", ActivityKind.Client);

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none"
        });

        try
        {
            _logger.LogInformation("Retrieving all orders from orders-api");

            var orders = await _httpClient.GetFromJsonAsync<IEnumerable<Order>>("api/orders", cancellationToken).ConfigureAwait(false);
            var result = orders ?? Enumerable.Empty<Order>();

            activity?.SetTag("orders.count", result.Count());
            activity?.SetStatus(ActivityStatusCode.Ok);
            _logger.LogInformation("Successfully retrieved {Count} orders", result.Count());
            return result;
        }
        catch (HttpRequestException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, $"HTTP error: {ex.StatusCode}");
            _logger.LogError(ex, "HTTP error while fetching orders from orders-api. Status: {StatusCode}", ex.StatusCode);
            throw;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while fetching orders from orders-api");
            throw;
        }
    }

    /// <summary>
    /// Retrieves a specific order by its unique identifier from the Orders API.
    /// </summary>
    /// <param name="orderId">The unique identifier of the order.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>The order if found; otherwise, null.</returns>
    /// <exception cref="ArgumentException">Thrown when orderId is null or empty.</exception>
    /// <exception cref="HttpRequestException">Thrown when API request fails (excluding 404).</exception>
    public async Task<Order?> GetOrderByIdAsync(string orderId, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(orderId))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(orderId));
        }

        using var activity = _activitySource.StartActivity("GetOrderById", ActivityKind.Client);
        activity?.SetTag("order.id", orderId);

        using var logScope = _logger.BeginScope(new Dictionary<string, object>
        {
            ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "none",
            ["OrderId"] = orderId
        });

        try
        {
            _logger.LogInformation("Retrieving order with ID: {OrderId}", orderId);

            var order = await _httpClient.GetFromJsonAsync<Order>($"api/orders/{orderId}", cancellationToken).ConfigureAwait(false);

            if (order == null)
            {
                activity?.SetStatus(ActivityStatusCode.Error, "Order not found");
                _logger.LogWarning("Order with ID {OrderId} not found", orderId);
            }
            else
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
            }

            return order;
        }
        catch (HttpRequestException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            activity?.SetStatus(ActivityStatusCode.Error, "Order not found (404)");
            _logger.LogWarning("Order with ID {OrderId} not found (404)", orderId);
            return null;
        }
        catch (HttpRequestException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, $"HTTP error: {ex.StatusCode}");
            _logger.LogError(ex, "HTTP error while fetching order {OrderId} from orders-api. Status: {StatusCode}",
                orderId, ex.StatusCode);
            throw;
        }
        catch (Exception ex) when (ex is not ArgumentException)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            _logger.LogError(ex, "Unexpected error while fetching order {OrderId} from orders-api", orderId);
            throw;
        }
    }

    /// <summary>
    /// Retrieves weather forecast data from the Orders API.
    /// </summary>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>A collection of weather forecasts, or null if unavailable.</returns>
    /// <exception cref="HttpRequestException">Thrown when API request fails.</exception>
    public async Task<IEnumerable<WeatherForecast>?> GetWeatherForecastAsync(CancellationToken cancellationToken = default)
    {
        using var activity = _activitySource.StartActivity("GetWeatherForecast", ActivityKind.Client);

        try
        {
            _logger.LogInformation("Fetching weather forecasts from orders-api");
            var forecasts = await _httpClient.GetFromJsonAsync<IEnumerable<WeatherForecast>>("WeatherForecast", cancellationToken).ConfigureAwait(false);

            activity?.SetTag("forecasts.count", forecasts?.Count() ?? 0);
            _logger.LogInformation("Successfully retrieved {Count} weather forecasts", forecasts?.Count() ?? 0);
            return forecasts;
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "HTTP error while fetching weather forecasts from orders-api. Status: {StatusCode}", ex.StatusCode);
            throw;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unexpected error while fetching weather forecasts from orders-api");
            throw;
        }
    }

    /// <summary>
    /// Updates an existing order through the Orders API.
    /// </summary>
    /// <param name="id">The unique identifier of the order to update.</param>
    /// <param name="order">The updated order data.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>True if the order was successfully updated; otherwise, false.</returns>
    /// <exception cref="ArgumentException">Thrown when id is null or empty.</exception>
    /// <exception cref="ArgumentNullException">Thrown when order is null.</exception>
    /// <exception cref="HttpRequestException">Thrown when API request fails.</exception>
    public async Task<bool> UpdateOrderAsync(string id, Order order, CancellationToken cancellationToken = default)
    {
        using var activity = _activitySource.StartActivity("UpdateOrder", ActivityKind.Client);
        activity?.SetTag("order.id", id);

        if (string.IsNullOrWhiteSpace(id))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(id));
        }

        ArgumentNullException.ThrowIfNull(order);

        try
        {
            _logger.LogInformation("Updating order {OrderId}", id);
            var response = await _httpClient.PutAsJsonAsync($"api/orders/{id}", order, cancellationToken).ConfigureAwait(false);
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
            _logger.LogError(ex, "HTTP error while updating order {OrderId}. Status: {StatusCode}", id, ex.StatusCode);
            throw;
        }
        catch (Exception ex) when (ex is not ArgumentException)
        {
            _logger.LogError(ex, "Unexpected error while updating order {OrderId}", id);
            throw;
        }
    }

    /// <summary>
    /// Deletes an order by its unique identifier through the Orders API.
    /// </summary>
    /// <param name="id">The unique identifier of the order to delete.</param>
    /// <param name="cancellationToken">Cancellation token to cancel the operation.</param>
    /// <returns>True if the order was successfully deleted; otherwise, false.</returns>
    /// <exception cref="ArgumentException">Thrown when id is null or empty.</exception>
    /// <exception cref="HttpRequestException">Thrown when API request fails.</exception>
    public async Task<bool> DeleteOrderAsync(string id, CancellationToken cancellationToken = default)
    {
        using var activity = _activitySource.StartActivity("DeleteOrder", ActivityKind.Client);
        activity?.SetTag("order.id", id);

        if (string.IsNullOrWhiteSpace(id))
        {
            throw new ArgumentException("Order ID cannot be null or empty", nameof(id));
        }

        try
        {
            _logger.LogInformation("Deleting order {OrderId}", id);
            var response = await _httpClient.DeleteAsync($"api/orders/{id}", cancellationToken).ConfigureAwait(false);
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
            _logger.LogError(ex, "HTTP error while deleting order {OrderId}. Status: {StatusCode}", id, ex.StatusCode);
            throw;
        }
        catch (Exception ex) when (ex is not ArgumentException)
        {
            _logger.LogError(ex, "Unexpected error while deleting order {OrderId}", id);
            throw;
        }
    }
}
