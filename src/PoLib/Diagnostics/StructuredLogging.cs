using Microsoft.Extensions.Logging;
using System.Diagnostics;

namespace PoLib.Diagnostics
{
    public static class StructuredLogging
    {
        /// <summary>
        /// Creates a logging scope with trace correlation IDs
        /// </summary>
        public static IDisposable? BeginCorrelatedScope(this ILogger logger, string? orderId = null, IDictionary<string, object>? additionalProperties = null)
        {
            var properties = new Dictionary<string, object>
            {
                ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown",
                ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "unknown",
                ["ParentSpanId"] = Activity.Current?.ParentSpanId.ToString() ?? "unknown"
            };

            if (!string.IsNullOrEmpty(orderId))
            {
                properties["OrderId"] = orderId;
            }

            if (additionalProperties != null)
            {
                foreach (var kvp in additionalProperties)
                {
                    properties[kvp.Key] = kvp.Value;
                }
            }

            return logger.BeginScope(properties);
        }

        /// <summary>
        /// Log structured event with trace correlation
        /// </summary>
        public static void LogStructuredInformation(
            this ILogger logger,
            string message,
            string eventName,
            IDictionary<string, object>? properties = null)
        {
            var allProperties = new Dictionary<string, object>
            {
                ["EventName"] = eventName,
                ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown",
                ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "unknown"
            };

            if (properties != null)
            {
                foreach (var kvp in properties)
                {
                    allProperties[kvp.Key] = kvp.Value;
                }
            }

            using (logger.BeginScope(allProperties))
            {
                logger.LogInformation(message);
            }
        }

        /// <summary>
        /// Log structured error with trace correlation
        /// </summary>
        public static void LogStructuredError(
            this ILogger logger,
            Exception exception,
            string message,
            IDictionary<string, object>? properties = null)
        {
            var allProperties = new Dictionary<string, object>
            {
                ["ErrorType"] = exception.GetType().Name,
                ["ErrorMessage"] = exception.Message,
                ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown",
                ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "unknown"
            };

            if (properties != null)
            {
                foreach (var kvp in properties)
                {
                    allProperties[kvp.Key] = kvp.Value;
                }
            }

            using (logger.BeginScope(allProperties))
            {
                logger.LogError(exception, message);
            }
        }
    }
}
