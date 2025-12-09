using System.Diagnostics;

namespace PoWebApp.Diagnostics
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

            activity.AddEvent(new ActivityEvent("exception", tags: new ActivityTagsCollection
            {
                { "exception.type", exception.GetType().FullName },
                { "exception.message", exception.Message },
                { "exception.stacktrace", exception.StackTrace ?? "" }
            }));

            return activity;
        }

        /// <summary>
        /// Adds messaging context to the activity
        /// </summary>
        public static Activity? AddMessagingContext(this Activity? activity, string messagingSystem, string destination, string operation)
        {
            if (activity == null) return null;

            activity.SetTag(DiagnosticsConfig.SemanticConventions.MessagingSystem, messagingSystem);
            activity.SetTag(DiagnosticsConfig.SemanticConventions.MessagingDestination, destination);
            activity.SetTag(DiagnosticsConfig.SemanticConventions.MessagingOperation, operation);

            return activity;
        }

        /// <summary>
        /// Adds order context to the activity
        /// </summary>
        public static Activity? AddOrderContext(this Activity? activity, string orderId, string? customerId = null, decimal? amount = null)
        {
            if (activity == null) return null;

            activity.SetTag(DiagnosticsConfig.SemanticConventions.OrderId, orderId);
            activity.AddBaggage(DiagnosticsConfig.BaggageKeys.OrderId, orderId);

            if (!string.IsNullOrEmpty(customerId))
            {
                activity.SetTag(DiagnosticsConfig.SemanticConventions.OrderCustomerId, customerId);
            }

            if (amount.HasValue)
            {
                activity.SetTag(DiagnosticsConfig.SemanticConventions.OrderAmount, amount.Value);
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
    }
}
