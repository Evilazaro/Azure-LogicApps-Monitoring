using Azure.Messaging.ServiceBus;
using Microsoft.Extensions.Diagnostics.HealthChecks;

namespace eShop.Orders.API.HealthChecks;

/// <summary>
/// Health check for Azure Service Bus connectivity.
/// </summary>
public sealed class ServiceBusHealthCheck : IHealthCheck
{
    private readonly ServiceBusClient _serviceBusClient;
    private readonly ILogger<ServiceBusHealthCheck> _logger;
    private readonly IConfiguration _configuration;

    public ServiceBusHealthCheck(
        ServiceBusClient serviceBusClient,
        ILogger<ServiceBusHealthCheck> logger,
        IConfiguration configuration)
    {
        _serviceBusClient = serviceBusClient ?? throw new ArgumentNullException(nameof(serviceBusClient));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _configuration = configuration ?? throw new ArgumentNullException(nameof(configuration));
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var topicName = _configuration["Azure:ServiceBus:TopicName"] ?? "ordersplaced";

            // Try to create a sender to verify connectivity
            // This doesn't send a message, just verifies the client can connect
            await using var sender = _serviceBusClient.CreateSender(topicName);

            return HealthCheckResult.Healthy($"Service Bus connection is healthy. Topic: {topicName}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Service Bus health check failed");

            return new HealthCheckResult(
                context.Registration.FailureStatus,
                description: "Service Bus connection failed",
                exception: ex);
        }
    }
}