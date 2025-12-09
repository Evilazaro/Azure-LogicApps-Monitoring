using System.Diagnostics;

namespace PoWebApp.Diagnostics
{
    /// <summary>
    /// Centralized diagnostics configuration for distributed tracing
    /// </summary>
    public static class DiagnosticsConfig
    {
        public const string ServiceName = "PoWebApp";
        public const string ServiceVersion = "1.0.0";
        public const string ServiceNamespace = "eShopOrders";

        // Activity Sources for custom instrumentation
        public static class ActivitySources
        {
            public static readonly ActivitySource Orders = new("PoWebApp.Orders", ServiceVersion);
            public static readonly ActivitySource UI = new("PoWebApp.UI", ServiceVersion);
            public static readonly ActivitySource Messaging = new("PoWebApp.Messaging", ServiceVersion);
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

            // Messaging attributes
            public const string MessagingSystem = "messaging.system";
            public const string MessagingDestination = "messaging.destination";
            public const string MessagingDestinationKind = "messaging.destination_kind";
            public const string MessagingOperation = "messaging.operation";
            public const string MessagingMessageId = "messaging.message_id";
            public const string MessagingPayloadSize = "messaging.message_payload_size_bytes";

            // Order business attributes
            public const string OrderId = "order.id";
            public const string OrderCustomerId = "order.customer_id";
            public const string OrderAmount = "order.amount";

            // Batch attributes
            public const string BatchSize = "batch.size";
            public const string BatchSuccessCount = "batch.success_count";
            public const string BatchFailureCount = "batch.failure_count";

            // Cloud attributes
            public const string CloudProvider = "cloud.provider";
            public const string CloudPlatform = "cloud.platform";
            public const string CloudService = "cloud.service";

            // Error attributes
            public const string ErrorType = "error.type";
            public const string ErrorMessage = "error.message";
        }

        // Common baggage keys for cross-service correlation
        public static class BaggageKeys
        {
            public const string OrderId = "order.id";
            public const string BusinessFlow = "business.flow";
            public const string MessagingSystem = "messaging.system";
            public const string CorrelationId = "correlation.id";
        }
    }
}
