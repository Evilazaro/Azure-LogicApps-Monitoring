using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using Microsoft.Extensions.Logging;
using System.Diagnostics;
using System.Text.Json;
using PoWebApp.Diagnostics;

namespace PoWebApp.Components
{
    public class Orders
    {
        private readonly TelemetryClient _telemetryClient;
        private readonly ILogger<Orders> _logger;
        private static readonly ActivitySource ActivitySource = new("PoWebApp.Orders", "1.0.0");

        public Orders(TelemetryClient telemetryClient, ILogger<Orders> logger)
        {
            _telemetryClient = telemetryClient;
            _logger = logger;
        }

        public async Task<int> AddOrderMessageToQueueAsync()
        {
            using var activity = ActivitySource.StartActivity("AddOrderMessageToQueue", ActivityKind.Producer);

            try
            {
                var queueName = "orders-queue";
                var queueServiceUri = Environment.GetEnvironmentVariable("AzureWebJobsStorage__queueServiceUri");
                
                if (string.IsNullOrEmpty(queueServiceUri))
                {
                    throw new InvalidOperationException("AzureWebJobsStorage__queueServiceUri environment variable is not configured");
                }
                
                var tenantId = Environment.GetEnvironmentVariable("AZURE_TENANT_ID");
                var queueUri = new Uri($"{queueServiceUri.TrimEnd('/')}/{queueName}");

                // Add semantic convention tags
                activity?.SetTag("messaging.system", "azure_queue_storage");
                activity?.SetTag("messaging.destination", queueName);
                activity?.SetTag("messaging.destination_kind", "queue");
                activity?.SetTag("messaging.url", queueServiceUri);
                activity?.SetTag("messaging.operation", "publish");
                activity?.SetTag("cloud.provider", "azure");
                activity?.SetTag("cloud.service", "storage");
                
                // Add baggage for cross-service correlation
                activity?.AddBaggage("business.flow", "order-processing");
                activity?.AddBaggage("messaging.system", "azure_queue_storage");

                using (_logger.BeginScope(new Dictionary<string, object>
                {
                    ["QueueName"] = queueName,
                    ["QueueUri"] = queueServiceUri ?? "unknown",
                    ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown",
                    ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "unknown"
                }))
                {
                    _logger.LogInformation("Starting batch order queue operation for queue: {QueueName}", queueName);

                    var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                    {
                        TenantId = tenantId
                    });

                    var queueClient = new QueueClient(queueUri, credential);

                    var successCount = 0;
                    var failureCount = 0;

                    // Track batch operation
                    var batchOperation = _telemetryClient.StartOperation<DependencyTelemetry>("Queue Batch Send");
                    batchOperation.Telemetry.Type = "Azure Queue Storage";
                    batchOperation.Telemetry.Target = queueServiceUri;
                    batchOperation.Telemetry.Properties["QueueName"] = queueName;
                    batchOperation.Telemetry.Properties["BatchSize"] = "5000";

                    // Add event for batch start
                    activity?.AddEvent(new ActivityEvent("BatchSendStarted",
                        tags: new ActivityTagsCollection
                        {
                            { "queue.name", queueName },
                            { "batch.size", 5000 },
                            { "timestamp", DateTimeOffset.UtcNow }
                        }));

                    try
                    {
                        for (int i = 0; i <= 5000; i++)
                        {
                            using var messageActivity = ActivitySource.StartActivity("SendQueueMessage", ActivityKind.Producer);

                            var orderNumber = Guid.NewGuid().ToString();
                            var orderData = new
                            {
                                OrderId = orderNumber,
                                CustomerId = $"CUST-{Random.Shared.Next(1000, 9999)}",
                                Amount = Random.Shared.Next(10, 1000),
                                Timestamp = DateTime.UtcNow,
                                TraceId = Activity.Current?.TraceId.ToString(),
                                SpanId = Activity.Current?.SpanId.ToString()
                            };

                            var message = JsonSerializer.Serialize(orderData);

                            // Add semantic conventions for messaging
                            messageActivity?.SetTag("messaging.system", "azure_queue_storage");
                            messageActivity?.SetTag("messaging.destination", queueName);
                            messageActivity?.SetTag("messaging.operation", "publish");
                            messageActivity?.SetTag("messaging.message_id", orderNumber);
                            messageActivity?.SetTag("messaging.message_payload_size_bytes", message.Length);
                            messageActivity?.SetTag("order.id", orderNumber);
                            messageActivity?.SetTag("order.customer_id", orderData.CustomerId);
                            messageActivity?.SetTag("order.amount", orderData.Amount);
                            messageActivity?.SetTag("message.index", i);
                            
                            // Add baggage to propagate context
                            messageActivity?.AddBaggage("order.id", orderNumber);

                            try
                            {
                                await queueClient.SendMessageAsync(message);
                                successCount++;
                                messageActivity?.SetStatus(ActivityStatusCode.Ok);
                                
                                if (i % 1000 == 0)
                                {
                                    _logger.LogInformation(
                                        "Batch progress: {MessagesSent}/{TotalMessages} messages sent",
                                        i, 5000);
                                }
                            }
                            catch (Exception ex)
                            {
                                failureCount++;
                                messageActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                                messageActivity?.RecordException(ex);
                                
                                messageActivity?.AddEvent(new ActivityEvent("MessageSendFailed",
                                    tags: new ActivityTagsCollection
                                    {
                                        { "order.id", orderNumber },
                                        { "error.type", ex.GetType().Name },
                                        { "error.message", ex.Message }
                                    }));

                                using (_logger.BeginScope(new Dictionary<string, object>
                                {
                                    ["OrderNumber"] = orderNumber,
                                    ["MessageIndex"] = i,
                                    ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown"
                                }))
                                {
                                    _logger.LogError(ex,
                                        "Failed to send message for order {OrderNumber} at index {MessageIndex}",
                                        orderNumber, i);
                                }

                                _telemetryClient.TrackException(ex, new Dictionary<string, string>
                                {
                                    { "OrderNumber", orderNumber },
                                    { "MessageIndex", i.ToString() },
                                    { "Operation", "SendQueueMessage" },
                                    { "QueueName", queueName }
                                });
                            }
                        }

                        batchOperation.Telemetry.Success = true;
                        batchOperation.Telemetry.Properties["SuccessCount"] = successCount.ToString();
                        batchOperation.Telemetry.Properties["FailureCount"] = failureCount.ToString();
                    }
                    finally
                    {
                        _telemetryClient.StopOperation(batchOperation);
                    }

                    activity?.SetTag("batch.success_count", successCount);
                    activity?.SetTag("batch.failure_count", failureCount);
                    activity?.SetTag("batch.total_count", 5000);
                    activity?.SetTag("batch.success_rate", (double)successCount / 5000);
                    activity?.SetStatus(ActivityStatusCode.Ok, $"Batch completed: {successCount} succeeded, {failureCount} failed");

                    // Add event for batch completion
                    activity?.AddEvent(new ActivityEvent("BatchSendCompleted",
                        tags: new ActivityTagsCollection
                        {
                            { "batch.success_count", successCount },
                            { "batch.failure_count", failureCount },
                            { "batch.duration_ms", activity?.Duration.TotalMilliseconds ?? 0 }
                        }));

                    // Track custom metric
                    _telemetryClient.TrackMetric("OrdersQueued", successCount, new Dictionary<string, string>
                    {
                        { "QueueName", queueName },
                        { "BatchSize", "5000" },
                        { "TraceId", Activity.Current?.TraceId.ToString() ?? "unknown" }
                    });

                    _logger.LogInformation(
                        "Batch operation completed: {SuccessCount} messages sent successfully, {FailureCount} failed",
                        successCount, failureCount);

                    return successCount;
                }
            }
            catch (Exception ex)
            {
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                activity?.RecordException(ex);
                
                activity?.AddEvent(new ActivityEvent("BatchOperationFailed",
                    tags: new ActivityTagsCollection
                    {
                        { "error.type", ex.GetType().Name },
                        { "error.message", ex.Message }
                    }));

                using (_logger.BeginScope(new Dictionary<string, object>
                {
                    ["TraceId"] = Activity.Current?.TraceId.ToString() ?? "unknown",
                    ["SpanId"] = Activity.Current?.SpanId.ToString() ?? "unknown"
                }))
                {
                    _logger.LogError(ex, "Error in AddOrderMessageToQueue operation: {ErrorMessage}", ex.Message);
                }

                _telemetryClient.TrackException(ex, new Dictionary<string, string>
                {
                    { "Operation", "AddOrderMessageToQueue" },
                    { "Component", "Orders" },
                    { "TraceId", Activity.Current?.TraceId.ToString() ?? "unknown" }
                });

                throw;
            }
        }
    }
}

