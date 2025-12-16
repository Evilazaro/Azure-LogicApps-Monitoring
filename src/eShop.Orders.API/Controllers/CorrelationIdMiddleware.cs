using System.Diagnostics;

namespace eShop.Orders.API.Middleware;

/// <summary>
/// Middleware that ensures correlation IDs are present in requests and responses.
/// Integrates with distributed tracing by adding correlation ID to activity tags.
/// </summary>
public class CorrelationIdMiddleware
{
    private const string CorrelationIdHeaderName = "X-Correlation-ID";
    private readonly RequestDelegate _next;
    private readonly ILogger<CorrelationIdMiddleware> _logger;

    /// <summary>
    /// Initializes a new instance of the CorrelationIdMiddleware.
    /// </summary>
    /// <param name="next">The next middleware in the pipeline.</param>
    /// <param name="logger">Logger for diagnostics.</param>
    public CorrelationIdMiddleware(RequestDelegate next, ILogger<CorrelationIdMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    /// <summary>
    /// Processes the HTTP request and ensures correlation ID is present.
    /// </summary>
    /// <param name="context">The HTTP context.</param>
    public async Task InvokeAsync(HttpContext context)
    {
        // Get or generate correlation ID
        var correlationId = GetOrGenerateCorrelationId(context);

        // Add to activity for distributed tracing
        var activity = Activity.Current;
        if (activity != null)
        {
            activity.SetTag("correlation.id", correlationId);
            activity.SetBaggage("correlation.id", correlationId); // Propagates to child activities
        }

        // Add to response headers for client tracking
        context.Response.OnStarting(() =>
        {
            context.Response.Headers[CorrelationIdHeaderName] = correlationId;
            return Task.CompletedTask;
        });

        // Add to logging scope for log correlation
        using (_logger.BeginScope(new Dictionary<string, object>
        {
            ["CorrelationId"] = correlationId,
            ["TraceId"] = activity?.TraceId.ToString() ?? "unknown",
            ["SpanId"] = activity?.SpanId.ToString() ?? "unknown"
        }))
        {
            await _next(context);
        }
    }

    private string GetOrGenerateCorrelationId(HttpContext context)
    {
        // Check if correlation ID is provided in request header
        if (context.Request.Headers.TryGetValue(CorrelationIdHeaderName, out var correlationId) &&
            !string.IsNullOrEmpty(correlationId))
        {
            return correlationId.ToString();
        }

        // Use TraceId from current activity as correlation ID
        var activity = Activity.Current;
        if (activity != null)
        {
            return activity.TraceId.ToString();
        }

        // Generate new correlation ID if none exists
        return Guid.NewGuid().ToString();
    }
}

/// <summary>
/// Extension methods for registering CorrelationIdMiddleware.
/// </summary>
public static class CorrelationIdMiddlewareExtensions
{
    /// <summary>
    /// Adds correlation ID middleware to the application pipeline.
    /// </summary>
    /// <param name="builder">The application builder.</param>
    /// <returns>The application builder for method chaining.</returns>
    public static IApplicationBuilder UseCorrelationId(this IApplicationBuilder builder)
    {
        return builder.UseMiddleware<CorrelationIdMiddleware>();
    }
}