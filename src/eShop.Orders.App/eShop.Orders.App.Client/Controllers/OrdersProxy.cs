using System.Diagnostics;
using System.Text;
using System.Text.Json;

namespace eShop.Orders.App.Client.Controllers;

/// <summary>
/// Proxy client for Orders API with distributed tracing support.
/// Automatically propagates trace context to API calls for end-to-end correlation.
/// </summary>
public sealed class OrdersProxy
{
    private readonly HttpClient _httpClient;
    private static readonly ActivitySource _activitySource = new("eShop.Orders.App.Client");

    private static readonly JsonSerializerOptions _jsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true
    };

    /// <summary>
    /// Initializes a new instance of the OrdersProxy.
    /// </summary>
    /// <param name="httpClient">HTTP client for API communication.</param>
    /// <exception cref="ArgumentNullException">Thrown when httpClient is null.</exception>
    public OrdersProxy(HttpClient httpClient)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
    }

    /// <summary>
    /// Places an order through the Orders API with distributed tracing.
    /// </summary>
    /// <param name="orderJson">JSON representation of the order.</param>
    /// <returns>HTTP response from the API.</returns>
    public async Task<HttpResponseMessage> PlaceOrder(string orderJson)
    {
        // Create activity for client-side HTTP call
        using var activity = _activitySource.StartActivity(
            "OrdersProxy.PlaceOrder",
            ActivityKind.Client);

        try
        {
            activity?.SetTag("http.method", "POST");
            activity?.SetTag("http.url", "/api/Orders/PlaceOrder");
            activity?.SetTag("http.client", "orders-proxy");

            var content = new StringContent(orderJson, Encoding.UTF8, "application/json");

            activity?.AddEvent(new ActivityEvent("Sending order to API"));
            var response = await _httpClient.PostAsync("/api/Orders/PlaceOrder", content);

            activity?.SetTag("http.status_code", (int)response.StatusCode);

            if (response.IsSuccessStatusCode)
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
                activity?.AddEvent(new ActivityEvent("Order placed successfully"));
            }
            else
            {
                activity?.SetStatus(ActivityStatusCode.Error, $"HTTP {response.StatusCode}");
                activity?.AddEvent(new ActivityEvent($"Order placement failed: {response.StatusCode}"));
            }

            return response;
        }
        catch (HttpRequestException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            throw;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);
            throw;
        }
    }
}