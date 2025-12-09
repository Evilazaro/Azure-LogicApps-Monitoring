using System.Diagnostics;

namespace PoProcAPI.Diagnostics
{
    /// <summary>
    /// Extension methods for Activity to simplify common tracing operations
    /// </summary>
    public static class ActivityExtensions
    {
        /// <summary>
        /// Records an exception with proper semantic conventions
        /// </summary>
        public static Activity? RecordException(this Activity? activity, Exception exception)
        {
            if (activity == null) return null;

            activity.SetTag(DiagnosticsConfig.SemanticConventions.ErrorType, exception.GetType().FullName);
            activity.SetTag(DiagnosticsConfig.SemanticConventions.ErrorMessage, exception.Message);
            activity.SetStatus(ActivityStatusCode.Error, exception.Message);

            activity.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", exception.GetType().FullName },
                { "exception.message", exception.Message },
                { "exception.stacktrace", exception.StackTrace ?? "" }
            }));

            return activity;
        }

        /// <summary>
        /// Adds order context to the activity
        /// </summary>
        public static Activity? AddOrderContext(this Activity? activity, Order order)
        {
            if (activity == null || order == null) return null;

            if (order.Id > 0)
            {
                activity.SetTag(DiagnosticsConfig.SemanticConventions.OrderId, order.Id);
                activity.AddBaggage(DiagnosticsConfig.BaggageKeys.OrderId, order.Id.ToString());
            }

            if (order.Total > 0)
            {
                activity.SetTag(DiagnosticsConfig.SemanticConventions.OrderAmount, order.Total);
            }

            if (order.Quantity > 0)
            {
                activity.SetTag(DiagnosticsConfig.SemanticConventions.OrderQuantity, order.Quantity);
            }

            return activity;
        }

        /// <summary>
        /// Gets the trace context for propagation (W3C Trace Context format)
        /// </summary>
        public static (string? TraceParent, string? TraceState) GetTraceContext(this Activity? activity)
        {
            if (activity == null) return (null, null);

            var traceParent = $"00-{activity.TraceId}-{activity.SpanId}-{(activity.Recorded ? "01" : "00")}";
            var traceState = activity.TraceStateString;

            return (traceParent, traceState);
        }

        /// <summary>
        /// Adds HTTP response context to the activity
        /// </summary>
        public static Activity? AddHttpResponseContext(this Activity? activity, int statusCode, long? contentLength = null)
        {
            if (activity == null) return null;

            activity.SetTag(DiagnosticsConfig.SemanticConventions.HttpResponseStatusCode, statusCode);

            if (contentLength.HasValue)
            {
                activity.SetTag(DiagnosticsConfig.SemanticConventions.HttpResponseBodySize, contentLength.Value);
            }

            // Set status based on HTTP status code
            if (statusCode >= 400)
            {
                activity.SetStatus(ActivityStatusCode.Error, $"HTTP {statusCode}");
            }
            else
            {
                activity.SetStatus(ActivityStatusCode.Ok);
            }

            return activity;
        }
    }
}
