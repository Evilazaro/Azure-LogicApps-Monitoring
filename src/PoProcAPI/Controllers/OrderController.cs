using Microsoft.AspNetCore.Mvc;
using System.Diagnostics;

namespace PoProcAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class OrderController : ControllerBase
    {
        private readonly ILogger<OrderController> _logger;
        private static readonly ActivitySource ActivitySource = new("PoProcAPI.Orders", "1.0.0");

        public OrderController(ILogger<OrderController> logger)
        {
            _logger = logger;
        }

        [HttpPost(Name = "ProcessOrder")]
        public IActionResult ProcessOrder([FromBody] OrderRequest orderRequest)
        {
            using var activity = ActivitySource.StartActivity("ProcessOrder", ActivityKind.Server);
            
            // Add semantic convention attributes
            activity?.SetTag("http.method", HttpContext.Request.Method);
            activity?.SetTag("http.route", "/Order");
            activity?.SetTag("http.target", HttpContext.Request.Path);
            activity?.SetTag("order.id", orderRequest.OrderId);
            activity?.SetTag("order.customer_id", orderRequest.CustomerId);
            activity?.SetTag("order.amount", orderRequest.Amount);
            activity?.SetTag("operation.name", "ProcessOrder");
            activity?.SetTag("service.name", "PoProcAPI");
            
            // Add baggage for cross-service correlation
            activity?.AddBaggage("order.id", orderRequest.OrderId);
            activity?.AddBaggage("business.flow", "order-processing");

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

                    // Simulate order validation
                    using var validationActivity = ActivitySource.StartActivity("ValidateOrder", ActivityKind.Internal);
                    validationActivity?.SetTag("order.id", orderRequest.OrderId);
                    validationActivity?.SetTag("validation.type", "business_rules");
                    
                    ValidateOrder(orderRequest);
                    validationActivity?.SetStatus(ActivityStatusCode.Ok);
                    
                    // Add event for validation complete
                    activity?.AddEvent(new ActivityEvent("OrderValidated",
                        tags: new ActivityTagsCollection
                        {
                            { "order.id", orderRequest.OrderId },
                            { "validation.result", "success" }
                        }));

                    // Simulate order processing
                    using var processingActivity = ActivitySource.StartActivity("ProcessOrderInternal", ActivityKind.Internal);
                    processingActivity?.SetTag("order.id", orderRequest.OrderId);
                    processingActivity?.SetTag("processing.type", "order_fulfillment");
                    
                    // Simulate processing logic
                    Thread.Sleep(100); // Simulate processing time
                    
                    processingActivity?.SetStatus(ActivityStatusCode.Ok);
                    
                    _logger.LogInformation("Order processed successfully: {OrderId}", orderRequest.OrderId);
                }

                // Set success status with description
                activity?.SetStatus(ActivityStatusCode.Ok, "Order processed successfully");
                activity?.AddEvent(new ActivityEvent("OrderCompleted",
                    tags: new ActivityTagsCollection
                    {
                        { "order.id", orderRequest.OrderId },
                        { "processing.duration_ms", activity?.Duration.TotalMilliseconds ?? 0 }
                    }));

                return Accepted(new { 
                    OrderId = orderRequest.OrderId, 
                    Status = "Accepted",
                    TraceId = Activity.Current?.TraceId.ToString()
                });
            }
            catch (Exception ex)
            {
                // Record exception with proper semantic conventions
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                activity?.RecordException(ex);
                activity?.AddEvent(new ActivityEvent("OrderProcessingFailed",
                    tags: new ActivityTagsCollection
                    {
                        { "order.id", orderRequest.OrderId },
                        { "error.type", ex.GetType().Name },
                        { "error.message", ex.Message }
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
