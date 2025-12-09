using System.Diagnostics;

namespace PoProcAPI.Diagnostics
{
    /// <summary>
    /// Centralized diagnostics configuration for distributed tracing
    /// </summary>
    public static class DiagnosticsConfig
    {
        public const string ServiceName = "PoProcAPI";
        public const string ServiceVersion = "1.0.0";
        public const string ServiceNamespace = "eShopOrders";

        // Activity Sources for custom instrumentation
        public static class ActivitySources
        {
            public static readonly ActivitySource Orders = new("PoProcAPI.Orders", ServiceVersion);
            public static readonly ActivitySource Database = new("PoProcAPI.Database", ServiceVersion);
            public static readonly ActivitySource External = new("PoProcAPI.External", ServiceVersion);
        }

        // Semantic convention keys for consistent tagging
        public static class SemanticConventions
        {
            // Service attributes
            public const string ServiceName = "service.name";
            public const string ServiceVersion = "service.version";
            public const string ServiceNamespace = "service.namespace";
            public const string ServiceInstanceId = "service.instance.id";
            public const string DeploymentEnvironment = "deployment.environment";

            // HTTP attributes
            public const string HttpMethod = "http.method";
            public const string HttpRoute = "http.route";
            public const string HttpTarget = "http.target";
            public const string HttpStatusCode = "http.status_code";
            public const string HttpUrl = "http.url";

            // Order business attributes
            public const string OrderId = "order.id";
            public const string OrderCustomerId = "order.customer_id";
            public const string OrderAmount = "order.amount";
            public const string OrderStatus = "order.status";

            // Cloud attributes
            public const string CloudProvider = "cloud.provider";
            public const string CloudPlatform = "cloud.platform";
            public const string CloudRegion = "cloud.region";

            // Error attributes
            public const string ErrorType = "error.type";
            public const string ErrorMessage = "error.message";
            public const string ErrorStackTrace = "error.stack_trace";
        }

        // Common baggage keys for cross-service correlation
        public static class BaggageKeys
        {
            public const string OrderId = "order.id";
            public const string BusinessFlow = "business.flow";
            public const string CorrelationId = "correlation.id";
            public const string UserId = "user.id";
        }
    }
}
