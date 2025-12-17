using System.Diagnostics;
using System.Net.Http.Json;
using eShop.Orders.App.Client.Models;
using Microsoft.Extensions.Logging;

namespace eShop.Orders.App.Client.Services;

/// <summary>
/// Provides order management operations with comprehensive OpenTelemetry instrumentation.
/// Calls the server's proxy endpoints which forward requests to the Orders API using Aspire service discovery.
/// </summary>
public sealed class OrderService
{
    // Use proxy endpoint instead of direct API call
    private const string OrdersProxyEndpoint = "/api/proxy/orders";
    private const string ActivitySourceName = "eShop.Orders.Client";
    
    private static readonly ActivitySource ActivitySource = new(ActivitySourceName);
    private readonly HttpClient _httpClient;
    private readonly ILogger<OrderService> _logger;

    public OrderService(HttpClient httpClient, ILogger<OrderService> logger)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Places an order asynchronously with full distributed tracing support.
    /// Calls the server's proxy endpoint which forwards to the Orders API.
    /// </summary>
    public async Task<OrderResult> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = ActivitySource.StartActivity("PlaceOrder", ActivityKind.Client);
        
        try
        {
            activity?.SetTag("order.id", order.Id);
            activity?.SetTag("order.quantity", order.Quantity);
            activity?.SetTag("order.total", order.Total);
            activity?.SetTag("proxy.endpoint", OrdersProxyEndpoint);

            _logger.LogInformation(
                "Placing order {OrderId} with quantity {Quantity} and total {Total} via proxy",
                order.Id, order.Quantity, order.Total);

            var response = await _httpClient.PostAsJsonAsync(OrdersProxyEndpoint, order, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
                _logger.LogInformation("Order {OrderId} placed successfully via proxy", order.Id);
                return OrderResult.Success("Order placed successfully!");
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                var errorMessage = $"Failed to place order: {(int)response.StatusCode} - {errorContent}";
                
                activity?.SetStatus(ActivityStatusCode.Error, errorMessage);
                _logger.LogWarning(
                    "Failed to place order {OrderId} via proxy. Status: {StatusCode}, Error: {Error}",
                    order.Id, response.StatusCode, errorContent);
                
                return OrderResult.Failure(errorMessage);
            }
        }
        catch (HttpRequestException ex)
        {
            var errorMessage = $"Network error while placing order: {ex.Message}";
            activity?.SetStatus(ActivityStatusCode.Error, errorMessage);
            activity?.AddException(ex);
            _logger.LogError(ex, "HTTP request error occurred while placing order {OrderId}", order.Id);
            return OrderResult.Failure(errorMessage);
        }
        catch (Exception ex)
        {
            var errorMessage = $"Error while placing order: {ex.Message}";
            activity?.SetStatus(ActivityStatusCode.Error, errorMessage);
            activity?.AddException(ex);
            _logger.LogError(ex, "Unexpected error occurred while placing order {OrderId}", order.Id);
            return OrderResult.Failure(errorMessage);
        }
    }
}

/// <summary>
/// Represents the result of an order operation.
/// </summary>
public sealed class OrderResult
{
    public bool IsSuccess { get; init; }
    public string Message { get; init; } = string.Empty;

    private OrderResult() { }

    public static OrderResult Success(string message) => new() { IsSuccess = true, Message = message };
    public static OrderResult Failure(string message) => new() { IsSuccess = false, Message = message };
}