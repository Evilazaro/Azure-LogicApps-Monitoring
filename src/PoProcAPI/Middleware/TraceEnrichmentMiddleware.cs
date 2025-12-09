using PoProcAPI.Diagnostics;
using System.Diagnostics;

namespace PoProcAPI.Middleware
{
    /// <summary>
    /// Middleware to enrich traces with additional context and handle exceptions
    /// </summary>
    public class TraceEnrichmentMiddleware
    {
        private readonly RequestDelegate _next;
        private readonly ILogger<TraceEnrichmentMiddleware> _logger;

        public TraceEnrichmentMiddleware(RequestDelegate next, ILogger<TraceEnrichmentMiddleware> logger)
        {
            _next = next;
            _logger = logger;
        }

        public async Task InvokeAsync(HttpContext context)
        {
            var activity = Activity.Current;

            if (activity != null)
            {
                // Enrich with request information
                activity.SetTag("http.request.content_length", context.Request.ContentLength ?? 0);
                activity.SetTag("http.request.user_agent", context.Request.Headers.UserAgent.ToString());
                activity.SetTag("http.request.method", context.Request.Method);
                activity.SetTag("http.request.path", context.Request.Path);

                // Add client IP
                var clientIp = context.Connection.RemoteIpAddress?.ToString() ?? "unknown";
                activity.SetTag("client.address", clientIp);

                // Add correlation ID if present
                if (context.Request.Headers.ContainsKey("X-Correlation-Id"))
                {
                    var correlationId = context.Request.Headers["X-Correlation-Id"].ToString();
                    activity.SetTag("correlation.id", correlationId);
                    activity.AddBaggage(DiagnosticsConfig.BaggageKeys.CorrelationId, correlationId);
                }
                else
                {
                    // Generate correlation ID if not present
                    var correlationId = Guid.NewGuid().ToString();
                    activity.SetTag("correlation.id", correlationId);
                    activity.AddBaggage(DiagnosticsConfig.BaggageKeys.CorrelationId, correlationId);
                    context.Response.Headers.Append("X-Correlation-Id", correlationId);
                }

                // Add business flow context
                activity.AddBaggage(DiagnosticsConfig.BaggageKeys.BusinessFlow, "order-processing");
            }

            try
            {
                await _next(context);

                // Enrich with response information
                if (activity != null)
                {
                    activity.SetTag("http.response.content_length", context.Response.ContentLength ?? 0);
                    activity.SetTag("http.response.status_code", context.Response.StatusCode);

                    // Set status based on HTTP status code
                    if (context.Response.StatusCode >= 400)
                    {
                        activity.SetStatus(ActivityStatusCode.Error, $"HTTP {context.Response.StatusCode}");
                    }
                    else
                    {
                        activity.SetStatus(ActivityStatusCode.Ok);
                    }
                }
            }
            catch (Exception ex)
            {
                // Record exception with proper semantic conventions
                activity?.RecordException(ex);
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);

                _logger.LogStructuredError(ex,
                    "Unhandled exception in request pipeline for path {Path}",
                    new Dictionary<string, object>
                    {
                        ["RequestPath"] = context.Request.Path.ToString(),
                        ["RequestMethod"] = context.Request.Method,
                        ["StatusCode"] = context.Response.StatusCode
                    });

                throw;
            }
        }
    }

    /// <summary>
    /// Extension method to register the middleware
    /// </summary>
    public static class TraceEnrichmentMiddlewareExtensions
    {
        public static IApplicationBuilder UseTraceEnrichment(this IApplicationBuilder builder)
        {
            return builder.UseMiddleware<TraceEnrichmentMiddleware>();
        }
    }
}
