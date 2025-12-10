using Microsoft.AspNetCore.Mvc;
using PoProcAPI.Diagnostics;
using System.Diagnostics;

namespace PoProcAPI.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class Orders : ControllerBase
    {
        private readonly ILogger<Orders> _logger;
        private static readonly ActivitySource _activitySource = DiagnosticsConfig.ActivitySources.Orders;

        public Orders(ILogger<Orders> logger)
        {
            _logger = logger;
        }

        [HttpPost(Name = "ProcessOrder")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status400BadRequest)]
        public IActionResult ProcessOrder(Order order)
        {
            // Create a new activity for order processing
            using var activity = _activitySource.StartActivity("ProcessOrder", ActivityKind.Server);

            try
            {
                // Add order context to the activity
                activity?.AddOrderContext(order);

                // Log with structured logging and trace correlation
                using (_logger.BeginCorrelatedScope(order.Id, new Dictionary<string, object>
                {
                    ["OrderDate"] = order.Date,
                    ["OrderTotal"] = order.Total,
                    ["OrderQuantity"] = order.Quantity
                }))
                {
                    _logger.LogStructuredInformation(
                        "Processing order with ID: {OrderId}",
                        "OrderProcessingStarted",
                        new Dictionary<string, object>
                        {
                            ["OrderId"] = order.Id,
                            ["OrderDate"] = order.Date.ToString("o"),
                            ["OrderTotal"] = order.Total,
                            ["OrderQuantity"] = order.Quantity
                        });

                    // Simulate order processing logic with a child activity
                    using var validationActivity = _activitySource.StartActivity("ValidateOrder", ActivityKind.Internal);
                    validationActivity?.SetTag("order.id", order.Id);

                    // Basic validation
                    if (order.Quantity <= 0)
                    {
                        _logger.LogStructuredWarning(
                            "Invalid order quantity for order {OrderId}",
                            new Dictionary<string, object>
                            {
                                ["OrderId"] = order.Id,
                                ["Quantity"] = order.Quantity
                            });

                        validationActivity?.SetStatus(ActivityStatusCode.Error, "Invalid quantity");
                        activity?.SetStatus(ActivityStatusCode.Error, "Validation failed");

                        return BadRequest(new { Message = "Order quantity must be greater than 0" });
                    }

                    if (order.Total <= 0)
                    {
                        _logger.LogStructuredWarning(
                            "Invalid order total for order {OrderId}",
                            new Dictionary<string, object>
                            {
                                ["OrderId"] = order.Id,
                                ["Total"] = order.Total
                            });

                        validationActivity?.SetStatus(ActivityStatusCode.Error, "Invalid total");
                        activity?.SetStatus(ActivityStatusCode.Error, "Validation failed");

                        return BadRequest(new { Message = "Order total must be greater than 0" });
                    }

                    validationActivity?.SetStatus(ActivityStatusCode.Ok, "Validation successful");

                    // Simulate processing
                    using var processingActivity = _activitySource.StartActivity("PerformOrderProcessing", ActivityKind.Internal);
                    processingActivity?.SetTag("order.id", order.Id);
                    processingActivity?.SetTag("processing.type", "standard");

                    // Simulate some processing time
                    Thread.Sleep(Random.Shared.Next(50, 150));

                    processingActivity?.SetStatus(ActivityStatusCode.Ok, "Processing completed");

                    _logger.LogStructuredInformation(
                        "Order with ID: {OrderId} processed successfully",
                        "OrderProcessingCompleted",
                        new Dictionary<string, object>
                        {
                            ["OrderId"] = order.Id,
                            ["ProcessingDuration"] = activity?.Duration.TotalMilliseconds ?? 0
                        });

                    // Set final activity status
                    activity?.SetStatus(ActivityStatusCode.Ok, "Order processed successfully");

                    var result = new
                    {
                        Message = "Order processed successfully",
                        OrderId = order.Id,
                        OrderDate = order.Date,
                        OrderTotal = order.Total,
                        TraceId = Activity.Current?.TraceId.ToString(),
                        SpanId = Activity.Current?.SpanId.ToString(),
                        PartitionKey = order.Date.ToString("yyyy-MM-dd"),
                        RowKey = order.Id,
                        RequestId = new Guid().ToString(),
                        Time = DateTime.UtcNow.ToString("o")
                    };

                    return Ok(result);
                }
            }
            catch (Exception ex)
            {
                // Record exception with proper semantic conventions
                activity?.RecordException(ex);

                _logger.LogStructuredError(ex,
                    "Error processing order with ID: {OrderId}",
                    new Dictionary<string, object>
                    {
                        ["OrderId"] = order.Id,
                        ["ErrorType"] = ex.GetType().Name
                    });

                return StatusCode(StatusCodes.Status500InternalServerError, new
                {
                    Message = "An error occurred processing the order",
                    TraceId = Activity.Current?.TraceId.ToString()
                });
            }
        }
    }
}
