using System.Diagnostics;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using eShop.Orders.App.Client.Models;
using Microsoft.Extensions.Logging;

namespace eShop.Orders.App.Client.Services;

/// <summary>
/// Provides order management operations with comprehensive OpenTelemetry instrumentation.
/// </summary>
public sealed class OrderService
{
    private const string OrdersApiEndpoint = "/api/orders";
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
    /// </summary>
    public async Task<OrderResult> PlaceOrderAsync(Order order, CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(order);

        using var activity = ActivitySource.StartActivity("PlaceOrder", ActivityKind.Producer);
        
        try
        {
            activity?.SetTag("order.id", order.Id);
            activity?.SetTag("order.quantity", order.Quantity);
            activity?.SetTag("order.total", order.Total);

            _logger.LogInformation(
                "Placing order {OrderId} with quantity {Quantity} and total {Total}",
                order.Id, order.Quantity, order.Total);

            var response = await _httpClient.PostAsJsonAsync(OrdersApiEndpoint, order, cancellationToken);

            if (response.IsSuccessStatusCode)
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
                _logger.LogInformation("Order {OrderId} placed successfully", order.Id);
                return OrderResult.Success("Order placed successfully!");
            }
            else
            {
                var errorContent = await response.Content.ReadAsStringAsync(cancellationToken);
                var errorMessage = $"Failed to place order: {(int)response.StatusCode} - {errorContent}";
                
                activity?.SetStatus(ActivityStatusCode.Error, errorMessage);
                _logger.LogWarning("Failed to place order {OrderId}. Status: {StatusCode}", order.Id, response.StatusCode);
                
                return OrderResult.Failure(errorMessage);
            }
        }
        catch (Exception ex)
        {
            var errorMessage = $"Error while placing order: {ex.Message}";
            activity?.SetStatus(ActivityStatusCode.Error, errorMessage);
            activity?.AddException(ex);
            _logger.LogError(ex, "Error occurred while placing order {OrderId}", order.Id);
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