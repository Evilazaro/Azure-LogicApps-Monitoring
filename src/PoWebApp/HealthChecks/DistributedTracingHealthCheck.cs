using Microsoft.Extensions.Diagnostics.HealthChecks;
using System.Diagnostics;
using System.Text.Json;

namespace PoWebApp.HealthChecks
{
    /// <summary>
    /// Health check to verify distributed tracing is properly configured
    /// </summary>
    public class DistributedTracingHealthCheck : IHealthCheck
    {
        private readonly ILogger<DistributedTracingHealthCheck> _logger;

        public DistributedTracingHealthCheck(ILogger<DistributedTracingHealthCheck> logger)
        {
            _logger = logger;
        }

        public Task<HealthCheckResult> CheckHealthAsync(
            HealthCheckContext context,
            CancellationToken cancellationToken = default)
        {
            var data = new Dictionary<string, object>();

            try
            {
                // Check if Activity.Current is available
                var currentActivity = Activity.Current;
                if (currentActivity == null)
                {
                    return Task.FromResult(HealthCheckResult.Degraded(
                        "No active activity found - tracing may not be properly configured",
                        data: data));
                }

                data["TraceId"] = currentActivity.TraceId.ToString();
                data["SpanId"] = currentActivity.SpanId.ToString();
                data["ActivitySourceName"] = currentActivity.Source.Name;
                data["IsRecorded"] = currentActivity.Recorded;

                // Check if Application Insights connection string is configured
                var connectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING");
                data["ApplicationInsightsConfigured"] = !string.IsNullOrEmpty(connectionString);

                // Verify activity sources are available
                data["OrderActivitySourceAvailable"] =
                    Diagnostics.DiagnosticsConfig.ActivitySources.Orders != null;
                data["MessagingActivitySourceAvailable"] =
                    Diagnostics.DiagnosticsConfig.ActivitySources.Messaging != null;
                data["UIActivitySourceAvailable"] =
                    Diagnostics.DiagnosticsConfig.ActivitySources.UI != null;

                if (string.IsNullOrEmpty(connectionString))
                {
                    return Task.FromResult(HealthCheckResult.Degraded(
                        "Application Insights connection string not configured",
                        data: data));
                }

                return Task.FromResult(HealthCheckResult.Healthy(
                    "Distributed tracing is properly configured",
                    data: data));
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Health check failed");
                return Task.FromResult(HealthCheckResult.Unhealthy(
                    "Error checking distributed tracing configuration",
                    ex,
                    data));
            }
        }
    }

    /// <summary>
    /// Extension methods for health check registration
    /// </summary>
    public static class DistributedTracingHealthCheckExtensions
    {
        public static IHealthChecksBuilder AddDistributedTracingHealthCheck(
            this IHealthChecksBuilder builder)
        {
            return builder.AddCheck<DistributedTracingHealthCheck>(
                "distributed-tracing",
                tags: new[] { "tracing", "telemetry" });
        }
    }

    /// <summary>
    /// Custom health check response writer for JSON output
    /// </summary>
    public static class HealthCheckResponseWriter
    {
        public static async Task WriteJsonResponse(HttpContext context, HealthReport report)
        {
            context.Response.ContentType = "application/json; charset=utf-8";

            var options = new JsonSerializerOptions
            {
                WriteIndented = true,
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase
            };

            var result = new
            {
                status = report.Status.ToString(),
                duration = report.TotalDuration,
                checks = report.Entries.Select(e => new
                {
                    name = e.Key,
                    status = e.Value.Status.ToString(),
                    description = e.Value.Description,
                    duration = e.Value.Duration,
                    data = e.Value.Data
                }),
                timestamp = DateTime.UtcNow
            };

            await JsonSerializer.SerializeAsync(context.Response.Body, result, options);
        }
    }
}
