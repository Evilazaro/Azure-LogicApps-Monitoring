using Azure.Identity;
using Azure.Storage.Queues;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.DataContracts;
using System.Diagnostics;

namespace PoWebApp.Components
{
    public class Orders
    {
        private readonly TelemetryClient _telemetryClient;
        private static readonly ActivitySource ActivitySource = new("PoWebApp.Orders");

        public Orders(TelemetryClient telemetryClient)
        {
            _telemetryClient = telemetryClient;
        }

        public async Task<int> AddOrderMessageToQueueAsync()
        {
            using var activity = ActivitySource.StartActivity("AddOrderMessageToQueue", ActivityKind.Producer);

            try
            {
                var queueName = "orders-queue";
                var queueServiceUri = Environment.GetEnvironmentVariable("AzureWebJobsStorage__queueServiceUri");
                var tenantId = Environment.GetEnvironmentVariable("AZURE_TENANT_ID");
                var queueUri = new Uri($"{queueServiceUri.TrimEnd('/')}/{queueName}");

                activity?.SetTag("queue.name", queueName);
                activity?.SetTag("queue.uri", queueServiceUri);

                var credential = new DefaultAzureCredential(new DefaultAzureCredentialOptions
                {
                    TenantId = tenantId
                });

                var queueClient = new QueueClient(queueUri, credential);
                await queueClient.CreateIfNotExistsAsync();

                var successCount = 0;
                var failureCount = 0;

                // Track batch operation
                var batchOperation = _telemetryClient.StartOperation<DependencyTelemetry>("Queue Batch Send");
                batchOperation.Telemetry.Type = "Azure Queue Storage";
                batchOperation.Telemetry.Target = queueServiceUri;

                try
                {
                    for (int i = 0; i <= 10; i++)
                    {
                        using var messageActivity = ActivitySource.StartActivity("SendQueueMessage", ActivityKind.Producer);

                        var orderNumber = Guid.NewGuid().ToString();
                        var message = $"New order {orderNumber} placed at : {DateTime.UtcNow:o}";

                        messageActivity?.SetTag("order.number", orderNumber);
                        messageActivity?.SetTag("message.index", i);

                        try
                        {
                            await queueClient.SendMessageAsync(message);
                            successCount++;
                        }
                        catch (Exception ex)
                        {
                            failureCount++;
                            messageActivity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                            _telemetryClient.TrackException(ex, new Dictionary<string, string>
                            {
                                { "OrderNumber", orderNumber },
                                { "MessageIndex", i.ToString() },
                                { "Operation", "SendQueueMessage" }
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
                activity?.SetStatus(ActivityStatusCode.Ok);

                // Track custom metric
                _telemetryClient.TrackMetric("OrdersQueued", successCount, new Dictionary<string, string>
                {
                    { "QueueName", queueName },
                    { "BatchSize", "10" }
                });

                return successCount;
            }
            catch (Exception ex)
            {
                activity?.SetStatus(ActivityStatusCode.Error, ex.Message);
                activity?.AddException(ex);

                _telemetryClient.TrackException(ex, new Dictionary<string, string>
                {
                    { "Operation", "AddOrderMessageToQueue" },
                    { "Component", "Orders" }
                });

                throw;
            }
        }
    }
}

