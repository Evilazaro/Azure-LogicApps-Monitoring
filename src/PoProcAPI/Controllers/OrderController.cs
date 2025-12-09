using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;
using PoProcAPI.Diagnostics;

namespace PoProcAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class OrderController : ControllerBase
    {
        private readonly ILogger<OrderController> _logger;

        public OrderController(ILogger<OrderController> logger)
        {
            _logger = logger;
        }

        [HttpPost(Name = "ProcessOrder")]
        public IActionResult ProcessOrder([FromBody] OrderRequest orderRequest)
        {
            using var activity = DiagnosticsConfig.ActivitySources.Orders.StartActivity("ProcessOrder", ActivityKind.Server);

            // Enrich with HTTP context using extension method
            activity?.AddHttpContext(HttpContext);

            // Add order context with semantic conventions
            activity?.AddOrderContext(orderRequest.OrderId, orderRequest.CustomerId, orderRequest.Amount);
            activity?.SetTag("operation.name", "ProcessOrder");
            activity?.SetTag(DiagnosticsConfig.SemanticConventions.ServiceName, DiagnosticsConfig.ServiceName);

            // Add baggage for cross-service correlation
            activity?.AddBaggage(DiagnosticsConfig.BaggageKeys.BusinessFlow, "order-processing");
            activity?.AddBaggage(DiagnosticsConfig.BaggageKeys.CorrelationId, Activity.Current?.TraceId.ToString() ?? Guid.NewGuid().ToString());

            try
            {
                // Add event for order received
                activity?.AddEvent(new ActivityEvent("OrderReceived",
                    tags: new ActivityTagsCollection
                    {
                        { "order.id", orderRequest.OrderId },
                        { "timestamp", DateTimeOffset.UtcNow }
                    }));

                using (_logger.BeginScope(new Dictionary<string, object>
                {
                    ["OrderId"] = orderRequest.OrderId,
                    ["CustomerId"] = orderRequest.CustomerId,
                    ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown",
                    ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "unknown"
                }))
                {
                    _logger.LogInformation(
                        "Processing order: {OrderId} for customer {CustomerId} with amount {Amount}",
                        orderRequest.OrderId,
                        orderRequest.CustomerId,
                        orderRequest.Amount);

                    // Simulate order validation with detailed tracing
                    using var validationActivity = DiagnosticsConfig.ActivitySources.Orders.StartActivity("ValidateOrder", ActivityKind.Internal);
                    validationActivity?.AddOrderContext(orderRequest.OrderId);
                    validationActivity?.SetTag("validation.type", "business_rules");
                    validationActivity?.SetTag("validation.rules", "required_fields,amount_positive");
                    
                    var validationStart = Stopwatch.GetTimestamp();

                    ValidateOrder(orderRequest);
                    
                    var validationDuration = Stopwatch.GetElapsedTime(validationStart);
                    validationActivity?.SetTag("validation.duration_ms", validationDuration.TotalMilliseconds);
                    validationActivity?.SetStatus(ActivityStatusCode.Ok);

                    // Add event for validation complete with performance metrics
                    activity?.AddEvent(new ActivityEvent("OrderValidated",
                        tags: new ActivityTagsCollection
                        {
                            { "order.id", orderRequest.OrderId },
                            { "validation.result", "success" },
                            { "validation.duration_ms", validationDuration.TotalMilliseconds }
                        }));

                    // Simulate order processing with detailed tracing
                    var processingStart = Stopwatch.GetTimestamp();
                    using var processingActivity = DiagnosticsConfig.ActivitySources.Orders.StartActivity("ProcessOrderInternal", ActivityKind.Internal);
                    processingActivity?.AddOrderContext(orderRequest.OrderId);
                    processingActivity?.SetTag("processing.type", "order_fulfillment");
                    processingActivity?.SetTag("processing.step", "fulfillment_initiation");

                    // Simulate processing logic
                    Thread.Sleep(100); // Simulate processing time
                    
                    var processingDuration = Stopwatch.GetElapsedTime(processingStart);
                    processingActivity?.SetTag("processing.duration_ms", processingDuration.TotalMilliseconds);
                    processingActivity?.SetTag("processing.status", "completed");
                    processingActivity?.SetStatus(ActivityStatusCode.Ok, "Order fulfillment completed");
                    
                    // Add processing event with metrics
                    processingActivity?.AddEvent(new ActivityEvent("FulfillmentCompleted",
                        tags: new ActivityTagsCollection
                        {
                            { "order.id", orderRequest.OrderId },
                            { "processing.duration_ms", processingDuration.TotalMilliseconds }
                        }));

                    _logger.LogInformation("Order processed successfully: {OrderId}", orderRequest.OrderId);
                }

                // Set success status with description
                activity?.SetStatus(ActivityStatusCode.Ok, "Order processed successfully");
                activity?.SetTag(DiagnosticsConfig.SemanticConventions.OrderStatus, "accepted");
                
                var (traceParent, traceState) = activity.GetTraceContext();
                
                activity?.AddEvent(new ActivityEvent("OrderCompleted",
                    tags: new ActivityTagsCollection
                    {
                        { "order.id", orderRequest.OrderId },
                        { "processing.duration_ms", activity?.Duration.TotalMilliseconds ?? 0 },
                        { "completion.timestamp", DateTimeOffset.UtcNow.ToString("o") },
                        { "trace.parent", traceParent ?? "unknown" }
                    }));

                return Accepted(new
                {
                    OrderId = orderRequest.OrderId,
                    Status = "Accepted",
                    TraceId = Activity.Current?.TraceId.ToString()
                });
            }
            catch (Exception ex)
            {
                // Record exception with proper semantic conventions using extension method
                activity?.RecordException(ex);
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                activity?.SetTag(DiagnosticsConfig.SemanticConventions.OrderStatus, "failed");
                activity?.AddEvent(new ActivityEvent("OrderProcessingFailed",
                    tags: new ActivityTagsCollection
                    {
                        { "order.id", orderRequest.OrderId },
                        { "error.type", ex.GetType().Name },
                        { "error.message", ex.Message },
                        { "failure.timestamp", DateTimeOffset.UtcNow.ToString("o") }
                    }));

                using (_logger.BeginScope(new Dictionary<string, object>
                {
                    ["OrderId"] = orderRequest.OrderId,
                    ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown",
                    ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "unknown"
                }))
                {
                    _logger.LogError(ex,
                        "Error processing order: {OrderId}. Error: {ErrorMessage}",
                        orderRequest.OrderId,
                        ex.Message);
                }

                throw;
            }
        }

        private void ValidateOrder(OrderRequest orderRequest)
        {
            if (string.IsNullOrEmpty(orderRequest.OrderId))
                throw new ArgumentException("OrderId cannot be null or empty", nameof(orderRequest.OrderId));

            if (string.IsNullOrEmpty(orderRequest.CustomerId))
                throw new ArgumentException("CustomerId cannot be null or empty", nameof(orderRequest.CustomerId));

            if (orderRequest.Amount <= 0)
                throw new ArgumentException("Amount must be greater than zero", nameof(orderRequest.Amount));
        }
    }
}
