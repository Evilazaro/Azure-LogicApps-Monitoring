using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.Extensions.Logging;
using PoWebApp.Client.Diagnostics;
using System.Diagnostics;
using System.Text.Json;

namespace PoWebApp.Client
{
    public class Orders
    {
        private readonly ILogger<Orders> _logger;

        public Orders(ILogger<Orders> logger)
        {
            _logger = logger;
        }

        public async Task<int> AddOrderMessageToQueueAsync()
        {
            var files = Directory.GetFiles("/Files");
            var filePath = "./Files/orders.json";
            var ordersJson = File.ReadAllText(filePath);
            Order[] orders = JsonSerializer.Deserialize<Order[]>(ordersJson) ?? Array.Empty<Order>();

            int batchSize = orders.Count();

            using var activity = DiagnosticsConfig.ActivitySources.Orders.StartActivity(
                "AddOrderMessageToQueue",
                ActivityKind.Producer);

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

                // Add messaging context using extension method
                activity?.AddMessagingContext("azure-queue", queueName, "batch-publish");

                // Add additional semantic convention tags
                activity?.SetTag(DiagnosticsConfig.SemanticConventions.MessagingDestinationKind, "queue");
                activity?.SetTag(DiagnosticsConfig.SemanticConventions.CloudProvider, "azure");
                activity?.SetTag(DiagnosticsConfig.SemanticConventions.CloudService, "storage");
                activity?.SetTag("messaging.url", queueServiceUri);
                activity?.SetTag(DiagnosticsConfig.SemanticConventions.BatchSize, batchSize);

                // Add baggage for cross-service correlation
                activity?.AddBaggage(DiagnosticsConfig.BaggageKeys.BusinessFlow, "order-processing");
                activity?.AddBaggage(DiagnosticsConfig.BaggageKeys.MessagingSystem, "azure-queue");

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

                    // Add event for batch start
                    activity?.AddEvent(new ActivityEvent("BatchSendStarted",
                        tags: new ActivityTagsCollection
                        {
                            { "queue.name", queueName },
                            { "batch.size", batchSize },
                            { "timestamp", DateTimeOffset.UtcNow.ToString("o") }
                        }));

                    try
                    {
                        var i = 0;
                        foreach (var order in orders)
                        {
                            i++;

                            using var messageActivity = DiagnosticsConfig.ActivitySources.Messaging.StartActivity(
                                "SendQueueMessage",
                                ActivityKind.Producer);

                            var orderData = new
                            {
                                Id = order.Id,
                                Date = order.Date,
                                Quantity = order.Quantity,
                                Total = order.Total,
                                Message = order.Message,
                                TraceId = Activity.Current?.TraceId.ToString(),
                                SpanId = Activity.Current?.SpanId.ToString()
                            };

                            var message = JsonSerializer.Serialize(orderData);

                            // Add messaging and order context using extension methods
                            messageActivity?.AddMessagingContext("azure-queue", queueName, "publish");
                            messageActivity?.AddOrderContext(order.Id.ToString(), order.Quantity.ToString(), order.Total.ToString());

                            // Add additional semantic conventions
                            messageActivity?.SetTag(DiagnosticsConfig.SemanticConventions.MessagingMessageId, order.Id);
                            messageActivity?.SetTag(DiagnosticsConfig.SemanticConventions.MessagingPayloadSize, message.Length);

                            try
                            {
                                await queueClient.SendMessageAsync(message);
                                successCount++;
                                messageActivity?.SetStatus(ActivityStatusCode.Ok);

                                _logger.LogInformation(
                                    "Batch progress: {MessagesSent}/{TotalMessages} messages sent, Batch size: {BatchSize}",
                                    i, batchSize, batchSize);
                            }
                            catch (Exception ex)
                            {
                                failureCount++;

                                // Record exception using extension method
                                messageActivity?.RecordException(ex);
                                messageActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);

                                messageActivity?.AddEvent(new ActivityEvent("MessageSendFailed",
                                    tags: new ActivityTagsCollection
                                    {
                                        { "order.id", order.Id },
                                        { "error.type", ex.GetType().Name },
                                        { "error.message", ex.Message },
                                        { "message.index", i }
                                    }));

                                _logger.LogStructuredError(ex,
                                    "Failed to send message for order {OrderNumber} at index {MessageIndex}",
                                    new Dictionary<string, object>
                                    {
                                        ["OrderNumber"] = order.Id,
                                        ["MessageIndex"] = i,
                                        ["QueueName"] = queueName
                                    });
                            }
                        }

                        // All message processing complete
                    }
                    catch (Exception batchEx)
                    {
                        activity?.RecordException(batchEx);
                        throw;
                    }

                    // Add batch completion tags using semantic conventions
                    activity?.SetTag(DiagnosticsConfig.SemanticConventions.BatchSuccessCount, successCount);
                    activity?.SetTag(DiagnosticsConfig.SemanticConventions.BatchFailureCount, failureCount);
                    activity?.SetTag("batch.total_count", batchSize);
                    activity?.SetTag("batch.success_rate", (double)successCount / batchSize);

                    var batchStatus = failureCount == 0 ? ActivityStatusCode.Ok : ActivityStatusCode.Error;
                    activity?.SetStatus(batchStatus, $"Batch completed: {successCount} succeeded, {failureCount} failed");

                    // Add event for batch completion
                    activity?.AddEvent(new ActivityEvent("BatchSendCompleted",
                        tags: new ActivityTagsCollection
                        {
                            { "batch.success_count", successCount },
                            { "batch.failure_count", failureCount },
                            { "batch.duration_ms", activity?.Duration.TotalMilliseconds ?? 0 }
                        }));

                    // Log batch completion with structured logging
                    _logger.LogStructuredInformation(
                        "Batch operation completed: {SuccessCount} messages sent successfully, {FailureCount} failed",
                        "BatchOperationCompleted",
                        new Dictionary<string, object>
                        {
                            ["SuccessCount"] = successCount,
                            ["FailureCount"] = failureCount,
                            ["QueueName"] = queueName,
                            ["BatchSize"] = batchSize,
                            ["SuccessRate"] = (double)successCount / batchSize
                        });

                    return successCount;
                }
            }
            catch (Exception ex)
            {
                // Record exception using extension method
                activity?.RecordException(ex);
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);

                activity?.AddEvent(new ActivityEvent("BatchOperationFailed",
                    tags: new ActivityTagsCollection
                    {
                        { "error.type", ex.GetType().Name },
                        { "error.message", ex.Message }
                    }));

                _logger.LogStructuredError(ex,
                    "Error in AddOrderMessageToQueue operation: {ErrorMessage}",
                    new Dictionary<string, object>
                    {
                        ["Operation"] = "AddOrderMessageToQueue",
                        ["Component"] = "Orders"
                    });

                throw;
            }
        }
    }
}

