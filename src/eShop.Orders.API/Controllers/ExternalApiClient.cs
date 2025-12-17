using System.Diagnostics;

namespace eShop.Orders.API.Services;

/// <summary>
/// Example HTTP client service with distributed tracing.
/// Demonstrates context propagation across HTTP boundaries.
/// </summary>
public class ExternalApiClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<ExternalApiClient> _logger;
    private static readonly ActivitySource _activitySource = Extensions.CreateActivitySource();

    /// <summary>
    /// Initializes a new instance of the ExternalApiClient.
    /// </summary>
    /// <param name="httpClient">HTTP client with automatic trace propagation.</param>
    /// <param name="logger">Logger for structured logging.</param>
    /// <exception cref="ArgumentNullException">Thrown when required dependencies are null.</exception>
    public ExternalApiClient(HttpClient httpClient, ILogger<ExternalApiClient> logger)
    {
        _httpClient = httpClient ?? throw new ArgumentNullException(nameof(httpClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
    }

    /// <summary>
    /// Calls an external API with distributed tracing.
    /// Trace context is automatically propagated via HTTP headers.
    /// </summary>
    /// <param name="orderId">The order identifier to validate.</param>
    /// <returns>True if the order is valid, false otherwise.</returns>
    public async Task<bool> ValidateOrderAsync(string orderId)
    {
        // Create a custom span for this operation
        using var activity = _activitySource.StartActivity("ValidateOrder.ExternalApi", ActivityKind.Client);

        try
        {
            activity?.SetTag("order.id", orderId);
            activity?.SetTag("http.client.name", "external-api");

            _logger.LogInformation("Validating order {OrderId} with external API", orderId);

            // HTTP client instrumentation automatically adds trace headers:
            // - traceparent (W3C Trace Context)
            // - tracestate (vendor-specific context)
            var response = await _httpClient.GetAsync($"/api/validation/{orderId}");

            activity?.SetTag("http.response.status_code", (int)response.StatusCode);

            if (response.IsSuccessStatusCode)
            {
                activity?.SetStatus(ActivityStatusCode.Ok);
                activity?.AddEvent(new ActivityEvent("Order validated successfully"));
                return true;
            }

            activity?.SetTag("validation.failed", true);
            activity?.AddEvent(new ActivityEvent($"Validation failed with status {response.StatusCode}"));
            return false;
        }
        catch (HttpRequestException ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "HTTP error validating order {OrderId}", orderId);
            throw;
        }
        catch (Exception ex)
        {
            activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
            activity?.AddException(ex);

            _logger.LogError(ex, "Error validating order {OrderId}", orderId);
            throw;
        }
    }
}