using PoWebApp.Diagnostics;
using System.Diagnostics;

namespace PoWebApp.Examples
{
    /// <summary>
    /// Example demonstrating how to use distributed tracing with Application Insights
    /// in the PoWebApp application.
    /// </summary>
    public class DistributedTracingExample
    {
        private readonly ILogger<DistributedTracingExample> _logger;
        private readonly IHttpClientFactory _httpClientFactory;

        public DistributedTracingExample(
            ILogger<DistributedTracingExample> logger,
            IHttpClientFactory httpClientFactory)
        {
            _logger = logger;
            _httpClientFactory = httpClientFactory;
        }

        /// <summary>
        /// Example 1: Creating a custom span for business operations
        /// </summary>
        public async Task ProcessOrderExample(string orderId, string customerId, string amount)
        {
            // Start a new activity (span) for order processing
            using var activity = DiagnosticsConfig.ActivitySources.Orders.StartActivity(
                "ProcessOrder",
                ActivityKind.Internal);

            // Add order context using extension method
            activity?.AddOrderContext(orderId, customerId, amount);

            // Add custom tags
            activity?.SetTag("order.status", "processing");
            activity?.SetTag("processing.timestamp", DateTimeOffset.UtcNow.ToString("o"));

            try
            {
                // Simulate order processing
                _logger.LogInformation("Processing order {OrderId} for customer {CustomerId}",
                    orderId, customerId);

                // Call downstream service (automatically creates child span)
                await CallPaymentServiceExample(orderId, amount);

                // Mark success
                activity?.SetStatus(ActivityStatusCode.Ok, "Order processed successfully");
                activity?.SetTag("order.status", "completed");
            }
            catch (Exception ex)
            {
                // Record exception with proper semantic conventions
                activity?.RecordException(ex);
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);

                _logger.LogStructuredError(ex, "Failed to process order {OrderId}",
                    new Dictionary<string, object> { ["OrderId"] = orderId });

                throw;
            }
        }

        /// <summary>
        /// Example 2: Creating spans for external service calls
        /// </summary>
        private async Task CallPaymentServiceExample(string orderId, string amount)
        {
            // Create a span for external service call
            using var activity = DiagnosticsConfig.ActivitySources.Orders.StartActivity(
                "CallPaymentService",
                ActivityKind.Client);

            activity?.SetTag("payment.amount", amount);
            activity?.SetTag("payment.currency", "USD");
            activity?.SetTag("peer.service", "PaymentAPI");

            try
            {
                // HttpClient automatically propagates trace context
                var httpClient = _httpClientFactory.CreateClient();

                // Simulate API call
                _logger.LogInformation("Calling payment service for order {OrderId}", orderId);

                // In real scenario, you would make actual HTTP call:
                // var response = await httpClient.PostAsync(...);

                await Task.Delay(100); // Simulate network delay

                activity?.SetStatus(ActivityStatusCode.Ok);
            }
            catch (Exception ex)
            {
                activity?.RecordException(ex);
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                throw;
            }
        }

        /// <summary>
        /// Example 3: Creating spans for messaging operations
        /// </summary>
        public async Task SendOrderNotificationExample(string orderId, string quantity, string total, string messageContent)
        {
            using var activity = DiagnosticsConfig.ActivitySources.Messaging.StartActivity(
                "SendOrderNotification",
                ActivityKind.Producer);

            // Add messaging context
            activity?.AddMessagingContext("azure-queue", "order-notifications", "publish");
            activity?.SetTag(DiagnosticsConfig.SemanticConventions.MessagingMessageId, Guid.NewGuid().ToString());
            activity?.SetTag(DiagnosticsConfig.SemanticConventions.MessagingPayloadSize,
                System.Text.Encoding.UTF8.GetByteCount(messageContent));

            // Add order context as baggage for cross-service correlation
            activity?.AddOrderContext(orderId, quantity, total);

            try
            {
                _logger.LogStructuredInformation(
                    "Sending notification for order {OrderId}",
                    "OrderNotificationSent",
                    new Dictionary<string, object>
                    {
                        ["OrderId"] = orderId,
                        ["MessageSize"] = messageContent.Length
                    });

                // Simulate sending message
                await Task.Delay(50);

                activity?.SetStatus(ActivityStatusCode.Ok);
            }
            catch (Exception ex)
            {
                activity?.RecordException(ex);
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                throw;
            }
        }

        /// <summary>
        /// Example 4: Using correlated logging scopes
        /// </summary>
        public void CorrelatedLoggingExample(string orderId)
        {
            // Create a correlated logging scope
            using var logScope = _logger.BeginCorrelatedScope(
                orderId,
                new Dictionary<string, object>
                {
                    ["CustomerId"] = "CUST-123",
                    ["Environment"] = "Production"
                });

            // All logs within this scope will include trace IDs and custom properties
            _logger.LogInformation("Starting order validation");
            _logger.LogInformation("Order validation completed");
        }

        /// <summary>
        /// Example 5: Propagating trace context manually (for non-HTTP scenarios)
        /// </summary>
        public (string? TraceParent, string? TraceState) GetTraceContextForPropagation()
        {
            // Get current trace context for manual propagation
            var currentActivity = Activity.Current;
            return currentActivity.GetTraceContext();
        }

        /// <summary>
        /// Example 6: Creating a parent-child span relationship
        /// </summary>
        public async Task ProcessBatchOrdersExample(List<string> orderIds)
        {
            using var batchActivity = DiagnosticsConfig.ActivitySources.Orders.StartActivity(
                "ProcessBatchOrders",
                ActivityKind.Internal);

            batchActivity?.SetTag(DiagnosticsConfig.SemanticConventions.BatchSize, orderIds.Count);

            int successCount = 0;
            int failureCount = 0;

            foreach (var orderId in orderIds)
            {
                try
                {
                    // Each ProcessOrder call creates a child span
                    await ProcessOrderExample(orderId, "BATCH-CUSTOMER", "100.00m");
                    successCount++;
                }
                catch (Exception ex)
                {
                    failureCount++;
                    _logger.LogError(ex, "Failed to process order {OrderId} in batch", orderId);
                }
            }

            batchActivity?.SetTag(DiagnosticsConfig.SemanticConventions.BatchSuccessCount, successCount);
            batchActivity?.SetTag(DiagnosticsConfig.SemanticConventions.BatchFailureCount, failureCount);

            if (failureCount > 0)
            {
                batchActivity?.SetStatus(ActivityStatusCode.Error,
                    $"Batch processing completed with {failureCount} failures");
            }
            else
            {
                batchActivity?.SetStatus(ActivityStatusCode.Ok, "All orders processed successfully");
            }
        }

        /// <summary>
        /// Example 7: Adding custom events to spans
        /// </summary>
        public async Task ProcessOrderWithEventsExample(string orderId,string quantity, string total)
        {
            using var activity = DiagnosticsConfig.ActivitySources.Orders.StartActivity(
                "ProcessOrderWithEvents",
                ActivityKind.Internal);

            activity?.AddOrderContext(orderId, quantity, total);

            // Add custom events to track milestones
            activity?.AddEvent(new ActivityEvent("OrderValidationStarted"));
            await Task.Delay(50); // Simulate validation

            activity?.AddEvent(new ActivityEvent("OrderValidationCompleted",
                tags: new ActivityTagsCollection
                {
                    { "validation.result", "passed" },
                    { "validation.duration_ms", 50 }
                }));

            activity?.AddEvent(new ActivityEvent("InventoryCheckStarted"));
            await Task.Delay(30); // Simulate inventory check

            activity?.AddEvent(new ActivityEvent("InventoryCheckCompleted",
                tags: new ActivityTagsCollection
                {
                    { "inventory.available", true },
                    { "inventory.location", "Warehouse-A" }
                }));

            activity?.SetStatus(ActivityStatusCode.Ok, "Order processed with all milestones");
        }
    }
}
